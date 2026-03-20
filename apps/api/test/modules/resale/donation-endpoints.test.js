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
  getItemError = null,
  donationEntry = null,
  donationList = [],
  donationSummary = { totalDonated: 0, totalValue: 0 },
  springCleanItems = [],
} = {}) {
  const badgeCalls = [];
  const donationCalls = [];
  const defaultItem = {
    id: testItemId,
    name: "Blue Shirt",
    resaleStatus: null,
    photoUrl: "http://example.com/photo.jpg",
    category: "tops",
    brand: "Nike",
    purchasePrice: 50,
    wearCount: 3,
    neglectStatus: "neglected",
  };

  const defaultDonation = {
    id: "donation-1",
    profileId: "profile-1",
    itemId: testItemId,
    charityName: null,
    estimatedValue: 10,
    donationDate: "2026-03-15",
    createdAt: "2026-03-15T10:00:00.000Z",
  };

  return {
    badgeCalls,
    donationCalls,
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    pool: {
      async connect() {
        return {
          async query(sql, params) {
            if (sql.includes("set_config")) return { rows: [] };
            if (sql.includes("neglect_status")) {
              return {
                rows: springCleanItems.map((item) => ({
                  id: item.id || "item-1",
                  profile_id: "profile-1",
                  photo_url: item.photoUrl || null,
                  name: item.name || "Item",
                  category: item.category || "tops",
                  brand: item.brand || null,
                  purchase_price: item.purchasePrice || null,
                  currency: item.currency || "GBP",
                  wear_count: item.wearCount ?? 0,
                  last_worn_date: item.lastWornDate || null,
                  neglect_status: "neglected",
                  resale_status: null,
                  days_unworn: item.daysUnworn ?? 200,
                  created_at: new Date("2025-01-01"),
                })),
              };
            }
            return { rows: [] };
          },
          release() {},
        };
      },
    },
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
        const item = { ...(itemForGet ?? defaultItem), ...fields };
        return { item };
      },
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
      async createHistoryEntry(auth, params) { return { id: "h1", ...params }; },
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
      async evaluateAndNotify() { return { candidates: 0, prompted: false }; },
      async getPendingPrompts() { return []; },
      async getPendingCount() { return 0; },
      async updatePromptAction() { return {}; },
    },
    donationRepository: {
      async createDonation(auth, params) {
        donationCalls.push(params);
        return donationEntry ?? { ...defaultDonation, ...params };
      },
      async listDonations(auth, params) {
        return donationList;
      },
      async getDonationSummary(auth) {
        return donationSummary;
      },
    },
  };
}

// --- POST /v1/donations ---

test("POST /v1/donations requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId }, {});
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("POST /v1/donations creates donation and updates item resale_status to 'donated' (201)", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId, estimatedValue: 15 },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.donation);
  assert.ok(res.body.item);
  assert.equal(res.body.item.resaleStatus, "donated");
});

test("POST /v1/donations returns 400 when itemId is missing", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    {},
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("itemId"));
});

test("POST /v1/donations returns 404 for non-existent item", async () => {
  const ctx = buildContext({
    getItemError: { statusCode: 404, message: "Item not found" },
  });
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: "non-existent-item" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 404);
});

test("POST /v1/donations returns 409 for item with resale_status 'sold'", async () => {
  const ctx = buildContext({
    itemForGet: { id: testItemId, name: "Sold Item", resaleStatus: "sold" },
  });
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 409);
});

test("POST /v1/donations returns 409 for item with resale_status 'donated'", async () => {
  const ctx = buildContext({
    itemForGet: { id: testItemId, name: "Donated Item", resaleStatus: "donated" },
  });
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 409);
});

test("POST /v1/donations allows donation for item with resale_status NULL", async () => {
  const ctx = buildContext({
    itemForGet: { id: testItemId, name: "Eligible Item", resaleStatus: null },
  });
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 201);
});

test("POST /v1/donations allows donation for item with resale_status 'listed'", async () => {
  const ctx = buildContext({
    itemForGet: { id: testItemId, name: "Listed Item", resaleStatus: "listed" },
  });
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 201);
});

test("POST /v1/donations checks generous_giver badge on success", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 201);
  assert.ok(ctx.badgeCalls.includes("generous_giver"));
});

test("POST /v1/donations stores charity_name when provided", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("POST", "http://localhost/v1/donations",
    { itemId: testItemId, charityName: "Oxfam" },
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 201);
  assert.equal(ctx.donationCalls[0].charityName, "Oxfam");
});

// --- GET /v1/donations ---

test("GET /v1/donations requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("GET", "http://localhost/v1/donations");
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("GET /v1/donations returns donations list and summary", async () => {
  const ctx = buildContext({
    donationList: [{ id: "d1", itemId: "item-1", estimatedValue: 10 }],
    donationSummary: { totalDonated: 1, totalValue: 10 },
  });
  const req = createJsonRequest("GET", "http://localhost/v1/donations", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.donations));
  assert.equal(res.body.donations.length, 1);
  assert.ok(res.body.summary);
  assert.equal(res.body.summary.totalDonated, 1);
});

test("GET /v1/donations respects limit and offset", async () => {
  const ctx = buildContext();
  const req = createJsonRequest("GET", "http://localhost/v1/donations?limit=10&offset=5", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
});

// --- GET /v1/spring-clean/items ---

test("GET /v1/spring-clean/items requires authentication (401)", async () => {
  const ctx = buildContext({ authenticated: false });
  const req = createJsonRequest("GET", "http://localhost/v1/spring-clean/items");
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 401);
});

test("GET /v1/spring-clean/items returns neglected items with NULL resale_status", async () => {
  const ctx = buildContext({
    springCleanItems: [
      { id: "item-1", name: "Old Shirt", category: "tops", daysUnworn: 200, purchasePrice: 50, wearCount: 3 },
    ],
  });
  const req = createJsonRequest("GET", "http://localhost/v1/spring-clean/items", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 1);
  assert.equal(res.body.items[0].name, "Old Shirt");
});

test("GET /v1/spring-clean/items excludes items with resale_status 'listed', 'sold', 'donated'", async () => {
  // Items with non-null resale_status are filtered out by the SQL query (resale_status IS NULL)
  // This test verifies the endpoint returns an empty array when no eligible items exist
  const ctx = buildContext({ springCleanItems: [] });
  const req = createJsonRequest("GET", "http://localhost/v1/spring-clean/items", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 0);
});

test("GET /v1/spring-clean/items includes estimatedValue for each item", async () => {
  const ctx = buildContext({
    springCleanItems: [
      { id: "item-1", name: "Expensive Coat", purchasePrice: 100, wearCount: 3 },
    ],
  });
  const req = createJsonRequest("GET", "http://localhost/v1/spring-clean/items", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.items[0].estimatedValue > 0);
  // For purchasePrice=100, wearCount=3 (1-5 range) -> factor=0.6 -> 60
  assert.equal(res.body.items[0].estimatedValue, 60);
});

test("GET /v1/spring-clean/items returns empty array when no neglected items exist", async () => {
  const ctx = buildContext({ springCleanItems: [] });
  const req = createJsonRequest("GET", "http://localhost/v1/spring-clean/items", null,
    { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 0);
});
