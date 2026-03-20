const NEGLECT_THRESHOLD_DAYS = 180;

function computeNeglectStatus(row) {
  const thresholdMs = NEGLECT_THRESHOLD_DAYS * 24 * 60 * 60 * 1000;
  const now = Date.now();

  // Use last_worn_date if available (future Epic 5)
  const wearCount = row.wear_count ?? 0;
  if (wearCount > 0 && row.last_worn_date) {
    const lastWorn = new Date(row.last_worn_date).getTime();
    return (now - lastWorn) > thresholdMs ? "neglected" : null;
  }

  // Fallback: use created_at for items never worn
  if (row.created_at) {
    const created = new Date(row.created_at).getTime();
    return (now - created) > thresholdMs ? "neglected" : null;
  }

  return null;
}

function mapItemRow(row) {
  return {
    id: row.id,
    profileId: row.profile_id,
    photoUrl: row.photo_url,
    originalPhotoUrl: row.original_photo_url ?? null,
    name: row.name ?? null,
    bgRemovalStatus: row.bg_removal_status ?? null,
    category: row.category ?? null,
    color: row.color ?? null,
    secondaryColors: row.secondary_colors ?? null,
    pattern: row.pattern ?? null,
    material: row.material ?? null,
    style: row.style ?? null,
    season: row.season ?? null,
    occasion: row.occasion ?? null,
    categorizationStatus: row.categorization_status ?? null,
    brand: row.brand ?? null,
    purchasePrice: row.purchase_price != null ? parseFloat(row.purchase_price) : null,
    purchaseDate: row.purchase_date != null ? (typeof row.purchase_date === "string" ? row.purchase_date : row.purchase_date.toISOString().split("T")[0]) : null,
    currency: row.currency ?? null,
    isFavorite: row.is_favorite ?? false,
    neglectStatus: computeNeglectStatus(row),
    resaleStatus: row.resale_status ?? null,
    creationMethod: row.creation_method ?? "manual",
    extractionJobId: row.extraction_job_id ?? null,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null
  };
}

export function createItemRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    async createItem(authContext, { photoUrl, name, originalPhotoUrl = null, bgRemovalStatus = null, categorizationStatus = null }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up the profile ID for the authenticated user
        const profileResult = await client.query(
          `select id from app_public.profiles where firebase_uid = $1 limit 1`,
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `insert into app_public.items (profile_id, photo_url, name, original_photo_url, bg_removal_status, categorization_status)
           values ($1, $2, $3, $4, $5, $6)
           returning *`,
          [profileId, photoUrl, name ?? null, originalPhotoUrl, bgRemovalStatus, categorizationStatus]
        );

        await client.query("commit");
        return mapItemRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async createItemFromExtraction(authContext, {
      photoUrl, name, originalPhotoUrl = null, category = null, color = null,
      secondaryColors = null, pattern = null, material = null, style = null,
      season = null, occasion = null, bgRemovalStatus = null,
      categorizationStatus = null, creationMethod = "ai_extraction",
      extractionJobId = null
    }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const profileResult = await client.query(
          `select id from app_public.profiles where firebase_uid = $1 limit 1`,
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `insert into app_public.items
             (profile_id, photo_url, name, original_photo_url,
              category, color, secondary_colors, pattern, material, style,
              season, occasion, bg_removal_status, categorization_status,
              creation_method, extraction_job_id)
           values ($1, $2, $3, $4, $5, $6, $7::text[], $8, $9, $10,
                   $11::text[], $12::text[], $13, $14, $15, $16)
           returning *`,
          [
            profileId, photoUrl, name ?? null, originalPhotoUrl,
            category, color, secondaryColors ?? [], pattern, material, style,
            season ?? [], occasion ?? [], bgRemovalStatus, categorizationStatus,
            creationMethod, extractionJobId
          ]
        );

        await client.query("commit");
        return mapItemRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async getItem(authContext, itemId) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `select i.*
             from app_public.items i
             join app_public.profiles p on p.id = i.profile_id
            where i.id = $1
              and p.firebase_uid = $2
            limit 1`,
          [itemId, authContext.userId]
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return null;
        }

        return mapItemRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async updateItem(authContext, itemId, fields) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Build dynamic SET clause from provided fields
        const setClauses = [];
        const values = [];
        let paramIndex = 1;

        if (fields.photoUrl !== undefined) {
          setClauses.push(`photo_url = $${paramIndex++}`);
          values.push(fields.photoUrl);
        }

        if (fields.bgRemovalStatus !== undefined) {
          setClauses.push(`bg_removal_status = $${paramIndex++}`);
          values.push(fields.bgRemovalStatus);
        }

        if (fields.originalPhotoUrl !== undefined) {
          setClauses.push(`original_photo_url = $${paramIndex++}`);
          values.push(fields.originalPhotoUrl);
        }

        if (fields.name !== undefined) {
          setClauses.push(`name = $${paramIndex++}`);
          values.push(fields.name);
        }

        if (fields.category !== undefined) {
          setClauses.push(`category = $${paramIndex++}`);
          values.push(fields.category);
        }

        if (fields.color !== undefined) {
          setClauses.push(`color = $${paramIndex++}`);
          values.push(fields.color);
        }

        if (fields.secondary_colors !== undefined) {
          setClauses.push(`secondary_colors = $${paramIndex++}::text[]`);
          values.push(fields.secondary_colors);
        }

        if (fields.pattern !== undefined) {
          setClauses.push(`pattern = $${paramIndex++}`);
          values.push(fields.pattern);
        }

        if (fields.material !== undefined) {
          setClauses.push(`material = $${paramIndex++}`);
          values.push(fields.material);
        }

        if (fields.style !== undefined) {
          setClauses.push(`style = $${paramIndex++}`);
          values.push(fields.style);
        }

        if (fields.season !== undefined) {
          setClauses.push(`season = $${paramIndex++}::text[]`);
          values.push(fields.season);
        }

        if (fields.occasion !== undefined) {
          setClauses.push(`occasion = $${paramIndex++}::text[]`);
          values.push(fields.occasion);
        }

        if (fields.categorizationStatus !== undefined) {
          setClauses.push(`categorization_status = $${paramIndex++}`);
          values.push(fields.categorizationStatus);
        }

        if (fields.brand !== undefined) {
          setClauses.push(`brand = $${paramIndex++}`);
          values.push(fields.brand);
        }

        if (fields.purchasePrice !== undefined) {
          setClauses.push(`purchase_price = $${paramIndex++}`);
          values.push(fields.purchasePrice);
        }

        if (fields.purchaseDate !== undefined) {
          setClauses.push(`purchase_date = $${paramIndex++}`);
          values.push(fields.purchaseDate);
        }

        if (fields.currency !== undefined) {
          setClauses.push(`currency = $${paramIndex++}`);
          values.push(fields.currency);
        }

        if (fields.isFavorite !== undefined) {
          setClauses.push(`is_favorite = $${paramIndex++}`);
          values.push(fields.isFavorite);
        }

        if (fields.resaleStatus !== undefined) {
          setClauses.push(`resale_status = $${paramIndex++}`);
          values.push(fields.resaleStatus);
        }

        if (setClauses.length === 0) {
          throw new Error("No fields to update");
        }

        setClauses.push(`updated_at = NOW()`);

        // Ensure the item belongs to the authenticated user
        values.push(itemId);
        values.push(authContext.userId);

        const result = await client.query(
          `UPDATE app_public.items i
           SET ${setClauses.join(", ")}
           FROM app_public.profiles p
           WHERE i.id = $${paramIndex++}
             AND i.profile_id = p.id
             AND p.firebase_uid = $${paramIndex}
           RETURNING i.*`,
          values
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return null;
        }

        return mapItemRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async deleteItem(authContext, itemId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `DELETE FROM app_public.items
           WHERE id = $1
             AND profile_id = (
               SELECT id FROM app_public.profiles WHERE firebase_uid = $2
             )
           RETURNING id`,
          [itemId, authContext.userId]
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return null;
        }
        return { deleted: true };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async listItems(authContext, { limit, category, color, season, occasion, brand, neglectStatus, resaleStatus } = {}) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const whereClauses = ["p.firebase_uid = $1"];
        const values = [authContext.userId];
        let paramIndex = 2;

        if (category) {
          whereClauses.push(`i.category = $${paramIndex++}`);
          values.push(category);
        }
        if (color) {
          whereClauses.push(`i.color = $${paramIndex++}`);
          values.push(color);
        }
        if (season) {
          whereClauses.push(`$${paramIndex++} = ANY(i.season)`);
          values.push(season);
        }
        if (occasion) {
          whereClauses.push(`$${paramIndex++} = ANY(i.occasion)`);
          values.push(occasion);
        }
        if (brand) {
          whereClauses.push(`i.brand = $${paramIndex++}`);
          values.push(brand);
        }
        if (resaleStatus) {
          whereClauses.push(`i.resale_status = $${paramIndex++}`);
          values.push(resaleStatus);
        }

        const queryLimit = limit && Number.isInteger(limit) && limit > 0 ? limit : 200;
        values.push(queryLimit);

        const result = await client.query(
          `select i.*
             from app_public.items i
             join app_public.profiles p on p.id = i.profile_id
            where ${whereClauses.join(" AND ")}
            order by i.created_at desc
            limit $${paramIndex}`,
          values
        );

        await client.query("commit");

        const mappedItems = result.rows.map(mapItemRow);

        // Post-query filter for computed neglect status
        if (neglectStatus) {
          return mappedItems.filter(item => item.neglectStatus === neglectStatus);
        }

        return mappedItems;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }
  };
}
