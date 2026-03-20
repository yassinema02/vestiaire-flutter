import assert from "node:assert/strict";
import test from "node:test";
import { createStylePointsService } from "../../../src/modules/gamification/style-points-service.js";

function createMockUserStatsRepo({
  awardPointsResult = { totalPoints: 10, pointsAwarded: 10 },
  awardPointsWithStreakResult = null,
  isFirstLogToday = false,
  isStreakDay = false,
} = {}) {
  const calls = [];

  return {
    calls,
    async awardPoints(authContext, { points }) {
      calls.push({ method: "awardPoints", authContext, points });
      return awardPointsResult;
    },
    async awardPointsWithStreak(authContext, { basePoints, isFirstLogToday: flt, isStreakDay: sd }) {
      calls.push({ method: "awardPointsWithStreak", authContext, basePoints, isFirstLogToday: flt, isStreakDay: sd });
      if (awardPointsWithStreakResult) return awardPointsWithStreakResult;
      const bonus = (flt ? 2 : 0) + (sd ? 3 : 0);
      return {
        totalPoints: basePoints + bonus + 100,
        pointsAwarded: basePoints + bonus,
        currentStreak: sd ? 3 : 0,
      };
    },
    async checkFirstLogToday(authContext) {
      calls.push({ method: "checkFirstLogToday", authContext });
      return isFirstLogToday;
    },
    async checkStreakDay(authContext) {
      calls.push({ method: "checkStreakDay", authContext });
      return isStreakDay;
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- Factory tests ---

test("createStylePointsService throws when userStatsRepo is missing", () => {
  assert.throws(() => createStylePointsService({}), TypeError);
});

// --- awardItemUploadPoints tests ---

test("awardItemUploadPoints calls awardPoints with 10 points", async () => {
  const mockRepo = createMockUserStatsRepo();
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  await service.awardItemUploadPoints(testAuthContext);

  const awardCall = mockRepo.calls.find(c => c.method === "awardPoints");
  assert.ok(awardCall);
  assert.equal(awardCall.points, 10);
});

test("awardItemUploadPoints returns pointsAwarded: 10 and action: item_upload", async () => {
  const mockRepo = createMockUserStatsRepo({
    awardPointsResult: { totalPoints: 50, pointsAwarded: 10 }
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardItemUploadPoints(testAuthContext);

  assert.equal(result.pointsAwarded, 10);
  assert.equal(result.totalPoints, 50);
  assert.equal(result.action, "item_upload");
});

// --- awardWearLogPoints tests ---

test("awardWearLogPoints awards 5 base points when no bonuses apply", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: false,
    isStreakDay: false,
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.equal(result.pointsAwarded, 5);
  assert.equal(result.bonuses.firstLogOfDay, 0);
  assert.equal(result.bonuses.streakDay, 0);
});

test("awardWearLogPoints awards 7 points when first-log-of-day bonus applies (+5 +2)", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: true,
    isStreakDay: false,
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.equal(result.pointsAwarded, 7);
  assert.equal(result.bonuses.firstLogOfDay, 2);
  assert.equal(result.bonuses.streakDay, 0);
});

test("awardWearLogPoints awards 8 points when streak bonus applies (+5 +3)", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: false,
    isStreakDay: true,
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.equal(result.pointsAwarded, 8);
  assert.equal(result.bonuses.firstLogOfDay, 0);
  assert.equal(result.bonuses.streakDay, 3);
});

test("awardWearLogPoints awards 10 points when both bonuses apply (+5 +2 +3)", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: true,
    isStreakDay: true,
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.equal(result.pointsAwarded, 10);
  assert.equal(result.bonuses.firstLogOfDay, 2);
  assert.equal(result.bonuses.streakDay, 3);
});

test("awardWearLogPoints returns correct bonuses breakdown", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: true,
    isStreakDay: true,
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.deepEqual(result.bonuses, { firstLogOfDay: 2, streakDay: 3 });
  assert.equal(result.action, "wear_log");
});

test("awardWearLogPoints returns currentStreak from repository", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: false,
    isStreakDay: true,
    awardPointsWithStreakResult: {
      totalPoints: 100,
      pointsAwarded: 8,
      currentStreak: 7,
    }
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.equal(result.currentStreak, 7);
});

// --- Story 6.3: Pre-computed isStreakDay parameter ---

test("awardWearLogPoints uses pre-computed isStreakDay=true from options instead of checkStreakDay", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: false,
    isStreakDay: false, // checkStreakDay would return false
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext, { isStreakDay: true });

  // Should use the pre-computed value (true) not checkStreakDay (false)
  assert.equal(result.bonuses.streakDay, 3);
  assert.equal(result.pointsAwarded, 8); // 5 base + 3 streak
  // checkStreakDay should NOT have been called when isStreakDay is provided
  const checkStreakCalls = mockRepo.calls.filter(c => c.method === "checkStreakDay");
  assert.equal(checkStreakCalls.length, 0);
});

test("awardWearLogPoints uses pre-computed isStreakDay=false from options", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: false,
    isStreakDay: true, // checkStreakDay would return true
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext, { isStreakDay: false });

  // Should use the pre-computed value (false) not checkStreakDay (true)
  assert.equal(result.bonuses.streakDay, 0);
  assert.equal(result.pointsAwarded, 5); // 5 base only
  const checkStreakCalls = mockRepo.calls.filter(c => c.method === "checkStreakDay");
  assert.equal(checkStreakCalls.length, 0);
});

test("awardWearLogPoints falls back to checkStreakDay when isStreakDay not provided", async () => {
  const mockRepo = createMockUserStatsRepo({
    isFirstLogToday: false,
    isStreakDay: true,
  });
  const service = createStylePointsService({ userStatsRepo: mockRepo });

  const result = await service.awardWearLogPoints(testAuthContext);

  assert.equal(result.bonuses.streakDay, 3);
  const checkStreakCalls = mockRepo.calls.filter(c => c.method === "checkStreakDay");
  assert.equal(checkStreakCalls.length, 1);
});
