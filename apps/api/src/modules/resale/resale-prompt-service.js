/**
 * Resale prompt service for monthly resale candidate identification and prompts.
 *
 * Identifies neglected wardrobe items eligible for resale, creates prompt records,
 * and sends push notifications. Handles prompt lifecycle (pending, accepted, dismissed).
 *
 * Story 13.2: Monthly Resale Prompts (FR-RSL-01, FR-RSL-05, FR-RSL-06)
 */

/**
 * Compute the depreciation factor based on wear count.
 * @param {number} wearCount - Number of times the item has been worn.
 * @returns {number} Depreciation factor (0.4 to 0.7).
 */
export function getDepreciationFactor(wearCount) {
  if (wearCount >= 20) return 0.4;
  if (wearCount >= 6) return 0.5;
  if (wearCount >= 1) return 0.6;
  return 0.7;
}

/**
 * Compute the estimated sale price for an item.
 * @param {number|null} purchasePrice - Original purchase price (may be null).
 * @param {number} wearCount - Number of times worn.
 * @returns {number} Estimated sale price (minimum 1, default 10 if no purchase price).
 */
export function computeEstimatedPrice(purchasePrice, wearCount) {
  if (purchasePrice == null || purchasePrice === 0) return 10;
  const factor = getDepreciationFactor(wearCount);
  return Math.max(1, Math.round(purchasePrice * factor));
}

/**
 * Factory to create a resale prompt service.
 *
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 * @param {object} options.notificationService - Notification service instance.
 * @returns {object} Resale prompt service instance.
 */
export function createResalePromptService({ pool, notificationService }) {
  return {
    /**
     * Identify resale candidates for the authenticated user.
     * Returns up to `limit` neglected items eligible for resale prompts.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} [options]
     * @param {number} [options.limit=3] - Max candidates to return.
     * @returns {Promise<Array>} Array of candidate objects.
     */
    async identifyResaleCandidates(authContext, { limit = 3 } = {}) {
      const client = await pool.connect();
      try {
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId]);

        const result = await client.query(
          `SELECT i.id, i.name, i.category, i.photo_url, i.brand,
                  i.purchase_price, i.currency, i.wear_count, i.last_worn_date, i.created_at,
                  COALESCE(i.purchase_price, 0) AS raw_price,
                  COALESCE(i.wear_count, 0) AS wears
           FROM app_public.items i
           WHERE i.resale_status IS NULL
             AND (
               (COALESCE(i.wear_count, 0) > 0 AND i.last_worn_date IS NOT NULL AND i.last_worn_date < CURRENT_DATE - INTERVAL '180 days')
               OR (COALESCE(i.wear_count, 0) = 0 AND i.created_at < CURRENT_DATE - INTERVAL '180 days')
             )
             AND i.id NOT IN (
               SELECT rp.item_id FROM app_public.resale_prompts rp
               WHERE rp.dismissed_until > CURRENT_DATE
             )
           ORDER BY
             CASE WHEN i.purchase_price IS NOT NULL AND COALESCE(i.wear_count, 0) > 0
                  THEN i.purchase_price / GREATEST(i.wear_count, 1)
                  ELSE 999999 END DESC,
             COALESCE(i.last_worn_date, i.created_at) ASC
           LIMIT $1`,
          [limit]
        );

        return result.rows.map((row) => {
          const wearCount = parseInt(row.wears, 10) || 0;
          const purchasePrice = row.purchase_price ? parseFloat(row.purchase_price) : null;
          const estimatedPrice = computeEstimatedPrice(purchasePrice, wearCount);
          const lastWornOrCreated = row.last_worn_date || row.created_at;
          const daysSinceLastWorn = Math.floor(
            (Date.now() - new Date(lastWornOrCreated).getTime()) / (1000 * 60 * 60 * 24)
          );

          return {
            itemId: row.id,
            name: row.name,
            category: row.category,
            photoUrl: row.photo_url,
            brand: row.brand,
            purchasePrice,
            currency: row.currency || "GBP",
            wearCount,
            daysSinceLastWorn,
            estimatedPrice,
            estimatedCurrency: "GBP",
          };
        });
      } finally {
        client.release();
      }
    },

    /**
     * Create prompt records for the given candidates.
     *
     * @param {object} authContext - Auth context with userId and profileId.
     * @param {Array} candidates - Array of candidate objects from identifyResaleCandidates.
     * @returns {Promise<Array>} Array of created prompt records with IDs.
     */
    async createPromptBatch(authContext, candidates) {
      const client = await pool.connect();
      try {
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId]);

        // Get profile ID
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        if (profileResult.rows.length === 0) return [];
        const profileId = profileResult.rows[0].id;

        const prompts = [];
        for (const candidate of candidates) {
          const result = await client.query(
            `INSERT INTO app_public.resale_prompts (profile_id, item_id, estimated_price, estimated_currency)
             VALUES ($1, $2, $3, $4)
             RETURNING id, profile_id, item_id, estimated_price, estimated_currency, action, dismissed_until, created_at`,
            [profileId, candidate.itemId, candidate.estimatedPrice, candidate.estimatedCurrency]
          );
          prompts.push(result.rows[0]);
        }

        return prompts;
      } finally {
        client.release();
      }
    },

    /**
     * Evaluate and notify: identify candidates, create prompts, send notification.
     *
     * @param {object} authContext - Auth context.
     * @returns {Promise<object>} Result with candidates count and prompted flag.
     */
    async evaluateAndNotify(authContext) {
      const candidates = await this.identifyResaleCandidates(authContext);

      if (candidates.length === 0) {
        return { candidates: 0, prompted: false };
      }

      const prompts = await this.createPromptBatch(authContext, candidates);

      // Get profile ID for notification
      const client = await pool.connect();
      try {
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        if (profileResult.rows.length > 0 && prompts.length > 0) {
          const profileId = profileResult.rows[0].id;
          // Fire-and-forget notification
          notificationService.sendPushNotification(
            profileId,
            {
              title: "Time to declutter?",
              body: `You have ${candidates.length} item${candidates.length > 1 ? "s" : ""} you haven't worn in months. See what they could sell for!`,
              data: { type: "resale_prompt", promptId: prompts[0].id },
            },
            { preferenceKey: "resale_prompts" }
          ).catch((err) => {
            console.error("[resale-prompt-service] Notification failed:", err.message);
          });
        }
      } finally {
        client.release();
      }

      return { candidates: candidates.length, prompted: true };
    },

    /**
     * Get pending prompts for the current month.
     *
     * @param {object} authContext - Auth context.
     * @returns {Promise<Array>} Array of pending prompt objects with item metadata.
     */
    async getPendingPrompts(authContext) {
      const client = await pool.connect();
      try {
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId]);

        const result = await client.query(
          `SELECT rp.id, rp.profile_id, rp.item_id, rp.estimated_price, rp.estimated_currency,
                  rp.action, rp.dismissed_until, rp.created_at,
                  i.name AS item_name, i.photo_url AS item_photo_url,
                  i.category AS item_category, i.brand AS item_brand,
                  i.wear_count AS item_wear_count, i.last_worn_date AS item_last_worn_date,
                  i.created_at AS item_created_at
           FROM app_public.resale_prompts rp
           JOIN app_public.items i ON rp.item_id = i.id
           WHERE rp.action IS NULL
             AND rp.created_at >= DATE_TRUNC('month', CURRENT_DATE)
           ORDER BY rp.created_at DESC`
        );

        return result.rows.map((row) => ({
          id: row.id,
          profileId: row.profile_id,
          itemId: row.item_id,
          estimatedPrice: parseFloat(row.estimated_price),
          estimatedCurrency: row.estimated_currency,
          action: row.action,
          dismissedUntil: row.dismissed_until,
          createdAt: row.created_at,
          itemName: row.item_name,
          itemPhotoUrl: row.item_photo_url,
          itemCategory: row.item_category,
          itemBrand: row.item_brand,
          itemWearCount: parseInt(row.item_wear_count, 10) || 0,
          itemLastWornDate: row.item_last_worn_date,
          itemCreatedAt: row.item_created_at,
        }));
      } finally {
        client.release();
      }
    },

    /**
     * Update the action on a prompt record.
     *
     * @param {object} authContext - Auth context.
     * @param {string} promptId - Prompt UUID.
     * @param {object} options
     * @param {string} options.action - 'accepted' or 'dismissed'.
     * @returns {Promise<object>} Updated prompt record.
     */
    async updatePromptAction(authContext, promptId, { action }) {
      if (action !== "accepted" && action !== "dismissed") {
        const error = new Error("action must be 'accepted' or 'dismissed'");
        error.statusCode = 400;
        throw error;
      }

      const client = await pool.connect();
      try {
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId]);

        const dismissedUntil = action === "dismissed"
          ? new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0]
          : null;

        const result = await client.query(
          `UPDATE app_public.resale_prompts
           SET action = $1, dismissed_until = $2
           WHERE id = $3
           RETURNING id, profile_id, item_id, estimated_price, estimated_currency, action, dismissed_until, created_at`,
          [action, dismissedUntil, promptId]
        );

        if (result.rows.length === 0) {
          const error = new Error("Prompt not found");
          error.statusCode = 404;
          throw error;
        }

        return {
          id: result.rows[0].id,
          profileId: result.rows[0].profile_id,
          itemId: result.rows[0].item_id,
          estimatedPrice: parseFloat(result.rows[0].estimated_price),
          estimatedCurrency: result.rows[0].estimated_currency,
          action: result.rows[0].action,
          dismissedUntil: result.rows[0].dismissed_until,
          createdAt: result.rows[0].created_at,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get the count of pending prompts for the current month.
     *
     * @param {object} authContext - Auth context.
     * @returns {Promise<number>} Count of pending prompts.
     */
    async getPendingCount(authContext) {
      const client = await pool.connect();
      try {
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId]);

        const result = await client.query(
          `SELECT COUNT(*) as count FROM app_public.resale_prompts
           WHERE action IS NULL
             AND created_at >= DATE_TRUNC('month', CURRENT_DATE)`
        );

        return parseInt(result.rows[0].count, 10);
      } finally {
        client.release();
      }
    },
  };
}
