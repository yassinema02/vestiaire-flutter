import assert from "node:assert/strict";
import { Readable } from "node:stream";
import test from "node:test";
import { handleRequest } from "../../../src/main.js";

function createResponseCapture() {
  return {
    statusCode: undefined,
    body: undefined,
    writeHead(statusCode) {
      this.statusCode = statusCode;
    },
    end(body) {
      if (body) this.body = JSON.parse(body);
    },
  };
}

function createJsonRequest(method, url, body, headers = {}) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json",
    ...headers,
  };
  return stream;
}

function buildContext({
  authenticated = true,
  shouldFail = false,
  failError = null,
  createResult = null,
  feedResult = null,
  squadPostsResult = null,
  getResult = null,
  toggleReactionResult = null,
  createCommentResult = null,
  listCommentsResult = null,
  deleteCommentFail = false,
} = {}) {
  const defaultPost = {
    id: "post-1",
    authorId: "profile-1",
    photoUrl: "https://storage.example.com/photo.jpg",
    caption: "My outfit",
    createdAt: "2026-03-19T00:00:00.000Z",
    authorDisplayName: "Test User",
    authorPhotoUrl: null,
    taggedItems: [],
    squadIds: ["squad-1"],
    reactionCount: 0,
    commentCount: 0,
    hasReacted: false,
  };

  return {
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate(req) {
        if (!authenticated) {
          const { AuthenticationError } = await import(
            "../../../src/modules/auth/service.js"
          );
          throw new AuthenticationError("Unauthorized");
        }
        return {
          userId: "firebase-user-123",
          email: "user@example.com",
          emailVerified: true,
          provider: "google.com",
        };
      },
    },
    profileService: {},
    itemService: {
      async createItemForUser() { return { item: { id: "item-1" } }; },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(_, id) { return { item: { id } }; },
      async updateItemForUser() { return { item: {} }; },
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {},
    outfitRepository: { async listOutfits() { return []; } },
    usageLimitService: {},
    wearLogRepository: {},
    analyticsRepository: {},
    analyticsSummaryService: {},
    userStatsRepo: { async getUserStats() { return {}; } },
    stylePointsService: {},
    levelService: {},
    streakService: {},
    badgeRepo: {},
    badgeService: {},
    challengeRepo: {},
    challengeService: {},
    subscriptionSyncService: {},
    premiumGuard: {},
    resaleListingService: {},
    resaleHistoryRepo: {},
    shoppingScanService: {},
    shoppingScanRepo: {},
    squadService: {
      async createSquad() { return { squad: {} }; },
      async joinSquad() { return { squad: {} }; },
      async listMySquads() { return { squads: [] }; },
      async getSquad() { return { squad: {} }; },
      async listMembers() { return { members: [] }; },
      async leaveSquad() { return { success: true }; },
      async removeMember() { return { success: true }; },
    },
    ootdService: {
      async createPost(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 400, code: "BAD_REQUEST", message: "Bad input" };
        return createResult ?? { post: { ...defaultPost, photoUrl: data.photoUrl, caption: data.caption } };
      },
      async listFeedPosts(authContext, opts) {
        if (shouldFail) throw failError || { statusCode: 500, message: "Error" };
        return feedResult ?? { posts: [], nextCursor: null };
      },
      async listSquadPosts(authContext, opts) {
        if (shouldFail) throw failError || { statusCode: 403, code: "FORBIDDEN", message: "Not a member" };
        return squadPostsResult ?? { posts: [], nextCursor: null };
      },
      async getPost(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
        return getResult ?? { post: defaultPost };
      },
      async deletePost(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 403, code: "FORBIDDEN", message: "Not author" };
      },
      async toggleReaction(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
        return toggleReactionResult ?? { reacted: true, reactionCount: 1 };
      },
      async createComment(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 400, code: "BAD_REQUEST", message: "Bad input" };
        return createCommentResult ?? {
          comment: {
            id: "comment-1",
            postId: data.postId,
            authorId: "profile-1",
            text: data.text,
            createdAt: "2026-03-19T00:00:00.000Z",
            authorDisplayName: "Test User",
            authorPhotoUrl: null,
          },
        };
      },
      async listComments(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
        return listCommentsResult ?? { comments: [], nextCursor: null };
      },
      async deleteComment(authContext, data) {
        if (shouldFail || deleteCommentFail) throw failError || { statusCode: 403, code: "FORBIDDEN", message: "Not authorized" };
      },
    },
  };
}

// POST /v1/squads/posts
test("POST /v1/squads/posts returns 201 with created post", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts", {
    photoUrl: "https://storage.example.com/photo.jpg",
    caption: "My outfit",
    squadIds: ["squad-1"],
    taggedItemIds: [],
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.post);
});

test("POST /v1/squads/posts returns 400 for missing photoUrl", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts", {
    photoUrl: "",
    squadIds: ["squad-1"],
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 400, code: "BAD_REQUEST", message: "photoUrl is required" },
  }));

  assert.equal(res.statusCode, 400);
});

test("POST /v1/squads/posts returns 400 for missing squadIds", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts", {
    photoUrl: "https://example.com/photo.jpg",
    squadIds: [],
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 400, code: "BAD_REQUEST", message: "squadIds must be a non-empty array" },
  }));

  assert.equal(res.statusCode, 400);
});

test("POST /v1/squads/posts returns 403 for non-member squad", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts", {
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["non-member-squad"],
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 403, code: "FORBIDDEN", message: "Not a member" },
  }));

  assert.equal(res.statusCode, 403);
});

test("POST /v1/squads/posts returns 401 without auth", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts", {
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["squad-1"],
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

// GET /v1/squads/posts/feed
test("GET /v1/squads/posts/feed returns 200 with paginated posts", async () => {
  const req = createJsonRequest("GET", "/v1/squads/posts/feed", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    feedResult: { posts: [{ id: "p1" }], nextCursor: null },
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.posts));
});

// GET /v1/squads/:id/posts
test("GET /v1/squads/:id/posts returns 200 with squad-filtered posts", async () => {
  const req = createJsonRequest("GET", "/v1/squads/squad-1/posts", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    squadPostsResult: { posts: [{ id: "p1" }], nextCursor: null },
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.posts));
});

test("GET /v1/squads/:id/posts returns 403 for non-member", async () => {
  const req = createJsonRequest("GET", "/v1/squads/squad-1/posts", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 403, code: "FORBIDDEN", message: "Not a member" },
  }));

  assert.equal(res.statusCode, 403);
});

// GET /v1/squads/posts/:postId
test("GET /v1/squads/posts/:postId returns 200 with post detail", async () => {
  const req = createJsonRequest("GET", "/v1/squads/posts/post-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.post);
});

test("GET /v1/squads/posts/:postId returns 404 for non-existent post", async () => {
  const req = createJsonRequest("GET", "/v1/squads/posts/nonexistent", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 404, code: "NOT_FOUND", message: "Post not found" },
  }));

  assert.equal(res.statusCode, 404);
});

// DELETE /v1/squads/posts/:postId
test("DELETE /v1/squads/posts/:postId returns 204 for author", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 204);
});

test("DELETE /v1/squads/posts/:postId returns 403 for non-author", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 403, code: "FORBIDDEN", message: "Not author" },
  }));

  assert.equal(res.statusCode, 403);
});

test("DELETE /v1/squads/posts/:postId returns 401 without auth", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1");
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

// --- POST /v1/squads/posts/:postId/reactions ---

test("POST /v1/squads/posts/:postId/reactions returns 200 with reacted: true on first call", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/reactions", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    toggleReactionResult: { reacted: true, reactionCount: 1 },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.reacted, true);
  assert.equal(res.body.reactionCount, 1);
});

test("POST /v1/squads/posts/:postId/reactions returns 200 with reacted: false on toggle off", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/reactions", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    toggleReactionResult: { reacted: false, reactionCount: 0 },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.reacted, false);
});

test("POST /v1/squads/posts/:postId/reactions returns 401 without auth", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/reactions");
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/squads/posts/:postId/reactions returns 404 for invalid post", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/nonexistent/reactions", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 404, code: "NOT_FOUND", message: "Post not found" },
  }));

  assert.equal(res.statusCode, 404);
});

// --- POST /v1/squads/posts/:postId/comments ---

test("POST /v1/squads/posts/:postId/comments returns 201 with created comment", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/comments", {
    text: "Great outfit!",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.comment);
});

test("POST /v1/squads/posts/:postId/comments returns 400 for empty text", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/comments", {
    text: "",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 400, code: "BAD_REQUEST", message: "Comment text is required" },
  }));

  assert.equal(res.statusCode, 400);
});

test("POST /v1/squads/posts/:postId/comments returns 400 for text > 200 chars", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/comments", {
    text: "A".repeat(201),
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 400, code: "BAD_REQUEST", message: "Comment text must be at most 200 characters" },
  }));

  assert.equal(res.statusCode, 400);
});

test("POST /v1/squads/posts/:postId/comments returns 401 without auth", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/comments", {
    text: "Hello",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

// --- GET /v1/squads/posts/:postId/comments ---

test("GET /v1/squads/posts/:postId/comments returns 200 with paginated comments", async () => {
  const req = createJsonRequest("GET", "/v1/squads/posts/post-1/comments", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    listCommentsResult: {
      comments: [{ id: "c1", text: "Nice!" }],
      nextCursor: null,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.comments));
});

// --- DELETE /v1/squads/posts/:postId/comments/:commentId ---

test("DELETE /v1/squads/posts/:postId/comments/:commentId returns 204 for comment author", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1/comments/comment-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 204);
});

test("DELETE /v1/squads/posts/:postId/comments/:commentId returns 204 for post author", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1/comments/comment-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 204);
});

test("DELETE /v1/squads/posts/:postId/comments/:commentId returns 403 for non-author", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1/comments/comment-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 403, code: "FORBIDDEN", message: "Not authorized" },
  }));

  assert.equal(res.statusCode, 403);
});

test("DELETE /v1/squads/posts/:postId/comments/:commentId returns 401 without auth", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/posts/post-1/comments/comment-1");
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

// --- Feed includes correct counts ---

test("GET /v1/squads/posts/feed includes correct reactionCount, commentCount, hasReacted fields", async () => {
  const req = createJsonRequest("GET", "/v1/squads/posts/feed", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    feedResult: {
      posts: [{
        id: "p1",
        reactionCount: 3,
        commentCount: 5,
        hasReacted: true,
      }],
      nextCursor: null,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.posts[0].reactionCount, 3);
  assert.equal(res.body.posts[0].commentCount, 5);
  assert.equal(res.body.posts[0].hasReacted, true);
});

// --- POST /v1/squads/posts/:postId/steal-look (Story 9.5) ---

test("POST /v1/squads/posts/:postId/steal-look returns 200 with match data on success", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/steal-look", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  const stealLookResult = {
    sourceMatches: [
      {
        sourceItem: { id: "item-a", name: "Blue Top", category: "tops" },
        matches: [{ itemId: "w1", matchScore: 85, matchReason: "Similar" }],
      },
    ],
  };

  const ctx = buildContext();
  ctx.ootdService.stealThisLook = async () => stealLookResult;
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.sourceMatches);
  assert.equal(res.body.sourceMatches.length, 1);
});

test("POST /v1/squads/posts/:postId/steal-look returns 404 for non-existent post", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/nonexistent/steal-look", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  const ctx = buildContext();
  ctx.ootdService.stealThisLook = async () => {
    throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
  };
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 404);
});

test("POST /v1/squads/posts/:postId/steal-look returns 400 for post with no tagged items", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/steal-look", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  const ctx = buildContext();
  ctx.ootdService.stealThisLook = async () => {
    throw { statusCode: 400, code: "NO_TAGGED_ITEMS", message: "No tagged items" };
  };
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, "NO_TAGGED_ITEMS");
});

test("POST /v1/squads/posts/:postId/steal-look returns 422 when wardrobe is empty", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/steal-look", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  const ctx = buildContext();
  ctx.ootdService.stealThisLook = async () => {
    throw { statusCode: 422, code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first" };
  };
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "WARDROBE_EMPTY");
});

test("POST /v1/squads/posts/:postId/steal-look returns 502 when Gemini fails", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/steal-look", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  const ctx = buildContext();
  ctx.ootdService.stealThisLook = async () => {
    throw { statusCode: 502, code: "MATCHING_FAILED", message: "Unable to find matches" };
  };
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 502);
  assert.equal(res.body.code, "MATCHING_FAILED");
});

test("POST /v1/squads/posts/:postId/steal-look returns 401 without authentication", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/post-1/steal-look");
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/squads/posts/:postId/steal-look returns 404 for post in non-member squad (RLS)", async () => {
  const req = createJsonRequest("POST", "/v1/squads/posts/hidden-post/steal-look", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  const ctx = buildContext();
  ctx.ootdService.stealThisLook = async () => {
    throw { statusCode: 404, code: "NOT_FOUND", message: "Post not found" };
  };
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 404);
});
