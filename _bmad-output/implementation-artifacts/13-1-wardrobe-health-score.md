# Story 13.1: Wardrobe Health Score

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want a unified "Health Score" for my wardrobe to understand how efficiently I'm using what I own,
so that I am motivated to declutter or wear more of my clothes.

## Acceptance Criteria

1. Given the system has calculated my wear logs and wardrobe size, when I view the Wardrobe tab or Analytics tab, then I see my Wardrobe Health Score (0-100). The score is calculated from 3 weighted factors: % of items worn in the last 90 days (50%), % of items with CPW below 5 (30%), and size-vs-utilization ratio (20%). The score is displayed prominently with a circular progress indicator. (FR-HLT-01)

2. Given my Wardrobe Health Score is displayed, when I view the score, then it is color-coded: Green (#22C55E) for 80-100, Yellow (#F59E0B) for 50-79, Red (#EF4444) for below 50. The color applies to the circular progress ring and the score number. (FR-HLT-02)

3. Given my Wardrobe Health Score is calculated, when the section renders, then I see a specific actionable recommendation to improve my score (e.g., "Declutter 8 items to reach Green status", "Wear 5 more items this month to boost your score"). The recommendation is generated server-side based on which factor has the most room for improvement. (FR-HLT-03)

4. Given my Wardrobe Health Score is calculated, when the section renders, then I see a percentile comparison: "Top X% of Vestiaire users". The percentile is computed using the same deterministic formula established in Story 11.2: `percentile = max(1, 100 - score)`. A score of 80 shows "Top 20%". (FR-HLT-04)

5. Given I have no items in my wardrobe at all, when the health score section loads, then it shows an empty state: "Add items to your wardrobe to see your health score!" with an `Icons.health_and_safety_outlined` icon (32px, #9CA3AF). The score displays as 0. (FR-HLT-01)

6. Given I have items but no wear logs, when the health score section loads, then the score reflects the reality: utilization factor is 0 (no items worn in 90 days), CPW factor depends on purchase prices and wear counts, and size-vs-utilization is poor. The recommendation says something like "Start logging your outfits to improve your score!" (FR-HLT-01)

7. Given the API call to fetch health score data fails, when the screen loads, then the existing error-retry pattern handles the failure gracefully -- the section shows an inline error or the full dashboard shows an error state with a "Retry" button. (FR-HLT-01)

8. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1276+ API tests, 1705+ Flutter tests) and new tests cover: health score repository method, factor computations, recommendation generation, API endpoint (auth, empty wardrobe, edge cases), mobile HealthScoreSection widget (score display, color coding, recommendation, percentile, empty state), Wardrobe tab integration, Analytics dashboard integration, and edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Add wardrobe health score method to analytics repository (AC: 1, 3, 4, 5, 6)
  - [x] 1.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getWardrobeHealthScore(authContext)` method following the identical connection/RLS pattern as existing methods: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
  - [x] 1.2: Execute a single SQL query to gather raw health metrics: `SELECT COUNT(*) AS total_items, COUNT(*) FILTER (WHERE last_worn_date >= CURRENT_DATE - INTERVAL '90 days') AS items_worn_90d, COUNT(*) FILTER (WHERE purchase_price IS NOT NULL AND wear_count > 0 AND (purchase_price / wear_count) < 5) AS items_good_cpw, COUNT(*) FILTER (WHERE purchase_price IS NOT NULL AND wear_count > 0) AS items_with_cpw, COALESCE(SUM(wear_count), 0) AS total_wears FROM app_public.items`.
  - [x] 1.3: Compute the 3 factor scores in JS (each 0-100):
    - **utilizationScore** (weight 50%): `totalItems > 0 ? (itemsWorn90d / totalItems) * 100 : 0` -- % of wardrobe worn in last 90 days.
    - **cpwScore** (weight 30%): `itemsWithCpw > 0 ? (itemsGoodCpw / itemsWithCpw) * 100 : 0` -- % of priced+worn items with CPW below 5.
    - **sizeUtilizationScore** (weight 20%): Measures whether wardrobe size is reasonable relative to usage. Formula: `totalItems > 0 ? Math.min(100, (totalWears / totalItems) * 10) : 0` -- if average wears per item is 10+, perfect score. This penalizes large wardrobes with low total usage.
  - [x] 1.4: Compute composite score: `Math.round(utilizationScore * 0.50 + cpwScore * 0.30 + sizeUtilizationScore * 0.20)`. Clamp to 0-100.
  - [x] 1.5: Compute percentile: `Math.max(1, 100 - compositeScore)` (same deterministic formula as Story 11.2).
  - [x] 1.6: Generate recommendation string based on lowest-scoring factor:
    - If utilizationScore is lowest: calculate how many more items need to be worn to reach next tier. E.g., if score < 80 and utilization is the bottleneck, compute items needed: `Math.ceil(totalItems * 0.8 - itemsWorn90d)` items to wear -> "Wear {n} more items this month to reach Green status".
    - If cpwScore is lowest: "Focus on wearing your pricier items to lower their cost-per-wear".
    - If sizeUtilizationScore is lowest: calculate items to declutter: `Math.max(0, totalItems - Math.ceil(totalWears / 8))` -> "Declutter {n} items to improve your wardrobe efficiency".
    - If score >= 80: "Great job! Keep wearing your wardrobe evenly to maintain your Green status."
    - If totalItems === 0: "Add items to your wardrobe to start tracking your health score!"
    - If totalWears === 0: "Start logging your outfits to see your wardrobe health improve!"
  - [x] 1.7: Return object: `{ score: number, factors: { utilizationScore, cpwScore, sizeUtilizationScore }, percentile: number, recommendation: string, totalItems: number, itemsWorn90d: number, colorTier: "green"|"yellow"|"red" }`. Set `colorTier` based on score: "green" for 80-100, "yellow" for 50-79, "red" for 0-49.

- [x] Task 2: API - Add wardrobe health score route (AC: 1, 7)
  - [x] 2.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/wardrobe-health`. Requires authentication (401 if unauthenticated). This is a FREE-TIER endpoint -- no premium gating. Call `analyticsRepository.getWardrobeHealthScore(authContext)`.
  - [x] 2.2: Return 200 with the full health score result object.
  - [x] 2.3: Place route after existing analytics routes in main.js (after the seasonal-reports routes from Story 11.4).

- [x] Task 3: API - Unit tests for wardrobe health score repository method (AC: 1, 3, 4, 5, 6, 8)
  - [x] 3.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getWardrobeHealthScore`:
    - Returns composite score between 0 and 100.
    - utilizationScore: 0 when no items worn in 90 days, 100 when all items worn.
    - cpwScore: 0 when no items have CPW below 5, 100 when all priced+worn items have CPW below 5.
    - cpwScore: 0 when no items have purchase_price or wear_count (division edge case).
    - sizeUtilizationScore: 0 when no wears, 100 when avg wears per item >= 10.
    - Composite score uses correct weights (0.50, 0.30, 0.20).
    - Score clamped to 0-100.
    - Percentile computed as max(1, 100 - score).
    - colorTier: "green" for score 80-100, "yellow" for 50-79, "red" for 0-49.
    - Recommendation string is non-empty for all score tiers.
    - Returns zero score with empty recommendation prompt for user with no items.
    - Respects RLS (user A cannot see user B's health data).
    - Handles items without purchase_price (cpwScore ignores them).
    - Handles items without wear logs (utilizationScore considers last_worn_date).
    - Edge case: single item wardrobe.
    - Edge case: all items worn recently with good CPW (score near 100).

- [x] Task 4: API - Integration tests for wardrobe health score endpoint (AC: 1, 7, 8)
  - [x]4.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/wardrobe-health` returns 200 with health score object for authenticated user.
    - `GET /v1/analytics/wardrobe-health` returns 401 if unauthenticated.
    - Response includes `score`, `factors`, `percentile`, `recommendation`, `totalItems`, `itemsWorn90d`, `colorTier` fields.
    - Returns zero score for user with no items.
    - No premium gating -- free users can access this endpoint.

- [x] Task 5: Mobile - Add wardrobe health score API method to ApiClient (AC: 1)
  - [x]5.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getWardrobeHealthScore()` method. Calls `GET /v1/analytics/wardrobe-health` using `_authenticatedGet`. Returns response JSON map. Throws `ApiException` on error.

- [x] Task 6: Mobile - Create HealthScoreSection widget (AC: 1, 2, 3, 4, 5, 6)
  - [x]6.1: Create `apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart` with `HealthScoreSection` StatelessWidget. Constructor accepts: `required int score`, `required String colorTier`, `required Map<String, dynamic> factors`, `required int percentile`, `required String recommendation`, `required int totalItems`, `required int itemsWorn90d`.
  - [x]6.2: **Section header:** "Wardrobe Health" (16px bold, #1F2937) with a `Icons.health_and_safety` icon (16px, color matching the tier).
  - [x]6.3: **Score display:** A circular progress ring (120x120) using `CustomPaint` with `Canvas.drawArc`, following the same pattern as `SustainabilitySection` from Story 11.2. Ring fill represents score/100. Ring color: red (#EF4444) for 0-49, yellow (#F59E0B) for 50-79, green (#22C55E) for 80-100. Score number displayed centered inside the ring (32px bold, color matching the ring). Below the ring: "out of 100" label (12px, #6B7280).
  - [x]6.4: **Percentile badge:** Below the score ring, display "Top {percentile}% of Vestiaire users" in a compact chip (12px bold, #4F46E5 background, white text, 16px border radius). Same styling as the SustainabilitySection percentile chip.
  - [x]6.5: **Factor breakdown:** Below the percentile, show 3 rows, each with: factor name (14px, #1F2937), weight in parentheses (12px, #6B7280), and individual score as a small horizontal progress bar (height 8, width 100, same color coding as the main score ring). Factor display names: "Items Worn in 90 Days (50%)", "Cost-Per-Wear Efficiency (30%)", "Wardrobe Size Efficiency (20%)".
  - [x]6.6: **Recommendation card:** Below the factor breakdown, a card (same styling as CO2 savings card in 11.2 -- light background, 12px radius, 16px padding) showing: `Icons.lightbulb_outline` icon (24px, tier color), "Recommendation" label (14px bold, #1F2937), recommendation text (14px, #374151). Background color: light green (#F0FDF4) for green tier, light yellow (#FFFBEB) for yellow tier, light red (#FEF2F2) for red tier.
  - [x]6.7: **Empty state:** When `totalItems == 0`, show "Add items to your wardrobe to see your health score!" with `Icons.health_and_safety_outlined` icon (32px, #9CA3AF). Still show the score ring at 0.
  - [x]6.8: Add `Semantics` labels: "Wardrobe health score, [score] out of 100", "Top [percentile] percent of users", "Factor [name], score [value] out of 100", "Recommendation: [text]".

- [x] Task 7: Mobile - Integrate HealthScoreSection into AnalyticsDashboardScreen (AC: 1, 7)
  - [x]7.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `int? _healthScore`, `String? _healthColorTier`, `Map<String, dynamic>? _healthFactors`, `int? _healthPercentile`, `String? _healthRecommendation`, `int? _healthTotalItems`, `int? _healthItemsWorn90d`.
  - [x]7.2: Update `_loadAnalytics()`: Add the wardrobe health API call to the existing parallel fetch. This is a FREE-TIER call, so it runs for ALL users (both free and premium). Call `apiClient.getWardrobeHealthScore()` and parse results into state fields. Free users now trigger 7 API calls (6 existing free + 1 health score). Premium users now trigger 10 API calls (6 free + 1 health + 3 premium: brand value, sustainability, gap analysis).
  - [x]7.3: In the `CustomScrollView` slivers, add a `SliverToBoxAdapter` wrapping `HealthScoreSection(...)` as the FIRST section at the top of the analytics dashboard, before the existing `SummaryCardsRow`. The health score is the hero metric that sets context for everything below.
  - [x]7.4: Handle API failure: if the health score call fails, set health fields to null/defaults so the section shows a graceful fallback, while the rest of the dashboard still loads.

- [x] Task 8: Mobile - Integrate HealthScoreSection into WardrobeScreen (AC: 1)
  - [x]8.1: In `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`, add a compact health score summary widget at the top of the wardrobe grid (above the filter bar). This is a mini version: a single row showing the health score number (colored), the tier label ("Green"/"Yellow"/"Red"), and the recommendation text truncated to one line. Tap navigates to the Analytics Dashboard.
  - [x]8.2: Add state fields and a fetch call for the health score in `_loadItems()` or `initState`. Call `apiClient.getWardrobeHealthScore()` and store the result. Handle failure silently (hide the mini health bar if fetch fails).
  - [x]8.3: The mini health bar is a `Container` with 12px border-radius, tier-colored left border (4px), white background, padding 12px. Shows: score number (20px bold, tier color), tier label (12px, tier color), truncated recommendation (12px, #6B7280, maxLines: 1, overflow: ellipsis). Wrapped in `GestureDetector` navigating to AnalyticsDashboardScreen on tap.
  - [x]8.4: Add `Semantics` label: "Wardrobe health score [score], tap to view details".

- [x] Task 9: Mobile - Widget tests for HealthScoreSection (AC: 1, 2, 3, 4, 5, 6, 8)
  - [x]9.1: Create `apps/mobile/test/features/analytics/widgets/health_score_section_test.dart`:
    - Renders section header "Wardrobe Health" with health icon.
    - Renders circular score ring with correct score value.
    - Score ring color: red for 0-49, yellow for 50-79, green for 80-100.
    - Renders percentile badge with correct text "Top X% of Vestiaire users".
    - Renders 3 factor rows with correct names, weights, and progress bars.
    - Renders recommendation card with correct text and tier-colored background.
    - Empty state shows prompt when totalItems is 0.
    - Semantics labels present on all key elements.

- [x] Task 10: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 7, 8)
  - [x]10.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders HealthScoreSection as the first section.
    - Dashboard fetches wardrobe health for ALL users (no premium gating).
    - Mock API returns health score data.
    - Free user triggers 7 parallel API calls (6 free + 1 health).
    - Premium user triggers 10 parallel API calls (6 free + 1 health + 3 premium).
    - Dashboard error state still works with health score added.

- [x] Task 11: Mobile - Widget tests for mini health bar on WardrobeScreen (AC: 1, 8)
  - [x]11.1: In `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`, add tests:
    - Mini health bar renders with correct score and color.
    - Mini health bar shows recommendation text.
    - Tapping mini health bar navigates to AnalyticsDashboardScreen.
    - Mini health bar hidden when API call fails.
    - Existing wardrobe grid tests continue to pass.

- [x] Task 12: Regression testing (AC: all)
  - [x]12.1: Run `flutter analyze` -- zero new issues.
  - [x]12.2: Run `flutter test` -- all existing 1705+ Flutter tests plus new tests pass.
  - [x]12.3: Run `npm --prefix apps/api test` -- all existing 1276+ API tests plus new tests pass.
  - [x]12.4: Verify existing AnalyticsDashboardScreen tests pass with the new section added (mock API updated).
  - [x]12.5: Verify existing WardrobeScreen tests pass with the new mini health bar.
  - [x]12.6: Verify existing sustainability and brand value sections still render correctly.

## Dev Notes

- This is the **first story in Epic 13** (Circular Resale Triggers). It establishes the Wardrobe Health Score as the foundational metric that drives the subsequent stories: 13.2 (Monthly Resale Prompts) and 13.3 (Spring Clean Declutter Flow). The health score provides the motivational context for users to declutter.
- This story implements **FR-HLT-01** (health score 0-100 based on 3 weighted factors), **FR-HLT-02** (green/yellow/red color coding), **FR-HLT-03** (actionable recommendations), and **FR-HLT-04** (deterministic percentile).
- **FREE-TIER feature.** Unlike the sustainability score (Story 11.2, premium-only), the wardrobe health score is accessible to ALL users. The health score is a motivational tool that drives engagement (and eventual resale/donation actions in Stories 13.2 and 13.3). Premium gating would reduce the feature's effectiveness as a behavior-change driver.
- **Distinct from Sustainability Score (Story 11.2).** The sustainability score uses 5 factors (avg wear, utilization, CPW, resale activity, new purchases) and is premium-only. The health score uses 3 different factors with different weights per FR-HLT-01 and is free-tier. They share UI patterns (circular ring, percentile, factor breakdown) but compute different metrics.
- **Extends the existing analytics repository.** Stories 5.4-11.4 established the analytics repository with multiple methods. This story adds `getWardrobeHealthScore` following the identical connection/RLS/camelCase pattern.
- **Extends the existing AnalyticsDashboardScreen.** The health score section is added as the FIRST section (hero position), before the existing SummaryCardsRow. The dashboard now fetches an additional free-tier endpoint for all users.
- **Also surfaces on the WardrobeScreen.** A compact mini health bar at the top of the wardrobe grid provides at-a-glance health context and drives users to the full Analytics dashboard. This satisfies FR-HLT-01's requirement that the score is visible from the "Wardrobe tab."
- **No new database migration needed.** All required data already exists: `items.wear_count`, `items.last_worn_date`, `items.purchase_price`, `items.created_at`. The health score is computed on-the-fly from existing data.
- **No new dependencies needed.** Uses existing packages. The circular score ring reuses the `CustomPaint` pattern from Story 11.2's `SustainabilitySection`.

### Design Decision: 3-Factor Health Score (Not 5-Factor Like Sustainability)

FR-HLT-01 specifies 3 factors with specific weights: % items worn in 90 days (50%), % items with CPW < 5 (30%), size vs utilization ratio (20%). This is intentionally simpler than the 5-factor sustainability score. The health score is a quick-read metric focused on "am I using my wardrobe?" while sustainability measures broader environmental impact. Keeping them distinct avoids confusion and lets each score serve its purpose.

### Design Decision: Free-Tier Access

The wardrobe health score is free-tier because it serves as the engagement hook for Epic 13's behavior-change loop: see health score -> feel motivated to improve -> declutter/sell/donate (Stories 13.2, 13.3). Premium-gating the entry point would reduce adoption. The premium value in Epic 13 comes from the AI-powered resale listing generation (already implemented in Story 7.3) and advanced analytics (Epic 11), not from the health score itself.

### Design Decision: Server-Side Recommendation Generation

Recommendations are generated server-side because they depend on the factor scores and require simple math to determine which factor is the bottleneck. This keeps the recommendation logic centralized and consistent. The client simply displays the string.

### Design Decision: Mini Health Bar on Wardrobe Tab

FR-HLT-01 states the score should be visible from the "Wardrobe or Analytics tab." A compact summary bar on the WardrobeScreen satisfies this without cluttering the wardrobe grid. It acts as a gentle nudge and a gateway to the full Analytics dashboard.

### Design Decision: Health Score as First Dashboard Section

The health score is positioned as the first (hero) section on the Analytics dashboard. It provides an executive summary of wardrobe efficiency before the detailed breakdowns (CPW, top worn, neglected, categories, sustainability, etc.). This gives users an immediate "how am I doing?" answer.

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getWardrobeHealthScore` method)
  - `apps/api/src/main.js` (add `GET /v1/analytics/wardrobe-health` route, no premium guard)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart` (health score widget)
  - `apps/mobile/test/features/analytics/widgets/health_score_section_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add health score state, 7th free-tier fetch, new first sliver)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getWardrobeHealthScore` method)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (add mini health bar at top)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add health score tests, update mock)
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (add mini health bar tests)
- Modified API test files:
  - `apps/api/test/modules/analytics/analytics-repository.test.js` (add tests for `getWardrobeHealthScore`)
  - `apps/api/test/modules/analytics/analytics-endpoints.test.js` (add tests for new endpoint)
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
      ├── ai_insights_section.dart (Story 5.7)
      ├── brand_value_section.dart (Story 11.1)
      ├── category_distribution_section.dart (Story 5.6)
      ├── cpw_item_row.dart (Story 5.4)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── gap_analysis_section.dart (Story 11.3)
      ├── health_score_section.dart (NEW)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── seasonal_reports_section.dart (Story 11.4)
      ├── summary_cards_row.dart (Story 5.4)
      ├── sustainability_section.dart (Story 11.2)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (Story 5.6)
  ```

### Technical Requirements

- **Analytics repository extension:** Add `getWardrobeHealthScore` method to the existing `createAnalyticsRepository` return object. Same pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
- **Single SQL query for all metrics:** Use one query with aggregate functions (`COUNT`, `FILTER`) to gather all raw data. Factor score computation happens in JS to keep SQL simple and scoring logic maintainable.
- **Factor score formulas (all 0-100):**
  - utilizationScore (50%): `totalItems > 0 ? (itemsWorn90d / totalItems) * 100 : 0` -- % of wardrobe actively used in 90 days.
  - cpwScore (30%): `itemsWithCpw > 0 ? (itemsGoodCpw / itemsWithCpw) * 100 : 0` -- % of priced+worn items with CPW below 5.
  - sizeUtilizationScore (20%): `totalItems > 0 ? Math.min(100, (totalWears / totalItems) * 10) : 0` -- penalizes hoarding.
- **Composite score:** Weighted sum: `0.50 * utilization + 0.30 * cpw + 0.20 * sizeUtilization`, rounded to integer, clamped 0-100.
- **Color tiers:** Green (80-100), Yellow (50-79), Red (0-49). These match FR-HLT-02.
- **Percentile formula:** `max(1, 100 - score)`. Same deterministic approach as Story 11.2.
- **Recommendation generation:** Server-side string based on lowest-scoring factor. No AI involved.
- **No premium gating.** This is a free-tier endpoint. Do NOT use `premiumGuard.requirePremium()`.
- **Score ring widget:** Reuse the `CustomPaint` circular ring pattern from `SustainabilitySection` (Story 11.2). Use the same arc-drawing approach with tier-based coloring.
- **Mini health bar:** Compact row widget on WardrobeScreen. Fetches health score independently. Fails silently (hidden) if API errors.

### Architecture Compliance

- **Server authority for analytics data:** Health scores are computed server-side. The client displays pre-computed results.
- **RLS enforces data isolation:** Health score endpoint is RLS-scoped via `set_config`. A user can only see their own health data.
- **Mobile boundary owns presentation:** The API returns raw scores, factors, and recommendation string. The client handles ring rendering, color coding, layout, and formatting.
- **No new AI calls:** This story is purely data aggregation + computation + UI display. No Gemini involvement.
- **API module placement:** New method goes in existing `apps/api/src/modules/analytics/analytics-repository.js`. New route goes in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/wardrobe-health` follows the existing analytics endpoint naming convention.
- **Epic 13 component mapping:** Architecture specifies `mobile/features/resale`, `api/modules/resale`, `api/modules/notifications` for Epic 13. However, the health score is an analytics computation (not resale-specific), so it correctly lives in `api/modules/analytics` and `mobile/features/analytics`. Stories 13.2 and 13.3 will introduce resale-specific components.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `flutter/material.dart` -- `CustomPaint`, `Container`, `Row`, `Column`
  - `intl: ^0.19.0` -- number formatting
  - `dart:math` -- `min`, `max` for score clamping
- The circular score ring does NOT require a third-party package. Reuse the `CustomPaint` pattern from Story 11.2's SustainabilitySection.
- API side: no new npm dependencies. Uses existing `pool` from `pg`.

### File Structure Requirements

- New mobile widget goes in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing analytics widgets.
- Test file mirrors source structure under `apps/mobile/test/features/analytics/widgets/`.
- API tests extend existing test files in `apps/api/test/modules/analytics/`.
- The mini health bar widget on WardrobeScreen is built inline (not a separate widget file) since it's a simple row layout.

### Testing Requirements

- **API repository tests** must verify:
  - Composite score is correctly weighted (0.50, 0.30, 0.20)
  - Each factor score computes correctly against its formula
  - Score clamped to 0-100
  - Percentile: max(1, 100 - score)
  - colorTier matches score ranges: green 80-100, yellow 50-79, red 0-49
  - Recommendation string is non-empty for all scenarios
  - Returns zero score for user with no items
  - Returns appropriate score for user with items but no wears
  - Handles items without purchase_price (cpwScore ignores them)
  - RLS enforcement (user isolation)
  - Edge cases: single item, all items worn recently, all items with good CPW, large idle wardrobe
- **API endpoint tests** must verify:
  - 200 response with correct JSON structure for authenticated user
  - 401 for unauthenticated requests
  - NO premium gating (free users get 200, not 403)
  - Response includes all expected fields (score, factors, percentile, recommendation, totalItems, itemsWorn90d, colorTier)
  - Returns zero score for user with no items
- **Mobile widget tests** must verify:
  - Score ring renders with correct score value
  - Score ring color: red 0-49, yellow 50-79, green 80-100
  - Percentile badge displays correctly
  - Factor breakdown shows 3 rows with correct names and weights
  - Recommendation card displays with tier-colored background
  - Empty state renders correctly
  - Semantics labels present
- **Dashboard integration tests** must verify:
  - HealthScoreSection appears as first section on dashboard
  - Health score fetched for ALL users (no premium gating)
  - Free user triggers 7 parallel API calls; premium user triggers 10
- **WardrobeScreen integration tests** must verify:
  - Mini health bar renders at top of wardrobe grid
  - Mini health bar shows correct score and recommendation
  - Tap navigates to AnalyticsDashboardScreen
  - Mini health bar hidden on API failure
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1705+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1276+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 11.2** (done) established: `SustainabilitySection` widget with circular score ring (CustomPaint), factor breakdown, percentile chip, CO2 savings card. Dashboard conditionally fetches 8 endpoints for premium (6 free + 2 premium). `getSustainabilityAnalytics` is the 8th repository method. Deterministic percentile formula: `max(1, 100 - score)`. Test baselines after 11.2: 1115 API tests, 1533 Flutter tests.
- **Story 11.4** (done) established: `SeasonalReportsSection` and `HeatmapSection`. Dashboard fetches 10 endpoints for premium (6 free + 4 premium). Test baselines after 11.4: 1175 API tests, 1585 Flutter tests.
- **Story 12.4** (done, most recent epic) established latest test baselines: 1276 API tests, 1705 Flutter tests.
- **Story 5.4** (done) established: `AnalyticsDashboardScreen`, `analytics-repository.js` factory pattern, CPW thresholds (green < 5, yellow 5-20, red > 20). Error-retry pattern. `Future.wait` parallel fetch.
- **Story 5.5** (done) established: `TopWornSection`, `NeglectedItemsSection` with 60-day neglect threshold. Neglected items API uses `last_worn_date` and `created_at` as fallback.
- **Story 2.7** (done) established: `neglect_status` computation on items (180-day threshold), `isNeglected` getter on WardrobeItem model. FilterBar "Neglect" filter.
- **Story 7.2** (done) established: `PremiumGateCard`, `premiumGuard`. NOTE: This story does NOT use premium gating.
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Section headers: 16px bold, #1F2937.
  - Empty state icons: 32px, #9CA3AF with descriptive text.
  - Conditional API fetching: premium-only calls skip for free users.
  - Circular score ring: `CustomPaint` with `drawArc` (from Story 11.2).
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `resale_status`, `created_at`, `updated_at`.
- **Current test baselines (from Story 12.4):** 1276 API tests, 1705 Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT compute health scores client-side by fetching all items and computing in Dart. Use the dedicated server-side endpoint.
- DO NOT add premium gating. This is a FREE-TIER feature. Do NOT use `premiumGuard.requirePremium()` or `PremiumGateCard`.
- DO NOT confuse with the sustainability score (Story 11.2). Health score has 3 factors with different weights; sustainability has 5 factors. They are separate metrics.
- DO NOT add charting libraries for the score ring. Use Flutter's built-in `CustomPaint`. Do NOT use `fl_chart` for this -- it's a progress ring, not a chart.
- DO NOT create a new screen for the health score. It is a section within the existing `AnalyticsDashboardScreen` AND a mini bar on the existing `WardrobeScreen`.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify existing API endpoints or repository methods. Only add new methods.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT use actual cross-user queries for percentile calculation. Use the deterministic formula `max(1, 100 - score)`.
- DO NOT store health scores in the database. They are computed on-the-fly from existing item data.
- DO NOT re-fetch the entire dashboard when the health score section loads. It loads as part of the initial parallel fetch.
- DO NOT implement resale prompts or declutter flows in this story. Those are Stories 13.2 and 13.3.
- DO NOT use negative framing for low health scores. Use encouraging language like "Wear 5 more items this month to boost your score!" rather than "Your wardrobe is unhealthy."
- DO NOT hardcode the health score factors in multiple places. Define constants for weights (0.50, 0.30, 0.20) and thresholds (CPW < 5, 90-day window, tier boundaries) in the repository method.

### Out of Scope

- **Monthly Resale Prompts (FR-RSL-01, FR-RSL-05, FR-RSL-06):** Story 13.2.
- **Spring Clean Declutter Flow & Donations (FR-HLT-05, FR-DON-01-03, FR-DON-05):** Story 13.3.
- **AI-powered health recommendations:** No Gemini usage in this story. Recommendations are deterministic strings.
- **Health score history/trends over time:** Not required by any FR.
- **Animated score ring transitions:** Nice-to-have if time permits, but not required.
- **Social sharing of health score:** Not required by any FR.
- **Health score notifications/alerts:** Not in this story. Story 13.2 handles resale prompts.
- **Actual percentile calculation using cross-user data:** V1 uses deterministic formula. Real percentiles require a privileged aggregation query and are deferred.
- **Offline health score viewing:** Out of scope for V1.
- **Export/share health data:** Not required by any FR.

### References

- [Source: epics.md - Story 13.1: Wardrobe Health Score]
- [Source: epics.md - FR-HLT-01: The system shall calculate a wardrobe health score (0-100) based on 3 weighted factors: % items worn in 90 days (50%), % items with CPW < 5 (30%), size vs utilization ratio (20%)]
- [Source: epics.md - FR-HLT-02: The health score shall be color-coded: Green (80-100), Yellow (50-79), Red (< 50)]
- [Source: epics.md - FR-HLT-03: The score shall include recommendations (e.g., "Declutter 8 items to improve health")]
- [Source: epics.md - FR-HLT-04: A deterministic user comparison shall show percentile ranking]
- [Source: architecture.md - Epic 13 Circular Resale Triggers -> mobile/features/resale, api/modules/resale, api/modules/notifications]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: architecture.md - Gated features include... advanced analytics (NOTE: health score is NOT premium-gated)]
- [Source: 11-2-sustainability-scoring-co2-savings.md - SustainabilitySection, circular score ring CustomPaint pattern, factor breakdown, percentile chip, deterministic percentile formula]
- [Source: 5-4-basic-wardrobe-value-analytics.md - AnalyticsDashboardScreen, analytics-repository.js factory pattern, Future.wait parallel pattern, CPW thresholds]
- [Source: 5-5-top-worn-neglected-items-analytics.md - NeglectedItemsSection, 60-day neglect threshold, last_worn_date/created_at fallback]
- [Source: 2-7-neglect-detection-badging.md - neglect_status computation, 180-day threshold, isNeglected getter]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing analytics methods]
- [Source: apps/mobile/lib/src/features/analytics/widgets/sustainability_section.dart - CustomPaint circular ring pattern to reuse]
- [Source: apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart - dashboard with parallel fetch pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Dashboard test scroll offsets needed adjustment due to HealthScoreSection adding height above existing sections.
- Health score Future.wait integration required `.then(onError:)` pattern to handle API failures gracefully without blocking other parallel fetches.

### Completion Notes List

- Task 1: Added `getWardrobeHealthScore(authContext)` method to analytics-repository.js with single SQL query, 3-factor scoring (utilization 50%, CPW 30%, size-utilization 20%), composite score clamped 0-100, deterministic percentile, color tier, and recommendation generation.
- Task 2: Added `GET /v1/analytics/wardrobe-health` route in main.js after heatmap route. FREE-TIER, no premium gating.
- Task 3: Added 22 unit tests for getWardrobeHealthScore covering all factor calculations, edge cases, RLS, empty wardrobe, single item, perfect score.
- Task 4: Added 5 endpoint integration tests for wardrobe-health: auth, response shape, empty state, no premium gating.
- Task 5: Added `getWardrobeHealthScore()` method to ApiClient calling GET /v1/analytics/wardrobe-health.
- Task 6: Created HealthScoreSection widget with circular score ring (CustomPaint), percentile badge, 3 factor rows with progress bars, recommendation card with tier-colored background, empty state, and Semantics labels.
- Task 7: Integrated HealthScoreSection as first section on AnalyticsDashboardScreen. Health score is fetched in parallel with other free-tier calls using `.then(onError:)` for graceful failure handling.
- Task 8: Added mini health bar on WardrobeScreen above filter bar. Shows score, tier label, truncated recommendation. Tap navigates to Analytics dashboard. Hidden on API failure.
- Task 9: Created 14 widget tests for HealthScoreSection covering header, score ring, color coding, percentile, factors, recommendation, empty state, semantics.
- Task 10: Added 7 dashboard integration tests for health score. Updated existing tests with scroll offsets and API call count expectations (7 free, 11 premium).
- Task 11: Added 5 wardrobe screen tests for mini health bar: render, recommendation, navigation, failure hiding, grid compatibility.
- Task 12: All regression tests pass. flutter analyze: 15 pre-existing issues, 0 new. flutter test: 1730 pass (was 1705). npm test: 1303 pass (was 1276).

### File List

- `apps/api/src/modules/analytics/analytics-repository.js` (modified - added getWardrobeHealthScore method)
- `apps/api/src/main.js` (modified - added GET /v1/analytics/wardrobe-health route)
- `apps/api/test/modules/analytics/analytics-repository.test.js` (modified - added 22 health score unit tests)
- `apps/api/test/modules/analytics/analytics-endpoints.test.js` (modified - added 5 health score endpoint tests)
- `apps/mobile/lib/src/core/networking/api_client.dart` (modified - added getWardrobeHealthScore method)
- `apps/mobile/lib/src/features/analytics/widgets/health_score_section.dart` (new - HealthScoreSection widget)
- `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (modified - health score state, fetch, hero section)
- `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (modified - mini health bar)
- `apps/mobile/test/features/analytics/widgets/health_score_section_test.dart` (new - 14 widget tests)
- `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (modified - 7 new tests, updated existing scroll offsets and mock)
- `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (modified - 5 new tests, updated mock)
