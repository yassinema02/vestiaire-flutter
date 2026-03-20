# Story 5.4: Basic Wardrobe Value Analytics

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see the total value of my wardrobe and average Cost-Per-Wear,
so that I understand my fashion spending efficiency.

## Acceptance Criteria

1. Given I have items in my wardrobe, when I navigate to a new "Analytics" screen, then I see an analytics dashboard that displays: the total number of items, the total wardrobe value (sum of all items' `purchase_price` that have a price set), and the overall average Cost-Per-Wear (total value of priced items / total wears across those items). Items without a `purchase_price` are excluded from the value and CPW calculations but still counted in the total items metric. (FR-ANA-01)

2. Given I am on the Analytics dashboard, when the data loads, then each metric is displayed in a summary card row at the top of the screen: "Total Items" (count icon), "Wardrobe Value" (currency icon, formatted with currency symbol), and "Avg. Cost-Per-Wear" (trending icon, formatted with currency symbol). Currency defaults to GBP (the user's most common currency, or GBP if no items have prices). (FR-ANA-01)

3. Given I am on the Analytics dashboard, when the data loads, then below the summary cards I see a scrollable list of all items that have a `purchase_price`, sorted by CPW descending (worst value first). Each item row shows: thumbnail image, name/category label, purchase price, wear count, individual CPW value, and a CPW color indicator. (FR-ANA-01, FR-ANA-02)

4. Given an item has a `purchase_price` and `wear_count > 0`, when its CPW is calculated as `purchase_price / wear_count`, then the CPW value is color-coded: green (< 5), yellow (5-20), red (> 20). The thresholds are in the item's currency unit. Items with `wear_count == 0` show CPW as "No wears" in red. Items without a `purchase_price` show CPW as "No price" in grey. (FR-ANA-02)

5. Given I tap on an item row in the CPW list, when the tap is registered, then I navigate to the existing `ItemDetailScreen` for that item (reusing the navigation pattern from the wardrobe grid). (FR-ANA-01)

6. Given the API call to fetch items fails (network error, server error), when the analytics screen attempts to load, then an error state is shown with a "Retry" button. Tapping retry re-fetches the data. (FR-ANA-01)

7. Given I have no items in my wardrobe at all, when I open the Analytics screen, then an empty state is displayed: "Add items to your wardrobe to see analytics!" with a CTA button that navigates to the Add Item flow. (FR-ANA-01)

8. Given I have items but none have a `purchase_price` set, when the Analytics dashboard loads, then "Total Items" shows the correct count, "Wardrobe Value" shows "N/A", "Avg. CPW" shows "N/A", and the CPW list section shows a prompt: "Add purchase prices to your items to see cost-per-wear analytics." (FR-ANA-01, FR-ANA-02)

9. Given the Analytics dashboard is accessible, when I look at the navigation, then the Analytics screen is reachable from the HomeScreen via a clearly visible entry point (a button or card in the existing analytics section area, near the "Wear Calendar" button). The entry point is labeled "Analytics Dashboard" or similar. (FR-ANA-01)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (337 API tests, 806+ Flutter tests) and new tests cover: AnalyticsDashboardScreen widget rendering, summary card calculations, CPW list rendering, CPW color-coding logic, item tap navigation, error state, empty state, no-price state, and edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Create analytics summary endpoint (AC: 1, 2, 6)
  - [x] 1.1: Create `apps/api/src/modules/analytics/analytics-repository.js` with `createAnalyticsRepository({ pool })` factory following the same pattern as `createWearLogRepository` and `createItemRepository`.
  - [x] 1.2: Add `async getWardrobeSummary(authContext)` method that executes a single SQL query against the `items` table (RLS-scoped): `SELECT COUNT(*) AS total_items, COUNT(purchase_price) AS priced_items, COALESCE(SUM(purchase_price), 0) AS total_value, COALESCE(SUM(CASE WHEN purchase_price IS NOT NULL THEN wear_count ELSE 0 END), 0) AS total_wears, MODE() WITHIN GROUP (ORDER BY currency) FILTER (WHERE currency IS NOT NULL) AS dominant_currency FROM app_public.items`. Returns `{ totalItems, pricedItems, totalValue, totalWears, averageCpw (computed: totalValue/totalWears or null), dominantCurrency }`.
  - [x] 1.3: Add `async getItemsWithCpw(authContext)` method that queries: `SELECT id, name, category, photo_url, purchase_price, currency, wear_count, CASE WHEN wear_count > 0 AND purchase_price IS NOT NULL THEN purchase_price / wear_count ELSE NULL END AS cpw FROM app_public.items WHERE purchase_price IS NOT NULL ORDER BY cpw DESC NULLS FIRST` (RLS-scoped). Returns array of item CPW objects.
  - [x] 1.4: Both methods follow the standard pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.firebaseUid])` -> query -> `client.release()`. Use try/finally for connection release.

- [x] Task 2: API - Create analytics routes (AC: 1, 2, 3, 6)
  - [x] 2.1: Import `createAnalyticsRepository` in `apps/api/src/main.js`.
  - [x] 2.2: In `createRuntime()`, instantiate `const analyticsRepository = createAnalyticsRepository({ pool })` and add to the returned object.
  - [x] 2.3: Add `analyticsRepository` to the `handleRequest` destructuring.
  - [x] 2.4: Add route `GET /v1/analytics/wardrobe-summary`: calls `analyticsRepository.getWardrobeSummary(authContext)`. Returns 200 with `{ summary: { totalItems, pricedItems, totalValue, totalWears, averageCpw, dominantCurrency } }`.
  - [x] 2.5: Add route `GET /v1/analytics/items-cpw`: calls `analyticsRepository.getItemsWithCpw(authContext)`. Returns 200 with `{ items: [...] }`.
  - [x] 2.6: Both routes require authentication (401 if unauthenticated). Follow existing auth check pattern in main.js.

- [x] Task 3: API - Unit tests for analytics repository (AC: 1, 2, 3, 4, 10)
  - [x] 3.1: Create `apps/api/test/modules/analytics/analytics-repository.test.js`:
    - `getWardrobeSummary` returns correct totalItems count.
    - `getWardrobeSummary` returns correct totalValue (sum of purchase_price where not null).
    - `getWardrobeSummary` returns correct totalWears (sum of wear_count for priced items).
    - `getWardrobeSummary` calculates averageCpw correctly (totalValue / totalWears).
    - `getWardrobeSummary` returns averageCpw as null when totalWears is 0.
    - `getWardrobeSummary` returns dominantCurrency as the most common currency.
    - `getWardrobeSummary` excludes items without purchase_price from value/cpw calculations.
    - `getWardrobeSummary` returns zeros for empty wardrobe.
    - `getWardrobeSummary` respects RLS (user A cannot see user B's analytics).
    - `getItemsWithCpw` returns items ordered by CPW descending (worst value first).
    - `getItemsWithCpw` calculates cpw as purchase_price / wear_count.
    - `getItemsWithCpw` returns cpw as null for items with wear_count 0.
    - `getItemsWithCpw` only returns items with purchase_price set.
    - `getItemsWithCpw` respects RLS.

- [x] Task 4: API - Integration tests for analytics endpoints (AC: 1, 2, 3, 6, 10)
  - [x] 4.1: Create `apps/api/test/modules/analytics/analytics-endpoints.test.js`:
    - `GET /v1/analytics/wardrobe-summary` returns 200 with summary object.
    - `GET /v1/analytics/wardrobe-summary` returns 401 if unauthenticated.
    - `GET /v1/analytics/wardrobe-summary` returns zeros for user with no items.
    - `GET /v1/analytics/items-cpw` returns 200 with items array.
    - `GET /v1/analytics/items-cpw` returns 401 if unauthenticated.
    - `GET /v1/analytics/items-cpw` returns empty array for user with no priced items.
    - `GET /v1/analytics/items-cpw` correctly calculates CPW for items with wears.
    - `GET /v1/analytics/items-cpw` returns null CPW for items with zero wears.

- [x] Task 5: Mobile - Create AnalyticsDashboardScreen widget (AC: 1, 2, 3, 4, 5, 6, 7, 8, 9)
  - [x] 5.1: Create `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` with an `AnalyticsDashboardScreen` StatefulWidget. Constructor accepts: `required ApiClient apiClient`, optional `VoidCallback? onNavigateToAddItem` (for empty state CTA).
  - [x] 5.2: State fields: `Map<String, dynamic>? _summary` (wardrobe summary data), `List<Map<String, dynamic>>? _itemsCpw` (items with CPW), `bool _isLoading = true`, `String? _error`.
  - [x] 5.3: In `initState`, call `_loadAnalytics()` which: (a) sets `_isLoading = true`, (b) calls `widget.apiClient.getWardrobeSummary()` and `widget.apiClient.getItemsCpw()` in parallel using `Future.wait`, (c) stores results in `_summary` and `_itemsCpw`, (d) sets `_isLoading = false`. On error, sets `_error` with the error message and `_isLoading = false`. Guard `setState` with `if (mounted)`.
  - [x] 5.4: Build method structure: `Scaffold` with `AppBar(title: Text("Analytics"))`, `body:` a `RefreshIndicator` wrapping a `CustomScrollView` with slivers:
    - `SliverToBoxAdapter` for the `SummaryCardsRow` widget (Task 6).
    - `SliverToBoxAdapter` for section header "Cost-Per-Wear Breakdown".
    - `SliverList` for the CPW item list (or empty/no-price state).
  - [x] 5.5: Loading state: show `CircularProgressIndicator` centered.
  - [x] 5.6: Error state: show error message with "Retry" `TextButton`. Tapping retry calls `_loadAnalytics()`.
  - [x] 5.7: Empty state (no items at all): show "Add items to your wardrobe to see analytics!" with icon `Icons.analytics_outlined` and a "Add Item" `ElevatedButton` that calls `widget.onNavigateToAddItem?.call()`.
  - [x] 5.8: No-price state (items exist but none have purchase_price): show summary cards with totalItems count but "N/A" for value and CPW. Show prompt "Add purchase prices to your items to see cost-per-wear analytics." in the CPW list area.
  - [x] 5.9: Pull-to-refresh via `RefreshIndicator` calls `_loadAnalytics()`.
  - [x] 5.10: Add `Semantics` labels: "Analytics dashboard", "Total items: [N]", "Wardrobe value: [amount]", "Average cost per wear: [amount]".

- [x] Task 6: Mobile - Create SummaryCardsRow widget (AC: 1, 2, 8)
  - [x] 6.1: Create `apps/mobile/lib/src/features/analytics/widgets/summary_cards_row.dart` with a `SummaryCardsRow` StatelessWidget. Constructor accepts: `required int totalItems`, `required double? totalValue`, `required double? averageCpw`, `required String? currency`.
  - [x] 6.2: Display three metric cards in a horizontal `Row` (evenly spaced):
    - **Total Items**: `Icons.checkroom`, value = totalItems count, label "Total Items".
    - **Wardrobe Value**: `Icons.account_balance_wallet_outlined`, value = formatted currency amount (e.g., "£2,450") or "N/A" if totalValue is null/zero, label "Wardrobe Value".
    - **Avg. CPW**: `Icons.trending_down`, value = formatted currency amount (e.g., "£8.50") or "N/A" if averageCpw is null, label "Avg. Cost/Wear".
  - [x] 6.3: Each card: `Container` with rounded corners (12px), background #F9FAFB, padding 12px. Icon (24px, primary color #4F46E5), value text (20px bold, #1F2937), label text (12px, #6B7280).
  - [x] 6.4: Currency formatting: use the dominant currency from the summary. Map: GBP -> "£", EUR -> "€", USD -> "$". Format numbers with commas for thousands. CPW to 2 decimal places.
  - [x] 6.5: Add `Semantics` labels: "Total items: [N]", "Wardrobe value: [amount]", "Average cost per wear: [amount]".

- [x] Task 7: Mobile - Create CpwItemRow widget (AC: 3, 4, 5)
  - [x] 7.1: Create `apps/mobile/lib/src/features/analytics/widgets/cpw_item_row.dart` with a `CpwItemRow` StatelessWidget. Constructor accepts: `required String itemId`, `required String? name`, `required String? category`, `required String? photoUrl`, `required double? purchasePrice`, `required String? currency`, `required int wearCount`, `required double? cpw`, `required VoidCallback onTap`.
  - [x] 7.2: Layout: `InkWell(onTap: onTap)` wrapping a `Row` with:
    - Circular item thumbnail (40x40) using `CachedNetworkImage` (from `cached_network_image` package already in pubspec.yaml), with fallback `Icons.checkroom`.
    - Column: item `displayLabel` (name ?? category ?? "Item") in 14px #1F2937, purchase price in 12px #6B7280.
    - Spacer.
    - Column (right-aligned): CPW value in 14px bold with color coding, wear count in 12px #6B7280.
  - [x] 7.3: CPW color coding: parse `cpw` value and apply color:
    - `cpw < 5.0` -> green (#22C55E) with label "Great value"
    - `cpw >= 5.0 && cpw <= 20.0` -> yellow/amber (#F59E0B) with label "Fair value"
    - `cpw > 20.0` -> red (#EF4444) with label "Low value"
    - `wearCount == 0` -> red (#EF4444) with text "No wears"
    - `cpw == null` (no price) -> grey (#9CA3AF) with text "No price" (should not appear in list since list is filtered to priced items)
  - [x] 7.4: CPW display format: currency symbol + cpw to 2 decimal places + "/wear" (e.g., "£8.50/wear").
  - [x] 7.5: Add `Semantics` labels: "[item name], cost per wear: [amount], [value rating]".

- [x] Task 8: Mobile - Add analytics API methods to ApiClient (AC: 1, 2, 3)
  - [x] 8.1: Add `Future<Map<String, dynamic>> getWardrobeSummary()` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `GET /v1/analytics/wardrobe-summary` using the existing `authenticatedGet` method. Returns the response JSON map.
  - [x] 8.2: Add `Future<Map<String, dynamic>> getItemsCpw()` to `ApiClient`. Calls `GET /v1/analytics/items-cpw` using `authenticatedGet`. Returns the response JSON map.

- [x] Task 9: Mobile - Add navigation route to AnalyticsDashboardScreen (AC: 9)
  - [x] 9.1: Add an "Analytics Dashboard" entry point on the HomeScreen, near the existing "Wear Calendar" button. Use a `TextButton` or `OutlinedButton` with `Icons.analytics_outlined` and label "Analytics". Tapping it pushes `AnalyticsDashboardScreen` as a full-screen route.
  - [x] 9.2: Pass `apiClient` and `onNavigateToAddItem` from the HomeScreen to the `AnalyticsDashboardScreen`.
  - [x] 9.3: Add `Semantics` label: "View analytics dashboard".
  - [x] 9.4: This does NOT add new constructor params to HomeScreen -- it uses the existing `apiClient` already available.

- [x] Task 10: Mobile - Unit tests for AnalyticsDashboardScreen (AC: 1, 2, 3, 6, 7, 8, 10)
  - [ ] 10.1: Create `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`:
    - Renders AppBar with "Analytics" title.
    - Shows loading indicator while fetching data.
    - Displays summary cards with correct totalItems, totalValue, averageCpw.
    - Displays CPW item list sorted by CPW descending.
    - CPW color coding: green for < 5, yellow for 5-20, red for > 20.
    - Items with zero wears show "No wears" in red.
    - Error state shows error message and retry button.
    - Tapping retry re-fetches data.
    - Empty state (no items) shows "Add items" message and CTA button.
    - No-price state shows "N/A" for value and CPW, prompt for adding prices.
    - Tapping an item row triggers onTap callback.
    - Pull-to-refresh triggers data reload.
    - Semantics labels present on all key elements.

- [x] Task 11: Mobile - Widget tests for SummaryCardsRow (AC: 2, 8, 10)
  - [ ] 11.1: Create `apps/mobile/test/features/analytics/widgets/summary_cards_row_test.dart`:
    - Displays correct total items count.
    - Displays formatted wardrobe value with currency symbol.
    - Displays formatted average CPW with currency symbol.
    - Shows "N/A" when totalValue is null.
    - Shows "N/A" when averageCpw is null.
    - Formats GBP, EUR, USD correctly.
    - Semantics labels present.

- [x] Task 12: Mobile - Widget tests for CpwItemRow (AC: 3, 4, 5, 10)
  - [ ] 12.1: Create `apps/mobile/test/features/analytics/widgets/cpw_item_row_test.dart`:
    - Renders item name, purchase price, wear count, CPW value.
    - Green color for CPW < 5.
    - Yellow/amber color for CPW 5-20.
    - Red color for CPW > 20.
    - "No wears" text for zero wear count.
    - Tap invokes onTap callback.
    - Thumbnail renders with CachedNetworkImage or fallback icon.
    - Semantics labels present.

- [x] Task 13: Mobile - HomeScreen integration tests (AC: 9, 10)
  - [ ] 13.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - "Analytics" button renders on HomeScreen.
    - Tapping the button navigates to AnalyticsDashboardScreen.
    - All existing HomeScreen tests continue to pass.

- [x] Task 14: Regression testing (AC: all)
  - [ ] 14.1: Run `flutter analyze` -- zero issues.
  - [ ] 14.2: Run `flutter test` -- all existing 806+ Flutter tests plus new tests pass.
  - [ ] 14.3: Run `npm --prefix apps/api test` -- all existing 337+ API tests plus new tests pass.
  - [ ] 14.4: Verify existing HomeScreen tests pass with the new "Analytics" button.
  - [ ] 14.5: Verify existing WearCalendarScreen tests still pass.
  - [ ] 14.6: Verify existing wardrobe grid and item detail tests still pass.

## Dev Notes

- This is the **fourth story in Epic 5** (Wardrobe Analytics & Wear Logging). It builds on Story 5.1 (wear logging infrastructure with `wear_count` and `last_worn_date` on items), Story 5.2 (evening reminder), and Story 5.3 (wear calendar view). It is the first analytics dashboard story.
- This story implements **FR-ANA-01** (analytics dashboard with total items, wardrobe value, average CPW, category distribution) and **FR-ANA-02** (CPW calculation with color coding). Note: category distribution from FR-ANA-01 is deferred to Story 5.6 (Category Distribution Charts) per the epic breakdown. This story focuses on value metrics and CPW.
- **New API endpoints are needed.** Unlike Stories 5.2 and 5.3 (which reused the existing `GET /v1/wear-logs` endpoint), this story creates the first analytics-specific API endpoints. The analytics calculations happen server-side for accuracy and efficiency.
- **No new database migration is needed.** All required data already exists: `items.purchase_price`, `items.wear_count`, `items.currency`, `items.category`, `items.name`, `items.photo_url` are all established from previous stories (2.1, 2.4, 5.1).
- **No new dependencies are needed.** All functionality uses packages already in `pubspec.yaml`: `cached_network_image` for thumbnails, `intl` for number/currency formatting, `http` via `ApiClient` for API calls.

### Design Decision: Server-Side Analytics Calculations

Analytics aggregations (total value, total wears, average CPW) are computed server-side via SQL rather than client-side for several reasons:
1. **Accuracy:** SQL aggregations on the full dataset avoid floating-point accumulation errors from client-side iteration.
2. **Performance:** A single SQL query with COUNT/SUM is faster than fetching all items to the client and computing there, especially as wardrobes grow to hundreds of items.
3. **Foundation for Stories 5.5-5.7:** The analytics repository established here will be extended for top-worn/neglected items (5.5), category distribution (5.6), and AI summary (5.7).
4. **RLS enforcement:** Server-side queries are naturally RLS-scoped. No risk of client-side data leakage.

### Design Decision: Separate Summary and Items-CPW Endpoints

Two endpoints are created rather than one because:
1. **Summary** is lightweight (single-row aggregation) and always needed for the top cards.
2. **Items-CPW** returns a potentially large list and is only needed for the scrollable list section.
3. Both are fetched in parallel from the mobile client via `Future.wait` for minimal latency.
4. Future stories (5.5, 5.6) will add more endpoints (top-worn, neglected, category distribution) following the same pattern.

### Design Decision: Navigation Entry Point (Temporary)

The Analytics Dashboard is accessed via a button on the HomeScreen, placed near the existing "Wear Calendar" button from Story 5.3. This is a temporary navigation approach. When all analytics stories (5.4-5.7) are complete, the analytics section may be consolidated into a dedicated analytics screen with tabs or sections. For now, individual entry points on the HomeScreen keep each feature discoverable without premature navigation restructuring.

### Design Decision: CPW Thresholds Are Hardcoded

The CPW color thresholds (green < 5, yellow 5-20, red > 20) are hardcoded per FR-ANA-02 specification. They are defined as constants in the CpwItemRow widget. These thresholds are currency-agnostic (5 GBP, 5 EUR, 5 USD all use the same thresholds). A future enhancement could make them currency-aware, but FR-ANA-02 does not require this.

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (analytics data access)
  - `apps/api/test/modules/analytics/analytics-repository.test.js`
  - `apps/api/test/modules/analytics/analytics-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (main dashboard)
  - `apps/mobile/lib/src/features/analytics/widgets/summary_cards_row.dart` (top metrics cards)
  - `apps/mobile/lib/src/features/analytics/widgets/cpw_item_row.dart` (CPW list item)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`
  - `apps/mobile/test/features/analytics/widgets/summary_cards_row_test.dart`
  - `apps/mobile/test/features/analytics/widgets/cpw_item_row_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add analyticsRepository instantiation, add GET /v1/analytics/* routes)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add getWardrobeSummary, getItemsCpw methods)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add "Analytics" navigation button)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add analytics button tests)
- No SQL migration files.
- The analytics feature module directory structure after this story:
  ```
  apps/mobile/lib/src/features/analytics/
  ├── models/
  │   └── wear_log.dart (Story 5.1)
  ├── screens/
  │   ├── analytics_dashboard_screen.dart (NEW)
  │   └── wear_calendar_screen.dart (Story 5.3)
  ├── services/
  │   └── wear_log_service.dart (Story 5.1)
  └── widgets/
      ├── cpw_item_row.dart (NEW)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      └── summary_cards_row.dart (NEW)
  ```

### Technical Requirements

- **API analytics repository:** Follows the same factory pattern as `createWearLogRepository` and `createItemRepository`: `createAnalyticsRepository({ pool })` returns an object with methods. Each method: `pool.connect()` -> set RLS context -> query -> release. Use try/finally for connection cleanup.
- **SQL aggregation:** Use `COUNT(*)`, `COUNT(purchase_price)`, `SUM(purchase_price)`, `SUM(wear_count)` in a single query. `MODE() WITHIN GROUP (ORDER BY currency)` for dominant currency. PostgreSQL 16 supports all these aggregate functions.
- **CPW calculation:** Server-side: `purchase_price / wear_count` using SQL CASE expression. Client-side: reuse the existing `WardrobeItem.costPerWear` getter for display, but the API also returns pre-computed CPW to avoid client-side re-computation for sorting.
- **Currency formatting:** Use `intl` package `NumberFormat.currency()` with the dominant currency symbol. Map: GBP -> "£", EUR -> "€", USD -> "$". Format with 2 decimal places for CPW, no decimals for total value.
- **Summary card layout:** Three cards in a horizontal Row. Each card: rounded container (#F9FAFB background, 12px radius), icon (24px, #4F46E5), value (20px bold, #1F2937), label (12px, #6B7280). Same card styling pattern as `MonthSummaryRow` from Story 5.3.
- **CPW list:** `SliverList` of `CpwItemRow` widgets. Each row is minimum 56px height with 44x44 touch target. Thumbnail 40x40 circular with `CachedNetworkImage`.

### Architecture Compliance

- **Server authority for analytics data:** All analytics computations happen server-side via SQL aggregations. The mobile client displays pre-computed results. This prevents data inconsistency between the client's local item cache and the actual database state.
- **RLS enforces data isolation:** Analytics endpoints are RLS-scoped via `set_config('app.current_user_id', ...)`. A user can only see their own wardrobe analytics.
- **Mobile boundary owns presentation:** The analytics dashboard UI (cards, list, color coding) is a mobile-only concern. The API returns raw numbers; the client applies formatting and color logic.
- **No new AI calls:** This story is purely data aggregation + UI display. No Gemini involvement.
- **API module placement:** The analytics repository goes in `apps/api/src/modules/analytics/` as specified in the architecture document for Epic 5 (`api/modules/analytics`).
- **JSON REST over HTTPS:** New endpoints follow existing patterns: `GET /v1/analytics/wardrobe-summary` and `GET /v1/analytics/items-cpw`. RESTful resource-oriented naming.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `intl: ^0.19.0` -- number formatting (currency, thousands separators, decimal places)
  - `cached_network_image` -- item thumbnails in CPW list
  - `http` via `ApiClient` -- API calls
  - `flutter/material.dart` -- CustomScrollView, SliverList, RefreshIndicator, InkWell
- API side: no new npm dependencies. Uses existing `pool` from `pg` for database access.

### File Structure Requirements

- API analytics module goes in `apps/api/src/modules/analytics/` -- creating the `analytics` module directory for the first time.
- API test files go in `apps/api/test/modules/analytics/`.
- Mobile screen goes in `apps/mobile/lib/src/features/analytics/screens/` (alongside `wear_calendar_screen.dart`).
- Mobile widgets go in `apps/mobile/lib/src/features/analytics/widgets/` (alongside existing Story 5.1/5.3 widgets).
- Test files mirror source structure under `apps/mobile/test/features/analytics/`.

### Testing Requirements

- **API repository tests** must verify:
  - Correct aggregation results (totalItems, totalValue, totalWears, averageCpw)
  - Correct handling of items without purchase_price (excluded from value/cpw)
  - Correct CPW per-item calculation
  - RLS enforcement (user isolation)
  - Edge cases: empty wardrobe, all items have price, no items have price, zero wears
- **API endpoint tests** must verify:
  - 200 responses with correct JSON structure
  - 401 for unauthenticated requests
  - Empty results for empty wardrobes
- **Mobile widget tests** must verify:
  - AnalyticsDashboardScreen renders summary cards and CPW list
  - Summary cards display correct values with formatting
  - CPW color coding matches thresholds (green < 5, yellow 5-20, red > 20)
  - Item tap navigates correctly
  - Loading, error, empty, and no-price states render correctly
  - Pull-to-refresh works
  - Semantics labels present on all interactive elements
- **Regression:**
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 806+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 337+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 5.3** (done) established: `WearCalendarScreen` in `apps/mobile/lib/src/features/analytics/screens/`, `DayDetailBottomSheet` and `MonthSummaryRow` in widgets. HomeScreen has a "Wear Calendar" button. The `SummaryCardsRow` in this story follows the same card styling pattern as `MonthSummaryRow`.
- **Story 5.1** (done) established: `WearLog` model, `WearLogService`, `LogOutfitBottomSheet`, `GET /v1/wear-logs` endpoint, `wear_logs` + `wear_log_items` tables, `wear_count` and `last_worn_date` columns on `items` table, `increment_wear_counts` RPC. The `wear_count` column is the data source for CPW calculation.
- **Story 2.4** (done) established: `purchase_price` (NUMERIC(10,2)), `purchase_date`, `currency`, `brand` columns on `items` table via migration 009. `WardrobeItem` model has `purchasePrice`, `purchaseDate`, `currency`, `brand` fields. The `costPerWear` getter and `costPerWearDisplay` getter already exist on `WardrobeItem` -- these calculate CPW client-side for individual item display.
- **Story 2.5** (done) established: `GET /v1/items` with server-side filtering, `ApiClient.listItems()` with filter params, `WardrobeScreen` grid with `CachedNetworkImage`, `FilterBar` widget. The CPW list reuses `CachedNetworkImage` for item thumbnails.
- **Story 2.6** (done) established: `ItemDetailScreen` at `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` showing all item metadata including wear count and CPW. Tapping an item in the CPW list navigates to this screen.
- **HomeScreen constructor (as of Story 5.3):** `locationService` (required), `weatherService` (required), `sharedPreferences`, `weatherCacheService`, `outfitContextService`, `calendarService`, `calendarPreferencesService`, `calendarEventService`, `outfitGenerationService`, `outfitPersistenceService`, `onNavigateToAddItem`, `apiClient`, `morningNotificationService`, `morningNotificationPreferences`, `wearLogService`, `eveningReminderService`, `eveningReminderPreferences`, `initialOpenLogSheet`. This story does NOT add new constructor params -- it uses the existing `apiClient` and `onNavigateToAddItem`.
- **Key pattern from prior stories:** DI via optional constructor parameters with null defaults for test injection.
- **Key pattern:** Error states with retry button (used across weather, calendar sync, outfit generation, wear calendar screens).
- **Key pattern:** Summary metric cards in a horizontal row (MonthSummaryRow in Story 5.3).
- **Key pattern:** Semantics labels on all interactive elements (minimum 44x44 touch targets).
- **Items table columns (as of Story 5.1):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `created_at`, `updated_at`.

### Key Anti-Patterns to Avoid

- DO NOT compute analytics aggregations client-side by fetching all items via `GET /v1/items` and summing in Dart. Use the dedicated server-side analytics endpoints for accuracy and performance.
- DO NOT add `table_calendar`, charting libraries, or any other third-party packages for this story. The dashboard is simple summary cards + a list. Charts come in Story 5.6.
- DO NOT implement category distribution in this story. That is Story 5.6 (FR-ANA-05).
- DO NOT implement the top-worn/neglected items sections in this story. That is Story 5.5 (FR-ANA-03, FR-ANA-04).
- DO NOT implement AI-generated summary in this story. That is Story 5.7 (FR-ANA-06, premium-gated).
- DO NOT create a new bottom navigation tab for analytics. Use a button on the HomeScreen (same approach as Story 5.3's Wear Calendar).
- DO NOT modify the `items` table schema. All needed columns already exist.
- DO NOT modify existing API endpoints (`GET /v1/items`, `POST /v1/wear-logs`, etc.). Create new analytics-specific endpoints.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT create a separate analytics service class on mobile. The `ApiClient` methods are sufficient for these simple GET requests. A service class would be premature abstraction -- Story 5.5-5.7 may warrant one later.
- DO NOT hardcode the currency symbol as GBP only. Use the `dominantCurrency` from the summary endpoint to determine the correct symbol.
- DO NOT fetch item details separately for the CPW list. The `GET /v1/analytics/items-cpw` endpoint returns all needed fields (name, category, photo_url, purchase_price, currency, wear_count, cpw) in a single call.

### Out of Scope

- **Top Worn & Neglected Items (FR-ANA-03, FR-ANA-04):** Story 5.5.
- **Category Distribution Charts (FR-ANA-05):** Story 5.6.
- **AI-Generated Analytics Summary (FR-ANA-06):** Story 5.7.
- **Brand Value Analytics (FR-BRD-01, FR-BRD-02):** Epic 11, Story 11.1.
- **Sustainability Scoring (FR-SUS-*):** Epic 11, Story 11.2.
- **Wardrobe Gap Analysis:** Epic 11, Story 11.3.
- **Calendar Heatmap / Seasonal Reports:** Epic 11, Story 11.4.
- **Gamification / Style Points:** Epic 6.
- **Premium gating on analytics features:** Not required for basic analytics (FR-ANA-01, FR-ANA-02 are free-tier). Premium gating applies to FR-ANA-06 (AI summary) in Story 5.7.
- **Offline analytics viewing:** Requires local data cache. Out of scope for V1.
- **Export/share analytics data:** Not required by any FR.
- **Historical value tracking (value over time):** Not required by any FR.

### References

- [Source: epics.md - Story 5.4: Basic Wardrobe Value Analytics]
- [Source: epics.md - FR-ANA-01: The analytics dashboard shall display: total items, total wardrobe value, average cost-per-wear, and category distribution]
- [Source: epics.md - FR-ANA-02: Cost-per-wear (CPW) shall be calculated as purchase_price / wear_count, color-coded: green (< £5), yellow (£5-20), red (> £20)]
- [Source: prd.md - Analytics: Total items, wardrobe value, average cost-per-wear, category distribution]
- [Source: architecture.md - Epic 5 Analytics & Wear Logging -> mobile/features/analytics, api/modules/analytics, infra/sql/functions]
- [Source: architecture.md - Data Architecture: items table with purchase_price, wear_count, currency]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: ux-design-specification.md - Anti-Patterns: Overwhelming Data Displays -- data must be visualized simply]
- [Source: ux-design-specification.md - Positive Reinforcement Loops: Every journey ends with quantifiable positive feedback (e.g., lower cost-per-wear)]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - wear_count column on items, WearLog model, analytics feature module]
- [Source: 5-3-monthly-wear-calendar-view.md - MonthSummaryRow card pattern, WearCalendarScreen, HomeScreen navigation button pattern]
- [Source: 2-4-manual-metadata-editing-creation.md - purchase_price, currency, brand columns on items table, WardrobeItem model fields]
- [Source: 2-6-item-detail-view-management.md - ItemDetailScreen, items table full column list]
- [Source: apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart - WardrobeItem model with costPerWear getter, purchasePrice, wearCount fields]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented analytics repository with `getWardrobeSummary` and `getItemsWithCpw` methods using server-side SQL aggregations with RLS enforcement via `set_config`.
- Added two new API routes: `GET /v1/analytics/wardrobe-summary` and `GET /v1/analytics/items-cpw` with authentication checks.
- Created `AnalyticsDashboardScreen` with loading, error, empty, no-price, and data-loaded states. Uses `Future.wait` for parallel API calls and `RefreshIndicator` for pull-to-refresh.
- Created `SummaryCardsRow` widget displaying three metric cards (Total Items, Wardrobe Value, Avg. CPW) with currency formatting via `intl` package.
- Created `CpwItemRow` widget with CPW color coding (green < 5, yellow 5-20, red > 20), thumbnail via `CachedNetworkImage`, and tap navigation.
- Added `getWardrobeSummary()` and `getItemsCpw()` methods to mobile `ApiClient`.
- Added "Analytics" button on HomeScreen near existing "Wear Calendar" button, using existing `apiClient` (no new constructor params).
- All Semantics labels added for accessibility.
- 27 new API tests (19 repository + 8 endpoint) -- 364 total API tests pass.
- 41 new Flutter tests (14 dashboard + 10 summary cards + 13 CPW item row + 2 HomeScreen + 2 HomeScreen nav) -- 878 total Flutter tests pass.
- `flutter analyze` shows 5 pre-existing issues (all from Story 5.3 test file), zero new issues.

### Change Log

- 2026-03-18: Story 5.4 implemented -- analytics dashboard with wardrobe value metrics and CPW breakdown list.

### File List

New files:
- apps/api/src/modules/analytics/analytics-repository.js
- apps/api/test/modules/analytics/analytics-repository.test.js
- apps/api/test/modules/analytics/analytics-endpoints.test.js
- apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart
- apps/mobile/lib/src/features/analytics/widgets/summary_cards_row.dart
- apps/mobile/lib/src/features/analytics/widgets/cpw_item_row.dart
- apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart
- apps/mobile/test/features/analytics/widgets/summary_cards_row_test.dart
- apps/mobile/test/features/analytics/widgets/cpw_item_row_test.dart

Modified files:
- apps/api/src/main.js (added analyticsRepository import, instantiation, routes)
- apps/mobile/lib/src/core/networking/api_client.dart (added getWardrobeSummary, getItemsCpw methods)
- apps/mobile/lib/src/features/home/screens/home_screen.dart (added Analytics button and navigation)
- apps/mobile/test/features/home/screens/home_screen_test.dart (added analytics button tests)
