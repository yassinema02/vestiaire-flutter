/**
 * Repository for user stats / gamification data access.
 *
 * Handles reading and updating user_stats via RLS-scoped queries
 * and atomic RPC functions.
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createUserStatsRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Get the user's gamification stats.
     * Returns defaults (zeros/nulls) if no user_stats row exists.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} User stats in camelCase.
     */
    async getUserStats(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT total_points, current_streak, longest_streak, last_streak_date, streak_freeze_used_at, current_level, current_level_name
           FROM app_public.user_stats
           WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)`,
          [authContext.userId]
        );

        // Get live item count
        const itemCountResult = await client.query(
          `SELECT COUNT(*) AS item_count FROM app_public.items WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)`,
          [authContext.userId]
        );

        await client.query("commit");

        const itemCount = parseInt(itemCountResult.rows[0]?.item_count ?? "0", 10);

        if (result.rows.length === 0) {
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
            itemCount,
          };
        }

        const row = result.rows[0];
        const currentLevel = row.current_level ?? 1;

        // Calculate next level threshold from current level
        const thresholds = { 1: 10, 2: 25, 3: 50, 4: 100, 5: 200 };
        const nextLevelThreshold = thresholds[currentLevel] ?? null;

        // Calculate streak freeze availability (Monday-based week)
        const freezeUsedAt = row.streak_freeze_used_at ?? null;
        let streakFreezeAvailable = true;
        if (freezeUsedAt != null) {
          // Use is_streak_freeze_available from DB for consistency
          const freezeCheckResult = await client.query(
            "SELECT app_public.is_streak_freeze_available($1, CURRENT_DATE) AS available",
            [freezeUsedAt]
          );
          streakFreezeAvailable = freezeCheckResult.rows[0].available;
        }

        return {
          totalPoints: row.total_points,
          currentStreak: row.current_streak,
          longestStreak: row.longest_streak,
          lastStreakDate: row.last_streak_date ?? null,
          streakFreezeUsedAt: freezeUsedAt,
          streakFreezeAvailable,
          currentLevel,
          currentLevelName: row.current_level_name ?? "Closet Rookie",
          nextLevelThreshold,
          itemCount,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Award points to a user via the award_style_points RPC.
     * Creates the user_stats row if it doesn't exist (upsert).
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {number} params.points - Points to award.
     * @returns {Promise<object>} { totalPoints, pointsAwarded }
     */
    async awardPoints(authContext, { points }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          "SELECT * FROM app_public.award_style_points($1, $2)",
          [profileId, points]
        );

        await client.query("commit");

        return {
          totalPoints: result.rows[0].total_points,
          pointsAwarded: points,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Award points with streak tracking via the award_points_with_streak RPC.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {number} params.basePoints - Base points to award.
     * @param {boolean} params.isFirstLogToday - Whether this is the first log today.
     * @param {boolean} params.isStreakDay - Whether this continues a streak.
     * @returns {Promise<object>} { totalPoints, pointsAwarded, currentStreak }
     */
    async awardPointsWithStreak(authContext, { basePoints, isFirstLogToday, isStreakDay }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          "SELECT * FROM app_public.award_points_with_streak($1, $2, $3, $4)",
          [profileId, basePoints, isFirstLogToday, isStreakDay]
        );

        await client.query("commit");

        const row = result.rows[0];
        return {
          totalPoints: row.total_points,
          pointsAwarded: row.points_awarded,
          currentStreak: row.current_streak,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Check if this would be the first wear log today for the user.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<boolean>} true if no wear logs exist for today.
     */
    async checkFirstLogToday(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT COUNT(*) AS log_count
           FROM app_public.wear_logs
           WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)
             AND logged_date = CURRENT_DATE`,
          [authContext.userId]
        );

        await client.query("commit");

        const logCount = parseInt(result.rows[0].log_count, 10);
        return logCount === 0;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Check if this log continues a streak (last_streak_date is yesterday).
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<boolean>} true if streak continues.
     */
    async checkStreakDay(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT last_streak_date
           FROM app_public.user_stats
           WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)`,
          [authContext.userId]
        );

        await client.query("commit");

        if (result.rows.length === 0 || result.rows[0].last_streak_date == null) {
          return false;
        }

        const lastStreakDate = result.rows[0].last_streak_date;
        // Compare with yesterday
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toISOString().split("T")[0];

        // lastStreakDate can be a Date object or string
        const lastDateStr = lastStreakDate instanceof Date
          ? lastStreakDate.toISOString().split("T")[0]
          : String(lastStreakDate).split("T")[0];

        return lastDateStr === yesterdayStr;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}
