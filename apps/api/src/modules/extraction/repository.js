function mapJobRow(row) {
  return {
    id: row.id,
    profileId: row.profile_id,
    status: row.status,
    totalPhotos: row.total_photos,
    uploadedPhotos: row.uploaded_photos,
    processedPhotos: row.processed_photos,
    totalItemsFound: row.total_items_found,
    errorMessage: row.error_message ?? null,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null
  };
}

function mapPhotoRow(row) {
  return {
    id: row.id,
    jobId: row.job_id,
    photoUrl: row.photo_url,
    originalFilename: row.original_filename ?? null,
    status: row.status,
    itemsFound: row.items_found,
    errorMessage: row.error_message ?? null,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null
  };
}

function mapItemRow(row) {
  return {
    id: row.id,
    jobId: row.job_id,
    photoId: row.photo_id,
    itemIndex: row.item_index,
    photoUrl: row.photo_url,
    originalCropUrl: row.original_crop_url ?? null,
    category: row.category,
    color: row.color,
    secondaryColors: row.secondary_colors ?? [],
    pattern: row.pattern,
    material: row.material,
    style: row.style,
    season: row.season ?? [],
    occasion: row.occasion ?? [],
    bgRemovalStatus: row.bg_removal_status,
    categorizationStatus: row.categorization_status,
    detectionConfidence: row.detection_confidence ?? null,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null
  };
}

export function createExtractionRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    async createJob(authContext, { totalPhotos }) {
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
          `insert into app_public.wardrobe_extraction_jobs (profile_id, total_photos)
           values ($1, $2)
           returning *`,
          [profileId, totalPhotos]
        );

        await client.query("commit");
        return mapJobRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async getJob(authContext, jobId) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `select wej.*
             from app_public.wardrobe_extraction_jobs wej
             join app_public.profiles p on p.id = wej.profile_id
            where wej.id = $1
              and p.firebase_uid = $2
            limit 1`,
          [jobId, authContext.userId]
        );

        if (result.rows.length === 0) {
          await client.query("commit");
          return null;
        }

        const job = mapJobRow(result.rows[0]);

        // Fetch associated photos
        const photosResult = await client.query(
          `select * from app_public.extraction_job_photos
            where job_id = $1
            order by created_at asc`,
          [jobId]
        );

        // Fetch associated items
        const itemsResult = await client.query(
          `select * from app_public.extraction_job_items
            where job_id = $1
            order by photo_id, item_index asc`,
          [jobId]
        );

        await client.query("commit");

        job.photos = photosResult.rows.map(mapPhotoRow);
        job.items = itemsResult.rows.map(mapItemRow);
        return job;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async updateJobStatus(authContext, jobId, { status, uploadedPhotos, processedPhotos, totalItemsFound, errorMessage }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const setClauses = [];
        const values = [jobId, authContext.userId];
        let paramIndex = 3;

        if (status !== undefined) {
          setClauses.push(`status = $${paramIndex++}`);
          values.push(status);
        }
        if (uploadedPhotos !== undefined) {
          setClauses.push(`uploaded_photos = $${paramIndex++}`);
          values.push(uploadedPhotos);
        }
        if (processedPhotos !== undefined) {
          setClauses.push(`processed_photos = $${paramIndex++}`);
          values.push(processedPhotos);
        }
        if (totalItemsFound !== undefined) {
          setClauses.push(`total_items_found = $${paramIndex++}`);
          values.push(totalItemsFound);
        }
        if (errorMessage !== undefined) {
          setClauses.push(`error_message = $${paramIndex++}`);
          values.push(errorMessage);
        }

        setClauses.push("updated_at = now()");

        const result = await client.query(
          `update app_public.wardrobe_extraction_jobs
              set ${setClauses.join(", ")}
            where id = $1
              and profile_id in (
                select id from app_public.profiles where firebase_uid = $2
              )
           returning *`,
          values
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return null;
        }

        return mapJobRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async addJobPhoto(authContext, { jobId, photoUrl, originalFilename }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `insert into app_public.extraction_job_photos (job_id, photo_url, original_filename)
           values ($1, $2, $3)
           returning *`,
          [jobId, photoUrl, originalFilename ?? null]
        );

        await client.query("commit");
        return mapPhotoRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async addJobItem(authContext, { jobId, photoId, itemIndex, photoUrl, originalCropUrl, category, color, secondaryColors, pattern, material, style, season, occasion, bgRemovalStatus, categorizationStatus, detectionConfidence }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `insert into app_public.extraction_job_items
             (job_id, photo_id, item_index, photo_url, original_crop_url, category, color, secondary_colors, pattern, material, style, season, occasion, bg_removal_status, categorization_status, detection_confidence)
           values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
           returning *`,
          [jobId, photoId, itemIndex, photoUrl, originalCropUrl ?? null, category ?? null, color ?? null, secondaryColors ?? [], pattern ?? null, material ?? null, style ?? null, season ?? [], occasion ?? [], bgRemovalStatus ?? "pending", categorizationStatus ?? "pending", detectionConfidence ?? null]
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

    async getJobItems(authContext, jobId) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `select * from app_public.extraction_job_items
            where job_id = $1
            order by photo_id, item_index asc`,
          [jobId]
        );

        await client.query("commit");
        return result.rows.map(mapItemRow);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async getExtractionItemsByIds(authContext, jobId, itemIds) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        if (!itemIds || itemIds.length === 0) {
          await client.query("commit");
          return [];
        }

        // Build parameterized IN clause
        const placeholders = itemIds.map((_, i) => `$${i + 2}`).join(", ");
        const result = await client.query(
          `select eji.* from app_public.extraction_job_items eji
            where eji.job_id = $1
              and eji.id in (${placeholders})
            order by eji.photo_id, eji.item_index asc`,
          [jobId, ...itemIds]
        );

        await client.query("commit");
        return result.rows.map(mapItemRow);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async updatePhotoStatus(authContext, photoId, { status, itemsFound, errorMessage }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const setClauses = [];
        const values = [photoId];
        let paramIndex = 2;

        if (status !== undefined) {
          setClauses.push(`status = $${paramIndex++}`);
          values.push(status);
        }
        if (itemsFound !== undefined) {
          setClauses.push(`items_found = $${paramIndex++}`);
          values.push(itemsFound);
        }
        if (errorMessage !== undefined) {
          setClauses.push(`error_message = $${paramIndex++}`);
          values.push(errorMessage);
        }

        if (setClauses.length === 0) {
          await client.query("commit");
          return null;
        }

        const result = await client.query(
          `update app_public.extraction_job_photos
              set ${setClauses.join(", ")}
            where id = $1
           returning *`,
          values
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          return null;
        }

        return mapPhotoRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }
  };
}
