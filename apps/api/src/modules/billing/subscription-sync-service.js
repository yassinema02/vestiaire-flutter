/**
 * Subscription sync service for RevenueCat integration.
 *
 * Handles:
 * - Client-initiated subscription sync (POST /v1/subscription/sync)
 * - RevenueCat webhook events (POST /v1/webhooks/revenuecat)
 * - On-demand entitlement verification
 *
 * Uses the sync_premium_from_revenuecat RPC to persist subscription state.
 * Follows the factory pattern used by all API services.
 */

const REVENUECAT_API_BASE = "https://api.revenuecat.com/v1";
const PRO_ENTITLEMENT_ID = "Vestiaire Pro";

/**
 * Fetch subscriber data from RevenueCat REST API v1.
 *
 * @param {string} appUserId - The RevenueCat app_user_id (Firebase UID).
 * @param {string} apiKey - RevenueCat REST API secret key.
 * @returns {Promise<object|null>} Subscriber data or null on failure.
 */
async function fetchSubscriber(appUserId, apiKey) {
  const url = `${REVENUECAT_API_BASE}/subscribers/${encodeURIComponent(appUserId)}`;

  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`RevenueCat API error: ${response.status} ${response.statusText}`);
  }

  const data = await response.json();
  return data.subscriber;
}

/**
 * Parse entitlement status from subscriber data.
 *
 * @param {object} subscriber - RevenueCat subscriber object.
 * @returns {{ isActive: boolean, expiresDate: string|null }}
 */
function parseEntitlement(subscriber) {
  const entitlement = subscriber?.entitlements?.[PRO_ENTITLEMENT_ID];

  if (!entitlement || !entitlement.is_active) {
    return { isActive: false, expiresDate: null };
  }

  return {
    isActive: true,
    expiresDate: entitlement.expires_date || null,
  };
}

/**
 * Call the sync_premium_from_revenuecat RPC.
 *
 * @param {import('pg').Pool} pool
 * @param {string} firebaseUid
 * @param {boolean} isPremium
 * @param {Date|null} expiresAt
 * @returns {Promise<object>} { isPremium, premiumSource, premiumExpiresAt }
 */
async function callSyncRpc(pool, firebaseUid, isPremium, expiresAt) {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "SELECT * FROM app_public.sync_premium_from_revenuecat($1, $2, $3)",
      [firebaseUid, isPremium, expiresAt]
    );

    const row = result.rows[0];
    if (!row) {
      throw { statusCode: 404, message: "Profile not found" };
    }

    return {
      isPremium: row.is_premium,
      premiumSource: row.premium_source,
      premiumExpiresAt: row.premium_expires_at ? new Date(row.premium_expires_at).toISOString() : null,
    };
  } finally {
    client.release();
  }
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool
 * @param {object} options.config
 * @param {string} options.config.revenueCatApiKey
 * @param {string} options.config.revenueCatWebhookAuthHeader
 * @param {function} [options.fetchFn] - Optional fetch override for testing.
 */
export function createSubscriptionSyncService({ pool, config, fetchFn }) {
  if (!pool) throw new TypeError("pool is required");
  if (!config) throw new TypeError("config is required");

  // Allow injecting a custom fetch for testing
  const _fetch = fetchFn || globalThis.fetch;

  /**
   * Fetch subscriber from RevenueCat, using injected fetch if provided.
   */
  async function _fetchSubscriber(appUserId) {
    const url = `${REVENUECAT_API_BASE}/subscribers/${encodeURIComponent(appUserId)}`;

    const response = await _fetch(url, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${config.revenueCatApiKey}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      throw new Error(`RevenueCat API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    return data.subscriber;
  }

  return {
    /**
     * Sync subscription from client request.
     * Verifies the user owns the appUserId, calls RevenueCat API, updates DB.
     *
     * @param {object} authContext - { userId }
     * @param {object} params - { appUserId }
     * @returns {Promise<object>} { isPremium, premiumSource, premiumExpiresAt }
     */
    async syncFromClient(authContext, { appUserId }) {
      // Verify user can only sync their own subscription
      if (authContext.userId !== appUserId) {
        throw { statusCode: 403, message: "Cannot sync subscription for another user" };
      }

      try {
        const subscriber = await _fetchSubscriber(appUserId);
        const { isActive, expiresDate } = parseEntitlement(subscriber);

        const expiresAt = isActive && expiresDate ? new Date(expiresDate) : null;
        return await callSyncRpc(pool, appUserId, isActive, expiresAt);
      } catch (error) {
        // Graceful degradation: if RevenueCat API fails, return current DB state
        if (error?.statusCode) throw error;

        console.error("[subscription-sync] RevenueCat API error:", error.message ?? error);

        // Fall back to current DB state
        const client = await pool.connect();
        try {
          const result = await client.query(
            "SELECT is_premium, premium_source, premium_expires_at FROM app_public.profiles WHERE firebase_uid = $1",
            [appUserId]
          );

          const row = result.rows[0];
          if (!row) throw { statusCode: 404, message: "Profile not found" };

          return {
            isPremium: row.is_premium,
            premiumSource: row.premium_source,
            premiumExpiresAt: row.premium_expires_at ? new Date(row.premium_expires_at).toISOString() : null,
          };
        } finally {
          client.release();
        }
      }
    },

    /**
     * Handle a RevenueCat webhook event.
     *
     * @param {object} webhookBody - The full webhook JSON body.
     * @param {string} authorizationHeader - The Authorization header value.
     * @returns {Promise<object>} { handled: true }
     */
    async handleWebhookEvent(webhookBody, authorizationHeader) {
      // Verify webhook authorization
      if (authorizationHeader !== config.revenueCatWebhookAuthHeader) {
        throw { statusCode: 401, message: "Invalid webhook authorization" };
      }

      const event = webhookBody?.event;
      if (!event) {
        return { handled: true };
      }

      const eventType = event.type;
      const appUserId = event.app_user_id;
      const expirationAtMs = event.expiration_at_ms;

      if (!appUserId) {
        console.error("[subscription-sync] Webhook missing app_user_id");
        return { handled: true };
      }

      // Grant premium events
      const grantTypes = ["INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "NON_RENEWING_PURCHASE"];
      if (grantTypes.includes(eventType)) {
        const expiresAt = expirationAtMs ? new Date(expirationAtMs) : null;
        await callSyncRpc(pool, appUserId, true, expiresAt);
        return { handled: true };
      }

      // Expiration event -- revoke premium
      if (eventType === "EXPIRATION") {
        await callSyncRpc(pool, appUserId, false, null);
        return { handled: true };
      }

      // Cancellation -- only revoke if expiration is in the past
      if (eventType === "CANCELLATION") {
        if (expirationAtMs && expirationAtMs < Date.now()) {
          await callSyncRpc(pool, appUserId, false, null);
        }
        // If expiration is in the future, entitlement is still active until then
        return { handled: true };
      }

      // All other events (BILLING_ISSUE, PRODUCT_CHANGE, etc.) -- no premium change
      console.log(`[subscription-sync] Webhook event ${eventType} for ${appUserId} -- no premium change`);
      return { handled: true };
    },

    /**
     * Verify entitlement for any user (server-side on-demand check).
     *
     * @param {string} firebaseUid
     * @returns {Promise<object>} { isPremium, expiresAt }
     */
    async verifyEntitlement(firebaseUid) {
      try {
        const subscriber = await _fetchSubscriber(firebaseUid);
        const { isActive, expiresDate } = parseEntitlement(subscriber);

        return {
          isPremium: isActive,
          expiresAt: expiresDate || null,
        };
      } catch (error) {
        console.error("[subscription-sync] RevenueCat verification error:", error.message ?? error);

        // Fall back to DB
        const client = await pool.connect();
        try {
          const result = await client.query(
            "SELECT is_premium, premium_expires_at FROM app_public.profiles WHERE firebase_uid = $1",
            [firebaseUid]
          );

          const row = result.rows[0];
          if (!row) return { isPremium: false, expiresAt: null };

          return {
            isPremium: row.is_premium,
            expiresAt: row.premium_expires_at ? new Date(row.premium_expires_at).toISOString() : null,
          };
        } finally {
          client.release();
        }
      }
    },
  };
}
