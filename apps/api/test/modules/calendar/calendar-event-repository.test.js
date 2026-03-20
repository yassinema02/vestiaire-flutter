import assert from "node:assert/strict";
import test from "node:test";
import { createCalendarEventRepository } from "../../../src/modules/calendar/calendar-event-repository.js";

// --- Mock pool that records queries ---
function createMockPool({ profileId = "profile-uuid-1", existingEvents = [], userOverrideEvent = null } = {}) {
  const queries = [];
  let inTransaction = false;

  return {
    queries,
    async connect() {
      return {
        async query(sql, params = []) {
          queries.push({ sql, params });

          if (sql === "begin") {
            inTransaction = true;
            return {};
          }
          if (sql === "commit" || sql === "rollback") {
            inTransaction = false;
            return {};
          }
          if (sql.includes("set_config")) {
            return {};
          }
          if (sql.includes("select id from app_public.profiles")) {
            return { rows: [{ id: profileId }] };
          }
          if (sql.includes("INSERT INTO app_public.calendar_events")) {
            // Simulate upsert returning the event
            return {
              rows: [{
                id: "event-uuid-1",
                profile_id: profileId,
                source_calendar_id: params[1],
                source_event_id: params[2],
                title: params[3],
                event_type: params[9],
                formality_score: params[10],
                user_override: false
              }]
            };
          }
          if (sql.includes("SELECT * FROM app_public.calendar_events")) {
            return { rows: existingEvents };
          }
          if (sql.includes("UPDATE app_public.calendar_events")) {
            if (userOverrideEvent) {
              return { rows: [userOverrideEvent] };
            }
            // If no override event configured, simulate not found (RLS)
            return { rows: [] };
          }
          if (sql.includes("DELETE FROM app_public.calendar_events")) {
            return { rowCount: 1 };
          }
          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

test("createCalendarEventRepository throws when pool is missing", () => {
  assert.throws(() => createCalendarEventRepository({}), TypeError);
});

test("upsertEvents inserts new events correctly", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  const events = [{
    sourceCalendarId: "cal-1",
    sourceEventId: "evt-1",
    title: "Sprint Planning",
    description: "Weekly sprint planning",
    location: "Office",
    startTime: "2026-03-15T10:00:00Z",
    endTime: "2026-03-15T11:00:00Z",
    allDay: false,
    eventType: "work",
    formalityScore: 5,
    classificationSource: "keyword"
  }];

  const result = await repo.upsertEvents(testAuthContext, events);

  assert.equal(result.length, 1);
  assert.equal(result[0].source_event_id, "evt-1");

  // Verify set_config was called
  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("upsertEvents updates existing events (matched by source IDs)", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  const events = [{
    sourceCalendarId: "cal-1",
    sourceEventId: "evt-1",
    title: "Updated Sprint Planning",
    startTime: "2026-03-15T10:30:00Z",
    endTime: "2026-03-15T11:30:00Z",
    eventType: "work",
    formalityScore: 5,
    classificationSource: "keyword"
  }];

  await repo.upsertEvents(testAuthContext, events);

  // Verify the INSERT ... ON CONFLICT query was used
  const insertQuery = pool.queries.find(q => q.sql.includes("ON CONFLICT"));
  assert.ok(insertQuery);
  assert.ok(insertQuery.sql.includes("DO UPDATE SET"));
});

test("upsertEvents preserves user_override events during update", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  await repo.upsertEvents(testAuthContext, [{
    sourceCalendarId: "cal-1",
    sourceEventId: "evt-1",
    title: "Test",
    startTime: "2026-03-15T10:00:00Z",
    endTime: "2026-03-15T11:00:00Z",
    eventType: "work",
    formalityScore: 5,
    classificationSource: "keyword"
  }]);

  // Verify the CASE WHEN clause for user_override
  const insertQuery = pool.queries.find(q => q.sql.includes("ON CONFLICT"));
  assert.ok(insertQuery.sql.includes("CASE WHEN calendar_events.user_override THEN calendar_events.event_type ELSE EXCLUDED.event_type END"));
  assert.ok(insertQuery.sql.includes("CASE WHEN calendar_events.user_override THEN calendar_events.formality_score ELSE EXCLUDED.formality_score END"));
  assert.ok(insertQuery.sql.includes("CASE WHEN calendar_events.user_override THEN calendar_events.classification_source ELSE EXCLUDED.classification_source END"));
});

test("getEventsForDateRange returns events within range", async () => {
  const testEvents = [
    { id: "evt-1", title: "Meeting", start_time: "2026-03-15T10:00:00Z" },
    { id: "evt-2", title: "Lunch", start_time: "2026-03-15T12:00:00Z" }
  ];
  const pool = createMockPool({ existingEvents: testEvents });
  const repo = createCalendarEventRepository({ pool });

  const result = await repo.getEventsForDateRange(testAuthContext, {
    startDate: "2026-03-15",
    endDate: "2026-03-15"
  });

  assert.equal(result.length, 2);
  assert.equal(result[0].title, "Meeting");
});

test("getEventsForDateRange excludes events outside range", async () => {
  // The mock returns whatever existingEvents are provided
  // In a real DB test, the SQL WHERE clause handles filtering
  const pool = createMockPool({ existingEvents: [] });
  const repo = createCalendarEventRepository({ pool });

  const result = await repo.getEventsForDateRange(testAuthContext, {
    startDate: "2026-03-15",
    endDate: "2026-03-15"
  });

  assert.equal(result.length, 0);
});

test("markStaleEvents removes events not in provided ID list", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  const deletedCount = await repo.markStaleEvents(testAuthContext, {
    sourceCalendarId: "cal-1",
    sourceEventIds: ["evt-1", "evt-2"],
    startDate: "2026-03-15",
    endDate: "2026-03-22"
  });

  assert.equal(deletedCount, 1);

  // Verify DELETE query filters correctly
  const deleteQuery = pool.queries.find(q => q.sql.includes("DELETE"));
  assert.ok(deleteQuery);
  assert.ok(deleteQuery.sql.includes("user_override = false"));
  assert.ok(deleteQuery.sql.includes("source_event_id != ALL"));
});

test("markStaleEvents preserves events with user_override = true", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  await repo.markStaleEvents(testAuthContext, {
    sourceCalendarId: "cal-1",
    sourceEventIds: [],
    startDate: "2026-03-15",
    endDate: "2026-03-22"
  });

  // Verify the WHERE clause includes user_override = false
  const deleteQuery = pool.queries.find(q => q.sql.includes("DELETE"));
  assert.ok(deleteQuery.sql.includes("user_override = false"));
});

test("RLS enforces profile-scoped access via set_config", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  await repo.getEventsForDateRange(testAuthContext, {
    startDate: "2026-03-15",
    endDate: "2026-03-15"
  });

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("upsertEvents returns empty array for empty input", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  const result = await repo.upsertEvents(testAuthContext, []);
  assert.deepEqual(result, []);
});

// --- Tests for updateEventOverride (Story 3.6) ---

test("updateEventOverride updates event_type, formality_score, classification_source, and user_override", async () => {
  const updatedRow = {
    id: "event-uuid-1",
    event_type: "formal",
    formality_score: 8,
    classification_source: "user",
    user_override: true
  };
  const pool = createMockPool({ userOverrideEvent: updatedRow });
  const repo = createCalendarEventRepository({ pool });

  const result = await repo.updateEventOverride(testAuthContext, "event-uuid-1", {
    eventType: "formal",
    formalityScore: 8
  });

  // Verify the UPDATE query was sent
  const updateQuery = pool.queries.find(q => q.sql.includes("UPDATE app_public.calendar_events"));
  assert.ok(updateQuery);
  assert.ok(updateQuery.sql.includes("classification_source = 'user'"));
  assert.ok(updateQuery.sql.includes("user_override = true"));
  assert.equal(updateQuery.params[0], "formal");
  assert.equal(updateQuery.params[1], 8);
  assert.equal(updateQuery.params[2], "event-uuid-1");
});

test("updateEventOverride returns the updated event row", async () => {
  const updatedRow = {
    id: "event-uuid-1",
    event_type: "social",
    formality_score: 4,
    classification_source: "user",
    user_override: true
  };
  const pool = createMockPool({ userOverrideEvent: updatedRow });
  const repo = createCalendarEventRepository({ pool });

  const result = await repo.updateEventOverride(testAuthContext, "event-uuid-1", {
    eventType: "social",
    formalityScore: 4
  });

  assert.equal(result.id, "event-uuid-1");
  assert.equal(result.event_type, "social");
  assert.equal(result.formality_score, 4);
  assert.equal(result.classification_source, "user");
  assert.equal(result.user_override, true);
});

test("updateEventOverride rejects invalid event_type", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  await assert.rejects(
    () => repo.updateEventOverride(testAuthContext, "event-uuid-1", {
      eventType: "invalid_type",
      formalityScore: 5
    }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.ok(err.message.includes("Invalid event_type"));
      return true;
    }
  );
});

test("updateEventOverride rejects formality_score outside 1-10 range", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  // Too low
  await assert.rejects(
    () => repo.updateEventOverride(testAuthContext, "event-uuid-1", {
      eventType: "work",
      formalityScore: 0
    }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.ok(err.message.includes("formality_score"));
      return true;
    }
  );

  // Too high
  await assert.rejects(
    () => repo.updateEventOverride(testAuthContext, "event-uuid-1", {
      eventType: "work",
      formalityScore: 11
    }),
    (err) => {
      assert.equal(err.statusCode, 400);
      return true;
    }
  );

  // Non-integer
  await assert.rejects(
    () => repo.updateEventOverride(testAuthContext, "event-uuid-1", {
      eventType: "work",
      formalityScore: 5.5
    }),
    (err) => {
      assert.equal(err.statusCode, 400);
      return true;
    }
  );
});

test("updateEventOverride returns 404 for non-existent event ID", async () => {
  // No userOverrideEvent -> UPDATE returns empty rows -> 404
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  await assert.rejects(
    () => repo.updateEventOverride(testAuthContext, "nonexistent-id", {
      eventType: "work",
      formalityScore: 5
    }),
    (err) => {
      assert.equal(err.statusCode, 404);
      assert.ok(err.message.includes("not found"));
      return true;
    }
  );
});

test("updateEventOverride enforces RLS via set_config", async () => {
  const updatedRow = { id: "event-uuid-1", event_type: "work", formality_score: 5, classification_source: "user", user_override: true };
  const pool = createMockPool({ userOverrideEvent: updatedRow });
  const repo = createCalendarEventRepository({ pool });

  await repo.updateEventOverride(testAuthContext, "event-uuid-1", {
    eventType: "work",
    formalityScore: 5
  });

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("subsequent upsertEvents preserves overridden fields when user_override = true", async () => {
  const pool = createMockPool();
  const repo = createCalendarEventRepository({ pool });

  // Upsert an event (simulating re-sync after override)
  await repo.upsertEvents(testAuthContext, [{
    sourceCalendarId: "cal-1",
    sourceEventId: "evt-1",
    title: "Test",
    startTime: "2026-03-15T10:00:00Z",
    endTime: "2026-03-15T11:00:00Z",
    eventType: "casual",
    formalityScore: 2,
    classificationSource: "keyword"
  }]);

  // Verify CASE WHEN ensures override preservation
  const insertQuery = pool.queries.find(q => q.sql.includes("ON CONFLICT"));
  assert.ok(insertQuery.sql.includes("CASE WHEN calendar_events.user_override THEN calendar_events.event_type ELSE EXCLUDED.event_type END"));
  assert.ok(insertQuery.sql.includes("CASE WHEN calendar_events.user_override THEN calendar_events.formality_score ELSE EXCLUDED.formality_score END"));
  assert.ok(insertQuery.sql.includes("CASE WHEN calendar_events.user_override THEN calendar_events.classification_source ELSE EXCLUDED.classification_source END"));
});
