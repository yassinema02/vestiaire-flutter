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
  challengeAcceptResult = null,
  challengeUpdateResult = null,
  challengeStatusResult = null,
  challengeAcceptShouldFail = false,
  challengeUpdateShouldFail = false,
  challengeStatusShouldFail = false,
  trialExpiryResult = null,
  userStats = null,
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
      async createWearLog(authContext, { itemIds }) {
        return {
          id: "wearlog-1",
          profileId: "profile-uuid-1",
          loggedDate: "2026-03-19",
          itemIds,
        };
      },
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
    stylePointsService: {
      async awardItemUploadPoints() {
        return { pointsAwarded: 10, totalPoints: 10, action: "item_upload" };
      },
      async awardWearLogPoints() {
        return { pointsAwarded: 5, totalPoints: 25, action: "wear_log", bonuses: {} };
      },
    },
    levelService: {
      async recalculateLevel() {
        return { currentLevel: 1, currentLevelName: "Closet Rookie", previousLevel: 1, previousLevelName: "Closet Rookie", leveledUp: false };
      },
    },
    streakService: {
      async evaluateStreak() {
        return { currentStreak: 1, longestStreak: 1, lastStreakDate: "2026-03-19", streakExtended: false, isNewStreak: true, streakFreezeAvailable: true };
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
      async acceptChallenge(authContext, challengeKey) {
        if (challengeAcceptShouldFail) {
          throw { statusCode: 404, message: `Unknown challenge: ${challengeKey}` };
        }
        return challengeAcceptResult || {
          challenge: {
            key: "closet_safari",
            name: "Closet Safari",
            status: "active",
            acceptedAt: "2026-03-19T10:00:00Z",
            expiresAt: "2026-03-26T10:00:00Z",
            currentProgress: 5,
            targetCount: 20,
            timeRemainingSeconds: 604800,
          },
        };
      },
      async updateProgressOnItemCreate(authContext) {
        if (challengeUpdateShouldFail) {
          throw new Error("Challenge update failed");
        }
        return challengeUpdateResult || { challengeUpdate: null };
      },
      async getChallengeStatus(authContext) {
        if (challengeStatusShouldFail) {
          throw new Error("Challenge status failed");
        }
        return challengeStatusResult || null;
      },
      async checkTrialExpiry(authContext) {
        return trialExpiryResult || { isPremium: false, trialExpired: false };
      },
    },
  };
}

// --- POST /v1/challenges/closet_safari/accept tests ---

test("POST /v1/challenges/closet_safari/accept returns 200 with challenge state", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/challenges/closet_safari/accept");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.challenge);
  assert.equal(res.body.challenge.key, "closet_safari");
  assert.equal(res.body.challenge.status, "active");
  assert.equal(res.body.challenge.targetCount, 20);
});

test("POST /v1/challenges/closet_safari/accept returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/challenges/closet_safari/accept", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
});

test("POST /v1/challenges/unknown_key/accept returns 404", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/challenges/unknown_key/accept");

  await handleRequest(req, res, buildContext({ challengeAcceptShouldFail: true }));

  assert.equal(res.statusCode, 404);
});

test("POST /v1/challenges/closet_safari/accept is idempotent", async () => {
  const res1 = createResponseCapture();
  const req1 = createJsonRequest("POST", "/v1/challenges/closet_safari/accept");
  const ctx = buildContext();

  await handleRequest(req1, res1, ctx);
  assert.equal(res1.statusCode, 200);

  const res2 = createResponseCapture();
  const req2 = createJsonRequest("POST", "/v1/challenges/closet_safari/accept");
  await handleRequest(req2, res2, ctx);
  assert.equal(res2.statusCode, 200);
  assert.equal(res2.body.challenge.key, "closet_safari");
});

// --- POST /v1/items with challengeUpdate tests ---

test("POST /v1/items response includes challengeUpdate when active challenge exists", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext({
    challengeUpdateResult: {
      challengeUpdate: {
        key: "closet_safari",
        currentProgress: 10,
        targetCount: 20,
        completed: false,
        rewardGranted: false,
        timeRemainingSeconds: 500000,
      },
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.ok(res.body.challengeUpdate);
  assert.equal(res.body.challengeUpdate.key, "closet_safari");
  assert.equal(res.body.challengeUpdate.currentProgress, 10);
});

test("POST /v1/items response has challengeUpdate: null when no active challenge", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg",
    name: "Test Item",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.equal(res.body.challengeUpdate, null);
});

// --- GET /v1/user-stats with challenge tests ---

test("GET /v1/user-stats includes challenge object when challenge accepted", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext({
    challengeStatusResult: {
      key: "closet_safari",
      name: "Closet Safari",
      status: "active",
      currentProgress: 8,
      targetCount: 20,
      expiresAt: "2026-03-26T10:00:00Z",
      timeRemainingSeconds: 500000,
      reward: { type: "premium_trial", value: 30, description: "1 month Premium free" },
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.stats.challenge);
  assert.equal(res.body.stats.challenge.key, "closet_safari");
  assert.equal(res.body.stats.challenge.currentProgress, 8);
});

test("GET /v1/user-stats returns challenge: null when no challenge", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.stats.challenge, null);
});

// --- Challenge progress across multiple item uploads ---

test("Challenge progress increments correctly across multiple item uploads", async () => {
  let progressCount = 5;
  const ctx = buildContext({
    challengeUpdateResult: null, // Will be overridden
  });
  ctx.challengeService.updateProgressOnItemCreate = async () => {
    progressCount++;
    return {
      challengeUpdate: {
        key: "closet_safari",
        currentProgress: progressCount,
        targetCount: 20,
        completed: false,
        rewardGranted: false,
        timeRemainingSeconds: 500000,
      },
    };
  };

  const res1 = createResponseCapture();
  const req1 = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo1.jpg", name: "Item 1",
  });
  await handleRequest(req1, res1, ctx);
  assert.equal(res1.body.challengeUpdate.currentProgress, 6);

  const res2 = createResponseCapture();
  const req2 = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo2.jpg", name: "Item 2",
  });
  await handleRequest(req2, res2, ctx);
  assert.equal(res2.body.challengeUpdate.currentProgress, 7);
});

// --- Challenge completion triggers premium trial grant ---

test("Challenge completion triggers premium trial grant (completed=true, rewardGranted=true)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg", name: "Item 20",
  });

  await handleRequest(req, res, buildContext({
    challengeUpdateResult: {
      challengeUpdate: {
        key: "closet_safari",
        currentProgress: 20,
        targetCount: 20,
        completed: true,
        rewardGranted: true,
        timeRemainingSeconds: 300000,
      },
    },
  }));

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.challengeUpdate.completed, true);
  assert.equal(res.body.challengeUpdate.rewardGranted, true);
});

// --- Challenge update failure does not break item creation ---

test("Challenge update failure does not break item creation", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://example.com/photo.jpg", name: "Test Item",
  });

  await handleRequest(req, res, buildContext({
    challengeUpdateShouldFail: true,
  }));

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.item);
  assert.equal(res.body.item.id, "item-123");
  assert.equal(res.body.challengeUpdate, null);
});

// --- Challenge status failure does not break user stats ---

test("Challenge status failure does not break GET /v1/user-stats", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/user-stats");

  await handleRequest(req, res, buildContext({
    challengeStatusShouldFail: true,
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.stats);
  assert.equal(res.body.stats.challenge, null);
});
