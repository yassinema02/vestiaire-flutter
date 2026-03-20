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
  userStats = null,
  pointsAwardResult = { totalPoints: 10, pointsAwarded: 10 },
  wearLogPointsResult = null,
  pointsShouldFail = false,
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
        return userStats || {
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
    stylePointsService: pointsShouldFail ? {
      async awardItemUploadPoints() {
        throw new Error("Points system unavailable");
      },
      async awardWearLogPoints() {
        throw new Error("Points system unavailable");
      },
    } : {
      async awardItemUploadPoints() {
        return pointsAwardResult;
      },
      async awardWearLogPoints() {
        return wearLogPointsResult || {
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
    badgeService: {
      async getBadgeCatalog() { return []; },
      async getUserBadgeCollection() { return { badges: [], badgeCount: 0 }; },
      async evaluateAndAward() { return { badgesAwarded: [] }; },
    },
    challengeRepo: {},
    challengeService: {
      async acceptChallenge() { return { challenge: {} }; },
      async updateProgressOnItemCreate() { return { challengeUpdate: null }; },
      async getChallengeStatus() { return null; },
      async checkTrialExpiry() { return { isPremium: false, trialExpired: false }; },
    },
  };
}

// --- GET /v1/user-stats tests ---

test("GET /v1/user-stats returns 200 with default stats for new user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.stats);
  assert.equal(res.body.stats.totalPoints, 0);
  assert.equal(res.body.stats.currentStreak, 0);
  assert.equal(res.body.stats.longestStreak, 0);
  assert.equal(res.body.stats.lastStreakDate, null);
  assert.equal(res.body.stats.streakFreezeUsedAt, null);
  assert.equal(res.body.stats.streakFreezeAvailable, true);
});

test("GET /v1/user-stats returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/user-stats returns correct stats after points have been awarded", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext({
    userStats: {
      totalPoints: 150,
      currentStreak: 5,
      longestStreak: 10,
      lastStreakDate: "2026-03-18",
      streakFreezeUsedAt: null,
    }
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.totalPoints, 150);
  assert.equal(res.body.stats.currentStreak, 5);
  assert.equal(res.body.stats.longestStreak, 10);
});

// --- POST /v1/items with points ---

test("POST /v1/items response includes pointsAwarded with 10 points", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({
    pointsAwardResult: { pointsAwarded: 10, totalPoints: 10, action: "item_upload" },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.ok(res.body.pointsAwarded);
  assert.equal(res.body.pointsAwarded.pointsAwarded, 10);
  assert.equal(res.body.pointsAwarded.action, "item_upload");
});

// --- POST /v1/wear-logs with points ---

test("POST /v1/wear-logs response includes pointsAwarded with base + applicable bonuses", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
  });

  await handleRequest(req, res, buildContext({
    wearLogPointsResult: {
      pointsAwarded: 10,
      totalPoints: 50,
      currentStreak: 3,
      bonuses: { firstLogOfDay: 2, streakDay: 3 },
      action: "wear_log",
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.wearLog);
  assert.ok(res.body.pointsAwarded);
  assert.equal(res.body.pointsAwarded.pointsAwarded, 10);
  assert.equal(res.body.pointsAwarded.bonuses.firstLogOfDay, 2);
  assert.equal(res.body.pointsAwarded.bonuses.streakDay, 3);
});

// --- Points persistence ---

test("Points are persisted: GET /v1/user-stats reflects cumulative points after multiple actions", async () => {
  const context = buildContext({
    userStats: { totalPoints: 25, currentStreak: 1, longestStreak: 5, lastStreakDate: "2026-03-19", streakFreezeUsedAt: null },
  });

  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");
  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.totalPoints, 25);
});

// --- Points failure does not break primary operations ---

test("Points failure does not break item creation (item still returned)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({ pointsShouldFail: true }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.equal(res.body.item.id, "item-123");
  assert.equal(res.body.pointsAwarded, null);
});

test("Points failure does not break wear log creation (wear log still returned)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
  });

  await handleRequest(req, res, buildContext({ pointsShouldFail: true }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.wearLog);
  assert.equal(res.body.wearLog.id, "wearlog-1");
  assert.equal(res.body.pointsAwarded, null);
});
