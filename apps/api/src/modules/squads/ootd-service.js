/**
 * OOTD post service: business logic for creating, reading, deleting OOTD posts,
 * managing reactions and comments, and "Steal This Look" AI matching.
 *
 * Story 9.2: OOTD Post Creation (FR-SOC-06)
 * Story 9.4: Reactions & Comments (FR-SOC-09, FR-SOC-10, FR-SOC-11)
 * Story 9.5: "Steal This Look" Matcher (FR-SOC-12, FR-SOC-13)
 */

import { buildWardrobeSummary } from "../shopping/shopping-scan-service.js";

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const STEAL_LOOK_MODEL = "gemini-2.0-flash";

const STEAL_LOOK_PROMPT = `You are a wardrobe matching expert. A user wants to recreate a friend's outfit using items from their own wardrobe.

FRIEND'S OUTFIT ITEMS:
{sourceItemsJson}

USER'S WARDROBE:
{wardrobeSummary}

For each of the friend's outfit items, find up to 3 best matching items from the user's wardrobe. Match based on:
1. Category match (must be same or very similar category, e.g., tops/blouses, bottoms/trousers)
2. Color similarity (exact match scores highest, complementary or neutral substitutes score lower)
3. Style similarity (casual/formal/sporty alignment)
4. Material and pattern similarity (bonus factor)

Score each match 0-100 where:
- 80-100: Excellent match (very similar item)
- 60-79: Good match (similar category and style, different color/detail)
- 30-59: Partial match (same category, different style)
- Below 30: Do not include (not a useful match)

Return ONLY valid JSON:
{
  "matches": [
    {
      "sourceItemId": "<friend's item UUID>",
      "matchedItems": [
        {
          "itemId": "<user's wardrobe item UUID>",
          "matchScore": <integer 0-100>,
          "matchReason": "<1 sentence explaining why this is a match>"
        }
      ]
    }
  ]
}

RULES:
- Use ONLY item IDs from the user's wardrobe list. Do NOT invent IDs.
- If no good match exists (all below 30), return an empty matchedItems array for that source item.
- Maximum 3 matches per source item, sorted by matchScore descending.
- Category must be compatible (don't match shoes to tops).`;

const STEAL_LOOK_PROMPT_SUMMARY = `You are a wardrobe matching expert. A user wants to recreate a friend's outfit using items from their own wardrobe.

FRIEND'S OUTFIT ITEMS:
{sourceItemsJson}

USER'S WARDROBE (distribution summary):
{wardrobeSummary}

For each of the friend's outfit items, find up to 3 best matching item descriptions from the user's wardrobe distributions. Match based on:
1. Category match (must be same or very similar category)
2. Color similarity (exact match scores highest)
3. Style similarity (casual/formal/sporty alignment)

Score each match 0-100.

Return ONLY valid JSON:
{
  "matches": [
    {
      "sourceItemId": "<friend's item UUID>",
      "matchedItems": [
        {
          "category": "<category>",
          "color": "<color>",
          "style": "<style>",
          "matchScore": <integer 0-100>,
          "matchReason": "<1 sentence>"
        }
      ]
    }
  ]
}

RULES:
- Use ONLY categories, colors, and styles that exist in the wardrobe summary.
- If no good match exists (all below 30), return an empty matchedItems array.
- Maximum 3 matches per source item, sorted by matchScore descending.
- Category must be compatible.`;

/**
 * Estimate the cost of a Gemini API call based on token usage.
 * Gemini 2.0 Flash pricing: ~$0.075 per 1M input tokens, ~$0.30 per 1M output tokens.
 */
function estimateCost(usageMetadata) {
  const inputTokens = usageMetadata?.promptTokenCount ?? 0;
  const outputTokens = usageMetadata?.candidatesTokenCount ?? 0;
  const inputCost = (inputTokens / 1_000_000) * 0.075;
  const outputCost = (outputTokens / 1_000_000) * 0.30;
  return inputCost + outputCost;
}

/**
 * Validate post creation input.
 * @throws {{ statusCode: 400, message: string }} on validation failure.
 */
export function validatePostInput({ photoUrl, caption, squadIds, taggedItemIds }) {
  if (!photoUrl || typeof photoUrl !== "string" || photoUrl.trim().length === 0) {
    throw { statusCode: 400, code: "BAD_REQUEST", message: "photoUrl is required" };
  }

  if (caption !== undefined && caption !== null) {
    if (typeof caption !== "string") {
      throw { statusCode: 400, code: "BAD_REQUEST", message: "Caption must be a string" };
    }
    if (caption.length > 150) {
      throw { statusCode: 400, code: "BAD_REQUEST", message: "Caption must be at most 150 characters" };
    }
  }

  if (!squadIds || !Array.isArray(squadIds) || squadIds.length === 0) {
    throw { statusCode: 400, code: "BAD_REQUEST", message: "squadIds must be a non-empty array" };
  }

  for (const id of squadIds) {
    if (typeof id !== "string" || !UUID_REGEX.test(id)) {
      throw { statusCode: 400, code: "BAD_REQUEST", message: "Each squadId must be a valid UUID" };
    }
  }

  if (taggedItemIds !== undefined && taggedItemIds !== null) {
    if (!Array.isArray(taggedItemIds)) {
      throw { statusCode: 400, code: "BAD_REQUEST", message: "taggedItemIds must be an array" };
    }
    for (const id of taggedItemIds) {
      if (typeof id !== "string" || !UUID_REGEX.test(id)) {
        throw { statusCode: 400, code: "BAD_REQUEST", message: "Each taggedItemId must be a valid UUID" };
      }
    }
  }

  return {
    photoUrl: photoUrl.trim(),
    caption: caption?.trim() ?? null,
    squadIds,
    taggedItemIds: taggedItemIds ?? [],
  };
}

/**
 * Validate comment input.
 * @throws {{ statusCode: 400, message: string }} on validation failure.
 */
export function validateCommentInput({ text }) {
  if (!text || typeof text !== "string" || text.trim().length === 0) {
    throw { statusCode: 400, code: "BAD_REQUEST", message: "Comment text is required" };
  }
  if (text.trim().length > 200) {
    throw { statusCode: 400, code: "BAD_REQUEST", message: "Comment text must be at most 200 characters" };
  }
  return { text: text.trim() };
}

/**
 * @param {object} options
 * @param {object} options.ootdRepo - OOTD repository instance.
 * @param {object} options.squadRepo - Squad repository instance.
 * @param {import('pg').Pool} [options.pool] - PostgreSQL connection pool (for notifications).
 * @param {object} [options.itemRepo] - Item repository (for steal-look wardrobe fetch).
 * @param {object} [options.geminiClient] - Gemini AI client (for steal-look matching).
 * @param {object} [options.aiUsageLogRepo] - AI usage log repository (for steal-look logging).
 * @param {object} [options.notificationService] - Notification service for FCM delivery (Story 9.6).
 */
export function createOotdService({ ootdRepo, squadRepo, pool, itemRepo, geminiClient, aiUsageLogRepo, notificationService }) {
  if (!ootdRepo) {
    throw new TypeError("ootdRepo is required");
  }
  if (!squadRepo) {
    throw new TypeError("squadRepo is required");
  }

  return {
    /**
     * Create a new OOTD post.
     */
    async createPost(authContext, { photoUrl, caption, squadIds, taggedItemIds }) {
      const validated = validatePostInput({ photoUrl, caption, squadIds, taggedItemIds });

      // Look up profile ID for membership checks
      const profileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!profileId) {
        throw { statusCode: 401, message: "Profile not found" };
      }

      // Verify user is a member of all selected squads
      for (const squadId of validated.squadIds) {
        const membership = await squadRepo.getMembership(squadId, profileId);
        if (!membership) {
          throw { statusCode: 403, code: "FORBIDDEN", message: "You are not a member of one or more selected squads" };
        }
      }

      const post = await ootdRepo.createPost(authContext, validated);

      // Fire-and-forget: send push notifications to squad members (Story 9.6)
      if (notificationService) {
        const authorName = post.authorDisplayName ?? "Someone";
        const notifBody = validated.caption?.substring(0, 100) || "Check out their outfit!";
        for (const squadId of validated.squadIds) {
          notificationService.sendToSquadMembers(squadId, profileId, {
            title: `${authorName} posted a new OOTD`,
            body: notifBody,
            data: { type: "ootd_post", postId: post.id },
            checkSocialMode: "all",
          }).catch((err) => console.error("[NOTIFICATION] Error:", err));
        }
      }

      return { post };
    },

    /**
     * Get a single post by ID.
     */
    async getPost(authContext, { postId }) {
      const post = await ootdRepo.getPostById(authContext, postId);
      if (!post) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
      }
      return { post };
    },

    /**
     * List posts for a specific squad (paginated).
     */
    async listSquadPosts(authContext, { squadId, limit, cursor }) {
      // Verify user is a member of the squad
      const profileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!profileId) {
        throw { statusCode: 401, message: "Profile not found" };
      }
      const membership = await squadRepo.getMembership(squadId, profileId);
      if (!membership) {
        throw { statusCode: 403, code: "FORBIDDEN", message: "You are not a member of this squad" };
      }

      const effectiveLimit = Math.min(limit || 20, 50);
      return ootdRepo.listPostsForSquad(authContext, squadId, { limit: effectiveLimit, cursor });
    },

    /**
     * List posts across all user's squads (paginated feed).
     */
    async listFeedPosts(authContext, { limit, cursor }) {
      const effectiveLimit = Math.min(limit || 20, 50);
      return ootdRepo.listPostsForUser(authContext, { limit: effectiveLimit, cursor });
    },

    /**
     * Soft-delete a post (only the author can do this).
     */
    async deletePost(authContext, { postId }) {
      const post = await ootdRepo.getPostById(authContext, postId);
      if (!post) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
      }

      // Check post author matches
      const profileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!profileId || post.authorId !== profileId) {
        throw { statusCode: 403, code: "FORBIDDEN", message: "Only the author can delete this post" };
      }

      await ootdRepo.softDeletePost(authContext, postId);
    },

    // --- Reactions ---

    /**
     * Toggle a fire reaction on a post.
     */
    async toggleReaction(authContext, { postId }) {
      // Verify post exists and is visible to user
      const post = await ootdRepo.getPostById(authContext, postId);
      if (!post) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
      }

      const toggleResult = await ootdRepo.toggleReaction(authContext, postId);
      const reactionCount = await ootdRepo.getReactionCount(postId);

      return { reacted: toggleResult.reacted, reactionCount };
    },

    // --- Comments ---

    /**
     * Create a comment on a post.
     */
    async createComment(authContext, { postId, text }) {
      const validated = validateCommentInput({ text });

      // Verify post exists and is visible to user
      const post = await ootdRepo.getPostById(authContext, postId);
      if (!post) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
      }

      const comment = await ootdRepo.createComment(authContext, postId, { text: validated.text });

      // Fire-and-forget notification to post author (if commenter is not the author)
      const profileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (profileId && post.authorId !== profileId && notificationService) {
        notificationService.sendPushNotification(post.authorId, {
          title: `${comment.authorDisplayName ?? "Someone"} commented on your OOTD`,
          body: validated.text.substring(0, 100),
          data: { type: "ootd_comment", postId },
        }, { checkSocialNotOff: true }).catch((err) => console.error("[NOTIFICATION] Error:", err));
      }

      return { comment };
    },

    /**
     * List paginated comments for a post.
     */
    async listComments(authContext, { postId, limit, cursor }) {
      // Verify post exists and is visible to user
      const post = await ootdRepo.getPostById(authContext, postId);
      if (!post) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
      }

      const effectiveLimit = Math.min(limit || 50, 100);
      return ootdRepo.listComments(authContext, postId, { limit: effectiveLimit, cursor });
    },

    /**
     * Delete a comment (soft delete). Caller must be comment author or post author.
     */
    async deleteComment(authContext, { postId, commentId }) {
      const comment = await ootdRepo.getCommentById(commentId);
      if (!comment) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Comment not found" };
      }

      const profileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!profileId) {
        throw { statusCode: 401, message: "Profile not found" };
      }

      // Check: caller is either comment author or post author
      const post = await ootdRepo.getPostById(authContext, postId);
      const isCommentAuthor = comment.author_id === profileId;
      const isPostAuthor = post && post.authorId === profileId;

      if (!isCommentAuthor && !isPostAuthor) {
        throw { statusCode: 403, code: "FORBIDDEN", message: "Only the comment author or post author can delete this comment" };
      }

      await ootdRepo.softDeleteComment(authContext, commentId);
    },

    // --- Steal This Look ---

    /**
     * Find matching items in user's wardrobe for a friend's OOTD post.
     * Story 9.5: "Steal This Look" Matcher (FR-SOC-12, FR-SOC-13)
     */
    async stealThisLook(authContext, { postId }) {
      // (a) Fetch the post
      const post = await ootdRepo.getPostById(authContext, postId);
      if (!post) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
      }

      // (b) Check tagged items
      if (!post.taggedItems || post.taggedItems.length === 0) {
        throw { statusCode: 400, code: "NO_TAGGED_ITEMS", message: "This post has no tagged items" };
      }

      // (c) Fetch tagged item details with full metadata
      const sourceItems = await ootdRepo.getPostItemsWithDetails(postId);

      // (d) Fetch user's wardrobe
      const wardrobeResult = await itemRepo.listItems(authContext, { limit: 1000 });
      const wardrobeItems = wardrobeResult.items ?? wardrobeResult;
      if (!wardrobeItems || wardrobeItems.length === 0) {
        throw { statusCode: 422, code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first to find matches." };
      }

      // (e) Build wardrobe representation
      const isLargeWardrobe = wardrobeItems.length > 50;
      let wardrobeSummary;
      let wardrobeIdMap;

      if (isLargeWardrobe) {
        wardrobeSummary = buildWardrobeSummary(wardrobeItems);
      } else {
        // Per-item mode: include IDs for direct matching
        wardrobeSummary = JSON.stringify(wardrobeItems.map(item => ({
          id: item.id,
          name: item.name ?? null,
          category: item.category ?? null,
          color: item.color ?? null,
          style: item.style ?? null,
          material: item.material ?? null,
          pattern: item.pattern ?? null,
          season: item.season ?? null,
          occasion: item.occasion ?? null,
        })));
      }

      // Build a lookup map for wardrobe items
      wardrobeIdMap = new Map(wardrobeItems.map(item => [item.id, item]));

      // (f) Construct Gemini prompt
      const sourceItemsJson = JSON.stringify(sourceItems.map(item => ({
        id: item.id,
        name: item.name,
        category: item.category,
        color: item.color,
        style: item.style,
        material: item.material,
        pattern: item.pattern,
      })));

      const promptTemplate = isLargeWardrobe ? STEAL_LOOK_PROMPT_SUMMARY : STEAL_LOOK_PROMPT;
      const prompt = promptTemplate
        .replace("{sourceItemsJson}", sourceItemsJson)
        .replace("{wardrobeSummary}", wardrobeSummary);

      const startTime = Date.now();

      try {
        // (g) Call Gemini
        const model = await geminiClient.getGenerativeModel(STEAL_LOOK_MODEL);
        const result = await model.generateContent({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: "application/json" },
        });

        const response = result.response;
        const latencyMs = Date.now() - startTime;
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        // (h) Parse and validate response
        const sourceItemIdSet = new Set(sourceItems.map(i => i.id));

        if (!Array.isArray(parsed.matches)) {
          throw new Error("Invalid response: matches is not an array");
        }

        const sourceMatches = [];
        for (const matchGroup of parsed.matches) {
          if (!sourceItemIdSet.has(matchGroup.sourceItemId)) continue;

          const sourceItem = sourceItems.find(i => i.id === matchGroup.sourceItemId);
          let validatedMatches = [];

          if (isLargeWardrobe) {
            // Distribution mode: resolve descriptive matches to actual items
            for (const match of (matchGroup.matchedItems || [])) {
              const score = Math.max(0, Math.min(100, Math.round(Number(match.matchScore) || 0)));
              if (score < 30) continue;

              // Find best matching item from wardrobe
              const candidates = wardrobeItems.filter(item => {
                if (match.category && item.category !== match.category) return false;
                return true;
              });

              // Sort by color match, then style match
              candidates.sort((a, b) => {
                const aColorMatch = a.color === match.color ? 1 : 0;
                const bColorMatch = b.color === match.color ? 1 : 0;
                if (aColorMatch !== bColorMatch) return bColorMatch - aColorMatch;
                const aStyleMatch = a.style === match.style ? 1 : 0;
                const bStyleMatch = b.style === match.style ? 1 : 0;
                return bStyleMatch - aStyleMatch;
              });

              const topCandidate = candidates[0];
              if (topCandidate) {
                // Avoid duplicates
                if (!validatedMatches.find(m => m.itemId === topCandidate.id)) {
                  validatedMatches.push({
                    itemId: topCandidate.id,
                    name: topCandidate.name ?? null,
                    category: topCandidate.category ?? null,
                    color: topCandidate.color ?? null,
                    photoUrl: topCandidate.photoUrl ?? topCandidate.photo_url ?? null,
                    matchScore: score,
                    matchReason: match.matchReason ?? null,
                  });
                }
              }
            }
          } else {
            // Per-item mode: validate IDs
            for (const match of (matchGroup.matchedItems || [])) {
              const score = Math.max(0, Math.min(100, Math.round(Number(match.matchScore) || 0)));
              if (score < 30) continue;
              if (!wardrobeIdMap.has(match.itemId)) continue;

              const wardrobeItem = wardrobeIdMap.get(match.itemId);
              validatedMatches.push({
                itemId: match.itemId,
                name: wardrobeItem.name ?? null,
                category: wardrobeItem.category ?? null,
                color: wardrobeItem.color ?? null,
                photoUrl: wardrobeItem.photoUrl ?? wardrobeItem.photo_url ?? null,
                matchScore: score,
                matchReason: match.matchReason ?? null,
              });
            }
          }

          // Sort by score descending and limit to 3
          validatedMatches.sort((a, b) => b.matchScore - a.matchScore);
          validatedMatches = validatedMatches.slice(0, 3);

          sourceMatches.push({
            sourceItem: {
              id: sourceItem.id,
              name: sourceItem.name ?? null,
              category: sourceItem.category ?? null,
              color: sourceItem.color ?? null,
              photoUrl: sourceItem.photoUrl ?? null,
            },
            matches: validatedMatches,
          });
        }

        // Ensure all source items are represented (even with no matches)
        for (const sourceItem of sourceItems) {
          if (!sourceMatches.find(sm => sm.sourceItem.id === sourceItem.id)) {
            sourceMatches.push({
              sourceItem: {
                id: sourceItem.id,
                name: sourceItem.name ?? null,
                category: sourceItem.category ?? null,
                color: sourceItem.color ?? null,
                photoUrl: sourceItem.photoUrl ?? null,
              },
              matches: [],
            });
          }
        }

        // (i) Log AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "steal_look",
            model: STEAL_LOOK_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success",
          });
        } catch (logErr) {
          console.error("[steal-look] Failed to log AI usage:", logErr.message);
        }

        // (j) Return result
        return { sourceMatches };
      } catch (err) {
        const latencyMs = Date.now() - startTime;

        // Log failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "steal_look",
            model: STEAL_LOOK_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: err.message,
          });
        } catch (logErr) {
          console.error("[steal-look] Failed to log AI usage failure:", logErr.message);
        }

        // Re-throw if it's already a structured error
        if (err.statusCode) throw err;

        throw {
          statusCode: 502,
          code: "MATCHING_FAILED",
          message: "Unable to find matches. Please try again.",
        };
      }
    },
  };
}
