# Story 11.2: Sustainability Scoring & CO2 Savings

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Premium User,
I want to see my environmental impact quantified based on my wearing habits,
so that I understand my contribution to sustainable fashion and am motivated to wear what I own.

## Acceptance Criteria

1. Given I am a Premium user with wardrobe items and wear logs, when I scroll down the Analytics dashboard (existing `AnalyticsDashboardScreen`), then I see a new "Sustainability" section below the existing "Brand Value" section. The section displays a sustainability score (0-100) calculated from 5 weighted factors: average wear count (30%), percentage of wardrobe worn in last 90 days (25%), average CPW efficiency (20%), resale activity (15%), and new purchases avoided (10%). The score is displayed prominently with a circular progress indicator. (FR-SUS-01)

2. Given the sustainability score is displayed, when I view the section, then the score number is shown inside a circular progress ring that uses a color gradient: red (0-33), yellow (34-66), green (67-100). A leaf icon (`Icons.eco`) is displayed next to the score label "Sustainability Score". Below the score, the 5 individual factor scores are shown as a compact breakdown list with factor name, weight, and individual score (0-100 each). (FR-SUS-03)

3. Given I have wear logs, when the sustainability section loads, then below the score I see an "Estimated CO2 Savings" metric. The calculation uses industry benchmarks: each item re-wear avoids approximately 0.5 kg CO2 equivalent (the CO2 cost of producing a new average garment is ~10 kg; 20 wears is a reasonable lifetime, so each additional wear beyond the first saves ~0.5 kg). The display shows: total estimated CO2 saved in kg (formatted with 1 decimal), and a relatable comparison (e.g., "Equivalent to X km not driven" using 0.21 kg CO2/km). (FR-SUS-02)

4. Given my sustainability score is calculated, when the section renders, then I see a percentile comparison: "Top X% of Vestiaire users". The percentile is computed server-side using a deterministic formula based on the user's score (not actual user comparison for V1): percentile = max(1, 100 - score). A score of 80 shows "Top 20%". This avoids cross-user queries while providing motivational feedback. (FR-SUS-04)

5. Given I am a Free user viewing the Analytics dashboard, when the "Sustainability" section would render, then instead a `PremiumGateCard` is displayed with title "Sustainability Score", subtitle "See your environmental impact and CO2 savings", icon `Icons.eco_outlined`, and a "Go Premium" CTA that calls `subscriptionService.presentPaywallIfNeeded()`. Free users do NOT trigger the sustainability API call. (FR-SUS-01, Premium gating per architecture)

6. Given I have no wear logs at all, when the sustainability section loads, then it shows an empty state: "Start logging your outfits to see your sustainability impact!" with an `Icons.eco_outlined` icon (32px, #9CA3AF). The score displays as 0 and CO2 savings as 0.0 kg. (FR-SUS-01)

7. Given my sustainability score reaches 80 or above, when the API computes the score, then it also triggers badge evaluation for the "Eco Warrior" badge via `badgeService.checkAndAward(authContext, 'eco_warrior')`. The badge evaluation is best-effort (try/catch) and does NOT fail the sustainability endpoint. The API response includes a `badgeAwarded` boolean indicating if the Eco Warrior badge was newly awarded. (FR-SUS-05)

8. Given the API call to fetch sustainability data fails, when the analytics screen loads, then the existing error-retry pattern from Story 5.4 handles the failure gracefully -- the entire dashboard shows an error state with a "Retry" button. (FR-SUS-01)

9. Given the `eco_warrior` badge check in `evaluate_badges` RPC currently returns FALSE (placeholder from Story 6.4), when this story's migration runs, then the function is updated to check `sustainability_score >= 80` from the sustainability computation. Since sustainability scores are computed on-the-fly (not stored), the badge is awarded via the API layer (not the RPC). The RPC placeholder is kept as-is; badge awarding for eco_warrior happens in the API via `badgeService.checkAndAward`. (FR-SUS-05, FR-GAM-04)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1084+ API tests, 1514+ Flutter tests) and new tests cover: sustainability score repository method, CO2 savings calculation, API endpoint (auth, premium gating, empty wardrobe, badge trigger), mobile SustainabilitySection widget (premium/free states, score display, color gradient, factor breakdown, CO2 savings, percentile, empty state), dashboard integration, and edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Add sustainability analytics method to analytics repository (AC: 1, 2, 3, 4, 6, 7)
  - [x] 1.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getSustainabilityAnalytics(authContext)` method following the identical connection/RLS pattern as existing methods: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
  - [x] 1.2: Execute a single SQL query to gather raw sustainability metrics: `SELECT COUNT(*) AS total_items, COALESCE(AVG(wear_count), 0) AS avg_wear_count, COUNT(*) FILTER (WHERE last_worn_date >= CURRENT_DATE - INTERVAL '90 days') AS items_worn_90d, COALESCE(AVG(CASE WHEN purchase_price IS NOT NULL AND wear_count > 0 THEN purchase_price / wear_count ELSE NULL END), 0) AS avg_cpw, COALESCE(SUM(CASE WHEN wear_count > 1 THEN wear_count - 1 ELSE 0 END), 0) AS total_rewears, COUNT(*) FILTER (WHERE resale_status IN ('listed', 'sold', 'donated')) AS resale_active_items, COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '90 days') AS new_items_90d FROM app_public.items`.
  - [x] 1.3: Compute the 5 factor scores in JS (each 0-100):
    - **avgWearScore** (weight 30%): `Math.min(100, (avgWearCount / 20) * 100)` -- 20 wears = perfect score.
    - **utilizationScore** (weight 25%): `totalItems > 0 ? (itemsWorn90d / totalItems) * 100 : 0` -- % of wardrobe worn in 90 days.
    - **cpwScore** (weight 20%): `avgCpw > 0 ? Math.min(100, (5 / avgCpw) * 100) : 0` -- CPW of 5 or less = perfect score; higher CPW = lower score. 0 if no priced items.
    - **resaleScore** (weight 15%): `totalItems > 0 ? Math.min(100, (resaleActiveItems / totalItems) * 50 * 100 / 50) : 0` -- simplified: `Math.min(100, (resaleActiveItems / Math.max(totalItems, 1)) * 500)`. Having 20% of items in resale cycle = perfect score.
    - **newPurchaseScore** (weight 10%): `totalItems > 0 ? Math.max(0, 100 - (newItems90d / Math.max(totalItems, 1)) * 200) : 100` -- 0 new items in 90 days = 100; adding 50%+ of wardrobe as new = 0.
  - [x] 1.4: Compute composite score: `Math.round(avgWearScore * 0.30 + utilizationScore * 0.25 + cpwScore * 0.20 + resaleScore * 0.15 + newPurchaseScore * 0.10)`. Clamp to 0-100.
  - [x] 1.5: Compute CO2 savings: `totalRewears * 0.5` (kg CO2 saved). Compute car km equivalent: `co2SavedKg / 0.21` rounded to 1 decimal.
  - [x] 1.6: Compute percentile: `Math.max(1, 100 - compositeScore)`.
  - [x] 1.7: Return object: `{ score: number, factors: { avgWearScore, utilizationScore, cpwScore, resaleScore, newPurchaseScore }, co2SavedKg: number, co2CarKmEquivalent: number, percentile: number, totalRewears: number, totalItems: number, badgeAwarded: false }`. The `badgeAwarded` field is set by the route handler, not the repository.

- [x] Task 2: API - Add sustainability route with premium gating and badge trigger (AC: 1, 4, 5, 7, 8)
  - [x] 2.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/sustainability`. Requires authentication (401 if unauthenticated). Before calling the repository, call `premiumGuard.requirePremium(authContext)` to enforce premium-only access (returns 403 with `PREMIUM_REQUIRED` for free users). Call `analyticsRepository.getSustainabilityAnalytics(authContext)`.
  - [x] 2.2: After getting the result, if `result.score >= 80`, attempt badge award: wrap in try/catch, call `badgeService.checkAndAward(authContext, 'eco_warrior')`. If badge was newly awarded, set `result.badgeAwarded = true`. Badge failure must NOT fail the endpoint.
  - [x] 2.3: Return 200 with the full sustainability result object. Place route after existing analytics routes in main.js (after brand-value route).

- [x] Task 3: API - Unit tests for sustainability repository method (AC: 1, 2, 3, 4, 6, 10)
  - [x] 3.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getSustainabilityAnalytics`:
    - Returns composite score between 0 and 100.
    - avgWearScore: 0 when no wears, 100 when avg >= 20 wears.
    - utilizationScore: 0 when no items worn in 90 days, 100 when all worn.
    - cpwScore: 100 when avg CPW <= 5, decreasing for higher CPW, 0 when no priced items.
    - resaleScore: 0 when no resale activity, increases with resale items.
    - newPurchaseScore: 100 when no new items in 90 days, decreases with more new items.
    - Composite score uses correct weights (0.30, 0.25, 0.20, 0.15, 0.10).
    - CO2 savings: 0 when no rewears, correct when rewears exist (totalRewears * 0.5).
    - CO2 car km equivalent computed correctly (co2SavedKg / 0.21).
    - Percentile computed as max(1, 100 - score).
    - Returns zero score for user with no items.
    - Respects RLS (user A cannot see user B's sustainability data).
    - Handles items without purchase_price (cpwScore is 0 when no priced items).
    - Handles items without wear logs (avgWearScore is 0).
    - resaleScore correctly counts items with resale_status in ('listed', 'sold', 'donated').

- [x] Task 4: API - Integration tests for sustainability endpoint (AC: 1, 5, 7, 8, 10)
  - [x] 4.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/sustainability` returns 200 with sustainability object for premium user.
    - `GET /v1/analytics/sustainability` returns 401 if unauthenticated.
    - `GET /v1/analytics/sustainability` returns 403 with `PREMIUM_REQUIRED` for free user.
    - Response includes `score`, `factors`, `co2SavedKg`, `co2CarKmEquivalent`, `percentile`, `badgeAwarded` fields.
    - Returns zero score for user with no items.
    - Badge trigger: when score >= 80, `badgeAwarded` may be true (if badge not already earned).

- [x] Task 5: Mobile - Add sustainability API method to ApiClient (AC: 1)
  - [x] 5.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getSustainabilityAnalytics()` method. Calls `GET /v1/analytics/sustainability` using `_authenticatedGet`. Returns response JSON map. Throws `ApiException` on error (including 403 for non-premium).

- [x] Task 6: Mobile - Create SustainabilitySection widget (AC: 1, 2, 3, 4, 5, 6)
  - [x] 6.1: Create `apps/mobile/lib/src/features/analytics/widgets/sustainability_section.dart` with `SustainabilitySection` StatelessWidget. Constructor accepts: `required bool isPremium`, `required int score`, `required Map<String, dynamic> factors`, `required double co2SavedKg`, `required double co2CarKmEquivalent`, `required int percentile`, `required bool badgeAwarded`, `SubscriptionService? subscriptionService`.
  - [x] 6.2: **Premium gate (free users):** If `!isPremium`, render `PremiumGateCard(title: "Sustainability Score", subtitle: "See your environmental impact and CO2 savings", icon: Icons.eco_outlined, subscriptionService: subscriptionService)`. Do NOT render score or factors.
  - [x] 6.3: **Section header:** "Sustainability" (16px bold, #1F2937) with a leaf icon `Icons.eco` (16px, #22C55E) next to it.
  - [x] 6.4: **Score display:** A `CustomPaint` or `CircularProgressIndicator`-based circular ring (120x120). The ring fill represents score/100. Ring color: red (#EF4444) for 0-33, yellow (#F59E0B) for 34-66, green (#22C55E) for 67-100. Score number displayed centered inside the ring (32px bold, color matching the ring). Below the ring: "out of 100" label (12px, #6B7280).
  - [x] 6.5: **Percentile badge:** Below the score ring, display "Top {percentile}% of Vestiaire users" in a compact chip/badge (12px bold, #4F46E5 background, white text, 16px border radius).
  - [x] 6.6: **Factor breakdown:** Below the percentile, show 5 rows, each with: factor name (14px, #1F2937), weight in parentheses (12px, #6B7280), and individual score as a small horizontal progress bar (height 8, width 100, same color coding as the main score ring). Factor display names: "Wear Frequency (30%)", "Wardrobe Utilization (25%)", "Cost Efficiency (20%)", "Resale Activity (15%)", "Purchase Restraint (10%)".
  - [x] 6.7: **CO2 savings card:** Below the factor breakdown, a card (#F0FDF4 background, 12px radius, 16px padding) showing: large leaf icon (#22C55E, 24px), "Estimated CO2 Saved" label (14px bold, #1F2937), CO2 value "{co2SavedKg} kg CO2" (20px bold, #22C55E), comparison line "Equivalent to {co2CarKmEquivalent} km not driven" (12px, #6B7280).
  - [x] 6.8: **Empty state:** When `score == 0` and `co2SavedKg == 0`, show "Start logging your outfits to see your sustainability impact!" with `Icons.eco_outlined` icon (32px, #9CA3AF). Still show the score ring at 0.
  - [x] 6.9: **Badge notification:** If `badgeAwarded` is true, show a subtle celebration banner at the top of the section: "You earned the Eco Warrior badge!" with `Icons.emoji_events` (gold color). This is informational only -- the badge modal is handled by the existing badge system.
  - [x] 6.10: Add `Semantics` labels: "Sustainability score, [score] out of 100", "Top [percentile] percent of users", "Estimated CO2 saved, [amount] kilograms", "Factor [name], score [value] out of 100".

- [x] Task 7: Mobile - Integrate SustainabilitySection into AnalyticsDashboardScreen (AC: 1, 2, 3, 4, 5, 8)
  - [x] 7.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `int? _sustainabilityScore`, `Map<String, dynamic>? _sustainabilityFactors`, `double? _co2SavedKg`, `double? _co2CarKmEquivalent`, `int? _sustainabilityPercentile`, `bool _sustainabilityBadgeAwarded = false`.
  - [x] 7.2: Update `_loadAnalytics()`: After the existing 7 parallel fetches (6 free + 1 premium brand value), add a conditional 8th fetch for sustainability analytics ONLY if the user is premium. If premium, call `apiClient.getSustainabilityAnalytics()` and parse results into state fields. If not premium, skip the call. Update the conditional `Future.wait` to include the 8th call for premium users. Premium users now trigger 8 API calls; free users still trigger 6.
  - [x] 7.3: In the `CustomScrollView` slivers, after the existing `BrandValueSection` sliver, add a `SliverToBoxAdapter` wrapping `SustainabilitySection(isPremium: subscriptionService?.isPremiumCached ?? false, score: _sustainabilityScore ?? 0, factors: _sustainabilityFactors ?? {}, co2SavedKg: _co2SavedKg ?? 0.0, co2CarKmEquivalent: _co2CarKmEquivalent ?? 0.0, percentile: _sustainabilityPercentile ?? 100, badgeAwarded: _sustainabilityBadgeAwarded, subscriptionService: subscriptionService)`.
  - [x] 7.4: No new navigation methods needed -- the sustainability section is informational (no drill-down).

- [x] Task 8: Mobile - Widget tests for SustainabilitySection (AC: 1, 2, 3, 4, 5, 6, 10)
  - [x] 8.1: Create `apps/mobile/test/features/analytics/widgets/sustainability_section_test.dart`:
    - Renders PremiumGateCard when isPremium is false.
    - Does NOT render score or factors when isPremium is false.
    - Renders section header "Sustainability" with leaf icon when isPremium is true.
    - Renders circular score ring with correct score value.
    - Score ring color: red for 0-33, yellow for 34-66, green for 67-100.
    - Renders percentile badge with correct text "Top X% of Vestiaire users".
    - Renders 5 factor rows with correct names, weights, and progress bars.
    - Renders CO2 savings card with correct kg value and km equivalent.
    - Empty state shows prompt when score is 0 and co2SavedKg is 0.
    - Badge awarded banner shows when badgeAwarded is true.
    - Badge awarded banner hidden when badgeAwarded is false.
    - Semantics labels present on all key elements.

- [x] Task 9: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 5, 8, 10)
  - [x] 9.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders SustainabilitySection below BrandValueSection for premium user.
    - Dashboard renders PremiumGateCard for sustainability for free user.
    - Dashboard error state still works (handles 8 API calls for premium, 6 for free).
    - Mock API returns sustainability data for premium user.
    - Mock API does NOT call sustainability endpoint for free user.
    - Premium user triggers 8 parallel API calls; free user triggers 6.

- [x] Task 10: Regression testing (AC: all)
  - [x] 10.1: Run `flutter analyze` -- zero new issues.
  - [x] 10.2: Run `flutter test` -- all existing 1514+ Flutter tests plus new tests pass.
  - [x] 10.3: Run `npm --prefix apps/api test` -- all existing 1084+ API tests plus new tests pass.
  - [x] 10.4: Verify existing AnalyticsDashboardScreen tests pass with the new section added (mock API updated).
  - [x] 10.5: Verify existing premium gating tests continue to pass.
  - [x] 10.6: Verify existing badge system tests continue to pass (eco_warrior badge still placeholder in RPC; API-layer awarding is new).

## Dev Notes

- This is the **second story in Epic 11** (Advanced Analytics 2.0). It adds sustainability scoring and CO2 savings estimation to the Analytics dashboard, building on the analytics infrastructure from Stories 5.4-5.7 and the brand value section from Story 11.1.
- This story implements **FR-SUS-01** (sustainability score 0-100 based on 5 weighted factors), **FR-SUS-02** (CO2 savings estimation), **FR-SUS-03** (color gradient + leaf icon display), and **FR-SUS-04** (percentile comparison).
- This story also enables the **FR-SUS-05** Eco Warrior badge (score >= 80) by triggering badge evaluation from the API layer. The `evaluate_badges` RPC placeholder for `eco_warrior` stays as-is; the badge is awarded via `badgeService.checkAndAward` in the sustainability endpoint handler.
- **Premium-gated feature.** Per architecture: "Gated features include... advanced analytics." Per Story 7.2 premium matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only." The `premiumGuard.requirePremium()` utility (created in Story 7.2) is used for server-side gating. Client-side uses `PremiumGateCard` (created in Story 7.2) for the free-user experience.
- **Extends the existing analytics repository.** Stories 5.4-5.6 established `analytics-repository.js` with 6 methods. Story 11.1 added `getBrandValueAnalytics` as the 7th. This story adds `getSustainabilityAnalytics` as the 8th method, following the identical connection/RLS/camelCase pattern.
- **Extends the existing AnalyticsDashboardScreen.** The sustainability section is added as a sliver after `BrandValueSection`. The dashboard now conditionally fetches 8 endpoints (6 free + 2 premium) for premium users, or 6 for free users.
- **No new database migration needed.** All required data already exists: `items.wear_count`, `items.last_worn_date`, `items.purchase_price`, `items.resale_status`, `items.created_at`. The sustainability score is computed on-the-fly from existing data -- no new tables or columns.
- **No new dependencies needed.** Uses existing packages. The circular score ring can be built with `CustomPaint` or `TweenAnimationBuilder` + `CircularProgressIndicator` from Flutter's material library.

### Design Decision: Server-Side Sustainability Computation

All 5 factor scores and the composite score are computed server-side via a single SQL query + JS computation. This follows the established architecture principle of "server authority for analytics data." The client receives pre-computed scores and displays them. This prevents client-side data inconsistency and keeps the scoring formula centralized.

### Design Decision: CO2 Savings Benchmark (0.5 kg per re-wear)

The CO2 savings estimate uses a simplified industry benchmark: producing a new average garment emits approximately 10 kg CO2; assuming a 20-wear reasonable lifetime, each re-wear beyond the first saves ~0.5 kg CO2. This is a conservative, defensible estimate based on WRAP UK and Quantis data. The formula is: `totalRewears * 0.5 kg`. Total rewears = sum of (wear_count - 1) for all items with wear_count > 1.

### Design Decision: Deterministic Percentile (No Cross-User Queries)

FR-SUS-04 requires a percentile comparison. For V1, this uses a deterministic formula `percentile = max(1, 100 - score)` rather than actual cross-user queries. This avoids: (1) RLS complications (would need a privileged query), (2) performance impact of aggregating all users, (3) cold-start issues with few users. The deterministic formula provides motivational feedback that feels realistic. A future version could use actual percentile calculations.

### Design Decision: Eco Warrior Badge Awarded via API Layer

The `evaluate_badges` RPC has a FALSE placeholder for `eco_warrior` (from Story 6.4). Rather than creating a migration to update the RPC (which would need to compute sustainability scores in PL/pgSQL), the badge is awarded in the API layer: the sustainability endpoint checks `score >= 80` and calls `badgeService.checkAndAward`. This is consistent with how badge evaluation works -- best-effort, try/catch wrapped, non-blocking.

### Design Decision: Conditional Premium-Only Fetch

The sustainability API call is only made when the user is premium (`subscriptionService.isPremiumCached`). Free users see a `PremiumGateCard` without any API call, avoiding a wasted 403 roundtrip. This matches the pattern established in Story 11.1 (brand value) and Story 5.7 (AI insights).

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getSustainabilityAnalytics` method)
  - `apps/api/src/main.js` (add `GET /v1/analytics/sustainability` route with premium guard and badge trigger)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/sustainability_section.dart` (sustainability score widget)
  - `apps/mobile/test/features/analytics/widgets/sustainability_section_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add sustainability state, conditional 8th fetch, new sliver)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getSustainabilityAnalytics` method)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add sustainability tests, update mock)
- Modified API test files:
  - `apps/api/test/modules/analytics/analytics-repository.test.js` (add tests for `getSustainabilityAnalytics`)
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
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── summary_cards_row.dart (Story 5.4)
      ├── sustainability_section.dart (NEW)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (Story 5.6)
  ```

### Technical Requirements

- **Analytics repository extension:** Add `getSustainabilityAnalytics` method to the existing `createAnalyticsRepository` return object. Same pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
- **Single SQL query for all metrics:** Use one query with aggregate functions (`COUNT`, `AVG`, `SUM`, `FILTER`) to gather all raw data. Factor score computation happens in JS to keep SQL simple and scoring logic maintainable.
- **Factor score formulas (all 0-100):**
  - avgWearScore: `min(100, (avgWearCount / 20) * 100)` -- benchmark: 20 wears is excellent.
  - utilizationScore: `(itemsWorn90d / totalItems) * 100` -- what % of wardrobe is actively used.
  - cpwScore: `min(100, (5 / avgCpw) * 100)` -- benchmark: CPW of 5 or less is excellent.
  - resaleScore: `min(100, (resaleActiveItems / totalItems) * 500)` -- 20% resale participation = perfect.
  - newPurchaseScore: `max(0, 100 - (newItems90d / totalItems) * 200)` -- fewer new items = better.
- **Composite score:** Weighted sum: `0.30 * avgWear + 0.25 * utilization + 0.20 * cpw + 0.15 * resale + 0.10 * newPurchase`, rounded to integer, clamped 0-100.
- **CO2 formula:** `totalRewears * 0.5` kg. Total rewears = `SUM(CASE WHEN wear_count > 1 THEN wear_count - 1 ELSE 0 END)`.
- **Percentile formula:** `max(1, 100 - score)`. Deterministic, no cross-user queries.
- **Premium gating:** Use `premiumGuard.requirePremium(authContext)` from `apps/api/src/modules/billing/premium-guard.js` (Story 7.2). Client-side uses `PremiumGateCard` from `apps/mobile/lib/src/core/widgets/premium_gate_card.dart` (Story 7.2).
- **Badge trigger:** After computing sustainability score, if score >= 80, call `badgeService.checkAndAward(authContext, 'eco_warrior')` in try/catch. Import `badgeService` from `apps/api/src/modules/badges/badge-service.js` (Story 6.4). The `checkAndAward` method handles idempotency (won't re-award if already earned).
- **Score ring widget:** Use `CustomPaint` with `Canvas.drawArc` for the circular progress ring. Alternatively, use `SizedBox` + `CircularProgressIndicator` with `strokeWidth: 8` and `value: score / 100`. Color: `score <= 33 ? Color(0xFFEF4444) : score <= 66 ? Color(0xFFF59E0B) : Color(0xFF22C55E)`.
- **CO2 card styling:** Light green background `Color(0xFFF0FDF4)`, consistent with sustainability/eco theme. Leaf icon in green `Color(0xFF22C55E)`.

### Architecture Compliance

- **Server authority for analytics data:** Sustainability scores are computed server-side. The client displays pre-computed results.
- **RLS enforces data isolation:** Sustainability endpoint is RLS-scoped via `set_config`. A user can only see their own sustainability data.
- **Premium gating enforced server-side:** `premiumGuard.requirePremium()` checks `profiles.is_premium`. Client-side gate is for UX only.
- **Mobile boundary owns presentation:** The API returns raw scores and metrics. The client handles ring rendering, color coding, layout, and formatting.
- **No new AI calls:** This story is purely data aggregation + computation + UI display. No Gemini involvement.
- **API module placement:** New method goes in existing `apps/api/src/modules/analytics/analytics-repository.js`. New route goes in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/sustainability` follows the existing analytics endpoint naming convention.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `flutter/material.dart` -- `CustomPaint`, `CircularProgressIndicator`, `Container`, `Row`, `Column`
  - `intl: ^0.19.0` -- number formatting for CO2 values
  - `dart:math` -- `min`, `max` for score clamping
- The circular score ring does NOT require a third-party package. Use Flutter's built-in `CustomPaint` or `CircularProgressIndicator`.
- API side: no new npm dependencies. Uses existing `pool` from `pg`, `premiumGuard` from billing module, `badgeService` from badges module.

### File Structure Requirements

- New mobile widget goes in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing analytics widgets.
- Test file mirrors source structure under `apps/mobile/test/features/analytics/widgets/`.
- API tests extend existing test files in `apps/api/test/modules/analytics/`.

### Testing Requirements

- **API repository tests** must verify:
  - Composite score is correctly weighted (0.30, 0.25, 0.20, 0.15, 0.10)
  - Each factor score computes correctly against its benchmark
  - Score clamped to 0-100
  - CO2 savings: totalRewears * 0.5
  - CO2 car km equivalent: co2SavedKg / 0.21
  - Percentile: max(1, 100 - score)
  - Returns zero score for user with no items
  - Returns zero score for user with items but no wears
  - Handles items without purchase_price (cpwScore is 0)
  - Handles resale_status correctly (counts listed, sold, donated)
  - RLS enforcement (user isolation)
  - Edge cases: single item, all items worn recently, no new items, all new items
- **API endpoint tests** must verify:
  - 200 response with correct JSON structure for premium user
  - 401 for unauthenticated requests
  - 403 with PREMIUM_REQUIRED for free user
  - Response includes all expected fields (score, factors, co2SavedKg, co2CarKmEquivalent, percentile, badgeAwarded)
  - Badge trigger when score >= 80
  - Badge NOT triggered when score < 80
  - Empty results for user with no items
- **Mobile widget tests** must verify:
  - PremiumGateCard renders for free users
  - Score ring renders with correct score value
  - Score ring color: red 0-33, yellow 34-66, green 67-100
  - Percentile badge displays correctly
  - Factor breakdown shows 5 rows with correct names and weights
  - CO2 savings card displays kg and km equivalent
  - Empty state renders correctly
  - Badge awarded banner appears when badgeAwarded is true
  - Semantics labels present
- **Dashboard integration tests** must verify:
  - SustainabilitySection appears below BrandValueSection for premium
  - PremiumGateCard appears for free user
  - Premium user triggers 8 parallel API calls; free user triggers 6
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1514+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1084+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 11.1** (done) established: `BrandValueSection` added below `WearFrequencySection`. Dashboard conditionally fetches 7 endpoints for premium (6 free + 1 brand value). `getBrandValueAnalytics` is the 7th repository method. Premium-only fetch pattern with `isPremiumCached` check. Test baselines: 1084 API tests, 1514 Flutter tests.
- **Story 7.2** (done) established: `PremiumGateCard` reusable widget at `apps/mobile/lib/src/core/widgets/premium_gate_card.dart`. `premiumGuard` utility at `apps/api/src/modules/billing/premium-guard.js`. `isPremiumCached` getter. Premium gating matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only."
- **Story 6.4** (done) established: `badges` and `user_badges` tables. `evaluate_badges` RPC with 15 badges; `eco_warrior` has FALSE placeholder. `badgeService` at `apps/api/src/modules/badges/badge-service.js` with `checkAndAward(authContext, badgeKey)` method. Badge evaluation is best-effort (try/catch). The eco_warrior badge definition (key='eco_warrior', name='Eco Warrior', sort_order=15) already exists in the database.
- **Story 7.4** (done) established: `resale_history` table, `items.resale_status` CHECK constraint ('listed', 'sold', 'donated', NULL). Resale status is stored on the items table and can be queried with `FILTER (WHERE resale_status IN ('listed', 'sold', 'donated'))`.
- **Story 5.4** (done) established: `AnalyticsDashboardScreen`, `analytics-repository.js` factory pattern, CPW thresholds (green < 5, yellow 5-20, red > 20). Currency formatting. Error-retry pattern. `Future.wait` parallel fetch.
- **Story 5.5** (done) established: `TopWornSection` with `ChoiceChip` period filters. Isolated section re-fetch pattern.
- **Story 5.6** (done) established: `CategoryDistributionSection`, `WearFrequencySection`. Dashboard with 6 parallel API calls. `fl_chart` dependency.
- **Story 5.7** (done) established: `AiInsightsSection` with premium/free-teaser states. Pattern for premium-only analytics sections.
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
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `resale_status`, `created_at`, `updated_at`.
- **Current test baselines (from Story 11.1):** 1084+ API tests, 1514+ Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT compute sustainability scores client-side by fetching all items and computing in Dart. Use the dedicated server-side endpoint.
- DO NOT skip premium gating. This is an "advanced analytics" feature that MUST be premium-only per architecture and Story 7.2 premium matrix.
- DO NOT call the sustainability API for free users. Check `isPremiumCached` before making the call. Free users see `PremiumGateCard` only.
- DO NOT add charting libraries for the score ring. Use Flutter's built-in `CustomPaint` or `CircularProgressIndicator`. Do NOT use `fl_chart` for this -- it's a progress ring, not a chart.
- DO NOT create a new screen for sustainability. It is a section within the existing `AnalyticsDashboardScreen`.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify the `evaluate_badges` RPC function. Badge awarding for eco_warrior happens in the API layer via `badgeService.checkAndAward`. The RPC placeholder stays as-is.
- DO NOT modify existing API endpoints or repository methods. Only add new methods.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT use actual cross-user queries for percentile calculation. Use the deterministic formula `max(1, 100 - score)`.
- DO NOT hardcode CO2 benchmarks in multiple places. Define `CO2_PER_REWEAR_KG = 0.5` and `CO2_PER_KM_DRIVEN = 0.21` as named constants in the repository method.
- DO NOT create a separate sustainability service. The analytics repository method is sufficient for this data aggregation story (no AI involved).
- DO NOT block the sustainability endpoint response on badge evaluation failure. Badge awarding must be try/catch wrapped and best-effort.
- DO NOT use negative framing for low sustainability scores. Use encouraging language like "Keep wearing your items to improve your score!" rather than "Your sustainability is poor."
- DO NOT store sustainability scores in the database. They are computed on-the-fly from existing item data. This keeps the score always up-to-date without sync concerns.
- DO NOT re-fetch the entire dashboard when the sustainability section loads. It loads as part of the initial parallel fetch.

### Out of Scope

- **Wardrobe Gap Analysis (FR-GAP-*):** Story 11.3.
- **Seasonal Reports & Heatmaps (FR-SEA-*, FR-HMP-*):** Story 11.4.
- **Actual percentile calculation using cross-user data:** V1 uses deterministic formula. Real percentiles require a privileged aggregation query and are deferred.
- **Sustainability score history/trends over time:** Not required by any FR.
- **AI-powered sustainability recommendations:** No Gemini usage in this story.
- **Social sharing of sustainability score:** Not required by any FR.
- **Sustainability leaderboard:** Not required by any FR.
- **Updating evaluate_badges RPC for eco_warrior:** Badge is awarded via API layer instead.
- **Offline sustainability viewing:** Out of scope for V1.
- **Export/share sustainability data:** Not required by any FR.
- **Tab restructuring of analytics dashboard:** The vertical scroll pattern continues.
- **Animated score ring transitions:** Nice-to-have if time permits, but not required.

### References

- [Source: epics.md - Story 11.2: Sustainability Scoring & CO2 Savings]
- [Source: epics.md - FR-SUS-01: The system shall calculate a sustainability score (0-100) based on 5 weighted factors: avg wear count (30%), % wardrobe worn in 90 days (25%), avg CPW (20%), resale activity (15%), new purchases avoided (10%)]
- [Source: epics.md - FR-SUS-02: The system shall estimate CO2 savings from re-wearing vs buying new]
- [Source: epics.md - FR-SUS-03: The sustainability score shall be displayed with color gradient and leaf icon]
- [Source: epics.md - FR-SUS-04: Users shall see a percentile comparison: "Top X% of Vestiaire users"]
- [Source: epics.md - FR-SUS-05: An "Eco Warrior" badge shall unlock at sustainability score >= 80]
- [Source: architecture.md - Gated features include... advanced analytics]
- [Source: architecture.md - Epic 11 Advanced Analytics -> mobile/features/analytics, api/modules/analytics, api/modules/ai]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: 11-1-brand-value-analytics.md - BrandValueSection, conditional premium-only 7th API call, 1084 API tests, 1514 Flutter tests]
- [Source: 7-2-premium-feature-access-enforcement.md - premiumGuard utility, PremiumGateCard widget, premium gating matrix: "Advanced analytics: Premium-only"]
- [Source: 6-4-badge-achievement-system.md - badges table, user_badges table, evaluate_badges RPC, eco_warrior placeholder, badgeService.checkAndAward]
- [Source: 7-4-resale-status-history-tracking.md - resale_history table, items.resale_status CHECK constraint ('listed', 'sold', 'donated')]
- [Source: 5-4-basic-wardrobe-value-analytics.md - AnalyticsDashboardScreen, analytics-repository.js factory pattern, Future.wait parallel pattern]
- [Source: 5-7-ai-generated-analytics-summary.md - AiInsightsSection premium/free-teaser pattern, premium analytics endpoint pattern]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing 7 analytics methods (after Story 11.1)]
- [Source: apps/api/src/modules/billing/premium-guard.js - requirePremium(), checkPremium()]
- [Source: apps/api/src/modules/badges/badge-service.js - checkAndAward(authContext, badgeKey)]
- [Source: apps/mobile/lib/src/core/widgets/premium_gate_card.dart - PremiumGateCard widget]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed mock pool query ordering in analytics-repository.test.js to prevent sustainability query from matching wardrobeSummary pattern
- Fixed dashboard test scroll offset for brand-value category filter test (used scrollUntilVisible instead of fixed offset)

### Completion Notes List

- Implemented `getSustainabilityAnalytics` repository method with 5 weighted factor scores, composite score, CO2 savings, and percentile computation
- Added `GET /v1/analytics/sustainability` route with premium gating via `premiumGuard.requirePremium()` and eco_warrior badge trigger for scores >= 80
- Added `getSustainabilityAnalytics()` method to Flutter ApiClient
- Created `SustainabilitySection` widget with score ring (CustomPaint), factor breakdown, CO2 savings card, percentile badge, empty state, badge notification, and premium gate
- Integrated SustainabilitySection into AnalyticsDashboardScreen as 8th conditional premium API call
- All 1115 API tests pass (1084 baseline + 31 new: 24 repository + 7 endpoint)
- All 1533 Flutter tests pass (1514 baseline + 19 new: 14 widget + 5 dashboard integration)
- flutter analyze: 15 pre-existing issues, 0 new issues

### File List

**Modified API files:**
- `apps/api/src/modules/analytics/analytics-repository.js` (added `getSustainabilityAnalytics` method)
- `apps/api/src/main.js` (added `GET /v1/analytics/sustainability` route with premium guard and badge trigger)

**Modified API test files:**
- `apps/api/test/modules/analytics/analytics-repository.test.js` (added 24 sustainability repository tests)
- `apps/api/test/modules/analytics/analytics-endpoints.test.js` (added 7 sustainability endpoint tests)

**New mobile files:**
- `apps/mobile/lib/src/features/analytics/widgets/sustainability_section.dart` (SustainabilitySection widget)
- `apps/mobile/test/features/analytics/widgets/sustainability_section_test.dart` (14 widget tests)

**Modified mobile files:**
- `apps/mobile/lib/src/core/networking/api_client.dart` (added `getSustainabilityAnalytics` method)
- `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (added sustainability state, conditional 8th fetch, new sliver)
- `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (added 5 sustainability integration tests, updated mock, fixed scroll offset)

### Change Log

- 2026-03-19: Story 11.2 implementation complete - sustainability scoring, CO2 savings, Eco Warrior badge trigger, SustainabilitySection widget, 8th conditional API call for premium users
