/**
 * Repository for challenge data access.
 *
 * Handles reading challenge definitions, user challenges,
 * accepting challenges, incrementing progress, and expiring challenges.
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createChallengeRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Get a challenge definition by key.
     *
     * @param {string} challengeKey - The challenge key (e.g., "closet_safari").
     * @returns {Promise<object|null>} Challenge definition in camelCase, or null.
     */
    async getChallenge(challengeKey) {
      const client = await pool.connect();
      try {
        const result = await client.query(
          `SELECT key, name, description, target_count, time_limit_days, reward_type, reward_value, icon_name
           FROM app_public.challenges
           WHERE key = $1`,
          [challengeKey]
        );

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        return {
          key: row.key,
          name: row.name,
          description: row.description,
          targetCount: row.target_count,
          timeLimitDays: row.time_limit_days,
          rewardType: row.reward_type,
          rewardValue: row.reward_value,
          iconName: row.icon_name,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get a user's challenge state for a given challenge key.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} challengeKey - The challenge key.
     * @returns {Promise<object|null>} User challenge state in camelCase, or null.
     */
    async getUserChallenge(authContext, challengeKey) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT uc.status, uc.accepted_at, uc.completed_at, uc.expires_at, uc.current_progress,
                  c.target_count, c.name, c.key, c.reward_type, c.reward_value,
                  EXTRACT(EPOCH FROM (uc.expires_at - NOW()))::INTEGER AS time_remaining_seconds
           FROM app_public.user_challenges uc
           JOIN app_public.challenges c ON c.id = uc.challenge_id
           WHERE uc.profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)
             AND c.key = $2`,
          [authContext.userId, challengeKey]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        return {
          key: row.key,
          name: row.name,
          status: row.status,
          acceptedAt: row.accepted_at,
          completedAt: row.completed_at,
          expiresAt: row.expires_at,
          currentProgress: row.current_progress,
          targetCount: row.target_count,
          rewardType: row.reward_type,
          rewardValue: row.reward_value,
          timeRemainingSeconds: row.time_remaining_seconds,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Accept a challenge for a user.
     *
     * Sets current_progress to the user's current item count.
     * Idempotent via ON CONFLICT DO NOTHING.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} challengeKey - The challenge key.
     * @returns {Promise<object>} Challenge state in camelCase.
     */
    async acceptChallenge(authContext, challengeKey) {
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
          throw { statusCode: 404, message: "Profile not found" };
        }

        const profileId = profileResult.rows[0].id;

        // Look up challenge_id
        const challengeResult = await client.query(
          "SELECT id, time_limit_days FROM app_public.challenges WHERE key = $1 LIMIT 1",
          [challengeKey]
        );

        if (challengeResult.rows.length === 0) {
          await client.query("commit");
          throw { statusCode: 404, message: `Challenge not found: ${challengeKey}` };
        }

        const challengeId = challengeResult.rows[0].id;

        // Count current items for this profile
        const itemCountResult = await client.query(
          "SELECT COUNT(*)::INTEGER AS count FROM app_public.items WHERE profile_id = $1",
          [profileId]
        );
        const currentItemCount = itemCountResult.rows[0].count;

        // Insert (idempotent)
        const insertResult = await client.query(
          `INSERT INTO app_public.user_challenges (profile_id, challenge_id, status, expires_at, current_progress)
           VALUES ($1, $2, 'active', NOW() + ($3 || ' days')::INTERVAL, $4)
           ON CONFLICT (profile_id, challenge_id) DO NOTHING
           RETURNING *`,
          [profileId, challengeId, String(challengeResult.rows[0].time_limit_days), currentItemCount]
        );

        // If ON CONFLICT (already exists), select and return existing
        let uc;
        if (insertResult.rows.length === 0) {
          const existing = await client.query(
            `SELECT uc.*, c.key, c.name, c.target_count, c.reward_type, c.reward_value,
                    EXTRACT(EPOCH FROM (uc.expires_at - NOW()))::INTEGER AS time_remaining_seconds
             FROM app_public.user_challenges uc
             JOIN app_public.challenges c ON c.id = uc.challenge_id
             WHERE uc.profile_id = $1 AND uc.challenge_id = $2`,
            [profileId, challengeId]
          );
          uc = existing.rows[0];
        } else {
          // Fetch full data for newly inserted row
          const newRow = await client.query(
            `SELECT uc.*, c.key, c.name, c.target_count, c.reward_type, c.reward_value,
                    EXTRACT(EPOCH FROM (uc.expires_at - NOW()))::INTEGER AS time_remaining_seconds
             FROM app_public.user_challenges uc
             JOIN app_public.challenges c ON c.id = uc.challenge_id
             WHERE uc.id = $1`,
            [insertResult.rows[0].id]
          );
          uc = newRow.rows[0];
        }

        await client.query("commit");

        return {
          key: uc.key,
          name: uc.name,
          status: uc.status,
          acceptedAt: uc.accepted_at,
          expiresAt: uc.expires_at,
          currentProgress: uc.current_progress,
          targetCount: uc.target_count,
          timeRemainingSeconds: uc.time_remaining_seconds,
          rewardType: uc.reward_type,
          rewardValue: uc.reward_value,
        };
      } catch (error) {
        try { await client.query("rollback"); } catch (_) { /* ignore */ }
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Increment challenge progress for a user via the database RPC.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} challengeKey - The challenge key.
     * @returns {Promise<object|null>} Progress update in camelCase, or null.
     */
    async incrementProgress(authContext, challengeKey) {
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
          "SELECT * FROM app_public.increment_challenge_progress($1, $2)",
          [profileId, challengeKey]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        return {
          challengeKey: row.challenge_key,
          currentProgress: row.current_progress,
          targetCount: row.target_count,
          completed: row.completed,
          rewardGranted: row.reward_granted,
          timeRemainingSeconds: row.time_remaining_seconds,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Expire a challenge if its time has passed.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} challengeKey - The challenge key.
     * @returns {Promise<object|null>} Updated state or null.
     */
    async expireChallengeIfNeeded(authContext, challengeKey) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `UPDATE app_public.user_challenges uc
           SET status = 'expired'
           FROM app_public.challenges c
           WHERE uc.challenge_id = c.id
             AND c.key = $1
             AND uc.profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $2)
             AND uc.status = 'active'
             AND uc.expires_at < NOW()
           RETURNING uc.status, uc.current_progress, c.target_count, c.key, c.name,
                     EXTRACT(EPOCH FROM (uc.expires_at - NOW()))::INTEGER AS time_remaining_seconds`,
          [challengeKey, authContext.userId]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        return {
          key: row.key,
          name: row.name,
          status: row.status,
          currentProgress: row.current_progress,
          targetCount: row.target_count,
          timeRemainingSeconds: row.time_remaining_seconds,
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
