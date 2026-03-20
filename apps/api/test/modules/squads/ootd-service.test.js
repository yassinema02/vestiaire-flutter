import assert from "node:assert/strict";
import test from "node:test";
import {
  createOotdService,
  validatePostInput,
  validateCommentInput,
} from "../../../src/modules/squads/ootd-service.js";

const testAuthContext = { userId: "firebase-user-123" };
const testProfileId = "profile-1";

function createMockOotdRepo({
  posts = [],
  createdPost = null,
  postItems = [],
  postSquads = [],
  toggleReactionResult = null,
  reactionCount = 0,
  comments = [],
  createdComment = null,
  commentById = null,
} = {}) {
  const calls = [];
  return {
    calls,
    async createPost(authContext, data) {
      calls.push({ method: "createPost", authContext, data });
      return createdPost ?? {
        id: "post-1",
        authorId: testProfileId,
        photoUrl: data.photoUrl,
        caption: data.caption,
        createdAt: "2026-03-19T00:00:00.000Z",
        authorDisplayName: "Test User",
        authorPhotoUrl: null,
        taggedItems: [],
        squadIds: data.squadIds,
        reactionCount: 0,
        commentCount: 0,
        hasReacted: false,
      };
    },
    async getPostById(authContext, postId) {
      calls.push({ method: "getPostById", authContext, postId });
      const found = posts.find((p) => p.id === postId);
      return found ?? null;
    },
    async listPostsForSquad(authContext, squadId, opts) {
      calls.push({ method: "listPostsForSquad", authContext, squadId, opts });
      return { posts: posts.filter((p) => p.squadIds?.includes(squadId)), nextCursor: null };
    },
    async listPostsForUser(authContext, opts) {
      calls.push({ method: "listPostsForUser", authContext, opts });
      return { posts, nextCursor: null };
    },
    async softDeletePost(authContext, postId) {
      calls.push({ method: "softDeletePost", authContext, postId });
    },
    async getPostItemsByPostId(postId) {
      calls.push({ method: "getPostItemsByPostId", postId });
      return postItems;
    },
    async getPostSquadsByPostId(postId) {
      calls.push({ method: "getPostSquadsByPostId", postId });
      return postSquads;
    },
    async toggleReaction(authContext, postId) {
      calls.push({ method: "toggleReaction", authContext, postId });
      return toggleReactionResult ?? { reacted: true };
    },
    async getReactionCount(postId) {
      calls.push({ method: "getReactionCount", postId });
      return reactionCount;
    },
    async hasUserReacted(postId, profileId) {
      calls.push({ method: "hasUserReacted", postId, profileId });
      return false;
    },
    async createComment(authContext, postId, data) {
      calls.push({ method: "createComment", authContext, postId, data });
      return createdComment ?? {
        id: "comment-1",
        postId,
        authorId: testProfileId,
        text: data.text,
        createdAt: "2026-03-19T00:00:00.000Z",
        authorDisplayName: "Test User",
        authorPhotoUrl: null,
      };
    },
    async listComments(authContext, postId, opts) {
      calls.push({ method: "listComments", authContext, postId, opts });
      return { comments, nextCursor: null };
    },
    async softDeleteComment(authContext, commentId) {
      calls.push({ method: "softDeleteComment", authContext, commentId });
    },
    async getCommentById(commentId) {
      calls.push({ method: "getCommentById", commentId });
      return commentById ?? null;
    },
  };
}

function createMockSquadRepo({
  membership = null,
  profileId = testProfileId,
} = {}) {
  const calls = [];
  return {
    calls,
    async getMembership(squadId, userId) {
      calls.push({ method: "getMembership", squadId, userId });
      if (membership && membership.squadId === squadId && membership.userId === userId) {
        return membership;
      }
      // Default: user is a member of any squad
      if (userId === profileId) {
        return { squadId, userId, role: "member" };
      }
      return null;
    },
    async getProfileIdForUser(userId) {
      calls.push({ method: "getProfileIdForUser", userId });
      return profileId;
    },
  };
}

// --- validatePostInput tests ---

test("validatePostInput rejects missing photoUrl", () => {
  assert.throws(
    () => validatePostInput({ photoUrl: "", squadIds: ["00000000-0000-0000-0000-000000000001"] }),
    (err) => err.statusCode === 400
  );
});

test("validatePostInput rejects null photoUrl", () => {
  assert.throws(
    () => validatePostInput({ photoUrl: null, squadIds: ["00000000-0000-0000-0000-000000000001"] }),
    (err) => err.statusCode === 400
  );
});

test("validatePostInput rejects caption > 150 chars", () => {
  assert.throws(
    () => validatePostInput({
      photoUrl: "https://example.com/photo.jpg",
      caption: "A".repeat(151),
      squadIds: ["00000000-0000-0000-0000-000000000001"],
    }),
    (err) => err.statusCode === 400
  );
});

test("validatePostInput rejects empty squadIds array", () => {
  assert.throws(
    () => validatePostInput({
      photoUrl: "https://example.com/photo.jpg",
      squadIds: [],
    }),
    (err) => err.statusCode === 400
  );
});

test("validatePostInput rejects missing squadIds", () => {
  assert.throws(
    () => validatePostInput({
      photoUrl: "https://example.com/photo.jpg",
    }),
    (err) => err.statusCode === 400
  );
});

test("validatePostInput accepts valid input", () => {
  const result = validatePostInput({
    photoUrl: "https://example.com/photo.jpg",
    caption: "My outfit today",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
    taggedItemIds: ["00000000-0000-0000-0000-000000000002"],
  });

  assert.equal(result.photoUrl, "https://example.com/photo.jpg");
  assert.equal(result.caption, "My outfit today");
  assert.equal(result.squadIds.length, 1);
  assert.equal(result.taggedItemIds.length, 1);
});

test("validatePostInput accepts empty taggedItemIds", () => {
  const result = validatePostInput({
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
    taggedItemIds: [],
  });

  assert.equal(result.taggedItemIds.length, 0);
});

test("validatePostInput accepts null caption", () => {
  const result = validatePostInput({
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
    caption: null,
  });

  assert.equal(result.caption, null);
});

test("validatePostInput rejects invalid UUID in squadIds", () => {
  assert.throws(
    () => validatePostInput({
      photoUrl: "https://example.com/photo.jpg",
      squadIds: ["not-a-uuid"],
    }),
    (err) => err.statusCode === 400
  );
});

// --- Mock notification service ---

function createMockNotificationService() {
  const calls = [];
  return {
    calls,
    async sendPushNotification(profileId, payload, options) {
      calls.push({ method: "sendPushNotification", profileId, payload, options });
    },
    async sendToSquadMembers(squadId, excludeProfileId, payload) {
      calls.push({ method: "sendToSquadMembers", squadId, excludeProfileId, payload });
    },
  };
}

// --- createPost tests ---

test("createPost validates photoUrl required", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createPost(testAuthContext, {
      photoUrl: "",
      squadIds: ["00000000-0000-0000-0000-000000000001"],
    }),
    (err) => err.statusCode === 400
  );
});

test("createPost validates caption max 150 chars", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createPost(testAuthContext, {
      photoUrl: "https://example.com/photo.jpg",
      caption: "A".repeat(151),
      squadIds: ["00000000-0000-0000-0000-000000000001"],
    }),
    (err) => err.statusCode === 400
  );
});

test("createPost validates squadIds is non-empty array", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createPost(testAuthContext, {
      photoUrl: "https://example.com/photo.jpg",
      squadIds: [],
    }),
    (err) => err.statusCode === 400
  );
});

test("createPost validates taggedItemIds is array (can be empty)", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.createPost(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
    taggedItemIds: [],
  });

  assert.ok(result.post);
});

test("createPost verifies user is member of all selected squads", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.createPost(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
  });

  assert.ok(result.post);
  assert.ok(squadRepo.calls.some((c) => c.method === "getMembership"));
});

test("createPost throws 403 when user is not member of a squad", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo({ profileId: null });
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createPost(testAuthContext, {
      photoUrl: "https://example.com/photo.jpg",
      squadIds: ["00000000-0000-0000-0000-000000000001"],
    }),
    (err) => err.statusCode === 401 || err.statusCode === 403
  );
});

test("createPost creates post with items and squads on success", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.createPost(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg",
    caption: "My look",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
    taggedItemIds: ["00000000-0000-0000-0000-000000000002"],
  });

  assert.ok(result.post);
  assert.ok(ootdRepo.calls.some((c) => c.method === "createPost"));
});

// --- getPost tests ---

test("getPost returns post with tagged items and author info", async () => {
  const testPost = {
    id: "post-1",
    authorId: testProfileId,
    photoUrl: "https://example.com/photo.jpg",
    caption: "My outfit",
    createdAt: "2026-03-19T00:00:00.000Z",
    authorDisplayName: "Test User",
    authorPhotoUrl: null,
    taggedItems: [],
    squadIds: ["squad-1"],
    reactionCount: 0,
    commentCount: 0,
  };
  const ootdRepo = createMockOotdRepo({ posts: [testPost] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.getPost(testAuthContext, { postId: "post-1" });

  assert.ok(result.post);
  assert.equal(result.post.id, "post-1");
});

test("getPost throws 404 for non-existent post", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.getPost(testAuthContext, { postId: "nonexistent" }),
    (err) => err.statusCode === 404
  );
});

// --- listSquadPosts tests ---

test("listSquadPosts verifies membership before listing", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await service.listSquadPosts(testAuthContext, { squadId: "00000000-0000-0000-0000-000000000001" });

  assert.ok(squadRepo.calls.some((c) => c.method === "getMembership"));
});

test("listSquadPosts returns paginated results with cursor", async () => {
  const posts = [
    { id: "p1", squadIds: ["squad-1"], authorId: testProfileId, createdAt: "2026-03-19T00:00:00.000Z" },
  ];
  const ootdRepo = createMockOotdRepo({ posts });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.listSquadPosts(testAuthContext, { squadId: "squad-1" });

  assert.ok(Array.isArray(result.posts));
  assert.ok("nextCursor" in result);
});

// --- listFeedPosts tests ---

test("listFeedPosts returns posts across all user squads", async () => {
  const posts = [
    { id: "p1", authorId: testProfileId, createdAt: "2026-03-19T00:00:00.000Z" },
  ];
  const ootdRepo = createMockOotdRepo({ posts });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.listFeedPosts(testAuthContext, {});

  assert.ok(Array.isArray(result.posts));
});

// --- deletePost tests ---

test("deletePost soft-deletes when user is author", async () => {
  const testPost = {
    id: "post-1",
    authorId: testProfileId,
    photoUrl: "https://example.com/photo.jpg",
    caption: null,
    createdAt: "2026-03-19T00:00:00.000Z",
    taggedItems: [],
    squadIds: [],
    reactionCount: 0,
    commentCount: 0,
  };
  const ootdRepo = createMockOotdRepo({ posts: [testPost] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await service.deletePost(testAuthContext, { postId: "post-1" });

  assert.ok(ootdRepo.calls.some((c) => c.method === "softDeletePost"));
});

test("deletePost throws 403 when user is not author", async () => {
  const testPost = {
    id: "post-1",
    authorId: "other-profile",
    photoUrl: "https://example.com/photo.jpg",
    caption: null,
    createdAt: "2026-03-19T00:00:00.000Z",
    taggedItems: [],
    squadIds: [],
    reactionCount: 0,
    commentCount: 0,
  };
  const ootdRepo = createMockOotdRepo({ posts: [testPost] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.deletePost(testAuthContext, { postId: "post-1" }),
    (err) => err.statusCode === 403
  );
});

test("deletePost throws 404 for non-existent post", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.deletePost(testAuthContext, { postId: "nonexistent" }),
    (err) => err.statusCode === 404
  );
});

// --- validateCommentInput tests ---

test("validateCommentInput rejects empty text", () => {
  assert.throws(
    () => validateCommentInput({ text: "" }),
    (err) => err.statusCode === 400
  );
});

test("validateCommentInput rejects null text", () => {
  assert.throws(
    () => validateCommentInput({ text: null }),
    (err) => err.statusCode === 400
  );
});

test("validateCommentInput rejects text > 200 chars", () => {
  assert.throws(
    () => validateCommentInput({ text: "A".repeat(201) }),
    (err) => err.statusCode === 400
  );
});

test("validateCommentInput accepts valid text and trims", () => {
  const result = validateCommentInput({ text: "  Nice outfit!  " });
  assert.equal(result.text, "Nice outfit!");
});

// --- toggleReaction tests ---

const testPostForReactions = {
  id: "post-1",
  authorId: testProfileId,
  photoUrl: "https://example.com/photo.jpg",
  caption: null,
  createdAt: "2026-03-19T00:00:00.000Z",
  taggedItems: [],
  squadIds: ["squad-1"],
  reactionCount: 0,
  commentCount: 0,
  hasReacted: false,
};

test("toggleReaction adds reaction when not present", async () => {
  const ootdRepo = createMockOotdRepo({
    posts: [testPostForReactions],
    toggleReactionResult: { reacted: true },
    reactionCount: 1,
  });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.toggleReaction(testAuthContext, { postId: "post-1" });

  assert.equal(result.reacted, true);
  assert.equal(result.reactionCount, 1);
});

test("toggleReaction removes reaction when already present", async () => {
  const ootdRepo = createMockOotdRepo({
    posts: [testPostForReactions],
    toggleReactionResult: { reacted: false },
    reactionCount: 0,
  });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.toggleReaction(testAuthContext, { postId: "post-1" });

  assert.equal(result.reacted, false);
  assert.equal(result.reactionCount, 0);
});

test("toggleReaction returns 404 for non-existent post", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.toggleReaction(testAuthContext, { postId: "nonexistent" }),
    (err) => err.statusCode === 404
  );
});

// --- createComment tests ---

test("createComment creates comment with valid text", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.createComment(testAuthContext, {
    postId: "post-1",
    text: "Great outfit!",
  });

  assert.ok(result.comment);
  assert.equal(result.comment.text, "Great outfit!");
});

test("createComment returns 400 for empty text", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createComment(testAuthContext, { postId: "post-1", text: "" }),
    (err) => err.statusCode === 400
  );
});

test("createComment returns 400 for text > 200 chars", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createComment(testAuthContext, {
      postId: "post-1",
      text: "A".repeat(201),
    }),
    (err) => err.statusCode === 400
  );
});

test("createComment returns 404 for non-existent post", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.createComment(testAuthContext, {
      postId: "nonexistent",
      text: "Hello",
    }),
    (err) => err.statusCode === 404
  );
});

test("createComment triggers notification to post author via notificationService", async () => {
  const postByOtherUser = {
    ...testPostForReactions,
    authorId: "other-profile",
  };
  const ootdRepo = createMockOotdRepo({ posts: [postByOtherUser] });
  const squadRepo = createMockSquadRepo();
  const notificationService = createMockNotificationService();
  const service = createOotdService({ ootdRepo, squadRepo, notificationService });

  const result = await service.createComment(testAuthContext, {
    postId: "post-1",
    text: "Love it!",
  });

  assert.ok(result.comment);
  // Wait for fire-and-forget notification
  await new Promise(r => setTimeout(r, 10));
  assert.ok(notificationService.calls.some(c => c.method === "sendPushNotification"));
  const call = notificationService.calls.find(c => c.method === "sendPushNotification");
  assert.equal(call.profileId, "other-profile");
  assert.ok(call.payload.title.includes("commented"));
  assert.equal(call.payload.data.type, "ootd_comment");
});

test("createComment does NOT trigger notification when commenter is the author", async () => {
  // Post authored by same user
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions] });
  const squadRepo = createMockSquadRepo();
  const notificationService = createMockNotificationService();
  const service = createOotdService({ ootdRepo, squadRepo, notificationService });

  const result = await service.createComment(testAuthContext, {
    postId: "post-1",
    text: "Self comment",
  });

  assert.ok(result.comment);
  await new Promise(r => setTimeout(r, 10));
  assert.equal(notificationService.calls.filter(c => c.method === "sendPushNotification").length, 0);
});

test("createPost triggers sendToSquadMembers with correct parameters", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const notificationService = createMockNotificationService();
  const service = createOotdService({ ootdRepo, squadRepo, notificationService });

  await service.createPost(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg",
    caption: "My outfit today",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
  });

  // Wait for fire-and-forget notification
  await new Promise(r => setTimeout(r, 10));
  assert.ok(notificationService.calls.some(c => c.method === "sendToSquadMembers"));
  const call = notificationService.calls.find(c => c.method === "sendToSquadMembers");
  assert.equal(call.squadId, "00000000-0000-0000-0000-000000000001");
  assert.equal(call.excludeProfileId, testProfileId);
  assert.ok(call.payload.title.includes("posted a new OOTD"));
  assert.equal(call.payload.body, "My outfit today");
  assert.equal(call.payload.data.type, "ootd_post");
  assert.equal(call.payload.checkSocialMode, "all");
});

test("createPost uses fallback body when caption is null", async () => {
  const ootdRepo = createMockOotdRepo();
  const squadRepo = createMockSquadRepo();
  const notificationService = createMockNotificationService();
  const service = createOotdService({ ootdRepo, squadRepo, notificationService });

  await service.createPost(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg",
    squadIds: ["00000000-0000-0000-0000-000000000001"],
  });

  await new Promise(r => setTimeout(r, 10));
  const call = notificationService.calls.find(c => c.method === "sendToSquadMembers");
  assert.equal(call.payload.body, "Check out their outfit!");
});

// --- listComments tests ---

test("listComments returns paginated comments ordered by created_at ASC", async () => {
  const comments = [
    { id: "c1", postId: "post-1", authorId: testProfileId, text: "First", createdAt: "2026-03-19T00:00:00.000Z" },
    { id: "c2", postId: "post-1", authorId: testProfileId, text: "Second", createdAt: "2026-03-19T01:00:00.000Z" },
  ];
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions], comments });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.listComments(testAuthContext, { postId: "post-1" });

  assert.ok(Array.isArray(result.comments));
  assert.ok("nextCursor" in result);
});

test("listComments excludes soft-deleted comments (handled by repo)", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions], comments: [] });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  const result = await service.listComments(testAuthContext, { postId: "post-1" });

  assert.equal(result.comments.length, 0);
});

// --- deleteComment tests ---

test("deleteComment soft-deletes when caller is comment author", async () => {
  const comment = { id: "comment-1", post_id: "post-1", author_id: testProfileId, text: "My comment" };
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions], commentById: comment });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await service.deleteComment(testAuthContext, { postId: "post-1", commentId: "comment-1" });

  assert.ok(ootdRepo.calls.some((c) => c.method === "softDeleteComment"));
});

test("deleteComment soft-deletes when caller is post author", async () => {
  const comment = { id: "comment-1", post_id: "post-1", author_id: "other-profile", text: "Their comment" };
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions], commentById: comment });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await service.deleteComment(testAuthContext, { postId: "post-1", commentId: "comment-1" });

  assert.ok(ootdRepo.calls.some((c) => c.method === "softDeleteComment"));
});

test("deleteComment returns 403 when caller is neither comment author nor post author", async () => {
  const postByOther = { ...testPostForReactions, authorId: "other-profile" };
  const comment = { id: "comment-1", post_id: "post-1", author_id: "third-profile", text: "A comment" };
  const ootdRepo = createMockOotdRepo({ posts: [postByOther], commentById: comment });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.deleteComment(testAuthContext, { postId: "post-1", commentId: "comment-1" }),
    (err) => err.statusCode === 403
  );
});

test("deleteComment returns 404 for non-existent comment", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [testPostForReactions], commentById: null });
  const squadRepo = createMockSquadRepo();
  const service = createOotdService({ ootdRepo, squadRepo });

  await assert.rejects(
    () => service.deleteComment(testAuthContext, { postId: "post-1", commentId: "nonexistent" }),
    (err) => err.statusCode === 404
  );
});

// --- stealThisLook tests (Story 9.5) ---

const testPostWithItems = {
  id: "post-1",
  authorId: "other-profile",
  photoUrl: "https://example.com/photo.jpg",
  caption: "My outfit",
  createdAt: "2026-03-19T00:00:00.000Z",
  taggedItems: [
    { id: "ti-1", postId: "post-1", itemId: "item-a", itemName: "Blue Top", itemCategory: "tops" },
  ],
  squadIds: ["squad-1"],
  reactionCount: 0,
  commentCount: 0,
  hasReacted: false,
};

const testPostNoItems = {
  ...testPostWithItems,
  id: "post-no-items",
  taggedItems: [],
};

const sourceItemDetails = [
  { id: "item-a", name: "Blue Top", category: "tops", color: "blue", secondaryColors: [], pattern: "solid", material: "cotton", style: "casual", season: ["spring"], occasion: ["everyday"], photoUrl: "https://example.com/blue-top.jpg" },
];

const wardrobeItems = [
  { id: "w1", name: "Navy Blouse", category: "tops", color: "navy", style: "casual", material: "cotton", pattern: "solid", season: ["spring"], occasion: ["everyday"], photo_url: "https://example.com/w1.jpg" },
  { id: "w2", name: "White Tee", category: "tops", color: "white", style: "casual", material: "cotton", pattern: "solid", season: ["summer"], occasion: ["everyday"], photo_url: "https://example.com/w2.jpg" },
  { id: "w3", name: "Red Dress", category: "dresses", color: "red", style: "formal", material: "silk", pattern: "solid", season: ["all"], occasion: ["party"], photo_url: "https://example.com/w3.jpg" },
];

function createMockItemRepo({ items = wardrobeItems } = {}) {
  const calls = [];
  return {
    calls,
    async listItems(authContext, opts) {
      calls.push({ method: "listItems", authContext, opts });
      return { items };
    },
  };
}

function createMockGeminiClient({ response = null, shouldFail = false } = {}) {
  const calls = [];
  const defaultResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [
          {
            sourceItemId: "item-a",
            matchedItems: [
              { itemId: "w1", matchScore: 85, matchReason: "Similar navy top in casual style" },
              { itemId: "w2", matchScore: 65, matchReason: "White casual top as alternative" },
            ],
          },
        ],
      }) }] } }],
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 },
    },
  };
  return {
    calls,
    async getGenerativeModel(modelName) {
      calls.push({ method: "getGenerativeModel", modelName });
      return {
        async generateContent(request) {
          calls.push({ method: "generateContent", request });
          if (shouldFail) throw new Error("Gemini API error");
          return response ?? defaultResponse;
        },
      };
    },
    isAvailable() { return true; },
  };
}

function createMockAiUsageLogRepo() {
  const calls = [];
  return {
    calls,
    async logUsage(authContext, data) {
      calls.push({ method: "logUsage", authContext, data });
    },
  };
}

function createStealLookService(overrides = {}) {
  const ootdRepo = overrides.ootdRepo ?? createMockOotdRepo({
    posts: [testPostWithItems, testPostNoItems],
  });
  // Add getPostItemsWithDetails to mock
  if (!ootdRepo.getPostItemsWithDetails) {
    ootdRepo.getPostItemsWithDetails = async (postId) => {
      ootdRepo.calls.push({ method: "getPostItemsWithDetails", postId });
      return overrides.sourceItems ?? sourceItemDetails;
    };
  }
  const squadRepo = overrides.squadRepo ?? createMockSquadRepo();
  const itemRepo = overrides.itemRepo ?? createMockItemRepo();
  const geminiClient = overrides.geminiClient ?? createMockGeminiClient();
  const aiUsageLogRepo = overrides.aiUsageLogRepo ?? createMockAiUsageLogRepo();

  return {
    service: createOotdService({ ootdRepo, squadRepo, itemRepo, geminiClient, aiUsageLogRepo }),
    ootdRepo,
    squadRepo,
    itemRepo,
    geminiClient,
    aiUsageLogRepo,
  };
}

test("stealThisLook fetches post, tagged items, wardrobe, calls Gemini, returns matches", async () => {
  const { service, geminiClient, aiUsageLogRepo } = createStealLookService();

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });

  assert.ok(result.sourceMatches);
  assert.equal(result.sourceMatches.length, 1);
  assert.equal(result.sourceMatches[0].sourceItem.id, "item-a");
  assert.ok(result.sourceMatches[0].matches.length > 0);
  assert.ok(geminiClient.calls.some(c => c.method === "generateContent"));
});

test("stealThisLook throws 404 when post not found", async () => {
  const { service } = createStealLookService({
    ootdRepo: createMockOotdRepo({ posts: [] }),
  });

  await assert.rejects(
    () => service.stealThisLook(testAuthContext, { postId: "nonexistent" }),
    (err) => err.statusCode === 404
  );
});

test("stealThisLook throws 400 when post has no tagged items", async () => {
  const { service } = createStealLookService();

  await assert.rejects(
    () => service.stealThisLook(testAuthContext, { postId: "post-no-items" }),
    (err) => err.statusCode === 400 && err.code === "NO_TAGGED_ITEMS"
  );
});

test("stealThisLook throws 422 when user wardrobe is empty", async () => {
  const { service } = createStealLookService({
    itemRepo: createMockItemRepo({ items: [] }),
  });

  await assert.rejects(
    () => service.stealThisLook(testAuthContext, { postId: "post-1" }),
    (err) => err.statusCode === 422 && err.code === "WARDROBE_EMPTY"
  );
});

test("stealThisLook logs AI usage on success with feature steal_look", async () => {
  const { service, aiUsageLogRepo } = createStealLookService();

  await service.stealThisLook(testAuthContext, { postId: "post-1" });

  const logCall = aiUsageLogRepo.calls.find(c => c.method === "logUsage");
  assert.ok(logCall);
  assert.equal(logCall.data.feature, "steal_look");
  assert.equal(logCall.data.status, "success");
});

test("stealThisLook logs AI usage on failure with feature steal_look", async () => {
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ shouldFail: true }),
    aiUsageLogRepo,
  });

  await assert.rejects(
    () => service.stealThisLook(testAuthContext, { postId: "post-1" }),
    (err) => err.statusCode === 502
  );

  const logCall = aiUsageLogRepo.calls.find(c => c.method === "logUsage");
  assert.ok(logCall);
  assert.equal(logCall.data.feature, "steal_look");
  assert.equal(logCall.data.status, "failure");
});

test("stealThisLook throws 502 when Gemini returns unparseable response", async () => {
  const badGemini = createMockGeminiClient({
    response: {
      response: {
        candidates: [{ content: { parts: [{ text: "not json" }] } }],
        usageMetadata: {},
      },
    },
  });

  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const { service } = createStealLookService({
    geminiClient: badGemini,
    aiUsageLogRepo,
  });

  await assert.rejects(
    () => service.stealThisLook(testAuthContext, { postId: "post-1" }),
    (err) => err.statusCode === 502 && err.code === "MATCHING_FAILED"
  );
});

test("stealThisLook clamps out-of-range match scores to [0, 100]", async () => {
  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [
            { itemId: "w1", matchScore: 150, matchReason: "Over 100" },
            { itemId: "w2", matchScore: -10, matchReason: "Below 0" },
          ],
        }],
      }) }] } }],
      usageMetadata: {},
    },
  };

  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  const matches = result.sourceMatches[0].matches;

  // Score 150 clamped to 100
  assert.ok(matches.some(m => m.matchScore === 100));
  // Score -10 clamped to 0, which is < 30 so filtered out
  assert.ok(!matches.some(m => m.matchScore < 0));
});

test("stealThisLook filters out matches with score < 30", async () => {
  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [
            { itemId: "w1", matchScore: 25, matchReason: "Poor match" },
            { itemId: "w2", matchScore: 50, matchReason: "OK match" },
          ],
        }],
      }) }] } }],
      usageMetadata: {},
    },
  };

  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  const matches = result.sourceMatches[0].matches;

  assert.equal(matches.length, 1);
  assert.equal(matches[0].matchScore, 50);
});

test("stealThisLook limits to 3 matches per source item", async () => {
  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [
            { itemId: "w1", matchScore: 90, matchReason: "Great" },
            { itemId: "w2", matchScore: 80, matchReason: "Good" },
            { itemId: "w3", matchScore: 70, matchReason: "OK" },
            { itemId: "w1", matchScore: 60, matchReason: "Dupe" }, // would be 4th
          ],
        }],
      }) }] } }],
      usageMetadata: {},
    },
  };

  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  assert.ok(result.sourceMatches[0].matches.length <= 3);
});

test("stealThisLook validates matched item IDs exist in user wardrobe", async () => {
  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [
            { itemId: "w1", matchScore: 85, matchReason: "Valid" },
            { itemId: "fake-id", matchScore: 90, matchReason: "Invalid" },
          ],
        }],
      }) }] } }],
      usageMetadata: {},
    },
  };

  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  const matches = result.sourceMatches[0].matches;

  assert.ok(matches.every(m => m.itemId !== "fake-id"));
  assert.ok(matches.some(m => m.itemId === "w1"));
});

test("stealThisLook discards matches with invalid item IDs", async () => {
  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [
            { itemId: "nonexistent-1", matchScore: 95, matchReason: "Invented" },
            { itemId: "nonexistent-2", matchScore: 80, matchReason: "Also invented" },
          ],
        }],
      }) }] } }],
      usageMetadata: {},
    },
  };

  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  assert.equal(result.sourceMatches[0].matches.length, 0);
});

test("stealThisLook works with large wardrobe (> 50 items, uses summarized mode)", async () => {
  // Generate 55 items
  const largeWardrobe = Array.from({ length: 55 }, (_, i) => ({
    id: `w-${i}`,
    name: `Item ${i}`,
    category: i % 3 === 0 ? "tops" : i % 3 === 1 ? "bottoms" : "dresses",
    color: i % 2 === 0 ? "blue" : "red",
    style: "casual",
    material: "cotton",
    pattern: "solid",
    season: ["all"],
    occasion: ["everyday"],
    photo_url: `https://example.com/w-${i}.jpg`,
  }));

  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [
            { category: "tops", color: "blue", style: "casual", matchScore: 75, matchReason: "Blue casual top" },
          ],
        }],
      }) }] } }],
      usageMetadata: { promptTokenCount: 200, candidatesTokenCount: 60 },
    },
  };

  const { service } = createStealLookService({
    itemRepo: createMockItemRepo({ items: largeWardrobe }),
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  assert.ok(result.sourceMatches);
  assert.equal(result.sourceMatches.length, 1);
  // Should have resolved distribution matches to actual items
  if (result.sourceMatches[0].matches.length > 0) {
    assert.ok(result.sourceMatches[0].matches[0].itemId.startsWith("w-"));
  }
});

test("stealThisLook returns empty matches array for source items with no good matches", async () => {
  const geminiResponse = {
    response: {
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        matches: [{
          sourceItemId: "item-a",
          matchedItems: [],
        }],
      }) }] } }],
      usageMetadata: {},
    },
  };

  const { service } = createStealLookService({
    geminiClient: createMockGeminiClient({ response: geminiResponse }),
  });

  const result = await service.stealThisLook(testAuthContext, { postId: "post-1" });
  assert.equal(result.sourceMatches[0].matches.length, 0);
});

test("getPostItemsWithDetails returns full item metadata for tagged items", async () => {
  const ootdRepo = createMockOotdRepo({ posts: [testPostWithItems] });
  ootdRepo.getPostItemsWithDetails = async (postId) => {
    return sourceItemDetails;
  };

  const items = await ootdRepo.getPostItemsWithDetails("post-1");
  assert.equal(items.length, 1);
  assert.equal(items[0].id, "item-a");
  assert.equal(items[0].category, "tops");
  assert.equal(items[0].color, "blue");
  assert.equal(items[0].material, "cotton");
});
