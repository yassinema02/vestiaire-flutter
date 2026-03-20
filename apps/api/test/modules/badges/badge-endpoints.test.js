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
    }
  };
}

function createJsonRequest(method, url, body, includeAuth = true) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json"
  };
  if (includeAuth) {
    stream.headers.authorization = "Bearer signed.jwt.token";
  }
  return stream;
}

function buildContext({
  authenticated = true,
  badgeCatalog = [],
  userBadges = [],
  userBadgeCount = 0,
  evaluateResult = [],
  badgeShouldFail = false,
} = {}) {
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
          provider: "google.com"
        };
      }
    },
    profileService: {},
    itemService: {
      async createItemForUser(authContext, params) {
        return {
          item: {
            id: "item-123",
            profileId: "profile-uuid-1",
            photoUrl: params.photoUrl,
            name: params.name,
          }
        };
      },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(authContext, itemId) { return { item: { id: itemId } }; },
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {},
    outfitRepository: {
      async listOutfits() { return []; },
    },
    usageLimitService: {},
    wearLogRepository: {
      async createWearLog(authContext, { itemIds, outfitId, photoUrl, loggedDate }) {
        return {
          id: "wearlog-1",
          profileId: "profile-uuid-1",
          loggedDate: loggedDate || "2026-03-19",
          outfitId: outfitId || null,
          photoUrl: photoUrl || null,
          createdAt: new Date().toISOString(),
          itemIds,
        };
      },
      async listWearLogs() { return []; },
    },
    analyticsRepository: {},
    analyticsSummaryService: {},
    userStatsRepo: {
      async getUserStats() {
        return {
          totalPoints: 0,
          currentStreak: 0,
          longestStreak: 0,
          lastStreakDate: null,
          streakFreezeUsedAt: null,
          streakFreezeAvailable: true,
          currentLevel: 1,
          currentLevelName: "Closet Rookie",
          nextLevelThreshold: 10,
          itemCount: 0,
        };
      },
    },
    stylePointsService: {
      async awardItemUploadPoints() {
        return { pointsAwarded: 10, totalPoints: 10, action: "item_upload" };
      },
      async awardWearLogPoints() {
        return {
          pointsAwarded: 5,
          totalPoints: 25,
          currentStreak: 0,
          bonuses: { firstLogOfDay: 0, streakDay: 0 },
          action: "wear_log",
        };
      },
    },
    levelService: {
      async recalculateLevel() {
        return {
          currentLevel: 1,
          currentLevelName: "Closet Rookie",
          previousLevel: 1,
          previousLevelName: "Closet Rookie",
          leveledUp: false,
          itemCount: 1,
          nextLevelThreshold: 10,
        };
      },
    },
    streakService: {
      async evaluateStreak() {
        return {
          currentStreak: 1,
          longestStreak: 1,
          lastStreakDate: "2026-03-19",
          streakFreezeUsedAt: null,
          streakExtended: false,
          isNewStreak: true,
          freezeUsed: false,
          streakFreezeAvailable: true,
        };
      },
      async getStreakFreezeStatus() {
        return { streakFreezeAvailable: true, streakFreezeUsedAt: null };
      },
    },
    badgeRepo: {},
    badgeService: badgeShouldFail ? {
      async getBadgeCatalog() { throw new Error("Badge service unavailable"); },
      async getUserBadgeCollection() { throw new Error("Badge service unavailable"); },
      async evaluateAndAward() { throw new Error("Badge service unavailable"); },
    } : {
      async getBadgeCatalog() { return badgeCatalog; },
      async getUserBadgeCollection() { return { badges: userBadges, badgeCount: userBadgeCount }; },
      async evaluateAndAward() { return { badgesAwarded: evaluateResult }; },
    },
  };
}

// --- GET /v1/badges tests ---

test("GET /v1/badges returns 200 with all 15 badge definitions", async () => {
  const catalog = Array.from({ length: 15 }, (_, i) => ({
    key: `badge_${i + 1}`,
    name: `Badge ${i + 1}`,
    description: `Description ${i + 1}`,
    iconName: "star",
    iconColor: "#FBBF24",
    category: "wardrobe",
    sortOrder: i + 1,
  }));

  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/badges");

  await handleRequest(req, res, buildContext({ badgeCatalog: catalog }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.badges);
  assert.equal(res.body.badges.length, 15);
});

test("GET /v1/badges returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/badges", null, false);

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

// --- GET /v1/user-stats with badges ---

test("GET /v1/user-stats includes badges array and badgeCount", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext({
    userBadges: [{ key: "first_step", name: "First Step" }],
    userBadgeCount: 1,
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.stats.badges);
  assert.equal(res.body.stats.badges.length, 1);
  assert.equal(res.body.stats.badgeCount, 1);
});

test("GET /v1/user-stats returns empty badges for new user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.stats.badges, []);
  assert.equal(res.body.stats.badgeCount, 0);
});

// --- POST /v1/items with badgesAwarded ---

test("POST /v1/items response includes badgesAwarded (e.g., first_step badge on first item)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({
    evaluateResult: [{ key: "first_step", name: "First Step", description: "Upload first item", iconName: "star", iconColor: "#FBBF24" }],
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.badgesAwarded);
  assert.equal(res.body.badgesAwarded.length, 1);
  assert.equal(res.body.badgesAwarded[0].key, "first_step");
});

// --- POST /v1/wear-logs with badgesAwarded ---

test("POST /v1/wear-logs response includes badgesAwarded", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
  });

  await handleRequest(req, res, buildContext({
    evaluateResult: [{ key: "week_warrior", name: "Week Warrior", description: "d", iconName: "fire", iconColor: "#F97316" }],
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.badgesAwarded);
  assert.equal(res.body.badgesAwarded.length, 1);
  assert.equal(res.body.badgesAwarded[0].key, "week_warrior");
});

// --- Badge failure does not break primary operations ---

test("Badge evaluation failure does not break item creation", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({ badgeShouldFail: true }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.equal(res.body.item.id, "item-123");
  assert.equal(res.body.badgesAwarded, null);
});

test("Badge evaluation failure does not break wear log creation", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
  });

  await handleRequest(req, res, buildContext({ badgeShouldFail: true }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.wearLog);
  assert.equal(res.body.wearLog.id, "wearlog-1");
  assert.equal(res.body.badgesAwarded, null);
});

// --- evaluate_badges idempotent ---

test("evaluate_badges RPC does not re-award already earned badges (returns empty on second call)", async () => {
  const callCount = { n: 0 };
  const context = buildContext();
  context.badgeService = {
    async getBadgeCatalog() { return []; },
    async getUserBadgeCollection() { return { badges: [], badgeCount: 0 }; },
    async evaluateAndAward() {
      callCount.n++;
      // First call awards, second call returns empty (idempotent)
      if (callCount.n === 1) {
        return { badgesAwarded: [{ key: "first_step", name: "First Step", description: "d", iconName: "star", iconColor: "#FBBF24" }] };
      }
      return { badgesAwarded: [] };
    },
  };

  // First call
  const res1 = createResponseCapture();
  const req1 = createJsonRequest("POST", "/v1/items", { photoUrl: "https://example.com/photo.jpg", name: "Test" });
  await handleRequest(req1, res1, context);
  assert.equal(res1.body.badgesAwarded.length, 1);

  // Second call (same conditions) returns empty
  const res2 = createResponseCapture();
  const req2 = createJsonRequest("POST", "/v1/items", { photoUrl: "https://example.com/photo2.jpg", name: "Test2" });
  await handleRequest(req2, res2, context);
  assert.equal(res2.body.badgesAwarded.length, 0);
});
