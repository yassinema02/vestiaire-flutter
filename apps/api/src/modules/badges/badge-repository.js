/**
 * Repository for badge data access.
 *
 * Handles reading badge definitions, user badges, and evaluating
 * badge eligibility via the evaluate_badges RPC.
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createBadgeRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Get the full badge catalog (all 15 badge definitions).
     *
     * @returns {Promise<Array<object>>} Badge definitions in sort order, camelCase.
     */
    async getAllBadges() {
      const client = await pool.connect();
      try {
        const result = await client.query(
          `SELECT key, name, description, icon_name, icon_color, category, sort_order
           FROM app_public.badges
           ORDER BY sort_order`
        );

        return result.rows.map((row) => ({
          key: row.key,
          name: row.name,
          description: row.description,
          iconName: row.icon_name,
          iconColor: row.icon_color,
          category: row.category,
          sortOrder: row.sort_order,
        }));
      } finally {
        client.release();
      }
    },

    /**
     * Get earned badges for a user.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} User's earned badges in camelCase, ordered by awarded_at DESC.
     */
    async getUserBadges(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT b.key, b.name, b.description, b.icon_name, b.icon_color, b.category, ub.awarded_at
           FROM app_public.user_badges ub
           JOIN app_public.badges b ON b.id = ub.badge_id
           WHERE ub.profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)
           ORDER BY ub.awarded_at DESC`,
          [authContext.userId]
        );

        await client.query("commit");

        return result.rows.map((row) => ({
          key: row.key,
          name: row.name,
          description: row.description,
          iconName: row.icon_name,
          iconColor: row.icon_color,
          category: row.category,
          awardedAt: row.awarded_at,
        }));
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Evaluate and award badges for a user via the evaluate_badges RPC.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} Newly awarded badges in camelCase.
     */
    async evaluateBadges(authContext) {
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
          return [];
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          "SELECT * FROM app_public.evaluate_badges($1)",
          [profileId]
        );

        await client.query("commit");

        return result.rows.map((row) => ({
          key: row.badge_key,
          name: row.badge_name,
          description: row.badge_description,
          iconName: row.badge_icon_name,
          iconColor: row.badge_icon_color,
        }));
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}
