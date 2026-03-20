/**
 * Service for user level progression.
 *
 * Handles level recalculation by calling the database RPC function
 * and mapping results to camelCase for API consumers.
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createLevelService({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Recalculate the user's level based on their wardrobe item count.
     *
     * Looks up the profile_id from firebase_uid, then calls the
     * recalculate_user_level RPC which atomically counts items,
     * determines the level, and upserts user_stats.
     *
     * @param {object} authContext - Must have userId (firebase_uid).
     * @returns {Promise<object>} Level result in camelCase.
     */
    async recalculateLevel(authContext) {
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

        // Call the RPC
        const result = await client.query(
          "SELECT * FROM app_public.recalculate_user_level($1)",
          [profileId]
        );

        await client.query("commit");

        const row = result.rows[0];
        return {
          currentLevel: row.current_level,
          currentLevelName: row.current_level_name,
          previousLevel: row.previous_level,
          previousLevelName: row.previous_level_name,
          leveledUp: row.leveled_up,
          itemCount: row.item_count,
          nextLevelThreshold: row.next_level_threshold,
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
