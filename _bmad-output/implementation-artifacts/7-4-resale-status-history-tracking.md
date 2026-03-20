# Story 7.4: Resale Status & History Tracking

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to track the lifecycle of items I am selling -- from listed to sold -- and view my resale history with total earnings,
so that I can see how much money I've recouped from my wardrobe.

## Acceptance Criteria

1. Given I am on the item detail screen for an item with `resale_status = 'listed'`, when I tap "Mark as Sold", then a bottom sheet appears where I enter the sale price (required, numeric, > 0) and optional sale date (defaults to today). On confirmation, the API endpoint `PATCH /v1/items/:id/resale-status` is called with `{ status: "sold", salePrice: number, saleCurrency: string, saleDate: string }`. The API updates `items.resale_status` to `'sold'` and inserts a row into `resale_history` with the sale details. The item detail screen refreshes to reflect the new status. (FR-RSL-04, FR-RSL-10)

2. Given I am on the item detail screen for an item with `resale_status = 'listed'`, when I tap "Mark as Donated", then a confirmation dialog appears. On confirmation, the API endpoint `PATCH /v1/items/:id/resale-status` is called with `{ status: "donated" }`. The API updates `items.resale_status` to `'donated'` and inserts a row into `resale_history` with `sale_price = 0` and `type = 'donated'`. (FR-RSL-04, FR-RSL-10)

3. Given I am on the item detail screen for any item (regardless of current `resale_status`), when I tap "Mark as Donated", then the same donation flow as AC#2 applies. Items with NULL or 'listed' resale_status can be donated. Items with 'sold' status cannot be donated (button hidden). (FR-RSL-04)

4. Given I have sold or donated items, when I navigate to the Profile screen and tap "Resale History", then a ResaleHistoryScreen loads showing: a summary card at the top with total items sold, total items donated, and total earnings (sum of all sale prices), followed by a chronological list of resale history entries. Each entry shows: item image thumbnail, item name, status badge ("Sold" in green / "Donated" in purple), sale price (for sold items), and date. (FR-RSL-07)

5. Given I am on the ResaleHistoryScreen, when I have at least one sold item, then an earnings chart is displayed below the summary card showing monthly earnings aggregated over time as a bar chart. Months with zero earnings are shown as empty bars. The chart shows the last 6 months. (FR-RSL-08)

6. Given I mark an item as sold and the total number of items with `resale_status = 'sold'` reaches 10 or more, when the status update succeeds, then the API checks badge eligibility via `badgeService.checkAndAward(authContext, 'circular_champion')` and the "Circular Champion" badge is awarded. (FR-RSL-09)

7. Given I update an item's `resale_status` to 'sold' or 'donated', when the API processes the request, then it also ensures the `items` table is kept in sync: the `resale_status` column reflects the latest state, and the `resale_history` row references the item and the `resale_listings` entry (if one exists). (FR-RSL-10)

8. Given the `circular_champion` badge check function in migration 019 currently returns `v_earned := FALSE` (placeholder), when this story's migration runs, then the function is updated to count items with `resale_status = 'sold'` and award the badge at >= 10. The `circular_seller` badge check is also updated to count items with `resale_status IN ('listed', 'sold', 'donated')` and award at >= 1. (FR-RSL-09, FR-GAM-04)

9. Given I am on the Profile screen, when I view my stats, then the profile summary includes "Items Sold" count and "Total Earnings" amount fetched from `resale_history`. (FR-RSL-07)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (666+ API tests, 1123+ Flutter tests) and new tests cover: resale status update API endpoint, resale history creation, resale history listing API, earnings aggregation, ResaleHistoryScreen widget, earnings chart, profile integration, badge function updates, and item detail screen status transitions.

## Tasks / Subtasks

- [x] Task 1: Database migration for `resale_history` table and badge function updates (AC: 1, 2, 7, 8)
  - [x]1.1: Create `infra/sql/migrations/023_resale_history.sql`. Create `app_public.resale_history` table: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE`, `resale_listing_id UUID REFERENCES app_public.resale_listings(id) ON DELETE SET NULL` (nullable -- donated items may not have a listing), `type TEXT NOT NULL CHECK (type IN ('sold', 'donated'))`, `sale_price NUMERIC(10,2) DEFAULT 0`, `sale_currency TEXT DEFAULT 'GBP'`, `sale_date DATE DEFAULT CURRENT_DATE`, `created_at TIMESTAMPTZ DEFAULT now()`. Add RLS: `CREATE POLICY resale_history_user_policy ON app_public.resale_history FOR ALL USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`. Add indexes: `CREATE INDEX idx_resale_history_profile ON app_public.resale_history(profile_id, created_at DESC)`, `CREATE INDEX idx_resale_history_item ON app_public.resale_history(item_id)`.
  - [x]1.2: In the same migration, update the `app_public.check_badge_eligibility` function to replace the placeholder logic for `circular_seller` and `circular_champion`. For `circular_seller`: `SELECT COUNT(*) >= 1 INTO v_earned FROM app_public.items WHERE profile_id = p_profile_id AND resale_status IS NOT NULL`. For `circular_champion`: `SELECT COUNT(*) >= 10 INTO v_earned FROM app_public.items WHERE profile_id = p_profile_id AND resale_status = 'sold'`. Use `CREATE OR REPLACE FUNCTION` to update the existing function -- copy the full function body from migration 019, replacing ONLY the two badge cases.
  - [x]1.3: Add a SQL comment at the top: `-- Migration 023: Resale history table and badge eligibility updates. Story 7.4: Resale Status & History Tracking. FR-RSL-04, FR-RSL-07, FR-RSL-08, FR-RSL-09, FR-RSL-10`.

- [x] Task 2: API -- Create resale history repository (AC: 1, 2, 4, 5, 7)
  - [x]2.1: Create `apps/api/src/modules/resale/resale-history-repository.js` with `createResaleHistoryRepository({ pool })`. Follow the exact factory pattern used by other repositories (e.g., `apps/api/src/modules/items/repository.js`).
  - [x]2.2: Implement `async createHistoryEntry(authContext, { itemId, resaleListingId, type, salePrice, saleCurrency, saleDate })`. Steps: (a) acquire client from pool, (b) set RLS context via `set_config('app.current_user_id', authContext.userId, true)`, (c) INSERT into `app_public.resale_history`, (d) return the inserted row mapped to camelCase: `{ id, profileId, itemId, resaleListingId, type, salePrice, saleCurrency, saleDate, createdAt }`.
  - [x]2.3: Implement `async listHistory(authContext, { limit = 50, offset = 0 })`. Query: `SELECT rh.*, i.name as item_name, i.photo_url as item_photo_url, i.category as item_category, i.brand as item_brand FROM app_public.resale_history rh JOIN app_public.items i ON rh.item_id = i.id ORDER BY rh.created_at DESC LIMIT $1 OFFSET $2`. Return array of mapped rows.
  - [x]2.4: Implement `async getEarningsSummary(authContext)`. Query: `SELECT COUNT(*) FILTER (WHERE type = 'sold') as items_sold, COUNT(*) FILTER (WHERE type = 'donated') as items_donated, COALESCE(SUM(sale_price) FILTER (WHERE type = 'sold'), 0) as total_earnings FROM app_public.resale_history`. Return `{ itemsSold, itemsDonated, totalEarnings }`.
  - [x]2.5: Implement `async getMonthlyEarnings(authContext, { months = 6 })`. Query: `SELECT DATE_TRUNC('month', sale_date) as month, SUM(sale_price) as earnings FROM app_public.resale_history WHERE type = 'sold' AND sale_date >= (CURRENT_DATE - INTERVAL '1 month' * $1) GROUP BY DATE_TRUNC('month', sale_date) ORDER BY month ASC`. Return array of `{ month, earnings }`.

- [x] Task 3: API -- Create `PATCH /v1/items/:id/resale-status` endpoint (AC: 1, 2, 3, 6, 7)
  - [x]3.1: Add route `PATCH /v1/items/:id/resale-status` to `apps/api/src/main.js`. Place it near the existing item routes (after `PUT /v1/items/:id` and before resale routes). The route: authenticates via `requireAuth`, extracts `itemId` from URL path, reads body `{ status, salePrice?, saleCurrency?, saleDate? }`, validates `status` is one of `['sold', 'donated']` (return 400 if invalid), fetches the item via `itemRepo.getItem(authContext, itemId)` (return 404 if not found), validates the status transition is allowed (listed->sold, listed->donated, null->donated; reject sold->donated, donated->sold with 409 Conflict), calls `itemRepo.updateItem(authContext, itemId, { resaleStatus: status })`, creates a `resale_history` entry via `resaleHistoryRepo.createHistoryEntry(...)`, and returns 200 with `{ item: updatedItem, historyEntry }`.
  - [x]3.2: For `status = 'sold'`, validate `salePrice` is a positive number (return 400 if missing/invalid). Default `saleCurrency` to `'GBP'`. Default `saleDate` to today's date.
  - [x]3.3: For `status = 'sold'`, look up the most recent `resale_listings` entry for this item: `SELECT id FROM app_public.resale_listings WHERE item_id = $1 ORDER BY created_at DESC LIMIT 1`. Pass the `resale_listing_id` to the history entry (nullable if no listing exists).
  - [x]3.4: After successful status update to 'sold', check badge eligibility best-effort: `badgeService.checkAndAward(authContext, 'circular_champion')`. Wrap in try/catch -- do not block response.
  - [x]3.5: Wire up `resaleHistoryRepo` in `createRuntime()`: instantiate `createResaleHistoryRepository({ pool })` and add to the runtime object. Add to `handleRequest` destructuring.

- [x] Task 4: API -- Create `GET /v1/resale/history` endpoint (AC: 4, 5, 9)
  - [x]4.1: Add route `GET /v1/resale/history` to `apps/api/src/main.js`. Authenticates via `requireAuth`. Accepts query params: `limit` (default 50), `offset` (default 0). Calls `resaleHistoryRepo.listHistory(authContext, { limit, offset })`, `resaleHistoryRepo.getEarningsSummary(authContext)`, and `resaleHistoryRepo.getMonthlyEarnings(authContext)`. Returns 200 with `{ history: [...], summary: { itemsSold, itemsDonated, totalEarnings }, monthlyEarnings: [...] }`.

- [x] Task 5: Mobile -- Create ResaleHistory model (AC: 4)
  - [x]5.1: Create `apps/mobile/lib/src/features/resale/models/resale_history.dart` with classes: `ResaleHistoryEntry` (fields: `String id`, `String itemId`, `String? resaleListingId`, `String type`, `double salePrice`, `String saleCurrency`, `DateTime saleDate`, `DateTime createdAt`, `String? itemName`, `String? itemPhotoUrl`, `String? itemCategory`, `String? itemBrand`), `ResaleEarningsSummary` (fields: `int itemsSold`, `int itemsDonated`, `double totalEarnings`), `MonthlyEarnings` (fields: `DateTime month`, `double earnings`). Each with `factory fromJson(Map<String, dynamic> json)`.

- [x] Task 6: Mobile -- Create ResaleHistoryService (AC: 4, 5)
  - [x]6.1: Create `apps/mobile/lib/src/features/resale/services/resale_history_service.dart` with `ResaleHistoryService` class. Constructor accepts `ApiClient`.
  - [x]6.2: Implement `Future<Map<String, dynamic>?> fetchHistory({ int limit = 50, int offset = 0 })` that calls `_apiClient.authenticatedGet("/v1/resale/history?limit=$limit&offset=$offset")`. Returns parsed map with `history`, `summary`, `monthlyEarnings` keys. Returns null on error.
  - [x]6.3: Implement `Future<Map<String, dynamic>?> updateResaleStatus(String itemId, { required String status, double? salePrice, String? saleCurrency, String? saleDate })` that calls `_apiClient.authenticatedPatch("/v1/items/$itemId/resale-status", body: { "status": status, ... })`. Returns the response on success, null on error. On 409, throws a `StatusTransitionException` so the UI can show an appropriate message.

- [x] Task 7: Mobile -- Create ResaleHistoryScreen (AC: 4, 5)
  - [x]7.1: Create `apps/mobile/lib/src/features/resale/screens/resale_history_screen.dart` with `ResaleHistoryScreen` StatefulWidget. Constructor accepts `ApiClient apiClient` and optional `ResaleHistoryService? resaleHistoryService`.
  - [x]7.2: Screen layout following Vibrant Soft-UI design system: (a) AppBar with "Resale History" title and back button. (b) Summary card at top: 3-stat row showing "Items Sold" (count, green), "Items Donated" (count, purple), "Total Earnings" (formatted currency, #4F46E5). Use `Card` with rounded corners and subtle elevation matching the design system. (c) Earnings chart section (see Task 8). (d) Scrollable list of `ResaleHistoryEntry` items: each row has item thumbnail (40x40 rounded, `CachedNetworkImage`), item name, status chip ("Sold" green / "Donated" purple), sale price (for sold items, formatted with currency), date. (e) Empty state: illustration + "No resale history yet. List items for sale from their detail screen." with a call-to-action.
  - [x]7.3: On `initState`, call `_loadHistory()` which fetches from the service and transitions from loading to success/error. Use `mounted` guard before `setState`.
  - [x]7.4: Add `Semantics` labels: "Resale history" on the screen, "Items sold: X" on sold count, "Total earnings: X" on earnings, each history entry labeled with item name and status.

- [x] Task 8: Mobile -- Create EarningsChart widget (AC: 5)
  - [x]8.1: Create `apps/mobile/lib/src/features/resale/widgets/earnings_chart.dart` with an `EarningsChart` StatelessWidget. Constructor accepts `List<MonthlyEarnings> data`. Do NOT add `fl_chart` or any charting library. Implement a simple custom-painted bar chart using `CustomPaint` + `CustomPainter`: (a) 6 vertical bars (one per month), equal width, height proportional to earnings relative to max. (b) Month labels below bars (abbreviated: "Jan", "Feb", etc.). (c) Earnings label above each bar (formatted currency, small text). (d) Bar color: #4F46E5 with rounded top corners. (e) Empty months show a thin baseline. (f) Overall height: 180px. (g) If no data, show "No earnings data yet" text.
  - [x]8.2: Add `Semantics` label: "Monthly earnings chart" on the widget, with each bar labeled "Month: X, Earnings: Y".

- [x] Task 9: Mobile -- Add "Mark as Sold" / "Mark as Donated" to item detail screen (AC: 1, 2, 3)
  - [x]9.1: Update `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart`. For items with `resaleStatus == 'listed'`: add two buttons below the existing "Regenerate Listing" button: "Mark as Sold" (green outlined, `Icons.attach_money`) and "Mark as Donated" (purple outlined, `Icons.volunteer_activism`). For items with `resaleStatus == null`: show only "Mark as Donated" button (items can be donated without being listed first).
  - [x]9.2: Implement `_showMarkAsSoldSheet()`: shows a `showModalBottomSheet` with: (a) title "Mark Item as Sold", (b) sale price `TextFormField` (numeric keyboard, required, prefix with currency symbol), (c) sale date `TextFormField` with date picker (defaults to today), (d) "Confirm Sale" button (green, full width). On confirm: call `resaleHistoryService.updateResaleStatus(item.id, status: 'sold', salePrice: price, saleDate: date)`, show success snackbar "Item marked as sold!", refresh item detail.
  - [x]9.3: Implement `_showDonateConfirmation()`: shows `showDialog` with: title "Donate Item", body "Mark this item as donated? This cannot be undone.", "Cancel" and "Donate" buttons. On confirm: call `resaleHistoryService.updateResaleStatus(item.id, status: 'donated')`, show success snackbar "Item marked as donated!", refresh item detail.
  - [x]9.4: For items with `resaleStatus == 'sold'`, show a read-only "Sold" badge/chip (green) and hide all action buttons (generate listing, mark as sold, mark as donated). For items with `resaleStatus == 'donated'`, show a "Donated" badge/chip (purple) and hide all action buttons.
  - [x]9.5: The `ResaleHistoryService` must be available on the item detail screen. Pass it through the constructor or instantiate it from the existing `ApiClient`. Add optional `ResaleHistoryService? resaleHistoryService` parameter to the item detail screen constructor, defaulting to creating one from `apiClient` if not provided.

- [x] Task 10: Mobile -- Add "Resale History" entry point to Profile screen (AC: 4, 9)
  - [x]10.1: Update `apps/mobile/lib/src/features/profile/screens/profile_screen.dart`. Add a new list tile / card in the profile actions section: icon `Icons.history`, title "Resale History", subtitle showing "X items sold - Y total earned" (fetched from a lightweight summary call or cached). Tapping navigates to `ResaleHistoryScreen`.
  - [x]10.2: Add a summary fetch in `_loadUserStats()` or a separate method that calls `GET /v1/resale/history?limit=0` (returns summary without history entries) to populate the subtitle. Cache in state. On error, show subtitle "View your resale activity".

- [x] Task 11: API -- Unit tests for resale history repository (AC: 1, 2, 4, 5, 7, 10)
  - [x]11.1: Create `apps/api/test/modules/resale/resale-history-repository.test.js`:
    - `createHistoryEntry` inserts a row with correct profile_id, item_id, type, sale_price.
    - `createHistoryEntry` links resale_listing_id when provided.
    - `createHistoryEntry` allows null resale_listing_id for donated items.
    - `listHistory` returns entries in reverse chronological order with item metadata.
    - `listHistory` respects limit and offset.
    - `listHistory` only returns entries for the authenticated user (RLS).
    - `getEarningsSummary` returns correct counts and total earnings.
    - `getEarningsSummary` returns zeros when no history exists.
    - `getMonthlyEarnings` returns monthly aggregations for the specified period.
    - `getMonthlyEarnings` excludes donated items from earnings.

- [x] Task 12: API -- Integration tests for resale status and history endpoints (AC: 1, 2, 3, 6, 10)
  - [x]12.1: Create `apps/api/test/modules/resale/resale-status-history.test.js`:
    - `PATCH /v1/items/:id/resale-status` requires authentication (401).
    - `PATCH /v1/items/:id/resale-status` with status 'sold' updates item and creates history entry.
    - `PATCH /v1/items/:id/resale-status` with status 'sold' requires salePrice > 0 (400).
    - `PATCH /v1/items/:id/resale-status` with status 'donated' updates item and creates history entry with price 0.
    - `PATCH /v1/items/:id/resale-status` returns 409 for invalid transitions (sold->donated).
    - `PATCH /v1/items/:id/resale-status` returns 404 for non-existent item.
    - `PATCH /v1/items/:id/resale-status` links resale_listing_id on sold.
    - `PATCH /v1/items/:id/resale-status` checks circular_champion badge on sold.
    - `GET /v1/resale/history` requires authentication (401).
    - `GET /v1/resale/history` returns history, summary, and monthlyEarnings.
    - `GET /v1/resale/history` respects limit and offset query params.

- [x] Task 13: Mobile -- Unit tests for ResaleHistory models (AC: 4, 10)
  - [x]13.1: Create `apps/mobile/test/features/resale/models/resale_history_test.dart`:
    - `ResaleHistoryEntry.fromJson()` parses all fields correctly.
    - `ResaleHistoryEntry.fromJson()` handles null optional fields (resaleListingId, itemBrand).
    - `ResaleEarningsSummary.fromJson()` parses counts and earnings.
    - `MonthlyEarnings.fromJson()` parses month and earnings.

- [x] Task 14: Mobile -- Unit tests for ResaleHistoryService (AC: 4, 10)
  - [x]14.1: Create `apps/mobile/test/features/resale/services/resale_history_service_test.dart`:
    - `fetchHistory` calls API with correct params and returns parsed data.
    - `fetchHistory` returns null on error.
    - `updateResaleStatus` sends correct body for sold status.
    - `updateResaleStatus` sends correct body for donated status.
    - `updateResaleStatus` throws StatusTransitionException on 409.

- [x] Task 15: Mobile -- Widget tests for ResaleHistoryScreen (AC: 4, 5, 10)
  - [x]15.1: Create `apps/mobile/test/features/resale/screens/resale_history_screen_test.dart`:
    - Shows loading indicator during fetch.
    - Displays summary card with items sold, donated, and earnings.
    - Displays history entries with item name, status chip, price, and date.
    - Displays earnings chart when sold items exist.
    - Shows empty state when no history exists.
    - Semantics labels present on summary and entries.

- [x] Task 16: Mobile -- Widget tests for EarningsChart (AC: 5, 10)
  - [x]16.1: Create `apps/mobile/test/features/resale/widgets/earnings_chart_test.dart`:
    - Renders chart with provided monthly data.
    - Shows "No earnings data yet" when data is empty.
    - Semantics label present.

- [x] Task 17: Mobile -- Widget tests for item detail screen resale status actions (AC: 1, 2, 3, 10)
  - [x]17.1: Update `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart`:
    - "Mark as Sold" button visible for items with resaleStatus 'listed'.
    - "Mark as Donated" button visible for items with resaleStatus 'listed' or null.
    - Buttons hidden for items with resaleStatus 'sold' or 'donated'.
    - "Sold" badge shown for sold items.
    - "Donated" badge shown for donated items.
    - Tapping "Mark as Sold" shows bottom sheet with price field.
    - Tapping "Mark as Donated" shows confirmation dialog.

- [x] Task 18: Regression testing (AC: all)
  - [x]18.1: Run `flutter analyze` -- zero new issues.
  - [x]18.2: Run `flutter test` -- all existing 1123+ tests plus new tests pass.
  - [x]18.3: Run `npm --prefix apps/api test` -- all existing 666+ API tests plus new tests pass.
  - [x]18.4: Verify existing item detail screen functionality is preserved (all existing buttons and actions still work).
  - [x]18.5: Verify existing resale listing generation (Story 7.3) still works.
  - [x]18.6: Verify profile screen loads correctly with the new "Resale History" entry.
  - [x]18.7: Verify wardrobe grid filtering by resale_status still works.

## Dev Notes

- This is the FOURTH and FINAL story in Epic 7 (Resale Integration & Subscription). It completes the resale lifecycle by adding status transitions (listed->sold, listed->donated, null->donated), a `resale_history` table, profile-level resale stats, an earnings chart, and badge eligibility updates.
- Story 7.3 (done) established the resale module: `resale-listing-service.js`, `resale_listings` table, `items.resale_status` column with CHECK constraint `('listed', 'sold', 'donated')`, the `POST /v1/resale/generate` endpoint, and mobile `features/resale/` directory with models, services, and screens.
- The `items.resale_status` column and its CHECK constraint already exist from migration 022. The allowed values (`'listed'`, `'sold'`, `'donated'`, NULL) are already enforced at the database level. This story only needs to add the `resale_history` table and update the badge function.
- The `resale_listings` table already exists. The `resale_history` table references it via `resale_listing_id` (nullable FK) to link a sale event to the listing that preceded it.

### Design Decision: Status Transition Rules

Valid transitions:
- `NULL -> 'donated'` (item donated without ever being listed)
- `'listed' -> 'sold'` (item sold after listing)
- `'listed' -> 'donated'` (item donated after listing)
- `NULL -> 'listed'` (handled by Story 7.3's generate listing flow, NOT this story)

Invalid transitions (return 409):
- `'sold' -> *` (sold is terminal)
- `'donated' -> *` (donated is terminal)
- `NULL -> 'sold'` (cannot sell without listing first)

### Design Decision: Earnings Chart Without External Library

To avoid adding a charting dependency (fl_chart, syncfusion, etc.), the earnings chart is implemented as a simple `CustomPaint` widget. This keeps the dependency tree lean and avoids version conflicts. The chart is a basic 6-month bar chart -- sufficient for the MVP. If more advanced charting is needed later (Epic 11 analytics), a dedicated charting library can be added then.

### Design Decision: Badge Function Update Strategy

Migration 019 created `check_badge_eligibility` with placeholder logic (`v_earned := FALSE`) for `circular_seller` and `circular_champion`. This migration uses `CREATE OR REPLACE FUNCTION` to update the function. The full function body from migration 019 must be copied and the two badge cases replaced. This is the standard pattern for updating PostgreSQL functions -- the function is atomic and the old version is fully replaced.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/023_resale_history.sql` (resale_history table, badge function updates)
  - `apps/api/src/modules/resale/resale-history-repository.js` (CRUD for resale history)
  - `apps/api/test/modules/resale/resale-history-repository.test.js`
  - `apps/api/test/modules/resale/resale-status-history.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/resale/models/resale_history.dart` (ResaleHistoryEntry, ResaleEarningsSummary, MonthlyEarnings)
  - `apps/mobile/lib/src/features/resale/services/resale_history_service.dart` (ResaleHistoryService)
  - `apps/mobile/lib/src/features/resale/screens/resale_history_screen.dart` (ResaleHistoryScreen)
  - `apps/mobile/lib/src/features/resale/widgets/earnings_chart.dart` (EarningsChart)
  - `apps/mobile/test/features/resale/models/resale_history_test.dart`
  - `apps/mobile/test/features/resale/services/resale_history_service_test.dart`
  - `apps/mobile/test/features/resale/screens/resale_history_screen_test.dart`
  - `apps/mobile/test/features/resale/widgets/earnings_chart_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add PATCH /v1/items/:id/resale-status route, GET /v1/resale/history route, wire resaleHistoryRepo in createRuntime and handleRequest)
- Modified mobile files:
  - `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` (add Mark as Sold/Donated buttons, status badges)
  - `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (add Resale History entry point)
  - `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart` (add resale status transition tests)

### Technical Requirements

- **New API endpoint:** `PATCH /v1/items/:id/resale-status` -- accepts `{ status: "sold"|"donated", salePrice?: number, saleCurrency?: string, saleDate?: string }`. Returns `{ item, historyEntry }` with HTTP 200. Requires authentication. Validates status transitions.
- **New API endpoint:** `GET /v1/resale/history` -- accepts query params `limit` (default 50), `offset` (default 0). Returns `{ history: [...], summary: {...}, monthlyEarnings: [...] }` with HTTP 200. Requires authentication.
- **Database table:** `resale_history` in `app_public` schema with RLS. FK to `profiles`, `items`, and `resale_listings` (nullable).
- **Badge function update:** `check_badge_eligibility` -- replace placeholder logic for `circular_seller` and `circular_champion` with real queries against `items.resale_status`.
- **No new mobile dependencies.** The earnings chart uses `CustomPaint` (built-in). `CachedNetworkImage` is already a dependency. No charting library needed.
- **Currency format:** Use `NumberFormat.currency(symbol: '\u00A3')` from the `intl` package (already a dependency) for formatting prices.

### Architecture Compliance

- **Server authority for resale state:** All status transitions happen via the API endpoint. The mobile client sends the desired status; the API validates the transition and updates the database. The mobile client NEVER directly modifies `resale_status`.
- **Database boundary owns canonical state:** `resale_history` stores the complete sale/donation record. RLS enforces user-scoped access. The `items.resale_status` column is the lightweight state tracker.
- **Mobile boundary owns presentation:** `ResaleHistoryScreen` handles all presentation: summary, list, chart, empty state.
- **AI calls are NOT involved in this story.** This is purely CRUD and presentation -- no Gemini calls needed.
- **Badge checks are best-effort.** The `circular_champion` badge check after marking sold is wrapped in try/catch and does not block the response.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `pg` (via pool), existing badge service, existing item repository.
- **Mobile:** No new dependencies. `CustomPaint` for chart (built-in). `intl` package for currency formatting (already a dependency). `CachedNetworkImage` for thumbnails (already a dependency).

### File Structure Requirements

- `resale-history-repository.js` goes in `apps/api/src/modules/resale/` alongside the existing `resale-listing-service.js`.
- Mobile resale history files go in the existing `apps/mobile/lib/src/features/resale/` directory.
- `earnings_chart.dart` goes in `apps/mobile/lib/src/features/resale/widgets/` -- a new subdirectory.
- Migration file: `023_resale_history.sql` follows sequential numbering after `022_resale_listings.sql`.
- Test files mirror source structure.

### Testing Requirements

- **Resale history repository unit tests** must verify: entry creation with correct fields, linking to resale_listing_id, null listing for donations, chronological listing with item metadata, pagination, RLS enforcement, earnings summary with correct counts, zeros when no history, monthly aggregation, exclusion of donations from earnings.
- **Endpoint integration tests** must verify: authentication, sold status update with history creation, salePrice validation, donated status update, 409 on invalid transitions, 404 on missing item, listing linkage, badge check on sold, history listing with summary and monthly earnings, pagination.
- **Mobile model tests** must verify: JSON parsing for all model classes, null handling for optional fields.
- **Mobile service tests** must verify: correct API calls, response parsing, error handling, StatusTransitionException on 409.
- **ResaleHistoryScreen widget tests** must verify: loading state, summary display, history list, earnings chart presence, empty state, semantics.
- **EarningsChart widget tests** must verify: rendering with data, empty state message, semantics.
- **Item detail screen tests** must verify: button visibility per status, sold/donated badge display, bottom sheet for sold, dialog for donated.
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1123+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 666+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 7.3** (done) established: `resale-listing-service.js` in `apps/api/src/modules/resale/`, `resale_listings` table (migration 022), `items.resale_status` column with CHECK constraint, `POST /v1/resale/generate` route, mobile `features/resale/` with `ResaleListing` model, `ResaleListingService`, `ResaleListingScreen`. The service sets `resale_status = 'listed'` on generation (only when NULL). The route is wired in `createRuntime()` and `handleRequest`. **666 API tests, 1123 Flutter tests.**
- **Story 7.2** (done) established: `premiumGuard` with `checkUsageQuota`, `PremiumGateCard` widget, `FREE_LIMITS` constants. Not directly needed for this story (no premium gating on status changes).
- **Story 7.1** (done) established: `SubscriptionService`, `subscriptionSyncService`. Not directly needed for this story.
- **Story 6.4** (done) established: `badgeService.checkAndAward(authContext, badgeKey)` pattern. The `circular_champion` badge already exists in the `badges` table (migration 019) but its eligibility function returns FALSE (placeholder).
- **Story 2.6** (done) established: item detail screen with action buttons -- this is where "Mark as Sold" / "Mark as Donated" buttons will be added.
- **`createRuntime()` currently returns (as of Story 7.3, 29 services):** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`, `wearLogRepository`, `analyticsRepository`, `analyticsSummaryService`, `aiUsageLogRepo`, `geminiClient`, `userStatsRepo`, `badgeService`, `challengeService`, `challengeRepository`, `scheduleService`, `notificationService`, `subscriptionSyncService`, `premiumGuard`, `resaleListingService`, `itemRepo` (alias for `itemRepository`). This story adds `resaleHistoryRepo`.
- **`handleRequest` destructuring** currently includes all services listed above. This story adds `resaleHistoryRepo`.
- **`mapError` function** handles 400, 401, 403, 404, 429, 500, 503. This story needs 409 (Conflict) -- add it to `mapError` if not already present: `case 409: res.writeHead(409, ...); break;`.
- **Key patterns from previous stories:**
  - Factory pattern for all API services/repositories: `createXxxService({ deps })` or `createXxxRepository({ pool })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories.
  - Semantics labels on all interactive elements.
  - Best-effort for non-critical operations (try/catch, do not break primary flow).
  - Bottom sheet pattern: used in wear logging flow and other stories.

### Key Anti-Patterns to Avoid

- DO NOT add `fl_chart` or any charting library. Use `CustomPaint` for the simple bar chart.
- DO NOT allow invalid status transitions. Enforce at the API level: sold and donated are terminal states.
- DO NOT allow marking as sold without a sale price. The price is required for earnings tracking.
- DO NOT call Gemini or any AI service. This story is purely CRUD.
- DO NOT modify the existing `POST /v1/resale/generate` endpoint. That belongs to Story 7.3.
- DO NOT modify migration 022. Create a new migration 023 for the `resale_history` table and badge function updates.
- DO NOT duplicate the badge function. Use `CREATE OR REPLACE FUNCTION` to update the existing function in-place.
- DO NOT add premium gating to the status change or history endpoints. All users can track resale status -- premium only gates the AI listing generation (Story 7.3).
- DO NOT store earnings summary on the profile or user_stats table. Compute it dynamically from `resale_history`. Avoid denormalization.
- DO NOT create a separate donations table. Donated items go into `resale_history` with `type = 'donated'` and `sale_price = 0`. The full donation log (`donation_log` table) is deferred to Epic 13 which adds charity/organization tracking.
- DO NOT block the response on badge checks. Wrap in try/catch.
- DO NOT forget to handle 409 in `mapError` if it's not already there.

### Out of Scope

- **Resale candidate identification** (FR-RSL-01): Epic 13, Story 13.2.
- **Monthly resale prompts** (FR-RSL-05, FR-RSL-06): Epic 13.
- **Full donation tracking with charity/organization** (FR-DON-01 to FR-DON-05): Epic 13.
- **AI listing generation** (FR-RSL-02): Already done in Story 7.3.
- **Clipboard copy of listing text** (FR-RSL-03): Already done in Story 7.3.
- **Sustainability score integration** (FR-SUS-01 resale activity factor): Epic 11.
- **Wardrobe grid resale filter UI enhancement**: The filter already works (Story 7.3 added `resaleStatus` to `listItems`). No UI changes needed beyond what's already built.

### References

- [Source: epics.md - Story 7.4: Resale Status & History Tracking]
- [Source: epics.md - Epic 7: Resale Integration & Subscription]
- [Source: prd.md - FR-RSL-04: Items track resale_status with CHECK constraint]
- [Source: prd.md - FR-RSL-07: Resale history on profile showing items listed, sold, total earnings]
- [Source: prd.md - FR-RSL-08: Earnings chart showing monthly earnings over time]
- [Source: prd.md - FR-RSL-09: Selling 10+ items unlocks Circular Champion badge]
- [Source: prd.md - FR-RSL-10: Resale status changes sync back to items table]
- [Source: architecture.md - Data Architecture: resale_listings, resale_history tables]
- [Source: architecture.md - Server authority for sensitive rules: resale state changes]
- [Source: architecture.md - check constraints for enumerations like resale_status]
- [Source: architecture.md - Epic 7 -> mobile/features/resale, api/modules/resale, api/modules/billing]
- [Source: functional-requirements.md - FR-RSL-04 through FR-RSL-10]
- [Source: 7-3-ai-resale-listing-generation.md - resale module, resale_listings table, resale_status column, POST /v1/resale/generate]
- [Source: 7-3-ai-resale-listing-generation.md - 666 API tests, 1123 Flutter tests]
- [Source: infra/sql/migrations/022_resale_listings.sql - resale_listings table, items.resale_status column]
- [Source: infra/sql/migrations/019_badges.sql - circular_seller, circular_champion badge definitions, check_badge_eligibility function]
- [Source: apps/api/src/modules/resale/resale-listing-service.js - existing resale module]
- [Source: apps/api/src/modules/items/repository.js - mapItemRow, updateItem with resaleStatus, listItems filter]
- [Source: apps/api/src/main.js - createRuntime, handleRequest, mapError, route patterns]
- [Source: apps/mobile/lib/src/features/profile/screens/profile_screen.dart - ProfileScreen structure]
- [Source: apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart - item detail with resale button]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No halts or blockers encountered.

### Completion Notes List

- Task 1: Created migration 023 with resale_history table (RLS, indexes) and updated evaluate_badges function for circular_seller (resale_status IS NOT NULL >= 1) and circular_champion (resale_status = 'sold' >= 10).
- Task 2: Created resale-history-repository.js with createHistoryEntry, listHistory, getEarningsSummary, getMonthlyEarnings. All follow factory pattern with RLS context.
- Task 3: Added PATCH /v1/items/:id/resale-status route with status validation, transition validation (null->donated, listed->sold, listed->donated), salePrice validation for sold, and best-effort badge check.
- Task 4: Added GET /v1/resale/history route returning history, summary, and monthlyEarnings via parallel queries.
- Task 5: Created ResaleHistoryEntry, ResaleEarningsSummary, MonthlyEarnings models with fromJson factories.
- Task 6: Created ResaleHistoryService with fetchHistory and updateResaleStatus (throws StatusTransitionException on 409).
- Task 7: Created ResaleHistoryScreen with summary card, earnings chart, history list, and empty state.
- Task 8: Created EarningsChart using CustomPaint (no external charting library).
- Task 9: Added Mark as Sold (bottom sheet with price), Mark as Donated (dialog), and Sold/Donated badges to item detail screen.
- Task 10: Added Resale History entry point to Profile screen with summary subtitle.
- Task 11: Created 10 unit tests for resale history repository.
- Task 12: Created 11 integration tests for resale status and history endpoints.
- Task 13: Created 5 unit tests for ResaleHistory models.
- Task 14: Created 5 unit tests for ResaleHistoryService.
- Task 15: Created 6 widget tests for ResaleHistoryScreen.
- Task 16: Created 3 widget tests for EarningsChart.
- Task 17: Added 7 widget tests for item detail screen resale status actions.
- Task 18: All regression tests pass. 689 API tests (666 baseline + 23 new), 1151 Flutter tests (1123 baseline + 28 new). flutter analyze: 0 new issues.
- Also added checkAndAward method to badge-service.js, added 409 Conflict to mapError, added resaleStatus support to item service updateItemForUser, and added public authenticatedGet to ApiClient.

### Change Log

- 2026-03-19: Story 7.4 implementation complete. Added resale_history table, status transition endpoints, ResaleHistoryScreen with earnings chart, badge function updates, and comprehensive tests.

### File List

New files:
- infra/sql/migrations/023_resale_history.sql
- apps/api/src/modules/resale/resale-history-repository.js
- apps/api/test/modules/resale/resale-history-repository.test.js
- apps/api/test/modules/resale/resale-status-history.test.js
- apps/mobile/lib/src/features/resale/models/resale_history.dart
- apps/mobile/lib/src/features/resale/services/resale_history_service.dart
- apps/mobile/lib/src/features/resale/screens/resale_history_screen.dart
- apps/mobile/lib/src/features/resale/widgets/earnings_chart.dart
- apps/mobile/test/features/resale/models/resale_history_test.dart
- apps/mobile/test/features/resale/services/resale_history_service_test.dart
- apps/mobile/test/features/resale/screens/resale_history_screen_test.dart
- apps/mobile/test/features/resale/widgets/earnings_chart_test.dart

Modified files:
- apps/api/src/main.js (added PATCH /v1/items/:id/resale-status, GET /v1/resale/history, wired resaleHistoryRepo, added 409 to mapError)
- apps/api/src/modules/badges/badge-service.js (added checkAndAward method)
- apps/api/src/modules/items/service.js (added resaleStatus to updateItemForUser validation)
- apps/mobile/lib/src/core/networking/api_client.dart (added public authenticatedGet)
- apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart (added Mark as Sold/Donated buttons, Sold/Donated badges, resaleHistoryService)
- apps/mobile/lib/src/features/profile/screens/profile_screen.dart (added Resale History entry point with summary)
- apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart (added 7 resale status tests)
