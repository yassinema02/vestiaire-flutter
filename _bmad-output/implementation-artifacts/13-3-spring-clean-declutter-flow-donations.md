# Story 13.3: Spring Clean Declutter Flow & Donations

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want a guided process to review all my unworn clothes and decide what to keep, sell, or donate,
so that doing a wardrobe clean-out is structured and easy.

## Acceptance Criteria

1. Given I am on the Analytics Dashboard or Wardrobe screen, when I see my Wardrobe Health Score section, then I see a "Spring Clean" button (or entry point) that initiates the guided declutter flow. The button is visible to ALL users (free-tier). The button text reads "Spring Clean" with an `Icons.cleaning_services` icon. (FR-HLT-05)

2. Given I initiate the Spring Clean mode, when the Spring Clean screen loads, then the system fetches all my neglected items (`neglect_status = 'neglected'`, i.e., not worn in 180+ days) that have `resale_status IS NULL` (not already listed/sold/donated). Items are presented one at a time in a card-based swipe interface. Each card shows: item image (full width, 300px height), item name, category, brand (if available), "Not worn in {days} days" label, estimated value (same depreciation formula as Story 13.2), and three action buttons: "Keep", "Sell", "Donate". (FR-HLT-05)

3. Given I am reviewing an item in the Spring Clean flow, when I tap "Keep", then the item is marked as reviewed and skipped (no status change). The next item card appears with a slide animation. A running tally at the top shows "Reviewed X of Y items". (FR-HLT-05)

4. Given I am reviewing an item in the Spring Clean flow, when I tap "Sell", then the item's `resale_status` is updated to `'listed'` via the existing `PATCH /v1/items/:id/resale-status` endpoint pattern, and the user is given the option to generate a resale listing (navigate to `ResaleListingScreen` after the Spring Clean session ends). The item is added to a "sell queue" displayed in the session summary. (FR-HLT-05)

5. Given I am reviewing an item in the Spring Clean flow, when I tap "Donate", then a `donation_log` entry is created via `POST /v1/donations` with the item ID, estimated value, and date. The item's `resale_status` is updated to `'donated'`. An optional charity/organization name can be entered via a quick text field in a bottom sheet before confirming. The item is added to a "donated" list displayed in the session summary. (FR-HLT-05, FR-DON-01, FR-DON-02, FR-DON-05)

6. Given I have completed reviewing all items (or tapped "Finish" to end early), when the session summary screen appears, then I see: total items reviewed, items kept, items marked for sale (with "Generate Listings" CTA button navigating to ResalePromptsScreen or individual ResaleListingScreen), items donated (with total estimated donation value), and an updated Wardrobe Health Score preview (re-fetched to show improvement). (FR-HLT-05, FR-DON-05)

7. Given I have donated items through the Spring Clean flow or the item detail screen, when I navigate to my Profile, then I can tap "Donation History" to see a `DonationHistoryScreen` listing all donated items with: item image thumbnail, item name, charity/organization (if provided), date, and estimated value. The screen shows a summary card at the top: total items donated, total estimated value. (FR-DON-03)

8. Given I have donated 20 or more cumulative items (across all donation methods: Spring Clean, item detail "Mark as Donated"), when the donation is recorded, then the API checks badge eligibility via `badgeService.checkAndAward(authContext, 'generous_giver')` and the "Generous Giver" badge is awarded. The `check_badge_eligibility` function is updated to count items with `resale_status = 'donated'` and items in `donation_log`, using whichever gives the higher count. (FR-DON-04, FR-GAM-04)

9. Given the `donation_log` table does not yet exist, when migration 038 is applied, then it creates `app_public.donation_log` with columns: `id UUID PK DEFAULT gen_random_uuid()`, `profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE`, `charity_name TEXT DEFAULT NULL`, `estimated_value NUMERIC(10,2) DEFAULT 0`, `donation_date DATE DEFAULT CURRENT_DATE`, `created_at TIMESTAMPTZ DEFAULT now()`. RLS is enabled. Index on `(profile_id, created_at DESC)`. (FR-DON-02)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1342+ API tests, 1761+ Flutter tests) and new tests cover: donation_log migration, donation API endpoints, Spring Clean screen (card display, keep/sell/donate actions, session summary), DonationHistoryScreen, badge function update for generous_giver, and integration with existing resale flows.

## Tasks / Subtasks

- [x] Task 1: Database migration for `donation_log` table and badge function update (AC: 8, 9)
  - [x] 1.1: Create `infra/sql/migrations/038_donation_log.sql`. Create `app_public.donation_log` table: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE`, `charity_name TEXT DEFAULT NULL`, `estimated_value NUMERIC(10,2) DEFAULT 0`, `donation_date DATE DEFAULT CURRENT_DATE`, `created_at TIMESTAMPTZ DEFAULT now()`. Enable RLS: `ALTER TABLE app_public.donation_log ENABLE ROW LEVEL SECURITY`. Add RLS policy: `CREATE POLICY donation_log_user_policy ON app_public.donation_log FOR ALL USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`. Add index: `CREATE INDEX idx_donation_log_profile ON app_public.donation_log(profile_id, created_at DESC)`. Add index: `CREATE INDEX idx_donation_log_item ON app_public.donation_log(item_id)`.
  - [x] 1.2: In the same migration, update the `app_public.check_badge_eligibility` function (or `evaluate_badges` depending on current naming -- check migration 019 and 023 for the actual function name) to replace the placeholder logic for `generous_giver`. The check should be: `SELECT COUNT(*) >= 20 INTO v_earned FROM app_public.donation_log WHERE profile_id = p_profile_id`. This counts actual donation_log entries (not just resale_status = 'donated') because donation_log is the canonical donation record. Use `CREATE OR REPLACE FUNCTION` -- copy the full function body from the most recent version (migration 023 or 037), replacing ONLY the `generous_giver` case.
  - [x] 1.3: Add a SQL comment at the top: `-- Migration 038: Donation log table and generous_giver badge eligibility. Story 13.3: Spring Clean Declutter Flow & Donations. FR-DON-01, FR-DON-02, FR-DON-03, FR-DON-04, FR-DON-05, FR-HLT-05`.

- [x] Task 2: API -- Create donation repository (AC: 5, 7, 8)
  - [x] 2.1: Create `apps/api/src/modules/resale/donation-repository.js` with `createDonationRepository({ pool })`. Follow the exact factory pattern used by `resale-history-repository.js`.
  - [x] 2.2: Implement `async createDonation(authContext, { itemId, charityName, estimatedValue, donationDate })`. Steps: (a) acquire client from pool, (b) set RLS context via `set_config('app.current_user_id', authContext.userId, true)`, (c) INSERT into `app_public.donation_log`, (d) return the inserted row mapped to camelCase: `{ id, profileId, itemId, charityName, estimatedValue, donationDate, createdAt }`. (e) Release client in finally block.
  - [x] 2.3: Implement `async listDonations(authContext, { limit = 50, offset = 0 })`. Query: `SELECT dl.*, i.name as item_name, i.photo_url as item_photo_url, i.category as item_category, i.brand as item_brand FROM app_public.donation_log dl JOIN app_public.items i ON dl.item_id = i.id ORDER BY dl.created_at DESC LIMIT $1 OFFSET $2`. Return array of mapped rows with camelCase keys.
  - [x] 2.4: Implement `async getDonationSummary(authContext)`. Query: `SELECT COUNT(*) as total_donated, COALESCE(SUM(estimated_value), 0) as total_value FROM app_public.donation_log`. Return `{ totalDonated: number, totalValue: number }`.

- [x] Task 3: API -- Create `POST /v1/donations` and `GET /v1/donations` endpoints (AC: 5, 7)
  - [x] 3.1: Add route `POST /v1/donations` to `apps/api/src/main.js`. Requires authentication. Reads body `{ itemId, charityName?, estimatedValue?, donationDate? }`. Validates `itemId` is present (400 if missing). Fetches the item via `itemRepo.getItem(authContext, itemId)` -- return 404 if not found. Validates the item is eligible for donation: `resale_status` must be NULL or 'listed' (not 'sold' or already 'donated') -- return 409 if ineligible. Calls `donationRepository.createDonation(authContext, { itemId, charityName, estimatedValue, donationDate })`. Updates item `resale_status` to `'donated'` via `itemRepo.updateItem(authContext, itemId, { resaleStatus: 'donated' })`. After success, check badge eligibility best-effort: `badgeService.checkAndAward(authContext, 'generous_giver')`. Returns 201 with `{ donation, item }`.
  - [x] 3.2: Add route `GET /v1/donations` to `apps/api/src/main.js`. Requires authentication. Accepts query params: `limit` (default 50), `offset` (default 0). Calls `donationRepository.listDonations(authContext, { limit, offset })` and `donationRepository.getDonationSummary(authContext)` in parallel. Returns 200 with `{ donations: [...], summary: { totalDonated, totalValue } }`.
  - [x] 3.3: Place both routes after the existing resale routes and before `notFound` in main.js.
  - [x] 3.4: Wire up `donationRepository` in `createRuntime()`: instantiate `createDonationRepository({ pool })` and add to the runtime object. Add to `handleRequest` destructuring.

- [x] Task 4: API -- Create Spring Clean session endpoint (AC: 2)
  - [x] 4.1: Add route `GET /v1/spring-clean/items` to `apps/api/src/main.js`. Requires authentication. Queries items eligible for Spring Clean: `SELECT i.*, (CURRENT_DATE - COALESCE(i.last_worn_date, i.created_at::date)) as days_unworn FROM app_public.items i WHERE i.neglect_status = 'neglected' AND i.resale_status IS NULL ORDER BY days_unworn DESC`. Returns 200 with `{ items: [...] }` where each item includes all standard `mapItemRow` fields plus `daysUnworn`. This is a FREE-TIER endpoint -- no premium gating.
  - [x] 4.2: For each item, compute estimated value using the same depreciation formula from Story 13.2: `Math.round(purchasePrice * depreciationFactor)` where depreciationFactor is 0.4 for 20+ wears, 0.5 for 6-19, 0.6 for 1-5, 0.7 for 0 wears. Items without `purchase_price` get default estimated value of 10. Minimum 1. Include `estimatedValue` in each item's response.

- [x] Task 5: Mobile -- Create DonationLog model (AC: 7)
  - [x] 5.1: Create `apps/mobile/lib/src/features/resale/models/donation_log.dart` with classes: `DonationLogEntry` (fields: `String id`, `String itemId`, `String? charityName`, `double estimatedValue`, `DateTime donationDate`, `DateTime createdAt`, `String? itemName`, `String? itemPhotoUrl`, `String? itemCategory`, `String? itemBrand`), `DonationSummary` (fields: `int totalDonated`, `double totalValue`). Each with `factory fromJson(Map<String, dynamic> json)`.

- [x] Task 6: Mobile -- Create DonationService (AC: 5, 7)
  - [x] 6.1: Create `apps/mobile/lib/src/features/resale/services/donation_service.dart` with `DonationService` class. Constructor accepts `ApiClient`.
  - [x] 6.2: Implement `Future<Map<String, dynamic>?> createDonation({ required String itemId, String? charityName, double? estimatedValue })` that calls `_apiClient.authenticatedPost("/v1/donations", body: { "itemId": itemId, "charityName": charityName, "estimatedValue": estimatedValue })`. Returns response on success, null on non-409 error. Throws `StatusTransitionException` (reuse from `resale_history_service.dart`) on 409.
  - [x] 6.3: Implement `Future<Map<String, dynamic>?> fetchDonations({ int limit = 50, int offset = 0 })` that calls `_apiClient.authenticatedGet("/v1/donations?limit=$limit&offset=$offset")`. Returns parsed map with `donations` and `summary`. Returns null on error.
  - [x] 6.4: Add `Future<Map<String, dynamic>> createDonationEntry(Map<String, dynamic> body)` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedPost("/v1/donations", body: body)`.
  - [x] 6.5: Add `Future<Map<String, dynamic>> getDonations({int limit = 50, int offset = 0})` to ApiClient. Calls `authenticatedGet("/v1/donations?limit=$limit&offset=$offset")`.
  - [x] 6.6: Add `Future<Map<String, dynamic>> getSpringCleanItems()` to ApiClient. Calls `authenticatedGet("/v1/spring-clean/items")`.

- [x] Task 7: Mobile -- Create SpringCleanScreen (AC: 1, 2, 3, 4, 5, 6)
  - [x] 7.1: Create `apps/mobile/lib/src/features/resale/screens/spring_clean_screen.dart` with a `SpringCleanScreen` StatefulWidget. Constructor accepts `ApiClient apiClient` and optional `DonationService? donationService` and `ResaleHistoryService? resaleHistoryService`.
  - [x] 7.2: On `initState`, fetch eligible items from `GET /v1/spring-clean/items`. Store the list in state. Show loading indicator during fetch. Use `mounted` guard before `setState`.
  - [x] 7.3: Screen layout following Vibrant Soft-UI design system: (a) AppBar with "Spring Clean" title, `Icons.cleaning_services` icon, and a "Finish" text button to end the session early. (b) Progress indicator at the top: "Reviewing X of Y items" with a linear progress bar (#4F46E5). (c) The current item card (full-width, centered): item image (width: double.infinity, height: 300, `CachedNetworkImage`, rounded 16px corners), item name (20px bold, #1F2937), category and brand row (14px, #6B7280), "Not worn in {daysUnworn} days" label (14px, #F59E0B, with `Icons.schedule`), estimated value (16px bold, #22C55E, e.g., "Est. value: ~15 GBP"). (d) Three action buttons at the bottom in a row: "Keep" (outlined #6B7280, `Icons.favorite_border`), "Sell" (filled #4F46E5, `Icons.sell`), "Donate" (filled #8B5CF6 purple, `Icons.volunteer_activism`). Each button is 44px height minimum.
  - [x] 7.4: **Keep action:** Mark item as reviewed (local state only, no API call). Advance to next item with a slide-left animation (`AnimatedSwitcher` or `PageView`). Increment "kept" counter.
  - [x] 7.5: **Sell action:** Call `PATCH /v1/items/:id/resale-status` with `{ status: "listed" }` if item's current `resale_status` is NULL. This reuses the existing endpoint from Story 7.4 (which handles NULL -> listed transition -- but NOTE: the valid transition is `NULL -> listed` which is done by Story 7.3's generate listing flow, NOT the status endpoint. Instead, mark the item locally as "to sell" and add to sell queue. The actual listing generation will happen from the session summary. Do NOT change resale_status during the flow -- wait for listing generation). Add item to `_sellQueue` list in state. Advance to next item. Increment "sell" counter.
  - [x] 7.6: **Donate action:** Show a quick bottom sheet with: "Donate Item" title, optional `TextFormField` for charity/organization name (hint: "Charity or organization (optional)"), "Confirm Donation" button (#8B5CF6, full width). On confirm: call `POST /v1/donations` with itemId, charityName, estimatedValue. On success: advance to next item, increment "donated" counter. Use `mounted` guard.
  - [x] 7.7: **Session summary:** When all items are reviewed or "Finish" is tapped, navigate to a summary view (can be a new screen or replace the current content). Summary shows: (a) "Spring Clean Complete!" header with `Icons.celebration` (24px, #22C55E). (b) Stats row: items reviewed, items kept, items to sell, items donated. (c) If items to sell > 0: "Generate Resale Listings" CTA button (filled #4F46E5, `Icons.sell`) that navigates to `ResalePromptsScreen` or iterates through sell queue items to `ResaleListingScreen`. (d) If items donated > 0: total estimated donation value with "View Donation History" link. (e) "View Updated Health Score" button that navigates to AnalyticsDashboardScreen.
  - [x] 7.8: **Empty state:** When no neglected items are found, show: "Your wardrobe is in great shape! No neglected items to review." with `Icons.check_circle_outline` icon (48px, #22C55E). Include a "Back to Wardrobe" button.
  - [x] 7.9: Add `Semantics` labels: "Spring Clean review, item X of Y" on the progress bar, "Item [name], not worn in [days] days, estimated value [value]" on each card, "Keep this item" on keep button, "Sell this item" on sell button, "Donate this item" on donate button, "Spring Clean complete, [kept] kept, [sold] to sell, [donated] donated" on summary.

- [x] Task 8: Mobile -- Create DonationHistoryScreen (AC: 7)
  - [x] 8.1: Create `apps/mobile/lib/src/features/resale/screens/donation_history_screen.dart` with a `DonationHistoryScreen` StatefulWidget. Constructor accepts `ApiClient apiClient` and optional `DonationService? donationService`.
  - [x] 8.2: Screen layout: (a) AppBar with "Donation History" title and back button. (b) Summary card at top: "Items Donated" count (purple) and "Total Value" (formatted currency, #8B5CF6). Use `Card` with rounded corners. (c) Scrollable list of `DonationLogEntry` items: each row has item thumbnail (40x40 rounded, `CachedNetworkImage`), item name, charity name (if provided, 12px, #6B7280), date, estimated value. Status chip "Donated" in purple. (d) Empty state: "No donations yet. Use Spring Clean to declutter your wardrobe!" with `Icons.volunteer_activism` icon (32px, #9CA3AF).
  - [x] 8.3: On `initState`, call `_loadDonations()` which fetches from the service. Use `mounted` guard.
  - [x] 8.4: Add `Semantics` labels: "Donation history" on the screen, "Total items donated: X" on count, "Total donation value: X" on value, each entry labeled with item name and charity.

- [x] Task 9: Mobile -- Add Spring Clean entry point to HealthScoreSection and WardrobeScreen (AC: 1)
  - [x] 9.1: In `apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart`, add a "Spring Clean" button below the recommendation card. Style: outlined button with `Icons.cleaning_services` icon, text "Spring Clean", full width, #4F46E5 border color, 44px height. The button triggers a callback `onSpringCleanTap` (required callback parameter added to `HealthScoreSection` constructor). The button is ALWAYS visible (not gated by score tier), but is most compelling when the score is yellow or red.
  - [x] 9.2: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, pass an `onSpringCleanTap` callback to `HealthScoreSection` that navigates to `SpringCleanScreen`.
  - [x] 9.3: In `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`, add a "Spring Clean" icon button to the mini health bar (existing from Story 13.1). When tapped, navigate to `SpringCleanScreen`. Alternatively, add a compact "Spring Clean" button near the mini health bar.

- [x] Task 10: Mobile -- Add Donation History entry point to Profile screen (AC: 7)
  - [x] 10.1: Update `apps/mobile/lib/src/features/profile/screens/profile_screen.dart`. Add a new list tile below the existing "Resale History" entry: icon `Icons.volunteer_activism` (purple), title "Donation History", subtitle showing "X items donated" (fetched from a lightweight summary call). Tapping navigates to `DonationHistoryScreen`.
  - [x] 10.2: Fetch donation summary in `_loadUserStats()` or a separate method: call `GET /v1/donations?limit=0` (returns summary without donation entries) to populate the subtitle. Cache in state. On error, show subtitle "View your donations".

- [x] Task 11: API -- Unit tests for donation repository (AC: 5, 7, 8, 10)
  - [x] 11.1: Create `apps/api/test/modules/resale/donation-repository.test.js`:
    - `createDonation` inserts a row with correct profile_id, item_id, charity_name, estimated_value.
    - `createDonation` allows null charity_name.
    - `createDonation` defaults donation_date to today.
    - `listDonations` returns entries in reverse chronological order with item metadata.
    - `listDonations` respects limit and offset.
    - `listDonations` only returns entries for the authenticated user (RLS).
    - `getDonationSummary` returns correct count and total value.
    - `getDonationSummary` returns zeros when no donations exist.

- [x] Task 12: API -- Integration tests for donation and Spring Clean endpoints (AC: 2, 5, 7, 8, 10)
  - [x] 12.1: Create `apps/api/test/modules/resale/donation-endpoints.test.js`:
    - `POST /v1/donations` requires authentication (401).
    - `POST /v1/donations` creates donation and updates item resale_status to 'donated' (201).
    - `POST /v1/donations` returns 400 when itemId is missing.
    - `POST /v1/donations` returns 404 for non-existent item.
    - `POST /v1/donations` returns 409 for item with resale_status 'sold'.
    - `POST /v1/donations` returns 409 for item with resale_status 'donated'.
    - `POST /v1/donations` allows donation for item with resale_status NULL.
    - `POST /v1/donations` allows donation for item with resale_status 'listed'.
    - `POST /v1/donations` checks generous_giver badge on success.
    - `POST /v1/donations` stores charity_name when provided.
    - `GET /v1/donations` requires authentication (401).
    - `GET /v1/donations` returns donations list and summary.
    - `GET /v1/donations` respects limit and offset.
    - `GET /v1/spring-clean/items` requires authentication (401).
    - `GET /v1/spring-clean/items` returns neglected items with NULL resale_status.
    - `GET /v1/spring-clean/items` excludes items with resale_status 'listed', 'sold', 'donated'.
    - `GET /v1/spring-clean/items` includes estimatedValue for each item.
    - `GET /v1/spring-clean/items` returns empty array when no neglected items exist.

- [x] Task 13: Mobile -- Unit tests for DonationLog model (AC: 7, 10)
  - [x] 13.1: Create `apps/mobile/test/features/resale/models/donation_log_test.dart`:
    - `DonationLogEntry.fromJson()` parses all fields correctly.
    - `DonationLogEntry.fromJson()` handles null charityName and itemBrand.
    - `DonationSummary.fromJson()` parses totalDonated and totalValue.

- [x] Task 14: Mobile -- Unit tests for DonationService (AC: 5, 7, 10)
  - [x] 14.1: Create `apps/mobile/test/features/resale/services/donation_service_test.dart`:
    - `createDonation` calls API with correct body.
    - `createDonation` returns parsed response on success.
    - `createDonation` returns null on non-409 error.
    - `createDonation` throws StatusTransitionException on 409.
    - `fetchDonations` calls API with correct params.
    - `fetchDonations` returns null on error.

- [x] Task 15: Mobile -- Widget tests for SpringCleanScreen (AC: 1, 2, 3, 4, 5, 6, 10)
  - [x] 15.1: Create `apps/mobile/test/features/resale/screens/spring_clean_screen_test.dart`:
    - Shows loading indicator during fetch.
    - Displays item card with name, category, days unworn, estimated value.
    - Progress indicator shows "Reviewing X of Y items".
    - "Keep" button advances to next item.
    - "Sell" button adds item to sell queue and advances.
    - "Donate" button shows bottom sheet with charity field.
    - Donation confirmation calls API.
    - Session summary shows correct counts.
    - "Finish" button ends session early and shows summary.
    - Empty state shows when no neglected items found.
    - Semantics labels present on all interactive elements.

- [x] Task 16: Mobile -- Widget tests for DonationHistoryScreen (AC: 7, 10)
  - [x] 16.1: Create `apps/mobile/test/features/resale/screens/donation_history_screen_test.dart`:
    - Shows loading indicator during fetch.
    - Displays summary card with total donated and total value.
    - Displays donation entries with item name, charity, date, value.
    - Empty state shows when no donations.
    - Semantics labels present.

- [x] Task 17: Mobile -- Widget tests for HealthScoreSection Spring Clean button (AC: 1, 10)
  - [x] 17.1: Update `apps/mobile/test/features/analytics/widgets/health_score_section_test.dart`:
    - "Spring Clean" button is visible on HealthScoreSection.
    - Tapping "Spring Clean" triggers the callback.
  - [x] 17.2: Update `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`:
    - "Spring Clean" button on health score section navigates to SpringCleanScreen.
  - [x] 17.3: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`:
    - Spring Clean entry point is visible near the mini health bar.

- [x] Task 18: Regression testing (AC: all)
  - [x] 18.1: Run `flutter analyze` -- zero new issues.
  - [x] 18.2: Run `flutter test` -- all existing 1761+ Flutter tests plus new tests pass.
  - [x] 18.3: Run `npm --prefix apps/api test` -- all existing 1342+ API tests plus new tests pass.
  - [x] 18.4: Verify existing ResaleListingScreen (Story 7.3) still works.
  - [x] 18.5: Verify existing ResaleHistoryScreen (Story 7.4) still works.
  - [x] 18.6: Verify existing ResalePromptsScreen (Story 13.2) still works.
  - [x] 18.7: Verify existing HealthScoreSection (Story 13.1) still works with new button.
  - [x] 18.8: Verify existing WardrobeScreen mini health bar still works.
  - [x] 18.9: Verify existing Profile screen loads correctly with new Donation History entry.
  - [x] 18.10: Verify existing item detail screen "Mark as Donated" (Story 7.4) still works alongside new donation_log flow.

## Dev Notes

- This is the **third and FINAL story in Epic 13** (Circular Resale Triggers) and the **FINAL story in the ENTIRE Vestiaire project**. It completes the circular economy loop by providing a guided declutter experience that integrates all prior resale infrastructure (listing generation from 7.3, status tracking from 7.4, resale prompts from 13.2) with a new dedicated donation tracking system.
- This story implements **FR-HLT-05** (Spring Clean guided declutter mode), **FR-DON-01** (mark items as donated), **FR-DON-02** (donation_log with item reference, charity, date, estimated value), **FR-DON-03** (donation history on profile), and **FR-DON-05** (Spring Clean logs donations automatically).
- **FR-DON-04** (Generous Giver badge at 20+ donated) is implemented by updating the badge eligibility function. The badge definition already exists from Story 6.4 migration 019 with a placeholder FALSE check.
- **FREE-TIER feature.** Like the health score (13.1) and resale prompts (13.2), the Spring Clean flow is accessible to ALL users. The declutter flow drives engagement and funnels users toward the existing resale listing generator (Story 7.3), which has its own premium gating.

### Design Decision: donation_log vs resale_history for Donations

Story 7.4 already tracks donated items in `resale_history` with `type = 'donated'` and `sale_price = 0`. The new `donation_log` table adds charity/organization tracking and is the canonical donation record per the architecture (`donation_log` is listed in the data architecture). The two are complementary: `resale_history` tracks the item lifecycle (listed -> donated), while `donation_log` provides the detailed donation record. When an item is donated via Spring Clean, BOTH a `donation_log` entry AND a `resale_history` entry (via the existing `PATCH /v1/items/:id/resale-status` flow) should be created. However, to keep it simple: the `POST /v1/donations` endpoint creates only a `donation_log` entry and updates `resale_status` to 'donated'. The existing "Mark as Donated" flow from Story 7.4 creates a `resale_history` entry. Both methods set `resale_status = 'donated'`. The `generous_giver` badge should count `donation_log` entries as the canonical source.

### Design Decision: Sell Queue (Not Immediate Listing)

When a user taps "Sell" during Spring Clean, the item is NOT immediately listed for resale. Instead, it's added to a local sell queue. After the session ends, the user can generate listings for all queued items. This keeps the Spring Clean flow fast (no waiting for AI listing generation mid-flow) and gives the user a batch workflow. The sell queue is a local state list -- no API call is needed during the "Sell" action. The actual `resale_status` change to `'listed'` happens when the user generates a resale listing via Story 7.3's existing flow.

### Design Decision: Estimated Value Calculation (Reuse from 13.2)

The estimated value formula is identical to Story 13.2: `Math.round(purchasePrice * depreciationFactor)` where depreciation factors are 0.7 (0 wears), 0.6 (1-5 wears), 0.5 (6-19 wears), 0.4 (20+ wears). Default 10 for items without purchase_price. Minimum 1. This formula is computed server-side in the `GET /v1/spring-clean/items` endpoint. Consider extracting the depreciation logic into a shared utility function in `apps/api/src/modules/resale/` to avoid duplication with `resale-prompt-service.js`.

### Design Decision: Spring Clean Entry Points

The Spring Clean flow is accessible from two places: (1) the HealthScoreSection on the Analytics Dashboard (primary entry via a dedicated button), and (2) the WardrobeScreen near the mini health bar (secondary entry). This follows the pattern established in Story 13.1 where the health score is surfaced in both locations. The Analytics Dashboard is the primary context since the health score motivates decluttering.

### Design Decision: Donation History Separate from Resale History

The Profile screen gets a separate "Donation History" entry point alongside the existing "Resale History" (Story 7.4). Donations are a distinct action from resale (different motivation, different metrics). Combining them would dilute both. The DonationHistoryScreen shows only donation_log entries with charity details, while ResaleHistoryScreen shows sales and earnings.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/038_donation_log.sql` (donation_log table, badge function update)
  - `apps/api/src/modules/resale/donation-repository.js` (CRUD for donation log)
  - `apps/api/test/modules/resale/donation-repository.test.js`
  - `apps/api/test/modules/resale/donation-endpoints.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/resale/models/donation_log.dart` (DonationLogEntry, DonationSummary)
  - `apps/mobile/lib/src/features/resale/services/donation_service.dart` (DonationService)
  - `apps/mobile/lib/src/features/resale/screens/spring_clean_screen.dart` (SpringCleanScreen)
  - `apps/mobile/lib/src/features/resale/screens/donation_history_screen.dart` (DonationHistoryScreen)
  - `apps/mobile/test/features/resale/models/donation_log_test.dart`
  - `apps/mobile/test/features/resale/services/donation_service_test.dart`
  - `apps/mobile/test/features/resale/screens/spring_clean_screen_test.dart`
  - `apps/mobile/test/features/resale/screens/donation_history_screen_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add POST /v1/donations, GET /v1/donations, GET /v1/spring-clean/items routes; wire donationRepository in createRuntime and handleRequest)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add createDonationEntry, getDonations, getSpringCleanItems methods)
  - `apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart` (add Spring Clean button with onSpringCleanTap callback)
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (pass onSpringCleanTap callback to HealthScoreSection)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (add Spring Clean entry point near mini health bar)
  - `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (add Donation History entry point)
  - `apps/mobile/test/features/analytics/widgets/health_score_section_test.dart` (add Spring Clean button tests)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add Spring Clean navigation test)
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (add Spring Clean entry point test)

### Technical Requirements

- **New API endpoints:**
  - `POST /v1/donations` -- creates donation_log entry and updates item resale_status. Accepts `{ itemId, charityName?, estimatedValue?, donationDate? }`. Returns 201 with `{ donation, item }`. Requires authentication. No premium gating.
  - `GET /v1/donations` -- returns donation history and summary. Accepts `limit`, `offset` query params. Returns `{ donations: [...], summary: { totalDonated, totalValue } }`.
  - `GET /v1/spring-clean/items` -- returns neglected items eligible for Spring Clean with estimated values. Returns `{ items: [...] }`. No premium gating.
- **Database table:** `donation_log` in `app_public` schema with RLS. FK to `profiles` and `items`.
- **Badge function update:** `check_badge_eligibility` (or `evaluate_badges`) -- replace placeholder logic for `generous_giver` with real query against `donation_log`.
- **Estimated value formula:** Same as Story 13.2. `Math.round(purchasePrice * depreciationFactor)`, minimum 1, default 10. Consider extracting to shared utility.
- **No new mobile dependencies.** Uses existing packages: `CachedNetworkImage`, `intl` for formatting.
- **No AI calls.** This story is purely CRUD, UI flow, and data presentation.

### Architecture Compliance

- **Server authority for donations:** Donation records are created server-side. The mobile client sends the donation request; the API validates, persists, and updates item status.
- **Database boundary owns canonical state:** `donation_log` stores the complete donation record. RLS enforces user-scoped access.
- **Mobile boundary owns presentation:** `SpringCleanScreen` and `DonationHistoryScreen` handle all presentation: card swipe, progress tracking, session summary, history list.
- **Epic 13 component mapping:** Architecture specifies `mobile/features/resale`, `api/modules/resale`, `api/modules/notifications` for Epic 13. This story correctly uses `mobile/features/resale` and `api/modules/resale`. Notifications are not needed (no push notification for donations).
- **Badge checks are best-effort.** The `generous_giver` badge check after donation is wrapped in try/catch and does not block the response.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `pg` (via pool), existing badge service, existing item repository.
- **Mobile:** No new dependencies. Uses existing `CachedNetworkImage` for thumbnails, `intl` for currency formatting. The card swipe UI uses Flutter's built-in `AnimatedSwitcher` or `PageView` -- no swiping library needed.

### File Structure Requirements

- `donation-repository.js` goes in `apps/api/src/modules/resale/` alongside existing `resale-listing-service.js`, `resale-history-repository.js`, and `resale-prompt-service.js`.
- Mobile donation files go in the existing `apps/mobile/lib/src/features/resale/` directory.
- `SpringCleanScreen` goes in `apps/mobile/lib/src/features/resale/screens/` -- it's a declutter/resale flow.
- `DonationHistoryScreen` goes in `apps/mobile/lib/src/features/resale/screens/`.
- Migration file: `038_donation_log.sql` follows sequential numbering after `037_resale_prompts.sql`.
- Test files mirror source structure under `apps/api/test/modules/resale/` and `apps/mobile/test/features/resale/`.

### Testing Requirements

- **Donation repository unit tests** must verify: entry creation with correct fields, null charity_name handling, default donation_date, chronological listing with item metadata, pagination, RLS enforcement, summary with correct count and total, zeros when no donations.
- **Endpoint integration tests** must verify: authentication on all 3 endpoints, donation creation with item status update, validation (missing itemId, non-existent item, invalid status transitions), charity_name storage, badge check on donation, donation history with summary, pagination, Spring Clean items (neglected + NULL resale_status only, includes estimatedValue, empty when no neglected items).
- **Mobile model tests** must verify: JSON parsing for DonationLogEntry and DonationSummary, null handling.
- **Mobile service tests** must verify: correct API calls, response parsing, error handling, StatusTransitionException on 409.
- **SpringCleanScreen widget tests** must verify: loading state, item card display, progress indicator, keep/sell/donate actions, donation bottom sheet, session summary, finish early, empty state, semantics.
- **DonationHistoryScreen widget tests** must verify: loading state, summary display, donation list, empty state, semantics.
- **HealthScoreSection tests** must verify: Spring Clean button visibility, callback trigger.
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1761+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1342+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 13.2** (done) established: `resale-prompt-service.js` with candidate identification using neglect_status and resale_status filters, estimated price depreciation formula, `ResalePromptsScreen`, Home screen banner. Migration 037. Test baselines after 13.2: **1342 API tests, 1761 Flutter tests.** The estimated value formula and candidate selection criteria are reused in this story.
- **Story 13.1** (done) established: `GET /v1/analytics/wardrobe-health` endpoint (free-tier), `HealthScoreSection` widget with circular score ring and `onSpringCleanTap` callback slot (to be added by this story), mini health bar on WardrobeScreen. Test baselines after 13.1: 1303 API tests, 1730 Flutter tests.
- **Story 7.4** (done) established: `PATCH /v1/items/:id/resale-status` with status transition validation (null->donated is valid, sold->donated is 409), `resale_history` table (migration 023), `ResaleHistoryService` with `StatusTransitionException`, `ResaleHistoryScreen`, "Mark as Donated" on item detail screen. The existing "Mark as Donated" flow creates `resale_history` entries. This story adds `donation_log` as the canonical donation record.
- **Story 7.3** (done) established: `ResaleListingScreen`, `POST /v1/resale/generate`, resale_status = 'listed' on generation. The Spring Clean "Sell" action funnels users to this screen after the session.
- **Story 6.4** (done) established: `badgeService.checkAndAward(authContext, badgeKey)`, `badges` table with `generous_giver` badge definition (key: 'generous_giver', name: 'Generous Giver', description: 'Donate 20 or more items', icon_name: 'volunteer_activism', icon_color: '#8B5CF6', category: 'special'). The `check_badge_eligibility` function has a placeholder FALSE for generous_giver. This story replaces it with a real check against `donation_log`.
- **Story 2.7** (done) established: `computeNeglectStatus(row)`, `NEGLECT_THRESHOLD_DAYS = 180`, `neglect_status` field on items. The Spring Clean screen uses `neglect_status = 'neglected'` to identify eligible items.
- **`createRuntime()` currently returns (as of Story 13.2, ~35 services).** This story adds `donationRepository`.
- **`handleRequest` destructuring** includes all services. This story adds `donationRepository`.
- **`mapError` function** handles 400, 401, 403, 404, 409, 429, 500, 503. No changes needed.
- **Key patterns from prior stories:**
  - Factory pattern for all API repositories: `createXxxRepository({ pool })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Best-effort for non-critical operations (try/catch, do not break primary flow).
  - Bottom sheet pattern: used in wear logging, mark-as-sold, and now donate-with-charity.
  - StatusTransitionException for 409 errors (reuse from ResaleHistoryService).
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `resale_status`, `created_at`, `updated_at`.
- **Current test baselines (from Story 13.2):** 1342 API tests, 1761 Flutter tests.
- **Resale feature module directory structure after this story:**
  ```
  apps/mobile/lib/src/features/resale/
  ├── models/
  │   ├── donation_log.dart (NEW)
  │   ├── resale_history.dart (Story 7.4)
  │   ├── resale_listing.dart (Story 7.3)
  │   └── resale_prompt.dart (Story 13.2)
  ├── screens/
  │   ├── donation_history_screen.dart (NEW)
  │   ├── resale_history_screen.dart (Story 7.4)
  │   ├── resale_listing_screen.dart (Story 7.3)
  │   ├── resale_prompts_screen.dart (Story 13.2)
  │   └── spring_clean_screen.dart (NEW)
  ├── services/
  │   ├── donation_service.dart (NEW)
  │   ├── resale_history_service.dart (Story 7.4)
  │   ├── resale_listing_service.dart (Story 7.3)
  │   └── resale_prompt_service.dart (Story 13.2)
  └── widgets/
      └── earnings_chart.dart (Story 7.4)
  ```

### Key Anti-Patterns to Avoid

- DO NOT change `resale_status` during the Spring Clean "Sell" action. The sell queue is local state only. The actual listing happens post-session via the existing resale listing flow (Story 7.3).
- DO NOT create a `donation_log` entry for the "Sell" action. Only "Donate" creates a donation_log entry.
- DO NOT call Gemini or any AI service. This story is purely CRUD and UI.
- DO NOT add premium gating to Spring Clean or donations. These are FREE-TIER features.
- DO NOT duplicate the estimated value formula. Extract to a shared utility or reuse from `resale-prompt-service.js`.
- DO NOT modify existing `resale_history` table or the `PATCH /v1/items/:id/resale-status` endpoint. Only add new endpoints.
- DO NOT block the response on badge checks. Wrap `badgeService.checkAndAward` in try/catch.
- DO NOT use `setState` inside async gaps without checking `mounted` first.
- DO NOT implement complex swipe gestures (Tinder-like) for the card interface. Use simple button taps with `AnimatedSwitcher` for card transitions. Keep it accessible.
- DO NOT store the sell queue server-side. It's ephemeral local state within the Spring Clean session.
- DO NOT create a separate API endpoint for "batch donate" or "batch sell". Each donation is a separate `POST /v1/donations` call. The sell queue items are handled individually post-session.
- DO NOT modify migration 019, 022, 023, or 037. Create a new migration 038 for `donation_log` and badge function update.
- DO NOT confuse `donation_log` with `resale_history`. They serve different purposes: `donation_log` is the canonical donation record with charity details, `resale_history` tracks the item lifecycle.
- DO NOT use negative or guilt-inducing language. Use encouraging language like "Great job decluttering!" not "You have too many clothes."

### Out of Scope

- **Server-side cron for Spring Clean reminders:** Not required. Users initiate Spring Clean manually.
- **Animated Tinder-style swipe gestures:** Simple button taps are sufficient and more accessible.
- **Donation receipt generation / tax documentation:** Out of scope for V1.
- **Integration with charity APIs:** Users enter charity name manually; no API lookup.
- **Gamification points for Spring Clean actions:** Not required by FRs. Badge (Generous Giver) covers the gamification aspect.
- **Seasonal Spring Clean reminders (push notifications):** Not required. The health score and resale prompts provide sufficient motivation.
- **Batch resale listing generation for sell queue:** Users generate listings one at a time via the existing ResaleListingScreen. Batch generation is a future enhancement.
- **Donation value receipt/summary export:** Not required for V1.

### References

- [Source: epics.md - Story 13.3: Spring Clean Declutter Flow & Donations]
- [Source: epics.md - Epic 13: Circular Resale Triggers]
- [Source: epics.md - FR-HLT-05: A "Spring Clean" guided declutter mode shall walk users through neglected items with keep/sell/donate options]
- [Source: epics.md - FR-DON-01: Users shall mark items as "Donated" from the item detail screen]
- [Source: epics.md - FR-DON-02: Donations shall be logged in donation_log with: item reference, charity/organization, date, estimated value]
- [Source: epics.md - FR-DON-03: Users shall view donation history on their profile]
- [Source: epics.md - FR-DON-04: Donating 20+ items shall unlock the "Generous Giver" badge]
- [Source: epics.md - FR-DON-05: The Spring Clean guided declutter flow shall log donations automatically]
- [Source: architecture.md - Data Architecture: resale_listings, resale_history, donation_log]
- [Source: architecture.md - Epic 13 Circular Resale Triggers -> mobile/features/resale, api/modules/resale, api/modules/notifications]
- [Source: architecture.md - Server authority for sensitive rules: resale state changes]
- [Source: architecture.md - check constraints for enumerations like resale_status]
- [Source: 13-2-monthly-resale-prompts.md - estimated value depreciation formula, candidate identification criteria, 1342 API tests, 1761 Flutter tests]
- [Source: 13-1-wardrobe-health-score.md - HealthScoreSection, mini health bar, GET /v1/analytics/wardrobe-health]
- [Source: 7-4-resale-status-history-tracking.md - PATCH /v1/items/:id/resale-status, resale_history, StatusTransitionException, Mark as Donated flow]
- [Source: 7-3-ai-resale-listing-generation.md - ResaleListingScreen, POST /v1/resale/generate]
- [Source: 6-4-badge-achievement-system.md - badgeService.checkAndAward, generous_giver badge placeholder, check_badge_eligibility function]
- [Source: 2-7-neglect-detection-badging.md - computeNeglectStatus, NEGLECT_THRESHOLD_DAYS = 180, neglect_status on items]
- [Source: apps/api/src/modules/resale/resale-prompt-service.js - estimated price formula to reuse]
- [Source: apps/api/src/modules/resale/resale-history-repository.js - repository factory pattern]
- [Source: apps/api/src/modules/badges/badge-service.js - checkAndAward method]
- [Source: apps/api/src/modules/items/repository.js - mapItemRow, updateItem, computeNeglectStatus]
- [Source: apps/api/src/main.js - createRuntime, handleRequest, mapError, route patterns]
- [Source: apps/mobile/lib/src/features/resale/ - existing resale module structure]
- [Source: apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart - HealthScoreSection to extend]
- [Source: apps/mobile/lib/src/features/profile/screens/profile_screen.dart - ProfileScreen with Resale History entry]
- [Source: infra/sql/migrations/019_badges.sql - generous_giver badge definition, check_badge_eligibility placeholder]
- [Source: infra/sql/migrations/023_resale_history.sql - updated badge function for circular_seller, circular_champion]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed Spring Clean screen tests: CachedNetworkImage causes pumpAndSettle to timeout in tests; resolved by using empty photoUrl in test data
- Fixed analytics dashboard tests: Spring Clean button added height to HealthScoreSection, requiring increased scroll offsets in existing tests (-600 -> -700 for neglected section, -1200 -> -1300 for brand value/premium sections)
- Fixed DonationHistoryScreen semantics test: multiple widgets matching "Blue Shirt" label; fixed by using more specific regex pattern

### Completion Notes List

- Task 1: Created migration 038 with donation_log table (RLS, indexes) and updated evaluate_badges function to count donation_log entries for generous_giver badge (>= 20)
- Task 2: Created donation-repository.js with createDonation, listDonations, getDonationSummary methods following exact factory pattern from resale-history-repository.js
- Task 3: Added POST /v1/donations (creates donation + updates resale_status to donated + checks generous_giver badge) and GET /v1/donations (returns donations list + summary) endpoints
- Task 4: Added GET /v1/spring-clean/items endpoint returning neglected items with NULL resale_status, including computeEstimatedPrice from resale-prompt-service.js (shared utility, no duplication)
- Task 5: Created DonationLogEntry and DonationSummary models with fromJson factories
- Task 6: Created DonationService with createDonation and fetchDonations methods; added createDonationEntry, getDonations, getSpringCleanItems to ApiClient
- Task 7: Created SpringCleanScreen with card-based review flow, Keep/Sell/Donate actions, donation bottom sheet, session summary, empty state, and semantics labels
- Task 8: Created DonationHistoryScreen with summary card, donation list with thumbnails, charity names, dates, values, empty state, and semantics labels
- Task 9: Added Spring Clean button to HealthScoreSection (onSpringCleanTap callback), wired navigation in AnalyticsDashboardScreen, added Spring Clean icon button near mini health bar in WardrobeScreen
- Task 10: Added Donation History list tile to ProfileScreen with donation count subtitle, separate from Resale History
- Task 11-12: Created 27 new API tests (8 repository unit tests + 19 integration tests)
- Task 13-17: Created 30 new Flutter tests (3 model + 6 service + 11 spring clean widget + 5 donation history widget + 2 health score section + 1 dashboard + 1 wardrobe screen + 1 spring clean entry)
- Task 18: Full regression pass - 1369 API tests, 1791 Flutter tests, flutter analyze zero new issues

### Change Log

- 2026-03-19: Implemented Story 13.3 - Spring Clean Declutter Flow & Donations (all 18 tasks complete)

### File List

**New files:**
- infra/sql/migrations/038_donation_log.sql
- apps/api/src/modules/resale/donation-repository.js
- apps/api/test/modules/resale/donation-repository.test.js
- apps/api/test/modules/resale/donation-endpoints.test.js
- apps/mobile/lib/src/features/resale/models/donation_log.dart
- apps/mobile/lib/src/features/resale/services/donation_service.dart
- apps/mobile/lib/src/features/resale/screens/spring_clean_screen.dart
- apps/mobile/lib/src/features/resale/screens/donation_history_screen.dart
- apps/mobile/test/features/resale/models/donation_log_test.dart
- apps/mobile/test/features/resale/services/donation_service_test.dart
- apps/mobile/test/features/resale/screens/spring_clean_screen_test.dart
- apps/mobile/test/features/resale/screens/donation_history_screen_test.dart

**Modified files:**
- apps/api/src/main.js (added import, donationRepository in createRuntime/handleRequest, 3 new routes)
- apps/mobile/lib/src/core/networking/api_client.dart (added createDonationEntry, getDonations, getSpringCleanItems)
- apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart (added onSpringCleanTap callback, Spring Clean button)
- apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart (added SpringCleanScreen import, onSpringCleanTap navigation)
- apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart (added SpringCleanScreen import, Spring Clean icon near mini health bar)
- apps/mobile/lib/src/features/profile/screens/profile_screen.dart (added DonationHistoryScreen import, donation history tile with summary)
- apps/mobile/test/features/analytics/widgets/health_score_section_test.dart (added Spring Clean button tests)
- apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart (added Spring Clean navigation test, fixed scroll offsets)
- apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart (added Spring Clean entry point test)
