# Story 13.2: Monthly Resale Prompts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the app to gently nudge me once a month to sell items I haven't worn in a long time,
so that I don't hoard unworn clothes and can improve my wardrobe health score.

## Acceptance Criteria

1. Given I have items with `neglect_status = "neglected"` (not worn in 180+ days) and `resale_status IS NULL` (not already listed/sold/donated), when the monthly resale evaluation endpoint is triggered, then the system identifies up to 3 resale candidate items per user, prioritized by: highest CPW first, then longest time since last worn, then oldest `created_at`. Each candidate includes an estimated sale price computed as `Math.round(purchasePrice * depreciationFactor)` where depreciationFactor is 0.4 for items worn 20+ times, 0.5 for 6-19, 0.6 for 1-5, and 0.7 for 0 wears. Items without `purchase_price` receive a default estimated price of 10 (GBP). (FR-RSL-01)

2. Given the monthly evaluation has identified resale candidates for me, when the API processes the results, then a push notification is sent via the existing `notificationService.sendPushNotification` with title "Time to declutter?" and body "You have {count} items you haven't worn in months. See what they could sell for!" The notification respects the user's `notification_preferences.resale_prompts` toggle (must be `true`, default `true`) and quiet hours. The notification `data` payload includes `{ type: "resale_prompt", promptId }`. (FR-RSL-05)

3. Given I receive a resale prompt notification or open the app and have pending resale prompts, when I navigate to the resale prompts screen (via notification tap or a banner on the Home screen), then I see a `ResalePromptsScreen` displaying: a header card showing my current Wardrobe Health Score (fetched from Story 13.1's endpoint) with text "Improve your score by decluttering!", followed by a list of 1-3 candidate items. Each item card shows: item image thumbnail, item name, category, days since last worn, estimated sale price, and two action buttons: "List for Sale" and "I'll Keep It". (FR-RSL-05, FR-RSL-06)

4. Given I am viewing a resale prompt item card, when I tap "List for Sale", then the app navigates to the existing `ResaleListingScreen` (from Story 7.3) with the item pre-loaded, allowing me to generate an AI resale listing. After returning from the listing screen, the item is removed from the prompts list and the prompt record is updated with `action = 'accepted'`. (FR-RSL-05)

5. Given I am viewing a resale prompt item card, when I tap "I'll Keep It", then the item is removed from the prompts list with a brief animation, the prompt record is updated with `action = 'dismissed'`, and the item will NOT appear in resale prompts again for 90 days (tracked via `dismissed_until` date on the prompt record). (FR-RSL-06)

6. Given I want to globally disable resale prompt notifications, when I navigate to the NotificationPreferencesScreen, then I see a "Resale Prompts" toggle under the existing notification categories. Toggling it off updates `notification_preferences.resale_prompts` to `false` via the existing `PUT /v1/profiles/me` endpoint. When disabled, no resale prompt notifications are sent, but I can still view prompts manually via the Profile screen. (FR-RSL-06)

7. Given the monthly evaluation runs, when the API creates prompt records, then it stores them in a new `resale_prompts` table with: `id`, `profile_id`, `item_id`, `estimated_price`, `estimated_currency`, `action` (NULL = pending, 'accepted', 'dismissed'), `dismissed_until` (for dismissed items), `created_at`. Items that were dismissed within the last 90 days (where `dismissed_until > CURRENT_DATE`) are excluded from candidate selection. (FR-RSL-05, FR-RSL-06)

8. Given I have pending resale prompts (action IS NULL, created in the current month), when the Home screen loads, then a compact banner appears below the weather widget: "You have {count} items to declutter" with a "View" button. Tapping navigates to ResalePromptsScreen. The banner is hidden if there are no pending prompts or if `notification_preferences.resale_prompts` is false. (FR-RSL-05)

9. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1303+ API tests, 1730+ Flutter tests) and new tests cover: resale candidate identification logic, estimated price calculation, resale prompt creation, notification delivery, ResalePromptsScreen widget (item cards, actions, health score display, empty state), Home screen banner, NotificationPreferencesScreen resale toggle, dismiss cooldown logic, and API endpoints.

## Tasks / Subtasks

- [x] Task 1: Database migration for `resale_prompts` table and notification_preferences update (AC: 7, 6)
  - [x] 1.1: Create `infra/sql/migrations/030_resale_prompts.sql`. Create `app_public.resale_prompts` table: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE`, `estimated_price NUMERIC(10,2) NOT NULL DEFAULT 10`, `estimated_currency TEXT NOT NULL DEFAULT 'GBP'`, `action TEXT CHECK (action IN ('accepted', 'dismissed'))` (NULL means pending), `dismissed_until DATE` (NULL unless dismissed), `created_at TIMESTAMPTZ DEFAULT now()`. Add RLS policy: `CREATE POLICY resale_prompts_user_policy ON app_public.resale_prompts FOR ALL USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`. Add indexes: `CREATE INDEX idx_resale_prompts_profile ON app_public.resale_prompts(profile_id, created_at DESC)`, `CREATE INDEX idx_resale_prompts_item ON app_public.resale_prompts(item_id)`, `CREATE INDEX idx_resale_prompts_pending ON app_public.resale_prompts(profile_id) WHERE action IS NULL`.
  - [x]1.2: In the same migration, update the `notification_preferences` default on `profiles` to include `resale_prompts: true`: `ALTER TABLE app_public.profiles ALTER COLUMN notification_preferences SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all","resale_prompts":true}'::jsonb`. Add a data migration to add the key to existing profiles: `UPDATE app_public.profiles SET notification_preferences = notification_preferences || '{"resale_prompts": true}'::jsonb WHERE NOT (notification_preferences ? 'resale_prompts')`.
  - [x]1.3: Add SQL comment: `-- Migration 030: Resale prompts table and notification_preferences update. Story 13.2: Monthly Resale Prompts. FR-RSL-01, FR-RSL-05, FR-RSL-06`.

- [x] Task 2: API -- Create resale prompt service with candidate identification (AC: 1, 2, 7)
  - [x]2.1: Create `apps/api/src/modules/resale/resale-prompt-service.js` with `createResalePromptService({ pool, notificationService })`. Follow the exact factory pattern used by other services.
  - [x]2.2: Implement `async identifyResaleCandidates(authContext, { limit = 3 })` method. Steps: (a) acquire client from pool, (b) set RLS context, (c) query for neglected items eligible for resale prompts:
    ```sql
    SELECT i.id, i.name, i.category, i.photo_url, i.brand,
           i.purchase_price, i.currency, i.wear_count, i.last_worn_date, i.created_at,
           COALESCE(i.purchase_price, 0) AS raw_price,
           COALESCE(i.wear_count, 0) AS wears
    FROM app_public.items i
    WHERE i.resale_status IS NULL
      AND (
        (COALESCE(i.wear_count, 0) > 0 AND i.last_worn_date IS NOT NULL AND i.last_worn_date < CURRENT_DATE - INTERVAL '180 days')
        OR (COALESCE(i.wear_count, 0) = 0 AND i.created_at < CURRENT_DATE - INTERVAL '180 days')
      )
      AND i.id NOT IN (
        SELECT rp.item_id FROM app_public.resale_prompts rp
        WHERE rp.dismissed_until > CURRENT_DATE
      )
    ORDER BY
      CASE WHEN i.purchase_price IS NOT NULL AND COALESCE(i.wear_count, 0) > 0
           THEN i.purchase_price / GREATEST(i.wear_count, 1)
           ELSE 999999 END DESC,
      COALESCE(i.last_worn_date, i.created_at) ASC
    LIMIT $1
    ```
    (d) For each candidate, compute estimated sale price in JS: `depreciationFactor` is 0.4 for wears >= 20, 0.5 for 6-19, 0.6 for 1-5, 0.7 for 0 wears. `estimatedPrice = purchasePrice ? Math.round(purchasePrice * depreciationFactor) : 10`. Minimum estimatedPrice is 1. (e) Return array of candidate objects: `{ itemId, name, category, photoUrl, brand, purchasePrice, currency, wearCount, daysSinceLastWorn, estimatedPrice, estimatedCurrency }`.
  - [x]2.3: Implement `async createPromptBatch(authContext, candidates)` method. For each candidate, INSERT into `app_public.resale_prompts` with `profile_id` from authContext, `item_id`, `estimated_price`, `estimated_currency`. Return the created prompt records with IDs.
  - [x]2.4: Implement `async evaluateAndNotify(authContext)` method that: (a) calls `identifyResaleCandidates(authContext)`, (b) if candidates.length > 0, calls `createPromptBatch(authContext, candidates)`, (c) sends push notification via `notificationService.sendPushNotification(profileId, { title: "Time to declutter?", body: "You have ${candidates.length} item${candidates.length > 1 ? 's' : ''} you haven't worn in months. See what they could sell for!", data: { type: "resale_prompt", promptId: prompts[0].id } }, { preferenceKey: "resale_prompts" })`. Fire-and-forget. (d) Returns `{ candidates: candidates.length, prompted: true }` or `{ candidates: 0, prompted: false }`.
  - [x]2.5: Implement `async getPendingPrompts(authContext)` method. Query: `SELECT rp.*, i.name AS item_name, i.photo_url AS item_photo_url, i.category AS item_category, i.brand AS item_brand, i.wear_count AS item_wear_count, i.last_worn_date AS item_last_worn_date, i.created_at AS item_created_at FROM app_public.resale_prompts rp JOIN app_public.items i ON rp.item_id = i.id WHERE rp.action IS NULL AND rp.created_at >= DATE_TRUNC('month', CURRENT_DATE) ORDER BY rp.created_at DESC`. Return array mapped to camelCase.
  - [x]2.6: Implement `async updatePromptAction(authContext, promptId, { action })` method. Validates `action` is 'accepted' or 'dismissed'. For 'dismissed', also sets `dismissed_until = CURRENT_DATE + INTERVAL '90 days'`. UPDATE `app_public.resale_prompts SET action = $1, dismissed_until = $2 WHERE id = $3`. Return updated record.
  - [x]2.7: Implement `async getPendingCount(authContext)` method. Query: `SELECT COUNT(*) as count FROM app_public.resale_prompts WHERE action IS NULL AND created_at >= DATE_TRUNC('month', CURRENT_DATE)`. Return the count as integer.

- [x] Task 3: API -- Update notification service to support preferenceKey parameter (AC: 2)
  - [x]3.1: In `apps/api/src/modules/notifications/notification-service.js`, update `sendPushNotification` to accept an optional third parameter `options = {}` with `preferenceKey` field. If `preferenceKey` is provided (e.g., `"resale_prompts"`), check `notification_preferences[preferenceKey]` instead of `notification_preferences.social`. If the key is not found in preferences, default to `true` (opt-in by default). This generalizes the preference check beyond just `social`.
  - [x]3.2: Update existing callers (ootd-service.js comment/post notifications) to pass `{ preferenceKey: "social" }` explicitly, maintaining backward compatibility.

- [x] Task 4: API -- Add resale prompt endpoints (AC: 1, 2, 3, 4, 5, 7, 8)
  - [x]4.1: Add route `POST /v1/resale/prompts/evaluate` to `apps/api/src/main.js`. Requires authentication. Calls `resalePromptService.evaluateAndNotify(authContext)`. Returns 200 with the evaluation result. This endpoint is called by: (a) a Cloud Scheduler cron job hitting the API monthly, OR (b) manual trigger from the client (e.g., on app open, debounced to once per month per user using a simple date check in the client). For V1, the client triggers evaluation on Home screen load if the last evaluation was > 30 days ago (tracked via SharedPreferences).
  - [x]4.2: Add route `GET /v1/resale/prompts` to `apps/api/src/main.js`. Requires authentication. Calls `resalePromptService.getPendingPrompts(authContext)`. Returns 200 with `{ prompts: [...] }`.
  - [x]4.3: Add route `PATCH /v1/resale/prompts/:id` to `apps/api/src/main.js`. Requires authentication. Reads body `{ action }`. Validates action is 'accepted' or 'dismissed'. Calls `resalePromptService.updatePromptAction(authContext, promptId, { action })`. Returns 200 with updated prompt.
  - [x]4.4: Add route `GET /v1/resale/prompts/count` to `apps/api/src/main.js`. Requires authentication. Calls `resalePromptService.getPendingCount(authContext)`. Returns 200 with `{ count: number }`.
  - [x]4.5: Wire up `resalePromptService` in `createRuntime()`: instantiate `createResalePromptService({ pool, notificationService })` and add to the runtime object. Add to `handleRequest` destructuring.

- [x] Task 5: API -- Update notification_preferences validation for resale_prompts key (AC: 6)
  - [x]5.1: In `apps/api/src/modules/profiles/service.js`, update the `ALLOWED_NOTIFICATION_KEYS` or equivalent validation to accept `resale_prompts` as a boolean key alongside `outfit_reminders`, `wear_logging`, and `analytics`.

- [x] Task 6: Mobile -- Create ResalePrompt model (AC: 3, 7)
  - [x]6.1: Create `apps/mobile/lib/src/features/resale/models/resale_prompt.dart` with a `ResalePrompt` class. Fields: `String id`, `String itemId`, `double estimatedPrice`, `String estimatedCurrency`, `String? action`, `DateTime? dismissedUntil`, `DateTime createdAt`, `String? itemName`, `String? itemPhotoUrl`, `String? itemCategory`, `String? itemBrand`, `int itemWearCount`, `DateTime? itemLastWornDate`, `DateTime? itemCreatedAt`. Include `factory ResalePrompt.fromJson(Map<String, dynamic> json)`.
  - [x]6.2: Add computed getter `int get daysSinceLastWorn` that calculates days from `itemLastWornDate ?? itemCreatedAt` to now.

- [x] Task 7: Mobile -- Create ResalePromptService (AC: 3, 4, 5, 8)
  - [x]7.1: Create `apps/mobile/lib/src/features/resale/services/resale_prompt_service.dart` with a `ResalePromptService` class. Constructor accepts `ApiClient`.
  - [x]7.2: Implement `Future<List<ResalePrompt>> fetchPendingPrompts()` that calls `GET /v1/resale/prompts` and parses the response into a list of `ResalePrompt` objects. Returns empty list on error.
  - [x]7.3: Implement `Future<bool> triggerEvaluation()` that calls `POST /v1/resale/prompts/evaluate`. Returns `true` if candidates were found. Returns `false` on error or zero candidates.
  - [x]7.4: Implement `Future<void> acceptPrompt(String promptId)` that calls `PATCH /v1/resale/prompts/$promptId` with `{ "action": "accepted" }`.
  - [x]7.5: Implement `Future<void> dismissPrompt(String promptId)` that calls `PATCH /v1/resale/prompts/$promptId` with `{ "action": "dismissed" }`.
  - [x]7.6: Implement `Future<int> fetchPendingCount()` that calls `GET /v1/resale/prompts/count` and returns the count. Returns 0 on error.
  - [x]7.7: Add `Future<Map<String, dynamic>> getResalePrompts()` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedGet("/v1/resale/prompts")`.
  - [x]7.8: Add `Future<Map<String, dynamic>> evaluateResalePrompts()` to ApiClient. Calls `authenticatedPost("/v1/resale/prompts/evaluate", body: {})`.
  - [x]7.9: Add `Future<Map<String, dynamic>> updateResalePrompt(String promptId, Map<String, dynamic> body)` to ApiClient. Calls `authenticatedPatch("/v1/resale/prompts/$promptId", body: body)`.
  - [x]7.10: Add `Future<Map<String, dynamic>> getResalePromptsCount()` to ApiClient. Calls `authenticatedGet("/v1/resale/prompts/count")`.

- [x] Task 8: Mobile -- Create ResalePromptsScreen (AC: 3, 4, 5)
  - [x]8.1: Create `apps/mobile/lib/src/features/resale/screens/resale_prompts_screen.dart` with a `ResalePromptsScreen` StatefulWidget. Constructor accepts `ApiClient apiClient` and optional `ResalePromptService? resalePromptService` and `ResaleListingService? resaleListingService`.
  - [x]8.2: Screen layout following Vibrant Soft-UI design system: (a) AppBar with "Resale Suggestions" title and back button. (b) At top, a health score summary card: fetch from `GET /v1/analytics/wardrobe-health` and display the score with color ring (reuse `HealthScoreSection` pattern or a compact version), recommendation text, and "Improve your score by decluttering!" subtext. (c) Below, a list of `ResalePromptCard` widgets, one per pending prompt. (d) Empty state: "No items to declutter right now. Keep wearing your wardrobe!" with `Icons.check_circle_outline` icon (32px, #22C55E).
  - [x]8.3: Each `ResalePromptCard` shows: (a) item image thumbnail (80x80, rounded 12px, `CachedNetworkImage`), (b) item name (16px bold, #1F2937), (c) category and brand (12px, #6B7280), (d) "Not worn in {daysSinceLastWorn} days" label (12px, #F59E0B with `Icons.schedule` icon), (e) estimated sale price prominently displayed (20px bold, #22C55E, e.g., "~15 GBP"), (f) two action buttons side-by-side: "List for Sale" (filled #4F46E5, `Icons.sell`) and "I'll Keep It" (outlined #6B7280, `Icons.favorite_border`). Card has 16px padding, 12px border-radius, white background, subtle elevation.
  - [x]8.4: When "List for Sale" is tapped: (a) call `resalePromptService.acceptPrompt(prompt.id)`, (b) navigate to `ResaleListingScreen(item: WardrobeItem.fromPrompt(prompt))` via `Navigator.push`, (c) on return, remove the card from the list with `AnimatedList` or simple `setState`. Use `mounted` guard.
  - [x]8.5: When "I'll Keep It" is tapped: (a) call `resalePromptService.dismissPrompt(prompt.id)`, (b) remove the card from the list with a fade-out animation. Use `mounted` guard.
  - [x]8.6: On `initState`, call `_loadPrompts()` which fetches pending prompts and health score in parallel via `Future.wait`. Use `mounted` guard before `setState`. Show loading indicator during fetch.
  - [x]8.7: Add `Semantics` labels: "Resale suggestions" on the screen, "Item [name], estimated sale price [price], not worn in [days] days" on each card, "List item for sale" on accept button, "Keep this item" on dismiss button.

- [x] Task 9: Mobile -- Add resale prompt banner to Home screen (AC: 8)
  - [x]9.1: Update the Home screen (likely `apps/mobile/lib/src/features/home/screens/home_screen.dart`). After the weather widget section, add a conditional banner that appears when pending resale prompts exist.
  - [x]9.2: On Home screen load (in `_loadData()` or equivalent), call `resalePromptService.fetchPendingCount()` to get the count of pending prompts. Store in state. Also check if evaluation is needed: read `last_resale_evaluation` from SharedPreferences; if null or > 30 days ago, call `resalePromptService.triggerEvaluation()` and save today's date to SharedPreferences. Handle failures silently.
  - [x]9.3: The banner widget: `Container` with light amber background (#FFFBEB), 12px border-radius, 16px horizontal padding, 12px vertical padding. Contains a `Row` with: `Icons.sell` icon (20px, #F59E0B), text "You have {count} item{count > 1 ? 's' : ''} to declutter" (14px, #92400E), spacer, "View" text button (14px bold, #4F46E5). Tapping "View" navigates to `ResalePromptsScreen`.
  - [x]9.4: The banner is hidden when: count is 0, OR `notification_preferences.resale_prompts` is false (check cached preference). Use `mounted` guard before `setState`.
  - [x]9.5: Add `Semantics` label: "You have {count} items to declutter, tap to view resale suggestions".

- [x] Task 10: Mobile -- Update NotificationPreferencesScreen with resale prompts toggle (AC: 6)
  - [x]10.1: In `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`, add a new `SwitchListTile` for "Resale Prompts" after the existing categories. Icon: `Icons.sell` (amber color). Subtitle: "Monthly suggestions for items to sell or donate". Default: on (true).
  - [x]10.2: When toggled, update the local preferences map and call the existing `PUT /v1/profiles/me` with the updated `notification_preferences` object containing `resale_prompts: true/false`.
  - [x]10.3: Add `Semantics` label: "Resale prompts notifications, currently {enabled ? 'on' : 'off'}".

- [x] Task 11: API -- Unit tests for resale prompt service (AC: 1, 2, 5, 7, 9)
  - [x]11.1: Create `apps/api/test/modules/resale/resale-prompt-service.test.js`:
    - `identifyResaleCandidates` returns up to 3 neglected items with NULL resale_status.
    - `identifyResaleCandidates` excludes items with resale_status 'listed', 'sold', or 'donated'.
    - `identifyResaleCandidates` excludes items dismissed within the last 90 days.
    - `identifyResaleCandidates` prioritizes by highest CPW, then oldest.
    - `identifyResaleCandidates` returns empty array when no items are neglected.
    - Estimated price calculation: 0.4 factor for 20+ wears, 0.5 for 6-19, 0.6 for 1-5, 0.7 for 0.
    - Estimated price defaults to 10 when purchase_price is null.
    - Estimated price minimum is 1 (no zero-price estimates).
    - `createPromptBatch` inserts records into resale_prompts with correct fields.
    - `evaluateAndNotify` calls notificationService when candidates exist.
    - `evaluateAndNotify` does NOT notify when no candidates found.
    - `getPendingPrompts` returns only prompts with NULL action from current month.
    - `updatePromptAction` sets action and dismissed_until for dismissed prompts.
    - `updatePromptAction` sets only action for accepted prompts (no dismissed_until).
    - `getPendingCount` returns correct count.
    - RLS enforcement: user A cannot see user B's prompts.

- [x] Task 12: API -- Integration tests for resale prompt endpoints (AC: 1, 2, 3, 4, 5, 8, 9)
  - [x]12.1: Create `apps/api/test/modules/resale/resale-prompts.test.js`:
    - `POST /v1/resale/prompts/evaluate` requires authentication (401).
    - `POST /v1/resale/prompts/evaluate` returns 200 with candidates count.
    - `POST /v1/resale/prompts/evaluate` creates prompt records for neglected items.
    - `POST /v1/resale/prompts/evaluate` sends notification when candidates found.
    - `POST /v1/resale/prompts/evaluate` returns 0 candidates for user with no neglected items.
    - `GET /v1/resale/prompts` requires authentication (401).
    - `GET /v1/resale/prompts` returns pending prompts with item metadata.
    - `GET /v1/resale/prompts` excludes acted-upon prompts.
    - `PATCH /v1/resale/prompts/:id` requires authentication (401).
    - `PATCH /v1/resale/prompts/:id` accepts 'accepted' action.
    - `PATCH /v1/resale/prompts/:id` accepts 'dismissed' action and sets dismissed_until.
    - `PATCH /v1/resale/prompts/:id` returns 400 for invalid action.
    - `GET /v1/resale/prompts/count` returns correct pending count.

- [x] Task 13: Mobile -- Unit tests for ResalePrompt model (AC: 3, 9)
  - [x]13.1: Create `apps/mobile/test/features/resale/models/resale_prompt_test.dart`:
    - `ResalePrompt.fromJson()` parses all fields correctly.
    - `ResalePrompt.fromJson()` handles null optional fields.
    - `daysSinceLastWorn` computes correctly from itemLastWornDate.
    - `daysSinceLastWorn` falls back to itemCreatedAt when itemLastWornDate is null.

- [x] Task 14: Mobile -- Unit tests for ResalePromptService (AC: 3, 4, 5, 8, 9)
  - [x]14.1: Create `apps/mobile/test/features/resale/services/resale_prompt_service_test.dart`:
    - `fetchPendingPrompts` calls API and returns parsed prompts.
    - `fetchPendingPrompts` returns empty list on error.
    - `triggerEvaluation` calls API and returns true when candidates found.
    - `triggerEvaluation` returns false on error.
    - `acceptPrompt` calls PATCH with correct action.
    - `dismissPrompt` calls PATCH with correct action.
    - `fetchPendingCount` returns correct count.
    - `fetchPendingCount` returns 0 on error.

- [x] Task 15: Mobile -- Widget tests for ResalePromptsScreen (AC: 3, 4, 5, 9)
  - [x]15.1: Create `apps/mobile/test/features/resale/screens/resale_prompts_screen_test.dart`:
    - Shows loading indicator during fetch.
    - Displays health score summary card at top.
    - Displays prompt item cards with name, category, days, estimated price.
    - "List for Sale" button navigates to ResaleListingScreen.
    - "I'll Keep It" button removes item from list.
    - Empty state shows when no pending prompts.
    - Semantics labels present on all interactive elements.

- [x] Task 16: Mobile -- Widget tests for Home screen resale banner (AC: 8, 9)
  - [x]16.1: Update Home screen test file:
    - Resale banner is shown when pending count > 0.
    - Resale banner is hidden when pending count is 0.
    - Resale banner displays correct count text.
    - Tapping "View" navigates to ResalePromptsScreen.
    - Banner is hidden when resale_prompts preference is false.

- [x] Task 17: Mobile -- Widget tests for NotificationPreferencesScreen resale toggle (AC: 6, 9)
  - [x]17.1: Update notification preferences screen test file:
    - "Resale Prompts" toggle is visible.
    - Toggling off updates notification_preferences.
    - Toggling on updates notification_preferences.
    - Semantics label present.

- [x] Task 18: Regression testing (AC: all)
  - [x]18.1: Run `flutter analyze` -- zero new issues.
  - [x]18.2: Run `flutter test` -- all existing 1730+ Flutter tests plus new tests pass.
  - [x]18.3: Run `npm --prefix apps/api test` -- all existing 1303+ API tests plus new tests pass.
  - [x]18.4: Verify existing ResaleListingScreen (Story 7.3) still works.
  - [x]18.5: Verify existing ResaleHistoryScreen (Story 7.4) still works.
  - [x]18.6: Verify existing NotificationPreferencesScreen functionality is preserved.
  - [x]18.7: Verify existing Home screen functionality is preserved.
  - [x]18.8: Verify existing wardrobe health score (Story 13.1) still works.

## Dev Notes

- This is the **second story in Epic 13** (Circular Resale Triggers). It builds on Story 13.1 (Wardrobe Health Score) to provide the motivational context, and leverages the resale infrastructure from Epic 7 (Stories 7.3 and 7.4) for the "List for Sale" flow.
- This story implements **FR-RSL-01** (identify resale candidates based on neglect, CPW, wear count), **FR-RSL-05** (monthly resale prompt notifications), and **FR-RSL-06** (dismiss per-item or globally via settings).
- **FREE-TIER feature.** Like the health score (Story 13.1), resale prompts are accessible to ALL users. The prompts drive engagement and funnel users toward the existing resale listing generator (Story 7.3), which has its own premium gating (2 free listings/month). No additional premium gating is needed here.

### Design Decision: Client-Triggered Monthly Evaluation (Not Server Cron)

For V1, the monthly resale evaluation is triggered by the client (on Home screen load, debounced to once per 30 days via SharedPreferences). This avoids the need for a Cloud Scheduler cron job that iterates over all users -- which requires infrastructure that does not yet exist in the project. The `POST /v1/resale/prompts/evaluate` endpoint is designed so that a server-side cron can call it per-user in the future. The client-side approach ensures prompts are generated only for active users, reducing unnecessary processing.

### Design Decision: Estimated Sale Price Calculation

The estimated sale price uses a simple depreciation model: items with fewer wears retain more value. This is a rough heuristic, not a marketplace price estimate. The depreciation factors (0.7 for 0 wears, 0.6 for 1-5, 0.5 for 6-19, 0.4 for 20+) are intentionally optimistic to encourage listing. Items without a purchase price default to 10 GBP. The price is labeled as "estimated" in the UI to set expectations.

### Design Decision: 90-Day Dismiss Cooldown

When a user taps "I'll Keep It", the item is excluded from resale prompts for 90 days. This prevents the app from nagging about the same item every month while still re-evaluating after a quarter. The cooldown is stored as `dismissed_until` on the prompt record and checked during candidate selection.

### Design Decision: Prompt Records Scoped to Current Month

`getPendingPrompts` only returns prompts created in the current calendar month. This ensures old prompts from previous months are automatically "expired" without needing a cleanup job. Each monthly evaluation creates fresh prompts for the current month's candidates.

### Design Decision: Home Screen Banner (Not Modal/Sheet)

The resale prompt is surfaced as a compact, non-intrusive banner on the Home screen rather than a modal or bottom sheet. This respects the user's attention and avoids the "nagging" feel. The user must actively tap "View" to see the full suggestions.

### Design Decision: Notification Service Generalization

The existing `notificationService.sendPushNotification` is extended with a `preferenceKey` option to check any notification preference category, not just `social`. This makes the notification service reusable for future notification types without code changes.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/030_resale_prompts.sql` (resale_prompts table, notification_preferences update)
  - `apps/api/src/modules/resale/resale-prompt-service.js` (candidate identification, prompt CRUD, evaluation)
  - `apps/api/test/modules/resale/resale-prompt-service.test.js`
  - `apps/api/test/modules/resale/resale-prompts.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/resale/models/resale_prompt.dart` (ResalePrompt model)
  - `apps/mobile/lib/src/features/resale/services/resale_prompt_service.dart` (ResalePromptService)
  - `apps/mobile/lib/src/features/resale/screens/resale_prompts_screen.dart` (ResalePromptsScreen)
  - `apps/mobile/test/features/resale/models/resale_prompt_test.dart`
  - `apps/mobile/test/features/resale/services/resale_prompt_service_test.dart`
  - `apps/mobile/test/features/resale/screens/resale_prompts_screen_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add 4 resale prompt routes, wire resalePromptService in createRuntime and handleRequest)
  - `apps/api/src/modules/notifications/notification-service.js` (add preferenceKey option to sendPushNotification)
  - `apps/api/src/modules/profiles/service.js` (add resale_prompts to allowed notification keys)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add 4 resale prompt API methods)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add resale prompt banner, monthly evaluation trigger)
  - `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart` (add Resale Prompts toggle)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add banner tests)
  - `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart` (add resale toggle tests)

### Technical Requirements

- **New API endpoints:**
  - `POST /v1/resale/prompts/evaluate` -- triggers monthly evaluation for authenticated user. Returns `{ candidates: number, prompted: boolean }`. No premium gating.
  - `GET /v1/resale/prompts` -- returns pending prompts for current month. Returns `{ prompts: [...] }`.
  - `PATCH /v1/resale/prompts/:id` -- updates prompt action. Accepts `{ action: "accepted"|"dismissed" }`. Returns updated prompt.
  - `GET /v1/resale/prompts/count` -- returns pending prompt count. Returns `{ count: number }`.
- **Database table:** `resale_prompts` in `app_public` schema with RLS. FK to `profiles` and `items`.
- **Candidate identification criteria:** `neglect_status = "neglected"` (180+ days without wear), `resale_status IS NULL`, not dismissed within 90 days. Up to 3 candidates per evaluation.
- **Estimated price formula:** `Math.round(purchasePrice * depreciationFactor)`, minimum 1, default 10 when no purchase price. Depreciation: 0.7 (0 wears), 0.6 (1-5), 0.5 (6-19), 0.4 (20+).
- **Notification delivery:** Via existing `notificationService.sendPushNotification` with new `preferenceKey: "resale_prompts"` option. Fire-and-forget.
- **Monthly debounce:** Client stores `last_resale_evaluation` in SharedPreferences. Only triggers evaluation if > 30 days since last evaluation.
- **No new mobile dependencies.** Uses existing packages.

### Architecture Compliance

- **Server authority for candidate identification:** Resale candidates are computed server-side. The mobile client does not compute which items to suggest.
- **Server authority for notification preferences:** The `resale_prompts` preference is stored and enforced server-side. The mobile client caches it for UI display only.
- **RLS enforces data isolation:** All resale prompt queries are scoped via `set_config`. Users can only see their own prompts.
- **Mobile boundary owns presentation:** `ResalePromptsScreen` handles all presentation: health score context, item cards, actions, empty state.
- **No new AI calls:** Candidate identification is purely data-driven (SQL + JS math). The estimated price is a simple formula, not an AI prediction.
- **Epic 13 component mapping:** Architecture specifies `mobile/features/resale`, `api/modules/resale`, `api/modules/notifications` for Epic 13. This story correctly uses all three.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `pg` (via pool), existing notification service, existing items data.
- **Mobile:** No new dependencies. Uses existing `CachedNetworkImage`, `shared_preferences`, `intl` for currency formatting.

### File Structure Requirements

- `resale-prompt-service.js` goes in `apps/api/src/modules/resale/` alongside existing `resale-listing-service.js` and `resale-history-repository.js`.
- Mobile resale prompt files go in the existing `apps/mobile/lib/src/features/resale/` directory.
- Migration file: `030_resale_prompts.sql` -- follows sequential numbering. (Migrations 024-029 are assumed to exist from Epics 8-12.)
- Test files mirror source structure.

### Testing Requirements

- **Resale prompt service unit tests** must verify: candidate identification with correct priority, exclusion of listed/sold/donated items, exclusion of dismissed items within 90 days, estimated price calculation for all wear count tiers, default price for null purchase_price, minimum price of 1, prompt batch creation, notification delivery, pending prompts retrieval, action update with dismissed_until, pending count, RLS enforcement.
- **Endpoint integration tests** must verify: authentication on all 4 endpoints, evaluate creates prompts, evaluate sends notification, pending prompts returned with item metadata, action update for accepted/dismissed, invalid action returns 400, count returns correct number.
- **Mobile model tests** must verify: JSON parsing, null handling, daysSinceLastWorn computation.
- **Mobile service tests** must verify: correct API calls, response parsing, error handling.
- **ResalePromptsScreen widget tests** must verify: loading state, health score card, prompt cards, accept/dismiss actions, empty state, semantics.
- **Home screen banner tests** must verify: banner shown/hidden based on count, navigation, preference respect.
- **Notification preferences tests** must verify: resale toggle visibility, toggle persistence.
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1730+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1303+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 13.1** (done) established: `GET /v1/analytics/wardrobe-health` endpoint (free-tier), `HealthScoreSection` widget with circular score ring, `getWardrobeHealthScore()` in ApiClient, mini health bar on WardrobeScreen. Test baselines after 13.1: 1303 API tests, 1730 Flutter tests. The health score is used in this story's ResalePromptsScreen as motivational context.
- **Story 7.3** (done) established: `ResaleListingScreen`, `ResaleListingService`, `POST /v1/resale/generate`, `resale_listings` table (migration 022), `items.resale_status` column with CHECK constraint. The "List for Sale" action in this story navigates to `ResaleListingScreen`.
- **Story 7.4** (done) established: `PATCH /v1/items/:id/resale-status`, `GET /v1/resale/history`, `resale_history` table (migration 023), `resale-history-repository.js`, `ResaleHistoryScreen`, badge function updates for `circular_seller` and `circular_champion`. 689 API tests, 1151 Flutter tests.
- **Story 2.7** (done) established: `computeNeglectStatus(row)` in `repository.js`, `NEGLECT_THRESHOLD_DAYS = 180`, `neglectStatus` field on items, `isNeglected` getter on WardrobeItem, "Neglect" filter in FilterBar. The neglect computation is the basis for resale candidate identification.
- **Story 9.6** (done) established: `notification-service.js` in `apps/api/src/modules/notifications/` with `createNotificationService({ pool })`, `sendPushNotification(profileId, { title, body, data })`, `sendToSquadMembers`, `isQuietHours()`. Checks `notification_preferences.social` and quiet hours before sending. This story generalizes the preference check.
- **Story 1.6** (done) established: `push_token` and `notification_preferences` JSONB on `profiles` table. Default preferences: `{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all"}`. NotificationPreferencesScreen with toggle UI.
- **Story 4.7** (done) established: `MorningNotificationService` for local notifications, `flutter_local_notifications` dependency, SharedPreferences for notification scheduling.
- **Story 5.2** (done) established: Evening wear-log reminder pattern -- local notification scheduling with SharedPreferences debounce. Similar client-side scheduling pattern used for monthly evaluation trigger.
- **`createRuntime()` currently returns (as of Story 13.1, estimated ~33 services).** This story adds `resalePromptService`.
- **`handleRequest` destructuring** includes all services. This story adds `resalePromptService`.
- **Key patterns from prior stories:**
  - Factory pattern for all API services: `createXxxService({ deps })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories.
  - Semantics labels on all interactive elements.
  - Best-effort for non-critical operations (try/catch, do not break primary flow).
  - Fire-and-forget for notifications.
  - SharedPreferences for local debounce/scheduling state.
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `resale_status`, `created_at`, `updated_at`.
- **Current test baselines (from Story 13.1):** 1303 API tests, 1730 Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT compute resale candidates on the mobile client. All candidate identification happens server-side.
- DO NOT send notifications without checking `notification_preferences.resale_prompts`. The preference must be respected.
- DO NOT send notifications during quiet hours. Use the existing `isQuietHours()` check in the notification service.
- DO NOT block the evaluation response on notification delivery. Notifications are fire-and-forget.
- DO NOT create a server-side cron job in V1. Use client-triggered evaluation with SharedPreferences debounce.
- DO NOT show resale prompts for items that are already listed, sold, or donated. Check `resale_status IS NULL`.
- DO NOT show the same dismissed item again within 90 days. Check `dismissed_until > CURRENT_DATE`.
- DO NOT use AI for estimated sale price. Use the simple depreciation formula.
- DO NOT add premium gating to resale prompts. This is a FREE-TIER feature that drives engagement.
- DO NOT use a modal/dialog for the Home screen prompt. Use a non-intrusive banner.
- DO NOT store prompts permanently. `getPendingPrompts` only returns current-month prompts. Old prompts naturally expire.
- DO NOT modify the existing `resale_listings` or `resale_history` tables. This story only adds `resale_prompts`.
- DO NOT modify existing API endpoints. Only add new endpoints and extend the notification service.
- DO NOT use negative or guilt-inducing language in prompts. Use encouraging language like "See what they could sell for!" not "You're wasting money on these items."

### Out of Scope

- **Spring Clean Declutter Flow & Donations (FR-HLT-05, FR-DON-01-03, FR-DON-05):** Story 13.3.
- **Server-side cron job for batch evaluation:** Deferred. V1 uses client-triggered evaluation.
- **AI-powered price estimation using marketplace data:** Out of scope. Uses simple depreciation formula.
- **Platform-specific listing (Vinted vs Depop pricing):** Out of scope. Single estimated price.
- **Resale prompt history/analytics:** Out of scope.
- **Push notification for prompt expiry:** Out of scope.
- **In-app notification center/inbox:** Out of scope.
- **Animated card removal transitions beyond simple fade:** Nice-to-have, not required.

### References

- [Source: epics.md - Story 13.2: Monthly Resale Prompts]
- [Source: epics.md - Epic 13: Circular Resale Triggers]
- [Source: epics.md - FR-RSL-01: The system shall identify resale candidates based on: not worn in 90+ days, high CPW, and low wear count relative to age]
- [Source: epics.md - FR-RSL-05: The system shall send monthly resale prompt notifications for neglected items with estimated sale price]
- [Source: epics.md - FR-RSL-06: Users shall dismiss resale prompts per-item or globally via settings]
- [Source: architecture.md - Epic 13 Circular Resale Triggers -> mobile/features/resale, api/modules/resale, api/modules/notifications]
- [Source: architecture.md - Notifications and Async Work: monthly resale prompts]
- [Source: architecture.md - Preference enforcement occurs server-side so disabled notifications are never sent]
- [Source: 13-1-wardrobe-health-score.md - GET /v1/analytics/wardrobe-health, HealthScoreSection, free-tier, 1303 API tests, 1730 Flutter tests]
- [Source: 7-3-ai-resale-listing-generation.md - ResaleListingScreen, ResaleListingService, POST /v1/resale/generate, resale_listings table]
- [Source: 7-4-resale-status-history-tracking.md - PATCH /v1/items/:id/resale-status, resale_history table, resale-history-repository.js]
- [Source: 2-7-neglect-detection-badging.md - computeNeglectStatus, NEGLECT_THRESHOLD_DAYS = 180, neglectStatus on items]
- [Source: 9-6-social-notification-preferences.md - notification-service.js, sendPushNotification, isQuietHours, sendToSquadMembers]
- [Source: 1-6-push-notification-permissions-preferences.md - push_token, notification_preferences JSONB, NotificationPreferencesScreen]
- [Source: apps/api/src/modules/notifications/notification-service.js - sendPushNotification, preference checks, quiet hours]
- [Source: apps/api/src/modules/resale/resale-listing-service.js - existing resale module]
- [Source: apps/api/src/modules/resale/resale-history-repository.js - existing resale module]
- [Source: apps/api/src/modules/items/repository.js - computeNeglectStatus, NEGLECT_THRESHOLD_DAYS, mapItemRow]
- [Source: apps/api/src/main.js - createRuntime, handleRequest, route patterns]
- [Source: apps/mobile/lib/src/features/resale/screens/resale_listing_screen.dart - ResaleListingScreen for "List for Sale" navigation]
- [Source: apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart - HealthScoreSection pattern for compact health display]

## Dev Agent Record

### Implementation Plan
- Task 1: Created migration 037 (not 030 as originally specified since migrations 030-036 already existed). Created resale_prompts table with RLS, indexes, and notification_preferences update.
- Task 2: Created resale-prompt-service.js with full candidate identification, prompt CRUD, and notification delivery.
- Task 3: Extended notification-service.js with preferenceKey option for generalized preference checks.
- Task 4: Added 4 resale prompt API endpoints and wired resalePromptService in createRuntime/handleRequest.
- Task 5: Added resale_prompts to ALLOWED_NOTIFICATION_KEYS and BOOLEAN_ONLY_NOTIFICATION_KEYS.
- Task 6: Created ResalePrompt model with fromJson parsing and daysSinceLastWorn computed getter.
- Task 7: Created ResalePromptService and added 4 API client methods.
- Task 8: Created ResalePromptsScreen with health score card, item cards, accept/dismiss actions, and empty state.
- Task 9: Added resale prompt banner to HomeScreen with monthly evaluation trigger via SharedPreferences debounce.
- Task 10: Added "Resale Prompts" toggle to NotificationPreferencesScreen.
- Tasks 11-17: Created comprehensive unit, integration, and widget tests.
- Task 18: Regression verified -- all 1342 API tests pass, all 1761 Flutter tests pass, zero analyze errors.

### Completion Notes
- Migration file is 037_resale_prompts.sql (corrected from story's 030 to match existing migration numbering).
- Existing notification preferences test for event reminders toggle needed scrolling fix due to new resale_prompts toggle pushing it off-screen.
- Existing posting reminder toggle test index updated from 3 to 4 to account for new resale_prompts boolean category.
- ResalePromptsScreen widget tests and HomeScreen banner tests use `tester.runAsync` to resolve real async HTTP operations from mock clients.
- All acceptance criteria verified and satisfied.

## File List

### New Files
- `infra/sql/migrations/037_resale_prompts.sql` -- Database migration for resale_prompts table and notification_preferences update
- `apps/api/src/modules/resale/resale-prompt-service.js` -- Resale prompt service (candidate identification, prompt CRUD, evaluation)
- `apps/api/test/modules/resale/resale-prompt-service.test.js` -- Unit tests for resale prompt service
- `apps/api/test/modules/resale/resale-prompts.test.js` -- Integration tests for resale prompt endpoints
- `apps/mobile/lib/src/features/resale/models/resale_prompt.dart` -- ResalePrompt model
- `apps/mobile/lib/src/features/resale/services/resale_prompt_service.dart` -- ResalePromptService
- `apps/mobile/lib/src/features/resale/screens/resale_prompts_screen.dart` -- ResalePromptsScreen
- `apps/mobile/test/features/resale/models/resale_prompt_test.dart` -- Model unit tests
- `apps/mobile/test/features/resale/services/resale_prompt_service_test.dart` -- Service unit tests
- `apps/mobile/test/features/resale/screens/resale_prompts_screen_test.dart` -- Screen widget tests

### Modified Files
- `apps/api/src/main.js` -- Added resalePromptService import, instantiation in createRuntime, destructuring in handleRequest, and 4 resale prompt routes
- `apps/api/src/modules/notifications/notification-service.js` -- Added preferenceKey option to sendPushNotification
- `apps/api/src/modules/profiles/service.js` -- Added resale_prompts to ALLOWED_NOTIFICATION_KEYS and BOOLEAN_ONLY_NOTIFICATION_KEYS
- `apps/mobile/lib/src/core/networking/api_client.dart` -- Added 4 resale prompt API methods
- `apps/mobile/lib/src/features/home/screens/home_screen.dart` -- Added resale prompt banner and monthly evaluation trigger
- `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart` -- Added Resale Prompts toggle to kBooleanNotificationCategories and kNotificationCategories
- `apps/mobile/test/features/home/screens/home_screen_test.dart` -- Added 4 resale banner widget tests
- `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart` -- Added 4 resale toggle tests, fixed event reminders toggle index and scroll

## Change Log

- 2026-03-19: Implemented Story 13.2 -- Monthly Resale Prompts. Added resale_prompts table (migration 037), resale prompt service with candidate identification and notification delivery, 4 API endpoints, ResalePrompt model, ResalePromptService, ResalePromptsScreen, Home screen banner, notification preferences toggle. 39 new API tests (1342 total), 31 new Flutter tests (1761 total). All tests passing.
