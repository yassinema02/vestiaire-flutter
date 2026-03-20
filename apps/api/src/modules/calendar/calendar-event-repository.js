/**
 * Repository for calendar event CRUD operations.
 *
 * Handles upsert, date-range queries, and stale event cleanup.
 * All queries are RLS-scoped via set_config('app.current_user_id').
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createCalendarEventRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Upsert a batch of calendar events.
     *
     * Inserts new events or updates existing ones matched by
     * (profile_id, source_calendar_id, source_event_id).
     * Preserves user_override fields during update.
     *
     * @param {object} authContext - Must have userId.
     * @param {Array<object>} events - Events to upsert.
     * @returns {Promise<Array<object>>} Upserted event rows.
     */
    async upsertEvents(authContext, events) {
      if (!events || events.length === 0) return [];

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
        const results = [];

        for (const event of events) {
          const result = await client.query(
            `INSERT INTO app_public.calendar_events
              (profile_id, source_calendar_id, source_event_id, title, description, location,
               start_time, end_time, all_day, event_type, formality_score, classification_source)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
             ON CONFLICT (profile_id, source_calendar_id, source_event_id)
             DO UPDATE SET
               title = EXCLUDED.title,
               description = EXCLUDED.description,
               location = EXCLUDED.location,
               start_time = EXCLUDED.start_time,
               end_time = EXCLUDED.end_time,
               all_day = EXCLUDED.all_day,
               event_type = CASE WHEN calendar_events.user_override THEN calendar_events.event_type ELSE EXCLUDED.event_type END,
               formality_score = CASE WHEN calendar_events.user_override THEN calendar_events.formality_score ELSE EXCLUDED.formality_score END,
               classification_source = CASE WHEN calendar_events.user_override THEN calendar_events.classification_source ELSE EXCLUDED.classification_source END,
               updated_at = now()
             RETURNING *`,
            [
              profileId,
              event.sourceCalendarId,
              event.sourceEventId,
              event.title,
              event.description ?? null,
              event.location ?? null,
              event.startTime,
              event.endTime,
              event.allDay ?? false,
              event.eventType ?? "casual",
              event.formalityScore ?? 2,
              event.classificationSource ?? "keyword"
            ]
          );
          results.push(result.rows[0]);
        }

        await client.query("commit");
        return results;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get events within a date range for the authenticated user.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.startDate - ISO date string (YYYY-MM-DD).
     * @param {string} params.endDate - ISO date string (YYYY-MM-DD).
     * @returns {Promise<Array<object>>} Events ordered by start_time ASC.
     */
    async getEventsForDateRange(authContext, { startDate, endDate }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT * FROM app_public.calendar_events
           WHERE start_time >= $1::timestamptz
             AND start_time < ($2::date + interval '1 day')::timestamptz
           ORDER BY start_time ASC`,
          [startDate, endDate]
        );

        await client.query("commit");
        return result.rows;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Mark stale events by deleting those not in the provided sourceEventIds list
     * for a given calendar and date range. Preserves user_override events.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.sourceCalendarId - Calendar to clean up.
     * @param {Array<string>} params.sourceEventIds - Event IDs still present on device.
     * @param {string} params.startDate - ISO date string.
     * @param {string} params.endDate - ISO date string.
     * @returns {Promise<number>} Number of deleted events.
     */
    /**
     * Update an event's classification via user override.
     *
     * Sets event_type, formality_score, classification_source = 'user',
     * and user_override = true.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} eventId - UUID of the calendar event.
     * @param {object} params
     * @param {string} params.eventType - One of: work, social, active, formal, casual.
     * @param {number} params.formalityScore - Integer 1-10.
     * @returns {Promise<object>} Updated event row.
     */
    async updateEventOverride(authContext, eventId, { eventType, formalityScore }) {
      // Input validation
      const validEventTypes = ["work", "social", "active", "formal", "casual"];
      if (!validEventTypes.includes(eventType)) {
        const err = new Error(`Invalid event_type: ${eventType}. Must be one of: ${validEventTypes.join(", ")}`);
        err.statusCode = 400;
        throw err;
      }
      if (!Number.isInteger(formalityScore) || formalityScore < 1 || formalityScore > 10) {
        const err = new Error("Invalid formality_score: must be an integer between 1 and 10");
        err.statusCode = 400;
        throw err;
      }

      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `UPDATE app_public.calendar_events
           SET event_type = $1,
               formality_score = $2,
               classification_source = 'user',
               user_override = true,
               updated_at = now()
           WHERE id = $3
           RETURNING *`,
          [eventType, formalityScore, eventId]
        );

        if (result.rows.length === 0) {
          const err = new Error("Event not found");
          err.statusCode = 404;
          throw err;
        }

        await client.query("commit");
        return result.rows[0];
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async markStaleEvents(authContext, { sourceCalendarId, sourceEventIds, startDate, endDate }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `DELETE FROM app_public.calendar_events
           WHERE source_calendar_id = $1
             AND start_time >= $2::timestamptz
             AND start_time < ($3::date + interval '1 day')::timestamptz
             AND source_event_id != ALL($4::text[])
             AND user_override = false`,
          [sourceCalendarId, startDate, endDate, sourceEventIds]
        );

        await client.query("commit");
        return result.rowCount;
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }
  };
}
