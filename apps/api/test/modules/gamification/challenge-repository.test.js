import assert from "node:assert/strict";
import test from "node:test";
import { createChallengeRepository } from "../../../src/modules/gamification/challenge-repository.js";

// --- Mock pool factory ---

function createMockPool(queryResults = {}) {
  const queries = [];
  return {
    queries,
    connect() {
      return {
        query(sql, params) {
          queries.push({ sql, params });
          // Match queries by keyword
          if (sql.includes("set_config")) {
            return { rows: [] };
          }
          if (sql === "begin" || sql === "commit" || sql === "rollback") {
            return { rows: [] };
          }
          // Return result based on query type
          for (const [key, result] of Object.entries(queryResults)) {
            if (sql.includes(key)) {
              return typeof result === "function" ? result(sql, params) : result;
            }
          }
          return { rows: [] };
        },
        release() {},
      };
    },
  };
}

// --- getChallenge tests ---

test("getChallenge returns closet_safari challenge definition", async () => {
  const pool = createMockPool({
    "FROM app_public.challenges": {
      rows: [{
        key: "closet_safari",
        name: "Closet Safari",
        description: "Upload 20 items in 7 days to unlock 1 month Premium free",
        target_count: 20,
        time_limit_days: 7,
        reward_type: "premium_trial",
        reward_value: 30,
        icon_name: "explore",
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.getChallenge("closet_safari");

  assert.equal(result.key, "closet_safari");
  assert.equal(result.name, "Closet Safari");
  assert.equal(result.targetCount, 20);
  assert.equal(result.timeLimitDays, 7);
  assert.equal(result.rewardType, "premium_trial");
  assert.equal(result.rewardValue, 30);
  assert.equal(result.iconName, "explore");
});

test("getChallenge returns null for unknown challenge key", async () => {
  const pool = createMockPool({
    "FROM app_public.challenges": { rows: [] },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.getChallenge("unknown_key");

  assert.equal(result, null);
});

// --- getUserChallenge tests ---

test("getUserChallenge returns null when user has not accepted", async () => {
  const pool = createMockPool({
    "FROM app_public.user_challenges": { rows: [] },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.getUserChallenge({ userId: "user-1" }, "closet_safari");

  assert.equal(result, null);
});

test("getUserChallenge returns challenge state when accepted", async () => {
  const pool = createMockPool({
    "FROM app_public.user_challenges": {
      rows: [{
        key: "closet_safari",
        name: "Closet Safari",
        status: "active",
        accepted_at: "2026-03-19T10:00:00Z",
        completed_at: null,
        expires_at: "2026-03-26T10:00:00Z",
        current_progress: 5,
        target_count: 20,
        reward_type: "premium_trial",
        reward_value: 30,
        time_remaining_seconds: 604800,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.getUserChallenge({ userId: "user-1" }, "closet_safari");

  assert.equal(result.key, "closet_safari");
  assert.equal(result.status, "active");
  assert.equal(result.currentProgress, 5);
  assert.equal(result.targetCount, 20);
  assert.equal(result.timeRemainingSeconds, 604800);
});

// --- acceptChallenge tests ---

test("acceptChallenge creates user_challenges row with correct fields", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "FROM app_public.challenges WHERE key": { rows: [{ id: "challenge-1", time_limit_days: 7 }] },
    "COUNT": { rows: [{ count: 5 }] },
    "INSERT INTO app_public.user_challenges": {
      rows: [{ id: "uc-1" }],
    },
    "WHERE uc.id": {
      rows: [{
        key: "closet_safari",
        name: "Closet Safari",
        status: "active",
        accepted_at: "2026-03-19",
        expires_at: "2026-03-26",
        current_progress: 5,
        target_count: 20,
        reward_type: "premium_trial",
        reward_value: 30,
        time_remaining_seconds: 604800,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.acceptChallenge({ userId: "user-1" }, "closet_safari");

  assert.equal(result.key, "closet_safari");
  assert.equal(result.currentProgress, 5);
  assert.equal(result.status, "active");
});

test("acceptChallenge is idempotent (second call returns existing row)", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "FROM app_public.challenges WHERE key": { rows: [{ id: "challenge-1", time_limit_days: 7 }] },
    "COUNT": { rows: [{ count: 5 }] },
    "INSERT INTO app_public.user_challenges": {
      rows: [], // ON CONFLICT DO NOTHING, no rows returned
    },
    "WHERE uc.profile_id": {
      rows: [{
        key: "closet_safari",
        name: "Closet Safari",
        status: "active",
        accepted_at: "2026-03-19",
        expires_at: "2026-03-26",
        current_progress: 5,
        target_count: 20,
        reward_type: "premium_trial",
        reward_value: 30,
        time_remaining_seconds: 604800,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.acceptChallenge({ userId: "user-1" }, "closet_safari");

  assert.equal(result.key, "closet_safari");
  assert.equal(result.status, "active");
});

test("acceptChallenge sets current_progress to user's current item count", async () => {
  const queryCalls = [];
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "FROM app_public.challenges WHERE key": { rows: [{ id: "challenge-1", time_limit_days: 7 }] },
    "COUNT": { rows: [{ count: 12 }] },
    "INSERT INTO app_public.user_challenges": (sql, params) => {
      queryCalls.push(params);
      return {
        rows: [{ id: "uc-1" }],
      };
    },
    "WHERE uc.id": {
      rows: [{
        key: "closet_safari", name: "Closet Safari", status: "active",
        accepted_at: "2026-03-19", expires_at: "2026-03-26",
        current_progress: 12, target_count: 20,
        reward_type: "premium_trial", reward_value: 30,
        time_remaining_seconds: 604800,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.acceptChallenge({ userId: "user-1" }, "closet_safari");

  assert.equal(result.currentProgress, 12);
  // Verify the INSERT was called with itemCount=12
  const insertCall = queryCalls.find((p) => p && p.length === 4);
  assert.ok(insertCall);
  assert.equal(insertCall[3], 12);
});

test("acceptChallenge sets expires_at to 7 days from now", async () => {
  const insertParams = [];
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "FROM app_public.challenges WHERE key": { rows: [{ id: "challenge-1", time_limit_days: 7 }] },
    "COUNT": { rows: [{ count: 0 }] },
    "INSERT INTO app_public.user_challenges": (sql, params) => {
      insertParams.push({ sql, params });
      return { rows: [{ id: "uc-1" }] };
    },
    "WHERE uc.id": {
      rows: [{
        key: "closet_safari", name: "Closet Safari", status: "active",
        accepted_at: "2026-03-19", expires_at: "2026-03-26",
        current_progress: 0, target_count: 20,
        reward_type: "premium_trial", reward_value: 30,
        time_remaining_seconds: 604800,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  await repo.acceptChallenge({ userId: "user-1" }, "closet_safari");

  // Verify the INSERT SQL references the time_limit_days for interval
  const insertCall = insertParams[0];
  assert.ok(insertCall.sql.includes("INTERVAL"));
  assert.equal(insertCall.params[2], "7"); // time_limit_days as string
});

// --- incrementProgress tests ---

test("incrementProgress increments current_progress by 1", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "increment_challenge_progress": {
      rows: [{
        challenge_key: "closet_safari",
        current_progress: 6,
        target_count: 20,
        completed: false,
        reward_granted: false,
        time_remaining_seconds: 500000,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.incrementProgress({ userId: "user-1" }, "closet_safari");

  assert.equal(result.currentProgress, 6);
  assert.equal(result.completed, false);
  assert.equal(result.rewardGranted, false);
});

test("incrementProgress returns null when no active challenge", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "increment_challenge_progress": { rows: [] },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.incrementProgress({ userId: "user-1" }, "closet_safari");

  assert.equal(result, null);
});

test("incrementProgress completes challenge when reaching target_count", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "increment_challenge_progress": {
      rows: [{
        challenge_key: "closet_safari",
        current_progress: 20,
        target_count: 20,
        completed: true,
        reward_granted: true,
        time_remaining_seconds: 300000,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.incrementProgress({ userId: "user-1" }, "closet_safari");

  assert.equal(result.completed, true);
  assert.equal(result.rewardGranted, true);
  assert.equal(result.currentProgress, 20);
});

test("incrementProgress grants premium trial on completion", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "increment_challenge_progress": {
      rows: [{
        challenge_key: "closet_safari",
        current_progress: 20,
        target_count: 20,
        completed: true,
        reward_granted: true,
        time_remaining_seconds: 300000,
      }],
    },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.incrementProgress({ userId: "user-1" }, "closet_safari");

  assert.equal(result.rewardGranted, true);
});

test("incrementProgress is idempotent for already-completed challenges", async () => {
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "increment_challenge_progress": { rows: [] }, // No active challenge found
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.incrementProgress({ userId: "user-1" }, "closet_safari");

  assert.equal(result, null);
});

// --- expireChallengeIfNeeded tests ---

test("expireChallengeIfNeeded returns null when no expired challenge", async () => {
  const pool = createMockPool({
    "UPDATE app_public.user_challenges": { rows: [] },
  });

  const repo = createChallengeRepository({ pool });
  const result = await repo.expireChallengeIfNeeded({ userId: "user-1" }, "closet_safari");

  assert.equal(result, null);
});

// --- Constructor validation ---

test("createChallengeRepository throws if pool is missing", () => {
  assert.throws(() => createChallengeRepository({}), {
    message: "pool is required",
  });
});

// --- RLS isolation test ---

test("RLS isolation: queries use authContext.userId for profile lookup", async () => {
  const pool = createMockPool({
    "FROM app_public.user_challenges": { rows: [] },
  });

  const repo = createChallengeRepository({ pool });
  await repo.getUserChallenge({ userId: "user-A" }, "closet_safari");

  // Verify set_config was called with user-A
  const setConfigCall = pool.queries.find((q) => q.sql.includes("set_config"));
  assert.ok(setConfigCall);
  assert.equal(setConfigCall.params[0], "user-A");
});
