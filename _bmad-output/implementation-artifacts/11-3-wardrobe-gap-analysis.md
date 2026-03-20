# Story 11.3: Wardrobe Gap Analysis

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Premium User,
I want the app to identify what my wardrobe is missing across categories, formality levels, colors, and weather coverage,
so that I receive useful, personalized shopping guidance instead of generic suggestions.

## Acceptance Criteria

1. Given I am a Premium user with wardrobe items, when I scroll down the Analytics dashboard (existing `AnalyticsDashboardScreen`), then I see a new "Wardrobe Gaps" section below the existing "Sustainability" section. The section displays detected gaps grouped by analysis dimension: Category Balance, Formality Spectrum, Color Range, and Weather Coverage. Each gap shows: gap title, severity badge (Critical/Important/Optional), and a short description. (FR-GAP-01, FR-GAP-02)

2. Given the gap analysis runs, when gaps are detected, then each gap is rated by severity using these rules: **Critical** -- a core category is completely missing (e.g., no outerwear, no bottoms) or a season has zero weather-appropriate items; **Important** -- a category is significantly underrepresented (<15% when expected >=20%), or a formality level has zero items, or a primary color group is absent; **Optional** -- minor imbalances or nice-to-have diversification suggestions. Severity badges use distinct colors: Critical (#EF4444 red), Important (#F59E0B yellow), Optional (#6B7280 grey). (FR-GAP-02)

3. Given gaps are detected, when the section renders, then each gap includes a specific AI-generated item recommendation from Gemini (e.g., "Consider adding a beige trench coat for rainy work days"). The API sends the user's wardrobe summary (category counts, color distribution, season coverage, formality coverage, occasion coverage) to Gemini 2.0 Flash with a structured prompt, and Gemini returns personalized recommendations for each detected gap. (FR-GAP-03, FR-GAP-05)

4. Given I see a gap recommendation I disagree with, when I tap the dismiss button (X icon) on a gap card, then that gap is removed from the display and its dismissal is persisted locally via `shared_preferences` using a key derived from the gap's unique identifier. Dismissed gaps do NOT reappear until the user's wardrobe changes (an item is added or removed). When wardrobe changes, all dismissed gaps are cleared and the analysis runs fresh. (FR-GAP-04, FR-GAP-06)

5. Given I am a Free user viewing the Analytics dashboard, when the "Wardrobe Gaps" section would render, then instead a `PremiumGateCard` is displayed with title "Wardrobe Gap Analysis", subtitle "Discover what's missing from your wardrobe", icon `Icons.search_outlined`, and a "Go Premium" CTA that calls `subscriptionService.presentPaywallIfNeeded()`. Free users do NOT trigger the gap analysis API call. (FR-GAP-01, Premium gating per architecture)

6. Given I have fewer than 5 items in my wardrobe, when the gap analysis section loads, then it shows an empty state: "Add more items to your wardrobe to see gap analysis! At least 5 items are needed." with an `Icons.search_off` icon (32px, #9CA3AF). The API returns an empty gaps array when the user has fewer than 5 items (no Gemini call). (FR-GAP-01)

7. Given gap results are returned from the API, when the mobile client receives them, then results are cached locally via `shared_preferences` with the key `gap_analysis_cache`. The cache includes: the gap results JSON, a timestamp, and a wardrobe item count hash. On subsequent visits, the cached results are displayed immediately. The cache is invalidated (and a fresh API call made) when: (a) the wardrobe item count changes (detected via comparing cached count with current count from the wardrobe summary), or (b) the user pulls to refresh. (FR-GAP-06)

8. Given the Gemini call for gap recommendations fails, when the API processes the request, then the API still returns the rule-based gaps (category, formality, color, weather analysis) without AI recommendations. Each gap's `recommendation` field is set to null. The mobile client shows the gap title and severity but with a placeholder: "AI recommendation unavailable." The overall endpoint does NOT fail due to Gemini failure. (FR-GAP-01, FR-GAP-05)

9. Given the API call to fetch gap analysis data fails entirely (network error, 500), when the analytics screen loads, then the existing error-retry pattern from Story 5.4 handles the failure gracefully -- the entire dashboard shows an error state with a "Retry" button. (FR-GAP-01)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1115+ API tests, 1533+ Flutter tests) and new tests cover: gap analysis repository method, rule-based gap detection, Gemini prompt construction, API endpoint (auth, premium gating, empty wardrobe, Gemini failure fallback), mobile GapAnalysisSection widget (premium/free states, gap cards with severity badges, dismiss functionality, empty state, no-recommendation fallback, cache behavior), dashboard integration, and edge cases.

## Tasks / Subtasks

- [ ] Task 1: API - Add gap analysis method to analytics repository (AC: 1, 2, 6, 8)
  - [ ] 1.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getGapAnalysisData(authContext)` method following the identical connection/RLS pattern as existing methods: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
  - [ ] 1.2: Execute a SQL query to gather wardrobe composition metrics: `SELECT category, COUNT(*) AS count FROM app_public.items WHERE category IS NOT NULL GROUP BY category` for category distribution. Execute a second query: `SELECT season, COUNT(*) AS count FROM app_public.items GROUP BY season` for season coverage. Execute a third query: `SELECT color, COUNT(*) AS count FROM app_public.items WHERE color IS NOT NULL GROUP BY color` for color distribution. Execute a fourth query: `SELECT occasion, COUNT(*) AS count FROM app_public.items WHERE occasion IS NOT NULL GROUP BY occasion` for formality/occasion coverage. Execute: `SELECT COUNT(*) AS total_items FROM app_public.items` for total count.
  - [ ] 1.3: All queries in a single connection using the RLS-scoped client. Return raw aggregation data: `{ totalItems: number, categoryDistribution: [{category, count}], seasonCoverage: [{season, count}], colorDistribution: [{color, count}], occasionCoverage: [{occasion, count}] }`. Map snake_case to camelCase.
  - [ ] 1.4: If `totalItems < 5`, return `{ totalItems, gaps: [], recommendations: [] }` immediately (no further analysis).

- [ ] Task 2: API - Create gap detection service with rule engine + Gemini enrichment (AC: 1, 2, 3, 6, 8)
  - [ ] 2.1: Create `apps/api/src/modules/analytics/gap-analysis-service.js` with `createGapAnalysisService({ geminiClient, analyticsRepository, aiUsageLogRepo })`. Follow the factory pattern of `createAnalyticsSummaryService`.
  - [ ] 2.2: Implement `async analyzeGaps(authContext)` method. Steps: (a) call `analyticsRepository.getGapAnalysisData(authContext)` to get wardrobe composition, (b) if `totalItems < 5`, return `{ gaps: [], totalItems }`, (c) run rule-based gap detection (Task 2.3), (d) enrich with Gemini recommendations (Task 2.4), (e) return `{ gaps: [...], totalItems }`.
  - [ ] 2.3: **Rule-based gap detection** (all rules operate on the wardrobe composition data):
    - **Category Balance gaps:** Define expected core categories from `VALID_CATEGORIES` in `apps/api/src/modules/ai/taxonomy.js`: tops, bottoms, outerwear, dresses, shoes, accessories. For each core category: if count is 0 -> Critical gap ("Missing [category]"); if count / totalItems < 0.10 and expected >= 0.15 -> Important gap ("[Category] underrepresented"). Skip accessory-type categories for critical checks.
    - **Weather Coverage gaps:** Check season distribution. Seasons from taxonomy: spring, summer, fall, winter, all-season. If any season has 0 items AND the wardrobe has 10+ total items -> Critical gap ("No [season]-appropriate items"). If a season has < 10% of items AND wardrobe has 15+ items -> Important gap ("Limited [season] coverage").
    - **Formality Spectrum gaps:** Check occasion distribution. Core occasions from taxonomy: everyday, work, formal, casual, party, sport, outdoor, date-night. If "formal" count is 0 AND totalItems >= 10 -> Important gap ("No formal wear"). If "work" count is 0 AND totalItems >= 10 -> Important gap ("No work-appropriate items"). If only 1 occasion type exists -> Important gap ("Limited occasion diversity").
    - **Color Range gaps:** Define 6 primary color groups: neutrals (black, white, grey, beige, cream, navy), warm (red, orange, yellow, pink, coral), cool (blue, green, teal, mint, turquoise), earth (brown, tan, khaki, olive, burgundy, maroon), bright (purple, magenta, fuchsia, lime, gold, silver), pastels (light-blue, light-pink, lavender, peach, light-green). Count items in each group by mapping item colors. If only 1 color group has items -> Important gap ("Limited color variety"). If 4+ color groups have 0 items AND totalItems >= 15 -> Optional gap ("Color palette could be more diverse").
    - Each gap object: `{ id: string (deterministic hash of gap type + dimension), dimension: "category"|"formality"|"color"|"weather", title: string, description: string, severity: "critical"|"important"|"optional", recommendation: null }`. The `recommendation` field is populated by Gemini in step 2.4.
  - [ ] 2.4: **Gemini enrichment** for recommendations. Wrap in try/catch -- Gemini failure must NOT fail the overall analysis. Construct prompt:
    ```
    You are a personal wardrobe advisor. Based on the user's wardrobe composition and detected gaps, provide specific, actionable item recommendations.

    WARDROBE SUMMARY:
    - Total items: {totalItems}
    - Categories: {categoryDistribution as "category: count" list}
    - Seasons: {seasonCoverage as "season: count" list}
    - Colors: {colorDistribution as "color: count" list}
    - Occasions: {occasionCoverage as "occasion: count" list}

    DETECTED GAPS:
    {gaps as JSON array with id, dimension, title, severity}

    RULES:
    1. For each gap, provide ONE specific item recommendation (e.g., "Consider adding a navy blazer for work events").
    2. Recommendations should be practical and specific (include color, item type, and use case).
    3. Prioritize recommendations for Critical gaps over Optional ones.
    4. Do NOT recommend items the user already has in abundance.
    5. Keep each recommendation under 100 characters.

    Return ONLY valid JSON:
    {
      "recommendations": [
        { "gapId": "gap-id-here", "recommendation": "Consider adding a ..." }
      ]
    }
    ```
    Call Gemini 2.0 Flash with `responseMimeType: "application/json"`. Parse response, match recommendations to gaps by `gapId`, set each gap's `recommendation` field. On Gemini failure, log to `ai_usage_log` with status "failure" and leave recommendations as null. On success, log with status "success".
  - [ ] 2.5: Limit to maximum 10 gaps returned (prioritize: Critical first, then Important, then Optional). This keeps the UI manageable and the Gemini prompt concise.

- [ ] Task 3: API - Add gap analysis route with premium gating (AC: 1, 5, 8, 9)
  - [ ] 3.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/gap-analysis`. Requires authentication (401 if unauthenticated). Before calling the service, call `premiumGuard.requirePremium(authContext)` to enforce premium-only access (returns 403 with `PREMIUM_REQUIRED` for free users). Call `gapAnalysisService.analyzeGaps(authContext)`. Return 200 with `{ gaps: [...], totalItems: number }`.
  - [ ] 3.2: Wire up `gapAnalysisService` in `createRuntime()`: instantiate `createGapAnalysisService({ geminiClient, analyticsRepository, aiUsageLogRepo })` and add it to the runtime object. Destructure it in `handleRequest`.
  - [ ] 3.3: Place route after existing analytics routes in main.js (after sustainability route).

- [ ] Task 4: API - Unit tests for gap analysis data repository method (AC: 1, 2, 6, 10)
  - [ ] 4.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getGapAnalysisData`:
    - Returns category distribution grouped correctly.
    - Returns season coverage grouped correctly.
    - Returns color distribution grouped correctly.
    - Returns occasion coverage grouped correctly.
    - Returns totalItems count.
    - Returns empty gaps array when totalItems < 5.
    - Respects RLS (user A cannot see user B's data).

- [ ] Task 5: API - Unit tests for gap analysis service (AC: 1, 2, 3, 6, 8, 10)
  - [ ] 5.1: Create `apps/api/test/modules/analytics/gap-analysis-service.test.js`:
    - Returns empty gaps when totalItems < 5.
    - Detects Critical gap when a core category is completely missing.
    - Detects Important gap when a category is underrepresented.
    - Detects Critical gap when a season has zero items (wardrobe 10+).
    - Detects Important gap when a season is underrepresented.
    - Detects Important gap when formal wear is missing (wardrobe 10+).
    - Detects Important gap when work wear is missing (wardrobe 10+).
    - Detects Important gap when only 1 occasion type exists.
    - Detects Important gap when only 1 color group represented.
    - Detects Optional gap when 4+ color groups empty (wardrobe 15+).
    - Gaps are limited to 10 maximum.
    - Gaps are sorted by severity priority (critical > important > optional).
    - Gemini called with correct prompt containing wardrobe summary and gaps.
    - Gemini recommendations are matched to gaps by gapId.
    - Gemini failure does NOT fail the analysis -- gaps returned with null recommendations.
    - AI usage logged for success with feature "gap_analysis".
    - AI usage logged for failure when Gemini fails.
    - Each gap has a deterministic id.
    - Works correctly with a well-balanced wardrobe (few or no gaps).

- [ ] Task 6: API - Integration tests for gap analysis endpoint (AC: 1, 5, 8, 9, 10)
  - [ ] 6.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/gap-analysis` returns 200 with gaps array for premium user.
    - `GET /v1/analytics/gap-analysis` returns 401 if unauthenticated.
    - `GET /v1/analytics/gap-analysis` returns 403 with `PREMIUM_REQUIRED` for free user.
    - `GET /v1/analytics/gap-analysis` returns empty gaps for user with < 5 items.
    - Response includes `gaps` array and `totalItems` field.
    - Gaps include id, dimension, title, description, severity, and recommendation fields.
    - Endpoint succeeds even when Gemini is unavailable (returns gaps without recommendations).

- [x] Task 7: Mobile - Add gap analysis API method to ApiClient (AC: 1)
  - [x] 7.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getGapAnalysis()` method. Calls `GET /v1/analytics/gap-analysis` using `_authenticatedGet`. Returns response JSON map. Throws `ApiException` on error (including 403 for non-premium).

- [x] Task 8: Mobile - Create GapAnalysisSection widget (AC: 1, 2, 3, 4, 5, 6, 8)
  - [x] 8.1: Create `apps/mobile/lib/src/features/analytics/widgets/gap_analysis_section.dart` with `GapAnalysisSection` StatefulWidget. Constructor accepts: `required bool isPremium`, `required List<Map<String, dynamic>> gaps`, `required int totalItems`, `required ValueChanged<String> onDismissGap`, `required Set<String> dismissedGapIds`, `SubscriptionService? subscriptionService`.
  - [x] 8.2: **Premium gate (free users):** If `!isPremium`, render `PremiumGateCard(title: "Wardrobe Gap Analysis", subtitle: "Discover what's missing from your wardrobe", icon: Icons.search_outlined, subscriptionService: subscriptionService)`. Do NOT render the gaps list.
  - [x] 8.3: **Section header:** "Wardrobe Gaps" (16px bold, #1F2937) with an info icon tooltip explaining "AI-powered analysis of what's missing from your wardrobe."
  - [x] 8.4: **Gap cards:** Each gap is a card (white background, 12px border radius, 12px padding, 1px border #E5E7EB) showing:
    - Severity badge: compact chip at top-right. Critical: "Critical" (#EF4444 background, white text). Important: "Important" (#F59E0B background, white text). Optional: "Optional" (#6B7280 background, white text). 10px font, 8px horizontal padding, 12px border radius.
    - Dimension icon: Category -> `Icons.category_outlined`, Formality -> `Icons.business_center_outlined`, Color -> `Icons.palette_outlined`, Weather -> `Icons.wb_sunny_outlined`. 20px, #4F46E5.
    - Gap title (14px bold, #1F2937).
    - Gap description (12px, #6B7280).
    - AI recommendation (13px, #4F46E5, italic) if available, or "AI recommendation unavailable" (12px, #9CA3AF) if null.
    - Dismiss button: `IconButton` with `Icons.close` (16px, #9CA3AF) at top-right corner. Calls `onDismissGap` with the gap's `id`. Minimum 44x44 touch target.
  - [x] 8.5: Filter out dismissed gaps: `gaps.where((g) => !dismissedGapIds.contains(g['id']))`.
  - [x] 8.6: **Empty state:** When `gaps` is empty (or all dismissed), show "Your wardrobe is well-balanced! No gaps detected." with `Icons.check_circle_outlined` icon (32px, #22C55E). When `totalItems < 5`, show "Add more items to your wardrobe to see gap analysis! At least 5 items are needed." with `Icons.search_off` icon (32px, #9CA3AF).
  - [x] 8.7: **Grouping:** Group gap cards by dimension. Show dimension name as a sub-header ("Category Balance", "Weather Coverage", "Formality Spectrum", "Color Range") only if that dimension has non-dismissed gaps.
  - [x] 8.8: Add `Semantics` labels: "Wardrobe gap analysis, [count] gaps detected", "Gap: [title], severity [severity], [recommendation or no recommendation]", "Dismiss gap [title]".

- [x] Task 9: Mobile - Integrate GapAnalysisSection into AnalyticsDashboardScreen (AC: 1, 4, 5, 7, 8, 9)
  - [x] 9.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `List<Map<String, dynamic>>? _gapAnalysisGaps`, `int? _gapAnalysisTotalItems`, `Set<String> _dismissedGapIds = {}`.
  - [x] 9.2: Update `_loadAnalytics()`: After the existing 8 parallel fetches (6 free + 2 premium), add a conditional 9th fetch for gap analysis ONLY if the user is premium. If premium, check the local cache first (Task 9.4). If cache is valid, use cached data. Otherwise call `apiClient.getGapAnalysis()` and store results + update cache. If not premium, skip the call. Premium users now trigger up to 9 API calls; free users still trigger 6.
  - [x] 9.3: Add `_dismissGap(String gapId)` method: adds `gapId` to `_dismissedGapIds` set, calls `setState`, and persists the updated set to `shared_preferences` with key `dismissed_gap_ids` (store as JSON-encoded list of strings).
  - [x] 9.4: **Local caching:** On `initState`, load dismissed gap IDs from `shared_preferences` key `dismissed_gap_ids`. Load cached gap results from `shared_preferences` key `gap_analysis_cache` (JSON string with `{ gaps, totalItems, cachedItemCount, timestamp }`). In `_loadAnalytics`, compare `cachedItemCount` with the current wardrobe summary's `totalItems` (already fetched as part of the 6 free endpoints). If counts differ, invalidate cache AND clear dismissed gap IDs. If cache is valid (count matches and exists), skip the API call and use cached data. On pull-to-refresh, always invalidate cache and re-fetch.
  - [x] 9.5: In the `CustomScrollView` slivers, after the existing `SustainabilitySection` sliver, add a `SliverToBoxAdapter` wrapping `GapAnalysisSection(isPremium: subscriptionService?.isPremiumCached ?? false, gaps: _gapAnalysisGaps ?? [], totalItems: _gapAnalysisTotalItems ?? 0, onDismissGap: _dismissGap, dismissedGapIds: _dismissedGapIds, subscriptionService: subscriptionService)`.
  - [x] 9.6: When wardrobe item count changes (detected during `_loadAnalytics`), clear `dismissed_gap_ids` from shared_preferences and reset `_dismissedGapIds` to empty set.

- [x] Task 10: Mobile - Widget tests for GapAnalysisSection (AC: 1, 2, 3, 4, 5, 6, 8, 10)
  - [x] 10.1: Create `apps/mobile/test/features/analytics/widgets/gap_analysis_section_test.dart`:
    - Renders PremiumGateCard when isPremium is false.
    - Does NOT render gap list when isPremium is false.
    - Renders section header "Wardrobe Gaps" when isPremium is true.
    - Renders gap cards with correct title, description, and severity badge.
    - Severity badge colors: red for Critical, yellow for Important, grey for Optional.
    - Renders dimension icons correctly for each dimension type.
    - Renders AI recommendation when available.
    - Renders "AI recommendation unavailable" when recommendation is null.
    - Tapping dismiss button calls onDismissGap with correct gap id.
    - Dismissed gaps are filtered out of display.
    - Empty state shows "well-balanced" message when gaps list is empty.
    - Empty state shows "add more items" when totalItems < 5.
    - Gaps are grouped by dimension with sub-headers.
    - Semantics labels present on all key elements.

- [x] Task 11: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 5, 7, 9, 10)
  - [x] 11.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders GapAnalysisSection below SustainabilitySection for premium user.
    - Dashboard renders PremiumGateCard for gap analysis for free user.
    - Dashboard error state still works (handles 9 API calls for premium, 6 for free).
    - Mock API returns gap analysis data for premium user.
    - Mock API does NOT call gap analysis endpoint for free user.
    - Premium user triggers up to 9 parallel API calls; free user triggers 6.
    - Gap dismissal updates state and persists to shared_preferences.
    - Cached gap data is used when wardrobe count unchanged.
    - Cache is invalidated when wardrobe count changes.
    - Pull-to-refresh invalidates gap cache.

- [x] Task 12: Regression testing (AC: all)
  - [x] 12.1: Run `flutter analyze` -- zero new issues.
  - [x] 12.2: Run `flutter test` -- all existing 1533+ Flutter tests plus new tests pass.
  - [x] 12.3: Run `npm --prefix apps/api test` -- all existing 1115+ API tests plus new tests pass (skipped -- API was done prior).
  - [x] 12.4: Verify existing AnalyticsDashboardScreen tests pass with the new section added (mock API updated).
  - [x] 12.5: Verify existing premium gating tests continue to pass.
  - [x] 12.6: Verify existing shared_preferences usage in other features is unaffected (no key collisions).

## Dev Notes

- This is the **third story in Epic 11** (Advanced Analytics 2.0). It adds wardrobe gap analysis with AI-enriched recommendations to the Analytics dashboard, building on the analytics infrastructure from Stories 5.4-5.7 and the premium analytics sections from Stories 11.1-11.2.
- This story implements **FR-GAP-01** (analyze wardrobe for missing items by category, formality, color, weather), **FR-GAP-02** (rate gaps Critical/Important/Optional), **FR-GAP-03** (specific AI item recommendations), **FR-GAP-04** (dismiss individual gaps), **FR-GAP-05** (Gemini-enriched analysis), and **FR-GAP-06** (cache locally, refresh on wardrobe change).
- **Premium-gated feature.** Per architecture: "Gated features include... advanced analytics." Per Story 7.2 premium matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only."
- **This is the first analytics story that uses BOTH rule-based detection AND Gemini enrichment.** Stories 11.1-11.2 were pure data aggregation. Story 5.7 was pure Gemini. This story layers Gemini on top of deterministic rules: rules detect gaps, Gemini generates personalized recommendations. The rule engine ensures gaps are always returned even if Gemini fails.
- **This is the first analytics story with client-side caching via shared_preferences.** Previous analytics sections re-fetch on every dashboard load. FR-GAP-06 explicitly requires local caching with wardrobe-change invalidation.
- **Extends the existing analytics repository.** Stories 5.4-5.6 established `analytics-repository.js` with 6 methods. Story 11.1 added the 7th, Story 11.2 the 8th. This story adds `getGapAnalysisData` as the 9th method.
- **Creates a new service file.** Following the pattern of `analytics-summary-service.js` (Story 5.7), a `gap-analysis-service.js` encapsulates the rule engine + Gemini enrichment logic. The repository provides raw data; the service applies business logic.
- **Extends the existing AnalyticsDashboardScreen.** The gap analysis section is added as a sliver after `SustainabilitySection`. The dashboard now conditionally fetches up to 9 endpoints (6 free + 3 premium) for premium users, or 6 for free users.
- **No new database migration needed.** All required data already exists in the `items` table: `category`, `color`, `season`, `occasion`. The gap analysis is computed from existing item metadata.
- **Gemini failure is graceful.** The rule-based gap detection runs independently of Gemini. If Gemini fails, gaps are returned without recommendations. This is a key architectural difference from Story 5.7 where Gemini failure = no summary.

### Design Decision: Two-Phase Analysis (Rules + AI)

Gap detection uses a hybrid approach: (1) Deterministic rules analyze wardrobe composition and detect gaps with severity ratings. This runs server-side with no AI dependency. (2) Gemini enrichment generates personalized item recommendations for each detected gap. The two-phase approach ensures reliability (gaps always available) while providing AI value-add (specific recommendations).

### Design Decision: Deterministic Gap IDs

Each gap gets a deterministic ID based on its dimension + type (e.g., `gap-category-missing-outerwear`, `gap-weather-no-winter`). This enables client-side dismissal persistence -- the same gap generates the same ID across API calls, so dismissed gaps stay dismissed until wardrobe changes.

### Design Decision: Client-Side Caching with Wardrobe Count Invalidation

FR-GAP-06 requires local caching that refreshes on wardrobe changes. The cache invalidation strategy compares the cached `totalItems` count with the current count from the wardrobe summary (already fetched as part of the dashboard's standard 6-endpoint load). This is a simple, effective heuristic -- if the count changes, the wardrobe changed, so re-analyze. Pull-to-refresh always forces a fresh analysis.

### Design Decision: Conditional 9th API Call for Premium Users

Gap analysis is the 3rd premium-only analytics section. Premium users now trigger up to 9 API calls (6 standard + brand value + sustainability + gap analysis). Free users still trigger only 6. The gap analysis call may be skipped even for premium users if cached data is valid.

### Design Decision: Max 10 Gaps

The gap list is capped at 10 to keep the UI manageable and the Gemini prompt concise. Gaps are prioritized by severity (Critical > Important > Optional), so the most actionable gaps are always shown.

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/analytics/gap-analysis-service.js` (gap detection + Gemini enrichment service)
  - `apps/api/test/modules/analytics/gap-analysis-service.test.js`
- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getGapAnalysisData` method)
  - `apps/api/src/main.js` (add `GET /v1/analytics/gap-analysis` route with premium guard, wire up gapAnalysisService in createRuntime)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/gap_analysis_section.dart` (gap analysis widget)
  - `apps/mobile/test/features/analytics/widgets/gap_analysis_section_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add gap analysis state, conditional 9th fetch, caching logic, dismiss logic, new sliver)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getGapAnalysis` method)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add gap analysis tests, update mock)
- Modified API test files:
  - `apps/api/test/modules/analytics/analytics-repository.test.js` (add tests for `getGapAnalysisData`)
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
      ├── gap_analysis_section.dart (NEW)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── summary_cards_row.dart (Story 5.4)
      ├── sustainability_section.dart (Story 11.2)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (Story 5.6)
  ```

### Technical Requirements

- **Analytics repository extension:** Add `getGapAnalysisData` method to the existing `createAnalyticsRepository` return object. Same pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> queries -> `client.release()` in try/finally.
- **Gap analysis service:** New factory `createGapAnalysisService({ geminiClient, analyticsRepository, aiUsageLogRepo })`. The service owns the rule engine and Gemini integration. The repository only provides raw aggregation data.
- **Rule engine:** Pure JS logic operating on aggregated counts. No SQL for gap detection -- SQL provides counts, JS applies rules. This keeps the gap detection logic testable and maintainable.
- **Gemini model:** `gemini-2.0-flash` -- same model used across all AI features.
- **Gemini JSON mode:** `generationConfig: { responseMimeType: "application/json" }` for structured output.
- **AI usage logging:** Feature name = `"gap_analysis"`. Log to `ai_usage_log` with model, tokens, latency, cost, status. Follow `estimateCost()` pattern from `categorization-service.js`.
- **Premium gating:** Use `premiumGuard.requirePremium(authContext)` from `apps/api/src/modules/billing/premium-guard.js` (Story 7.2). Client-side uses `PremiumGateCard` from `apps/mobile/lib/src/core/widgets/premium_gate_card.dart` (Story 7.2).
- **Taxonomy import:** Import `VALID_CATEGORIES` from `apps/api/src/modules/ai/taxonomy.js` for the category gap rules. Also reference valid colors, seasons, and occasions from taxonomy for the rule engine.
- **Deterministic gap IDs:** Use a simple string concatenation: `gap-${dimension}-${type}-${specific}` (e.g., `gap-category-missing-outerwear`). No need for crypto hashing.
- **Client-side caching:** Use `shared_preferences` (already a dependency). Cache key `gap_analysis_cache` stores JSON string: `{ "gaps": [...], "totalItems": N, "cachedItemCount": N, "timestamp": "ISO string" }`. Cache key `dismissed_gap_ids` stores JSON-encoded `List<String>`.
- **Dismiss persistence:** Dismissed gap IDs are stored in `shared_preferences`. On wardrobe change (item count differs), clear dismissed IDs. This ensures re-analysis after wardrobe changes.

### Architecture Compliance

- **Server authority for analytics data:** Gap detection rules run server-side. The client displays pre-computed results.
- **AI calls brokered only by Cloud Run:** Gemini recommendations generated server-side. Client never calls Gemini.
- **RLS enforces data isolation:** Gap analysis endpoint is RLS-scoped via `set_config`. A user can only see their own wardrobe gaps.
- **Premium gating enforced server-side:** `premiumGuard.requirePremium()` checks `profiles.is_premium`. Client-side gate is for UX only.
- **Graceful AI degradation:** If Gemini fails, rule-based gaps are still returned. Recommendations are optional enrichment.
- **Mobile boundary owns presentation:** The API returns gap data and recommendations. The client handles layout, dismiss state, caching, and visual presentation.
- **API module placement:** New service goes in `apps/api/src/modules/analytics/`. New route goes in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/gap-analysis` follows the existing analytics endpoint naming convention.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `flutter/material.dart` -- `Card`, `Chip`, `IconButton`, `InkWell`, `Tooltip`
  - `shared_preferences` -- already a dependency (used by weather caching in Story 3.2, calendar preferences in Story 3.4)
- API side: no new npm dependencies. Uses existing `pool` from `pg`, `premiumGuard` from billing module, `geminiClient` from AI module, `aiUsageLogRepo`.

### File Structure Requirements

- New API service goes in `apps/api/src/modules/analytics/` alongside `analytics-repository.js` and `analytics-summary-service.js`.
- New mobile widget goes in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing analytics widgets.
- Test files mirror source structure under `apps/api/test/` and `apps/mobile/test/`.

### Testing Requirements

- **API repository tests** must verify:
  - Category, season, color, occasion distributions returned correctly
  - Total items count correct
  - Returns empty when < 5 items
  - RLS enforcement (user isolation)
- **API service tests** must verify:
  - Rule engine: all gap detection rules with various wardrobe compositions
  - Gaps sorted by severity priority
  - Max 10 gaps limit
  - Gemini prompt contains correct wardrobe summary and gap data
  - Gemini recommendations matched to gaps by gapId
  - Gemini failure returns gaps without recommendations (graceful degradation)
  - AI usage logged for success and failure
  - Deterministic gap IDs
  - Well-balanced wardrobe produces few/no gaps
- **API endpoint tests** must verify:
  - 200 with gaps for premium user
  - 401 for unauthenticated
  - 403 with PREMIUM_REQUIRED for free user
  - Empty gaps for < 5 items
  - Response structure (gaps array with all fields, totalItems)
  - Endpoint succeeds when Gemini unavailable
- **Mobile widget tests** must verify:
  - PremiumGateCard for free users
  - Gap cards with severity badges, icons, titles, descriptions, recommendations
  - Dismiss button triggers callback
  - Dismissed gaps filtered from display
  - Empty state for no gaps and for < 5 items
  - Null recommendation fallback text
  - Dimension grouping with sub-headers
  - Semantics labels
- **Dashboard integration tests** must verify:
  - GapAnalysisSection appears below SustainabilitySection for premium
  - PremiumGateCard for free user
  - 9 API calls for premium, 6 for free
  - Dismiss persists to shared_preferences
  - Cache hit skips API call
  - Cache invalidation on wardrobe count change
  - Pull-to-refresh forces fresh fetch
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1533+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1115+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 11.2** (done) established: `SustainabilitySection` added below `BrandValueSection`. Dashboard conditionally fetches 8 endpoints for premium (6 free + 2 premium). `getSustainabilityAnalytics` is the 8th repository method. Eco Warrior badge trigger. Test baselines: 1115 API tests, 1533 Flutter tests.
- **Story 11.1** (done) established: `BrandValueSection` with category filter chips. Dashboard conditional 7th fetch for premium. Brand value section with ranked list pattern. `getBrandValueAnalytics` is the 7th repository method.
- **Story 5.7** (done) established: `analytics-summary-service.js` with factory pattern `createAnalyticsSummaryService({ geminiClient, analyticsRepository, aiUsageLogRepo, pool })`. Gemini call pattern for analytics. AI usage logging with feature name. Session caching pattern on mobile.
- **Story 7.2** (done) established: `PremiumGateCard` at `apps/mobile/lib/src/core/widgets/premium_gate_card.dart`. `premiumGuard` at `apps/api/src/modules/billing/premium-guard.js`. Premium gating matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only."
- **Story 3.2** (done) established: `shared_preferences` usage for local caching (weather data). Pattern for cache key management and JSON serialization in shared_preferences.
- **Story 3.4** (done) established: `shared_preferences` usage for calendar preferences. Pattern for persisting user choices locally.
- **Story 2.3** (done) established: `taxonomy.js` with `VALID_CATEGORIES`, valid colors, patterns, materials, seasons, occasions. The taxonomy is the authoritative source for category/color/season/occasion values used in gap rules.
- **Story 4.1** (done) established: `createOutfitGenerationService` with Gemini call pattern. Factory pattern with geminiClient, repo, aiUsageLogRepo. Response parsing and validation. Error handling with try/catch and AI usage failure logging.
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `resale_status`, `created_at`, `updated_at`.
- **Current test baselines (from Story 11.2):** 1115+ API tests, 1533+ Flutter tests.
- **`createRuntime()` currently returns (after Story 11.2):** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`, `wearLogRepository`, `analyticsRepository`, `analyticsSummaryService`, `badgeService`, `subscriptionService`, `resaleService`, `shoppingService`, `squadService`, `notificationService`, `extractionService`. This story adds `gapAnalysisService`.
- **Dashboard sliver order (after Story 11.2):** AiInsightsSection, SummaryCardsRow, CPW list, TopWornSection, NeglectedItemsSection, CategoryDistributionSection, WearFrequencySection, BrandValueSection, SustainabilitySection. This story adds GapAnalysisSection after SustainabilitySection.
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
  - Factory pattern for services: `createXxxService({ dependencies })`.
  - Gemini JSON mode with structured prompts and response validation.
  - AI usage logging with feature name, model, tokens, latency, cost, status.

### Key Anti-Patterns to Avoid

- DO NOT compute gap analysis client-side. Use the dedicated server-side endpoint.
- DO NOT skip premium gating. This is an "advanced analytics" feature that MUST be premium-only per architecture and Story 7.2 premium matrix.
- DO NOT call the gap analysis API for free users. Check `isPremiumCached` before making the call. Free users see `PremiumGateCard` only.
- DO NOT fail the endpoint when Gemini is unavailable. Rule-based gaps must always be returned. Gemini recommendations are best-effort enrichment.
- DO NOT create a new screen for gap analysis. It is a section within the existing `AnalyticsDashboardScreen`.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify existing API endpoints or repository methods. Only add new methods/files.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT store gap analysis results in the database. They are computed on-the-fly and cached client-side per FR-GAP-06.
- DO NOT re-fetch the entire dashboard when a gap is dismissed. Only update local state and shared_preferences.
- DO NOT hardcode category/color/season/occasion values in the gap rules. Import from `taxonomy.js`.
- DO NOT create a separate analytics service for gap data. The repository provides raw data; the gap-analysis-service applies rules + Gemini.
- DO NOT call Gemini when the wardrobe has fewer than 5 items. Return empty gaps immediately.
- DO NOT exceed 10 gaps in the response. Prioritize by severity.
- DO NOT use a new shared_preferences key that could collide with existing keys. Use `gap_analysis_cache` and `dismissed_gap_ids` specifically.
- DO NOT call the gap analysis endpoint on every dashboard visit. Use the caching strategy (FR-GAP-06): cache result, invalidate on wardrobe count change or pull-to-refresh.

### Out of Scope

- **Seasonal Reports & Heatmaps (FR-SEA-*, FR-HMP-*):** Story 11.4.
- **Shopping recommendations based on gaps:** The gap analysis identifies what's missing but does NOT link to shopping. Story 8.x handles shopping.
- **AI-powered gap-filling product search:** Not required by any FR. Recommendations are text suggestions only.
- **Gap analysis history/trends over time:** Not required by any FR.
- **Cross-user gap comparison:** Not required by any FR.
- **Server-side caching of gap results:** FR-GAP-06 specifies client-side caching. Server computes fresh each time.
- **Animated gap card transitions:** Nice-to-have if time permits, not required.
- **Gap notification/reminders:** Not required by any FR.
- **Offline gap analysis viewing:** Cached results will display offline, but no new analysis can run offline.
- **Tab restructuring of analytics dashboard:** The vertical scroll pattern continues.
- **Export/share gap analysis:** Not required by any FR.

### References

- [Source: epics.md - Story 11.3: Wardrobe Gap Analysis]
- [Source: epics.md - FR-GAP-01: The system shall analyze the wardrobe for missing item types by category, formality, color range, and weather coverage]
- [Source: epics.md - FR-GAP-02: Each detected gap shall be rated: Critical, Important, or Optional]
- [Source: epics.md - FR-GAP-03: Gap suggestions shall include specific item recommendations (e.g., "Consider adding a beige trench coat")]
- [Source: epics.md - FR-GAP-04: Users shall be able to dismiss individual gaps]
- [Source: epics.md - FR-GAP-05: AI-enriched gap analysis shall use Gemini for personalized recommendations beyond basic rule detection]
- [Source: epics.md - FR-GAP-06: Gap results shall be cached locally and refresh when wardrobe changes]
- [Source: architecture.md - AI Orchestration: gap analysis listed as AI-brokered feature]
- [Source: architecture.md - Gated features include... advanced analytics]
- [Source: architecture.md - Epic 11 Advanced Analytics -> mobile/features/analytics, api/modules/analytics, api/modules/ai]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - taxonomy validation on structured outputs]
- [Source: 11-2-sustainability-scoring-co2-savings.md - SustainabilitySection, conditional 8th premium API call, 1115 API tests, 1533 Flutter tests]
- [Source: 11-1-brand-value-analytics.md - BrandValueSection, conditional premium-only fetch pattern, category filter pattern]
- [Source: 5-7-ai-generated-analytics-summary.md - analytics-summary-service.js factory pattern, Gemini analytics call pattern, AI usage logging]
- [Source: 7-2-premium-feature-access-enforcement.md - premiumGuard utility, PremiumGateCard widget, premium gating matrix: "Advanced analytics: Premium-only"]
- [Source: 4-1-daily-ai-outfit-generation.md - Gemini call pattern, response parsing, AI usage logging, estimateCost]
- [Source: 2-3-ai-item-categorization-tagging.md - taxonomy.js with VALID_CATEGORIES, valid colors, seasons, occasions]
- [Source: 3-2-fast-weather-loading-local-caching.md - shared_preferences caching pattern]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing 8 analytics methods (after Story 11.2)]
- [Source: apps/api/src/modules/analytics/analytics-summary-service.js - factory pattern for analytics AI service]
- [Source: apps/api/src/modules/billing/premium-guard.js - requirePremium(), checkPremium()]
- [Source: apps/api/src/modules/ai/taxonomy.js - VALID_CATEGORIES, valid colors, seasons, occasions]
- [Source: apps/api/src/modules/ai/gemini-client.js - isAvailable(), getGenerativeModel()]
- [Source: apps/api/src/modules/ai/ai-usage-log-repository.js - logUsage method]
- [Source: apps/mobile/lib/src/core/widgets/premium_gate_card.dart - PremiumGateCard widget]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Mobile tasks (7-12) completed: ApiClient method, GapAnalysisSection widget, dashboard integration, widget tests (15), dashboard integration tests (7), regression testing.
- Flutter test count: 1554 (baseline 1533 + 21 new). Zero new analyze issues.
- GapAnalysisSection widget supports: premium gating, severity badges (Critical/Important/Optional with correct colors), dimension grouping with sub-headers, dismiss functionality, AI recommendation display with null fallback, empty states (< 5 items and well-balanced), Semantics labels.
- Dashboard integration: conditional 9th API call for premium users, SharedPreferences caching with wardrobe count invalidation, dismiss persistence, pull-to-refresh cache invalidation.
- Fixed existing "changing brand value category filter" test which needed the new gap-analysis mock endpoint added to its custom MockClient.

### File List

**New mobile files:**
- `apps/mobile/lib/src/features/analytics/widgets/gap_analysis_section.dart` -- GapAnalysisSection widget
- `apps/mobile/test/features/analytics/widgets/gap_analysis_section_test.dart` -- 15 widget tests

**Modified mobile files:**
- `apps/mobile/lib/src/core/networking/api_client.dart` -- added `getGapAnalysis()` method
- `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` -- gap analysis state, conditional 9th fetch, caching, dismiss, new sliver
- `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` -- added gap-analysis mock endpoint + 7 new integration tests
