/**
 * Service for streak evaluation and freeze management.
 *
 * Handles streak evaluation by calling the database evaluate_streak RPC
 * and streak freeze status queries. Delegates to pool for data access.
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createStreakService({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Evaluate streak state for a user after logging an outfit.
     *
     * Looks up the profile_id from firebase_uid, then calls the
     * evaluate_streak RPC which atomically evaluates and updates
     * streak state (continuation, freeze, reset, idempotency).
     *
     * @param {object} authContext - Must have userId (firebase_uid).
     * @param {object} params
     * @param {string} [params.loggedDate] - The date of the log (YYYY-MM-DD). Defaults to today.
     * @returns {Promise<object>} Streak result in camelCase.
     */
    async evaluateStreak(authContext, { loggedDate } = {}) {
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

        // Call the RPC - use CURRENT_DATE if no loggedDate provided
        const dateParam = loggedDate || new Date().toISOString().split("T")[0];
        const result = await client.query(
          "SELECT * FROM app_public.evaluate_streak($1, $2::DATE)",
          [profileId, dateParam]
        );

        await client.query("commit");

        const row = result.rows[0];
        return {
          currentStreak: row.current_streak,
          longestStreak: row.longest_streak,
          lastStreakDate: row.last_streak_date ?? null,
          streakFreezeUsedAt: row.streak_freeze_used_at ?? null,
          streakExtended: row.streak_extended,
          isNewStreak: row.is_new_streak,
          freezeUsed: row.freeze_used,
          streakFreezeAvailable: row.streak_freeze_available,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get the streak freeze availability status for a user.
     *
     * @param {object} authContext - Must have userId (firebase_uid).
     * @returns {Promise<object>} { streakFreezeAvailable, streakFreezeUsedAt }
     */
    async getStreakFreezeStatus(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT streak_freeze_used_at
           FROM app_public.user_stats
           WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)`,
          [authContext.userId]
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return {
            streakFreezeAvailable: true,
            streakFreezeUsedAt: null,
          };
        }

        const freezeUsedAt = result.rows[0].streak_freeze_used_at ?? null;

        // Calculate Monday of current week
        const today = new Date();
        const dayOfWeek = today.getDay(); // 0=Sun, 1=Mon, ...
        const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
        const monday = new Date(today);
        monday.setDate(today.getDate() + mondayOffset);
        const mondayStr = monday.toISOString().split("T")[0];

        let streakFreezeAvailable = true;
        if (freezeUsedAt != null) {
          const freezeStr = freezeUsedAt instanceof Date
            ? freezeUsedAt.toISOString().split("T")[0]
            : String(freezeUsedAt).split("T")[0];
          streakFreezeAvailable = freezeStr < mondayStr;
        }

        return {
          streakFreezeAvailable,
          streakFreezeUsedAt: freezeUsedAt,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}
