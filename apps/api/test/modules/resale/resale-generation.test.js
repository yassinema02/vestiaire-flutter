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
  generateResult = null,
  generateShouldFail = false,
  generateFailError = null,
  quotaAllowed = true,
  quotaUsed = 0,
  quotaLimit = 2,
  isPremium = false,
  badgeCheckShouldFail = false,
} = {}) {
  const badgeCalls = [];
  const defaultResult = {
    listing: {
      id: "listing-1",
      title: "Great Blue Shirt",
      description: "A lovely shirt in great condition.",
      conditionEstimate: "Like New",
      hashtags: ["fashion", "shirt"],
      platform: "general"
    },
    item: {
      id: "item-1",
      name: "Blue Shirt",
      category: "tops",
      brand: "Nike",
      photoUrl: "https://example.com/photo.jpg"
    },
    generatedAt: "2026-03-19T00:00:00.000Z"
  };

  return {
    badgeCalls,
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate(req) {
        if (!authenticated) {
          const { AuthenticationError } = await import("../../../src/modules/auth/service.js");
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
    userStatsRepo: {
      async getUserStats() {
        return { totalPoints: 0, currentStreak: 0, longestStreak: 0, currentLevel: 1, currentLevelName: "Closet Rookie", nextLevelThreshold: 10, itemCount: 0 };
      },
    },
    stylePointsService: {
      async awardItemUploadPoints() { return { pointsAwarded: 10 }; },
      async awardWearLogPoints() { return { pointsAwarded: 5 }; },
    },
    levelService: {
      async recalculateLevel() { return { currentLevel: 1, currentLevelName: "Closet Rookie", previousLevel: 1, previousLevelName: "Closet Rookie", leveledUp: false }; },
    },
    streakService: {
      async evaluateStreak() { return { currentStreak: 1, longestStreak: 1, lastStreakDate: "2026-03-19", streakExtended: false, isNewStreak: true, streakFreezeAvailable: true }; },
    },
    badgeRepo: {},
    badgeService: {
      async getBadgeCatalog() { return []; },
      async getUserBadgeCollection() { return { badges: [], badgeCount: 0 }; },
      async evaluateAndAward() { return { badgesAwarded: [] }; },
      async checkAndAward(authContext, badgeKey) {
        badgeCalls.push({ authContext, badgeKey });
        if (badgeCheckShouldFail) throw new Error("Badge check failed");
        return { awarded: true, badgeKey };
      },
    },
    challengeRepo: {},
    challengeService: {
      async acceptChallenge() { return { challenge: { key: "closet_safari" } }; },
      async updateProgressOnItemCreate() { return { challengeUpdate: null }; },
      async getChallengeStatus() { return null; },
      async checkTrialExpiry() { return { isPremium: false, trialExpired: false }; },
    },
    subscriptionSyncService: {
      async syncFromClient() { return { isPremium: false }; },
      async handleWebhookEvent() { return { handled: true }; },
    },
    premiumGuard: {
      async checkPremium() { return { isPremium, profileId: "profile-1", premiumSource: null }; },
      async requirePremium(authContext) {
        if (!isPremium) throw { statusCode: 403, code: "PREMIUM_REQUIRED", message: "Premium required" };
        return { isPremium: true, profileId: "profile-1" };
      },
      async checkUsageQuota(authContext, opts) {
        const remaining = Math.max(0, quotaLimit - quotaUsed);
        return {
          allowed: quotaAllowed,
          isPremium,
          limit: quotaLimit,
          used: quotaUsed,
          remaining,
          resetsAt: "2026-04-01T00:00:00.000Z",
        };
      },
    },
    resaleListingService: {
      async generateListing(authContext, params) {
        if (generateShouldFail) {
          throw generateFailError || { statusCode: 500, message: "Resale listing generation failed" };
        }
        return generateResult || defaultResult;
      },
    },
  };
}

test("POST /v1/resale/generate requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" });

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/resale/generate returns 200 with listing on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.listing);
  assert.ok(res.body.listing.title);
  assert.ok(res.body.listing.description);
});

test("POST /v1/resale/generate returns correct response structure (listing, item, generatedAt)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.listing);
  assert.ok(res.body.item);
  assert.ok(res.body.generatedAt);
  assert.equal(res.body.listing.id, "listing-1");
  assert.equal(res.body.item.id, "item-1");
  assert.ok(Array.isArray(res.body.listing.hashtags));
});

test("POST /v1/resale/generate returns 429 when free user exceeds monthly limit", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({
    quotaAllowed: false,
    quotaUsed: 2,
    quotaLimit: 2,
  }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.code, "RATE_LIMIT_EXCEEDED");
  assert.equal(res.body.monthlyLimit, 2);
  assert.equal(res.body.used, 2);
  assert.equal(res.body.remaining, 0);
  assert.ok(res.body.resetsAt);
});

test("POST /v1/resale/generate allows unlimited for premium user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({
    isPremium: true,
    quotaAllowed: true,
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.listing);
});

test("POST /v1/resale/generate returns 404 for non-existent item", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "nonexistent" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({
    generateShouldFail: true,
    generateFailError: { statusCode: 404, message: "Item not found" },
  }));

  assert.equal(res.statusCode, 404);
});

test("POST /v1/resale/generate returns 503 when Gemini is unavailable", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({
    generateShouldFail: true,
    generateFailError: { statusCode: 503, message: "AI service unavailable" },
  }));

  assert.equal(res.statusCode, 503);
});

test("POST /v1/resale/generate returns 500 when Gemini call fails", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({
    generateShouldFail: true,
    generateFailError: { statusCode: 500, message: "Resale listing generation failed" },
  }));

  assert.equal(res.statusCode, 500);
});

test("POST /v1/resale/generate checks badge eligibility after success", async () => {
  const ctx = buildContext();
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", { itemId: "item-1" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.equal(ctx.badgeCalls.length, 1);
  assert.equal(ctx.badgeCalls[0].badgeKey, "circular_seller");
});

test("POST /v1/resale/generate returns 400 when itemId is missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/resale/generate", {}, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, "BAD_REQUEST");
});
