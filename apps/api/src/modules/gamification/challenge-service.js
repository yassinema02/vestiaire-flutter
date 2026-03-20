/**
 * Service for challenge business logic.
 *
 * Contains logic for accepting challenges, updating progress on item creation,
 * fetching challenge status, and checking premium trial expiry.
 */

/**
 * @param {object} options
 * @param {object} options.challengeRepo - Challenge repository instance.
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createChallengeService({ challengeRepo, pool }) {
  if (!challengeRepo) {
    throw new TypeError("challengeRepo is required");
  }
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Accept a challenge for a user.
     *
     * Validates challengeKey is "closet_safari" (only supported challenge for now).
     *
     * @param {object} authContext - Must have userId.
     * @param {string} challengeKey - The challenge key.
     * @returns {Promise<object>} { challenge: { key, name, status, acceptedAt, expiresAt, currentProgress, targetCount, timeRemainingSeconds } }
     */
    async acceptChallenge(authContext, challengeKey) {
      if (challengeKey !== "closet_safari") {
        throw { statusCode: 404, message: `Unknown challenge: ${challengeKey}` };
      }

      const result = await challengeRepo.acceptChallenge(authContext, challengeKey);
      return {
        challenge: {
          key: result.key,
          name: result.name,
          status: result.status,
          acceptedAt: result.acceptedAt,
          expiresAt: result.expiresAt,
          currentProgress: result.currentProgress,
          targetCount: result.targetCount,
          timeRemainingSeconds: result.timeRemainingSeconds,
        },
      };
    },

    /**
     * Update challenge progress when an item is created.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} { challengeUpdate: { key, currentProgress, targetCount, completed, rewardGranted, timeRemainingSeconds } | null }
     */
    async updateProgressOnItemCreate(authContext) {
      const result = await challengeRepo.incrementProgress(authContext, "closet_safari");

      if (!result) {
        return { challengeUpdate: null };
      }

      return {
        challengeUpdate: {
          key: result.challengeKey,
          currentProgress: result.currentProgress,
          targetCount: result.targetCount,
          completed: result.completed,
          rewardGranted: result.rewardGranted,
          timeRemainingSeconds: result.timeRemainingSeconds,
        },
      };
    },

    /**
     * Get the current challenge status for a user.
     *
     * Lazily expires stale challenges.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object|null>} Challenge state or null.
     */
    async getChallengeStatus(authContext) {
      const challenge = await challengeRepo.getUserChallenge(authContext, "closet_safari");

      if (!challenge) return null;

      // Lazily expire if time has passed and still active
      if (challenge.status === "active" && challenge.timeRemainingSeconds !== null && challenge.timeRemainingSeconds <= 0) {
        const expired = await challengeRepo.expireChallengeIfNeeded(authContext, "closet_safari");
        if (expired) return expired;
      }

      return {
        key: challenge.key,
        name: challenge.name,
        status: challenge.status,
        currentProgress: challenge.currentProgress,
        targetCount: challenge.targetCount,
        expiresAt: challenge.expiresAt,
        timeRemainingSeconds: challenge.timeRemainingSeconds,
        reward: {
          type: challenge.rewardType,
          value: challenge.rewardValue,
          description: "1 month Premium free",
        },
      };
    },

    /**
     * Check and handle premium trial expiry.
     *
     * Called lazily before premium-gated operations.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object|null>} Trial status or null.
     */
    async checkTrialExpiry(authContext) {
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
          await client.query("commit");
          return null;
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          "SELECT * FROM app_public.check_trial_expiry($1)",
          [profileId]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        return {
          isPremium: row.is_premium,
          premiumTrialExpiresAt: row.premium_trial_expires_at,
          trialExpired: row.trial_expired,
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
