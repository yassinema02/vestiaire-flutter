import assert from "node:assert/strict";
import test from "node:test";
import { createWearLogRepository, mapWearLogRow } from "../../../src/modules/wear-logs/wear-log-repository.js";

// Valid UUIDs for testing
const ITEM_1 = "00000000-0000-0000-0000-000000000001";
const ITEM_2 = "00000000-0000-0000-0000-000000000002";
const ITEM_3 = "00000000-0000-0000-0000-000000000003";
const OUTFIT_1 = "00000000-0000-0000-0000-0000000000a1";

// --- Mock pool that records queries ---
function createMockPool({
  profileId = "profile-uuid-1",
  wearLogRow = null,
  incrementResult = null,
  listResult = null,
  failProfile = false,
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
            if (failProfile) return { rows: [] };
            return { rows: [{ id: profileId }] };
          }

          if (sql.includes("INSERT INTO app_public.wear_logs")) {
            return {
              rows: [wearLogRow || {
                id: "wearlog-uuid-1",
                profile_id: profileId,
                logged_date: params[1] || "2026-03-17",
                outfit_id: params[2] || null,
                photo_url: params[3] || null,
                created_at: new Date().toISOString(),
              }]
            };
          }

          if (sql.includes("INSERT INTO app_public.wear_log_items")) {
            return { rows: [{ id: "wli-uuid-1", wear_log_id: params[0], item_id: params[1] }] };
          }

          if (sql.includes("increment_wear_counts")) {
            return { rows: [{ increment_wear_counts: incrementResult ?? params[0].length }] };
          }

          // listWearLogs query
          if (sql.includes("SELECT wl.*")) {
            if (listResult) {
              return { rows: listResult };
            }
            return { rows: [] };
          }

          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- createWearLogRepository factory ---

test("createWearLogRepository throws when pool is missing", () => {
  assert.throws(() => createWearLogRepository({}), TypeError);
});

// --- createWearLog tests ---

test("createWearLog inserts a wear log with items and returns the created record", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  const result = await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1, ITEM_2],
  });

  assert.ok(result.id);
  assert.equal(result.profileId, "profile-uuid-1");
  assert.deepEqual(result.itemIds, [ITEM_1, ITEM_2]);
});

test("createWearLog calls increment_wear_counts RPC with item IDs", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1, ITEM_2, ITEM_3],
  });

  const rpcQuery = pool.queries.find(q => q.sql.includes("increment_wear_counts"));
  assert.ok(rpcQuery, "Should call increment_wear_counts RPC");
  assert.deepEqual(rpcQuery.params[0], [ITEM_1, ITEM_2, ITEM_3]);
});

test("createWearLog passes logged_date to RPC for last_worn_date update", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1],
    loggedDate: "2026-03-15",
  });

  const rpcQuery = pool.queries.find(q => q.sql.includes("increment_wear_counts"));
  assert.ok(rpcQuery);
  assert.equal(rpcQuery.params[1], "2026-03-15");
});

test("createWearLog with outfitId sets the outfit reference", async () => {
  const pool = createMockPool({
    wearLogRow: {
      id: "wearlog-uuid-1",
      profile_id: "profile-uuid-1",
      logged_date: "2026-03-17",
      outfit_id: OUTFIT_1,
      photo_url: null,
      created_at: new Date().toISOString(),
    }
  });
  const repo = createWearLogRepository({ pool });

  const result = await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1],
    outfitId: OUTFIT_1,
  });

  assert.equal(result.outfitId, OUTFIT_1);
});

test("createWearLog without outfitId sets outfit_id to null", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  const result = await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1],
  });

  assert.equal(result.outfitId, null);
});

test("createWearLog with empty itemIds array throws 400", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await assert.rejects(
    () => repo.createWearLog(testAuthContext, { itemIds: [] }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.ok(err.message.includes("non-empty"));
      return true;
    }
  );
});

test("createWearLog with invalid UUID in itemIds throws 400", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await assert.rejects(
    () => repo.createWearLog(testAuthContext, { itemIds: ["not-a-uuid"] }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.ok(err.message.includes("valid UUID"));
      return true;
    }
  );
});

test("createWearLog sets app.current_user_id for RLS", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await repo.createWearLog(testAuthContext, { itemIds: [ITEM_1] });

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("createWearLog supports multiple logs per day (no unique constraint on date)", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  const result1 = await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1],
    loggedDate: "2026-03-17",
  });

  const result2 = await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_2],
    loggedDate: "2026-03-17",
  });

  assert.ok(result1.id);
  assert.ok(result2.id);
});

test("createWearLog increments wear_count for items logged multiple times", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1],
  });

  await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1],
  });

  // RPC should have been called twice
  const rpcCalls = pool.queries.filter(q => q.sql.includes("increment_wear_counts"));
  assert.equal(rpcCalls.length, 2);
});

test("createWearLog rolls back transaction on error", async () => {
  const pool = createMockPool({ failProfile: true });
  const repo = createWearLogRepository({ pool });

  try {
    await repo.createWearLog(testAuthContext, {
      itemIds: [ITEM_1],
    });
  } catch {
    // expected
  }

  const rollbackQuery = pool.queries.find(q => q.sql === "rollback");
  assert.ok(rollbackQuery, "Transaction should be rolled back on error");
});

// --- listWearLogs tests ---

test("listWearLogs returns logs within date range", async () => {
  const pool = createMockPool({
    listResult: [
      {
        id: "wearlog-1", profile_id: "profile-uuid-1",
        logged_date: "2026-03-15", outfit_id: null, photo_url: null,
        created_at: "2026-03-15T10:00:00Z", item_ids: [ITEM_1, ITEM_2],
      },
      {
        id: "wearlog-2", profile_id: "profile-uuid-1",
        logged_date: "2026-03-16", outfit_id: OUTFIT_1, photo_url: null,
        created_at: "2026-03-16T10:00:00Z", item_ids: [ITEM_3],
      },
    ]
  });
  const repo = createWearLogRepository({ pool });

  const result = await repo.listWearLogs(testAuthContext, {
    startDate: "2026-03-15",
    endDate: "2026-03-16",
  });

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "wearlog-1");
  assert.equal(result[1].id, "wearlog-2");
  assert.deepEqual(result[0].itemIds, [ITEM_1, ITEM_2]);
});

test("listWearLogs returns empty array for dates with no logs", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  const result = await repo.listWearLogs(testAuthContext, {
    startDate: "2026-01-01",
    endDate: "2026-01-31",
  });

  assert.ok(Array.isArray(result));
  assert.equal(result.length, 0);
});

test("listWearLogs sets app.current_user_id for RLS", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await repo.listWearLogs(testAuthContext, {
    startDate: "2026-03-15",
    endDate: "2026-03-16",
  });

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

// --- getWearLogsForDate tests ---

test("getWearLogsForDate returns logs for specific date", async () => {
  const pool = createMockPool({
    listResult: [{
      id: "wearlog-1", profile_id: "profile-uuid-1",
      logged_date: "2026-03-17", outfit_id: null, photo_url: null,
      created_at: "2026-03-17T10:00:00Z", item_ids: [ITEM_1],
    }]
  });
  const repo = createWearLogRepository({ pool });

  const result = await repo.getWearLogsForDate(testAuthContext, "2026-03-17");

  assert.equal(result.length, 1);
  assert.equal(result[0].loggedDate, "2026-03-17");
});

// --- mapWearLogRow tests ---

test("mapWearLogRow correctly maps database columns to camelCase", () => {
  const row = {
    id: "uuid-1",
    profile_id: "profile-1",
    logged_date: "2026-03-17",
    outfit_id: OUTFIT_1,
    photo_url: "http://example.com/photo.jpg",
    created_at: "2026-03-17T10:00:00Z",
    item_ids: [ITEM_1, ITEM_2],
  };

  const mapped = mapWearLogRow(row);

  assert.equal(mapped.id, "uuid-1");
  assert.equal(mapped.profileId, "profile-1");
  assert.equal(mapped.loggedDate, "2026-03-17");
  assert.equal(mapped.outfitId, OUTFIT_1);
  assert.equal(mapped.photoUrl, "http://example.com/photo.jpg");
  assert.equal(mapped.createdAt, "2026-03-17T10:00:00Z");
  assert.deepEqual(mapped.itemIds, [ITEM_1, ITEM_2]);
});

test("mapWearLogRow handles null optional fields", () => {
  const row = {
    id: "uuid-1",
    profile_id: "profile-1",
    logged_date: "2026-03-17",
    outfit_id: null,
    photo_url: null,
    created_at: "2026-03-17T10:00:00Z",
  };

  const mapped = mapWearLogRow(row);

  assert.equal(mapped.outfitId, null);
  assert.equal(mapped.photoUrl, null);
  assert.deepEqual(mapped.itemIds, []);
});

// --- increment_wear_counts RPC validation ---

test("increment_wear_counts RPC is called with correct parameters", async () => {
  const pool = createMockPool();
  const repo = createWearLogRepository({ pool });

  await repo.createWearLog(testAuthContext, {
    itemIds: [ITEM_1, ITEM_2],
    loggedDate: "2026-03-17",
  });

  const rpcQuery = pool.queries.find(q => q.sql.includes("increment_wear_counts"));
  assert.ok(rpcQuery);
  assert.deepEqual(rpcQuery.params[0], [ITEM_1, ITEM_2]);
  assert.equal(rpcQuery.params[1], "2026-03-17");
});
