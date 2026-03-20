import assert from "node:assert/strict";
import test from "node:test";
import { createChallengeService } from "../../../src/modules/gamification/challenge-service.js";

// --- Mock factories ---

function createMockChallengeRepo(overrides = {}) {
  return {
    async getChallenge(key) {
      return overrides.getChallenge?.(key) ?? null;
    },
    async getUserChallenge(authContext, key) {
      return overrides.getUserChallenge?.(authContext, key) ?? null;
    },
    async acceptChallenge(authContext, key) {
      return overrides.acceptChallenge?.(authContext, key) ?? {
        key: "closet_safari",
        name: "Closet Safari",
        status: "active",
        acceptedAt: "2026-03-19T10:00:00Z",
        expiresAt: "2026-03-26T10:00:00Z",
        currentProgress: 5,
        targetCount: 20,
        timeRemainingSeconds: 604800,
      };
    },
    async incrementProgress(authContext, key) {
      return overrides.incrementProgress?.(authContext, key) ?? null;
    },
    async expireChallengeIfNeeded(authContext, key) {
      return overrides.expireChallengeIfNeeded?.(authContext, key) ?? null;
    },
  };
}

function createMockPool(queryResults = {}) {
  return {
    connect() {
      return {
        query(sql, params) {
          if (sql.includes("set_config") || sql === "begin" || sql === "commit" || sql === "rollback") {
            return { rows: [] };
          }
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

const authContext = { userId: "firebase-user-123" };

// --- acceptChallenge tests ---

test("acceptChallenge returns challenge state for valid key", async () => {
  const repo = createMockChallengeRepo();
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.acceptChallenge(authContext, "closet_safari");

  assert.ok(result.challenge);
  assert.equal(result.challenge.key, "closet_safari");
  assert.equal(result.challenge.status, "active");
  assert.equal(result.challenge.currentProgress, 5);
  assert.equal(result.challenge.targetCount, 20);
});

test("acceptChallenge throws 404 for invalid challenge key", async () => {
  const repo = createMockChallengeRepo();
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  await assert.rejects(
    () => service.acceptChallenge(authContext, "unknown_key"),
    (error) => {
      assert.equal(error.statusCode, 404);
      return true;
    }
  );
});

// --- updateProgressOnItemCreate tests ---

test("updateProgressOnItemCreate returns challengeUpdate when active challenge exists", async () => {
  const repo = createMockChallengeRepo({
    incrementProgress: () => ({
      challengeKey: "closet_safari",
      currentProgress: 10,
      targetCount: 20,
      completed: false,
      rewardGranted: false,
      timeRemainingSeconds: 500000,
    }),
  });
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.updateProgressOnItemCreate(authContext);

  assert.ok(result.challengeUpdate);
  assert.equal(result.challengeUpdate.key, "closet_safari");
  assert.equal(result.challengeUpdate.currentProgress, 10);
  assert.equal(result.challengeUpdate.completed, false);
});

test("updateProgressOnItemCreate returns null challengeUpdate when no active challenge", async () => {
  const repo = createMockChallengeRepo({
    incrementProgress: () => null,
  });
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.updateProgressOnItemCreate(authContext);

  assert.equal(result.challengeUpdate, null);
});

test("updateProgressOnItemCreate returns completed=true when target reached", async () => {
  const repo = createMockChallengeRepo({
    incrementProgress: () => ({
      challengeKey: "closet_safari",
      currentProgress: 20,
      targetCount: 20,
      completed: true,
      rewardGranted: true,
      timeRemainingSeconds: 300000,
    }),
  });
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.updateProgressOnItemCreate(authContext);

  assert.equal(result.challengeUpdate.completed, true);
  assert.equal(result.challengeUpdate.rewardGranted, true);
});

// --- getChallengeStatus tests ---

test("getChallengeStatus returns challenge state", async () => {
  const repo = createMockChallengeRepo({
    getUserChallenge: () => ({
      key: "closet_safari",
      name: "Closet Safari",
      status: "active",
      currentProgress: 8,
      targetCount: 20,
      expiresAt: "2026-03-26T10:00:00Z",
      timeRemainingSeconds: 500000,
      rewardType: "premium_trial",
      rewardValue: 30,
    }),
  });
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.getChallengeStatus(authContext);

  assert.equal(result.key, "closet_safari");
  assert.equal(result.currentProgress, 8);
  assert.ok(result.reward);
  assert.equal(result.reward.type, "premium_trial");
  assert.equal(result.reward.description, "1 month Premium free");
});

test("getChallengeStatus expires stale challenges", async () => {
  let expireCalled = false;
  const repo = createMockChallengeRepo({
    getUserChallenge: () => ({
      key: "closet_safari",
      name: "Closet Safari",
      status: "active",
      currentProgress: 8,
      targetCount: 20,
      expiresAt: "2026-03-12T10:00:00Z",
      timeRemainingSeconds: -100,
      rewardType: "premium_trial",
      rewardValue: 30,
    }),
    expireChallengeIfNeeded: () => {
      expireCalled = true;
      return {
        key: "closet_safari",
        name: "Closet Safari",
        status: "expired",
        currentProgress: 8,
        targetCount: 20,
        timeRemainingSeconds: 0,
      };
    },
  });
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.getChallengeStatus(authContext);

  assert.equal(expireCalled, true);
  assert.equal(result.status, "expired");
});

test("getChallengeStatus returns null when no challenge", async () => {
  const repo = createMockChallengeRepo({
    getUserChallenge: () => null,
  });
  const pool = createMockPool();
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.getChallengeStatus(authContext);

  assert.equal(result, null);
});

// --- checkTrialExpiry tests ---

test("checkTrialExpiry calls check_trial_expiry RPC", async () => {
  let rpcCalled = false;
  const repo = createMockChallengeRepo();
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "check_trial_expiry": () => {
      rpcCalled = true;
      return {
        rows: [{
          is_premium: true,
          premium_trial_expires_at: "2026-04-19T10:00:00Z",
          trial_expired: false,
        }],
      };
    },
  });
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.checkTrialExpiry(authContext);

  assert.equal(rpcCalled, true);
  assert.equal(result.isPremium, true);
  assert.equal(result.trialExpired, false);
});

test("checkTrialExpiry downgrades expired premium trials", async () => {
  const repo = createMockChallengeRepo();
  const pool = createMockPool({
    "FROM app_public.profiles WHERE firebase_uid": { rows: [{ id: "profile-1" }] },
    "check_trial_expiry": {
      rows: [{
        is_premium: false,
        premium_trial_expires_at: null,
        trial_expired: true,
      }],
    },
  });
  const service = createChallengeService({ challengeRepo: repo, pool });

  const result = await service.checkTrialExpiry(authContext);

  assert.equal(result.isPremium, false);
  assert.equal(result.trialExpired, true);
  assert.equal(result.premiumTrialExpiresAt, null);
});

// --- Constructor validation ---

test("createChallengeService throws if challengeRepo is missing", () => {
  assert.throws(() => createChallengeService({ pool: {} }), {
    message: "challengeRepo is required",
  });
});

test("createChallengeService throws if pool is missing", () => {
  assert.throws(() => createChallengeService({ challengeRepo: {} }), {
    message: "pool is required",
  });
});
