# Story 7.1: Premium Subscription Purchase

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Free User,
I want to upgrade to Premium using my device's native payment system,
so that I can access unlimited AI features and advanced analytics.

## Acceptance Criteria

1. Given I am a free-tier user on the Profile tab, when I tap "Vestiaire Pro" (the existing subscription tile), then the app navigates to the SubscriptionScreen where I see my current plan status (Free), a "View Plans" button that presents the RevenueCat paywall, and a "Restore Purchases" option. (FR-OUT-10, PRD SaaS Subscription)

2. Given I am viewing the RevenueCat paywall, when I select the £4.99/month Premium plan and complete the native App Store / Play Store purchase flow, then RevenueCat processes the in-app purchase (IAP), the `purchases_flutter` SDK's `CustomerInfo` listener fires with an active "Vestiaire Pro" entitlement, the mobile client immediately reflects the Pro status in the UI (SubscriptionScreen, ProfileScreen), and `is_premium` updates server-side without requiring an app restart. (FR-OUT-10, PRD SaaS Subscription)

3. Given a purchase succeeds on the client, when the mobile app receives an updated `CustomerInfo` from RevenueCat confirming the "Vestiaire Pro" entitlement is active, then the app calls `POST /v1/subscription/sync` with the RevenueCat `app_user_id` and the entitlement status. The API verifies the entitlement via the RevenueCat REST API v1 (`GET /v1/subscribers/{app_user_id}`), and if the "Vestiaire Pro" entitlement is active, sets `profiles.is_premium = true`, `profiles.premium_source = 'revenuecat'`, and `profiles.premium_expires_at` to the entitlement's `expires_date`. The API returns `{ isPremium: true, premiumSource: "revenuecat", premiumExpiresAt: "<ISO 8601>" }`. (Architecture: server-side entitlement enforcement)

4. Given RevenueCat sends a webhook event to `POST /v1/webhooks/revenuecat`, when the event type is `INITIAL_PURCHASE`, `RENEWAL`, or `UNCANCELLATION` for a subscription product, then the API authenticates the webhook using the shared authorization header configured in RevenueCat dashboard, looks up the profile by `app_user_id` (which is the Firebase UID set during `Purchases.logIn`), and sets `profiles.is_premium = true`, `profiles.premium_source = 'revenuecat'`, `profiles.premium_expires_at = event.expiration_at_ms` (converted to timestamptz). Returns HTTP 200. (Architecture: RevenueCat acts as subscription state source; Cloud Run persists internal entitlement view)

5. Given RevenueCat sends a webhook event to `POST /v1/webhooks/revenuecat`, when the event type is `EXPIRATION` or `CANCELLATION` with `expiration_at_ms` in the past, then the API sets `profiles.is_premium = false` (only if `premium_source = 'revenuecat'` -- do NOT downgrade trial-granted premium), clears `premium_expires_at`, and returns HTTP 200. If `premium_source = 'trial'`, the webhook is ignored for the downgrade (trial expiry is handled by `check_trial_expiry` RPC from Story 6.5). (Architecture: server authority for sensitive rules)

6. Given a user has an active premium trial from the Closet Safari challenge (`is_premium = true`, `premium_source = 'trial'`), when the user also purchases a RevenueCat subscription, then the API sets `premium_source = 'revenuecat'` and `premium_expires_at` to the subscription expiration. The `premium_trial_expires_at` column from Story 6.5 is preserved but `premium_source` now reflects the stronger entitlement. If the paid subscription later expires, the user falls back to trial status if `premium_trial_expires_at` is still in the future. (FR-ONB-04 compatibility)

7. Given the "Go Premium" CTA buttons exist in the `UsageLimitCard` (Story 4.5) and throughout the app, when the user taps any "Go Premium" / "Upgrade" CTA, then the app calls `subscriptionService.presentPaywallIfNeeded()` which presents the RevenueCat paywall only if the user does not already have the "Vestiaire Pro" entitlement. After the paywall closes (purchase or dismiss), the UI refreshes to reflect any status change. (FR-OUT-09, FR-OUT-10)

8. Given I am a premium user (either via subscription or trial), when I view the SubscriptionScreen, then I see my plan status ("Vestiaire Pro"), plan type (Monthly/Yearly), renewal/expiration date, and a "Manage Subscription" button that opens the RevenueCat Customer Center. If my premium is from a trial, I see "Premium Trial" with the expiration date and a "Subscribe to keep Premium" CTA. (PRD SaaS Subscription)

9. Given the mobile app launches or the user signs in, when `SubscriptionService.configure()` runs at startup, then the service calls `Purchases.logIn(firebaseUid)` to associate the RevenueCat anonymous user with the authenticated Firebase UID. This ensures webhook `app_user_id` matches the `profiles.firebase_uid` for server-side lookups. If already logged in with the same UID, `logIn` is a no-op. (Architecture: RevenueCat integration)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (594 API tests, 1046 Flutter tests) and new tests cover: migration 021 (premium_source, premium_expires_at columns, sync_premium_from_revenuecat RPC), subscription-sync-service unit tests, webhook endpoint authentication and event handling, POST /v1/subscription/sync endpoint, mobile SubscriptionSyncService, updated UsageLimitCard CTA wiring, SubscriptionScreen updates, and RevenueCat logIn integration.

## Tasks / Subtasks

- [x] Task 1: Database -- Create migration 021 for premium source tracking columns (AC: 3, 4, 5, 6)
  - [x] 1.1: Create `infra/sql/migrations/021_premium_subscription.sql`. Add columns to `app_public.profiles`: `premium_source TEXT CHECK (premium_source IN ('trial', 'revenuecat'))` (nullable, NULL means not premium), `premium_expires_at TIMESTAMPTZ` (nullable, subscription expiration from RevenueCat). Back-fill existing premium trial users: `UPDATE app_public.profiles SET premium_source = 'trial' WHERE is_premium = true AND premium_trial_expires_at IS NOT NULL`.
  - [x] 1.2: Create RPC `app_public.sync_premium_from_revenuecat(p_firebase_uid TEXT, p_is_premium BOOLEAN, p_expires_at TIMESTAMPTZ)` in PL/pgSQL. Logic: (a) Look up profile by `firebase_uid = p_firebase_uid`. (b) If `p_is_premium = true`: set `is_premium = true`, `premium_source = 'revenuecat'`, `premium_expires_at = p_expires_at`. (c) If `p_is_premium = false`: only downgrade if `premium_source = 'revenuecat'` (do NOT downgrade trial-granted premium). If downgrading: set `is_premium = false`, `premium_source = NULL`, `premium_expires_at = NULL`. If `premium_source = 'trial'` and `premium_trial_expires_at > NOW()`: leave `is_premium = true` (trial still active). Returns `TABLE(is_premium BOOLEAN, premium_source TEXT, premium_expires_at TIMESTAMPTZ)`. SECURITY DEFINER.
  - [x] 1.3: Update `check_trial_expiry` RPC (from migration 020) to also set `premium_source = NULL` when it expires a trial: `UPDATE SET is_premium = false, premium_trial_expires_at = NULL, premium_source = NULL WHERE id = p_profile_id AND premium_source = 'trial'`. Use `CREATE OR REPLACE FUNCTION` to update the existing function.
  - [x] 1.4: Add index: `CREATE INDEX idx_profiles_premium_source ON app_public.profiles(premium_source) WHERE premium_source IS NOT NULL`.

- [x] Task 2: API -- Create subscription sync service (AC: 3, 4, 5, 6)
  - [x] 2.1: Create `apps/api/src/modules/billing/subscription-sync-service.js` with `createSubscriptionSyncService({ pool, config })`. Follow the factory pattern. The `config` object provides `revenueCatApiKey` (RevenueCat REST API v1 secret key) and `revenueCatWebhookAuthHeader` (shared authorization header for webhook verification).
  - [x] 2.2: Implement `async syncFromClient(authContext, { appUserId })` method. Steps: (a) Verify `authContext.userId === appUserId` (user can only sync their own subscription). (b) Call RevenueCat REST API: `GET https://api.revenuecat.com/v1/subscribers/${appUserId}` with header `Authorization: Bearer ${config.revenueCatApiKey}`, header `Content-Type: application/json`. (c) Parse response: check `subscriber.entitlements["Vestiaire Pro"]`. (d) If entitlement is active (`is_active: true`): extract `expires_date`, call `sync_premium_from_revenuecat(authContext.userId, true, expires_date)`. (e) If entitlement is not active or missing: call `sync_premium_from_revenuecat(authContext.userId, false, null)`. (f) Return `{ isPremium, premiumSource, premiumExpiresAt }`.
  - [x] 2.3: Implement `async handleWebhookEvent(event, authorizationHeader)` method. Steps: (a) Verify `authorizationHeader === config.revenueCatWebhookAuthHeader`. If mismatch, throw `{ statusCode: 401, message: "Invalid webhook authorization" }`. (b) Extract `event.event.type`, `event.event.app_user_id`, `event.event.expiration_at_ms`. (c) For types `INITIAL_PURCHASE`, `RENEWAL`, `UNCANCELLATION`, `NON_RENEWING_PURCHASE`: call `sync_premium_from_revenuecat(app_user_id, true, new Date(expiration_at_ms))`. (d) For types `EXPIRATION`, `CANCELLATION` (check `expiration_at_ms < Date.now()`): call `sync_premium_from_revenuecat(app_user_id, false, null)`. (e) For `CANCELLATION` where `expiration_at_ms` is in the future (user cancelled but billing period active): do nothing (entitlement still active until expiration). (f) For all other event types (`BILLING_ISSUE`, `PRODUCT_CHANGE`, etc.): log and return 200 (no premium status change). (g) Return `{ handled: true }`.
  - [x] 2.4: Implement `async verifyEntitlement(firebaseUid)` method (for on-demand server-side verification). Calls RevenueCat REST API same as 2.2 but accepts any `firebaseUid`. This is used when the server needs to double-check entitlement status (e.g., after a webhook failure or for premium-gated endpoints that want extra verification). Returns `{ isPremium, expiresAt }`.
  - [x] 2.5: Use `node-fetch` or the built-in `fetch` (Node 18+) for HTTP calls to RevenueCat API. Do NOT add axios or other HTTP libraries. Wrap all RevenueCat API calls in try/catch with logging -- RevenueCat API failures should NOT block the user (graceful degradation: fall back to current `is_premium` value in DB).

- [x] Task 3: API -- Add subscription sync and webhook endpoints to main.js (AC: 3, 4, 5, 9)
  - [x] 3.1: Add config keys to `apps/api/src/config.js`: `revenueCatApiKey` (from env `REVENUECAT_API_KEY`), `revenueCatWebhookAuthHeader` (from env `REVENUECAT_WEBHOOK_AUTH_HEADER`). Both default to empty string in development.
  - [x] 3.2: In `createRuntime()` in `apps/api/src/main.js`, import `createSubscriptionSyncService` from `./modules/billing/subscription-sync-service.js`. Instantiate: `const subscriptionSyncService = createSubscriptionSyncService({ pool, config })`. Add to the returned runtime object.
  - [x] 3.3: In `handleRequest`, add `subscriptionSyncService` to destructuring.
  - [x] 3.4: Add route `POST /v1/subscription/sync`. Requires authentication. Reads `{ appUserId }` from request body. Calls `subscriptionSyncService.syncFromClient(authContext, { appUserId })`. Returns 200 with result. Place after the gamification endpoints and before `notFound`.
  - [x] 3.5: Add route `POST /v1/webhooks/revenuecat`. Does NOT require Firebase authentication (RevenueCat sends webhooks directly). Reads `authorization` header from request. Reads JSON body as the webhook event. Calls `subscriptionSyncService.handleWebhookEvent(body, authorizationHeader)`. Returns 200 `{ success: true }`. On auth failure returns 401. Place the route BEFORE the auth middleware so it bypasses Firebase token verification. Use a route prefix check: if path starts with `/v1/webhooks/`, skip auth.
  - [x] 3.6: Add the webhook route bypass to the authentication flow. In the existing auth check block, add: `if (url.startsWith('/v1/webhooks/')) { /* skip auth, route handles its own verification */ }`. This allows RevenueCat to POST without a Firebase token.

- [x] Task 4: API -- Update premium check flow to reconcile sources (AC: 5, 6)
  - [x] 4.1: Update `usageLimitService.checkUsageLimit()` in `apps/api/src/modules/outfits/usage-limit-service.js`. Change the profile query to also select `premium_source` and `premium_expires_at`. If `is_premium = true` and `premium_source = 'revenuecat'` and `premium_expires_at < NOW()`: call `sync_premium_from_revenuecat(firebase_uid, false, null)` to lazily expire stale subscription state (belt-and-suspenders with webhooks). This handles edge cases where a webhook was missed.
  - [x] 4.2: Update `analyticsSummaryService` premium check similarly if it reads `is_premium` directly (check current implementation pattern).

- [x] Task 5: Mobile -- Create SubscriptionSyncService for server-side sync (AC: 3, 9)
  - [x] 5.1: Create `apps/mobile/lib/src/core/subscription/subscription_sync_service.dart` with class `SubscriptionSyncService`. Constructor: `SubscriptionSyncService({ required ApiClient apiClient })`.
  - [x] 5.2: Implement `Future<SubscriptionStatus> syncSubscription(String appUserId)` method. Calls `POST /v1/subscription/sync` with body `{ "appUserId": appUserId }`. Parses response into `SubscriptionStatus` model: `{ bool isPremium, String? premiumSource, String? premiumExpiresAt }`.
  - [x] 5.3: Create `apps/mobile/lib/src/core/subscription/models/subscription_status.dart` with `SubscriptionStatus` class. Fields: `bool isPremium`, `String? premiumSource`, `String? premiumExpiresAt`. Factory `fromJson`. Method `toJson`.

- [x] Task 6: Mobile -- Update SubscriptionService to sync with backend after purchase (AC: 2, 3, 9)
  - [x] 6.1: Update `apps/mobile/lib/src/core/subscription/subscription_service.dart`. Add optional `SubscriptionSyncService? syncService` field. Update constructor to accept it. This keeps the class backward-compatible (tests can pass null).
  - [x] 6.2: Add method `Future<void> syncWithBackend(String firebaseUid)`. Calls `syncService?.syncSubscription(firebaseUid)`. Wrapped in try/catch -- sync failure should NOT break the client experience. Log errors via `debugPrint`.
  - [x] 6.3: Update `logIn` method: after `Purchases.logIn(appUserId)`, call `syncWithBackend(appUserId)`. This syncs subscription state on every app launch / sign-in.
  - [x] 6.4: In the `addCustomerInfoUpdateListener` callback pattern, after `CustomerInfo` updates, trigger `syncWithBackend` if the entitlement status changed. This handles real-time purchase events (user buys while app is open).

- [x] Task 7: Mobile -- Wire "Go Premium" CTAs to RevenueCat paywall (AC: 7)
  - [x] 7.1: Update `apps/mobile/lib/src/features/home/widgets/usage_limit_card.dart`. Change the `onUpgrade` callback: instead of a no-op, it should call `subscriptionService.presentPaywallIfNeeded()`. The `UsageLimitCard` needs a new constructor parameter `SubscriptionService? subscriptionService` (nullable for backward compat). If `subscriptionService` is null, use `onUpgrade` callback as before.
  - [x] 7.2: Update `apps/mobile/lib/src/features/home/screens/home_screen.dart`. Pass `subscriptionService` to `UsageLimitCard` from the widget's dependency injection (the `MainShellScreen` already passes `subscriptionService` to `ProfileScreen`, so follow the same pattern to make it available on HomeScreen). Add `SubscriptionService? subscriptionService` to HomeScreen constructor if not already present.
  - [x] 7.3: Update any other "Go Premium" / "Upgrade" buttons found in the app to call `subscriptionService.presentPaywallIfNeeded()`. Search for `onUpgrade` callbacks and TODO comments referencing Story 7.1.

- [x] Task 8: Mobile -- Update SubscriptionScreen for trial vs subscription display (AC: 8)
  - [x] 8.1: Update `apps/mobile/lib/src/features/subscription/screens/subscription_screen.dart`. Add a `SubscriptionSyncService? syncService` constructor parameter. After presenting the paywall and after restore purchases, call `syncService?.syncSubscription(firebaseUid)` to push the entitlement to the backend.
  - [x] 8.2: Enhance the status card to differentiate trial vs paid subscription. If `CustomerInfo` shows the "Vestiaire Pro" entitlement is active, show "Vestiaire Pro" with plan details. If the entitlement is NOT active but the server previously returned `premiumSource = 'trial'`, show "Premium Trial" with expiration info and a "Subscribe to keep Premium" CTA.
  - [x] 8.3: Add an `onSubscriptionChanged` callback (optional) so parent screens can react to subscription changes without rebuilding.

- [x] Task 9: Mobile -- Update app initialization for RevenueCat logIn (AC: 9)
  - [x] 9.1: Update `apps/mobile/lib/main.dart`. After `subscriptionService.configure()`, check if the user is already authenticated (Firebase auth state). If yes, call `subscriptionService.logIn(firebaseUid)` and then `syncWithBackend(firebaseUid)`. This ensures RevenueCat user identity is set on app launch.
  - [x] 9.2: Update the auth state listener (wherever sign-in success is handled). After successful sign-in, call `subscriptionService.logIn(firebaseUid)`. After sign-out, call `subscriptionService.logOut()`. Verify this is already happening or add it.

- [x] Task 10: API -- Unit tests for subscription sync service (AC: 3, 4, 5, 6, 10)
  - [x] 10.1: Create `apps/api/test/modules/billing/subscription-sync-service.test.js`:
    - `syncFromClient` verifies `authContext.userId === appUserId`.
    - `syncFromClient` calls RevenueCat API and returns premium status when entitlement active.
    - `syncFromClient` returns non-premium when entitlement inactive.
    - `syncFromClient` gracefully handles RevenueCat API failure (returns current DB state).
    - `handleWebhookEvent` rejects invalid authorization header with 401.
    - `handleWebhookEvent` processes INITIAL_PURCHASE: sets is_premium = true.
    - `handleWebhookEvent` processes RENEWAL: sets is_premium = true with new expiration.
    - `handleWebhookEvent` processes EXPIRATION: sets is_premium = false (when premium_source = revenuecat).
    - `handleWebhookEvent` EXPIRATION does NOT downgrade trial users (premium_source = trial).
    - `handleWebhookEvent` processes CANCELLATION with future expiration: no change (still active).
    - `handleWebhookEvent` processes CANCELLATION with past expiration: sets is_premium = false.
    - `handleWebhookEvent` ignores BILLING_ISSUE events (returns 200, no status change).
    - `verifyEntitlement` calls RevenueCat API and returns entitlement status.
    - `sync_premium_from_revenuecat` RPC correctly handles trial-to-subscription upgrade.
    - `sync_premium_from_revenuecat` RPC preserves trial when subscription expires.

- [x] Task 11: API -- Integration tests for subscription and webhook endpoints (AC: 3, 4, 5, 10)
  - [x] 11.1: Create `apps/api/test/modules/billing/subscription-endpoints.test.js`:
    - `POST /v1/subscription/sync` returns 200 with premium status after sync.
    - `POST /v1/subscription/sync` returns 401 if unauthenticated.
    - `POST /v1/subscription/sync` returns 403 if appUserId does not match auth user.
    - `POST /v1/webhooks/revenuecat` returns 200 on valid INITIAL_PURCHASE webhook.
    - `POST /v1/webhooks/revenuecat` returns 401 on invalid authorization header.
    - `POST /v1/webhooks/revenuecat` bypasses Firebase auth (no Bearer token needed).
    - `POST /v1/webhooks/revenuecat` EXPIRATION webhook downgrades revenuecat premium user.
    - `POST /v1/webhooks/revenuecat` EXPIRATION webhook does NOT downgrade trial premium user.
    - `POST /v1/webhooks/revenuecat` RENEWAL webhook updates premium_expires_at.
    - Existing premium-gated endpoints (outfit generation, analytics) work correctly after subscription sync.

- [x] Task 12: Mobile -- Unit tests for SubscriptionSyncService (AC: 3, 10)
  - [x] 12.1: Create `apps/mobile/test/core/subscription/subscription_sync_service_test.dart`:
    - `syncSubscription` calls POST /v1/subscription/sync with correct body.
    - `syncSubscription` returns SubscriptionStatus on success.
    - `syncSubscription` handles API error gracefully.
    - `SubscriptionStatus.fromJson` parses all fields correctly.

- [x] Task 13: Mobile -- Unit tests for updated SubscriptionService (AC: 2, 9, 10)
  - [x] 13.1: Create or update `apps/mobile/test/core/subscription/subscription_service_test.dart`:
    - `logIn` calls Purchases.logIn and triggers syncWithBackend.
    - `syncWithBackend` calls syncService.syncSubscription.
    - `syncWithBackend` does not throw when syncService fails.
    - `syncWithBackend` does nothing when syncService is null.
    - All existing SubscriptionService tests continue to pass.

- [x] Task 14: Mobile -- Widget tests for updated UsageLimitCard and HomeScreen (AC: 7, 10)
  - [x] 14.1: Update `apps/mobile/test/features/home/widgets/usage_limit_card_test.dart`:
    - CTA button calls `subscriptionService.presentPaywallIfNeeded()` when tapped (with subscriptionService provided).
    - CTA button calls onUpgrade callback when subscriptionService is null (backward compat).
    - All existing UsageLimitCard tests continue to pass.
  - [x] 14.2: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - Verify UsageLimitCard receives subscriptionService.
    - All existing HomeScreen tests continue to pass.

- [x] Task 15: Mobile -- Widget tests for updated SubscriptionScreen (AC: 8, 10)
  - [x] 15.1: Create or update `apps/mobile/test/features/subscription/screens/subscription_screen_test.dart`:
    - Shows "Free Plan" status for non-premium users.
    - Shows "Vestiaire Pro" status for premium users.
    - Shows plan type and renewal date for active subscribers.
    - "View Plans" button calls presentPaywall.
    - "Manage Subscription" button calls presentCustomerCenter.
    - "Restore Purchases" calls restorePurchases and syncs with backend.
    - Differentiates trial vs paid subscription display.

- [x] Task 16: Regression testing (AC: all)
  - [x] 16.1: Run `flutter analyze` -- zero new issues.
  - [x] 16.2: Run `flutter test` -- all existing 1046+ tests plus new tests pass.
  - [x] 16.3: Run `npm --prefix apps/api test` -- all existing 594+ API tests plus new tests pass.
  - [x] 16.4: Verify existing outfit generation flow still works for free users (usage limits enforced).
  - [x] 16.5: Verify premium users (set via webhook) can generate without limits.
  - [x] 16.6: Verify Closet Safari trial grant still works correctly with `premium_source = 'trial'`.
  - [x] 16.7: Verify trial expiry check (`check_trial_expiry`) still works correctly with new `premium_source` column.
  - [x] 16.8: Verify webhook endpoint is accessible without Firebase auth token.

## Dev Notes

- This story implements the **RevenueCat subscription integration** -- the primary monetization mechanism for the app. It bridges the existing client-side RevenueCat SDK (`purchases_flutter: ^9.13.2`, `purchases_ui_flutter`, `SubscriptionService`, `SubscriptionScreen`) with server-side premium state management (`profiles.is_premium` from Story 4.5, `premium_trial_expires_at` from Story 6.5).
- The primary FRs covered are **FR-OUT-10** (premium users get unlimited AI) and the **PRD SaaS Subscription** requirements (RevenueCat billing, £4.99/month, server-side enforcement).
- **Dual premium sources:** This story introduces `premium_source` to distinguish between trial-granted premium (from Closet Safari, Story 6.5) and subscription-granted premium (from RevenueCat). This prevents a webhook expiration from accidentally revoking a trial, and vice versa.

### Design Decision: Client Sync + Webhook (Belt and Suspenders)

The architecture uses **two complementary mechanisms** for keeping `is_premium` accurate:
1. **Client-initiated sync** (`POST /v1/subscription/sync`): Called after purchase and on app launch. The API verifies against RevenueCat REST API. This provides immediate feedback to the user.
2. **Server-to-server webhook** (`POST /v1/webhooks/revenuecat`): RevenueCat sends events for renewals, expirations, cancellations. This catches state changes when the app is not open.
3. **Lazy verification in premium-gated endpoints**: If `premium_expires_at` is past, lazily downgrade. This catches edge cases where both sync and webhook failed.

This triple-redundancy ensures `is_premium` is always accurate.

### Why NOT Use RevenueCat Customer Info as the Only Source

The architecture mandates "server authority for sensitive rules" and "Cloud Run persists an internal entitlement view for fast authorization checks." Relying solely on RevenueCat API calls for every premium check would add latency and a single point of failure. The `is_premium` column is the fast, local source of truth for the API, synced from RevenueCat.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/021_premium_subscription.sql` (premium_source, premium_expires_at, sync RPC, updated check_trial_expiry)
  - `apps/api/src/modules/billing/subscription-sync-service.js` (RevenueCat sync + webhook handler)
  - `apps/api/test/modules/billing/subscription-sync-service.test.js`
  - `apps/api/test/modules/billing/subscription-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/core/subscription/subscription_sync_service.dart`
  - `apps/mobile/lib/src/core/subscription/models/subscription_status.dart`
  - `apps/mobile/test/core/subscription/subscription_sync_service_test.dart`
  - `apps/mobile/test/core/subscription/subscription_service_test.dart`
  - `apps/mobile/test/features/subscription/screens/subscription_screen_test.dart`
- Modified API files:
  - `apps/api/src/config.js` (add revenueCatApiKey, revenueCatWebhookAuthHeader)
  - `apps/api/src/main.js` (add subscriptionSyncService to runtime, add /v1/subscription/sync and /v1/webhooks/revenuecat routes, webhook auth bypass)
  - `apps/api/src/modules/outfits/usage-limit-service.js` (add lazy subscription expiry check)
- Modified mobile files:
  - `apps/mobile/lib/src/core/subscription/subscription_service.dart` (add syncService, syncWithBackend, logIn sync)
  - `apps/mobile/lib/src/features/subscription/screens/subscription_screen.dart` (add syncService, trial vs subscription display)
  - `apps/mobile/lib/src/features/home/widgets/usage_limit_card.dart` (wire CTA to presentPaywallIfNeeded)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (pass subscriptionService to UsageLimitCard)
  - `apps/mobile/lib/main.dart` (add logIn + sync on launch)
- Module placement per architecture: `api/modules/billing/` (new module), `mobile/features/subscription/`, `mobile/core/subscription/`.

### Technical Requirements

- **New database migration:** `021_premium_subscription.sql` adds `premium_source TEXT` and `premium_expires_at TIMESTAMPTZ` to `profiles`, creates `sync_premium_from_revenuecat` RPC, updates `check_trial_expiry` RPC.
- **RevenueCat REST API v1:** `GET /v1/subscribers/{app_user_id}` with `Authorization: Bearer <secret_api_key>`. Response contains `subscriber.entitlements["Vestiaire Pro"].is_active` and `.expires_date`.
- **RevenueCat webhook authentication:** Authorization header configured in RevenueCat dashboard, verified server-side via string comparison.
- **Webhook event types handled:** `INITIAL_PURCHASE`, `RENEWAL`, `UNCANCELLATION`, `NON_RENEWING_PURCHASE` (grant premium), `EXPIRATION` (revoke premium), `CANCELLATION` (revoke only if expiration is past).
- **Flutter SDK:** `purchases_flutter: ^9.13.2` (already in pubspec.yaml), `purchases_ui_flutter` (already imported). No new dependencies needed.
- **Node.js HTTP:** Use built-in `fetch` (Node 18+) for RevenueCat API calls. No new npm dependencies.

### Architecture Compliance

- **Server authority for subscription state:** `is_premium` in the `profiles` table is the source of truth for all API premium checks. The mobile client does NOT cache or enforce premium status locally -- it reads from `CustomerInfo` for display and syncs to the server.
- **RevenueCat as subscription state source:** RevenueCat manages the billing lifecycle (purchase, renewal, cancellation). The API maintains an "internal entitlement view" (`is_premium`, `premium_source`, `premium_expires_at`) for fast authorization without calling RevenueCat on every request.
- **Client UI shows paywalls; enforcement is server-side:** The mobile app presents the RevenueCat paywall for purchases, but all usage limit checks and feature gating happen in the Cloud Run API.
- **Mobile boundary does not own billing truth:** The `SubscriptionService` and `SubscriptionScreen` handle presentation and RevenueCat SDK interaction. The `SubscriptionSyncService` pushes entitlement state to the server. The API is the authority.
- **Webhook bypasses Firebase auth:** The `/v1/webhooks/revenuecat` route uses its own authorization header verification, not Firebase token verification. This is the correct pattern for server-to-server communication.

### Library / Framework Requirements

- **No new mobile dependencies.** `purchases_flutter: ^9.13.2` and `purchases_ui_flutter` are already in `pubspec.yaml`.
- **No new API dependencies.** Use Node 18+ built-in `fetch` for HTTP calls to RevenueCat.
- **RevenueCat dashboard configuration required** (outside code scope): Create webhook pointing to `{API_BASE_URL}/v1/webhooks/revenuecat`, set authorization header, enable relevant event types.

### File Structure Requirements

- New API module: `apps/api/src/modules/billing/` (create directory). This follows the architecture mapping: "Epic 7 Subscription & Resale -> api/modules/billing".
- New API test directory: `apps/api/test/modules/billing/` (create directory).
- Mobile files go in existing `apps/mobile/lib/src/core/subscription/` and `apps/mobile/lib/src/features/subscription/`.
- Test files mirror source structure.

### Testing Requirements

- **Database migration tests** must verify:
  - `premium_source` and `premium_expires_at` columns added to profiles
  - `sync_premium_from_revenuecat` RPC grants premium correctly
  - `sync_premium_from_revenuecat` RPC revokes only revenuecat-sourced premium
  - `sync_premium_from_revenuecat` RPC preserves trial premium when subscription expires
  - Updated `check_trial_expiry` RPC clears `premium_source` on trial expiry
  - Back-fill sets existing trial users to `premium_source = 'trial'`
- **API service tests** must verify RevenueCat API mock calls, webhook auth, event type handling, trial protection
- **API endpoint tests** must verify route accessibility, auth bypass for webhooks, response formats
- **Mobile tests** must verify sync service API calls, SubscriptionService sync integration, CTA wiring, SubscriptionScreen states
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1046+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 594+ tests plus new tests pass)
  - Existing usage limit tests pass (is_premium column still works)
  - Existing challenge/trial tests pass (premium_trial_expires_at still works)
  - Existing subscription screen tests pass (if any)

### Previous Story Intelligence

- **Story 6.5** (done) established: `challenges` and `user_challenges` tables (migration 020), `premium_trial_expires_at` column on profiles, `grant_premium_trial` RPC, `check_trial_expiry` RPC, `increment_challenge_progress` RPC, `challenge-repository.js`, `challenge-service.js`, trial expiry check in `POST /v1/outfits/generate` and `GET /v1/analytics/ai-summary`. Test counts: 594 API tests, 1046 Flutter tests.
- **Story 4.5** (done) established: `profiles.is_premium` column (migration 014), `usage-limit-service.js`, premium bypass in outfit generation, `UsageLimitCard` with "Go Premium" CTA (non-functional), `UsageIndicator`, 429 rate limit response. The `usageLimitService.checkUsageLimit()` reads `is_premium` from profiles -- this story adds lazy subscription expiry check.
- **Existing mobile infrastructure:**
  - `SubscriptionService` already exists at `apps/mobile/lib/src/core/subscription/subscription_service.dart` with `configure()`, `logIn()`, `logOut()`, `isProUser()`, `presentPaywall()`, `presentPaywallIfNeeded()`, `presentCustomerCenter()`, `restorePurchases()`, `addCustomerInfoUpdateListener()`.
  - `SubscriptionScreen` already exists at `apps/mobile/lib/src/features/subscription/screens/subscription_screen.dart` with status display, upgrade, manage, and restore flows.
  - `AppConfig` has `revenueCatApiKey` (compile-time env var `VESTIAIRE_REVENUECAT_API_KEY`).
  - `purchases_flutter: ^9.13.2` already in pubspec.yaml.
  - `main.dart` already calls `subscriptionService.configure()` and passes `subscriptionService` to `MainShellScreen`.
  - `MainShellScreen` already passes `subscriptionService` to `ProfileScreen`.
  - `ProfileScreen` already navigates to `SubscriptionScreen` and passes `subscriptionService`.
- **Existing API infrastructure:**
  - `createRuntime()` returns 26 services/repos. This story adds `subscriptionSyncService`.
  - `handleRequest` destructures all runtime services. Add `subscriptionSyncService`.
  - `mapError` handles 400, 401, 403, 404, 429, 503, 500. No new error codes needed.
  - Routes are defined in `handleRequest` with path matching. Webhook route needs auth bypass.
- **Key patterns:**
  - Factory pattern for all API services/repos.
  - DI via constructor parameters for mobile services.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements.
  - Best-effort for non-critical operations (try/catch, do not break primary actions).

### Key Anti-Patterns to Avoid

- DO NOT store subscription status client-side as the source of truth. The server (`profiles.is_premium`) is authoritative. The client displays `CustomerInfo` from RevenueCat for UI but does not enforce premium.
- DO NOT call RevenueCat REST API on every premium-gated request. Use the `is_premium` column for fast checks. Sync via webhook + client sync.
- DO NOT skip webhook authorization verification. Always verify the `authorization` header against the configured secret.
- DO NOT downgrade a trial user when a RevenueCat subscription expires. Check `premium_source` before revoking premium.
- DO NOT add `axios` or other HTTP libraries. Use Node 18+ built-in `fetch`.
- DO NOT modify the existing `SubscriptionService` class interface (constructor, public methods) in breaking ways. Add new capabilities additively with optional parameters.
- DO NOT remove or modify the existing `SubscriptionScreen` layout. Enhance it with trial vs subscription differentiation.
- DO NOT create a new paywall UI. Use RevenueCat's built-in `RevenueCatUI.presentPaywall()` and `RevenueCatUI.presentPaywallIfNeeded()`.
- DO NOT hardcode product IDs or entitlement names in multiple places. Use `SubscriptionService.proEntitlementId`, `SubscriptionService.monthlyProductId`, `SubscriptionService.yearlyProductId` constants.
- DO NOT block app startup if RevenueCat configuration fails. `configure()` should be resilient.
- DO NOT make webhook handling synchronous with the purchase flow. Webhooks are asynchronous and may arrive seconds after the purchase. The client sync provides immediate feedback.

### Out of Scope

- **Premium feature access enforcement for other features** (Story 7.2): This story only handles the purchase/sync flow. Story 7.2 will implement gating for shopping scans, resale listings, advanced analytics, and other premium-only features.
- **AI resale listing generation** (Story 7.3): Not related to subscription purchase.
- **Resale status tracking** (Story 7.4): Not related to subscription purchase.
- **RevenueCat dashboard configuration** (webhook URL, products, entitlements, offerings): This is infrastructure/ops work, not code. Document the required configuration in dev notes.
- **Yearly subscription plan:** RevenueCat will handle both monthly and yearly through the paywall. The API treats both identically -- it only checks the entitlement, not the plan type.
- **Promo codes or free trials via RevenueCat:** Not in scope for this story.
- **Subscription analytics or MRR tracking:** Not in scope.

### Environment Configuration Required

For deployment, the following environment variables must be set on the Cloud Run service:
- `REVENUECAT_API_KEY`: RevenueCat REST API v1 secret key (starts with `sk_`)
- `REVENUECAT_WEBHOOK_AUTH_HEADER`: Shared secret for webhook authorization (set in RevenueCat dashboard webhook settings)

For local development, these can be empty strings (RevenueCat API calls will gracefully fail).

### References

- [Source: epics.md - Story 7.1: Premium Subscription Purchase]
- [Source: epics.md - FR-OUT-10: Premium users shall have unlimited AI outfit generations]
- [Source: prd.md - SaaS Subscription: RevenueCat billing, £4.99/month Premium]
- [Source: prd.md - Payment compliance: Apple In-App Purchase via RevenueCat]
- [Source: prd.md - Server-side enforcement: All usage limits checked via Cloud Run API]
- [Source: architecture.md - Subscription and Premium Gating: RevenueCat acts as subscription state source]
- [Source: architecture.md - Server authority for sensitive rules: subscription gating]
- [Source: architecture.md - Client UI may show paywalls, but entitlement enforcement remains server-side]
- [Source: architecture.md - Epic 7 -> api/modules/billing, mobile/features/profile, mobile/features/resale]
- [Source: architecture.md - Mobile app boundary does not own billing truth]
- [Source: 4-5-ai-usage-limits-enforcement.md - profiles.is_premium column, usage-limit-service.js, UsageLimitCard "Go Premium" CTA]
- [Source: 6-5-challenge-rewards-premium-trial.md - premium_trial_expires_at, grant_premium_trial RPC, check_trial_expiry RPC, trial premium source]
- [Source: apps/mobile/lib/src/core/subscription/subscription_service.dart - existing SubscriptionService with RevenueCat SDK integration]
- [Source: apps/mobile/lib/src/features/subscription/screens/subscription_screen.dart - existing SubscriptionScreen]
- [Source: apps/mobile/lib/src/config/app_config.dart - revenueCatApiKey from env]
- [Source: apps/mobile/pubspec.yaml - purchases_flutter: ^9.13.2]
- [Source: apps/api/src/main.js - createRuntime(), handleRequest(), route definitions]
- [Source: RevenueCat Webhooks docs - https://www.revenuecat.com/docs/integrations/webhooks]
- [Source: RevenueCat Event Types - https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields]
- [Source: RevenueCat REST API v1 - https://www.revenuecat.com/docs/api-v1]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None.

### Completion Notes List

- Implemented migration 021 with premium_source, premium_expires_at columns, sync_premium_from_revenuecat RPC, updated check_trial_expiry RPC, and back-fill of existing trial users.
- Created subscription-sync-service.js in the new billing module following factory pattern, with syncFromClient, handleWebhookEvent, and verifyEntitlement methods. Uses built-in fetch (Node 18+) with graceful degradation on RevenueCat API failures.
- Added REVENUECAT_API_KEY and REVENUECAT_WEBHOOK_AUTH_HEADER to config/env.js.
- Added POST /v1/subscription/sync (authenticated) and POST /v1/webhooks/revenuecat (bypasses Firebase auth) routes to main.js.
- Updated usage-limit-service.js and analytics-summary-service.js with lazy subscription expiry checks (belt-and-suspenders with webhooks).
- Created mobile SubscriptionSyncService and SubscriptionStatus model.
- Updated SubscriptionService with optional syncService field, syncWithBackend method, and logIn integration.
- Wired UsageLimitCard "Go Premium" CTA to subscriptionService.presentPaywallIfNeeded() with backward compat.
- Enhanced SubscriptionScreen to differentiate trial vs paid subscription display.
- Updated main.dart to create SubscriptionSyncService and call logIn on startup if authenticated.
- All tests pass: 623 API tests (29 new), 1067 Flutter tests (21 new), zero regressions.

### Change Log

- 2026-03-19: Implemented Story 7.1 - Premium Subscription Purchase (all 16 tasks)

### File List

New files:
- infra/sql/migrations/021_premium_subscription.sql
- apps/api/src/modules/billing/subscription-sync-service.js
- apps/api/test/modules/billing/subscription-sync-service.test.js
- apps/api/test/modules/billing/subscription-endpoints.test.js
- apps/mobile/lib/src/core/subscription/subscription_sync_service.dart
- apps/mobile/lib/src/core/subscription/models/subscription_status.dart
- apps/mobile/test/core/subscription/subscription_sync_service_test.dart
- apps/mobile/test/core/subscription/subscription_service_test.dart
- apps/mobile/test/features/subscription/screens/subscription_screen_test.dart

Modified files:
- apps/api/src/config/env.js
- apps/api/src/main.js
- apps/api/src/modules/outfits/usage-limit-service.js
- apps/api/src/modules/analytics/analytics-summary-service.js
- apps/mobile/lib/src/core/subscription/subscription_service.dart
- apps/mobile/lib/src/features/subscription/screens/subscription_screen.dart
- apps/mobile/lib/src/features/home/widgets/usage_limit_card.dart
- apps/mobile/lib/src/features/home/screens/home_screen.dart
- apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart
- apps/mobile/lib/main.dart
- apps/mobile/lib/src/app.dart
- apps/mobile/test/features/home/widgets/usage_limit_card_test.dart
