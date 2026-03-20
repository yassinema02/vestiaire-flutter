import assert from "node:assert/strict";
import test from "node:test";
import { createLevelService } from "../../../src/modules/gamification/level-service.js";

const PROFILE_ID = "profile-uuid-1";

/**
 * Create a mock pool that simulates the recalculate_user_level RPC.
 * The RPC logic is replicated here to test the service's mapping behavior.
 */
function createMockPool({
  profileId = PROFILE_ID,
  itemCount = 0,
  storedLevel = 1,
  storedLevelName = "Closet Rookie",
  failProfile = false,
  failRpc = false,
} = {}) {
  const queries = [];

  // Level thresholds
  function calculateLevel(count) {
    if (count >= 200) return { level: 6, name: "Style Master", next: null };
    if (count >= 100) return { level: 5, name: "Style Expert", next: 200 };
    if (count >= 50) return { level: 4, name: "Wardrobe Pro", next: 100 };
    if (count >= 25) return { level: 3, name: "Fashion Explorer", next: 50 };
    if (count >= 10) return { level: 2, name: "Style Starter", next: 25 };
    return { level: 1, name: "Closet Rookie", next: 10 };
  }

  return {
    queries,
    async connect() {
      return {
        async query(sql, params = []) {
          queries.push({ sql, params });

          if (sql === "begin") return {};
          if (sql === "commit" || sql === "rollback") return {};
          if (sql.includes("set_config")) return {};

          // Profile lookup
          if (sql.includes("FROM app_public.profiles WHERE firebase_uid")) {
            if (failProfile) return { rows: [] };
            return { rows: [{ id: profileId }] };
          }

          // recalculate_user_level RPC
          if (sql.includes("recalculate_user_level")) {
            if (failRpc) throw new Error("RPC failed");
            const calc = calculateLevel(itemCount);
            // No downgrade
            const finalLevel = calc.level >= storedLevel ? calc.level : storedLevel;
            const finalName = calc.level >= storedLevel ? calc.name : storedLevelName;
            const thresholds = { 1: 10, 2: 25, 3: 50, 4: 100, 5: 200 };
            const finalNext = calc.level >= storedLevel ? calc.next : (thresholds[storedLevel] ?? null);
            return {
              rows: [{
                current_level: finalLevel,
                current_level_name: finalName,
                previous_level: storedLevel,
                previous_level_name: storedLevelName,
                leveled_up: finalLevel > storedLevel,
                item_count: itemCount,
                next_level_threshold: finalNext,
              }]
            };
          }

          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- Factory tests ---

test("createLevelService throws when pool is missing", () => {
  assert.throws(() => createLevelService({}), TypeError);
});

// --- recalculateLevel: Level thresholds ---

test("recalculateLevel returns level 1 'Closet Rookie' for 0 items", async () => {
  const pool = createMockPool({ itemCount: 0 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 1);
  assert.equal(result.currentLevelName, "Closet Rookie");
  assert.equal(result.leveledUp, false);
});

test("recalculateLevel returns level 2 'Style Starter' for exactly 10 items", async () => {
  const pool = createMockPool({ itemCount: 10 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 2);
  assert.equal(result.currentLevelName, "Style Starter");
});

test("recalculateLevel returns level 3 'Fashion Explorer' for 25 items", async () => {
  const pool = createMockPool({ itemCount: 25 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 3);
  assert.equal(result.currentLevelName, "Fashion Explorer");
});

test("recalculateLevel returns level 4 'Wardrobe Pro' for 50 items", async () => {
  const pool = createMockPool({ itemCount: 50 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 4);
  assert.equal(result.currentLevelName, "Wardrobe Pro");
});

test("recalculateLevel returns level 5 'Style Expert' for 100 items", async () => {
  const pool = createMockPool({ itemCount: 100 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 5);
  assert.equal(result.currentLevelName, "Style Expert");
});

test("recalculateLevel returns level 6 'Style Master' for 200 items", async () => {
  const pool = createMockPool({ itemCount: 200 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 6);
  assert.equal(result.currentLevelName, "Style Master");
});

// --- Level-up detection ---

test("recalculateLevel returns leveledUp: true when crossing 10-item threshold", async () => {
  const pool = createMockPool({ itemCount: 10, storedLevel: 1, storedLevelName: "Closet Rookie" });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.leveledUp, true);
  assert.equal(result.currentLevel, 2);
  assert.equal(result.previousLevel, 1);
});

test("recalculateLevel returns leveledUp: false when item count stays in same tier", async () => {
  const pool = createMockPool({ itemCount: 11, storedLevel: 2, storedLevelName: "Style Starter" });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.leveledUp, false);
  assert.equal(result.currentLevel, 2);
});

// --- nextLevelThreshold ---

test("recalculateLevel returns correct nextLevelThreshold for each level", async () => {
  // Level 1 -> threshold 10
  let pool = createMockPool({ itemCount: 5 });
  let service = createLevelService({ pool });
  let result = await service.recalculateLevel(testAuthContext);
  assert.equal(result.nextLevelThreshold, 10);

  // Level 2 -> threshold 25
  pool = createMockPool({ itemCount: 10 });
  service = createLevelService({ pool });
  result = await service.recalculateLevel(testAuthContext);
  assert.equal(result.nextLevelThreshold, 25);

  // Level 3 -> threshold 50
  pool = createMockPool({ itemCount: 25 });
  service = createLevelService({ pool });
  result = await service.recalculateLevel(testAuthContext);
  assert.equal(result.nextLevelThreshold, 50);

  // Level 4 -> threshold 100
  pool = createMockPool({ itemCount: 50 });
  service = createLevelService({ pool });
  result = await service.recalculateLevel(testAuthContext);
  assert.equal(result.nextLevelThreshold, 100);

  // Level 5 -> threshold 200
  pool = createMockPool({ itemCount: 100 });
  service = createLevelService({ pool });
  result = await service.recalculateLevel(testAuthContext);
  assert.equal(result.nextLevelThreshold, 200);
});

test("recalculateLevel returns nextLevelThreshold: null for level 6 (max)", async () => {
  const pool = createMockPool({ itemCount: 200 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.nextLevelThreshold, null);
});

// --- Boundary tests ---

test("Boundary: 9 items = level 1", async () => {
  const pool = createMockPool({ itemCount: 9 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 1);
  assert.equal(result.currentLevelName, "Closet Rookie");
});

test("Boundary: 10 items = level 2", async () => {
  const pool = createMockPool({ itemCount: 10 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 2);
  assert.equal(result.currentLevelName, "Style Starter");
});

test("Boundary: 24 items = level 2", async () => {
  const pool = createMockPool({ itemCount: 24, storedLevel: 2, storedLevelName: "Style Starter" });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 2);
  assert.equal(result.currentLevelName, "Style Starter");
});

test("Boundary: 25 items = level 3", async () => {
  const pool = createMockPool({ itemCount: 25 });
  const service = createLevelService({ pool });

  const result = await service.recalculateLevel(testAuthContext);

  assert.equal(result.currentLevel, 3);
  assert.equal(result.currentLevelName, "Fashion Explorer");
});

// --- Error handling ---

test("recalculateLevel throws when profile not found", async () => {
  const pool = createMockPool({ failProfile: true });
  const service = createLevelService({ pool });

  await assert.rejects(
    () => service.recalculateLevel(testAuthContext),
    { message: "Profile not found for authenticated user" }
  );
});

// --- RLS isolation ---

test("RLS isolation: sets app.current_user_id for scoped queries", async () => {
  const pool = createMockPool({ itemCount: 5 });
  const service = createLevelService({ pool });

  await service.recalculateLevel(testAuthContext);

  const configQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(configQuery);
  assert.equal(configQuery.params[0], "firebase-user-123");
});
