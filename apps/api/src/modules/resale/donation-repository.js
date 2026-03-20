/**
 * Repository for donation log data access.
 *
 * Handles CRUD operations for donation_log table including
 * donation creation, listing with item metadata, and summary aggregations.
 *
 * Story 13.3: Spring Clean Declutter Flow & Donations (FR-DON-01, FR-DON-02, FR-DON-03, FR-DON-05)
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createDonationRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create a donation log entry.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.itemId - Item UUID.
     * @param {string|null} params.charityName - Optional charity/organization name.
     * @param {number} params.estimatedValue - Estimated donation value.
     * @param {string|null} params.donationDate - Optional donation date (default today).
     * @returns {Promise<object>} The inserted row in camelCase.
     */
    async createDonation(authContext, { itemId, charityName = null, estimatedValue = 0, donationDate = null }) {
      const client = await pool.connect();
      try {
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
          throw { statusCode: 401, message: "Profile not found" };
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `INSERT INTO app_public.donation_log
             (profile_id, item_id, charity_name, estimated_value, donation_date)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [profileId, itemId, charityName, estimatedValue, donationDate || new Date().toISOString().split("T")[0]]
        );

        const row = result.rows[0];
        return {
          id: row.id,
          profileId: row.profile_id,
          itemId: row.item_id,
          charityName: row.charity_name,
          estimatedValue: parseFloat(row.estimated_value),
          donationDate: row.donation_date instanceof Date ? row.donation_date.toISOString().split("T")[0] : row.donation_date,
          createdAt: row.created_at?.toISOString?.() ?? row.created_at,
        };
      } finally {
        client.release();
      }
    },

    /**
     * List donation log entries for the authenticated user with item metadata.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} options
     * @param {number} options.limit - Max entries (default 50).
     * @param {number} options.offset - Offset (default 0).
     * @returns {Promise<Array<object>>} Donation entries with item metadata.
     */
    async listDonations(authContext, { limit = 50, offset = 0 } = {}) {
      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT dl.*, i.name as item_name, i.photo_url as item_photo_url, i.category as item_category, i.brand as item_brand
           FROM app_public.donation_log dl
           JOIN app_public.items i ON dl.item_id = i.id
           ORDER BY dl.created_at DESC
           LIMIT $1 OFFSET $2`,
          [limit, offset]
        );

        return result.rows.map((row) => ({
          id: row.id,
          profileId: row.profile_id,
          itemId: row.item_id,
          charityName: row.charity_name,
          estimatedValue: parseFloat(row.estimated_value),
          donationDate: row.donation_date instanceof Date ? row.donation_date.toISOString().split("T")[0] : row.donation_date,
          createdAt: row.created_at?.toISOString?.() ?? row.created_at,
          itemName: row.item_name,
          itemPhotoUrl: row.item_photo_url,
          itemCategory: row.item_category,
          itemBrand: row.item_brand,
        }));
      } finally {
        client.release();
      }
    },

    /**
     * Get donation summary for the authenticated user.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} { totalDonated: number, totalValue: number }
     */
    async getDonationSummary(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT COUNT(*) as total_donated, COALESCE(SUM(estimated_value), 0) as total_value
           FROM app_public.donation_log`
        );

        const row = result.rows[0];
        return {
          totalDonated: parseInt(row.total_donated, 10),
          totalValue: parseFloat(row.total_value),
        };
      } finally {
        client.release();
      }
    },
  };
}
