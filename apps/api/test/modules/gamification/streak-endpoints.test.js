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
  streakResult = null,
  streakShouldFail = false,
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
        return { item: { id: "item-123", profileId: "profile-uuid-1", photoUrl: params.photoUrl, name: params.name } };
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
    outfitRepository: { async listOutfits() { return []; } },
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
      async awardItemUploadPoints() { throw new Error("Points system unavailable"); },
      async awardWearLogPoints() { throw new Error("Points system unavailable"); },
    } : {
      async awardItemUploadPoints() {
        return { pointsAwarded: 10, totalPoints: 10, action: "item_upload" };
      },
      async awardWearLogPoints(authContext, opts = {}) {
        return wearLogPointsResult || {
          pointsAwarded: opts?.isStreakDay ? 8 : 5,
          totalPoints: 25,
          currentStreak: streakResult?.currentStreak ?? 0,
          bonuses: { firstLogOfDay: 0, streakDay: opts?.isStreakDay ? 3 : 0 },
          action: "wear_log",
        };
      },
    },
    levelService: {
      async recalculateLevel() {
        return {
          currentLevel: 1, currentLevelName: "Closet Rookie",
          previousLevel: 1, previousLevelName: "Closet Rookie",
          leveledUp: false, itemCount: 1, nextLevelThreshold: 10,
        };
      },
    },
    streakService: streakShouldFail ? {
      async evaluateStreak() { throw new Error("Streak system unavailable"); },
      async getStreakFreezeStatus() { throw new Error("Streak system unavailable"); },
    } : {
      async evaluateStreak() {
        return streakResult || {
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
  };
}

// --- POST /v1/wear-logs with streakUpdate ---

test("POST /v1/wear-logs response includes streakUpdate object", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", { items: ["item-1"] });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.wearLog);
  assert.ok(res.body.streakUpdate);
  assert.equal(typeof res.body.streakUpdate.currentStreak, "number");
  assert.equal(typeof res.body.streakUpdate.longestStreak, "number");
  assert.equal(typeof res.body.streakUpdate.isNewStreak, "boolean");
  assert.equal(typeof res.body.streakUpdate.streakExtended, "boolean");
  assert.equal(typeof res.body.streakUpdate.streakFreezeAvailable, "boolean");
});

test("POST /v1/wear-logs on consecutive days extends streak (streakExtended=true)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", { items: ["item-1"] });

  await handleRequest(req, res, buildContext({
    streakResult: {
      currentStreak: 5,
      longestStreak: 10,
      lastStreakDate: "2026-03-19",
      streakFreezeUsedAt: null,
      streakExtended: true,
      isNewStreak: false,
      freezeUsed: false,
      streakFreezeAvailable: true,
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.streakUpdate.streakExtended, true);
  assert.equal(res.body.streakUpdate.currentStreak, 5);
  assert.equal(res.body.streakUpdate.isNewStreak, false);
});

test("POST /v1/wear-logs after gap resets streak (isNewStreak=true)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", { items: ["item-1"] });

  await handleRequest(req, res, buildContext({
    streakResult: {
      currentStreak: 1,
      longestStreak: 10,
      lastStreakDate: "2026-03-19",
      streakFreezeUsedAt: null,
      streakExtended: false,
      isNewStreak: true,
      freezeUsed: false,
      streakFreezeAvailable: true,
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.streakUpdate.isNewStreak, true);
  assert.equal(res.body.streakUpdate.currentStreak, 1);
});

// --- GET /v1/user-stats with freeze fields ---

test("GET /v1/user-stats includes streakFreezeAvailable and streakFreezeUsedAt", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.stats);
  assert.equal(typeof res.body.stats.streakFreezeAvailable, "boolean");
  assert.equal(res.body.stats.streakFreezeAvailable, true);
});

test("GET /v1/user-stats returns streakFreezeAvailable=true for new user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.streakFreezeAvailable, true);
  assert.equal(res.body.stats.streakFreezeUsedAt, null);
});

test("GET /v1/user-stats returns streakFreezeAvailable=false when freeze used this week", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext({
    userStats: {
      totalPoints: 50,
      currentStreak: 3,
      longestStreak: 5,
      lastStreakDate: "2026-03-18",
      streakFreezeUsedAt: "2026-03-17",
      streakFreezeAvailable: false,
      currentLevel: 1,
      currentLevelName: "Closet Rookie",
      nextLevelThreshold: 10,
      itemCount: 5,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.streakFreezeAvailable, false);
  assert.equal(res.body.stats.streakFreezeUsedAt, "2026-03-17");
});

// --- Points streak bonus alignment ---

test("Points streak bonus (+3) aligns with streak evaluation (streakExtended=true => +3 bonus)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", { items: ["item-1"] });

  await handleRequest(req, res, buildContext({
    streakResult: {
      currentStreak: 5,
      longestStreak: 5,
      lastStreakDate: "2026-03-19",
      streakFreezeUsedAt: null,
      streakExtended: true,
      isNewStreak: false,
      freezeUsed: false,
      streakFreezeAvailable: true,
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.pointsAwarded);
  assert.equal(res.body.pointsAwarded.bonuses.streakDay, 3);
  assert.equal(res.body.pointsAwarded.pointsAwarded, 8); // 5 base + 3 streak
});

// --- Streak failure does not break wear log creation ---

test("Streak failure does not break wear log creation (wear log still returned)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", { items: ["item-1"] });

  await handleRequest(req, res, buildContext({ streakShouldFail: true }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.wearLog);
  assert.equal(res.body.wearLog.id, "wearlog-1");
  assert.equal(res.body.streakUpdate, null);
  // Points should still be awarded (without streak bonus)
  assert.ok(res.body.pointsAwarded);
});
