import assert from "node:assert/strict";
import test from "node:test";
import { createOutfitRepository, mapOutfitRow } from "../../../src/modules/outfits/outfit-repository.js";

// --- Mock pool that records queries ---
function createMockPool({
  profileId = "profile-uuid-1",
  validItemIds = null,
  outfitRow = null,
  outfitWithItems = null,
  outfitList = null,
  updateResult = null,
  deleteResult = null,
  failValidation = false,
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

          if (sql.includes("SELECT id FROM app_public.items")) {
            if (failValidation) {
              // Return fewer items than requested
              return { rows: [{ id: params[0][0] }] };
            }
            const ids = params[0] || validItemIds || [];
            return { rows: ids.map(id => ({ id })) };
          }

          if (sql.includes("INSERT INTO app_public.outfits")) {
            return {
              rows: [outfitRow || {
                id: "outfit-uuid-1",
                profile_id: profileId,
                name: params[1],
                explanation: params[2],
                occasion: params[3],
                source: params[4],
                is_favorite: false,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
              }]
            };
          }

          if (sql.includes("INSERT INTO app_public.outfit_items")) {
            return {
              rows: [{
                id: "outfit-item-uuid-1",
                outfit_id: params[0],
                item_id: params[1],
                position: params[2],
              }]
            };
          }

          if (sql.includes("UPDATE app_public.outfits")) {
            if (updateResult) {
              return { rows: [updateResult] };
            }
            return { rows: [] };
          }

          if (sql.includes("DELETE FROM app_public.outfits")) {
            if (deleteResult) {
              return { rows: [deleteResult] };
            }
            return { rows: [] };
          }

          if (sql.includes("SELECT o.*") && !sql.includes("WHERE o.id")) {
            // listOutfits query (no WHERE clause)
            if (outfitList) {
              return { rows: outfitList };
            }
            return { rows: [] };
          }

          if (sql.includes("SELECT o.*")) {
            if (outfitWithItems) {
              return { rows: [outfitWithItems] };
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

test("createOutfitRepository throws when pool is missing", () => {
  assert.throws(() => createOutfitRepository({}), TypeError);
});

test("createOutfit inserts outfit row with correct profile_id, name, explanation, occasion, source", async () => {
  const pool = createMockPool({ validItemIds: ["item-1", "item-2"] });
  const repo = createOutfitRepository({ pool });

  await repo.createOutfit(testAuthContext, {
    name: "Spring Casual",
    explanation: "Perfect for spring",
    occasion: "everyday",
    source: "ai",
    items: [
      { itemId: "item-1", position: 0 },
      { itemId: "item-2", position: 1 },
    ]
  });

  const insertQuery = pool.queries.find(q => q.sql.includes("INSERT INTO app_public.outfits"));
  assert.ok(insertQuery);
  assert.equal(insertQuery.params[0], "profile-uuid-1");
  assert.equal(insertQuery.params[1], "Spring Casual");
  assert.equal(insertQuery.params[2], "Perfect for spring");
  assert.equal(insertQuery.params[3], "everyday");
  assert.equal(insertQuery.params[4], "ai");
});

test("createOutfit creates outfit_items rows with correct item_id and position", async () => {
  const pool = createMockPool({ validItemIds: ["item-1", "item-2"] });
  const repo = createOutfitRepository({ pool });

  await repo.createOutfit(testAuthContext, {
    name: "Test",
    items: [
      { itemId: "item-1", position: 0 },
      { itemId: "item-2", position: 1 },
    ]
  });

  const itemInserts = pool.queries.filter(q => q.sql.includes("INSERT INTO app_public.outfit_items"));
  assert.equal(itemInserts.length, 2);
  assert.equal(itemInserts[0].params[1], "item-1");
  assert.equal(itemInserts[0].params[2], 0);
  assert.equal(itemInserts[1].params[1], "item-2");
  assert.equal(itemInserts[1].params[2], 1);
});

test("createOutfit returns the created outfit with generated UUID id", async () => {
  const pool = createMockPool({ validItemIds: ["item-1"] });
  const repo = createOutfitRepository({ pool });

  const result = await repo.createOutfit(testAuthContext, {
    name: "Test Outfit",
    items: [{ itemId: "item-1", position: 0 }]
  });

  assert.ok(result.id);
  assert.equal(result.name, "Test Outfit");
  assert.ok(Array.isArray(result.items));
});

test("createOutfit validates item ownership -- throws 400 when itemId doesn't belong to user", async () => {
  const pool = createMockPool({ failValidation: true });
  const repo = createOutfitRepository({ pool });

  await assert.rejects(
    () => repo.createOutfit(testAuthContext, {
      name: "Test",
      items: [
        { itemId: "item-1", position: 0 },
        { itemId: "item-2", position: 1 },
      ]
    }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.equal(err.code, "INVALID_ITEM");
      assert.ok(err.message.includes("items not found"));
      return true;
    }
  );
});

test("createOutfit rolls back transaction on item validation failure", async () => {
  const pool = createMockPool({ failValidation: true });
  const repo = createOutfitRepository({ pool });

  try {
    await repo.createOutfit(testAuthContext, {
      name: "Test",
      items: [
        { itemId: "item-1", position: 0 },
        { itemId: "item-2", position: 1 },
      ]
    });
  } catch {
    // expected
  }

  const rollbackQuery = pool.queries.find(q => q.sql === "rollback");
  assert.ok(rollbackQuery, "Transaction should be rolled back on validation failure");
});

test("createOutfit sets app.current_user_id for RLS", async () => {
  const pool = createMockPool({ validItemIds: ["item-1"] });
  const repo = createOutfitRepository({ pool });

  await repo.createOutfit(testAuthContext, {
    name: "Test",
    items: [{ itemId: "item-1", position: 0 }]
  });

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("getOutfit returns outfit with joined items array", async () => {
  const pool = createMockPool({
    outfitWithItems: {
      id: "outfit-uuid-1",
      profile_id: "profile-uuid-1",
      name: "Test Outfit",
      explanation: "Test explanation",
      occasion: "everyday",
      source: "ai",
      is_favorite: false,
      created_at: "2026-03-15T00:00:00Z",
      updated_at: "2026-03-15T00:00:00Z",
      items: [
        { id: "item-1", position: 0, name: "Shirt", category: "tops", color: "blue", photoUrl: null }
      ]
    }
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.getOutfit(testAuthContext, "outfit-uuid-1");

  assert.ok(result);
  assert.equal(result.id, "outfit-uuid-1");
  assert.equal(result.name, "Test Outfit");
  assert.ok(Array.isArray(result.items));
  assert.equal(result.items.length, 1);
});

test("getOutfit returns null when outfit does not exist", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  const result = await repo.getOutfit(testAuthContext, "nonexistent-id");

  assert.equal(result, null);
});

test("RLS prevents accessing another user's outfits via set_config", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.getOutfit({ userId: "different-user" }, "some-outfit-id");

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "different-user");
});

// --- listOutfits tests ---

test("listOutfits returns all outfits for the authenticated user ordered by created_at DESC", async () => {
  const pool = createMockPool({
    outfitList: [
      {
        id: "outfit-2", profile_id: "profile-uuid-1", name: "Newer", explanation: null,
        occasion: null, source: "ai", is_favorite: false,
        created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T00:00:00Z",
        items: [{ id: "item-1", position: 0, name: "Shirt", category: "tops", color: "blue", photoUrl: null }]
      },
      {
        id: "outfit-1", profile_id: "profile-uuid-1", name: "Older", explanation: null,
        occasion: null, source: "manual", is_favorite: true,
        created_at: "2026-03-14T00:00:00Z", updated_at: "2026-03-14T00:00:00Z",
        items: []
      },
    ]
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.listOutfits(testAuthContext);

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "outfit-2");
  assert.equal(result[1].id, "outfit-1");
});

test("listOutfits includes items array with full metadata", async () => {
  const pool = createMockPool({
    outfitList: [{
      id: "outfit-1", profile_id: "profile-uuid-1", name: "Test", explanation: null,
      occasion: "everyday", source: "ai", is_favorite: false,
      created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T00:00:00Z",
      items: [
        { id: "item-1", position: 0, name: "Shirt", category: "tops", color: "blue", photoUrl: "http://example.com/photo.jpg" }
      ]
    }]
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.listOutfits(testAuthContext);

  assert.equal(result[0].items.length, 1);
  assert.equal(result[0].items[0].id, "item-1");
  assert.equal(result[0].items[0].name, "Shirt");
  assert.equal(result[0].items[0].category, "tops");
  assert.equal(result[0].items[0].color, "blue");
  assert.equal(result[0].items[0].photoUrl, "http://example.com/photo.jpg");
});

test("listOutfits returns empty array when user has no outfits", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  const result = await repo.listOutfits(testAuthContext);

  assert.ok(Array.isArray(result));
  assert.equal(result.length, 0);
});

test("listOutfits sets app.current_user_id for RLS", async () => {
  const pool = createMockPool();
  const repo = createOutfitRepository({ pool });

  await repo.listOutfits(testAuthContext);

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});

test("listOutfits handles outfits with no items (filters [null] to [])", async () => {
  const pool = createMockPool({
    outfitList: [{
      id: "outfit-1", profile_id: "profile-uuid-1", name: "Empty",
      explanation: null, occasion: null, source: "ai", is_favorite: false,
      created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T00:00:00Z",
      items: [null]
    }]
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.listOutfits(testAuthContext);

  assert.equal(result.length, 1);
  assert.deepEqual(result[0].items, []);
});

// --- updateOutfit tests ---

test("updateOutfit toggles is_favorite to true", async () => {
  const pool = createMockPool({
    updateResult: {
      id: "outfit-uuid-1", profile_id: "profile-uuid-1", name: "Test",
      explanation: null, occasion: null, source: "ai", is_favorite: true,
      created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T00:00:00Z",
    }
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.updateOutfit(testAuthContext, "outfit-uuid-1", { isFavorite: true });

  assert.equal(result.isFavorite, true);
});

test("updateOutfit toggles is_favorite to false", async () => {
  const pool = createMockPool({
    updateResult: {
      id: "outfit-uuid-1", profile_id: "profile-uuid-1", name: "Test",
      explanation: null, occasion: null, source: "ai", is_favorite: false,
      created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T00:00:00Z",
    }
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.updateOutfit(testAuthContext, "outfit-uuid-1", { isFavorite: false });

  assert.equal(result.isFavorite, false);
});

test("updateOutfit returns updated outfit with new isFavorite value", async () => {
  const pool = createMockPool({
    updateResult: {
      id: "outfit-uuid-1", profile_id: "profile-uuid-1", name: "My Outfit",
      explanation: "test", occasion: "work", source: "manual", is_favorite: true,
      created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T01:00:00Z",
    }
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.updateOutfit(testAuthContext, "outfit-uuid-1", { isFavorite: true });

  assert.equal(result.id, "outfit-uuid-1");
  assert.equal(result.name, "My Outfit");
  assert.equal(result.isFavorite, true);
});

test("updateOutfit throws 404 when outfit not found", async () => {
  const pool = createMockPool(); // no updateResult
  const repo = createOutfitRepository({ pool });

  await assert.rejects(
    () => repo.updateOutfit(testAuthContext, "nonexistent-id", { isFavorite: true }),
    (err) => {
      assert.equal(err.statusCode, 404);
      assert.equal(err.code, "NOT_FOUND");
      assert.ok(err.message.includes("Outfit not found"));
      return true;
    }
  );
});

test("updateOutfit sets app.current_user_id for RLS", async () => {
  const pool = createMockPool({
    updateResult: {
      id: "outfit-uuid-1", profile_id: "profile-uuid-1", name: "Test",
      explanation: null, occasion: null, source: "ai", is_favorite: true,
      created_at: "2026-03-15T00:00:00Z", updated_at: "2026-03-15T00:00:00Z",
    }
  });
  const repo = createOutfitRepository({ pool });

  await repo.updateOutfit({ userId: "different-user" }, "outfit-uuid-1", { isFavorite: true });

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "different-user");
});

// --- deleteOutfit tests ---

test("deleteOutfit removes the outfit and returns { deleted: true }", async () => {
  const pool = createMockPool({
    deleteResult: { id: "outfit-uuid-1" }
  });
  const repo = createOutfitRepository({ pool });

  const result = await repo.deleteOutfit(testAuthContext, "outfit-uuid-1");

  assert.deepEqual(result, { deleted: true, id: "outfit-uuid-1" });
});

test("deleteOutfit throws 404 when outfit not found", async () => {
  const pool = createMockPool(); // no deleteResult
  const repo = createOutfitRepository({ pool });

  await assert.rejects(
    () => repo.deleteOutfit(testAuthContext, "nonexistent-id"),
    (err) => {
      assert.equal(err.statusCode, 404);
      assert.equal(err.code, "NOT_FOUND");
      assert.ok(err.message.includes("Outfit not found"));
      return true;
    }
  );
});

test("deleteOutfit sets app.current_user_id for RLS", async () => {
  const pool = createMockPool({
    deleteResult: { id: "outfit-uuid-1" }
  });
  const repo = createOutfitRepository({ pool });

  await repo.deleteOutfit({ userId: "different-user" }, "outfit-uuid-1");

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "different-user");
});

test("deleteOutfit sends DELETE query with correct outfit ID", async () => {
  const pool = createMockPool({
    deleteResult: { id: "outfit-uuid-1" }
  });
  const repo = createOutfitRepository({ pool });

  await repo.deleteOutfit(testAuthContext, "outfit-uuid-1");

  const deleteQuery = pool.queries.find(q => q.sql.includes("DELETE FROM app_public.outfits"));
  assert.ok(deleteQuery);
  assert.equal(deleteQuery.params[0], "outfit-uuid-1");
});

test("mapOutfitRow correctly maps database columns to camelCase", () => {
  const row = {
    id: "uuid-1",
    profile_id: "profile-1",
    name: "Test",
    explanation: "Test explanation",
    occasion: "everyday",
    source: "ai",
    is_favorite: true,
    created_at: "2026-03-15T00:00:00Z",
    updated_at: "2026-03-15T00:00:00Z",
    items: [{ id: "item-1", position: 0 }]
  };

  const mapped = mapOutfitRow(row);

  assert.equal(mapped.id, "uuid-1");
  assert.equal(mapped.profileId, "profile-1");
  assert.equal(mapped.name, "Test");
  assert.equal(mapped.explanation, "Test explanation");
  assert.equal(mapped.occasion, "everyday");
  assert.equal(mapped.source, "ai");
  assert.equal(mapped.isFavorite, true);
  assert.equal(mapped.createdAt, "2026-03-15T00:00:00Z");
  assert.equal(mapped.updatedAt, "2026-03-15T00:00:00Z");
  assert.deepEqual(mapped.items, [{ id: "item-1", position: 0 }]);
});
