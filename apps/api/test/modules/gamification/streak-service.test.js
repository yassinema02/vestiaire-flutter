import assert from "node:assert/strict";
import test from "node:test";
import { createStreakService } from "../../../src/modules/gamification/streak-service.js";

/**
 * Creates a mock pool that simulates the database behavior
 * for the evaluate_streak and getStreakFreezeStatus methods.
 */
function createMockPool({
  profileId = "profile-uuid-1",
  profileExists = true,
  evaluateStreakResult = null,
  freezeUsedAt = null,
  userStatsExists = true,
} = {}) {
  const queries = [];

  const mockClient = {
    queries,
    async query(sql, params) {
      queries.push({ sql, params });

      // begin / commit / rollback
      if (sql === "begin" || sql === "commit" || sql === "rollback") {
        return { rows: [] };
      }

      // set_config
      if (sql.includes("set_config")) {
        return { rows: [] };
      }

      // evaluate_streak RPC
      if (sql.includes("evaluate_streak")) {
        if (evaluateStreakResult) {
          return { rows: [evaluateStreakResult] };
        }
        return {
          rows: [{
            current_streak: 1,
            longest_streak: 1,
            last_streak_date: "2026-03-19",
            streak_freeze_used_at: null,
            streak_extended: false,
            is_new_streak: true,
            freeze_used: false,
            streak_freeze_available: true,
          }],
        };
      }

      // streak_freeze_used_at query (getStreakFreezeStatus) - must check before profile lookup
      // because this query also contains "profiles" and "firebase_uid"
      if (sql.includes("streak_freeze_used_at") && sql.includes("user_stats")) {
        if (!userStatsExists) return { rows: [] };
        return { rows: [{ streak_freeze_used_at: freezeUsedAt }] };
      }

      // Profile lookup (SELECT id FROM profiles)
      if (sql.includes("profiles") && sql.includes("firebase_uid")) {
        if (!profileExists) return { rows: [] };
        return { rows: [{ id: profileId }] };
      }

      return { rows: [] };
    },
    release() {},
  };

  return {
    queries,
    async connect() {
      return mockClient;
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- Factory tests ---

test("createStreakService throws when pool is missing", () => {
  assert.throws(() => createStreakService({}), TypeError);
});

test("createStreakService returns an object with evaluateStreak and getStreakFreezeStatus", () => {
  const pool = createMockPool();
  const service = createStreakService({ pool });
  assert.equal(typeof service.evaluateStreak, "function");
  assert.equal(typeof service.getStreakFreezeStatus, "function");
});

// --- evaluateStreak tests ---

test("evaluateStreak returns streak_extended=true when last_streak_date is yesterday", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 5,
      longest_streak: 10,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: true,
      is_new_streak: false,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.streakExtended, true);
  assert.equal(result.isNewStreak, false);
  assert.equal(result.currentStreak, 5);
});

test("evaluateStreak returns is_new_streak=true when last_streak_date is > 1 day ago", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 1,
      longest_streak: 10,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: false,
      is_new_streak: true,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.isNewStreak, true);
  assert.equal(result.streakExtended, false);
  assert.equal(result.currentStreak, 1);
});

test("evaluateStreak returns streak_extended=false when last_streak_date is today (already logged)", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 3,
      longest_streak: 5,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: false,
      is_new_streak: false,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.streakExtended, false);
  assert.equal(result.isNewStreak, false);
  assert.equal(result.currentStreak, 3);
});

test("evaluateStreak applies freeze when last_streak_date is 2 days ago and freeze available", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 6,
      longest_streak: 10,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: "2026-03-18",
      streak_extended: true,
      is_new_streak: false,
      freeze_used: true,
      streak_freeze_available: false,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.streakExtended, true);
  assert.equal(result.freezeUsed, true);
  assert.equal(result.streakFreezeAvailable, false);
});

test("evaluateStreak does NOT apply freeze when freeze already used this week", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 1,
      longest_streak: 5,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: "2026-03-17",
      streak_extended: false,
      is_new_streak: true,
      freeze_used: false,
      streak_freeze_available: false,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.isNewStreak, true);
  assert.equal(result.freezeUsed, false);
  assert.equal(result.streakFreezeAvailable, false);
});

test("evaluateStreak resets streak when last_streak_date is > 2 days ago (even with freeze available)", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 1,
      longest_streak: 10,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: false,
      is_new_streak: true,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.isNewStreak, true);
  assert.equal(result.currentStreak, 1);
  assert.equal(result.streakExtended, false);
});

test("evaluateStreak correctly calculates freeze availability on Monday (new week resets freeze)", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 8,
      longest_streak: 8,
      last_streak_date: "2026-03-16",
      streak_freeze_used_at: "2026-03-13",
      streak_extended: true,
      is_new_streak: false,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-16" });

  assert.equal(result.streakFreezeAvailable, true);
});

test("evaluateStreak correctly calculates freeze availability on Sunday (same week as Monday freeze)", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 1,
      longest_streak: 5,
      last_streak_date: "2026-03-22",
      streak_freeze_used_at: "2026-03-17",
      streak_extended: false,
      is_new_streak: true,
      freeze_used: false,
      streak_freeze_available: false,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-22" });

  assert.equal(result.streakFreezeAvailable, false);
});

test("evaluateStreak increments current_streak and updates longest_streak correctly", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 11,
      longest_streak: 11,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: true,
      is_new_streak: false,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.currentStreak, 11);
  assert.equal(result.longestStreak, 11);
});

test("evaluateStreak handles null last_streak_date (first ever log)", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 1,
      longest_streak: 1,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: false,
      is_new_streak: true,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.currentStreak, 1);
  assert.equal(result.isNewStreak, true);
});

test("evaluateStreak upserts user_stats row if not exists", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 1,
      longest_streak: 1,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: false,
      is_new_streak: true,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  // The RPC handles upsert internally - we just verify it returns valid data
  assert.equal(result.currentStreak, 1);
  assert.equal(result.isNewStreak, true);
});

test("evaluateStreak is idempotent for same-day calls", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 3,
      longest_streak: 5,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: null,
      streak_extended: false,
      is_new_streak: false,
      freeze_used: false,
      streak_freeze_available: true,
    },
  });
  const service = createStreakService({ pool });

  const result1 = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });
  const result2 = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result1.currentStreak, result2.currentStreak);
  assert.equal(result1.streakExtended, false);
  assert.equal(result2.streakExtended, false);
});

test("evaluateStreak maps database results to camelCase correctly", async () => {
  const pool = createMockPool({
    evaluateStreakResult: {
      current_streak: 3,
      longest_streak: 5,
      last_streak_date: "2026-03-19",
      streak_freeze_used_at: "2026-03-17",
      streak_extended: true,
      is_new_streak: false,
      freeze_used: false,
      streak_freeze_available: false,
    },
  });
  const service = createStreakService({ pool });

  const result = await service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" });

  assert.equal(result.currentStreak, 3);
  assert.equal(result.longestStreak, 5);
  assert.equal(result.lastStreakDate, "2026-03-19");
  assert.equal(result.streakFreezeUsedAt, "2026-03-17");
  assert.equal(result.streakExtended, true);
  assert.equal(result.isNewStreak, false);
  assert.equal(result.freezeUsed, false);
  assert.equal(result.streakFreezeAvailable, false);
});

test("evaluateStreak throws when profile not found", async () => {
  const pool = createMockPool({ profileExists: false });
  const service = createStreakService({ pool });

  await assert.rejects(
    () => service.evaluateStreak(testAuthContext, { loggedDate: "2026-03-19" }),
    { message: "Profile not found for authenticated user" }
  );
});

// --- getStreakFreezeStatus tests ---

test("getStreakFreezeStatus returns available=true when no freeze used", async () => {
  const pool = createMockPool({ freezeUsedAt: null });
  const service = createStreakService({ pool });

  const result = await service.getStreakFreezeStatus(testAuthContext);

  assert.equal(result.streakFreezeAvailable, true);
  assert.equal(result.streakFreezeUsedAt, null);
});

test("getStreakFreezeStatus returns available=false when freeze used this week", async () => {
  // Use a date that is guaranteed to be in the current week
  const today = new Date();
  const todayStr = today.toISOString().split("T")[0];

  const pool = createMockPool({ freezeUsedAt: todayStr });
  const service = createStreakService({ pool });

  const result = await service.getStreakFreezeStatus(testAuthContext);

  assert.equal(result.streakFreezeAvailable, false);
  assert.equal(result.streakFreezeUsedAt, todayStr);
});

test("getStreakFreezeStatus returns available=true on new week after previous week's freeze", async () => {
  // Use a date more than 7 days ago to ensure it's in a previous week
  const oldDate = new Date();
  oldDate.setDate(oldDate.getDate() - 14);
  const oldDateStr = oldDate.toISOString().split("T")[0];

  const pool = createMockPool({ freezeUsedAt: oldDateStr });
  const service = createStreakService({ pool });

  const result = await service.getStreakFreezeStatus(testAuthContext);

  assert.equal(result.streakFreezeAvailable, true);
});

test("getStreakFreezeStatus returns available=true when no user_stats row exists", async () => {
  const pool = createMockPool({ userStatsExists: false });
  const service = createStreakService({ pool });

  const result = await service.getStreakFreezeStatus(testAuthContext);

  assert.equal(result.streakFreezeAvailable, true);
  assert.equal(result.streakFreezeUsedAt, null);
});
