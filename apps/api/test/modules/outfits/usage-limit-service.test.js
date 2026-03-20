import assert from "node:assert/strict";
import test from "node:test";
import { createUsageLimitService, FREE_DAILY_LIMIT } from "../../../src/modules/outfits/usage-limit-service.js";

/**
 * Create a mock premiumGuard that returns the specified premium status.
 */
function createMockPremiumGuard({ isPremium = false, profileId = "profile-uuid-1" } = {}) {
  return {
    async checkPremium() {
      return { isPremium, profileId, premiumSource: isPremium ? "revenuecat" : null };
    },
  };
}

/**
 * Create a mock pool that returns the given profile and count results.
 */
function createMockPool({
  profileRows = [{ id: "profile-uuid-1", is_premium: false }],
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

test("FREE_DAILY_LIMIT constant is exported and equals 3", () => {
  assert.equal(FREE_DAILY_LIMIT, 3);
});

test("checkUsageLimit returns allowed: true when free user has 0 generations today", async () => {
  const pool = createMockPool({ countResult: 0 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  assert.equal(result.allowed, true);
  assert.equal(result.isPremium, false);
  assert.equal(result.dailyLimit, 3);
  assert.equal(result.used, 0);
  assert.equal(result.remaining, 3);
  assert.ok(result.resetsAt);
});

test("checkUsageLimit returns allowed: true with correct remaining when free user has 1 generation today", async () => {
  const pool = createMockPool({ countResult: 1 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  assert.equal(result.allowed, true);
  assert.equal(result.remaining, 2);
  assert.equal(result.used, 1);
});

test("checkUsageLimit returns allowed: true with correct remaining when free user has 2 generations today", async () => {
  const pool = createMockPool({ countResult: 2 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  assert.equal(result.allowed, true);
  assert.equal(result.remaining, 1);
  assert.equal(result.used, 2);
});

test("checkUsageLimit returns allowed: false with remaining: 0 when free user has 3 generations today", async () => {
  const pool = createMockPool({ countResult: 3 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  assert.equal(result.allowed, false);
  assert.equal(result.remaining, 0);
  assert.equal(result.used, 3);
  assert.equal(result.dailyLimit, 3);
});

test("checkUsageLimit returns allowed: false when free user has > 3 generations today (edge case)", async () => {
  const pool = createMockPool({ countResult: 5 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  assert.equal(result.allowed, false);
  assert.equal(result.remaining, 0);
  assert.equal(result.used, 5);
});

test("checkUsageLimit returns allowed: true, isPremium: true when user is premium regardless of usage count", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "profile-uuid-1", is_premium: true }],
    countResult: 10,
  });
  const premiumGuard = createMockPremiumGuard({ isPremium: true });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  assert.equal(result.allowed, true);
  assert.equal(result.isPremium, true);
  assert.equal(result.dailyLimit, null);
  assert.equal(result.remaining, null);
  assert.equal(result.resetsAt, null);
});

test("checkUsageLimit only counts status: success entries (query uses status = success)", async () => {
  const pool = createMockPool({ countResult: 1 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  await service.checkUsageLimit({ userId: "firebase-user-123" });

  // Verify the count query includes status = 'success'
  const countQuery = pool.queries.find(q => q.sql.includes("COUNT"));
  assert.ok(countQuery);
  assert.ok(countQuery.sql.includes("status = 'success'"));
});

test("checkUsageLimit only counts entries from the current UTC day (query uses created_at >= todayStart)", async () => {
  const pool = createMockPool({ countResult: 0 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  await service.checkUsageLimit({ userId: "firebase-user-123" });

  const countQuery = pool.queries.find(q => q.sql.includes("COUNT"));
  assert.ok(countQuery);
  assert.ok(countQuery.sql.includes("created_at >= $2"));

  // The second param should be today's UTC start
  const todayStart = new Date().toISOString().split("T")[0] + "T00:00:00Z";
  assert.equal(countQuery.params[1], todayStart);
});

test("checkUsageLimit returns correct resetsAt timestamp (next UTC midnight)", async () => {
  const pool = createMockPool({ countResult: 0 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.checkUsageLimit({ userId: "firebase-user-123" });

  const todayStart = new Date().toISOString().split("T")[0] + "T00:00:00Z";
  const expectedResetsAt = new Date(new Date(todayStart).getTime() + 86400000).toISOString();
  assert.equal(result.resetsAt, expectedResetsAt);
});

test("getUsageAfterGeneration returns updated count after a new generation log entry", async () => {
  const pool = createMockPool({ countResult: 2 });
  const premiumGuard = createMockPremiumGuard({ isPremium: false });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.getUsageAfterGeneration({ userId: "firebase-user-123" });

  assert.equal(result.used, 2);
  assert.equal(result.remaining, 1);
  assert.equal(result.dailyLimit, 3);
  assert.equal(result.isPremium, false);
});

test("getUsageAfterGeneration returns premium usage for premium users", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "profile-uuid-1", is_premium: true }],
    countResult: 5,
  });
  const premiumGuard = createMockPremiumGuard({ isPremium: true });
  const service = createUsageLimitService({ pool, premiumGuard });

  const result = await service.getUsageAfterGeneration({ userId: "firebase-user-123" });

  assert.equal(result.isPremium, true);
  assert.equal(result.used, 5);
  assert.equal(result.dailyLimit, null);
  assert.equal(result.remaining, null);
  assert.equal(result.resetsAt, null);
});

test("checkUsageLimit throws when premiumGuard.checkPremium throws 401", async () => {
  const pool = createMockPool({ profileRows: [] });
  const premiumGuard = {
    async checkPremium() {
      throw { statusCode: 401, message: "Profile not found" };
    },
  };
  const service = createUsageLimitService({ pool, premiumGuard });

  await assert.rejects(
    () => service.checkUsageLimit({ userId: "nonexistent-user" }),
    (error) => {
      assert.equal(error.statusCode, 401);
      assert.equal(error.message, "Profile not found");
      return true;
    }
  );
});

test("createUsageLimitService throws when pool is not provided", () => {
  assert.throws(() => createUsageLimitService({}), TypeError);
});
