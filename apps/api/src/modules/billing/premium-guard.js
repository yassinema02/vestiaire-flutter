/**
 * Premium guard utility for centralized premium access checks.
 *
 * Consolidates duplicated premium check logic from usage-limit-service.js
 * and analytics-summary-service.js into a single shared utility.
 *
 * Provides:
 * - checkPremium(authContext): returns premium status info
 * - requirePremium(authContext): throws 403 if not premium
 * - checkUsageQuota(authContext, opts): checks usage limits for free users
 */

/** Free-tier usage limits matching PRD values. */
export const FREE_LIMITS = {
  OUTFIT_GENERATION_DAILY: 3,
  SHOPPING_SCAN_DAILY: 3,
  RESALE_LISTING_MONTHLY: 2,
};

/**
 * Compute the start of the current UTC day as an ISO string.
 */
function getDayStart() {
  return new Date().toISOString().split("T")[0] + "T00:00:00Z";
}

/**
 * Compute the start of the current UTC month as an ISO string.
 */
function getMonthStart() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}-01T00:00:00Z`;
}

/**
 * Compute the end of the current UTC day or month.
 */
function getPeriodEnd(periodStart, period) {
  const start = new Date(periodStart);
  if (period === "day") {
    return new Date(start.getTime() + 86400000).toISOString();
  }
  // month: advance to next month
  const year = start.getUTCFullYear();
  const month = start.getUTCMonth();
  return new Date(Date.UTC(year, month + 1, 1)).toISOString();
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 * @param {object} options.subscriptionSyncService - Subscription sync service for lazy expiry.
 * @param {object} options.challengeService - Challenge service for trial expiry check.
 */
export function createPremiumGuard({ pool, subscriptionSyncService, challengeService }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Check the premium status of the authenticated user.
     *
     * Steps:
     * 1. Query profile for premium status
     * 2. Best-effort trial expiry check
     * 3. Lazy subscription expiry check if needed
     * 4. Return premium info
     *
     * @param {object} authContext - Auth context with userId.
     * @returns {Promise<{ isPremium: boolean, profileId: string, premiumSource: string|null }>}
     */
    async checkPremium(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Query profile
        const profileResult = await client.query(
          "SELECT id, is_premium, premium_source, premium_expires_at, premium_trial_expires_at FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw { statusCode: 401, message: "Profile not found" };
        }

        let profile = profileResult.rows[0];

        // Best-effort trial expiry check
        try {
          if (challengeService) {
            await challengeService.checkTrialExpiry(authContext);
          }
        } catch (trialError) {
          console.error("[premium-guard] Failed to check trial expiry:", trialError.message ?? trialError);
        }

        // Lazy subscription expiry check (belt-and-suspenders with webhooks)
        if (
          profile.is_premium &&
          profile.premium_source === "revenuecat" &&
          profile.premium_expires_at &&
          new Date(profile.premium_expires_at) < new Date()
        ) {
          try {
            await subscriptionSyncService.syncFromClient(authContext, {
              appUserId: authContext.userId,
            });
          } catch (syncError) {
            console.error("[premium-guard] Failed to lazily expire subscription:", syncError.message ?? syncError);
          }

          // Re-query profile after sync attempt
          const refreshResult = await client.query(
            "SELECT id, is_premium, premium_source, premium_expires_at, premium_trial_expires_at FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
            [authContext.userId]
          );
          if (refreshResult.rows.length > 0) {
            profile = refreshResult.rows[0];
          }
        }

        return {
          isPremium: profile.is_premium,
          profileId: profile.id,
          premiumSource: profile.premium_source,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Require premium access. Throws 403 if user is not premium.
     *
     * @param {object} authContext - Auth context with userId.
     * @returns {Promise<{ isPremium: boolean, profileId: string, premiumSource: string|null }>}
     */
    async requirePremium(authContext) {
      const result = await this.checkPremium(authContext);
      if (!result.isPremium) {
        throw {
          statusCode: 403,
          code: "PREMIUM_REQUIRED",
          message: "Premium subscription required",
        };
      }
      return result;
    },

    /**
     * Check usage quota for a feature. Premium users get unlimited access.
     * Free users are subject to per-period limits.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} options
     * @param {string} options.feature - Feature name (e.g., "outfit_generation").
     * @param {number} options.freeLimit - Max uses for free tier in the period.
     * @param {string} options.period - "day" or "month".
     * @returns {Promise<object>} Quota check result.
     */
    async checkUsageQuota(authContext, { feature, freeLimit, period }) {
      const premiumInfo = await this.checkPremium(authContext);

      if (premiumInfo.isPremium) {
        return {
          allowed: true,
          isPremium: true,
          limit: null,
          used: 0,
          remaining: null,
          resetsAt: null,
        };
      }

      // Count usage for the current period
      const periodStart = period === "day" ? getDayStart() : getMonthStart();
      const resetsAt = getPeriodEnd(periodStart, period);

      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const countResult = await client.query(
          `SELECT COUNT(*)::int AS count FROM app_public.ai_usage_log
           WHERE profile_id = $1 AND feature = $2 AND status = 'success' AND created_at >= $3`,
          [premiumInfo.profileId, feature, periodStart]
        );

        const count = countResult.rows[0].count;
        const remaining = Math.max(0, freeLimit - count);

        return {
          allowed: count < freeLimit,
          isPremium: false,
          limit: freeLimit,
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
