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

const testItemId = "item-uuid-1";

function buildContext({
  authenticated = true,
  itemForGet = null,
  itemForUpdate = null,
  getItemError = null,
  updateItemError = null,
  historyEntry = null,
  historyList = [],
  summary = { itemsSold: 0, itemsDonated: 0, totalEarnings: 0 },
  monthlyEarnings = [],
} = {}) {
  const badgeCalls = [];
  const defaultItem = {
    id: testItemId,
    name: "Blue Shirt",
    resaleStatus: "listed",
    photoUrl: "http://example.com/photo.jpg",
  };

  const defaultHistoryEntry = {
    id: "history-1",
    profileId: "profile-1",
    itemId: testItemId,
    type: "sold",
    salePrice: 50,
    saleCurrency: "GBP",
    saleDate: "2026-03-15",
    createdAt: "2026-03-15T10:00:00.000Z",
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
      async getItemForUser(auth, id) {
        if (getItemError) throw getItemError;
        const item = itemForGet ?? defaultItem;
        return { item };
      },
      async updateItemForUser(auth, id, fields) {
        if (updateItemError) throw updateItemError;
        const item = itemForUpdate ?? { ...(itemForGet ?? defaultItem), ...fields };
        return { item };
      },
      async deleteItemForUser() { return { deleted: true }; },
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
      async checkAndAward(authContext, badgeKey) {
        badgeCalls.push(badgeKey);
        return { badgesAwarded: [] };
      },
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
      async createHistoryEntry(auth, params) {
        return historyEntry ?? { ...defaultHistoryEntry, ...params };
      },
      async listHistory(auth, params) {
        return historyList;
      },
      async getEarningsSummary(auth) {
        return summary;
      },
      async getMonthlyEarnings(auth) {
        return monthlyEarnings;
      },
    },
  };
}

test("PATCH /v1/items/:id/resale-status requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "sold", salePrice: 50 });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("PATCH /v1/items/:id/resale-status with status 'sold' updates item and creates history entry", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "sold", salePrice: 50, saleCurrency: "GBP" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.item);
  assert.ok(res.body.historyEntry);
});

test("PATCH /v1/items/:id/resale-status with status 'sold' requires salePrice > 0 (400)", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "sold" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("salePrice"));
});

test("PATCH /v1/items/:id/resale-status with status 'donated' updates item and creates history entry with price 0", async () => {
  const ctx = buildContext({
    itemForGet: { id: testItemId, name: "Old Jacket", resaleStatus: "listed" },
  });
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "donated" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.historyEntry);
  assert.equal(res.body.historyEntry.type, "donated");
  assert.equal(res.body.historyEntry.salePrice, 0);
});

test("PATCH /v1/items/:id/resale-status returns 409 for invalid transitions (sold->donated)", async () => {
  const ctx = buildContext({
    itemForGet: { id: testItemId, name: "Sold Item", resaleStatus: "sold" },
  });
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "donated" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 409);
});

test("PATCH /v1/items/:id/resale-status returns 404 for non-existent item", async () => {
  const ctx = buildContext({
    getItemError: (() => { const e = new Error("Item not found"); e.statusCode = 404; e.code = "NOT_FOUND"; return e; })(),
  });
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/nonexistent/resale-status`,
    { status: "sold", salePrice: 50 },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 404);
});

test("PATCH /v1/items/:id/resale-status links resale_listing_id on sold (best-effort)", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "sold", salePrice: 99.99 },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
});

test("PATCH /v1/items/:id/resale-status checks circular_champion badge on sold", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "sold", salePrice: 50 },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.ok(ctx.badgeCalls.includes("circular_champion"));
});

test("PATCH /v1/items/:id/resale-status returns 400 for invalid status", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("PATCH", `http://localhost/v1/items/${testItemId}/resale-status`,
    { status: "invalid" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 400);
});

test("GET /v1/resale/history requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/history");
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("GET /v1/resale/history returns history, summary, and monthlyEarnings", async () => {
  const ctx = buildContext({
    historyList: [{ id: "h1", type: "sold", salePrice: 50 }],
    summary: { itemsSold: 1, itemsDonated: 0, totalEarnings: 50 },
    monthlyEarnings: [{ month: "2026-03-01", earnings: 50 }],
  });
  const req = createJsonRequest("GET", "http://localhost/v1/resale/history",
    null, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.history));
  assert.ok(res.body.summary);
  assert.ok(Array.isArray(res.body.monthlyEarnings));
});

test("GET /v1/resale/history respects limit and offset query params", async () => {
  let capturedParams = {};
  const ctx = buildContext();
  ctx.resaleHistoryRepo.listHistory = async (auth, params) => {
    capturedParams = params;
    return [];
  };
  const req = createJsonRequest("GET", "http://localhost/v1/resale/history?limit=10&offset=5",
    null, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.equal(capturedParams.limit, 10);
  assert.equal(capturedParams.offset, 5);
});
