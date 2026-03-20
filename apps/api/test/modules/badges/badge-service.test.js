import assert from "node:assert/strict";
import test from "node:test";
import { createBadgeService } from "../../../src/modules/badges/badge-service.js";

function createMockBadgeRepo({
  evaluateResult = [],
  allBadges = [],
  userBadges = [],
} = {}) {
  const calls = [];
  return {
    calls,
    async evaluateBadges(authContext) {
      calls.push({ method: "evaluateBadges", authContext });
      return evaluateResult;
    },
    async getAllBadges() {
      calls.push({ method: "getAllBadges" });
      return allBadges;
    },
    async getUserBadges(authContext) {
      calls.push({ method: "getUserBadges", authContext });
      return userBadges;
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- Factory tests ---

test("createBadgeService throws when badgeRepo is missing", () => {
  assert.throws(() => createBadgeService({}), TypeError);
});

// --- evaluateAndAward tests ---

test("evaluateAndAward returns { badgesAwarded: [] } when no badges earned", async () => {
  const repo = createMockBadgeRepo({ evaluateResult: [] });
  const service = createBadgeService({ badgeRepo: repo });

  const result = await service.evaluateAndAward(testAuthContext);

  assert.deepEqual(result, { badgesAwarded: [] });
});

test("evaluateAndAward returns { badgesAwarded: [...] } when badge earned", async () => {
  const repo = createMockBadgeRepo({
    evaluateResult: [{ key: "first_step", name: "First Step", description: "Upload first item", iconName: "star", iconColor: "#FBBF24" }],
  });
  const service = createBadgeService({ badgeRepo: repo });

  const result = await service.evaluateAndAward(testAuthContext);

  assert.equal(result.badgesAwarded.length, 1);
  assert.equal(result.badgesAwarded[0].key, "first_step");
});

// --- getBadgeCatalog tests ---

test("getBadgeCatalog returns all 15 badges", async () => {
  const badges = Array.from({ length: 15 }, (_, i) => ({
    key: `badge_${i + 1}`,
    name: `Badge ${i + 1}`,
    description: `Description ${i + 1}`,
    iconName: "star",
    iconColor: "#FBBF24",
    category: "wardrobe",
    sortOrder: i + 1,
  }));
  const repo = createMockBadgeRepo({ allBadges: badges });
  const service = createBadgeService({ badgeRepo: repo });

  const result = await service.getBadgeCatalog();

  assert.equal(result.length, 15);
});

// --- getUserBadgeCollection tests ---

test("getUserBadgeCollection returns correct badges and badgeCount", async () => {
  const repo = createMockBadgeRepo({
    userBadges: [
      { key: "first_step", name: "First Step", description: "d", iconName: "star", iconColor: "#FBBF24", category: "wardrobe", awardedAt: "2026-03-19T10:00:00Z" },
      { key: "week_warrior", name: "Week Warrior", description: "d", iconName: "fire", iconColor: "#F97316", category: "streak", awardedAt: "2026-03-18T10:00:00Z" },
    ],
  });
  const service = createBadgeService({ badgeRepo: repo });

  const result = await service.getUserBadgeCollection(testAuthContext);

  assert.equal(result.badges.length, 2);
  assert.equal(result.badgeCount, 2);
  assert.equal(result.badges[0].key, "first_step");
});

test("getUserBadgeCollection returns badgeCount 0 for user with no badges", async () => {
  const repo = createMockBadgeRepo({ userBadges: [] });
  const service = createBadgeService({ badgeRepo: repo });

  const result = await service.getUserBadgeCollection(testAuthContext);

  assert.equal(result.badges.length, 0);
  assert.equal(result.badgeCount, 0);
});
