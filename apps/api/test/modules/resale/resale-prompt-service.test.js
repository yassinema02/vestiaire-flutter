import assert from "node:assert/strict";
import test from "node:test";
import {
  createResalePromptService,
  computeEstimatedPrice,
  getDepreciationFactor,
} from "../../../src/modules/resale/resale-prompt-service.js";

// ───────────── Helpers ─────────────

const testAuth = { userId: "firebase-user-123" };
const testProfileId = "profile-uuid-1";

function createMockPool({
  queryResults = [],
  connectResults = null,
} = {}) {
  const queries = [];
  const client = {
    queries: [],
    async query(sql, params) {
      client.queries.push({ sql, params });
      if (connectResults) {
        const entry = connectResults.find((r) =>
          typeof r.match === "string" ? sql.includes(r.match) : r.match(sql, params)
        );
        if (entry) return entry.result;
      }
      return { rows: queryResults };
    },
    release() {},
  };

  return {
    queries,
    client,
    async connect() {
      return client;
    },
    async query(sql, params) {
      queries.push({ sql, params });
      return { rows: queryResults };
    },
  };
}

function createMockNotificationService() {
  const calls = [];
  return {
    calls,
    async sendPushNotification(profileId, notification, options) {
      calls.push({ profileId, notification, options });
    },
  };
}

// ───────────── Pure Function Tests ─────────────

test("getDepreciationFactor returns 0.4 for 20+ wears", () => {
  assert.equal(getDepreciationFactor(20), 0.4);
  assert.equal(getDepreciationFactor(100), 0.4);
});

test("getDepreciationFactor returns 0.5 for 6-19 wears", () => {
  assert.equal(getDepreciationFactor(6), 0.5);
  assert.equal(getDepreciationFactor(19), 0.5);
});

test("getDepreciationFactor returns 0.6 for 1-5 wears", () => {
  assert.equal(getDepreciationFactor(1), 0.6);
  assert.equal(getDepreciationFactor(5), 0.6);
});

test("getDepreciationFactor returns 0.7 for 0 wears", () => {
  assert.equal(getDepreciationFactor(0), 0.7);
});

test("computeEstimatedPrice applies correct factor for 20+ wears", () => {
  // 100 * 0.4 = 40
  assert.equal(computeEstimatedPrice(100, 25), 40);
});

test("computeEstimatedPrice applies correct factor for 6-19 wears", () => {
  // 100 * 0.5 = 50
  assert.equal(computeEstimatedPrice(100, 10), 50);
});

test("computeEstimatedPrice applies correct factor for 1-5 wears", () => {
  // 100 * 0.6 = 60
  assert.equal(computeEstimatedPrice(100, 3), 60);
});

test("computeEstimatedPrice applies correct factor for 0 wears", () => {
  // 100 * 0.7 = 70
  assert.equal(computeEstimatedPrice(100, 0), 70);
});

test("computeEstimatedPrice defaults to 10 when purchase_price is null", () => {
  assert.equal(computeEstimatedPrice(null, 5), 10);
});

test("computeEstimatedPrice defaults to 10 when purchase_price is 0", () => {
  assert.equal(computeEstimatedPrice(0, 5), 10);
});

test("computeEstimatedPrice minimum is 1 (no zero-price estimates)", () => {
  // 1 * 0.4 = 0.4 => rounds to 0, but minimum is 1
  assert.equal(computeEstimatedPrice(1, 25), 1);
});

test("computeEstimatedPrice rounds correctly", () => {
  // 55 * 0.6 = 33
  assert.equal(computeEstimatedPrice(55, 3), 33);
  // 47 * 0.5 = 23.5 => rounds to 24
  assert.equal(computeEstimatedPrice(47, 10), 24);
});

// ───────────── identifyResaleCandidates Tests ─────────────

test("identifyResaleCandidates returns candidates with correct shape", async () => {
  const oldDate = new Date(Date.now() - 200 * 24 * 60 * 60 * 1000).toISOString();
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("FROM app_public.items"),
        result: {
          rows: [
            {
              id: "item-1",
              name: "Blue Shirt",
              category: "Tops",
              photo_url: "http://img.com/1.jpg",
              brand: "Nike",
              purchase_price: "80",
              currency: "GBP",
              wear_count: "3",
              last_worn_date: oldDate,
              created_at: oldDate,
              raw_price: "80",
              wears: "3",
            },
          ],
        },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const candidates = await service.identifyResaleCandidates(testAuth);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].itemId, "item-1");
  assert.equal(candidates[0].name, "Blue Shirt");
  assert.equal(candidates[0].estimatedPrice, 48); // 80 * 0.6 = 48
  assert.equal(candidates[0].estimatedCurrency, "GBP");
  assert.ok(candidates[0].daysSinceLastWorn >= 199);
});

test("identifyResaleCandidates returns empty array when no items are neglected", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      { match: (sql) => sql.includes("FROM app_public.items"), result: { rows: [] } },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const candidates = await service.identifyResaleCandidates(testAuth);
  assert.equal(candidates.length, 0);
});

test("identifyResaleCandidates respects limit parameter", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      { match: (sql) => sql.includes("FROM app_public.items"), result: { rows: [] } },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  await service.identifyResaleCandidates(testAuth, { limit: 5 });
  const limitQuery = pool.client.queries.find((q) => q.sql.includes("LIMIT"));
  assert.ok(limitQuery);
  assert.deepEqual(limitQuery.params, [5]);
});

// ───────────── createPromptBatch Tests ─────────────

test("createPromptBatch inserts records into resale_prompts", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("FROM app_public.profiles"),
        result: { rows: [{ id: testProfileId }] },
      },
      {
        match: (sql) => sql.includes("INSERT INTO"),
        result: {
          rows: [{
            id: "prompt-1",
            profile_id: testProfileId,
            item_id: "item-1",
            estimated_price: "48",
            estimated_currency: "GBP",
            action: null,
            dismissed_until: null,
            created_at: new Date().toISOString(),
          }],
        },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const candidates = [{ itemId: "item-1", estimatedPrice: 48, estimatedCurrency: "GBP" }];
  const prompts = await service.createPromptBatch(testAuth, candidates);
  assert.equal(prompts.length, 1);
  assert.equal(prompts[0].id, "prompt-1");
});

// ───────────── evaluateAndNotify Tests ─────────────

test("evaluateAndNotify calls notificationService when candidates exist", async () => {
  const oldDate = new Date(Date.now() - 200 * 24 * 60 * 60 * 1000).toISOString();
  const notificationService = createMockNotificationService();

  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("FROM app_public.items"),
        result: {
          rows: [{
            id: "item-1", name: "Blue Shirt", category: "Tops",
            photo_url: "http://img.com/1.jpg", brand: "Nike",
            purchase_price: "80", currency: "GBP",
            wear_count: "3", last_worn_date: oldDate, created_at: oldDate,
            raw_price: "80", wears: "3",
          }],
        },
      },
      {
        match: (sql) => sql.includes("FROM app_public.profiles"),
        result: { rows: [{ id: testProfileId }] },
      },
      {
        match: (sql) => sql.includes("INSERT INTO"),
        result: {
          rows: [{
            id: "prompt-1", profile_id: testProfileId, item_id: "item-1",
            estimated_price: "48", estimated_currency: "GBP",
            action: null, dismissed_until: null, created_at: new Date().toISOString(),
          }],
        },
      },
    ],
  });

  const service = createResalePromptService({ pool, notificationService });
  const result = await service.evaluateAndNotify(testAuth);

  assert.equal(result.candidates, 1);
  assert.equal(result.prompted, true);

  // Wait for fire-and-forget notification
  await new Promise((r) => setTimeout(r, 50));
  assert.equal(notificationService.calls.length, 1);
  assert.equal(notificationService.calls[0].notification.title, "Time to declutter?");
  assert.equal(notificationService.calls[0].options.preferenceKey, "resale_prompts");
});

test("evaluateAndNotify does NOT notify when no candidates found", async () => {
  const notificationService = createMockNotificationService();

  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      { match: (sql) => sql.includes("FROM app_public.items"), result: { rows: [] } },
    ],
  });

  const service = createResalePromptService({ pool, notificationService });
  const result = await service.evaluateAndNotify(testAuth);

  assert.equal(result.candidates, 0);
  assert.equal(result.prompted, false);
  assert.equal(notificationService.calls.length, 0);
});

// ───────────── getPendingPrompts Tests ─────────────

test("getPendingPrompts returns only prompts with NULL action from current month", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("FROM app_public.resale_prompts"),
        result: {
          rows: [{
            id: "prompt-1", profile_id: testProfileId, item_id: "item-1",
            estimated_price: "48", estimated_currency: "GBP",
            action: null, dismissed_until: null,
            created_at: new Date().toISOString(),
            item_name: "Blue Shirt", item_photo_url: "http://img.com/1.jpg",
            item_category: "Tops", item_brand: "Nike",
            item_wear_count: "3", item_last_worn_date: null,
            item_created_at: new Date().toISOString(),
          }],
        },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const prompts = await service.getPendingPrompts(testAuth);
  assert.equal(prompts.length, 1);
  assert.equal(prompts[0].id, "prompt-1");
  assert.equal(prompts[0].itemName, "Blue Shirt");
  assert.equal(prompts[0].estimatedPrice, 48);

  // Verify query filters by action IS NULL and current month
  const selectQuery = pool.client.queries.find((q) =>
    q.sql.includes("action IS NULL") && q.sql.includes("DATE_TRUNC")
  );
  assert.ok(selectQuery, "Query should filter by action IS NULL and current month");
});

// ───────────── updatePromptAction Tests ─────────────

test("updatePromptAction sets action and dismissed_until for dismissed prompts", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("UPDATE"),
        result: {
          rows: [{
            id: "prompt-1", profile_id: testProfileId, item_id: "item-1",
            estimated_price: "48", estimated_currency: "GBP",
            action: "dismissed",
            dismissed_until: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0],
            created_at: new Date().toISOString(),
          }],
        },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const result = await service.updatePromptAction(testAuth, "prompt-1", { action: "dismissed" });
  assert.equal(result.action, "dismissed");
  assert.ok(result.dismissedUntil, "dismissed_until should be set");

  // Verify the UPDATE query was called with dismissed_until
  const updateQuery = pool.client.queries.find((q) => q.sql.includes("UPDATE"));
  assert.ok(updateQuery);
  assert.equal(updateQuery.params[0], "dismissed");
  assert.ok(updateQuery.params[1], "dismissed_until param should be set");
});

test("updatePromptAction sets only action for accepted prompts (no dismissed_until)", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("UPDATE"),
        result: {
          rows: [{
            id: "prompt-1", profile_id: testProfileId, item_id: "item-1",
            estimated_price: "48", estimated_currency: "GBP",
            action: "accepted", dismissed_until: null,
            created_at: new Date().toISOString(),
          }],
        },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const result = await service.updatePromptAction(testAuth, "prompt-1", { action: "accepted" });
  assert.equal(result.action, "accepted");
  assert.equal(result.dismissedUntil, null);

  const updateQuery = pool.client.queries.find((q) => q.sql.includes("UPDATE"));
  assert.ok(updateQuery);
  assert.equal(updateQuery.params[0], "accepted");
  assert.equal(updateQuery.params[1], null);
});

test("updatePromptAction throws 400 for invalid action", async () => {
  const pool = createMockPool();
  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  await assert.rejects(
    () => service.updatePromptAction(testAuth, "prompt-1", { action: "invalid" }),
    (err) => {
      assert.equal(err.statusCode, 400);
      return true;
    }
  );
});

// ───────────── getPendingCount Tests ─────────────

test("getPendingCount returns correct count", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("COUNT(*)"),
        result: { rows: [{ count: "3" }] },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const count = await service.getPendingCount(testAuth);
  assert.equal(count, 3);
});

test("getPendingCount returns 0 when no pending prompts", async () => {
  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("COUNT(*)"),
        result: { rows: [{ count: "0" }] },
      },
    ],
  });

  const service = createResalePromptService({
    pool,
    notificationService: createMockNotificationService(),
  });

  const count = await service.getPendingCount(testAuth);
  assert.equal(count, 0);
});

// ───────────── Notification Body Tests ─────────────

test("evaluateAndNotify sends correct notification body for single item", async () => {
  const oldDate = new Date(Date.now() - 200 * 24 * 60 * 60 * 1000).toISOString();
  const notificationService = createMockNotificationService();

  const pool = createMockPool({
    connectResults: [
      { match: "set_config", result: { rows: [] } },
      {
        match: (sql) => sql.includes("FROM app_public.items"),
        result: {
          rows: [{
            id: "item-1", name: "Shirt", category: "Tops",
            photo_url: "", brand: "", purchase_price: null, currency: "GBP",
            wear_count: "0", last_worn_date: null, created_at: oldDate,
            raw_price: "0", wears: "0",
          }],
        },
      },
      {
        match: (sql) => sql.includes("FROM app_public.profiles"),
        result: { rows: [{ id: testProfileId }] },
      },
      {
        match: (sql) => sql.includes("INSERT INTO"),
        result: {
          rows: [{
            id: "p-1", profile_id: testProfileId, item_id: "item-1",
            estimated_price: "10", estimated_currency: "GBP",
            action: null, dismissed_until: null, created_at: new Date().toISOString(),
          }],
        },
      },
    ],
  });

  const service = createResalePromptService({ pool, notificationService });
  await service.evaluateAndNotify(testAuth);

  await new Promise((r) => setTimeout(r, 50));
  assert.equal(notificationService.calls.length, 1);
  assert.ok(
    notificationService.calls[0].notification.body.includes("1 item"),
    "Body should say '1 item' (singular)"
  );
  assert.ok(
    !notificationService.calls[0].notification.body.includes("1 items"),
    "Body should not say '1 items'"
  );
});
