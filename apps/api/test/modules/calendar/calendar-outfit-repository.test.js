import assert from "node:assert/strict";
import test from "node:test";
import { createCalendarOutfitRepository } from "../../../src/modules/calendar/calendar-outfit-repository.js";

// --- Mock pool that records queries ---
function createMockPool({
  profileId = "profile-uuid-1",
  calendarOutfitRow = null,
  outfitRow = null,
  calendarOutfitRows = [],
  shouldFailInsert = false,
  shouldReturn404 = false,
} = {}) {
  const queries = [];

  return {
    queries,
    async connect() {
      return {
        async query(sql, params = []) {
          queries.push({ sql, params });

          if (sql === "begin") return {};
          if (sql === "commit" || sql === "rollback") return {};
          if (sql.includes("set_config")) return {};

          if (sql.includes("select id from app_public.profiles")) {
            return { rows: [{ id: profileId }] };
          }

          if (sql.includes("INSERT INTO app_public.calendar_outfits")) {
            if (shouldFailInsert) {
              const err = new Error("insert or update on table \"calendar_outfits\" violates foreign key constraint");
              err.code = "23503";
              throw err;
            }
            return {
              rows: [calendarOutfitRow || {
                id: "co-uuid-1",
                profile_id: profileId,
                outfit_id: params[1],
                calendar_event_id: params[2],
                scheduled_date: params[3],
                notes: params[4],
                created_at: "2026-03-19T00:00:00Z",
                updated_at: "2026-03-19T00:00:00Z",
              }],
            };
          }

          if (sql.includes("SELECT co.*") && sql.includes("calendar_outfits co")) {
            return {
              rows: calendarOutfitRows.map(r => ({
                ...r,
                outfit_data: outfitRow || { id: r.outfit_id, name: "Test Outfit", occasion: "casual", source: "ai", items: [] },
              })),
            };
          }

          if (sql.includes("UPDATE app_public.calendar_outfits")) {
            if (shouldReturn404) return { rows: [] };
            return {
              rows: [calendarOutfitRow || {
                id: params[params.length - 1],
                profile_id: profileId,
                outfit_id: params[0],
                calendar_event_id: null,
                scheduled_date: "2026-03-20",
                notes: null,
                created_at: "2026-03-19T00:00:00Z",
                updated_at: "2026-03-19T00:00:00Z",
              }],
            };
          }

          if (sql.includes("DELETE FROM app_public.calendar_outfits")) {
            if (shouldReturn404) return { rows: [] };
            return { rows: [{ id: params[0] }] };
          }

          // Outfit join query
          if (sql.includes("SELECT o.id, o.name")) {
            return {
              rows: [outfitRow || {
                id: "outfit-uuid-1",
                name: "Test Outfit",
                occasion: "casual",
                source: "ai",
                items: [{ id: "item-1", position: 0, name: "Shirt", category: "tops", color: "blue", photoUrl: null }],
              }],
            };
          }

          return { rows: [] };
        },
        release() {},
      };
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };

test("createCalendarOutfitRepository throws when pool is missing", () => {
  assert.throws(() => createCalendarOutfitRepository({}), TypeError);
});

test("createCalendarOutfit inserts a record and returns it with outfit data", async () => {
  const pool = createMockPool();
  const repo = createCalendarOutfitRepository({ pool });

  const result = await repo.createCalendarOutfit(testAuthContext, {
    outfitId: "outfit-uuid-1",
    calendarEventId: null,
    scheduledDate: "2026-03-20",
    notes: "Test note",
  });

  assert.equal(result.outfitId, "outfit-uuid-1");
  assert.ok(result.outfit);
  assert.equal(result.outfit.name, "Test Outfit");

  // Verify set_config was called with the firebase UID
  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("createCalendarOutfit throws on invalid outfit ID (FK violation)", async () => {
  const pool = createMockPool({ shouldFailInsert: true });
  const repo = createCalendarOutfitRepository({ pool });

  await assert.rejects(
    repo.createCalendarOutfit(testAuthContext, {
      outfitId: "invalid-uuid",
      scheduledDate: "2026-03-20",
    }),
    (err) => err.code === "23503"
  );
});

test("getCalendarOutfitsForDateRange returns outfits within range with joined data", async () => {
  const pool = createMockPool({
    calendarOutfitRows: [
      {
        id: "co-1",
        profile_id: "profile-uuid-1",
        outfit_id: "outfit-1",
        calendar_event_id: null,
        scheduled_date: "2026-03-20",
        notes: null,
        created_at: "2026-03-19T00:00:00Z",
        updated_at: "2026-03-19T00:00:00Z",
      },
    ],
  });
  const repo = createCalendarOutfitRepository({ pool });

  const result = await repo.getCalendarOutfitsForDateRange(testAuthContext, {
    startDate: "2026-03-19",
    endDate: "2026-03-25",
  });

  assert.equal(result.length, 1);
  assert.equal(result[0].outfitId, "outfit-1");
  assert.ok(result[0].outfit);
});

test("getCalendarOutfitsForDateRange returns empty array when no outfits scheduled", async () => {
  const pool = createMockPool({ calendarOutfitRows: [] });
  const repo = createCalendarOutfitRepository({ pool });

  const result = await repo.getCalendarOutfitsForDateRange(testAuthContext, {
    startDate: "2026-03-19",
    endDate: "2026-03-25",
  });

  assert.equal(result.length, 0);
});

test("updateCalendarOutfit updates the record and returns it", async () => {
  const pool = createMockPool();
  const repo = createCalendarOutfitRepository({ pool });

  const result = await repo.updateCalendarOutfit(testAuthContext, "co-uuid-1", {
    outfitId: "new-outfit-uuid",
  });

  assert.ok(result.id);
  assert.ok(result.outfit);
});

test("updateCalendarOutfit returns 404 for non-existent ID", async () => {
  const pool = createMockPool({ shouldReturn404: true });
  const repo = createCalendarOutfitRepository({ pool });

  await assert.rejects(
    repo.updateCalendarOutfit(testAuthContext, "nonexistent-id", {
      outfitId: "outfit-uuid-1",
    }),
    (err) => err.statusCode === 404
  );
});

test("deleteCalendarOutfit removes the record", async () => {
  const pool = createMockPool();
  const repo = createCalendarOutfitRepository({ pool });

  const result = await repo.deleteCalendarOutfit(testAuthContext, "co-uuid-1");

  assert.equal(result.deleted, true);
  assert.equal(result.id, "co-uuid-1");
});

test("deleteCalendarOutfit returns 404 for non-existent ID", async () => {
  const pool = createMockPool({ shouldReturn404: true });
  const repo = createCalendarOutfitRepository({ pool });

  await assert.rejects(
    repo.deleteCalendarOutfit(testAuthContext, "nonexistent-id"),
    (err) => err.statusCode === 404
  );
});

test("RLS set_config is called with correct userId on all operations", async () => {
  const pool = createMockPool();
  const repo = createCalendarOutfitRepository({ pool });

  await repo.createCalendarOutfit(testAuthContext, {
    outfitId: "outfit-1",
    scheduledDate: "2026-03-20",
  });

  const configQueries = pool.queries.filter(q => q.sql.includes("set_config"));
  assert.ok(configQueries.length > 0);
  for (const q of configQueries) {
    assert.equal(q.params[0], "firebase-user-123");
  }
});

test("unique constraint prevents duplicate scheduling for same date/event", async () => {
  const pool = createMockPool({
    shouldFailInsert: false,
  });
  // Override to simulate unique violation on second call
  let callCount = 0;
  const origConnect = pool.connect.bind(pool);
  pool.connect = async () => {
    const client = await origConnect();
    const origQuery = client.query.bind(client);
    client.query = async (sql, params) => {
      if (sql.includes("INSERT INTO app_public.calendar_outfits")) {
        callCount++;
        if (callCount > 1) {
          const err = new Error("duplicate key value violates unique constraint");
          err.code = "23505";
          throw err;
        }
      }
      return origQuery(sql, params);
    };
    return client;
  };

  const repo = createCalendarOutfitRepository({ pool });

  // First call succeeds
  await repo.createCalendarOutfit(testAuthContext, {
    outfitId: "outfit-1",
    scheduledDate: "2026-03-20",
  });

  // Second call fails with unique constraint
  await assert.rejects(
    repo.createCalendarOutfit(testAuthContext, {
      outfitId: "outfit-2",
      scheduledDate: "2026-03-20",
    }),
    (err) => err.code === "23505"
  );
});
