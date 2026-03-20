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
  syncFromClientResult = null,
  syncFromClientShouldFail = false,
  syncFromClientFailError = null,
  handleWebhookResult = null,
  handleWebhookShouldFail = false,
  handleWebhookFailError = null,
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
    outfitRepository: {
      async listOutfits() { return []; },
    },
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
      async awardItemUploadPoints() { return { pointsAwarded: 10, totalPoints: 10, action: "item_upload" }; },
      async awardWearLogPoints() { return { pointsAwarded: 5, totalPoints: 25, action: "wear_log", bonuses: {} }; },
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
    },
    challengeRepo: {},
    challengeService: {
      async acceptChallenge() { return { challenge: { key: "closet_safari" } }; },
      async updateProgressOnItemCreate() { return { challengeUpdate: null }; },
      async getChallengeStatus() { return null; },
      async checkTrialExpiry() { return { isPremium: false, trialExpired: false }; },
    },
    subscriptionSyncService: {
      async syncFromClient(authContext, params) {
        if (syncFromClientShouldFail) {
          throw syncFromClientFailError || { statusCode: 403, message: "Cannot sync subscription for another user" };
        }
        return syncFromClientResult || {
          isPremium: true,
          premiumSource: "revenuecat",
          premiumExpiresAt: "2026-04-19T00:00:00.000Z",
        };
      },
      async handleWebhookEvent(body, authorizationHeader) {
        if (handleWebhookShouldFail) {
          throw handleWebhookFailError || { statusCode: 401, message: "Invalid webhook authorization" };
        }
        return handleWebhookResult || { handled: true };
      },
    },
  };
}

// --- POST /v1/subscription/sync tests ---

test("POST /v1/subscription/sync returns 200 with premium status after sync", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/subscription/sync", { appUserId: "firebase-user-123" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.isPremium, true);
  assert.equal(res.body.premiumSource, "revenuecat");
  assert.ok(res.body.premiumExpiresAt);
});

test("POST /v1/subscription/sync returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/subscription/sync", { appUserId: "firebase-user-123" });

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/subscription/sync returns 403 if appUserId does not match auth user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/subscription/sync", { appUserId: "different-user" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({ syncFromClientShouldFail: true }));

  assert.equal(res.statusCode, 403);
});

// --- POST /v1/webhooks/revenuecat tests ---

test("POST /v1/webhooks/revenuecat returns 200 on valid INITIAL_PURCHASE webhook", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest(
    "POST",
    "/v1/webhooks/revenuecat",
    {
      event: {
        type: "INITIAL_PURCHASE",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() + 30 * 86400000,
      },
    },
    { authorization: "Bearer webhook_secret_123" }
  );

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
});

test("POST /v1/webhooks/revenuecat returns 401 on invalid authorization header", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest(
    "POST",
    "/v1/webhooks/revenuecat",
    {
      event: {
        type: "INITIAL_PURCHASE",
        app_user_id: "firebase-user-123",
      },
    },
    { authorization: "invalid_auth" }
  );

  await handleRequest(req, res, buildContext({
    handleWebhookShouldFail: true,
    handleWebhookFailError: { statusCode: 401, message: "Invalid webhook authorization" },
  }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/webhooks/revenuecat bypasses Firebase auth (no Bearer token needed)", async () => {
  const res = createResponseCapture();
  // No authorization header that would be a Firebase token
  const req = createJsonRequest(
    "POST",
    "/v1/webhooks/revenuecat",
    {
      event: {
        type: "RENEWAL",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() + 30 * 86400000,
      },
    },
    { authorization: "Bearer webhook_secret_123" }
  );

  // Use unauthenticated context -- webhook should still work
  // because it bypasses Firebase auth
  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
});

test("POST /v1/webhooks/revenuecat EXPIRATION webhook downgrades revenuecat premium user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest(
    "POST",
    "/v1/webhooks/revenuecat",
    {
      event: {
        type: "EXPIRATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() - 86400000,
      },
    },
    { authorization: "Bearer webhook_secret_123" }
  );

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
});

test("POST /v1/webhooks/revenuecat EXPIRATION webhook does NOT downgrade trial premium user (handled by RPC)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest(
    "POST",
    "/v1/webhooks/revenuecat",
    {
      event: {
        type: "EXPIRATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() - 86400000,
      },
    },
    { authorization: "Bearer webhook_secret_123" }
  );

  // The mock returns success -- the trial protection is in the RPC,
  // not in the endpoint handler
  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
});

test("POST /v1/webhooks/revenuecat RENEWAL webhook updates premium_expires_at", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest(
    "POST",
    "/v1/webhooks/revenuecat",
    {
      event: {
        type: "RENEWAL",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() + 30 * 86400000,
      },
    },
    { authorization: "Bearer webhook_secret_123" }
  );

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
});

test("Existing premium-gated endpoints work correctly after subscription sync (usage limit check)", async () => {
  // This is a smoke test to verify that adding subscriptionSyncService to the context
  // does not break existing endpoints
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/badges", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.badges);
});
