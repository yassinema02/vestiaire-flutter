/**
 * Repository for wear log CRUD operations.
 *
 * Handles creating wear logs with associated items and atomic wear count
 * increments in a single transaction. All queries are RLS-scoped via
 * set_config('app.current_user_id').
 */

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Map a database wear log row to camelCase response object.
 * @param {object} row - Database row.
 * @returns {object} Mapped wear log object.
 */
export function mapWearLogRow(row) {
  return {
    id: row.id,
    profileId: row.profile_id,
    loggedDate: row.logged_date,
    outfitId: row.outfit_id ?? null,
    photoUrl: row.photo_url ?? null,
    createdAt: row.created_at,
    itemIds: row.item_ids ?? [],
  };
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createWearLogRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create a wear log with associated items and atomic wear count increments.
     *
     * All operations happen in a single transaction:
     * 1. Insert wear_logs row
     * 2. Insert wear_log_items rows
     * 3. Call increment_wear_counts RPC
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string[]} params.itemIds - Non-empty array of item UUIDs.
     * @param {string} [params.outfitId] - Optional outfit UUID.
     * @param {string} [params.photoUrl] - Optional photo URL.
     * @param {string} [params.loggedDate] - Optional ISO date string, defaults to today.
     * @returns {Promise<object>} Created wear log with items.
     */
    async createWearLog(authContext, { itemIds, outfitId = null, photoUrl = null, loggedDate = null }) {
      // Validate itemIds
      if (!Array.isArray(itemIds) || itemIds.length === 0) {
        const err = new Error("itemIds must be a non-empty array");
        err.statusCode = 400;
        err.code = "BAD_REQUEST";
        throw err;
      }

      for (const id of itemIds) {
        if (typeof id !== "string" || !UUID_REGEX.test(id)) {
          const err = new Error("Each itemId must be a valid UUID string");
          err.statusCode = 400;
          err.code = "BAD_REQUEST";
          throw err;
        }
      }

      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Get the user's profile_id
        const profileResult = await client.query(
          "select id from app_public.profiles where firebase_uid = $1 limit 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        // Insert wear log
        const wearLogResult = await client.query(
          `INSERT INTO app_public.wear_logs (profile_id, logged_date, outfit_id, photo_url)
           VALUES ($1, COALESCE($2::date, CURRENT_DATE), $3, $4)
           RETURNING *`,
          [profileId, loggedDate, outfitId, photoUrl]
        );

        const wearLog = wearLogResult.rows[0];

        // Insert wear log items
        for (const itemId of itemIds) {
          await client.query(
            `INSERT INTO app_public.wear_log_items (wear_log_id, item_id)
             VALUES ($1, $2)`,
            [wearLog.id, itemId]
          );
        }

        // Atomic wear count increment via RPC
        await client.query(
          "SELECT app_public.increment_wear_counts($1::uuid[], $2::date)",
          [itemIds, loggedDate || wearLog.logged_date]
        );

        await client.query("commit");

        const mapped = mapWearLogRow(wearLog);
        mapped.itemIds = itemIds;

        return mapped;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List wear logs for the authenticated user within a date range.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.startDate - Start date (YYYY-MM-DD).
     * @param {string} params.endDate - End date (YYYY-MM-DD).
     * @returns {Promise<Array<object>>} Array of wear logs with nested item IDs.
     */
    async listWearLogs(authContext, { startDate, endDate }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT wl.*,
                  COALESCE(
                    array_agg(wli.item_id) FILTER (WHERE wli.item_id IS NOT NULL),
                    ARRAY[]::uuid[]
                  ) as item_ids
           FROM app_public.wear_logs wl
           LEFT JOIN app_public.wear_log_items wli ON wli.wear_log_id = wl.id
           WHERE wl.logged_date >= $1::date AND wl.logged_date <= $2::date
           GROUP BY wl.id
           ORDER BY wl.logged_date DESC, wl.created_at DESC`,
          [startDate, endDate]
        );

        await client.query("commit");

        return result.rows.map(mapWearLogRow);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get wear logs for a specific date.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} date - Date string (YYYY-MM-DD).
     * @returns {Promise<Array<object>>} Array of wear logs for the given date.
     */
    async getWearLogsForDate(authContext, date) {
      return this.listWearLogs(authContext, { startDate: date, endDate: date });
    },
  };
}
