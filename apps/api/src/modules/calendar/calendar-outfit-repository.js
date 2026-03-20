/**
 * Repository for calendar outfit CRUD operations.
 *
 * Handles creating, reading, updating, and deleting scheduled outfit
 * assignments in the calendar_outfits table.
 * All queries are RLS-scoped via set_config('app.current_user_id').
 */

/**
 * Map a calendar outfit database row to camelCase response object.
 * @param {object} row - Database row.
 * @returns {object} Mapped calendar outfit object.
 */
export function mapCalendarOutfitRow(row) {
  return {
    id: row.id,
    profileId: row.profile_id,
    outfitId: row.outfit_id,
    calendarEventId: row.calendar_event_id,
    scheduledDate: row.scheduled_date,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    outfit: row.outfit_data ?? null,
  };
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createCalendarOutfitRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create a calendar outfit assignment.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.outfitId - UUID of the outfit to assign.
     * @param {string} [params.calendarEventId] - UUID of the calendar event (optional).
     * @param {string} params.scheduledDate - Date in YYYY-MM-DD format.
     * @param {string} [params.notes] - Optional notes.
     * @returns {Promise<object>} Created calendar outfit with joined outfit data.
     */
    async createCalendarOutfit(authContext, { outfitId, calendarEventId, scheduledDate, notes }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up the profile ID for the authenticated user
        const profileResult = await client.query(
          "select id from app_public.profiles where firebase_uid = $1 limit 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `INSERT INTO app_public.calendar_outfits
            (profile_id, outfit_id, calendar_event_id, scheduled_date, notes)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [profileId, outfitId, calendarEventId ?? null, scheduledDate, notes ?? null]
        );

        const row = result.rows[0];

        // Fetch joined outfit data
        const outfitResult = await client.query(
          `SELECT o.id, o.name, o.occasion, o.source,
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
          [row.outfit_id]
        );

        await client.query("commit");

        const mapped = mapCalendarOutfitRow(row);
        if (outfitResult.rows.length > 0) {
          const outfitRow = outfitResult.rows[0];
          mapped.outfit = {
            id: outfitRow.id,
            name: outfitRow.name,
            occasion: outfitRow.occasion,
            source: outfitRow.source,
            items: outfitRow.items && outfitRow.items[0] !== null ? outfitRow.items : [],
          };
        }

        return mapped;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get calendar outfits within a date range for the authenticated user.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.startDate - Start date in YYYY-MM-DD format.
     * @param {string} params.endDate - End date in YYYY-MM-DD format.
     * @returns {Promise<Array<object>>} Calendar outfits ordered by scheduled_date ASC.
     */
    async getCalendarOutfitsForDateRange(authContext, { startDate, endDate }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT co.*,
                  json_build_object(
                    'id', o.id,
                    'name', o.name,
                    'occasion', o.occasion,
                    'source', o.source,
                    'items', (
                      SELECT json_agg(
                        json_build_object(
                          'id', oi.item_id,
                          'position', oi.position,
                          'name', i.name,
                          'category', i.category,
                          'color', i.color,
                          'photoUrl', i.photo_url
                        ) ORDER BY oi.position
                      )
                      FROM app_public.outfit_items oi
                      LEFT JOIN app_public.items i ON i.id = oi.item_id
                      WHERE oi.outfit_id = o.id
                    )
                  ) as outfit_data
           FROM app_public.calendar_outfits co
           LEFT JOIN app_public.outfits o ON o.id = co.outfit_id
           WHERE co.scheduled_date >= $1::date
             AND co.scheduled_date <= $2::date
           ORDER BY co.scheduled_date ASC`,
          [startDate, endDate]
        );

        await client.query("commit");

        return result.rows.map(row => {
          const mapped = mapCalendarOutfitRow(row);
          if (mapped.outfit && mapped.outfit.items === null) {
            mapped.outfit.items = [];
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
     * Update a calendar outfit assignment.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} calendarOutfitId - UUID of the calendar outfit to update.
     * @param {object} params
     * @param {string} [params.outfitId] - New outfit ID.
     * @param {string} [params.calendarEventId] - New event ID.
     * @param {string} [params.notes] - New notes.
     * @returns {Promise<object>} Updated calendar outfit.
     */
    async updateCalendarOutfit(authContext, calendarOutfitId, { outfitId, calendarEventId, notes }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Build dynamic SET clause
        const setClauses = [];
        const values = [];
        let paramIndex = 1;

        if (outfitId !== undefined) {
          setClauses.push(`outfit_id = $${paramIndex++}`);
          values.push(outfitId);
        }
        if (calendarEventId !== undefined) {
          setClauses.push(`calendar_event_id = $${paramIndex++}`);
          values.push(calendarEventId);
        }
        if (notes !== undefined) {
          setClauses.push(`notes = $${paramIndex++}`);
          values.push(notes);
        }

        if (setClauses.length === 0) {
          const err = new Error("No fields to update");
          err.statusCode = 400;
          throw err;
        }

        values.push(calendarOutfitId);
        const result = await client.query(
          `UPDATE app_public.calendar_outfits
           SET ${setClauses.join(", ")}
           WHERE id = $${paramIndex}
           RETURNING *`,
          values
        );

        if (result.rows.length === 0) {
          const err = new Error("Calendar outfit not found");
          err.statusCode = 404;
          throw err;
        }

        const row = result.rows[0];

        // Fetch joined outfit data
        const outfitResult = await client.query(
          `SELECT o.id, o.name, o.occasion, o.source,
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
          [row.outfit_id]
        );

        await client.query("commit");

        const mapped = mapCalendarOutfitRow(row);
        if (outfitResult.rows.length > 0) {
          const outfitRow = outfitResult.rows[0];
          mapped.outfit = {
            id: outfitRow.id,
            name: outfitRow.name,
            occasion: outfitRow.occasion,
            source: outfitRow.source,
            items: outfitRow.items && outfitRow.items[0] !== null ? outfitRow.items : [],
          };
        }

        return mapped;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Delete a calendar outfit assignment.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} calendarOutfitId - UUID of the calendar outfit to delete.
     * @returns {Promise<object>} Deletion confirmation.
     */
    async deleteCalendarOutfit(authContext, calendarOutfitId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `DELETE FROM app_public.calendar_outfits WHERE id = $1 RETURNING id`,
          [calendarOutfitId]
        );

        if (result.rows.length === 0) {
          const err = new Error("Calendar outfit not found");
          err.statusCode = 404;
          throw err;
        }

        await client.query("commit");

        return { deleted: true, id: calendarOutfitId };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}
