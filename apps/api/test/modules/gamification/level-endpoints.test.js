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
  levelResult = null,
  levelShouldFail = false,
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
    levelService: levelShouldFail ? {
      async recalculateLevel() {
        throw new Error("Level service unavailable");
      },
    } : {
      async recalculateLevel() {
        return levelResult || {
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
  };
}

// --- POST /v1/items with level data ---

test("POST /v1/items response includes levelUp: null when no level change", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({
    levelResult: {
      currentLevel: 1,
      currentLevelName: "Closet Rookie",
      previousLevel: 1,
      previousLevelName: "Closet Rookie",
      leveledUp: false,
      itemCount: 5,
      nextLevelThreshold: 10,
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.equal(res.body.levelUp, null);
});

test("POST /v1/items response includes levelUp object when level changes", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({
    levelResult: {
      currentLevel: 2,
      currentLevelName: "Style Starter",
      previousLevel: 1,
      previousLevelName: "Closet Rookie",
      leveledUp: true,
      itemCount: 10,
      nextLevelThreshold: 25,
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.ok(res.body.levelUp);
  assert.equal(res.body.levelUp.newLevel, 2);
  assert.equal(res.body.levelUp.newLevelName, "Style Starter");
  assert.equal(res.body.levelUp.previousLevel, 1);
  assert.equal(res.body.levelUp.previousLevelName, "Closet Rookie");
});

// --- GET /v1/user-stats with level fields ---

test("GET /v1/user-stats includes currentLevel, currentLevelName, nextLevelThreshold, itemCount", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext({
    userStats: {
      totalPoints: 50,
      currentStreak: 2,
      longestStreak: 5,
      lastStreakDate: "2026-03-19",
      streakFreezeUsedAt: null,
      currentLevel: 3,
      currentLevelName: "Fashion Explorer",
      nextLevelThreshold: 50,
      itemCount: 30,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.currentLevel, 3);
  assert.equal(res.body.stats.currentLevelName, "Fashion Explorer");
  assert.equal(res.body.stats.nextLevelThreshold, 50);
  assert.equal(res.body.stats.itemCount, 30);
});

test("GET /v1/user-stats returns defaults for new user (level 1, Closet Rookie, threshold 10)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.currentLevel, 1);
  assert.equal(res.body.stats.currentLevelName, "Closet Rookie");
  assert.equal(res.body.stats.nextLevelThreshold, 10);
  assert.equal(res.body.stats.itemCount, 0);
});

// --- Level-up detection on 10th item ---

test("Level-up is correctly detected when adding the 10th item", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Item 10",
  });

  await handleRequest(req, res, buildContext({
    levelResult: {
      currentLevel: 2,
      currentLevelName: "Style Starter",
      previousLevel: 1,
      previousLevelName: "Closet Rookie",
      leveledUp: true,
      itemCount: 10,
      nextLevelThreshold: 25,
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.levelUp);
  assert.equal(res.body.levelUp.newLevel, 2);
  assert.equal(res.body.levelUp.newLevelName, "Style Starter");
});

// --- Level failure does not break item creation ---

test("Level data failure does not break item creation (item still returned)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({ levelShouldFail: true }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.equal(res.body.item.id, "item-123");
  assert.equal(res.body.levelUp, null);
});
