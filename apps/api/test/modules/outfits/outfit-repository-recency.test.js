import assert from "node:assert/strict";
import test from "node:test";
import {
  createOutfitRepository,
  RECENCY_WINDOW_DAYS,
} from "../../../src/modules/outfits/outfit-repository.js";

// --- Mock pool that records queries and returns configurable results ---
function createMockPool({ recentItems = [] } = {}) {
  const queries = [];
  let releaseCount = 0;

  return {
    queries,
    get releaseCount() { return releaseCount; },
    async connect() {
      return {
        async query(sql, params = []) {
          queries.push({ sql, params });

          if (sql.includes("set_config")) return {};

          if (sql.includes("SELECT DISTINCT i.id")) {
            return { rows: recentItems };
          }

          return { rows: [] };
        },
        release() { releaseCount++; },
      };
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };

test("RECENCY_WINDOW_DAYS constant is exported and equals 7", () => {
  assert.equal(RECENCY_WINDOW_DAYS, 7);
});

test("getRecentOutfitItems returns empty array when no outfits exist", async () => {
  const pool = createMockPool({ recentItems: [] });
  const repo = createOutfitRepository({ pool });

  const result = await repo.getRecentOutfitItems(testAuthContext);

  assert.ok(Array.isArray(result));
  assert.equal(result.length, 0);
});

test("getRecentOutfitItems returns item objects from recent outfits", async () => {
  const pool = createMockPool({
    recentItems: [
      { id: "item-1", name: "Navy Blazer", category: "blazer", color: "navy" },
      { id: "item-2", name: "White Shirt", category: "tops", color: "white" },
    ],
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.getRecentOutfitItems(testAuthContext);

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "item-1");
  assert.equal(result[0].name, "Navy Blazer");
  assert.equal(result[0].category, "blazer");
  assert.equal(result[0].color, "navy");
  assert.equal(result[1].id, "item-2");
});

test("getRecentOutfitItems includes name, category, and color for each item", async () => {
  const pool = createMockPool({
    recentItems: [
      { id: "item-1", name: "Red Dress", category: "dresses", color: "red" },
    ],
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.getRecentOutfitItems(testAuthContext);

  const item = result[0];
  assert.ok("id" in item);
  assert.ok("name" in item);
  assert.ok("category" in item);
  assert.ok("color" in item);
  // Should not include extra fields
  assert.equal(Object.keys(item).length, 4);
});

test("getRecentOutfitItems sets app.current_user_id for RLS", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getRecentOutfitItems(testAuthContext);

  const configQuery = pool.queries.find((q) => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("getRecentOutfitItems respects RLS by setting the correct user ID", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getRecentOutfitItems({ userId: "different-user" });

  const configQuery = pool.queries.find((q) => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "different-user");
});

test("getRecentOutfitItems uses default 7-day window", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getRecentOutfitItems(testAuthContext);

  const selectQuery = pool.queries.find((q) => q.sql.includes("SELECT DISTINCT"));
  assert.ok(selectQuery);
  assert.equal(selectQuery.params[0], 7);
});

test("getRecentOutfitItems accepts a custom days parameter", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getRecentOutfitItems(testAuthContext, { days: 14 });

  const selectQuery = pool.queries.find((q) => q.sql.includes("SELECT DISTINCT"));
  assert.ok(selectQuery);
  assert.equal(selectQuery.params[0], 14);
});

test("getRecentOutfitItems releases the client after success", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getRecentOutfitItems(testAuthContext);

  assert.equal(pool.releaseCount, 1);
});

test("getRecentOutfitItems releases the client after failure", async () => {
  let releaseCount = 0;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("SELECT DISTINCT")) {
            throw new Error("DB error");
          }
          return { rows: [] };
        },
        release() { releaseCount++; },
      };
    },
  };
  const repo = createOutfitRepository({ pool });

  await assert.rejects(
    () => repo.getRecentOutfitItems(testAuthContext),
    { message: "DB error" }
  );

  assert.equal(releaseCount, 1);
});

test("getRecentOutfitItems query uses DISTINCT and joins outfits, outfit_items, items", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getRecentOutfitItems(testAuthContext);

  const selectQuery = pool.queries.find((q) => q.sql.includes("SELECT DISTINCT"));
  assert.ok(selectQuery);
  assert.ok(selectQuery.sql.includes("app_public.outfit_items"));
  assert.ok(selectQuery.sql.includes("app_public.outfits"));
  assert.ok(selectQuery.sql.includes("app_public.items"));
  assert.ok(selectQuery.sql.includes("INTERVAL"));
});
