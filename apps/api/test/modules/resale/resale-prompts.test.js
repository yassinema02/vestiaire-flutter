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

const testPromptId = "prompt-uuid-1";

function buildContext({
  authenticated = true,
  evaluateResult = { candidates: 2, prompted: true },
  pendingPrompts = [],
  updateResult = null,
  pendingCount = 0,
  evaluateError = null,
  updateError = null,
} = {}) {
  const defaultUpdateResult = {
    id: testPromptId,
    profileId: "profile-1",
    itemId: "item-1",
    estimatedPrice: 48,
    estimatedCurrency: "GBP",
    action: "accepted",
    dismissedUntil: null,
    createdAt: "2026-03-19T10:00:00.000Z",
  };

  return {
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
      async getItemForUser() { return { item: { id: "item-1" } }; },
      async updateItemForUser() { return { item: { id: "item-1" } }; },
      async deleteItemForUser() { return { deleted: true }; },
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarOutfitRepo: {},
    calendarService: {},
    outfitGenerationService: {},
    outfitRepository: { async listOutfits() { return []; } },
    usageLimitService: {},
    wearLogRepository: {},
    analyticsRepository: {},
    analyticsSummaryService: {},
    userStatsRepo: {
      async getUserStats() {
        return { totalPoints: 0, currentStreak: 0, longestStreak: 0, currentLevel: 1, currentLevelName: "Rookie", nextLevelThreshold: 10, itemCount: 0 };
      },
    },
    stylePointsService: {
      async awardItemUploadPoints() { return { pointsAwarded: 10 }; },
      async awardWearLogPoints() { return { pointsAwarded: 5 }; },
    },
    levelService: {
      async recalculateLevel() { return { currentLevel: 1, currentLevelName: "Rookie", previousLevel: 1, previousLevelName: "Rookie", leveledUp: false }; },
    },
    streakService: {
      async evaluateStreak() { return { currentStreak: 1, longestStreak: 1, lastStreakDate: "2026-03-19", streakExtended: false, isNewStreak: true, streakFreezeAvailable: true }; },
    },
    badgeRepo: {},
    badgeService: {
      async getBadgeCatalog() { return []; },
      async getUserBadgeCollection() { return { badges: [], badgeCount: 0 }; },
      async evaluateAndAward() { return { badgesAwarded: [] }; },
      async checkAndAward() { return { badgesAwarded: [] }; },
    },
    challengeRepo: {},
    challengeService: {
      async acceptChallenge() { return { challenge: { key: "closet_safari" } }; },
      async updateProgressOnItemCreate() { return { challengeUpdate: null }; },
      async getChallengeStatus() { return null; },
    },
    subscriptionSyncService: {
      async syncFromClient() { return { isPremium: false }; },
      async handleWebhookEvent() { return { handled: true }; },
    },
    premiumGuard: {
      async checkPremium() { return { isPremium: false }; },
      async checkUsageQuota() { return { allowed: true, used: 0, remaining: 2, resetsAt: "2026-04-01" }; },
    },
    resaleListingService: {
      async generateListing() { return { listing: {}, item: {}, generatedAt: "2026-03-19" }; },
    },
    resaleHistoryRepo: {
      async createHistoryEntry() { return {}; },
      async listHistory() { return []; },
      async getEarningsSummary() { return { itemsSold: 0, itemsDonated: 0, totalEarnings: 0 }; },
      async getMonthlyEarnings() { return []; },
    },
    shoppingScanService: {},
    shoppingScanRepo: {},
    squadService: {},
    ootdService: {},
    extractionService: {},
    extractionRepo: {},
    extractionProcessingService: {},
    tripDetectionService: {},
    itemRepo: {},
    resalePromptService: {
      async evaluateAndNotify(authContext) {
        if (evaluateError) throw evaluateError;
        return evaluateResult;
      },
      async getPendingPrompts(authContext) {
        return pendingPrompts;
      },
      async updatePromptAction(authContext, promptId, { action }) {
        if (updateError) throw updateError;
        if (action !== "accepted" && action !== "dismissed") {
          const err = new Error("action must be 'accepted' or 'dismissed'");
          err.statusCode = 400;
          throw err;
        }
        return updateResult || {
          ...defaultUpdateResult,
          action,
          dismissedUntil: action === "dismissed" ? "2026-06-17" : null,
        };
      },
      async getPendingCount(authContext) {
        return pendingCount;
      },
    },
  };
}

// ─── POST /v1/resale/prompts/evaluate ───

test("POST /v1/resale/prompts/evaluate requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("POST", "http://localhost/v1/resale/prompts/evaluate", {},
    {});
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("POST /v1/resale/prompts/evaluate returns 200 with candidates count", async () => {
  const ctx = buildContext({ evaluateResult: { candidates: 2, prompted: true } });
  const req = createJsonRequest("POST", "http://localhost/v1/resale/prompts/evaluate", {},
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.candidates, 2);
  assert.equal(res.body.prompted, true);
});

test("POST /v1/resale/prompts/evaluate returns 0 candidates for user with no neglected items", async () => {
  const ctx = buildContext({ evaluateResult: { candidates: 0, prompted: false } });
  const req = createJsonRequest("POST", "http://localhost/v1/resale/prompts/evaluate", {},
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.candidates, 0);
  assert.equal(res.body.prompted, false);
});

// ─── GET /v1/resale/prompts ───

test("GET /v1/resale/prompts requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/prompts", null, {});
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("GET /v1/resale/prompts returns pending prompts with item metadata", async () => {
  const ctx = buildContext({
    pendingPrompts: [
      {
        id: testPromptId,
        profileId: "profile-1",
        itemId: "item-1",
        estimatedPrice: 48,
        estimatedCurrency: "GBP",
        action: null,
        dismissedUntil: null,
        createdAt: "2026-03-19T10:00:00.000Z",
        itemName: "Blue Shirt",
        itemPhotoUrl: "http://img.com/1.jpg",
        itemCategory: "Tops",
        itemBrand: "Nike",
        itemWearCount: 3,
      },
    ],
  });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/prompts", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.prompts));
  assert.equal(res.body.prompts.length, 1);
  assert.equal(res.body.prompts[0].itemName, "Blue Shirt");
  assert.equal(res.body.prompts[0].estimatedPrice, 48);
});

test("GET /v1/resale/prompts excludes acted-upon prompts", async () => {
  const ctx = buildContext({ pendingPrompts: [] });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/prompts", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.prompts.length, 0);
});

// ─── PATCH /v1/resale/prompts/:id ───

test("PATCH /v1/resale/prompts/:id requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("PATCH", `http://localhost/v1/resale/prompts/${testPromptId}`,
    { action: "accepted" }, {});
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("PATCH /v1/resale/prompts/:id accepts 'accepted' action", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/resale/prompts/${testPromptId}`,
    { action: "accepted" }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.action, "accepted");
  assert.equal(res.body.dismissedUntil, null);
});

test("PATCH /v1/resale/prompts/:id accepts 'dismissed' action and sets dismissed_until", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/resale/prompts/${testPromptId}`,
    { action: "dismissed" }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.action, "dismissed");
  assert.ok(res.body.dismissedUntil, "dismissed_until should be set");
});

test("PATCH /v1/resale/prompts/:id returns 400 for invalid action", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/resale/prompts/${testPromptId}`,
    { action: "invalid" }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 400);
});

test("PATCH /v1/resale/prompts/:id returns 400 for missing action", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/resale/prompts/${testPromptId}`,
    {}, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 400);
});

// ─── GET /v1/resale/prompts/count ───

test("GET /v1/resale/prompts/count requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/prompts/count", null, {});
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("GET /v1/resale/prompts/count returns correct pending count", async () => {
  const ctx = buildContext({ pendingCount: 3 });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/prompts/count", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.count, 3);
});

test("GET /v1/resale/prompts/count returns 0 when no pending prompts", async () => {
  const ctx = buildContext({ pendingCount: 0 });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/prompts/count", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.count, 0);
});
