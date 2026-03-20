/**
 * Repository for resale history data access.
 *
 * Handles CRUD operations for resale_history table including
 * history entry creation, listing, earnings summary, and monthly aggregations.
 *
 * Story 7.4: Resale Status & History Tracking (FR-RSL-07, FR-RSL-08, FR-RSL-10)
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createResaleHistoryRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create a resale history entry.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.itemId - Item UUID.
     * @param {string|null} params.resaleListingId - Optional resale listing UUID.
     * @param {string} params.type - 'sold' or 'donated'.
     * @param {number} params.salePrice - Sale price (0 for donated).
     * @param {string} params.saleCurrency - Currency code (default 'GBP').
     * @param {string|null} params.saleDate - Sale date (default today).
     * @returns {Promise<object>} The inserted row in camelCase.
     */
    async createHistoryEntry(authContext, { itemId, resaleListingId = null, type, salePrice = 0, saleCurrency = "GBP", saleDate = null }) {
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
          throw { statusCode: 401, message: "Profile not found" };
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `INSERT INTO app_public.resale_history
             (profile_id, item_id, resale_listing_id, type, sale_price, sale_currency, sale_date)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING *`,
          [profileId, itemId, resaleListingId, type, salePrice, saleCurrency, saleDate || new Date().toISOString().split("T")[0]]
        );

        await client.query("commit");

        const row = result.rows[0];
        return {
          id: row.id,
          profileId: row.profile_id,
          itemId: row.item_id,
          resaleListingId: row.resale_listing_id,
          type: row.type,
          salePrice: parseFloat(row.sale_price),
          saleCurrency: row.sale_currency,
          saleDate: row.sale_date instanceof Date ? row.sale_date.toISOString().split("T")[0] : row.sale_date,
          createdAt: row.created_at?.toISOString?.() ?? row.created_at,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List resale history entries for the authenticated user.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} options
     * @param {number} options.limit - Max entries (default 50).
     * @param {number} options.offset - Offset (default 0).
     * @returns {Promise<Array<object>>} History entries with item metadata.
     */
    async listHistory(authContext, { limit = 50, offset = 0 } = {}) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT rh.*, i.name as item_name, i.photo_url as item_photo_url, i.category as item_category, i.brand as item_brand
           FROM app_public.resale_history rh
           JOIN app_public.items i ON rh.item_id = i.id
           ORDER BY rh.created_at DESC
           LIMIT $1 OFFSET $2`,
          [limit, offset]
        );

        await client.query("commit");

        return result.rows.map((row) => ({
          id: row.id,
          profileId: row.profile_id,
          itemId: row.item_id,
          resaleListingId: row.resale_listing_id,
          type: row.type,
          salePrice: parseFloat(row.sale_price),
          saleCurrency: row.sale_currency,
          saleDate: row.sale_date instanceof Date ? row.sale_date.toISOString().split("T")[0] : row.sale_date,
          createdAt: row.created_at?.toISOString?.() ?? row.created_at,
          itemName: row.item_name,
          itemPhotoUrl: row.item_photo_url,
          itemCategory: row.item_category,
          itemBrand: row.item_brand,
        }));
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get earnings summary for the authenticated user.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} { itemsSold, itemsDonated, totalEarnings }
     */
    async getEarningsSummary(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT
             COUNT(*) FILTER (WHERE type = 'sold') as items_sold,
             COUNT(*) FILTER (WHERE type = 'donated') as items_donated,
             COALESCE(SUM(sale_price) FILTER (WHERE type = 'sold'), 0) as total_earnings
           FROM app_public.resale_history`
        );

        await client.query("commit");

        const row = result.rows[0];
        return {
          itemsSold: parseInt(row.items_sold, 10),
          itemsDonated: parseInt(row.items_donated, 10),
          totalEarnings: parseFloat(row.total_earnings),
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get monthly earnings aggregation.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} options
     * @param {number} options.months - Number of months to look back (default 6).
     * @returns {Promise<Array<object>>} { month, earnings } sorted chronologically.
     */
    async getMonthlyEarnings(authContext, { months = 6 } = {}) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT DATE_TRUNC('month', sale_date) as month, SUM(sale_price) as earnings
           FROM app_public.resale_history
           WHERE type = 'sold'
             AND sale_date >= (CURRENT_DATE - INTERVAL '1 month' * $1)
           GROUP BY DATE_TRUNC('month', sale_date)
           ORDER BY month ASC`,
          [months]
        );

        await client.query("commit");

        return result.rows.map((row) => ({
          month: row.month?.toISOString?.() ?? row.month,
          earnings: parseFloat(row.earnings),
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
