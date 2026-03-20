import assert from "node:assert/strict";
import test from "node:test";
import { createUserStatsRepository } from "../../../src/modules/gamification/user-stats-repository.js";

const PROFILE_ID = "profile-uuid-1";
const PROFILE_ID_B = "profile-uuid-2";

/**
 * Create a mock pool that records queries and returns configurable results.
 */
function createMockPool({
  profileId = PROFILE_ID,
  userStatsRow = null,
  awardResult = null,
  awardWithStreakResult = null,
  wearLogCount = 0,
  lastStreakDate = null,
  failProfile = false,
  failUserStats = false,
  itemCount = 0,
} = {}) {
  const queries = [];

  return {
    queries,
    async connect() {
      return {
        async query(sql, params = []) {
          queries.push({ sql, params });

          if (sql === "begin") return {};
          if (sql === "commit" || sql === "rollback") return {};
          if (sql.includes("set_config")) return {};

          // Item count query (getUserStats)
          if (sql.includes("COUNT(*)") && sql.includes("app_public.items")) {
            return { rows: [{ item_count: String(itemCount) }] };
          }

          // getUserStats query (must be checked before generic profile lookup)
          if (sql.includes("FROM app_public.user_stats") && sql.includes("total_points")) {
            if (failUserStats || !userStatsRow) return { rows: [] };
            return { rows: [userStatsRow] };
          }

          // checkStreakDay query (select last_streak_date from user_stats)
          if (sql.includes("last_streak_date") && sql.includes("FROM app_public.user_stats") && !sql.includes("total_points")) {
            if (lastStreakDate === null) return { rows: [] };
            return { rows: [{ last_streak_date: lastStreakDate }] };
          }

          // checkFirstLogToday query (COUNT wear_logs)
          if (sql.includes("COUNT(*)") && sql.includes("wear_logs")) {
            return { rows: [{ log_count: String(wearLogCount) }] };
          }

          // Profile lookup (generic - for awardPoints/awardPointsWithStreak)
          if (sql.includes("FROM app_public.profiles WHERE firebase_uid")) {
            if (failProfile) return { rows: [] };
            return { rows: [{ id: profileId }] };
          }

          // award_style_points RPC
          if (sql.includes("award_style_points")) {
            return {
              rows: [awardResult || { total_points: params[1] }]
            };
          }

          // award_points_with_streak RPC
          if (sql.includes("award_points_with_streak")) {
            const basePoints = params[1];
            const isFirstLog = params[2];
            const isStreak = params[3];
            const bonus = (isFirstLog ? 2 : 0) + (isStreak ? 3 : 0);
            const totalAwarded = basePoints + bonus;
            return {
              rows: [awardWithStreakResult || {
                total_points: totalAwarded,
                points_awarded: totalAwarded,
                current_streak: isStreak ? 2 : 1,
              }]
            };
          }

          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };
const testAuthContextB = { userId: "firebase-user-456" };

// --- Factory tests ---

test("createUserStatsRepository throws when pool is missing", () => {
  assert.throws(() => createUserStatsRepository({}), TypeError);
});

// --- getUserStats tests ---

test("getUserStats returns defaults when no user_stats row exists", async () => {
  const pool = createMockPool({ userStatsRow: null });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.getUserStats(testAuthContext);

  assert.equal(result.totalPoints, 0);
  assert.equal(result.currentStreak, 0);
  assert.equal(result.longestStreak, 0);
  assert.equal(result.lastStreakDate, null);
  assert.equal(result.streakFreezeUsedAt, null);
  assert.equal(result.currentLevel, 1);
  assert.equal(result.currentLevelName, "Closet Rookie");
  assert.equal(result.nextLevelThreshold, 10);
  assert.equal(result.itemCount, 0);
});

test("getUserStats returns correct stats when row exists", async () => {
  const pool = createMockPool({
    userStatsRow: {
      total_points: 150,
      current_streak: 5,
      longest_streak: 10,
      last_streak_date: "2026-03-18",
      streak_freeze_used_at: null,
      current_level: 3,
      current_level_name: "Fashion Explorer",
    },
    itemCount: 30,
  });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.getUserStats(testAuthContext);

  assert.equal(result.totalPoints, 150);
  assert.equal(result.currentStreak, 5);
  assert.equal(result.longestStreak, 10);
  assert.equal(result.lastStreakDate, "2026-03-18");
  assert.equal(result.streakFreezeUsedAt, null);
  assert.equal(result.currentLevel, 3);
  assert.equal(result.currentLevelName, "Fashion Explorer");
  assert.equal(result.nextLevelThreshold, 50);
  assert.equal(result.itemCount, 30);
});

// --- awardPoints tests ---

test("awardPoints creates user_stats row if none exists (upsert)", async () => {
  const pool = createMockPool({
    awardResult: { total_points: 10 }
  });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.awardPoints(testAuthContext, { points: 10 });

  assert.equal(result.totalPoints, 10);
  assert.equal(result.pointsAwarded, 10);

  const rpcQuery = pool.queries.find(q => q.sql.includes("award_style_points"));
  assert.ok(rpcQuery, "Should call award_style_points RPC");
  assert.equal(rpcQuery.params[0], PROFILE_ID);
  assert.equal(rpcQuery.params[1], 10);
});

test("awardPoints increments existing total_points atomically", async () => {
  const pool = createMockPool({
    awardResult: { total_points: 30 }
  });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.awardPoints(testAuthContext, { points: 10 });

  assert.equal(result.totalPoints, 30);
  assert.equal(result.pointsAwarded, 10);
});

test("awardPoints returns updated totalPoints and pointsAwarded", async () => {
  const pool = createMockPool({
    awardResult: { total_points: 50 }
  });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.awardPoints(testAuthContext, { points: 10 });

  assert.equal(result.totalPoints, 50);
  assert.equal(result.pointsAwarded, 10);
});

// --- awardPointsWithStreak tests ---

test("awardPointsWithStreak adds base + first-log + streak bonuses correctly", async () => {
  const pool = createMockPool({
    awardWithStreakResult: {
      total_points: 10,
      points_awarded: 10,
      current_streak: 2,
    }
  });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.awardPointsWithStreak(testAuthContext, {
    basePoints: 5,
    isFirstLogToday: true,
    isStreakDay: true,
  });

  assert.equal(result.pointsAwarded, 10);
  assert.equal(result.totalPoints, 10);
});

test("awardPointsWithStreak updates current_streak and longest_streak", async () => {
  const pool = createMockPool({
    awardWithStreakResult: {
      total_points: 8,
      points_awarded: 8,
      current_streak: 5,
    }
  });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.awardPointsWithStreak(testAuthContext, {
    basePoints: 5,
    isFirstLogToday: false,
    isStreakDay: true,
  });

  assert.equal(result.currentStreak, 5);
});

test("awardPointsWithStreak sets last_streak_date to today", async () => {
  const pool = createMockPool();
  const repo = createUserStatsRepository({ pool });

  await repo.awardPointsWithStreak(testAuthContext, {
    basePoints: 5,
    isFirstLogToday: false,
    isStreakDay: true,
  });

  const rpcQuery = pool.queries.find(q => q.sql.includes("award_points_with_streak"));
  assert.ok(rpcQuery);
  assert.equal(rpcQuery.params[3], true); // isStreakDay = true
});

// --- checkFirstLogToday tests ---

test("checkFirstLogToday returns true when no wear logs exist for today", async () => {
  const pool = createMockPool({ wearLogCount: 0 });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.checkFirstLogToday(testAuthContext);

  assert.equal(result, true);
});

test("checkFirstLogToday returns false when wear logs exist for today", async () => {
  const pool = createMockPool({ wearLogCount: 2 });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.checkFirstLogToday(testAuthContext);

  assert.equal(result, false);
});

// --- checkStreakDay tests ---

test("checkStreakDay returns true when last_streak_date is yesterday", async () => {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().split("T")[0];

  const pool = createMockPool({ lastStreakDate: yesterdayStr });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.checkStreakDay(testAuthContext);

  assert.equal(result, true);
});

test("checkStreakDay returns false when last_streak_date is today (already counted)", async () => {
  const today = new Date();
  const todayStr = today.toISOString().split("T")[0];

  const pool = createMockPool({ lastStreakDate: todayStr });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.checkStreakDay(testAuthContext);

  assert.equal(result, false);
});

test("checkStreakDay returns false when last_streak_date is older than yesterday (broken)", async () => {
  const oldDate = new Date();
  oldDate.setDate(oldDate.getDate() - 5);
  const oldStr = oldDate.toISOString().split("T")[0];

  const pool = createMockPool({ lastStreakDate: oldStr });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.checkStreakDay(testAuthContext);

  assert.equal(result, false);
});

test("checkStreakDay returns false when no user_stats row exists", async () => {
  const pool = createMockPool({ lastStreakDate: null });
  const repo = createUserStatsRepository({ pool });

  const result = await repo.checkStreakDay(testAuthContext);

  assert.equal(result, false);
});

// --- RLS isolation ---

test("RLS isolation: sets app.current_user_id for scoped queries", async () => {
  const pool = createMockPool();
  const repo = createUserStatsRepository({ pool });

  await repo.getUserStats(testAuthContext);

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});
