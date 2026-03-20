# Story 11.4: Seasonal Reports & Heatmaps

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want detailed reports on how my wearing habits change with the seasons and a calendar heatmap showing my logging activity across the year,
so that I can better prepare for seasonal transitions and visually track my consistency.

## Acceptance Criteria

1. Given I am a Premium user with wardrobe items and wear logs, when I scroll down the Analytics dashboard (existing `AnalyticsDashboardScreen`), then I see a new "Seasonal Reports" section below the existing "Wardrobe Gaps" section. The section displays reports for each season (Spring, Summer, Fall, Winter) showing: item count tagged for that season, most worn items in that season, neglected items in that season, and a seasonal readiness score (1-10). The current/upcoming season's report is expanded by default; other seasons are collapsed in an accordion. (FR-SEA-01, FR-SEA-02)

2. Given a seasonal report is displayed, when I view it, then each report includes a historical comparison line (e.g., "This winter you wore 12% more items than last winter"). The comparison is computed server-side by comparing the current season's total wears against the same season in the prior year. If no prior year data exists, the comparison line shows "First [season] tracked -- keep logging to see trends!" (FR-SEA-03)

3. Given a new season is approaching (within 14 days of a seasonal boundary), when the seasonal reports API is called, then the API response includes a `transitionAlert` object with: `upcomingSeason` name, `daysUntil` count, and `readinessScore` for the upcoming season. The mobile client displays a prominent alert card at the top of the Seasonal Reports section: "Spring is coming in X days! Your readiness: Y/10" with an icon and a call-to-action to review the upcoming season's report. (FR-SEA-04)

4. Given I have wear logs, when I navigate to the Heatmap screen (accessible via a "View Heatmap" button in the Seasonal Reports section), then I see a calendar heatmap showing daily wear activity with color intensity proportional to the number of items worn that day. Days with 0 items are light grey (#F3F4F6), 1-2 items are light green (#BBF7D0), 3-5 items are medium green (#4ADE80), 6+ items are dark green (#16A34A). The default view is the current month. (FR-HMP-01)

5. Given I am on the Heatmap screen, when I toggle the view mode, then I can switch between Month, Quarter, and Year views. Month shows a standard calendar grid (reusing the grid pattern from Story 5.3). Quarter shows 3 months side-by-side in a compact layout with smaller day cells. Year shows all 12 months in a 4x3 grid with tiny day cells (similar to GitHub contribution graph). (FR-HMP-02)

6. Given I am on the Heatmap screen, when I tap a day cell that has wear activity, then a bottom sheet overlay appears showing the outfits/items worn that day. The overlay reuses the existing `DayDetailBottomSheet` from Story 5.3 which shows item thumbnails, names, and wear log details. (FR-HMP-03)

7. Given I am on the Heatmap screen, when the heatmap data loads, then below the heatmap grid I see streak statistics: current streak (consecutive days with at least one wear log), longest streak ever, total days logged, and average items per day. These are computed from the wear log data for the visible time period. (FR-HMP-04)

8. Given I am a Free user viewing the Analytics dashboard, when the "Seasonal Reports" section would render, then instead a `PremiumGateCard` is displayed with title "Seasonal Reports & Heatmap", subtitle "Track your seasonal wearing patterns and daily activity", icon `Icons.calendar_month_outlined`, and a "Go Premium" CTA that calls `subscriptionService.presentPaywallIfNeeded()`. Free users do NOT trigger the seasonal reports API call. The heatmap button is not shown. (FR-SEA-01, Premium gating per architecture)

9. Given I have no wear logs at all, when the Seasonal Reports section loads, then it shows an empty state: "Start logging your outfits to see seasonal patterns!" with an `Icons.calendar_month_outlined` icon (32px, #9CA3AF). The heatmap screen shows an empty grid with the message "No wear data yet. Log your outfits to build your heatmap!"

10. Given the API call to fetch seasonal report data fails, when the analytics screen loads, then the existing error-retry pattern from Story 5.4 handles the failure gracefully -- the entire dashboard shows an error state with a "Retry" button.

11. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1115+ API tests, 1554+ Flutter tests) and new tests cover: seasonal reports repository method, historical comparison, transition alert, API endpoint (auth, premium gating, empty wardrobe), heatmap screen (view modes, color intensity, day tap, streak stats), mobile SeasonalReportsSection widget (premium/free states, season accordion, readiness score, transition alert, empty state), dashboard integration, and edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Add seasonal reports method to analytics repository (AC: 1, 2, 3, 9)
  - [x] 1.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getSeasonalReports(authContext)` method following the identical connection/RLS pattern as existing methods: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
  - [x] 1.2: Define season date boundaries using meteorological seasons: Spring (Mar 1 - May 31), Summer (Jun 1 - Aug 31), Fall (Sep 1 - Nov 30), Winter (Dec 1 - Feb 28/29). Determine current season and upcoming season from `new Date()`.
  - [x] 1.3: For each season, execute SQL queries to gather: (a) Item count: `SELECT COUNT(*) FROM app_public.items WHERE season @> ARRAY['<season>']::text[]` (items tagged with that season via the `season` array column). (b) Most worn items: `SELECT i.id, i.name, i.photo_url, i.category, i.wear_count FROM app_public.items i WHERE i.season @> ARRAY['<season>']::text[] ORDER BY i.wear_count DESC LIMIT 5`. (c) Neglected items: `SELECT i.id, i.name, i.photo_url, i.category, i.wear_count FROM app_public.items i WHERE i.season @> ARRAY['<season>']::text[] AND (i.wear_count = 0 OR i.last_worn_date < CURRENT_DATE - INTERVAL '90 days') ORDER BY i.wear_count ASC, i.last_worn_date ASC NULLS FIRST LIMIT 5`. (d) Total wears this season period: `SELECT COALESCE(SUM(i.wear_count), 0) FROM app_public.items i WHERE i.season @> ARRAY['<season>']::text[]`.
  - [x] 1.4: Compute seasonal readiness score (1-10) per season: `Math.min(10, Math.max(1, Math.round((seasonItemCount / Math.max(totalItems, 1)) * 20 + (seasonWornItems / Math.max(seasonItemCount, 1)) * 5)))`. A well-stocked, well-worn season scores higher. Clamp to 1-10.
  - [x] 1.5: Historical comparison: For each season, query wear logs from the same season date range in the prior year: `SELECT COUNT(DISTINCT wli.item_id) FROM app_public.wear_logs wl JOIN app_public.wear_log_items wli ON wl.id = wli.wear_log_id WHERE wl.logged_date >= $1 AND wl.logged_date <= $2`. Compare current vs prior year: `percentChange = priorYearCount > 0 ? Math.round(((currentCount - priorYearCount) / priorYearCount) * 100) : null`. Return `{ percentChange: number | null, comparisonText: string }`.
  - [x] 1.6: Transition alert: Calculate days until the next season boundary. If `daysUntil <= 14`, include `transitionAlert: { upcomingSeason: string, daysUntil: number, readinessScore: number }` in the response. If `daysUntil > 14`, set `transitionAlert: null`.
  - [x] 1.7: Return object: `{ seasons: [{ season: string, itemCount: number, totalWears: number, mostWorn: [{id, name, photoUrl, category, wearCount}], neglected: [{id, name, photoUrl, category, wearCount}], readinessScore: number, historicalComparison: { percentChange: number|null, comparisonText: string } }], currentSeason: string, transitionAlert: { upcomingSeason, daysUntil, readinessScore } | null, totalItems: number }`. Map snake_case to camelCase.

- [x] Task 2: API - Add heatmap data method to analytics repository (AC: 4, 5, 6, 7)
  - [x] 2.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getHeatmapData(authContext, { startDate, endDate })` method. Uses same connection/RLS pattern.
  - [x] 2.2: SQL query: `SELECT wl.logged_date, COUNT(DISTINCT wli.item_id) AS items_count FROM app_public.wear_logs wl JOIN app_public.wear_log_items wli ON wl.id = wli.wear_log_id WHERE wl.logged_date >= $1 AND wl.logged_date <= $2 GROUP BY wl.logged_date ORDER BY wl.logged_date`. Return array of `{ date: string, itemsCount: number }`.
  - [x] 2.3: Compute streak statistics from the full wear log history (not limited to the date range): current streak (consecutive days ending on today with >= 1 log), longest streak ever, total days logged, average items per day. Query: `SELECT DISTINCT logged_date FROM app_public.wear_logs ORDER BY logged_date DESC`. Walk the dates to compute streaks.
  - [x] 2.4: Return object: `{ dailyActivity: [{ date: string, itemsCount: number }], streakStats: { currentStreak: number, longestStreak: number, totalDaysLogged: number, avgItemsPerDay: number } }`.

- [x] Task 3: API - Add seasonal reports route with premium gating (AC: 1, 3, 8, 10)
  - [x] 3.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/seasonal-reports`. Requires authentication (401 if unauthenticated). Call `premiumGuard.requirePremium(authContext)` to enforce premium-only access (returns 403 with `PREMIUM_REQUIRED` for free users). Call `analyticsRepository.getSeasonalReports(authContext)`. Return 200 with the seasonal reports object.
  - [x] 3.2: Place route after existing analytics routes in main.js (after gap-analysis route).

- [x] Task 4: API - Add heatmap data route with premium gating (AC: 4, 5, 7, 10)
  - [x] 4.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/heatmap?start=YYYY-MM-DD&end=YYYY-MM-DD`. Requires authentication (401). Call `premiumGuard.requirePremium(authContext)`. Validate `start` and `end` query params (both required, must be valid ISO dates, `end` must be >= `start`, date range must not exceed 366 days). Call `analyticsRepository.getHeatmapData(authContext, { startDate: start, endDate: end })`. Return 200.
  - [x] 4.2: Return 400 for missing/invalid date params or range exceeding 366 days.

- [x] Task 5: API - Unit tests for seasonal reports repository method (AC: 1, 2, 3, 9, 11)
  - [x] 5.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getSeasonalReports`:
    - Returns 4 seasons (spring, summer, fall, winter) with item counts, most worn, neglected.
    - Readiness score is between 1 and 10.
    - Historical comparison returns percentChange when prior year data exists.
    - Historical comparison returns null percentChange when no prior year data.
    - Transition alert included when next season is within 14 days.
    - Transition alert null when next season is > 14 days away.
    - Returns empty arrays for most worn / neglected when season has no items.
    - Respects RLS (user isolation).
    - Most worn items sorted by wear_count DESC, limited to 5.
    - Neglected items include items with 0 wears or not worn in 90 days.
    - Items tagged with "all-season" appear in all seasons.

- [x] Task 6: API - Unit tests for heatmap repository method (AC: 4, 5, 7, 11)
  - [x] 6.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getHeatmapData`:
    - Returns daily activity array with correct item counts per date.
    - Returns empty array when no wear logs in date range.
    - Streak stats: current streak computed correctly.
    - Streak stats: longest streak computed correctly.
    - Streak stats: total days logged correct.
    - Streak stats: average items per day correct.
    - Respects RLS (user isolation).
    - Items count is distinct items per day (not duplicate).

- [x] Task 7: API - Integration tests for seasonal reports and heatmap endpoints (AC: 1, 4, 8, 10, 11)
  - [x] 7.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/seasonal-reports` returns 200 with seasons array for premium user.
    - `GET /v1/analytics/seasonal-reports` returns 401 if unauthenticated.
    - `GET /v1/analytics/seasonal-reports` returns 403 with `PREMIUM_REQUIRED` for free user.
    - Response includes `seasons`, `currentSeason`, `transitionAlert`, `totalItems` fields.
    - `GET /v1/analytics/heatmap?start=...&end=...` returns 200 for premium user.
    - `GET /v1/analytics/heatmap` returns 401 if unauthenticated.
    - `GET /v1/analytics/heatmap` returns 403 for free user.
    - `GET /v1/analytics/heatmap` returns 400 for missing date params.
    - `GET /v1/analytics/heatmap` returns 400 for range exceeding 366 days.

- [x] Task 8: Mobile - Add seasonal reports and heatmap API methods to ApiClient (AC: 1, 4)
  - [x] 8.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getSeasonalReports()` method. Calls `GET /v1/analytics/seasonal-reports` using `_authenticatedGet`. Returns response JSON map. Throws `ApiException` on error (including 403 for non-premium).
  - [x] 8.2: Add `Future<Map<String, dynamic>> getHeatmapData({required String startDate, required String endDate})` method. Calls `GET /v1/analytics/heatmap?start=$startDate&end=$endDate` using `_authenticatedGet`.

- [x] Task 9: Mobile - Create SeasonalReportsSection widget (AC: 1, 2, 3, 8, 9)
  - [x] 9.1: Create `apps/mobile/lib/src/features/analytics/widgets/seasonal_reports_section.dart` with `SeasonalReportsSection` StatefulWidget. Constructor accepts: `required bool isPremium`, `required List<Map<String, dynamic>> seasons`, `required String currentSeason`, `required Map<String, dynamic>? transitionAlert`, `required VoidCallback onViewHeatmap`, `SubscriptionService? subscriptionService`.
  - [x] 9.2: **Premium gate (free users):** If `!isPremium`, render `PremiumGateCard(title: "Seasonal Reports & Heatmap", subtitle: "Track your seasonal wearing patterns and daily activity", icon: Icons.calendar_month_outlined, subscriptionService: subscriptionService)`. Do NOT render reports or heatmap button.
  - [x] 9.3: **Section header:** "Seasonal Reports" (16px bold, #1F2937) with a seasonal icon.
  - [x] 9.4: **Transition alert card (if present):** At the top of the section, a highlighted card (#FEF3C7 background, amber border) showing: "[Season] is coming in [X] days! Your readiness: [Y]/10" with `Icons.notifications_active` icon. Tappable to expand that season's report.
  - [x] 9.5: **Season accordion:** Four `ExpansionTile` widgets (one per season), each with a season icon (spring=flower, summer=sun, fall=leaf, winter=snowflake using `Icons.local_florist`, `Icons.wb_sunny`, `Icons.eco`, `Icons.ac_unit`). Current/upcoming season expanded by default. Each expanded tile shows:
    - Readiness score as a horizontal progress bar (1-10 scale, color-coded: red 1-3, yellow 4-6, green 7-10) with score number.
    - Item count: "[N] items for [season]".
    - Historical comparison text (e.g., "+12% more items worn vs last winter" in green, or "-8% fewer items" in red, or "First winter tracked" in grey).
    - "Most Worn" sub-section: horizontal scrollable row of item thumbnails (48x48 circular, using `CachedNetworkImage`) with item name below. Max 5 items. Tap navigates to item detail.
    - "Neglected" sub-section: same layout as Most Worn, but with a muted overlay and `Icons.warning_amber` badge.
  - [x] 9.6: **View Heatmap button:** Below the accordion, an `OutlinedButton` with `Icons.grid_view` and text "View Heatmap". Calls `onViewHeatmap` callback. Only shown for premium users.
  - [x] 9.7: **Empty state:** When all seasons have 0 items, show "Start logging your outfits to see seasonal patterns!" with `Icons.calendar_month_outlined` icon (32px, #9CA3AF).
  - [x] 9.8: Add `Semantics` labels: "Seasonal reports, [season] readiness score [N] out of 10", "Transition alert, [season] in [N] days", "[season] most worn items", "[season] neglected items".

- [x] Task 10: Mobile - Create WearHeatmapScreen (AC: 4, 5, 6, 7)
  - [x] 10.1: Create `apps/mobile/lib/src/features/analytics/screens/wear_heatmap_screen.dart` with `WearHeatmapScreen` StatefulWidget. Constructor accepts: `required ApiClient apiClient`, `WearLogService? wearLogService` (for day detail overlay reuse).
  - [x] 10.2: State: `_viewMode` (enum: month, quarter, year), `_currentDate` (DateTime, for navigation), `_dailyActivity` (Map<String, int>, date -> items count), `_streakStats` (Map), `_isLoading`, `_error`.
  - [x] 10.3: **View mode toggle:** A `SegmentedButton` or `ToggleButtons` at the top with "Month", "Quarter", "Year" options. Changing view mode re-fetches data for the new date range.
  - [x] 10.4: **Month view:** Standard calendar grid (7 columns, same layout pattern as `WearCalendarScreen` from Story 5.3). Each day cell is colored by intensity: 0 items = #F3F4F6, 1-2 = #BBF7D0, 3-5 = #4ADE80, 6+ = #16A34A. Day number displayed in the cell center. Month/year header with left/right navigation arrows. Cannot navigate past current month.
  - [x] 10.5: **Quarter view:** Three months in a vertical stack, each as a compact calendar grid with smaller cells (28x28). Month names as sub-headers. Same color intensity coding. Navigation arrows move by quarter.
  - [x] 10.6: **Year view:** 12 months in a 4-column x 3-row grid layout. Each month is a tiny grid (cells ~12x12) with no day numbers, just colored cells. Month name abbreviations above each grid. This resembles a GitHub contribution graph. Navigation arrows move by year. Cannot navigate past current year.
  - [x] 10.7: **Day tap:** Tapping a colored day cell in Month or Quarter view opens `DayDetailBottomSheet` (from Story 5.3). Year view day cells are too small for tapping -- tapping a month in year view switches to Month view for that month.
  - [x] 10.8: **Streak statistics row:** Below the heatmap grid, a `Row` of 4 metric cards (same style as `MonthSummaryRow` from Story 5.3): "Current Streak" (with flame icon), "Longest Streak" (with trophy icon), "Total Days" (with calendar icon), "Avg Items/Day" (with bar chart icon). Each card: value (20px bold, #1F2937), label (12px, #6B7280).
  - [x] 10.9: **Color legend:** Below the streak stats, a horizontal row showing the 4 color levels with labels: "None", "1-2", "3-5", "6+". Small colored squares (12x12) with text labels.
  - [x] 10.10: **Data fetching:** On init and view mode / navigation changes, call `apiClient.getHeatmapData(startDate: rangeStart, endDate: rangeEnd)`. Parse `dailyActivity` into `_dailyActivity` map and `streakStats` into `_streakStats`.
  - [x] 10.11: **Loading/error/empty states:** Same patterns as `WearCalendarScreen`. Loading: `CircularProgressIndicator` overlay. Error: message with retry button. Empty: "No wear data yet. Log your outfits to build your heatmap!" with `Icons.grid_view` icon.
  - [x] 10.12: Add `Semantics` labels: "Wear heatmap, [view mode] view", "Day [date], [count] items worn", "Current streak [N] days", "Longest streak [N] days".

- [x] Task 11: Mobile - Integrate SeasonalReportsSection into AnalyticsDashboardScreen (AC: 1, 3, 8, 10)
  - [x] 11.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `List<Map<String, dynamic>>? _seasonalSeasons`, `String? _currentSeason`, `Map<String, dynamic>? _transitionAlert`.
  - [x] 11.2: Update `_loadAnalytics()`: After the existing 9 parallel fetches (6 free + 3 premium), add a conditional 10th fetch for seasonal reports ONLY if the user is premium. If premium, call `apiClient.getSeasonalReports()` and store results. If not premium, skip the call. Premium users now trigger 10 API calls; free users still trigger 6.
  - [x] 11.3: In the `CustomScrollView` slivers, after the existing `GapAnalysisSection` sliver, add a `SliverToBoxAdapter` wrapping `SeasonalReportsSection(isPremium: subscriptionService?.isPremiumCached ?? false, seasons: _seasonalSeasons ?? [], currentSeason: _currentSeason ?? _getCurrentSeason(), transitionAlert: _transitionAlert, onViewHeatmap: _navigateToHeatmap, subscriptionService: subscriptionService)`.
  - [x] 11.4: Add `_navigateToHeatmap()` method: navigates to `WearHeatmapScreen` via `Navigator.push(MaterialPageRoute(builder: (_) => WearHeatmapScreen(apiClient: apiClient, wearLogService: wearLogService)))`.
  - [x] 11.5: Add helper `_getCurrentSeason()` that returns the current meteorological season string based on current month (for fallback when API data hasn't loaded).

- [x] Task 12: Mobile - Widget tests for SeasonalReportsSection (AC: 1, 2, 3, 8, 9, 11)
  - [x] 12.1: Create `apps/mobile/test/features/analytics/widgets/seasonal_reports_section_test.dart`:
    - Renders PremiumGateCard when isPremium is false.
    - Does NOT render season accordion when isPremium is false.
    - Renders section header "Seasonal Reports" when isPremium is true.
    - Renders 4 season expansion tiles.
    - Current season is expanded by default.
    - Renders readiness score with progress bar for each season.
    - Renders historical comparison text.
    - Renders transition alert card when transitionAlert is not null.
    - Hides transition alert when transitionAlert is null.
    - Renders "View Heatmap" button for premium users.
    - Tapping "View Heatmap" calls onViewHeatmap callback.
    - Empty state shows correct prompt when all seasons have 0 items.
    - Most worn items render as horizontal scrollable thumbnails.
    - Neglected items render with warning badge.
    - Semantics labels present on all key elements.

- [x] Task 13: Mobile - Widget tests for WearHeatmapScreen (AC: 4, 5, 6, 7, 11)
  - [x] 13.1: Create `apps/mobile/test/features/analytics/screens/wear_heatmap_screen_test.dart`:
    - Renders month view by default.
    - Color intensity: 0 items grey, 1-2 light green, 3-5 medium green, 6+ dark green.
    - View mode toggle switches between month, quarter, year.
    - Month view shows calendar grid with navigation arrows.
    - Cannot navigate past current month.
    - Quarter view shows 3 months.
    - Year view shows 12 months in 4x3 grid.
    - Tapping a day in month view opens DayDetailBottomSheet.
    - Tapping a month in year view switches to month view for that month.
    - Streak statistics row shows 4 metrics.
    - Color legend displays correctly.
    - Loading state shows progress indicator.
    - Error state shows retry button.
    - Empty state shows correct message.
    - Semantics labels present.

- [x] Task 14: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 8, 10, 11)
  - [x] 14.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders SeasonalReportsSection below GapAnalysisSection for premium user.
    - Dashboard renders PremiumGateCard for seasonal reports for free user.
    - Dashboard error state still works (handles 10 API calls for premium, 6 for free).
    - Mock API returns seasonal reports data for premium user.
    - Mock API does NOT call seasonal reports endpoint for free user.
    - Tapping "View Heatmap" navigates to WearHeatmapScreen.
    - Premium user triggers 10 parallel API calls; free user triggers 6.

- [x] Task 15: Regression testing (AC: all)
  - [x] 15.1: Run `flutter analyze` -- zero new issues.
  - [x] 15.2: Run `flutter test` -- all existing 1554+ Flutter tests plus new tests pass.
  - [x] 15.3: Run `npm --prefix apps/api test` -- all existing 1115+ API tests plus new tests pass.
  - [x] 15.4: Verify existing AnalyticsDashboardScreen tests pass with the new section added (mock API updated).
  - [x] 15.5: Verify existing premium gating tests continue to pass.
  - [x] 15.6: Verify existing WearCalendarScreen and DayDetailBottomSheet still work (reused in heatmap).

## Dev Notes

- This is the **fourth and final story in Epic 11** (Advanced Analytics 2.0). It adds seasonal wardrobe reports and a calendar heatmap to the Analytics dashboard, building on the analytics infrastructure from Stories 5.4-5.7 and the advanced analytics sections from Stories 11.1-11.3.
- This story implements **FR-SEA-01** (seasonal reports for Spring/Summer/Fall/Winter), **FR-SEA-02** (item count, most worn, neglected, readiness score per season), **FR-SEA-03** (historical comparison), **FR-SEA-04** (seasonal transition alerts), **FR-HMP-01** (calendar heatmap with color intensity), **FR-HMP-02** (Month/Quarter/Year view modes), **FR-HMP-03** (day tap detail overlay), and **FR-HMP-04** (streak tracking and statistics).
- **Premium-gated feature.** Per architecture: "Gated features include... advanced analytics." Per Story 7.2 premium matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only." The `premiumGuard.requirePremium()` utility (created in Story 7.2) is used for server-side gating. Client-side uses `PremiumGateCard` (created in Story 7.2) for the free-user experience.
- **Extends the existing analytics repository.** Stories 5.4-5.6 established `analytics-repository.js` with 6 methods. Story 11.1 added the 7th, 11.2 the 8th, 11.3 added `getGapAnalysisData` as the 9th. This story adds `getSeasonalReports` as the 10th and `getHeatmapData` as the 11th method.
- **Extends the existing AnalyticsDashboardScreen.** The seasonal reports section is added as a sliver after `GapAnalysisSection`. The dashboard now conditionally fetches up to 10 endpoints (6 free + 4 premium) for premium users, or 6 for free users.
- **Creates a new screen: WearHeatmapScreen.** Unlike previous Epic 11 stories which were dashboard sections only, the heatmap is a dedicated screen (navigated to from the dashboard). This follows the pattern of `WearCalendarScreen` from Story 5.3.
- **Reuses existing components:** `DayDetailBottomSheet` from Story 5.3 for the day-tap overlay. Calendar grid layout pattern from `WearCalendarScreen`. `MonthSummaryRow` card styling for streak stats. `CachedNetworkImage` for item thumbnails.
- **No new database migration needed.** All required data already exists: `items.season` (TEXT[] array), `items.wear_count`, `items.last_worn_date`, `wear_logs` table, `wear_log_items` table. Season is stored as an array on items (e.g., `['spring', 'fall']` for transitional pieces), populated via AI categorization (Story 2.3) or manual editing (Story 2.4).
- **No new dependencies needed.** Uses existing packages: `flutter/material.dart`, `intl`, `cached_network_image`. No charting library needed.

### Design Decision: Two Separate API Endpoints

Seasonal reports and heatmap data are served by two separate endpoints (`/v1/analytics/seasonal-reports` and `/v1/analytics/heatmap`) because they serve different use cases with different query patterns. Seasonal reports are fetched once on dashboard load. Heatmap data is fetched with date range parameters that change as the user navigates the heatmap (month/quarter/year).

### Design Decision: Heatmap as a Separate Screen

The heatmap is a full-screen experience (not a dashboard section) because: (1) it requires view mode switching (month/quarter/year) with different layouts, (2) it needs navigation controls for panning through time, (3) the year view needs full screen width for the 12-month grid, (4) it follows the precedent of `WearCalendarScreen` from Story 5.3.

### Design Decision: Meteorological Seasons

Using meteorological seasons (Mar/Jun/Sep/Dec boundaries) rather than astronomical seasons because: (1) they align better with clothing/fashion seasons, (2) they use clean month boundaries making date range queries simpler, (3) they match the typical retail fashion calendar.

### Design Decision: Season Column is an Array

The `items.season` column is `TEXT[]` (array), not a single value. Items can be tagged with multiple seasons (e.g., a light jacket is both "spring" and "fall"). The SQL uses `@>` (array contains) operator: `WHERE season @> ARRAY['spring']::text[]`. Items tagged "all-season" should appear in all 4 seasonal reports. Handle this by checking `season @> ARRAY['all-season']::text[]` with an OR condition in the query.

### Design Decision: Heatmap Streak Computation Server-Side

Streak statistics are computed server-side rather than client-side because: (1) the streak may span beyond the visible date range, (2) the "longest streak ever" requires querying the full history, (3) server authority for analytics data per architecture. The client displays pre-computed stats.

### Design Decision: Conditional 10th API Call for Premium Users

Seasonal reports is the 4th premium-only analytics section. Premium users now trigger up to 10 API calls (6 standard + brand value + sustainability + gap analysis + seasonal reports). Free users still trigger only 6. The heatmap endpoint is NOT called from the dashboard -- it is called separately from the WearHeatmapScreen.

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getSeasonalReports` and `getHeatmapData` methods)
  - `apps/api/src/main.js` (add `GET /v1/analytics/seasonal-reports` and `GET /v1/analytics/heatmap` routes with premium guard)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/seasonal_reports_section.dart` (seasonal reports widget)
  - `apps/mobile/lib/src/features/analytics/screens/wear_heatmap_screen.dart` (heatmap screen)
  - `apps/mobile/test/features/analytics/widgets/seasonal_reports_section_test.dart`
  - `apps/mobile/test/features/analytics/screens/wear_heatmap_screen_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add seasonal reports state, conditional 10th fetch, new sliver, `_navigateToHeatmap`)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getSeasonalReports` and `getHeatmapData` methods)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add seasonal reports tests, update mock)
- Modified API test files:
  - `apps/api/test/modules/analytics/analytics-repository.test.js` (add tests for `getSeasonalReports` and `getHeatmapData`)
  - `apps/api/test/modules/analytics/analytics-endpoints.test.js` (add tests for new endpoints)
- No SQL migration files.
- Analytics feature module directory structure after this story:
  ```
  apps/mobile/lib/src/features/analytics/
  ├── models/
  │   └── wear_log.dart (Story 5.1)
  ├── screens/
  │   ├── analytics_dashboard_screen.dart (modified)
  │   ├── wear_calendar_screen.dart (Story 5.3)
  │   └── wear_heatmap_screen.dart (NEW)
  ├── services/
  │   └── wear_log_service.dart (Story 5.1)
  └── widgets/
      ├── ai_insights_section.dart (Story 5.7)
      ├── brand_value_section.dart (Story 11.1)
      ├── category_distribution_section.dart (Story 5.6)
      ├── cpw_item_row.dart (Story 5.4)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── gap_analysis_section.dart (Story 11.3)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── seasonal_reports_section.dart (NEW)
      ├── summary_cards_row.dart (Story 5.4)
      ├── sustainability_section.dart (Story 11.2)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (Story 5.6)
  ```

### Technical Requirements

- **Analytics repository extension:** Add `getSeasonalReports` and `getHeatmapData` methods to the existing `createAnalyticsRepository` return object. Same pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> queries -> `client.release()` in try/finally.
- **Season date boundaries (meteorological):** Spring: Mar 1 - May 31, Summer: Jun 1 - Aug 31, Fall: Sep 1 - Nov 30, Winter: Dec 1 - Feb 28/29. Define as constants in the repository method.
- **Season column is TEXT[]:** The `items.season` column is a PostgreSQL text array. Use `@>` operator for containment: `WHERE season @> ARRAY['spring']::text[]`. Also include items tagged with `'all-season'`: `WHERE (season @> ARRAY['spring']::text[] OR season @> ARRAY['all-season']::text[])`.
- **Heatmap color intensity levels:** 0 items = #F3F4F6 (grey), 1-2 = #BBF7D0 (light green), 3-5 = #4ADE80 (medium green), 6+ = #16A34A (dark green). Define as constants.
- **Readiness score formula:** `Math.min(10, Math.max(1, Math.round((seasonItemCount / max(totalItems,1)) * 20 + (seasonWornItems / max(seasonItemCount,1)) * 5)))`. This rewards both having items for the season (stock coverage) and wearing them (utilization).
- **Historical comparison:** Query `wear_log_items` joined with `wear_logs` for the current season date range and the same range in the prior year. Compare distinct item counts. Format as "+X%" or "-X%" text.
- **Transition alert timing:** Season boundaries at Mar 1, Jun 1, Sep 1, Dec 1. Calculate days until next boundary. If <= 14, include alert.
- **Premium gating:** Use `premiumGuard.requirePremium(authContext)` from `apps/api/src/modules/billing/premium-guard.js` (Story 7.2). Client-side uses `PremiumGateCard` from `apps/mobile/lib/src/core/widgets/premium_gate_card.dart` (Story 7.2).
- **DayDetailBottomSheet reuse:** Import from `apps/mobile/lib/src/features/analytics/widgets/day_detail_bottom_sheet.dart`. Pass the date and wear logs from the heatmap's data to show the same detail view as the wear calendar.
- **Heatmap date range calculation:** Month view: first and last day of current month. Quarter view: first day of quarter's first month through last day of quarter's last month. Year view: Jan 1 through Dec 31 of the year.
- **Streak computation:** Walk sorted dates backwards from today. Current streak = consecutive days ending today (or most recent logged day) with logs. Longest streak = max consecutive run in entire history. This requires fetching ALL distinct logged dates, not just the current view's range.
- **View mode enum:** Create `enum HeatmapViewMode { month, quarter, year }` in the heatmap screen file.

### Architecture Compliance

- **Server authority for analytics data:** Seasonal readiness scores, historical comparisons, streak stats, and heatmap data are all computed server-side. The client displays pre-computed results.
- **RLS enforces data isolation:** Both endpoints are RLS-scoped via `set_config`. A user can only see their own seasonal/heatmap data.
- **Premium gating enforced server-side:** `premiumGuard.requirePremium()` checks `profiles.is_premium`. Client-side gate is for UX only.
- **Mobile boundary owns presentation:** The API returns raw data (item lists, date counts, scores). The client handles heatmap rendering, color intensity, season accordion layout, and view mode switching.
- **No new AI calls:** This story is purely data aggregation + UI display. No Gemini involvement.
- **API module placement:** New methods go in existing `apps/api/src/modules/analytics/analytics-repository.js`. New routes go in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/seasonal-reports` and `GET /v1/analytics/heatmap?start=&end=` follow the existing analytics endpoint naming convention.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `flutter/material.dart` -- `ExpansionTile`, `SegmentedButton`/`ToggleButtons`, `GridView`, `Container`, `Row`, `Column`
  - `intl: ^0.19.0` -- date formatting for month/year headers, season date boundaries
  - `cached_network_image` -- for item thumbnails in seasonal reports
  - `dart:math` -- `min`, `max` for score clamping
- The heatmap does NOT require a third-party charting package. Use colored `Container` widgets in a `GridView` (same approach as the custom calendar grid in Story 5.3).
- API side: no new npm dependencies. Uses existing `pool` from `pg` and `premiumGuard` from billing module.

### File Structure Requirements

- New mobile widget goes in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing analytics widgets.
- New heatmap screen goes in `apps/mobile/lib/src/features/analytics/screens/` alongside existing analytics screens.
- Test files mirror source structure under `apps/mobile/test/features/analytics/`.
- API tests extend existing test files in `apps/api/test/modules/analytics/`.

### Testing Requirements

- **API repository tests** must verify:
  - Seasonal reports return 4 seasons with correct data
  - Readiness score clamped 1-10
  - Historical comparison correct when prior year data exists
  - Historical comparison null when no prior year data
  - Transition alert included/excluded based on 14-day threshold
  - All-season items included in all seasons
  - Most worn sorted by wear_count DESC, limited to 5
  - Neglected items criteria (0 wears or not worn 90 days)
  - Heatmap daily activity correct item counts
  - Heatmap streak stats computed correctly
  - RLS enforcement (user isolation)
  - Edge cases: empty wardrobe, no wear logs, single item
- **API endpoint tests** must verify:
  - 200 with correct JSON structure for premium user
  - 401 for unauthenticated
  - 403 with PREMIUM_REQUIRED for free user
  - Heatmap 400 for missing/invalid dates, excessive range
  - Response includes all expected fields
- **Mobile widget tests** must verify:
  - PremiumGateCard for free users
  - Season accordion with 4 seasons, current expanded
  - Readiness score display and color coding
  - Historical comparison text
  - Transition alert card presence/absence
  - View Heatmap button and callback
  - Empty state
  - Semantics labels
- **Heatmap screen tests** must verify:
  - Default month view renders
  - Color intensity mapping correct
  - View mode toggle works
  - Quarter and year views render
  - Day tap opens bottom sheet
  - Year view month tap switches to month view
  - Streak statistics display
  - Color legend display
  - Loading/error/empty states
  - Navigation arrows (month, quarter, year)
  - Cannot navigate past current date
  - Semantics labels
- **Dashboard integration tests** must verify:
  - SeasonalReportsSection appears below GapAnalysisSection for premium
  - PremiumGateCard for free user
  - 10 API calls for premium, 6 for free
  - Heatmap navigation
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1554+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1115+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 11.3** (done) established: `GapAnalysisSection` added below `SustainabilitySection`. Dashboard conditionally fetches 9 endpoints for premium (6 free + 3 premium: brand value, sustainability, gap analysis). `getGapAnalysisData` is the 9th repository method. `gap-analysis-service.js` with Gemini enrichment. Client-side caching via shared_preferences. Test baselines: 1115 API tests (unchanged in 11.3 mobile-only phase), 1554 Flutter tests.
- **Story 11.2** (done) established: `SustainabilitySection` with score ring, CO2 savings, percentile, eco warrior badge trigger. 8th conditional premium API call. `getSustainabilityAnalytics` is the 8th repository method.
- **Story 11.1** (done) established: `BrandValueSection` with category filter chips and ranked brand list. 7th conditional premium API call. `getBrandValueAnalytics` is the 7th repository method.
- **Story 5.3** (done) established: `WearCalendarScreen` with custom month-view calendar grid (GridView, 7 columns), `DayDetailBottomSheet` for day-tap detail, `MonthSummaryRow` for summary metrics. Calendar grid layout is REUSED in the heatmap month view. `DayDetailBottomSheet` is REUSED for heatmap day-tap overlay.
- **Story 5.1** (done) established: `WearLog` model, `WearLogService` with `getLogsForDateRange`. `wear_logs` and `wear_log_items` tables. `GET /v1/wear-logs` endpoint. These are the data sources for the heatmap.
- **Story 7.2** (done) established: `PremiumGateCard`, `premiumGuard`, `isPremiumCached`. Premium gating matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only."
- **Story 2.3** (done) established: `taxonomy.js` with `VALID_SEASONS` = `['spring', 'summer', 'fall', 'winter', 'all-season']`. Items tagged with seasons via AI categorization. `items.season` is `TEXT[]` (array column).
- **Story 6.3** (done) established: Server-side streak tracking with `user_stats.current_streak`, `user_stats.longest_streak`, freeze logic. However, the heatmap computes its own streak from wear logs (different source: the heatmap measures consecutive logging days, while 6.3 tracks game streaks with freezes). Do NOT reuse the gamification streak for heatmap -- compute independently from `wear_logs`.
- **Dashboard sliver order (after Story 11.3):** AiInsightsSection, SummaryCardsRow, CPW list, TopWornSection, NeglectedItemsSection, CategoryDistributionSection, WearFrequencySection, BrandValueSection, SustainabilitySection, GapAnalysisSection. This story adds SeasonalReportsSection after GapAnalysisSection.
- **`createRuntime()` currently returns (after Story 11.3):** All existing services plus `gapAnalysisService`. No new service needed for this story -- the repository methods are sufficient (no AI/Gemini involved).
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Section headers: 16px bold, #1F2937.
  - Empty state icons: 32px, #9CA3AF with descriptive text.
  - `PremiumGateCard` for free-user premium feature gates.
  - Conditional API fetching: premium-only calls skip for free users.
  - Custom calendar grid with `GridView` (7 columns, no third-party package).
  - Bottom sheet for day detail via `showModalBottomSheet`.
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season` (TEXT[]), `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `resale_status`, `created_at`, `updated_at`.
- **Current test baselines (from Story 11.3):** 1115+ API tests, 1554+ Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT compute seasonal reports or heatmap data client-side. Use the dedicated server-side endpoints.
- DO NOT skip premium gating. This is an "advanced analytics" feature that MUST be premium-only per architecture and Story 7.2 premium matrix.
- DO NOT call the seasonal reports or heatmap API for free users. Check `isPremiumCached` before making the call. Free users see `PremiumGateCard` only.
- DO NOT add charting libraries for the heatmap. Use colored `Container` widgets in a `GridView`. Do NOT use `fl_chart` -- it's a grid of colored cells, not a chart.
- DO NOT add `table_calendar` or any third-party calendar package. Build the heatmap grid with Flutter's built-in widgets (same approach as Story 5.3 WearCalendarScreen).
- DO NOT create a new DayDetailBottomSheet -- REUSE the existing one from Story 5.3.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify existing API endpoints or repository methods. Only add new methods.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT fetch the entire wear log history on dashboard load. Seasonal reports are fetched as a single summary call. Heatmap data is fetched separately with date range params only when the heatmap screen is opened.
- DO NOT reuse the gamification streak from Story 6.3 (`user_stats.current_streak`). The heatmap streak measures consecutive wear-logging days, computed from `wear_logs` table. The gamification streak has freeze logic and different semantics.
- DO NOT hardcode season date boundaries in multiple places. Define as named constants in the repository method.
- DO NOT create a separate analytics service for seasonal data. The analytics repository method is sufficient for this data aggregation story (no AI involved).
- DO NOT call the heatmap endpoint from the dashboard. The heatmap endpoint is only called from the `WearHeatmapScreen` when the user navigates to it.
- DO NOT allow heatmap date range queries exceeding 366 days. Validate server-side.
- DO NOT include non-existent notification scheduling for seasonal transition alerts. FR-SEA-04 says "alerts shall notify users 2 weeks before a new season" -- for this story, the alert is displayed as a card in the Seasonal Reports section when the user views the dashboard. Push notification for seasonal transitions is out of scope for V1 (would require a server-side cron job and notification scheduling infrastructure beyond what's currently built).

### Out of Scope

- **Push notification scheduling for seasonal transition alerts:** FR-SEA-04 is implemented as an in-app alert card displayed when the user views the dashboard, not as a scheduled push notification. A server-side cron job for push notifications is out of scope for V1.
- **AI-powered seasonal recommendations:** No Gemini usage in this story. Recommendations are data-driven (most worn, neglected, readiness score).
- **Seasonal trend graphs over multiple years:** Not required by any FR. Only current vs prior year comparison.
- **Wardrobe health score (FR-HLT-*):** Epic 13, Story 13.1.
- **Offline heatmap viewing:** Out of scope for V1.
- **Export/share seasonal reports or heatmap:** Not required by any FR.
- **Tab restructuring of analytics dashboard:** The vertical scroll pattern continues.
- **Animated heatmap transitions between view modes:** Nice-to-have if time permits, not required.
- **Week view for heatmap:** Only Month, Quarter, Year per FR-HMP-02.
- **Heatmap sharing (screenshot/image export):** Not required by any FR.

### References

- [Source: epics.md - Story 11.4: Seasonal Reports & Heatmaps]
- [Source: epics.md - FR-SEA-01: The system shall generate seasonal wardrobe reports (Spring, Summer, Fall, Winter)]
- [Source: epics.md - FR-SEA-02: Each report shall show: item count per season, most worn items, neglected items, and seasonal readiness score (1-10)]
- [Source: epics.md - FR-SEA-03: Reports shall include historical comparison (e.g., "This winter you wore 12% more items than last")]
- [Source: epics.md - FR-SEA-04: Seasonal transition alerts shall notify users 2 weeks before a new season]
- [Source: epics.md - FR-HMP-01: The system shall display a calendar heatmap showing daily wear activity with color intensity proportional to items worn]
- [Source: epics.md - FR-HMP-02: The heatmap shall support view modes: Month, Quarter, Year]
- [Source: epics.md - FR-HMP-03: Users shall tap a day to see a detail overlay with outfits worn that day]
- [Source: epics.md - FR-HMP-04: The heatmap shall display streak tracking and streak statistics]
- [Source: architecture.md - Gated features include... advanced analytics]
- [Source: architecture.md - Epic 11 Advanced Analytics -> mobile/features/analytics, api/modules/analytics, api/modules/ai]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: 11-3-wardrobe-gap-analysis.md - GapAnalysisSection, conditional 9th premium API call, gap-analysis-service.js, 1554 Flutter tests]
- [Source: 11-2-sustainability-scoring-co2-savings.md - SustainabilitySection, conditional 8th premium API call, 1115 API tests]
- [Source: 11-1-brand-value-analytics.md - BrandValueSection, conditional premium-only fetch pattern]
- [Source: 7-2-premium-feature-access-enforcement.md - premiumGuard utility, PremiumGateCard widget, premium gating matrix: "Advanced analytics: Premium-only"]
- [Source: 5-3-monthly-wear-calendar-view.md - WearCalendarScreen custom calendar grid, DayDetailBottomSheet, MonthSummaryRow]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - WearLog model, WearLogService, wear_logs/wear_log_items tables]
- [Source: 2-3-ai-item-categorization-tagging.md - taxonomy.js VALID_SEASONS: spring, summer, fall, winter, all-season]
- [Source: 6-3-streak-tracking-freezes.md - server-side streak in user_stats (different from heatmap streak)]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing 9 analytics methods (after Story 11.3)]
- [Source: apps/api/src/modules/billing/premium-guard.js - requirePremium(), checkPremium()]
- [Source: apps/mobile/lib/src/core/widgets/premium_gate_card.dart - PremiumGateCard widget]
- [Source: apps/mobile/lib/src/features/analytics/widgets/day_detail_bottom_sheet.dart - DayDetailBottomSheet (reused)]
- [Source: apps/mobile/lib/src/features/analytics/screens/wear_calendar_screen.dart - calendar grid pattern (reused)]
- [Source: apps/mobile/lib/src/features/analytics/widgets/month_summary_row.dart - summary card pattern (reused)]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented `getSeasonalReports` (10th) and `getHeatmapData` (11th) methods in analytics-repository.js with full RLS, meteorological season boundaries, readiness scores, historical comparison, transition alerts, streak computation, and daily activity aggregation.
- Added `GET /v1/analytics/seasonal-reports` and `GET /v1/analytics/heatmap` routes in main.js with premium gating (401/403) and heatmap date validation (400 for missing/invalid/excessive range).
- Added `getSeasonalReports()` and `getHeatmapData()` to Flutter ApiClient.
- Created `SeasonalReportsSection` widget with premium gate, season accordion (4 seasons with ExpansionTile), readiness score progress bars, historical comparison text, transition alert card, most worn/neglected item thumbnails, View Heatmap button, empty state, and full Semantics.
- Created `WearHeatmapScreen` with Month/Quarter/Year view modes via SegmentedButton, color-intensity calendar grids (grey/light green/medium green/dark green), navigation arrows with current-date limit, day-tap to DayDetailBottomSheet, streak statistics row (4 metric cards), color legend, and loading/error/empty states.
- Integrated SeasonalReportsSection into AnalyticsDashboardScreen as the final sliver (after GapAnalysisSection). Premium users now trigger 10 parallel API calls; free users still trigger 6.
- Added 31 new API tests (11 seasonal reports repository + 8 heatmap repository + 9 endpoint + 3 factory) all passing.
- Added 15 SeasonalReportsSection widget tests, 14 WearHeatmapScreen tests, and 6 dashboard integration tests all passing.
- Updated existing dashboard tests to handle the new 10th API call for premium users.
- All 1175 API tests pass (up from 1144 baseline). All 1585 Flutter tests pass (up from 1554 baseline). Zero new analysis issues.

### Change Log

- 2026-03-19: Story 11.4 implementation complete. Added seasonal reports and wear heatmap features (final story in Epic 11).

### File List

**Modified API files:**
- `apps/api/src/modules/analytics/analytics-repository.js` -- added `getSeasonalReports` and `getHeatmapData` methods
- `apps/api/src/main.js` -- added `GET /v1/analytics/seasonal-reports` and `GET /v1/analytics/heatmap` routes

**Modified API test files:**
- `apps/api/test/modules/analytics/analytics-repository.test.js` -- added 19 tests for seasonal reports and heatmap repository methods
- `apps/api/test/modules/analytics/analytics-endpoints.test.js` -- added 9 endpoint tests for both new routes

**New mobile files:**
- `apps/mobile/lib/src/features/analytics/widgets/seasonal_reports_section.dart` -- SeasonalReportsSection widget
- `apps/mobile/lib/src/features/analytics/screens/wear_heatmap_screen.dart` -- WearHeatmapScreen with Month/Quarter/Year views
- `apps/mobile/test/features/analytics/widgets/seasonal_reports_section_test.dart` -- 15 widget tests
- `apps/mobile/test/features/analytics/screens/wear_heatmap_screen_test.dart` -- 14 screen tests

**Modified mobile files:**
- `apps/mobile/lib/src/core/networking/api_client.dart` -- added `getSeasonalReports` and `getHeatmapData` methods
- `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` -- added seasonal reports state, 10th premium fetch, SeasonalReportsSection sliver, heatmap navigation
- `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` -- added 6 integration tests, updated existing mocks for 10 API calls
