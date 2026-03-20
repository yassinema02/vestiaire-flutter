/**
 * Usage limit service for AI outfit generation.
 *
 * Checks daily usage limits for free-tier users by counting
 * successful outfit generations in the ai_usage_log table.
 * Premium users bypass all limits.
 *
 * Uses premiumGuard for centralized premium status checks.
 */

export const FREE_DAILY_LIMIT = 3;

/**
 * Compute the start of the current UTC day as an ISO string.
 */
function getTodayStart() {
  return new Date().toISOString().split("T")[0] + "T00:00:00Z";
}

/**
 * Compute the next UTC midnight as an ISO string.
 */
function getResetsAt(todayStart) {
  return new Date(new Date(todayStart).getTime() + 86400000).toISOString();
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 * @param {object} options.premiumGuard - Premium guard utility for premium checks.
 */
export function createUsageLimitService({ pool, premiumGuard }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Check whether the user is allowed to generate an outfit.
     *
     * @param {object} authContext - Auth context with userId.
     * @returns {Promise<object>} Usage limit result.
     */
    async checkUsageLimit(authContext) {
      // Use premiumGuard for premium status check
      const premiumInfo = await premiumGuard.checkPremium(authContext);

      if (premiumInfo.isPremium) {
        return {
          allowed: true,
          isPremium: true,
          dailyLimit: null,
          used: 0,
          remaining: null,
          resetsAt: null,
        };
      }

      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const todayStart = getTodayStart();

        const countResult = await client.query(
          `SELECT COUNT(*)::int AS count FROM app_public.ai_usage_log
           WHERE profile_id = $1 AND feature = 'outfit_generation' AND status = 'success' AND created_at >= $2`,
          [premiumInfo.profileId, todayStart]
        );

        const count = countResult.rows[0].count;
        const remaining = Math.max(0, FREE_DAILY_LIMIT - count);
        const resetsAt = getResetsAt(todayStart);

        return {
          allowed: count < FREE_DAILY_LIMIT,
          isPremium: false,
          dailyLimit: FREE_DAILY_LIMIT,
          used: count,
          remaining,
          resetsAt,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get usage metadata after a successful generation.
     * Called after the new ai_usage_log entry has been written.
     *
     * @param {object} authContext - Auth context with userId.
     * @returns {Promise<object>} Usage metadata.
     */
    async getUsageAfterGeneration(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const profileResult = await client.query(
          "select id, is_premium from app_public.profiles where firebase_uid = $1 limit 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw { statusCode: 401, message: "Profile not found" };
        }

        const { id: profileId, is_premium: isPremium } = profileResult.rows[0];

        const todayStart = getTodayStart();

        const countResult = await client.query(
          `SELECT COUNT(*)::int AS count FROM app_public.ai_usage_log
           WHERE profile_id = $1 AND feature = 'outfit_generation' AND status = 'success' AND created_at >= $2`,
          [profileId, todayStart]
        );

        const count = countResult.rows[0].count;

        if (isPremium) {
          return {
            isPremium: true,
            dailyLimit: null,
            used: count,
            remaining: null,
            resetsAt: null,
          };
        }

        const remaining = Math.max(0, FREE_DAILY_LIMIT - count);
        const resetsAt = getResetsAt(todayStart);

        return {
          isPremium: false,
          dailyLimit: FREE_DAILY_LIMIT,
          used: count,
          remaining,
          resetsAt,
        };
      } finally {
        client.release();
      }
    },
  };
}
