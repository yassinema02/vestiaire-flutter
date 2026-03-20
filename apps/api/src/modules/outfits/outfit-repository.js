/**
 * Repository for outfit CRUD operations.
 *
 * Handles creating outfits with associated items in a single transaction.
 * All queries are RLS-scoped via set_config('app.current_user_id').
 */

/** Default recency window in days for recently worn items. */
export const RECENCY_WINDOW_DAYS = 7;

/**
 * Map a database outfit row to camelCase response object.
 * @param {object} row - Database row.
 * @returns {object} Mapped outfit object.
 */
export function mapOutfitRow(row) {
  return {
    id: row.id,
    profileId: row.profile_id,
    name: row.name,
    explanation: row.explanation,
    occasion: row.occasion,
    source: row.source,
    isFavorite: row.is_favorite,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    items: row.items ?? [],
  };
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createOutfitRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create an outfit with associated items in a single transaction.
     *
     * Validates item ownership before creating the outfit.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.name - Outfit name.
     * @param {string} [params.explanation] - AI explanation.
     * @param {string} [params.occasion] - Occasion type.
     * @param {string} [params.source] - Source: 'ai' or 'manual'.
     * @param {Array<{itemId: string, position: number}>} params.items - Items to associate.
     * @returns {Promise<object>} Created outfit with items.
     */
    async createOutfit(authContext, { name, explanation, occasion, source, items }) {
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

        // Validate all item IDs belong to the user
        const itemIds = items.map(i => i.itemId);
        const validationResult = await client.query(
          "SELECT id FROM app_public.items WHERE id = ANY($1::uuid[]) AND profile_id = $2",
          [itemIds, profileId]
        );

        if (validationResult.rows.length !== items.length) {
          const err = new Error("One or more items not found");
          err.statusCode = 400;
          err.code = "INVALID_ITEM";
          throw err;
        }

        // Insert outfit
        const outfitResult = await client.query(
          `INSERT INTO app_public.outfits (profile_id, name, explanation, occasion, source)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [profileId, name, explanation ?? null, occasion ?? null, source ?? "ai"]
        );

        const outfit = outfitResult.rows[0];

        // Insert outfit items
        const outfitItems = [];
        for (const item of items) {
          const itemResult = await client.query(
            `INSERT INTO app_public.outfit_items (outfit_id, item_id, position)
             VALUES ($1, $2, $3)
             RETURNING *`,
            [outfit.id, item.itemId, item.position]
          );
          outfitItems.push(itemResult.rows[0]);
        }

        await client.query("commit");

        const mapped = mapOutfitRow(outfit);
        mapped.items = outfitItems.map(oi => ({
          id: oi.item_id,
          position: oi.position,
        }));

        return mapped;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List all outfits for the authenticated user with their items.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} Array of outfits with items, ordered by created_at DESC.
     */
    async listOutfits(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT o.*,
                  json_agg(
                    json_build_object(
                      'id', oi.item_id,
                      'position', oi.position,
                      'name', i.name,
                      'category', i.category,
                      'color', i.color,
                      'photoUrl', i.photo_url
                    ) ORDER BY oi.position
                  ) as items
           FROM app_public.outfits o
           LEFT JOIN app_public.outfit_items oi ON oi.outfit_id = o.id
           LEFT JOIN app_public.items i ON i.id = oi.item_id
           GROUP BY o.id
           ORDER BY o.created_at DESC`
        );

        await client.query("commit");

        return result.rows.map(row => {
          const mapped = mapOutfitRow(row);
          // Handle json_agg null: LEFT JOIN with no items produces [null]
          if (mapped.items && mapped.items.length === 1 && mapped.items[0] === null) {
            mapped.items = [];
          }
          return mapped;
        });
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Update an outfit's fields.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} outfitId - UUID of the outfit.
     * @param {object} fields - Fields to update.
     * @param {boolean} [fields.isFavorite] - New favorite status.
     * @returns {Promise<object>} Updated outfit.
     */
    async updateOutfit(authContext, outfitId, { isFavorite }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `UPDATE app_public.outfits SET is_favorite = $1 WHERE id = $2 RETURNING *`,
          [isFavorite, outfitId]
        );

        if (result.rows.length === 0) {
          const err = new Error("Outfit not found");
          err.statusCode = 404;
          err.code = "NOT_FOUND";
          throw err;
        }

        await client.query("commit");

        return mapOutfitRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Delete an outfit by ID.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} outfitId - UUID of the outfit.
     * @returns {Promise<object>} Deletion confirmation.
     */
    async deleteOutfit(authContext, outfitId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `DELETE FROM app_public.outfits WHERE id = $1 RETURNING id`,
          [outfitId]
        );

        if (result.rows.length === 0) {
          const err = new Error("Outfit not found");
          err.statusCode = 404;
          err.code = "NOT_FOUND";
          throw err;
        }

        await client.query("commit");

        return { deleted: true, id: outfitId };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get distinct items from outfits saved within a recent time window.
     *
     * Used for recency bias mitigation: items returned here were recently
     * part of saved outfits and the AI should try to avoid re-suggesting them.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} [options]
     * @param {number} [options.days=7] - Number of days to look back.
     * @returns {Promise<Array<{id: string, name: string, category: string, color: string}>>}
     */
    async getRecentOutfitItems(authContext, { days = RECENCY_WINDOW_DAYS } = {}) {
      const client = await pool.connect();
      try {
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT DISTINCT i.id, i.name, i.category, i.color
           FROM app_public.outfit_items oi
           JOIN app_public.outfits o ON o.id = oi.outfit_id
           JOIN app_public.items i ON i.id = oi.item_id
           WHERE o.created_at >= NOW() - INTERVAL '1 day' * $1
           ORDER BY i.name`,
          [days]
        );

        return result.rows.map(row => ({
          id: row.id,
          name: row.name,
          category: row.category,
          color: row.color,
        }));
      } finally {
        client.release();
      }
    },

    /**
     * Get a single outfit by ID with its items joined.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} outfitId - UUID of the outfit.
     * @returns {Promise<object|null>} Outfit with items, or null if not found.
     */
    async getOutfit(authContext, outfitId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT o.*,
                  json_agg(
                    json_build_object(
                      'id', oi.item_id,
                      'position', oi.position,
                      'name', i.name,
                      'category', i.category,
                      'color', i.color,
                      'photoUrl', i.photo_url
                    ) ORDER BY oi.position
                  ) as items
           FROM app_public.outfits o
           LEFT JOIN app_public.outfit_items oi ON oi.outfit_id = o.id
           LEFT JOIN app_public.items i ON i.id = oi.item_id
           WHERE o.id = $1
           GROUP BY o.id`,
          [outfitId]
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return null;
        }

        return mapOutfitRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}
