# Story 5.5: Top Worn & Neglected Items Analytics

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see my most worn items and items I haven't worn in a long time,
so that I can identify my staples and clear out dead weight.

## Acceptance Criteria

1. Given I have a history of wear logs, when I view the Analytics dashboard (existing `AnalyticsDashboardScreen`), then I see a new "Top 10 Most Worn" section below the existing CPW breakdown list. The section displays a ranked leaderboard of up to 10 items sorted by `wear_count` descending. Each row shows: rank number, item thumbnail, name/category label, wear count, and last worn date. (FR-ANA-04)

2. Given I am viewing the "Top 10 Most Worn" section, when I tap a time filter chip, then I can toggle between three periods: "30 Days", "90 Days", and "All Time" (default). The "30 Days" filter shows items with the highest number of wear_log_items entries in the last 30 days. The "90 Days" filter shows the last 90 days. "All Time" uses the `wear_count` column directly. The selected filter is visually highlighted. (FR-ANA-04)

3. Given I am viewing the Analytics dashboard, when the data loads, then I see a "Neglected Items" section below the "Top 10 Most Worn" section. This section shows all items that have not been worn in 60 or more days (based on `last_worn_date`), or items that have never been worn and were created 60+ days ago (based on `created_at`). Items are sorted by staleness (longest time since last worn first). Each row shows: item thumbnail, name/category label, days since last worn (or "Never worn"), and a CPW indicator if purchase price exists. (FR-ANA-03)

4. Given I tap any item in the "Top 10 Most Worn" or "Neglected Items" sections, when the tap is registered, then I navigate to the `ItemDetailScreen` for that item (reusing the same navigation pattern as the CPW list in Story 5.4). (FR-ANA-03, FR-ANA-04)

5. Given I have no wear logs at all, when the "Top 10 Most Worn" section loads, then it displays an empty state: "Start logging outfits to see your most worn items!" with an icon. The "Neglected Items" section still shows items older than 60 days based on `created_at`. (FR-ANA-04)

6. Given I have no items that meet the neglected threshold (all items worn within the last 60 days), when the "Neglected Items" section loads, then it shows a positive message: "No neglected items -- great job wearing your wardrobe!" (FR-ANA-03)

7. Given the API calls to fetch top-worn or neglected data fail, when the analytics screen loads, then the existing error-retry pattern from Story 5.4 handles the failure gracefully -- the entire dashboard shows an error state with a "Retry" button. (FR-ANA-03, FR-ANA-04)

8. Given the "Neglected Items" section shows items, when I count them, then the neglected threshold is 60 days (as specified in FR-ANA-03). This is a server-side constant; the client displays what the API returns. (FR-ANA-03)

9. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (364+ API tests, 878+ Flutter tests) and new tests cover: top-worn repository methods, neglected items repository method, API endpoints for both, mobile widget rendering for both sections, time filter switching, empty states, item tap navigation, and edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Add top-worn items method to analytics repository (AC: 1, 2, 5)
  - [x] 1.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getTopWornItems(authContext, { period = "all" })` method. The method follows the same pattern as `getWardrobeSummary`: `pool.connect()` -> set RLS -> query -> release with try/finally.
  - [x] 1.2: For `period === "all"`: query `SELECT id, name, category, photo_url, wear_count, last_worn_date FROM app_public.items WHERE wear_count > 0 ORDER BY wear_count DESC, last_worn_date DESC NULLS LAST LIMIT 10`. This uses the `wear_count` column directly.
  - [x] 1.3: For `period === "30"` or `period === "90"`: query the `wear_log_items` table joined with `wear_logs` and `items` to count wears within the date range. SQL: `SELECT i.id, i.name, i.category, i.photo_url, i.wear_count AS total_wear_count, i.last_worn_date, COUNT(wli.id) AS period_wear_count FROM app_public.items i JOIN app_public.wear_log_items wli ON wli.item_id = i.id JOIN app_public.wear_logs wl ON wl.id = wli.wear_log_id WHERE wl.logged_date >= CURRENT_DATE - INTERVAL '$1 days' GROUP BY i.id ORDER BY period_wear_count DESC, i.last_worn_date DESC NULLS LAST LIMIT 10`. Use parameterized interval: pass the number of days (30 or 90) as an integer parameter. Actually, use `CURRENT_DATE - $1::integer` for the interval to avoid SQL injection.
  - [x] 1.4: Validate `period` parameter: only accept `"all"`, `"30"`, or `"90"`. Throw a 400-equivalent error for invalid values.
  - [x] 1.5: Return array of objects: `{ id, name, category, photoUrl, wearCount (total), lastWornDate, periodWearCount (only for 30/90) }`. Map snake_case to camelCase.

- [x] Task 2: API - Add neglected items method to analytics repository (AC: 3, 6, 8)
  - [x] 2.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getNeglectedItems(authContext)` method following the same connection/RLS pattern.
  - [x] 2.2: SQL query: `SELECT id, name, category, photo_url, purchase_price, currency, wear_count, last_worn_date, created_at FROM app_public.items WHERE (last_worn_date IS NOT NULL AND last_worn_date < CURRENT_DATE - 60) OR (last_worn_date IS NULL AND wear_count = 0 AND created_at < CURRENT_DATE - 60) ORDER BY COALESCE(last_worn_date, created_at::date) ASC`. This returns items not worn in 60+ days (or never worn and created 60+ days ago), sorted by staleness.
  - [x] 2.3: For each item, compute `daysSinceWorn`: if `last_worn_date` exists, `CURRENT_DATE - last_worn_date` as integer; if null and `wear_count == 0`, `CURRENT_DATE - created_at::date` as integer. Include this as a computed column in the SQL: `CASE WHEN last_worn_date IS NOT NULL THEN CURRENT_DATE - last_worn_date ELSE CURRENT_DATE - created_at::date END AS days_since_worn`.
  - [x] 2.4: Return array of objects: `{ id, name, category, photoUrl, purchasePrice, currency, wearCount, lastWornDate, daysSinceWorn, cpw (computed: purchasePrice/wearCount or null) }`. Map snake_case to camelCase.

- [x] Task 3: API - Add routes for top-worn and neglected items (AC: 1, 2, 3, 7)
  - [x] 3.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/top-worn?period=all|30|90`. Extract `period` query param (default "all"). Call `analyticsRepository.getTopWornItems(authContext, { period })`. Return 200 with `{ items: [...] }`. Requires authentication (401 if unauthenticated).
  - [x] 3.2: In `apps/api/src/main.js`, add route `GET /v1/analytics/neglected`. Call `analyticsRepository.getNeglectedItems(authContext)`. Return 200 with `{ items: [...] }`. Requires authentication (401 if unauthenticated).
  - [x] 3.3: For invalid `period` values, return 400 with `{ error: "Invalid period. Must be 'all', '30', or '90'" }`.

- [x] Task 4: API - Unit tests for new analytics repository methods (AC: 1, 2, 3, 5, 6, 8, 9)
  - [x] 4.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getTopWornItems`:
    - Returns top 10 items sorted by wear_count descending for "all" period.
    - Returns at most 10 items even if more exist.
    - Returns empty array when no items have wear_count > 0.
    - For "30" period, counts only wear_log_items from last 30 days.
    - For "90" period, counts only wear_log_items from last 90 days.
    - Period filter excludes items with zero wears in that period.
    - Respects RLS (user A cannot see user B's items).
    - Throws error for invalid period value.
  - [x] 4.2: Add tests for `getNeglectedItems`:
    - Returns items not worn in 60+ days.
    - Returns items never worn but created 60+ days ago.
    - Does NOT return items worn within the last 60 days.
    - Does NOT return items created fewer than 60 days ago with no wears.
    - Returns items sorted by staleness (longest neglected first).
    - Computes daysSinceWorn correctly for worn items.
    - Computes daysSinceWorn correctly for never-worn items (uses created_at).
    - Includes CPW for items with purchase_price and wear_count > 0.
    - Respects RLS.
    - Returns empty array when no items meet the neglected threshold.

- [x] Task 5: API - Integration tests for new endpoints (AC: 1, 2, 3, 7, 9)
  - [x] 5.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/top-worn` returns 200 with items array (default period=all).
    - `GET /v1/analytics/top-worn?period=30` returns 200 with period-filtered items.
    - `GET /v1/analytics/top-worn?period=90` returns 200 with period-filtered items.
    - `GET /v1/analytics/top-worn?period=invalid` returns 400.
    - `GET /v1/analytics/top-worn` returns 401 if unauthenticated.
    - `GET /v1/analytics/top-worn` returns empty array for user with no worn items.
    - `GET /v1/analytics/neglected` returns 200 with items array.
    - `GET /v1/analytics/neglected` returns 401 if unauthenticated.
    - `GET /v1/analytics/neglected` returns empty array when no items are neglected.

- [x] Task 6: Mobile - Add API methods to ApiClient (AC: 1, 2, 3)
  - [x] 6.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getTopWornItems({String period = "all"})` method. Calls `GET /v1/analytics/top-worn?period=$period` using `_authenticatedGet`. Returns response JSON map.
  - [x] 6.2: Add `Future<Map<String, dynamic>> getNeglectedItems()` method. Calls `GET /v1/analytics/neglected` using `_authenticatedGet`. Returns response JSON map.

- [x] Task 7: Mobile - Create TopWornSection widget (AC: 1, 2, 4, 5)
  - [x] 7.1: Create `apps/mobile/lib/src/features/analytics/widgets/top_worn_section.dart` with a `TopWornSection` StatefulWidget. Constructor accepts: `required List<Map<String, dynamic>> items`, `required String selectedPeriod`, `required ValueChanged<String> onPeriodChanged`, `required ValueChanged<Map<String, dynamic>> onItemTap`.
  - [x] 7.2: Display a section header row: "Top 10 Most Worn" (16px bold, #1F2937) with three `ChoiceChip`s: "30 Days", "90 Days", "All Time". Tapping a chip calls `onPeriodChanged` with the period value ("30", "90", "all").
  - [x] 7.3: Below the header, display a ranked list. Each row: rank number (1-10) in a circular badge (#4F46E5 background, white text, 24x24), item thumbnail (40x40 circular, `CachedNetworkImage` with `Icons.checkroom` fallback), name/category label (14px, #1F2937), wear count in bold (e.g., "12 wears"), last worn date in 12px #6B7280 (e.g., "3 days ago" or "Mar 15"). Each row is an `InkWell` calling `onItemTap`.
  - [x] 7.4: Empty state: when `items` is empty, show "Start logging outfits to see your most worn items!" with `Icons.emoji_events_outlined` icon (32px, #9CA3AF).
  - [x] 7.5: Add `Semantics` labels: "Top worn items, [period] filter", "Rank [n], [item name], [wear count] wears".

- [x] Task 8: Mobile - Create NeglectedItemsSection widget (AC: 3, 4, 6)
  - [x] 8.1: Create `apps/mobile/lib/src/features/analytics/widgets/neglected_items_section.dart` with a `NeglectedItemsSection` StatelessWidget. Constructor accepts: `required List<Map<String, dynamic>> items`, `required ValueChanged<Map<String, dynamic>> onItemTap`.
  - [x] 8.2: Display a section header: "Neglected Items" (16px bold, #1F2937) with item count badge (e.g., "(5)").
  - [x] 8.3: Below the header, display a list of neglected items. Each row: item thumbnail (40x40 circular), name/category label (14px, #1F2937), days since worn in red (#EF4444) (e.g., "87 days" or "Never worn"), and if `purchasePrice` exists, a small CPW label. Each row is an `InkWell` calling `onItemTap`.
  - [x] 8.4: Empty/positive state: when `items` is empty, show "No neglected items -- great job wearing your wardrobe!" with `Icons.celebration` icon (32px, #22C55E).
  - [x] 8.5: Add `Semantics` labels: "Neglected items, [count] items", "[item name], not worn for [days] days".

- [x] Task 9: Mobile - Integrate new sections into AnalyticsDashboardScreen (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x] 9.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `List<Map<String, dynamic>>? _topWornItems`, `List<Map<String, dynamic>>? _neglectedItems`, `String _topWornPeriod = "all"`.
  - [x] 9.2: Update `_loadAnalytics()` to fetch all four endpoints in parallel using `Future.wait`: `getWardrobeSummary()`, `getItemsCpw()`, `getTopWornItems(period: _topWornPeriod)`, `getNeglectedItems()`. Store results in the corresponding state fields. Parse items from `results[2]["items"]` and `results[3]["items"]`.
  - [x] 9.3: Add a `_loadTopWorn(String period)` method for when the user changes the time filter. This only re-fetches `getTopWornItems(period: period)` (not the full dashboard). Sets `_topWornPeriod = period` and updates `_topWornItems` state.
  - [x] 9.4: In the `CustomScrollView` slivers, after the existing CPW list and its trailing `SizedBox`, add:
    - `SliverToBoxAdapter` wrapping `TopWornSection(items: _topWornItems ?? [], selectedPeriod: _topWornPeriod, onPeriodChanged: _loadTopWorn, onItemTap: _navigateToItemDetail)`.
    - `SliverToBoxAdapter` wrapping `NeglectedItemsSection(items: _neglectedItems ?? [], onItemTap: _navigateToItemDetail)`.
    - A final `SliverToBoxAdapter(child: SizedBox(height: 32))` for bottom padding.
  - [x] 9.5: The `_navigateToItemDetail` method already exists and accepts `Map<String, dynamic>` with an "id" key. Both new sections reuse it.

- [x] Task 10: Mobile - Widget tests for TopWornSection (AC: 1, 2, 4, 5, 9)
  - [x] 10.1: Create `apps/mobile/test/features/analytics/widgets/top_worn_section_test.dart`:
    - Renders section header "Top 10 Most Worn".
    - Displays three filter chips: "30 Days", "90 Days", "All Time".
    - Tapping a filter chip calls onPeriodChanged with correct value.
    - Renders ranked items with rank numbers 1-10.
    - Displays item name, wear count, and last worn date.
    - Tapping an item calls onItemTap.
    - Empty state shows prompt message when items list is empty.
    - Semantics labels present.

- [x] Task 11: Mobile - Widget tests for NeglectedItemsSection (AC: 3, 4, 6, 9)
  - [x] 11.1: Create `apps/mobile/test/features/analytics/widgets/neglected_items_section_test.dart`:
    - Renders section header "Neglected Items" with count.
    - Displays neglected items with days since worn.
    - Shows "Never worn" for items with no last_worn_date.
    - Tapping an item calls onItemTap.
    - Empty state shows positive "great job" message.
    - Semantics labels present.

- [x] Task 12: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 2, 3, 7, 9)
  - [x] 12.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders TopWornSection below CPW list.
    - Dashboard renders NeglectedItemsSection below TopWornSection.
    - Changing top-worn period filter triggers re-fetch of top-worn data only.
    - Top-worn section renders ranked items correctly.
    - Neglected section renders items with days-since-worn.
    - Dashboard error state still works (all four API calls fail).
    - Mock API returns all four endpoints in parallel.

- [x] Task 13: Regression testing (AC: all)
  - [x] 13.1: Run `flutter analyze` -- zero new issues.
  - [x] 13.2: Run `flutter test` -- all existing 878+ Flutter tests plus new tests pass.
  - [x] 13.3: Run `npm --prefix apps/api test` -- all existing 364+ API tests plus new tests pass.
  - [x] 13.4: Verify existing AnalyticsDashboardScreen tests pass with the new sections added.
  - [x] 13.5: Verify existing CPW list, summary cards, and HomeScreen tests still pass.

## Dev Notes

- This is the **fifth story in Epic 5** (Wardrobe Analytics & Wear Logging). It extends the Analytics Dashboard created in Story 5.4 with two new sections: a "Top 10 Most Worn" leaderboard and a "Neglected Items" list.
- This story implements **FR-ANA-03** (neglected items identification with 60-day threshold) and **FR-ANA-04** (top 10 most worn items leaderboard with time period filters).
- **Extends the existing analytics repository.** Story 5.4 created `apps/api/src/modules/analytics/analytics-repository.js` with `getWardrobeSummary` and `getItemsWithCpw`. This story adds `getTopWornItems` and `getNeglectedItems` methods to the same file, following the identical connection/RLS pattern.
- **Extends the existing AnalyticsDashboardScreen.** The two new sections are added as slivers in the existing `CustomScrollView`, below the CPW breakdown list. No new screen is created.
- **No new database migration needed.** All data exists: `items.wear_count`, `items.last_worn_date`, `items.created_at` (from Story 5.1), `wear_logs` and `wear_log_items` tables (from Story 5.1) for period-filtered queries. `items.purchase_price` and `items.currency` (from Story 2.4) for CPW on neglected items.
- **No new dependencies needed.** Uses `cached_network_image` (already in pubspec.yaml) for thumbnails, `ChoiceChip` from Material for filter chips, `intl` for date formatting.

### Design Decision: Period-Filtered Top Worn Uses wear_log_items

For the "All Time" filter, the query uses the `wear_count` column on `items` (fast, no joins). For "30 Days" and "90 Days" filters, the query counts `wear_log_items` entries within the date range by joining through `wear_logs.logged_date`. This is necessary because `wear_count` is a cumulative total with no time dimension. The `wear_log_items` table has an index on `item_id` (created in Story 5.1: `idx_wear_log_items_item`), and `wear_logs` has an index on `(profile_id, logged_date DESC)` (created in Story 5.1: `idx_wear_logs_profile_date`), making these queries efficient.

### Design Decision: Neglected Threshold is 60 Days Server-Side

FR-ANA-03 specifies "not worn in 60+ days, configurable." For V1, the 60-day threshold is a server-side constant in the SQL query. Making it configurable is deferred. The client displays whatever the API returns without knowledge of the threshold value. Note: the existing `computeNeglectStatus` in `apps/api/src/modules/items/repository.js` uses a 180-day threshold for the wardrobe grid badge (Story 2.7). The analytics neglected section uses a separate, more aggressive 60-day threshold per FR-ANA-03. These are intentionally different -- the badge (180 days) flags severely neglected items, while the analytics section (60 days) helps users stay proactive.

### Design Decision: Top Worn Period Filter Re-Fetches Independently

When the user taps a period filter chip, only the `getTopWornItems` endpoint is re-called (not the entire dashboard). This avoids unnecessary re-fetching of summary, CPW, and neglected data. The `_loadTopWorn` method updates only `_topWornItems` state.

### Design Decision: Sections Added as Slivers, Not Separate Tabs

The top-worn and neglected sections are added as additional slivers in the existing `CustomScrollView` of `AnalyticsDashboardScreen`. This follows the same progressive-enhancement pattern used in Story 5.4. When Story 5.6 (charts) and 5.7 (AI summary) are added, the dashboard may be restructured into tabs. For now, vertical scrolling keeps all analytics in a single view.

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getTopWornItems`, `getNeglectedItems` methods)
  - `apps/api/src/main.js` (add `GET /v1/analytics/top-worn`, `GET /v1/analytics/neglected` routes)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/top_worn_section.dart` (top worn leaderboard widget)
  - `apps/mobile/lib/src/features/analytics/widgets/neglected_items_section.dart` (neglected items widget)
  - `apps/mobile/test/features/analytics/widgets/top_worn_section_test.dart`
  - `apps/mobile/test/features/analytics/widgets/neglected_items_section_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add new state fields, parallel fetch, new slivers)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getTopWornItems`, `getNeglectedItems` methods)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add tests for new sections)
- Modified API test files:
  - `apps/api/test/modules/analytics/analytics-repository.test.js` (add tests for new methods)
  - `apps/api/test/modules/analytics/analytics-endpoints.test.js` (add tests for new endpoints)
- No SQL migration files.
- Analytics feature module directory structure after this story:
  ```
  apps/mobile/lib/src/features/analytics/
  ├── models/
  │   └── wear_log.dart (Story 5.1)
  ├── screens/
  │   ├── analytics_dashboard_screen.dart (modified)
  │   └── wear_calendar_screen.dart (Story 5.3)
  ├── services/
  │   └── wear_log_service.dart (Story 5.1)
  └── widgets/
      ├── cpw_item_row.dart (Story 5.4)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (NEW)
      ├── summary_cards_row.dart (Story 5.4)
      └── top_worn_section.dart (NEW)
  ```

### Technical Requirements

- **Analytics repository extension:** Add two new methods to the existing `createAnalyticsRepository` return object. Both follow the identical pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
- **Top-worn "all" query:** Simple `SELECT ... FROM app_public.items WHERE wear_count > 0 ORDER BY wear_count DESC LIMIT 10`. No joins needed.
- **Top-worn period query:** Requires join through `wear_log_items` -> `wear_logs` with date filter. Use parameterized day count: `WHERE wl.logged_date >= CURRENT_DATE - $2::integer`. The `$1` parameter is the user ID for RLS, `$2` is the day count (30 or 90).
- **Neglected items query:** `WHERE (last_worn_date IS NOT NULL AND last_worn_date < CURRENT_DATE - 60) OR (last_worn_date IS NULL AND wear_count = 0 AND created_at < CURRENT_DATE - 60)`. Sort by `COALESCE(last_worn_date, created_at::date) ASC` for stalest-first ordering. Include computed `days_since_worn` column.
- **Top-worn widget:** `ChoiceChip` from `material.dart` for period filters. Rank badge: `Container` with `BoxDecoration(shape: BoxShape.circle, color: #4F46E5)`, white `Text` inside. Item thumbnail: 40x40 `CachedNetworkImage` with circular clip.
- **Neglected items widget:** Days-since-worn text in red (#EF4444). "Never worn" for items with null `lastWornDate`. Count badge next to header.
- **Dashboard parallel fetch:** Update `Future.wait` from 2 calls to 4 calls. Index 0: summary, 1: items CPW, 2: top worn, 3: neglected. On period filter change, only re-fetch index 2.
- **Date formatting:** Use relative format for "last worn" dates (e.g., "3 days ago", "2 weeks ago"). Use `DateTime.now().difference(lastWornDate).inDays` for computation. For "days since worn" in neglected section, use the `daysSinceWorn` field returned by the API.

### Architecture Compliance

- **Server authority for analytics data:** Top-worn rankings and neglect detection are computed server-side via SQL. The client displays pre-computed results and the `daysSinceWorn` value from the API.
- **RLS enforces data isolation:** Both new endpoints are RLS-scoped. A user can only see their own top-worn and neglected items.
- **Mobile boundary owns presentation:** The API returns raw data (items, counts, dates). The client handles layout (ranked list, period chips, color coding, relative date formatting).
- **No new AI calls:** This story is purely data queries + UI display.
- **API module placement:** New methods go in the existing `apps/api/src/modules/analytics/analytics-repository.js`. New routes go in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/top-worn` and `GET /v1/analytics/neglected` follow the existing analytics endpoint naming convention.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `cached_network_image` -- item thumbnails
  - `intl: ^0.19.0` -- date formatting
  - `flutter/material.dart` -- `ChoiceChip`, `InkWell`, `CustomScrollView`, `SliverToBoxAdapter`
- API side: no new npm dependencies. Uses existing `pool` from `pg`.

### File Structure Requirements

- New mobile widgets go in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing Story 5.1/5.3/5.4 widgets.
- Test files mirror source structure under `apps/mobile/test/features/analytics/widgets/`.
- API tests extend the existing test files in `apps/api/test/modules/analytics/`.

### Testing Requirements

- **API repository tests** must verify:
  - Top-worn returns correct ranked items for all three periods
  - Top-worn respects the LIMIT 10
  - Top-worn period filters count wear_log_items within date range
  - Neglected items returns items exceeding 60-day threshold
  - Neglected items includes never-worn items older than 60 days
  - Neglected items excludes recently worn items
  - daysSinceWorn computed correctly for both cases
  - RLS enforcement (user isolation) for both methods
  - Edge cases: empty wardrobe, no worn items, all items recently worn
- **API endpoint tests** must verify:
  - 200 responses with correct JSON structure for both endpoints
  - 401 for unauthenticated requests
  - 400 for invalid period parameter
  - Empty results for qualifying edge cases
- **Mobile widget tests** must verify:
  - TopWornSection renders ranked items with rank badges
  - Period filter chips render and trigger callbacks
  - NeglectedItemsSection renders items with days-since-worn
  - Empty states render correctly for both sections
  - Item tap triggers navigation callback
  - Semantics labels present
- **Dashboard integration tests** must verify:
  - Both new sections appear in the scroll view
  - Period filter change triggers isolated re-fetch
  - Error state handles all four API failures
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 878+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 364+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 5.4** (done) established: `AnalyticsDashboardScreen` with `_loadAnalytics()` using `Future.wait` for parallel API calls, `_summary`, `_itemsCpw` state fields, `SummaryCardsRow`, `CpwItemRow`, `_navigateToItemDetail` method. The screen is a `CustomScrollView` with slivers. The analytics repository has `getWardrobeSummary` and `getItemsWithCpw`. API routes at `GET /v1/analytics/wardrobe-summary` and `GET /v1/analytics/items-cpw`. Story 5.4 completion notes: 364 total API tests, 878 total Flutter tests.
- **Story 5.4 dev notes explicitly state:** "Future stories (5.5, 5.6) will add more endpoints (top-worn, neglected, category distribution) following the same pattern." This confirms the extension approach.
- **Story 5.1** (done) established: `wear_logs` table (profile_id, logged_date, outfit_id, photo_url), `wear_log_items` table (wear_log_id, item_id), `wear_count` and `last_worn_date` columns on `items`, `increment_wear_counts` RPC, indexes on `wear_log_items(item_id)` and `wear_logs(profile_id, logged_date DESC)`.
- **Story 2.7** (done) established: `neglect_status` computed field via `computeNeglectStatus()` using 180-day threshold on the items repository. This is a *different* threshold from the 60-day analytics threshold in FR-ANA-03.
- **Story 2.4** (done) established: `purchase_price`, `currency` on items for CPW display in the neglected section.
- **HomeScreen constructor (as of Story 5.4):** Unchanged from Story 5.3. This story does NOT add new constructor params to any existing constructors.
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button.
  - `CachedNetworkImage` with `Icons.checkroom` fallback for thumbnails.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
- **Items table columns (as of Story 5.4):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `created_at`, `updated_at`.

### Key Anti-Patterns to Avoid

- DO NOT create a new screen for top-worn or neglected items. Both sections are added as slivers in the existing `AnalyticsDashboardScreen`.
- DO NOT reuse the `computeNeglectStatus` function from `apps/api/src/modules/items/repository.js` for the neglected items query. That function uses a 180-day threshold and is computed per-item on read. The analytics neglected query uses a 60-day threshold via SQL WHERE clause for efficient batch retrieval.
- DO NOT compute neglect detection client-side by fetching all items and filtering in Dart. Use the dedicated server-side endpoint.
- DO NOT re-fetch the entire dashboard when only the top-worn period filter changes. Only call `getTopWornItems` with the new period.
- DO NOT add charting libraries. This story uses simple list rendering. Charts come in Story 5.6.
- DO NOT implement category distribution or AI summary. Those are Stories 5.6 and 5.7.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify existing API endpoints or repository methods. Only add new methods.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT create a separate analytics service on mobile. The `ApiClient` methods are sufficient. A service class may be warranted in Story 5.6/5.7.
- DO NOT hardcode date formatting strings. Use `DateTime` arithmetic for relative dates.
- DO NOT confuse the two neglect thresholds: 180 days (wardrobe grid badge from Story 2.7) vs 60 days (analytics neglected section from FR-ANA-03).

### Out of Scope

- **Category Distribution Charts (FR-ANA-05):** Story 5.6.
- **AI-Generated Analytics Summary (FR-ANA-06):** Story 5.7.
- **Configurable neglect threshold:** FR-ANA-03 mentions "configurable" but V1 uses a fixed 60-day threshold.
- **Brand Value Analytics (FR-BRD-01, FR-BRD-02):** Epic 11.
- **Sustainability Scoring (FR-SUS-*):** Epic 11.
- **Gamification / Style Points:** Epic 6.
- **Premium gating:** Not required for FR-ANA-03, FR-ANA-04 (free-tier features).
- **Offline analytics viewing:** Out of scope for V1.
- **Swipe-to-dismiss or bulk actions on neglected items:** Not required by any FR.
- **Notifications for neglected items:** Not part of this story.

### References

- [Source: epics.md - Story 5.5: Top Worn & Neglected Items Analytics]
- [Source: epics.md - FR-ANA-03: The system shall identify neglected items (not worn in 60+ days, configurable) and display them in a dedicated section]
- [Source: epics.md - FR-ANA-04: The system shall display a "Top 10 Most Worn Items" leaderboard with time period filters]
- [Source: prd.md - Wardrobe Analytics: Cost-per-wear, neglected items, top-worn leaderboard, category distribution]
- [Source: architecture.md - Epic 5 Analytics & Wear Logging -> mobile/features/analytics, api/modules/analytics, infra/sql/functions]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: ux-design-specification.md - Anti-Patterns: Overwhelming Data Displays -- data must be visualized simply]
- [Source: ux-design-specification.md - Analytics/Sustainability Check: Accomplishment and Pride]
- [Source: 5-4-basic-wardrobe-value-analytics.md - AnalyticsDashboardScreen, analytics-repository.js, Future.wait parallel pattern, _navigateToItemDetail]
- [Source: 5-4-basic-wardrobe-value-analytics.md - "Future stories (5.5, 5.6) will add more endpoints following the same pattern"]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - wear_logs table, wear_log_items table, wear_count column, last_worn_date column, database indexes]
- [Source: 2-7-neglect-detection-badging.md - computeNeglectStatus with 180-day threshold (different from 60-day analytics threshold)]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing getWardrobeSummary and getItemsWithCpw methods]
- [Source: apps/api/src/modules/items/repository.js - NEGLECT_THRESHOLD_DAYS = 180, computeNeglectStatus function]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented `getTopWornItems(authContext, { period })` in analytics-repository.js. Supports "all" (uses wear_count column), "30", and "90" (counts wear_log_items within date range via JOIN). Validates period parameter, returns 400 for invalid values.
- Implemented `getNeglectedItems(authContext)` in analytics-repository.js. Returns items not worn in 60+ days or never-worn items created 60+ days ago, sorted by staleness. Computes daysSinceWorn and CPW server-side.
- Added `GET /v1/analytics/top-worn?period=all|30|90` and `GET /v1/analytics/neglected` routes in main.js. Both require authentication and follow existing error-handling patterns.
- Added `getTopWornItems()` and `getNeglectedItems()` to ApiClient.dart.
- Created `TopWornSection` widget with ranked leaderboard (1-10), ChoiceChip period filters (30 Days, 90 Days, All Time), item thumbnails, wear counts, relative date formatting, empty state, and Semantics labels.
- Created `NeglectedItemsSection` widget with item count badge, days-since-worn in red, "Never worn" label, CPW indicator, positive empty state, and Semantics labels.
- Updated `AnalyticsDashboardScreen` to fetch all 4 endpoints in parallel via Future.wait. Added `_loadTopWorn(period)` for isolated period filter re-fetch. Added both new sections as slivers below existing CPW list.
- API tests: 397 total (33 new) -- all passing.
- Flutter tests: 904 total (26 new) -- all passing.
- Flutter analyze: 0 new issues (5 pre-existing warnings in wear_calendar_screen_test.dart).

### Change Log

- 2026-03-18: Implemented Story 5.5 -- Top Worn & Neglected Items Analytics (FR-ANA-03, FR-ANA-04)

### File List

**New files:**
- `apps/mobile/lib/src/features/analytics/widgets/top_worn_section.dart`
- `apps/mobile/lib/src/features/analytics/widgets/neglected_items_section.dart`
- `apps/mobile/test/features/analytics/widgets/top_worn_section_test.dart`
- `apps/mobile/test/features/analytics/widgets/neglected_items_section_test.dart`

**Modified files:**
- `apps/api/src/modules/analytics/analytics-repository.js` (added getTopWornItems, getNeglectedItems)
- `apps/api/src/main.js` (added GET /v1/analytics/top-worn, GET /v1/analytics/neglected routes)
- `apps/mobile/lib/src/core/networking/api_client.dart` (added getTopWornItems, getNeglectedItems)
- `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (added state fields, parallel fetch, new slivers, _loadTopWorn)
- `apps/api/test/modules/analytics/analytics-repository.test.js` (added 21 new tests)
- `apps/api/test/modules/analytics/analytics-endpoints.test.js` (added 9 new tests)
- `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (added 7 new tests, updated mock)
