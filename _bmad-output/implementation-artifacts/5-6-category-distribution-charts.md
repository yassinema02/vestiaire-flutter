# Story 5.6: Category Distribution Charts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to visualize how my wardrobe is distributed across categories and see my wear frequency across the week,
so that I can identify imbalances (e.g., too many jackets, not enough tops) and understand my weekly wearing habits.

## Acceptance Criteria

1. Given I have categorized wardrobe items, when I scroll down the Analytics dashboard (existing `AnalyticsDashboardScreen`), then I see a new "Category Distribution" section below the existing "Neglected Items" section. The section displays a pie chart showing the distribution of items by category. Each slice represents a category (e.g., "tops", "bottoms", "outerwear") with its percentage. Only categories with at least 1 item appear. Categories are color-coded with distinct, accessible colors. (FR-ANA-05, FR-ANA-01)

2. Given I am viewing the "Category Distribution" pie chart, when the chart renders, then each slice is labeled with the category name and percentage (e.g., "Tops 35%"). Tapping a slice shows a tooltip with the exact item count and percentage (e.g., "Tops: 14 items (35%)"). The chart calculates percentages dynamically from the user's actual item data. (FR-ANA-05)

3. Given I am viewing the "Category Distribution" section, when the chart loads, then below the pie chart I see a legend listing each category with its color swatch, name, item count, and percentage. The legend is sorted by item count descending (largest category first). (FR-ANA-05)

4. Given I have wear logs, when I scroll below the "Category Distribution" section, then I see a "Wear Frequency" section displaying a bar chart showing the number of wear logs per day of the week (Monday through Sunday). Each bar represents a day. The bar height reflects the total number of wear_log entries for that day of the week across all time. (FR-ANA-05)

5. Given I am viewing the "Wear Frequency" bar chart, when I look at the bars, then each bar is labeled with the day abbreviation ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun") and the count value appears above the bar. The current day of the week is visually highlighted with the primary color (#4F46E5); other days use a secondary color (#C7D2FE). (FR-ANA-05)

6. Given I have no items in my wardrobe at all, when the "Category Distribution" section loads, then it shows an empty state: "Add items to see your wardrobe distribution!" with an `Icons.pie_chart_outline` icon (32px, #9CA3AF). The "Wear Frequency" section shows an empty state: "Start logging outfits to see your weekly patterns!" with an `Icons.bar_chart` icon. (FR-ANA-05)

7. Given the API calls to fetch category distribution or wear frequency data fail, when the analytics screen loads, then the existing error-retry pattern from Story 5.4 handles the failure gracefully -- the entire dashboard shows an error state with a "Retry" button. (FR-ANA-05)

8. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (397+ API tests, 904+ Flutter tests) and new tests cover: category distribution repository method, wear frequency repository method, API endpoints for both, mobile chart widget rendering for both sections, empty states, tooltip interactions, legend rendering, and edge cases.

## Tasks / Subtasks

- [x] Task 1: Add `fl_chart` dependency to mobile app (AC: 1, 4)
  - [x] 1.1: In `apps/mobile/pubspec.yaml`, add `fl_chart: ^0.70.2` under dependencies. Run `flutter pub get` to resolve.
  - [x] 1.2: Verify `flutter analyze` passes with zero new issues after adding the dependency.

- [x]Task 2: API - Add category distribution method to analytics repository (AC: 1, 2, 3, 6)
  - [x]2.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getCategoryDistribution(authContext)` method following the identical connection/RLS pattern as existing methods: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
  - [x]2.2: SQL query: `SELECT category, COUNT(*) AS item_count FROM app_public.items GROUP BY category ORDER BY item_count DESC`. This returns one row per category with its count.
  - [x]2.3: Compute total items from sum of all counts. For each row, compute `percentage = (item_count / totalItems) * 100` rounded to 1 decimal.
  - [x]2.4: Return array of objects: `{ category, itemCount, percentage }`. Map snake_case to camelCase.
  - [x]2.5: If no items exist (empty result), return an empty array.

- [x]Task 3: API - Add wear frequency method to analytics repository (AC: 4, 5, 6)
  - [x]3.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getWearFrequency(authContext)` method following the same pattern.
  - [x]3.2: SQL query: `SELECT EXTRACT(DOW FROM logged_date) AS day_of_week, COUNT(*) AS log_count FROM app_public.wear_logs GROUP BY day_of_week ORDER BY day_of_week`. DOW returns 0 (Sunday) through 6 (Saturday).
  - [x]3.3: Transform result into a 7-element array (Monday-Sunday order): map PostgreSQL DOW (0=Sun, 1=Mon, ..., 6=Sat) to ISO order (Mon=0, Tue=1, ..., Sun=6). Fill missing days with 0 count.
  - [x]3.4: Return array of 7 objects: `{ day: "Mon"|"Tue"|...|"Sun", dayIndex: 0-6, logCount: number }`. Always return all 7 days, even if count is 0.

- [x]Task 4: API - Add routes for category distribution and wear frequency (AC: 1, 4, 7)
  - [x]4.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/category-distribution`. Call `analyticsRepository.getCategoryDistribution(authContext)`. Return 200 with `{ categories: [...] }`. Requires authentication (401 if unauthenticated).
  - [x]4.2: In `apps/api/src/main.js`, add route `GET /v1/analytics/wear-frequency`. Call `analyticsRepository.getWearFrequency(authContext)`. Return 200 with `{ days: [...] }`. Requires authentication (401 if unauthenticated).

- [x]Task 5: API - Unit tests for new analytics repository methods (AC: 1, 2, 3, 4, 5, 6, 8)
  - [x]5.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getCategoryDistribution`:
    - Returns categories sorted by item_count descending.
    - Computes correct percentages (summing to 100).
    - Returns all categories present in the user's wardrobe.
    - Returns empty array for user with no items.
    - Respects RLS (user A cannot see user B's categories).
    - Handles single-category wardrobe (100%).
    - Handles items with null category (groups as null if any exist).
  - [x]5.2: Add tests for `getWearFrequency`:
    - Returns 7 elements (Mon-Sun) always.
    - Counts wear logs per day of week correctly.
    - Returns 0 for days with no wear logs.
    - Orders by Mon-Sun (ISO week order).
    - Respects RLS (user isolation).
    - Returns all zeros for user with no wear logs.
    - Correctly maps PostgreSQL DOW to ISO day order.

- [x]Task 6: API - Integration tests for new endpoints (AC: 1, 4, 7, 8)
  - [x]6.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/category-distribution` returns 200 with categories array.
    - `GET /v1/analytics/category-distribution` returns 401 if unauthenticated.
    - `GET /v1/analytics/category-distribution` returns empty array for user with no items.
    - `GET /v1/analytics/wear-frequency` returns 200 with 7-element days array.
    - `GET /v1/analytics/wear-frequency` returns 401 if unauthenticated.
    - `GET /v1/analytics/wear-frequency` returns all-zero counts for user with no wear logs.

- [x]Task 7: Mobile - Add API methods to ApiClient (AC: 1, 4)
  - [x]7.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getCategoryDistribution()` method. Calls `GET /v1/analytics/category-distribution` using `_authenticatedGet`. Returns response JSON map.
  - [x]7.2: Add `Future<Map<String, dynamic>> getWearFrequency()` method. Calls `GET /v1/analytics/wear-frequency` using `_authenticatedGet`. Returns response JSON map.

- [x]Task 8: Mobile - Create CategoryDistributionSection widget (AC: 1, 2, 3, 6)
  - [x]8.1: Create `apps/mobile/lib/src/features/analytics/widgets/category_distribution_section.dart` with a `CategoryDistributionSection` StatelessWidget. Constructor accepts: `required List<Map<String, dynamic>> categories`.
  - [x]8.2: Display a section header: "Category Distribution" (16px bold, #1F2937).
  - [x]8.3: Below the header, render a `PieChart` from `fl_chart` package (200x200 centered). Each `PieChartSectionData` has: `value` = itemCount, `title` = "[Category] [percentage]%" (e.g., "Tops 35%"), `color` from a predefined category color map, `radius` = 80, `titleStyle` = 11px bold white. Use `showingSections()` to build sections from the `categories` list.
  - [x]8.4: Category color map (consistent across the app): tops=#4F46E5, bottoms=#22C55E, dresses=#EC4899, outerwear=#F59E0B, shoes=#EF4444, bags=#8B5CF6, accessories=#06B6D4, activewear=#14B8A6, swimwear=#3B82F6, underwear=#A78BFA, sleepwear=#6366F1, suits=#0EA5E9, other=#9CA3AF.
  - [x]8.5: Below the pie chart, render a legend: a `Wrap` widget with `LegendItem` widgets. Each `LegendItem` shows: a 12x12 color swatch (rounded square), category name (12px, #1F2937), item count and percentage in parentheses (12px, #6B7280). Legend is sorted by item count descending (same order as API response).
  - [x]8.6: Handle touch interactions: when `PieChart` `pieTouchData` reports a touch on a section, highlight that section by increasing its radius to 90 and show a tooltip via `PieTouchResponse`. The tooltip shows "[Category]: [count] items ([percentage]%)".
  - [x]8.7: Empty state: when `categories` is empty, show "Add items to see your wardrobe distribution!" with `Icons.pie_chart_outline` icon (32px, #9CA3AF).
  - [x]8.8: Add `Semantics` labels: "Category distribution chart, [count] categories", "Category [name], [count] items, [percentage] percent".

- [x]Task 9: Mobile - Create WearFrequencySection widget (AC: 4, 5, 6)
  - [x]9.1: Create `apps/mobile/lib/src/features/analytics/widgets/wear_frequency_section.dart` with a `WearFrequencySection` StatelessWidget. Constructor accepts: `required List<Map<String, dynamic>> days`.
  - [x]9.2: Display a section header: "Wear Frequency" (16px bold, #1F2937).
  - [x]9.3: Below the header, render a `BarChart` from `fl_chart` (height 200). Create 7 `BarChartGroupData` entries (Mon-Sun). Each bar has `y` = logCount from the `days` array. Bar color: #4F46E5 (primary) for the current day of week (`DateTime.now().weekday - 1` maps to index 0-6), #C7D2FE (light) for other days. Bar width: 28.
  - [x]9.4: X-axis labels: "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" (12px, #6B7280). Y-axis: auto-scaled based on max count value. Show count value above each bar via `BarTooltipItem` shown always (not just on touch).
  - [x]9.5: Empty state: when all day counts are 0, show "Start logging outfits to see your weekly patterns!" with `Icons.bar_chart` icon (32px, #9CA3AF).
  - [x]9.6: Add `Semantics` labels: "Wear frequency chart, weekly distribution", "[day], [count] outfits logged".

- [x]Task 10: Mobile - Integrate new sections into AnalyticsDashboardScreen (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x]10.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `List<Map<String, dynamic>>? _categoryDistribution`, `List<Map<String, dynamic>>? _wearFrequency`.
  - [x]10.2: Update `_loadAnalytics()` to fetch all six endpoints in parallel using `Future.wait`: existing `getWardrobeSummary()`, `getItemsCpw()`, `getTopWornItems(period: _topWornPeriod)`, `getNeglectedItems()`, plus new `getCategoryDistribution()`, `getWearFrequency()`. Store results in the corresponding state fields. Parse from `results[4]["categories"]` and `results[5]["days"]`.
  - [x]10.3: In the `CustomScrollView` slivers, after the existing `NeglectedItemsSection` sliver, add:
    - `SliverToBoxAdapter` wrapping `CategoryDistributionSection(categories: _categoryDistribution ?? [])`.
    - `SliverToBoxAdapter` wrapping `WearFrequencySection(days: _wearFrequency ?? [])`.
    - Keep the final `SliverToBoxAdapter(child: SizedBox(height: 32))` for bottom padding after the new sections.
  - [x]10.4: No new `_navigateToItemDetail` calls needed -- charts are informational, not navigational to individual items.

- [x]Task 11: Mobile - Widget tests for CategoryDistributionSection (AC: 1, 2, 3, 6, 8)
  - [x]11.1: Create `apps/mobile/test/features/analytics/widgets/category_distribution_section_test.dart`:
    - Renders section header "Category Distribution".
    - Renders PieChart widget when categories are provided.
    - Renders legend with correct category names, counts, and percentages.
    - Legend is sorted by item count descending.
    - Empty state shows prompt message when categories list is empty.
    - Color swatches in legend match expected category colors.
    - Semantics labels present.

- [x]Task 12: Mobile - Widget tests for WearFrequencySection (AC: 4, 5, 6, 8)
  - [x]12.1: Create `apps/mobile/test/features/analytics/widgets/wear_frequency_section_test.dart`:
    - Renders section header "Wear Frequency".
    - Renders BarChart widget when days data is provided.
    - Displays 7 bars (Mon-Sun).
    - Empty state shows prompt when all counts are 0.
    - Semantics labels present.

- [x]Task 13: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 4, 7, 8)
  - [x]13.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders CategoryDistributionSection below NeglectedItemsSection.
    - Dashboard renders WearFrequencySection below CategoryDistributionSection.
    - Dashboard error state still works (all six API calls fail).
    - Mock API returns all six endpoints in parallel.
    - Category distribution section renders pie chart with test data.
    - Wear frequency section renders bar chart with test data.

- [x]Task 14: Regression testing (AC: all)
  - [x]14.1: Run `flutter analyze` -- zero new issues.
  - [x]14.2: Run `flutter test` -- all existing 904+ Flutter tests plus new tests pass.
  - [x]14.3: Run `npm --prefix apps/api test` -- all existing 397+ API tests plus new tests pass.
  - [x]14.4: Verify existing AnalyticsDashboardScreen tests pass with the new sections added (mock API updated to return 6 endpoints).
  - [x]14.5: Verify existing TopWornSection, NeglectedItemsSection, CPW list, and summary card tests still pass.

## Dev Notes

- This is the **sixth story in Epic 5** (Wardrobe Analytics & Wear Logging). It extends the Analytics Dashboard created in Story 5.4 and expanded in Story 5.5 with two new chart sections: a category distribution pie chart and a wear frequency bar chart.
- This story implements **FR-ANA-05** (wear frequency bar chart and category distribution pie chart).
- **First new dependency since Epic 3.** This story introduces `fl_chart` for chart rendering. This is the only charting library needed -- it provides PieChart and BarChart widgets natively. Do NOT use `syncfusion_flutter_charts`, `charts_flutter`, or any other charting package.
- **Extends the existing analytics repository.** Story 5.4 created `analytics-repository.js` with `getWardrobeSummary` and `getItemsWithCpw`. Story 5.5 added `getTopWornItems` and `getNeglectedItems`. This story adds `getCategoryDistribution` and `getWearFrequency` methods to the same file, following the identical connection/RLS pattern.
- **Extends the existing AnalyticsDashboardScreen.** The two new sections are added as slivers in the existing `CustomScrollView`, below the `NeglectedItemsSection`. No new screen is created.
- **No new database migration needed.** Category distribution uses `items.category` (established in Story 2.3). Wear frequency uses `wear_logs.logged_date` (established in Story 5.1). Both columns are already indexed.
- **Dashboard now fetches 6 endpoints in parallel.** The `Future.wait` call in `_loadAnalytics()` grows from 4 to 6 calls. This is still efficient since all calls are independent and parallel.

### Design Decision: fl_chart as Charting Library

`fl_chart` is chosen because:
1. It is the most popular Flutter charting library on pub.dev (11k+ likes).
2. It provides native PieChart and BarChart widgets with touch interaction support.
3. It is lightweight (no heavy dependencies) and well-maintained.
4. It is MIT-licensed.
5. Previous stories (5.4, 5.5) explicitly deferred chart functionality to this story with notes like "DO NOT add charting libraries -- charts come in Story 5.6."

### Design Decision: Category Distribution Uses Server-Side GROUP BY

The category distribution is computed server-side via `GROUP BY category` on the items table. This follows the established architecture principle of "server authority for analytics data." The client receives pre-computed category counts and percentages, avoiding the need to fetch all items and count client-side. RLS ensures data isolation.

### Design Decision: Wear Frequency Uses All-Time Data

The wear frequency bar chart shows all-time wear log counts per day of week. This provides a stable pattern (unlike a rolling 30-day window which might be sparse for new users). A future enhancement could add period filters similar to the top-worn section, but FR-ANA-05 does not require this.

### Design Decision: Charts Added as Slivers, Not Tabs

The chart sections continue the vertical scroll pattern from Stories 5.4 and 5.5. Story 5.5 noted: "When Story 5.6 (charts) and 5.7 (AI summary) are added, the dashboard may be restructured into tabs." After analysis, keeping vertical scroll is preferred because: (1) the total content is still manageable in a single scroll, (2) restructuring to tabs would break the established pattern and require significant refactoring better suited for a separate story, (3) Story 5.7 (AI summary) is the final analytics section and can add tabs if needed.

### Design Decision: PostgreSQL DOW Mapping

PostgreSQL `EXTRACT(DOW FROM date)` returns 0=Sunday through 6=Saturday. The API transforms this to ISO week order (Monday first) before returning to the client. The client receives data already in Mon-Sun order and does not need to handle the mapping.

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getCategoryDistribution`, `getWearFrequency` methods)
  - `apps/api/src/main.js` (add `GET /v1/analytics/category-distribution`, `GET /v1/analytics/wear-frequency` routes)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/category_distribution_section.dart` (pie chart widget)
  - `apps/mobile/lib/src/features/analytics/widgets/wear_frequency_section.dart` (bar chart widget)
  - `apps/mobile/test/features/analytics/widgets/category_distribution_section_test.dart`
  - `apps/mobile/test/features/analytics/widgets/wear_frequency_section_test.dart`
- Modified mobile files:
  - `apps/mobile/pubspec.yaml` (add `fl_chart: ^0.70.2`)
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add new state fields, update parallel fetch to 6 calls, add new slivers)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getCategoryDistribution`, `getWearFrequency` methods)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add tests for new sections, update mock to 6 endpoints)
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
      ├── category_distribution_section.dart (NEW)
      ├── cpw_item_row.dart (Story 5.4)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── summary_cards_row.dart (Story 5.4)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (NEW)
  ```

### Technical Requirements

- **Analytics repository extension:** Add two new methods to the existing `createAnalyticsRepository` return object. Both follow the identical pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
- **Category distribution query:** `SELECT category, COUNT(*) AS item_count FROM app_public.items GROUP BY category ORDER BY item_count DESC`. Compute percentage in JS: `(itemCount / totalItems) * 100` rounded to 1 decimal via `Math.round(... * 10) / 10`.
- **Wear frequency query:** `SELECT EXTRACT(DOW FROM logged_date) AS day_of_week, COUNT(*) AS log_count FROM app_public.wear_logs GROUP BY day_of_week ORDER BY day_of_week`. Map DOW (0=Sun, 1=Mon, ..., 6=Sat) to ISO order (Mon-Sun). Initialize a 7-element array with 0 counts, then fill from query results.
- **fl_chart PieChart:** Use `PieChart(PieChartData(sections: [...], pieTouchData: PieTouchData(...)))`. Each section: `PieChartSectionData(value: itemCount.toDouble(), title: "$category $percentage%", color: categoryColor, radius: 80, titleStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))`. Touched section radius increases to 90.
- **fl_chart BarChart:** Use `BarChart(BarChartData(barGroups: [...], titlesData: FlTitlesData(...)))`. Each group: `BarChartGroupData(x: dayIndex, barRods: [BarChartRodData(toY: logCount.toDouble(), color: isToday ? #4F46E5 : #C7D2FE, width: 28, borderRadius: BorderRadius.vertical(top: Radius.circular(4)))])`. X-axis titles from `["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]`.
- **Category color map:** Define as a `const Map<String, Color>` in the category distribution widget file. 13 categories from taxonomy.js mapped to distinct, accessible colors. Use the `other` color (#9CA3AF) as fallback for any unrecognized category.
- **Dashboard parallel fetch:** Update `Future.wait` from 4 calls to 6 calls. Index 0: summary, 1: items CPW, 2: top worn, 3: neglected, 4: category distribution, 5: wear frequency.

### Architecture Compliance

- **Server authority for analytics data:** Category counts and wear frequency distributions are computed server-side via SQL GROUP BY. The client displays pre-computed results.
- **RLS enforces data isolation:** Both new endpoints are RLS-scoped. A user can only see their own category distribution and wear frequency.
- **Mobile boundary owns presentation:** The API returns raw data (category counts, day-of-week counts). The client handles chart rendering, colors, tooltips, and layout.
- **No new AI calls:** This story is purely data aggregation + chart rendering.
- **API module placement:** New methods go in the existing `apps/api/src/modules/analytics/analytics-repository.js`. New routes go in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/category-distribution` and `GET /v1/analytics/wear-frequency` follow the existing analytics endpoint naming convention.

### Library / Framework Requirements

- **NEW dependency:** `fl_chart: ^0.70.2` -- pie chart and bar chart rendering. This is the ONLY new dependency for this story. Add to `apps/mobile/pubspec.yaml` under `dependencies`.
- Existing dependencies used:
  - `flutter/material.dart` -- `CustomScrollView`, `SliverToBoxAdapter`, `Wrap`, `Container`
  - `intl: ^0.19.0` -- not directly used by charts, but available if date formatting needed
- API side: no new npm dependencies. Uses existing `pool` from `pg`.

### File Structure Requirements

- New mobile widgets go in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing Story 5.1/5.3/5.4/5.5 widgets.
- Test files mirror source structure under `apps/mobile/test/features/analytics/widgets/`.
- API tests extend the existing test files in `apps/api/test/modules/analytics/`.

### Testing Requirements

- **API repository tests** must verify:
  - Category distribution returns correct counts per category sorted descending
  - Category distribution computes correct percentages
  - Category distribution returns empty array for empty wardrobe
  - Category distribution respects RLS (user isolation)
  - Wear frequency returns 7 elements always (Mon-Sun)
  - Wear frequency counts wear logs per day of week correctly
  - Wear frequency returns 0 for days with no logs
  - Wear frequency maps PostgreSQL DOW to ISO week order correctly
  - Wear frequency respects RLS
  - Wear frequency returns all zeros for user with no wear logs
- **API endpoint tests** must verify:
  - 200 responses with correct JSON structure for both endpoints
  - 401 for unauthenticated requests
  - Empty/zero results for qualifying edge cases
- **Mobile widget tests** must verify:
  - CategoryDistributionSection renders PieChart with categories
  - Legend renders with correct colors, names, counts, percentages
  - CategoryDistributionSection empty state renders correctly
  - WearFrequencySection renders BarChart with 7 bars
  - WearFrequencySection empty state renders for all-zero counts
  - Semantics labels present on both sections
- **Dashboard integration tests** must verify:
  - Both new sections appear in the scroll view after NeglectedItemsSection
  - Error state handles all six API failures
  - Mock API updated to return 6 parallel endpoint responses
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 904+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 397+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 5.5** (done) established: `TopWornSection` and `NeglectedItemsSection` widgets in `apps/mobile/lib/src/features/analytics/widgets/`. Dashboard now fetches 4 endpoints in parallel via `Future.wait`. `_topWornItems`, `_neglectedItems` state fields. `_loadTopWorn(period)` for isolated period re-fetch. Test counts: 397 API tests, 904 Flutter tests. Story 5.5 completion notes: "Future stories (5.6, 5.7) will add more endpoints following the same pattern."
- **Story 5.4** (done) established: `AnalyticsDashboardScreen` with `CustomScrollView` slivers, `_loadAnalytics()`, `SummaryCardsRow`, `CpwItemRow`, `_navigateToItemDetail`, error-retry pattern. The analytics repository has 4 methods total. API routes at `GET /v1/analytics/*`. Story 5.4 noted: "Future stories (5.5, 5.6) will add more endpoints following the same pattern."
- **Story 5.1** (done) established: `wear_logs` table with `logged_date DATE` column, `wear_log_items` table. Index `idx_wear_logs_profile_date` on `(profile_id, logged_date DESC)`. This provides the data source for the wear frequency bar chart.
- **Story 2.3** (done) established: `items.category` column with values from `VALID_CATEGORIES` taxonomy. Categories: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other. This provides the data source for the category distribution pie chart.
- **Valid categories** (from `apps/api/src/modules/ai/taxonomy.js`): `["tops", "bottoms", "dresses", "outerwear", "shoes", "bags", "accessories", "activewear", "swimwear", "underwear", "sleepwear", "suits", "other"]`. The category color map must cover all 13 values.
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Section headers: 16px bold, #1F2937.
  - Empty state icons: 32px, #9CA3AF with descriptive text.
- **Items table columns (as of Story 5.5):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `created_at`, `updated_at`.

### Key Anti-Patterns to Avoid

- DO NOT use any charting library other than `fl_chart`. Do not use `syncfusion_flutter_charts`, `charts_flutter`, `graphic`, or custom `CustomPainter` charts.
- DO NOT compute category distribution client-side by fetching all items via `GET /v1/items` and counting in Dart. Use the dedicated server-side endpoint.
- DO NOT compute wear frequency client-side by fetching all wear logs and counting in Dart. Use the dedicated server-side endpoint.
- DO NOT create a new screen for charts. Both sections are added as slivers in the existing `AnalyticsDashboardScreen`.
- DO NOT restructure the dashboard into tabs. Keep the vertical scroll pattern. Tab restructuring (if needed) is deferred to a future story.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify existing API endpoints or repository methods. Only add new methods.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT hardcode day-of-week labels in the API response. The API returns day names ("Mon", "Tue", etc.) so the client does not need to do DOW->name mapping.
- DO NOT implement AI analytics summary in this story. That is Story 5.7 (FR-ANA-06).
- DO NOT implement brand value analytics or sustainability scoring. Those are Epic 11.
- DO NOT re-fetch the entire dashboard when no filter changes occur. The initial load fetches all 6 endpoints in parallel; no chart-specific re-fetch is needed since charts show all-time data.
- DO NOT use `PieChart` `centerSpaceRadius: 0` for a full pie. Use a donut style with `centerSpaceRadius: 40` for a modern look -- but only if the design looks better. The standard pie (centerSpaceRadius: 0) is acceptable per FR-ANA-05.
- DO NOT forget to handle the case where `items.category` might be null. The GROUP BY will create a null category bucket. Map null category to "Uncategorized" in the display name.

### Out of Scope

- **AI-Generated Analytics Summary (FR-ANA-06):** Story 5.7.
- **Brand Value Analytics (FR-BRD-01, FR-BRD-02):** Epic 11.
- **Sustainability Scoring (FR-SUS-*):** Epic 11.
- **Gamification / Style Points:** Epic 6.
- **Premium gating:** Not required for FR-ANA-05 (free-tier feature).
- **Offline analytics viewing:** Out of scope for V1.
- **Period filters on wear frequency chart:** FR-ANA-05 does not require time filters on the wear frequency chart. All-time data is sufficient.
- **Drill-down from chart slices to filtered wardrobe view:** Not required by any FR.
- **Animation on chart load:** Nice-to-have if fl_chart provides it by default, but not a requirement.
- **Landscape chart orientation:** Portrait-only per architecture principle.
- **Color/season/pattern distribution charts:** Only category distribution is specified in FR-ANA-05.
- **Tab restructuring of analytics dashboard:** Deferred. The vertical scroll pattern continues.

### References

- [Source: epics.md - Story 5.6: Category Distribution Charts]
- [Source: epics.md - FR-ANA-05: The system shall display a wear frequency bar chart and category distribution pie chart]
- [Source: epics.md - FR-ANA-01: The analytics dashboard shall display: total items, total wardrobe value, average cost-per-wear, and category distribution]
- [Source: prd.md - Wardrobe Analytics: Cost-per-wear, neglected items, top-worn leaderboard, category distribution]
- [Source: architecture.md - Epic 5 Analytics & Wear Logging -> mobile/features/analytics, api/modules/analytics, infra/sql/functions]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: ux-design-specification.md - Anti-Patterns: Overwhelming Data Displays -- data must be visualized simply]
- [Source: ux-design-specification.md - Analytics/Sustainability Check: Accomplishment and Pride]
- [Source: ux-design-specification.md - fitness app progress ring visualization for wardrobe utilization]
- [Source: apps/api/src/modules/ai/taxonomy.js - VALID_CATEGORIES: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing getWardrobeSummary, getItemsWithCpw, getTopWornItems, getNeglectedItems methods]
- [Source: infra/sql/migrations/015_wear_logs.sql - wear_logs table with logged_date DATE column, idx_wear_logs_profile_date index]
- [Source: 5-5-top-worn-neglected-items-analytics.md - AnalyticsDashboardScreen with 4 parallel API calls, TopWornSection, NeglectedItemsSection, 397 API tests, 904 Flutter tests]
- [Source: 5-4-basic-wardrobe-value-analytics.md - AnalyticsDashboardScreen, analytics-repository.js, Future.wait parallel pattern, CustomScrollView slivers]
- [Source: 5-4-basic-wardrobe-value-analytics.md - "Future stories (5.5, 5.6) will add more endpoints following the same pattern"]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None.

### Completion Notes List

- Added `fl_chart: ^0.70.2` dependency to mobile app. No new analyze issues introduced.
- Added `getCategoryDistribution(authContext)` and `getWearFrequency(authContext)` repository methods to analytics-repository.js following the identical RLS/connection pattern as existing methods.
- Added `GET /v1/analytics/category-distribution` and `GET /v1/analytics/wear-frequency` routes in main.js.
- PostgreSQL DOW mapping (0=Sun through 6=Sat) correctly transformed to ISO order (Mon-Sun) in the API.
- Created `CategoryDistributionSection` widget with PieChart, touch interactions, legend, empty state, and semantics.
- Created `WearFrequencySection` widget with BarChart, day-of-week highlighting, empty state, and semantics.
- Updated `AnalyticsDashboardScreen` to fetch 6 endpoints in parallel and render new sections below NeglectedItemsSection.
- API tests: 419 total (397 baseline + 22 new). All pass.
- Flutter tests: 922 total (904 baseline + 18 new). All pass.
- `flutter analyze`: 5 issues (all pre-existing, zero new).

### Change Log

- 2026-03-18: Implemented Story 5.6 - Category Distribution Charts. Added fl_chart dependency, 2 new API repository methods, 2 new API routes, 2 new Flutter chart widgets, updated analytics dashboard to 6 parallel API calls.

### File List

**New files:**
- apps/mobile/lib/src/features/analytics/widgets/category_distribution_section.dart
- apps/mobile/lib/src/features/analytics/widgets/wear_frequency_section.dart
- apps/mobile/test/features/analytics/widgets/category_distribution_section_test.dart
- apps/mobile/test/features/analytics/widgets/wear_frequency_section_test.dart

**Modified files:**
- apps/mobile/pubspec.yaml (added fl_chart: ^0.70.2)
- apps/mobile/lib/src/core/networking/api_client.dart (added getCategoryDistribution, getWearFrequency methods)
- apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart (added 2 new state fields, updated Future.wait to 6 calls, added 2 new slivers)
- apps/api/src/modules/analytics/analytics-repository.js (added getCategoryDistribution, getWearFrequency methods)
- apps/api/src/main.js (added GET /v1/analytics/category-distribution, GET /v1/analytics/wear-frequency routes)
- apps/api/test/modules/analytics/analytics-repository.test.js (added 15 tests for new repository methods)
- apps/api/test/modules/analytics/analytics-endpoints.test.js (added 6 endpoint tests)
- apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart (added 4 integration tests, updated mocks for 6 endpoints)
