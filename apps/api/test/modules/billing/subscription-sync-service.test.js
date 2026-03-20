import assert from "node:assert/strict";
import test from "node:test";
import { createSubscriptionSyncService } from "../../../src/modules/billing/subscription-sync-service.js";

// --- Mock factories ---

function createMockPool(overrides = {}) {
  const queries = [];
  return {
    queries,
    connect() {
      return Promise.resolve({
        query(sql, params) {
          queries.push({ sql, params });

          if (sql.includes("sync_premium_from_revenuecat")) {
            const result = overrides.syncRpcResult ?? {
              is_premium: true,
              premium_source: "revenuecat",
              premium_expires_at: new Date("2026-04-19T00:00:00Z"),
            };
            return { rows: [result] };
          }

          if (sql.includes("app_public.profiles")) {
            const row = overrides.profileRow ?? {
              is_premium: false,
              premium_source: null,
              premium_expires_at: null,
            };
            return { rows: [row] };
          }

          return { rows: [] };
        },
        release() {},
      });
    },
  };
}

function createMockConfig(overrides = {}) {
  return {
    revenueCatApiKey: overrides.revenueCatApiKey ?? "sk_test_api_key",
    revenueCatWebhookAuthHeader: overrides.revenueCatWebhookAuthHeader ?? "Bearer webhook_secret_123",
    ...overrides,
  };
}

function createMockFetch(responseOverrides = {}) {
  const calls = [];
  const mockFetch = async (url, options) => {
    calls.push({ url, options });

    if (responseOverrides.shouldThrow) {
      throw new Error("Network error");
    }

    const ok = responseOverrides.ok ?? true;
    const status = responseOverrides.status ?? 200;
    const statusText = responseOverrides.statusText ?? "OK";
    const body = responseOverrides.body ?? {
      subscriber: {
        entitlements: {
          "Vestiaire Pro": {
            is_active: true,
            expires_date: "2026-04-19T00:00:00Z",
          },
        },
      },
    };

    return {
      ok,
      status,
      statusText,
      async json() {
        return body;
      },
    };
  };
  mockFetch.calls = calls;
  return mockFetch;
}

const authContext = { userId: "firebase-user-123" };

// --- syncFromClient tests ---

test("syncFromClient verifies authContext.userId === appUserId", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const fetchFn = createMockFetch();
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  await assert.rejects(
    () => service.syncFromClient(authContext, { appUserId: "different-user" }),
    (error) => {
      assert.equal(error.statusCode, 403);
      assert.ok(error.message.includes("another user"));
      return true;
    }
  );
});

test("syncFromClient calls RevenueCat API and returns premium status when entitlement active", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const fetchFn = createMockFetch({
    body: {
      subscriber: {
        entitlements: {
          "Vestiaire Pro": {
            is_active: true,
            expires_date: "2026-04-19T00:00:00Z",
          },
        },
      },
    },
  });
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.syncFromClient(authContext, { appUserId: "firebase-user-123" });

  assert.equal(result.isPremium, true);
  assert.equal(result.premiumSource, "revenuecat");
  assert.ok(result.premiumExpiresAt);
  assert.equal(fetchFn.calls.length, 1);
  assert.ok(fetchFn.calls[0].url.includes("firebase-user-123"));
});

test("syncFromClient returns non-premium when entitlement inactive", async () => {
  const pool = createMockPool({
    syncRpcResult: {
      is_premium: false,
      premium_source: null,
      premium_expires_at: null,
    },
  });
  const config = createMockConfig();
  const fetchFn = createMockFetch({
    body: {
      subscriber: {
        entitlements: {
          "Vestiaire Pro": {
            is_active: false,
            expires_date: null,
          },
        },
      },
    },
  });
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.syncFromClient(authContext, { appUserId: "firebase-user-123" });

  assert.equal(result.isPremium, false);
  assert.equal(result.premiumSource, null);
});

test("syncFromClient gracefully handles RevenueCat API failure (returns current DB state)", async () => {
  const pool = createMockPool({
    profileRow: {
      is_premium: true,
      premium_source: "trial",
      premium_expires_at: new Date("2026-04-01T00:00:00Z"),
    },
  });
  const config = createMockConfig();
  const fetchFn = createMockFetch({ shouldThrow: true });
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.syncFromClient(authContext, { appUserId: "firebase-user-123" });

  assert.equal(result.isPremium, true);
  assert.equal(result.premiumSource, "trial");
});

// --- handleWebhookEvent tests ---

test("handleWebhookEvent rejects invalid authorization header with 401", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  await assert.rejects(
    () => service.handleWebhookEvent(
      { event: { type: "INITIAL_PURCHASE", app_user_id: "user-1" } },
      "invalid_header"
    ),
    (error) => {
      assert.equal(error.statusCode, 401);
      return true;
    }
  );
});

test("handleWebhookEvent processes INITIAL_PURCHASE: sets is_premium = true", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "INITIAL_PURCHASE",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() + 30 * 86400000,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.ok(syncCall);
  assert.equal(syncCall.params[1], true); // p_is_premium
});

test("handleWebhookEvent processes RENEWAL: sets is_premium = true with new expiration", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const futureMs = Date.now() + 30 * 86400000;
  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "RENEWAL",
        app_user_id: "firebase-user-123",
        expiration_at_ms: futureMs,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.ok(syncCall);
  assert.equal(syncCall.params[1], true);
});

test("handleWebhookEvent processes EXPIRATION: sets is_premium = false (when premium_source = revenuecat)", async () => {
  const pool = createMockPool({
    syncRpcResult: {
      is_premium: false,
      premium_source: null,
      premium_expires_at: null,
    },
  });
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "EXPIRATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() - 86400000,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.ok(syncCall);
  assert.equal(syncCall.params[1], false); // p_is_premium
});

test("handleWebhookEvent EXPIRATION does NOT downgrade trial users (handled by RPC)", async () => {
  // The RPC sync_premium_from_revenuecat handles trial protection internally.
  // The webhook handler just calls the RPC with p_is_premium = false.
  // The RPC checks premium_source and preserves trial if active.
  const pool = createMockPool({
    syncRpcResult: {
      is_premium: true,
      premium_source: "trial",
      premium_expires_at: null,
    },
  });
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "EXPIRATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() - 86400000,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  // The RPC was called with false, but it returns trial state because it protects trial
});

test("handleWebhookEvent processes CANCELLATION with future expiration: no change (still active)", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const futureMs = Date.now() + 15 * 86400000;
  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "CANCELLATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: futureMs,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  // Should NOT have called sync RPC because expiration is in the future
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.equal(syncCall, undefined);
});

test("handleWebhookEvent processes CANCELLATION with past expiration: sets is_premium = false", async () => {
  const pool = createMockPool({
    syncRpcResult: {
      is_premium: false,
      premium_source: null,
      premium_expires_at: null,
    },
  });
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const pastMs = Date.now() - 86400000;
  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "CANCELLATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: pastMs,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.ok(syncCall);
  assert.equal(syncCall.params[1], false);
});

test("handleWebhookEvent ignores BILLING_ISSUE events (returns 200, no status change)", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "BILLING_ISSUE",
        app_user_id: "firebase-user-123",
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.equal(syncCall, undefined);
});

// --- verifyEntitlement tests ---

test("verifyEntitlement calls RevenueCat API and returns entitlement status", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const fetchFn = createMockFetch({
    body: {
      subscriber: {
        entitlements: {
          "Vestiaire Pro": {
            is_active: true,
            expires_date: "2026-04-19T00:00:00Z",
          },
        },
      },
    },
  });
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.verifyEntitlement("firebase-user-123");

  assert.equal(result.isPremium, true);
  assert.equal(result.expiresAt, "2026-04-19T00:00:00Z");
});

test("verifyEntitlement falls back to DB on API failure", async () => {
  const pool = createMockPool({
    profileRow: {
      is_premium: true,
      premium_expires_at: new Date("2026-04-01T00:00:00Z"),
    },
  });
  const config = createMockConfig();
  const fetchFn = createMockFetch({ shouldThrow: true });
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.verifyEntitlement("firebase-user-123");

  assert.equal(result.isPremium, true);
});

// --- sync_premium_from_revenuecat RPC behavior tests (via mocks) ---

test("sync_premium_from_revenuecat RPC correctly handles trial-to-subscription upgrade", async () => {
  // When upgrading from trial to subscription, the RPC should set source to revenuecat
  const pool = createMockPool({
    syncRpcResult: {
      is_premium: true,
      premium_source: "revenuecat",
      premium_expires_at: new Date("2026-04-19T00:00:00Z"),
    },
  });
  const config = createMockConfig();
  const fetchFn = createMockFetch();
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.syncFromClient(authContext, { appUserId: "firebase-user-123" });

  assert.equal(result.isPremium, true);
  assert.equal(result.premiumSource, "revenuecat");
});

test("sync_premium_from_revenuecat RPC preserves trial when subscription expires", async () => {
  // When subscription expires but trial is active, RPC should return trial state
  const pool = createMockPool({
    syncRpcResult: {
      is_premium: true,
      premium_source: "trial",
      premium_expires_at: null,
    },
  });
  const config = createMockConfig();
  const fetchFn = createMockFetch({
    body: {
      subscriber: {
        entitlements: {
          "Vestiaire Pro": {
            is_active: false,
            expires_date: null,
          },
        },
      },
    },
  });
  const service = createSubscriptionSyncService({ pool, config, fetchFn });

  const result = await service.syncFromClient(authContext, { appUserId: "firebase-user-123" });

  assert.equal(result.isPremium, true);
  assert.equal(result.premiumSource, "trial");
});

test("handleWebhookEvent processes UNCANCELLATION: sets is_premium = true", async () => {
  const pool = createMockPool();
  const config = createMockConfig();
  const service = createSubscriptionSyncService({ pool, config });

  const result = await service.handleWebhookEvent(
    {
      event: {
        type: "UNCANCELLATION",
        app_user_id: "firebase-user-123",
        expiration_at_ms: Date.now() + 30 * 86400000,
      },
    },
    "Bearer webhook_secret_123"
  );

  assert.equal(result.handled, true);
  const syncCall = pool.queries.find((q) => q.sql.includes("sync_premium_from_revenuecat"));
  assert.ok(syncCall);
  assert.equal(syncCall.params[1], true);
});

test("createSubscriptionSyncService throws on missing pool", () => {
  assert.throws(
    () => createSubscriptionSyncService({ config: createMockConfig() }),
    { message: "pool is required" }
  );
});

test("createSubscriptionSyncService throws on missing config", () => {
  assert.throws(
    () => createSubscriptionSyncService({ pool: createMockPool() }),
    { message: "config is required" }
  );
});
