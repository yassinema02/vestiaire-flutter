import assert from "node:assert/strict";
import test from "node:test";
import { createPremiumGuard, FREE_LIMITS } from "../../../src/modules/billing/premium-guard.js";

// --- Test helpers ---

function createMockPool({
  profileRows = [{ id: "profile-uuid-1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }],
  countResult = 0,
} = {}) {
  const queries = [];
  return {
    queries,
    connect() {
      return Promise.resolve({
        query(sql, params) {
          queries.push({ sql, params });

          // set_config
          if (sql.includes("set_config")) {
            return { rows: [] };
          }

          // profile lookup
          if (sql.includes("app_public.profiles")) {
            return { rows: profileRows };
          }

          // count query
          if (sql.includes("COUNT")) {
            return { rows: [{ count: countResult }] };
          }

          return { rows: [] };
        },
        release() {},
      });
    },
  };
}

function createMockSubscriptionSyncService({ shouldThrow = false } = {}) {
  const calls = [];
  return {
    calls,
    async syncFromClient(authContext, options) {
      calls.push({ authContext, options });
      if (shouldThrow) {
        throw new Error("Sync failed");
      }
      return { isPremium: false, premiumSource: null };
    },
  };
}

function createMockChallengeService({ shouldThrow = false } = {}) {
  const calls = [];
  return {
    calls,
    async checkTrialExpiry(authContext) {
      calls.push(authContext);
      if (shouldThrow) {
        throw new Error("Trial check failed");
      }
    },
  };
}

const authContext = { userId: "firebase-user-123" };

// --- checkPremium tests ---

test("checkPremium returns { isPremium: true } for premium user", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: true, premium_source: "revenuecat", premium_expires_at: "2099-01-01T00:00:00Z", premium_trial_expires_at: null }],
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkPremium(authContext);

  assert.equal(result.isPremium, true);
  assert.equal(result.profileId, "p1");
  assert.equal(result.premiumSource, "revenuecat");
});

test("checkPremium returns { isPremium: false } for free user", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }],
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkPremium(authContext);

  assert.equal(result.isPremium, false);
  assert.equal(result.profileId, "p1");
  assert.equal(result.premiumSource, null);
});

test("checkPremium performs lazy subscription expiry: calls sync when premium_expires_at is past", async () => {
  // First query returns premium with expired date, second query (after sync) returns non-premium
  let queryCount = 0;
  const pool = {
    connect() {
      return Promise.resolve({
        query(sql) {
          if (sql.includes("set_config")) return { rows: [] };
          if (sql.includes("app_public.profiles")) {
            queryCount++;
            if (queryCount === 1) {
              return { rows: [{ id: "p1", is_premium: true, premium_source: "revenuecat", premium_expires_at: "2020-01-01T00:00:00Z", premium_trial_expires_at: null }] };
            }
            // After sync, profile is downgraded
            return { rows: [{ id: "p1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }] };
          }
          return { rows: [] };
        },
        release() {},
      });
    },
  };

  const syncService = createMockSubscriptionSyncService();
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: syncService,
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkPremium(authContext);

  assert.equal(syncService.calls.length, 1);
  assert.equal(result.isPremium, false);
});

test("checkPremium performs lazy subscription expiry: does NOT call sync when premium_expires_at is future", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: true, premium_source: "revenuecat", premium_expires_at: "2099-01-01T00:00:00Z", premium_trial_expires_at: null }],
  });
  const syncService = createMockSubscriptionSyncService();
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: syncService,
    challengeService: createMockChallengeService(),
  });

  await guard.checkPremium(authContext);

  assert.equal(syncService.calls.length, 0);
});

test("checkPremium performs trial expiry check best-effort (calls challengeService.checkTrialExpiry)", async () => {
  const pool = createMockPool();
  const challengeService = createMockChallengeService();
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService,
  });

  await guard.checkPremium(authContext);

  assert.equal(challengeService.calls.length, 1);
  assert.equal(challengeService.calls[0].userId, "firebase-user-123");
});

test("checkPremium does not throw when trial expiry check fails", async () => {
  const pool = createMockPool();
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService({ shouldThrow: true }),
  });

  // Should not throw
  const result = await guard.checkPremium(authContext);
  assert.equal(result.isPremium, false);
});

test("checkPremium does not throw when lazy sync fails (graceful degradation)", async () => {
  // Profile shows expired premium, but sync fails -- should still return the re-queried profile
  let queryCount = 0;
  const pool = {
    connect() {
      return Promise.resolve({
        query(sql) {
          if (sql.includes("set_config")) return { rows: [] };
          if (sql.includes("app_public.profiles")) {
            queryCount++;
            // Both queries return the same expired premium (sync failed)
            return { rows: [{ id: "p1", is_premium: true, premium_source: "revenuecat", premium_expires_at: "2020-01-01T00:00:00Z", premium_trial_expires_at: null }] };
          }
          return { rows: [] };
        },
        release() {},
      });
    },
  };

  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService({ shouldThrow: true }),
    challengeService: createMockChallengeService(),
  });

  // Should not throw
  const result = await guard.checkPremium(authContext);
  // Profile still shows premium because sync failed and re-query returned same data
  assert.equal(result.isPremium, true);
});

test("checkPremium throws 401 when profile not found", async () => {
  const pool = createMockPool({ profileRows: [] });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  await assert.rejects(
    () => guard.checkPremium(authContext),
    (error) => {
      assert.equal(error.statusCode, 401);
      assert.equal(error.message, "Profile not found");
      return true;
    }
  );
});

// --- requirePremium tests ---

test("requirePremium throws 403 with PREMIUM_REQUIRED code for free user", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }],
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  await assert.rejects(
    () => guard.requirePremium(authContext),
    (error) => {
      assert.equal(error.statusCode, 403);
      assert.equal(error.code, "PREMIUM_REQUIRED");
      assert.ok(error.message.includes("Premium"));
      return true;
    }
  );
});

test("requirePremium returns premium info for premium user", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: true, premium_source: "revenuecat", premium_expires_at: "2099-01-01T00:00:00Z", premium_trial_expires_at: null }],
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.requirePremium(authContext);

  assert.equal(result.isPremium, true);
  assert.equal(result.profileId, "p1");
  assert.equal(result.premiumSource, "revenuecat");
});

// --- checkUsageQuota tests ---

test("checkUsageQuota returns unlimited for premium user", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: true, premium_source: "revenuecat", premium_expires_at: "2099-01-01T00:00:00Z", premium_trial_expires_at: null }],
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkUsageQuota(authContext, {
    feature: "outfit_generation",
    freeLimit: 3,
    period: "day",
  });

  assert.equal(result.allowed, true);
  assert.equal(result.isPremium, true);
  assert.equal(result.limit, null);
  assert.equal(result.remaining, null);
});

test("checkUsageQuota returns correct counts for free user with daily period", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }],
    countResult: 1,
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkUsageQuota(authContext, {
    feature: "outfit_generation",
    freeLimit: 3,
    period: "day",
  });

  assert.equal(result.allowed, true);
  assert.equal(result.isPremium, false);
  assert.equal(result.limit, 3);
  assert.equal(result.used, 1);
  assert.equal(result.remaining, 2);
  assert.ok(result.resetsAt);
});

test("checkUsageQuota returns correct counts for free user with monthly period", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }],
    countResult: 1,
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkUsageQuota(authContext, {
    feature: "resale_listing",
    freeLimit: 2,
    period: "month",
  });

  assert.equal(result.allowed, true);
  assert.equal(result.isPremium, false);
  assert.equal(result.limit, 2);
  assert.equal(result.used, 1);
  assert.equal(result.remaining, 1);
  assert.ok(result.resetsAt);
});

test("checkUsageQuota blocks when free limit is reached", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "p1", is_premium: false, premium_source: null, premium_expires_at: null, premium_trial_expires_at: null }],
    countResult: 3,
  });
  const guard = createPremiumGuard({
    pool,
    subscriptionSyncService: createMockSubscriptionSyncService(),
    challengeService: createMockChallengeService(),
  });

  const result = await guard.checkUsageQuota(authContext, {
    feature: "outfit_generation",
    freeLimit: 3,
    period: "day",
  });

  assert.equal(result.allowed, false);
  assert.equal(result.used, 3);
  assert.equal(result.remaining, 0);
});

// --- FREE_LIMITS constants ---

test("FREE_LIMITS constants match PRD values", () => {
  assert.equal(FREE_LIMITS.OUTFIT_GENERATION_DAILY, 3);
  assert.equal(FREE_LIMITS.SHOPPING_SCAN_DAILY, 3);
  assert.equal(FREE_LIMITS.RESALE_LISTING_MONTHLY, 2);
});

// --- Factory validation ---

test("createPremiumGuard throws when pool is not provided", () => {
  assert.throws(
    () => createPremiumGuard({ subscriptionSyncService: {}, challengeService: {} }),
    TypeError
  );
});
