/**
 * Repository for shopping scan data access.
 *
 * Handles CRUD operations for the shopping_scans table.
 * Uses RLS via app.current_user_id setting for row-level security.
 *
 * Story 8.1: Product URL Scraping (FR-SHP-11)
 */

/**
 * Map a database row (snake_case) to a JavaScript object (camelCase).
 */
export function mapScanRow(row) {
  return {
    id: row.id,
    profileId: row.profile_id,
    url: row.url ?? null,
    scanType: row.scan_type,
    productName: row.product_name ?? null,
    brand: row.brand ?? null,
    price: row.price != null ? parseFloat(row.price) : null,
    currency: row.currency ?? null,
    imageUrl: row.image_url ?? null,
    category: row.category ?? null,
    color: row.color ?? null,
    secondaryColors: row.secondary_colors ?? null,
    pattern: row.pattern ?? null,
    material: row.material ?? null,
    style: row.style ?? null,
    season: row.season ?? null,
    occasion: row.occasion ?? null,
    formalityScore: row.formality_score != null ? parseInt(row.formality_score, 10) : null,
    extractionMethod: row.extraction_method ?? null,
    compatibilityScore: row.compatibility_score != null ? parseInt(row.compatibility_score, 10) : null,
    insights: row.insights ?? null,
    wishlisted: row.wishlisted ?? false,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
  };
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createShoppingScanRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create a shopping scan record.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} scanData - Scan fields to insert.
     * @returns {Promise<object>} The created scan in camelCase.
     */
    async createScan(authContext, scanData) {
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
          `INSERT INTO app_public.shopping_scans
             (profile_id, url, scan_type, product_name, brand, price, currency, image_url,
              category, color, secondary_colors, pattern, material, style, season, occasion,
              formality_score, extraction_method)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::text[], $12, $13, $14, $15::text[], $16::text[], $17, $18)
           RETURNING *`,
          [
            profileId,
            scanData.url ?? null,
            scanData.scanType ?? "url",
            scanData.productName ?? null,
            scanData.brand ?? null,
            scanData.price ?? null,
            scanData.currency ?? "GBP",
            scanData.imageUrl ?? null,
            scanData.category ?? null,
            scanData.color ?? null,
            scanData.secondaryColors ?? null,
            scanData.pattern ?? null,
            scanData.material ?? null,
            scanData.style ?? null,
            scanData.season ?? null,
            scanData.occasion ?? null,
            scanData.formalityScore ?? null,
            scanData.extractionMethod ?? null,
          ]
        );

        await client.query("commit");
        return mapScanRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get a single scan by ID (with RLS).
     *
     * @param {object} authContext - Auth context with userId.
     * @param {string} scanId - Scan UUID.
     * @returns {Promise<object|null>} The scan or null.
     */
    async getScanById(authContext, scanId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          "SELECT * FROM app_public.shopping_scans WHERE id = $1",
          [scanId]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;
        return mapScanRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List scans for the authenticated user with pagination.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} options
     * @param {number} options.limit - Max results (default 20).
     * @param {number} options.offset - Offset (default 0).
     * @returns {Promise<Array<object>>} Scans ordered by created_at DESC.
     */
    /**
     * Update a shopping scan record (partial update).
     *
     * @param {object} authContext - Auth context with userId.
     * @param {string} scanId - Scan UUID.
     * @param {object} updateData - Fields to update (camelCase keys).
     * @returns {Promise<object|null>} The updated scan or null if not found (RLS).
     */
    async updateScan(authContext, scanId, updateData) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Map camelCase to snake_case for updatable fields
        const fieldMap = {
          productName: "product_name",
          brand: "brand",
          price: "price",
          currency: "currency",
          category: "category",
          color: "color",
          secondaryColors: "secondary_colors",
          pattern: "pattern",
          material: "material",
          style: "style",
          season: "season",
          occasion: "occasion",
          formalityScore: "formality_score",
          compatibilityScore: "compatibility_score",
          wishlisted: "wishlisted",
          insights: "insights",
        };

        const setClauses = [];
        const values = [scanId]; // $1 = scanId
        let paramIndex = 2;

        for (const [camelKey, snakeKey] of Object.entries(fieldMap)) {
          if (updateData[camelKey] !== undefined) {
            const val = updateData[camelKey];
            if (snakeKey === "secondary_colors" || snakeKey === "season" || snakeKey === "occasion") {
              setClauses.push(`${snakeKey} = $${paramIndex}::text[]`);
            } else if (snakeKey === "insights") {
              setClauses.push(`${snakeKey} = $${paramIndex}::jsonb`);
              // Serialize JSON object to string for the parameter
              values.push(val != null ? JSON.stringify(val) : null);
              paramIndex++;
              continue;
            } else {
              setClauses.push(`${snakeKey} = $${paramIndex}`);
            }
            values.push(val);
            paramIndex++;
          }
        }

        if (setClauses.length === 0) {
          // Nothing to update, just return the existing scan
          const existing = await client.query(
            "SELECT * FROM app_public.shopping_scans WHERE id = $1",
            [scanId]
          );
          await client.query("commit");
          if (existing.rows.length === 0) return null;
          return mapScanRow(existing.rows[0]);
        }

        const sql = `UPDATE app_public.shopping_scans SET ${setClauses.join(", ")} WHERE id = $1 RETURNING *`;
        const result = await client.query(sql, values);

        await client.query("commit");

        if (result.rows.length === 0) return null;
        return mapScanRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async listScans(authContext, { limit = 20, offset = 0 } = {}) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          "SELECT * FROM app_public.shopping_scans ORDER BY created_at DESC LIMIT $1 OFFSET $2",
          [limit, offset]
        );

        await client.query("commit");
        return result.rows.map(mapScanRow);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}
