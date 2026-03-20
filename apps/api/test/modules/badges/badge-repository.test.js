import assert from "node:assert/strict";
import test from "node:test";
import { createBadgeRepository } from "../../../src/modules/badges/badge-repository.js";

// --- Mock pool helpers ---

function createMockPool({
  allBadgesRows = [],
  userBadgesRows = [],
  evaluateRows = [],
  profileRows = [{ id: "profile-uuid-1" }],
} = {}) {
  const queries = [];

  return {
    queries,
    async connect() {
      return {
        async query(sql, params) {
          queries.push({ sql, params });

          if (sql.includes("set_config")) {
            return { rows: [] };
          }
          if (sql === "begin" || sql === "commit" || sql === "rollback") {
            return { rows: [] };
          }
          if (sql.includes("FROM app_public.badges") && sql.includes("ORDER BY sort_order")) {
            return { rows: allBadgesRows };
          }
          if (sql.includes("FROM app_public.user_badges")) {
            return { rows: userBadgesRows };
          }
          if (sql.includes("FROM app_public.profiles WHERE firebase_uid")) {
            return { rows: profileRows };
          }
          if (sql.includes("evaluate_badges")) {
            return { rows: evaluateRows };
          }

          return { rows: [] };
        },
        release() {},
      };
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- Factory tests ---

test("createBadgeRepository throws when pool is missing", () => {
  assert.throws(() => createBadgeRepository({}), TypeError);
});

// --- getAllBadges tests ---

test("getAllBadges returns all 15 badge definitions in sort order", async () => {
  const mockRows = Array.from({ length: 15 }, (_, i) => ({
    key: `badge_${i + 1}`,
    name: `Badge ${i + 1}`,
    description: `Description ${i + 1}`,
    icon_name: "star",
    icon_color: "#FBBF24",
    category: "wardrobe",
    sort_order: i + 1,
  }));

  const pool = createMockPool({ allBadgesRows: mockRows });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.getAllBadges();

  assert.equal(badges.length, 15);
  assert.equal(badges[0].key, "badge_1");
  assert.equal(badges[14].key, "badge_15");
});

test("getAllBadges maps snake_case to camelCase", async () => {
  const pool = createMockPool({
    allBadgesRows: [{
      key: "first_step",
      name: "First Step",
      description: "Upload first item",
      icon_name: "star",
      icon_color: "#FBBF24",
      category: "wardrobe",
      sort_order: 1,
    }],
  });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.getAllBadges();

  assert.equal(badges[0].iconName, "star");
  assert.equal(badges[0].iconColor, "#FBBF24");
  assert.equal(badges[0].sortOrder, 1);
  // Verify snake_case keys are NOT present
  assert.equal(badges[0].icon_name, undefined);
  assert.equal(badges[0].icon_color, undefined);
  assert.equal(badges[0].sort_order, undefined);
});

// --- getUserBadges tests ---

test("getUserBadges returns empty array for user with no badges", async () => {
  const pool = createMockPool({ userBadgesRows: [] });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.getUserBadges(testAuthContext);

  assert.deepEqual(badges, []);
});

test("getUserBadges returns correct badges for user with earned badges", async () => {
  const pool = createMockPool({
    userBadgesRows: [{
      key: "first_step",
      name: "First Step",
      description: "Upload first item",
      icon_name: "star",
      icon_color: "#FBBF24",
      category: "wardrobe",
      awarded_at: "2026-03-19T10:00:00Z",
    }],
  });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.getUserBadges(testAuthContext);

  assert.equal(badges.length, 1);
  assert.equal(badges[0].key, "first_step");
  assert.equal(badges[0].name, "First Step");
  assert.equal(badges[0].awardedAt, "2026-03-19T10:00:00Z");
});

test("getUserBadges returns badges ordered by awarded_at DESC", async () => {
  const pool = createMockPool({
    userBadgesRows: [
      { key: "first_step", name: "First Step", description: "d", icon_name: "star", icon_color: "#FBBF24", category: "wardrobe", awarded_at: "2026-03-19T10:00:00Z" },
      { key: "week_warrior", name: "Week Warrior", description: "d", icon_name: "fire", icon_color: "#F97316", category: "streak", awarded_at: "2026-03-18T10:00:00Z" },
    ],
  });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.getUserBadges(testAuthContext);

  assert.equal(badges.length, 2);
  assert.equal(badges[0].key, "first_step");
  assert.equal(badges[1].key, "week_warrior");
});

// --- evaluateBadges tests ---

test("evaluateBadges returns empty array when no new badges earned", async () => {
  const pool = createMockPool({ evaluateRows: [] });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.evaluateBadges(testAuthContext);

  assert.deepEqual(badges, []);
});

test("evaluateBadges returns newly awarded badge when criterion met", async () => {
  const pool = createMockPool({
    evaluateRows: [{
      badge_key: "first_step",
      badge_name: "First Step",
      badge_description: "Upload first item",
      badge_icon_name: "star",
      badge_icon_color: "#FBBF24",
    }],
  });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.evaluateBadges(testAuthContext);

  assert.equal(badges.length, 1);
  assert.equal(badges[0].key, "first_step");
  assert.equal(badges[0].iconName, "star");
  assert.equal(badges[0].iconColor, "#FBBF24");
});

test("evaluateBadges awards multiple badges simultaneously when multiple criteria met", async () => {
  const pool = createMockPool({
    evaluateRows: [
      { badge_key: "first_step", badge_name: "First Step", badge_description: "d", badge_icon_name: "star", badge_icon_color: "#FBBF24" },
      { badge_key: "week_warrior", badge_name: "Week Warrior", badge_description: "d", badge_icon_name: "fire", badge_icon_color: "#F97316" },
    ],
  });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.evaluateBadges(testAuthContext);

  assert.equal(badges.length, 2);
  assert.equal(badges[0].key, "first_step");
  assert.equal(badges[1].key, "week_warrior");
});

test("evaluateBadges returns empty array when profile not found", async () => {
  const pool = createMockPool({ profileRows: [] });
  const repo = createBadgeRepository({ pool });

  const badges = await repo.evaluateBadges(testAuthContext);

  assert.deepEqual(badges, []);
});

test("evaluateBadges calls evaluate_badges RPC with correct profile_id", async () => {
  const pool = createMockPool({
    profileRows: [{ id: "profile-uuid-42" }],
    evaluateRows: [],
  });
  const repo = createBadgeRepository({ pool });

  await repo.evaluateBadges(testAuthContext);

  const rpcCall = pool.queries.find((q) => q.sql.includes("evaluate_badges"));
  assert.ok(rpcCall);
  assert.deepEqual(rpcCall.params, ["profile-uuid-42"]);
});
