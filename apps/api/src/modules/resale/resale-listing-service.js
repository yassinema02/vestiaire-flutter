/**
 * Resale listing generation service using Gemini 2.0 Flash via Vertex AI.
 *
 * Analyzes item metadata and image to generate an optimized resale listing
 * for platforms like Vinted and Depop. Validates output, persists to
 * resale_listings table, updates item resale_status, and logs AI usage.
 *
 * Story 7.3: AI Resale Listing Generation (FR-RSL-02, FR-RSL-03)
 */

import fs from "node:fs";

const RESALE_MODEL = "gemini-2.0-flash";

const VALID_CONDITIONS = ["New", "Like New", "Good", "Fair"];

/**
 * Read image data from a URL or local file path.
 */
async function readImageData(imageUrl) {
  if (imageUrl.startsWith("/") || imageUrl.startsWith("file://")) {
    const filePath = imageUrl.replace("file://", "");
    return fs.readFileSync(filePath);
  }

  if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://")) {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Failed to download image: ${response.status} ${response.statusText}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  throw new Error(`Unsupported image URL format: ${imageUrl}`);
}

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
 * Build the Gemini prompt for resale listing generation.
 */
function buildPrompt(item, extraData) {
  const wearCount = extraData.wear_count ?? 0;
  const daysSinceLastWorn = extraData.last_worn_date
    ? Math.floor((Date.now() - new Date(extraData.last_worn_date).getTime()) / (1000 * 60 * 60 * 24))
    : "N/A";

  return `You are a resale listing copywriter specializing in Vinted and Depop. Generate an optimized listing for this clothing item.

ITEM METADATA:
- Category: ${item.category ?? "Unknown"}
- Primary Color: ${item.color ?? "Unknown"}
- Secondary Colors: ${item.secondaryColors?.join(", ") ?? "None"}
- Pattern: ${item.pattern ?? "Unknown"}
- Material: ${item.material ?? "Unknown"}
- Style: ${item.style ?? "Unknown"}
- Brand: ${item.brand || "Unbranded"}
- Season: ${item.season?.join(", ") ?? "Unknown"}
- Occasion: ${item.occasion?.join(", ") ?? "Unknown"}
- Purchase Price: ${extraData.purchase_price ?? "Unknown"} ${extraData.currency ?? ""}
- Times Worn: ${wearCount}
- Days Since Last Worn: ${daysSinceLastWorn}

RULES:
1. Title: Catchy, SEO-friendly, max 80 chars. Include brand if known, category, and a selling point.
2. Description: 3-5 sentences. Highlight condition, material quality, versatility, and styling tips. Be honest but positive.
3. Condition Estimate: Based on wear count and age. "New" (0 wears), "Like New" (1-5 wears), "Good" (6-20 wears), "Fair" (20+ wears).
4. Hashtags: 5-10 relevant hashtags (without # prefix) for Vinted/Depop SEO. Include brand, category, style, color, and trending fashion tags.

Analyze the item image for additional details about condition, quality, and visual appeal.

Return ONLY valid JSON:
{
  "title": "Catchy listing title",
  "description": "Detailed listing description...",
  "conditionEstimate": "one of: New, Like New, Good, Fair",
  "hashtags": ["hashtag1", "hashtag2"],
  "platform": "general"
}`;
}

/**
 * Validate and sanitize the parsed Gemini response.
 */
export function validateListingResponse(parsed) {
  let title = typeof parsed.title === "string" && parsed.title.trim() ? parsed.title.trim() : "Untitled Listing";
  if (title.length > 80) {
    title = title.substring(0, 80);
  }

  const description = typeof parsed.description === "string" && parsed.description.trim()
    ? parsed.description.trim()
    : "No description available.";

  const conditionEstimate = VALID_CONDITIONS.includes(parsed.conditionEstimate)
    ? parsed.conditionEstimate
    : "Good";

  let hashtags = [];
  if (Array.isArray(parsed.hashtags)) {
    hashtags = parsed.hashtags
      .filter((h) => typeof h === "string" && h.trim())
      .map((h) => h.trim())
      .slice(0, 10);
  }

  const platform = typeof parsed.platform === "string" && parsed.platform.trim()
    ? parsed.platform.trim()
    : "general";

  return { title, description, conditionEstimate, hashtags, platform };
}

/**
 * @param {object} options
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.itemRepo - Item repository with getItem and updateItem methods.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createResaleListingService({
  geminiClient,
  itemRepo,
  aiUsageLogRepo,
  pool
}) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Generate a resale listing for an item using Gemini vision analysis.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.itemId - The item's UUID.
     * @returns {Promise<object>} The generated listing with item metadata.
     */
    async generateListing(authContext, { itemId }) {
      // (a) Check Gemini availability
      if (!geminiClient.isAvailable()) {
        throw {
          statusCode: 503,
          message: "AI service unavailable"
        };
      }

      const startTime = Date.now();

      try {
        // (b) Fetch the item (ownership check via authContext)
        const item = await itemRepo.getItem(authContext, itemId);
        if (!item) {
          throw {
            statusCode: 404,
            message: "Item not found or not owned by user"
          };
        }

        // (c) Fetch additional item data for the prompt
        const client = await pool.connect();
        let extraData;
        let profileId;
        try {
          await client.query(
            "select set_config('app.current_user_id', $1, true)",
            [authContext.userId]
          );

          const extraResult = await client.query(
            "SELECT wear_count, last_worn_date, purchase_price, currency FROM app_public.items WHERE id = $1",
            [itemId]
          );
          extraData = extraResult.rows[0] ?? {};

          const profileResult = await client.query(
            "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
            [authContext.userId]
          );
          if (profileResult.rows.length === 0) {
            throw { statusCode: 401, message: "Profile not found" };
          }
          profileId = profileResult.rows[0].id;
        } finally {
          client.release();
        }

        // (d) Build the Gemini prompt
        const prompt = buildPrompt(item, extraData);

        // (e) Download and encode image
        const imageUrl = item.photoUrl || item.originalPhotoUrl;
        const imageData = await readImageData(imageUrl);

        // (f) Call Gemini 2.0 Flash with JSON mode
        const model = await geminiClient.getGenerativeModel(RESALE_MODEL);
        const result = await model.generateContent({
          contents: [
            {
              role: "user",
              parts: [
                {
                  inlineData: {
                    mimeType: "image/jpeg",
                    data: imageData.toString("base64")
                  }
                },
                { text: prompt }
              ]
            }
          ],
          generationConfig: { responseMimeType: "application/json" }
        });

        const response = result.response;
        const latencyMs = Date.now() - startTime;

        // (g) Parse and validate JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        let parsed;
        try {
          parsed = JSON.parse(rawText);
        } catch (parseError) {
          throw new Error("Failed to parse Gemini response as JSON");
        }

        const validated = validateListingResponse(parsed);

        // (h) Persist listing to resale_listings table
        const persistClient = await pool.connect();
        let listingId;
        try {
          await persistClient.query("begin");
          await persistClient.query(
            "select set_config('app.current_user_id', $1, true)",
            [authContext.userId]
          );

          const insertResult = await persistClient.query(
            `INSERT INTO app_public.resale_listings
               (profile_id, item_id, title, description, condition_estimate, hashtags, platform)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING id, created_at`,
            [profileId, itemId, validated.title, validated.description, validated.conditionEstimate, validated.hashtags, validated.platform]
          );
          listingId = insertResult.rows[0].id;
          const createdAt = insertResult.rows[0].created_at;

          // (i) Update item resale_status to 'listed' if currently NULL
          await persistClient.query(
            `UPDATE app_public.items SET resale_status = 'listed', updated_at = NOW()
             WHERE id = $1 AND resale_status IS NULL`,
            [itemId]
          );

          await persistClient.query("commit");

          validated.id = listingId;
          validated.generatedAt = createdAt?.toISOString?.() ?? createdAt ?? new Date().toISOString();
        } catch (persistError) {
          await persistClient.query("rollback");
          throw persistError;
        } finally {
          persistClient.release();
        }

        // (j) Log AI usage - success
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "resale_listing",
            model: RESALE_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success"
          });
        } catch (logError) {
          console.error("[resale-listing] Failed to log AI usage:", logError.message);
        }

        // Return listing + item metadata
        return {
          listing: {
            id: validated.id,
            title: validated.title,
            description: validated.description,
            conditionEstimate: validated.conditionEstimate,
            hashtags: validated.hashtags,
            platform: validated.platform
          },
          item: {
            id: item.id,
            name: item.name,
            category: item.category,
            brand: item.brand,
            photoUrl: item.photoUrl
          },
          generatedAt: validated.generatedAt
        };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        // Log failure to ai_usage_log
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "resale_listing",
            model: RESALE_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message
          });
        } catch (logError) {
          console.error("[resale-listing] Failed to log AI usage failure:", logError.message);
        }

        // Re-throw known errors (statusCode already set)
        if (error.statusCode) {
          throw error;
        }

        // Wrap unknown errors
        console.error("[resale-listing] Failed:", error.message);
        throw {
          statusCode: 500,
          message: "Resale listing generation failed"
        };
      }
    }
  };
}
