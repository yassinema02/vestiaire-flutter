# Story 5.7: AI-Generated Analytics Summary

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Premium User,
I want a simple, human-readable AI-generated summary of my wardrobe analytics,
so that I can grasp the key takeaways without analyzing the raw numbers myself.

## Acceptance Criteria

1. Given I am a Premium user (`profiles.is_premium = true`) viewing the Analytics dashboard, when the dashboard has loaded all underlying metrics (summary, CPW, top-worn, neglected, category distribution, wear frequency), then a new "AI Insights" section appears at the TOP of the `AnalyticsDashboardScreen` (above the existing `SummaryCardsRow`). The section displays a Gemini-generated short summary (2-4 sentences) that highlights a key positive wardrobe habit and one constructive suggestion. The summary has a subtle "AI-generated" indicator. (FR-ANA-06)

2. Given I am a Free user (`profiles.is_premium = false`) viewing the Analytics dashboard, when the dashboard loads, then the "AI Insights" section shows a locked/teaser state: a blurred or placeholder card with text "Unlock AI Wardrobe Insights" and a "Go Premium" CTA button. The CTA button is non-functional in this story (no purchase flow until Story 7.1). Free users do NOT trigger the AI summary API call. (FR-ANA-06, FR-OUT-10)

3. Given I am a Premium user and the AI summary API call succeeds, when the "AI Insights" section renders, then the summary text is displayed in a styled card (white background, 16px border radius, subtle shadow) with an icon (e.g., `Icons.auto_awesome`), the summary text (14px, #1F2937), and a small "Powered by AI" label (11px, #9CA3AF). The summary references specific numbers from the user's analytics (e.g., "Your average cost-per-wear of £4.20 is excellent"). (FR-ANA-06)

4. Given the API receives a request for AI analytics summary, when it processes the request, then it: (a) verifies the user is premium (returns 403 if not), (b) fetches all 6 analytics datasets server-side (summary, items CPW, top-worn, neglected, category distribution, wear frequency) using existing repository methods, (c) constructs a Gemini prompt with the aggregated analytics data, (d) calls Gemini 2.0 Flash with `responseMimeType: "application/json"`, (e) parses and validates the response, (f) logs usage to `ai_usage_log` with `feature = "analytics_summary"`, (g) returns the summary text. (FR-ANA-06)

5. Given the Gemini call fails (network error, rate limit, timeout, unparseable response), when the API handles the error, then it returns HTTP 500 with `{ error: "Analytics summary generation failed", code: "SUMMARY_GENERATION_FAILED" }`, logs the failure to `ai_usage_log` with status "failure", and the mobile client shows the "AI Insights" section with a fallback message: "Unable to generate insights right now. Pull to refresh to try again." with a retry button. (FR-ANA-06)

6. Given I am a Premium user and I have no items in my wardrobe, when the AI summary is requested, then the API returns a generic encouraging message without calling Gemini: `{ summary: "Start adding items to your wardrobe to get personalized AI insights about your style and spending habits!", isGeneric: true }`. This avoids wasting an AI call on empty data. (FR-ANA-06)

7. Given the "AI Insights" section is displayed with a summary, when I view it, then the summary is cached client-side for the duration of the session. Navigating away from and back to the Analytics dashboard does NOT trigger a new AI call. Pull-to-refresh DOES trigger a new AI call (refreshing the summary along with all other analytics data). (FR-ANA-06)

8. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (419+ API tests, 922+ Flutter tests) and new tests cover: analytics summary API endpoint (success, failure, premium check, empty wardrobe), Gemini prompt construction with analytics data, response parsing, AI usage logging, mobile AiInsightsSection widget (premium, free-teaser, loading, error states), HomeScreen/Dashboard integration, and premium status checking.

## Tasks / Subtasks

- [x] Task 1: API - Create analytics summary service (AC: 1, 4, 5, 6)
  - [x] 1.1: Create `apps/api/src/modules/analytics/analytics-summary-service.js` with `createAnalyticsSummaryService({ geminiClient, analyticsRepository, aiUsageLogRepo, pool })`. Follow the factory pattern of `createOutfitGenerationService`.
  - [x] 1.2: Implement `async generateSummary(authContext)` method. Steps: (a) check `geminiClient.isAvailable()` -- if false, throw `{ statusCode: 503, message: "AI service unavailable" }`, (b) look up `profile_id` and `is_premium` from `profiles` where `firebase_uid = authContext.userId`, (c) if not premium, throw `{ statusCode: 403, message: "Premium subscription required" }`, (d) fetch all 6 analytics datasets using existing repository methods: `getWardrobeSummary(authContext)`, `getItemsWithCpw(authContext)`, `getTopWornItems(authContext)`, `getNeglectedItems(authContext)`, `getCategoryDistribution(authContext)`, `getWearFrequency(authContext)` -- in parallel via `Promise.all`, (e) if `wardrobeSummary.totalItems === 0`, return the generic message without calling Gemini: `{ summary: "Start adding items to your wardrobe to get personalized AI insights about your style and spending habits!", isGeneric: true }`, (f) build the Gemini prompt (Task 1.3), (g) call Gemini, (h) parse and validate, (i) log usage, (j) return `{ summary: <text>, isGeneric: false }`.
  - [x] 1.3: Construct the Gemini prompt:
    ```
    You are a friendly wardrobe analytics advisor. Generate a short, encouraging summary (2-4 sentences) of this user's wardrobe analytics.

    ANALYTICS DATA:
    - Total items: {totalItems}
    - Wardrobe value: {currency}{totalValue}
    - Average cost-per-wear: {currency}{averageCpw} (green < 5, yellow 5-20, red > 20)
    - Items with price set: {pricedItems} of {totalItems}
    - Total wears across priced items: {totalWears}
    - Top 3 most worn items: {top3Items as "name (category): N wears"}
    - Neglected items count: {neglectedCount} items not worn in 60+ days
    - Category distribution: {top3Categories as "category: N items (X%)"}
    - Most active day: {mostActiveDay with count}
    - Least active day: {leastActiveDay with count}

    RULES:
    1. Highlight ONE specific positive habit (e.g., great CPW, consistent wearing, balanced wardrobe).
    2. Suggest ONE constructive improvement (e.g., wear neglected items, diversify categories).
    3. Reference specific numbers from the data (e.g., "Your £4.20 average cost-per-wear shows great value").
    4. Keep tone encouraging, not judgmental. Use "you" voice.
    5. Do NOT mention premium status, app features, or technical details.
    6. Maximum 4 sentences.

    Return ONLY valid JSON:
    { "summary": "Your wardrobe summary text here..." }
    ```
  - [x] 1.4: Parse and validate the Gemini response. Steps: (a) extract JSON from `response.candidates[0].content.parts[0].text`, (b) `JSON.parse`, (c) validate `summary` is a non-empty string, (d) truncate to 500 characters if longer. On parse failure, throw an error.
  - [x] 1.5: Log AI usage following the exact pattern from `outfit-generation-service.js`: extract `usageMetadata`, compute `estimateCost()`, call `aiUsageLogRepo.logUsage(authContext, { feature: "analytics_summary", model: "gemini-2.0-flash", inputTokens, outputTokens, latencyMs, estimatedCostUsd, status: "success" })`. On failure, log with `status: "failure"`.
  - [x] 1.6: Error handling: wrap the entire method in try/catch. On Gemini failure, log usage with "failure" status and re-throw with `{ statusCode: 500, message: "Analytics summary generation failed" }`.

- [x] Task 2: API - Add `GET /v1/analytics/ai-summary` endpoint (AC: 1, 4, 5)
  - [x] 2.1: In `apps/api/src/main.js`, import `createAnalyticsSummaryService` and instantiate in `createRuntime()` with `{ geminiClient, analyticsRepository, aiUsageLogRepo, pool }`. Add `analyticsSummaryService` to the returned runtime object.
  - [x] 2.2: Add `analyticsSummaryService` to the `handleRequest` destructuring.
  - [x] 2.3: Add route `GET /v1/analytics/ai-summary`. Requires authentication (401 if unauthenticated). Calls `analyticsSummaryService.generateSummary(authContext)`. Returns 200 with `{ summary: "...", isGeneric: boolean }`. Place after existing analytics routes and before `notFound`.
  - [x] 2.4: Error responses: 403 for non-premium users (with `{ error: "Premium Required", code: "PREMIUM_REQUIRED", message: "Premium subscription required for AI insights" }`), 503 for Gemini unavailable, 500 for generation failure.

- [x] Task 3: API - Unit tests for analytics summary service (AC: 1, 4, 5, 6, 8)
  - [x] 3.1: Create `apps/api/test/modules/analytics/analytics-summary-service.test.js`:
    - `generateSummary` calls Gemini with correct prompt containing analytics data.
    - `generateSummary` returns valid summary text from Gemini response.
    - `generateSummary` throws 403 when user is not premium.
    - `generateSummary` throws 503 when Gemini is unavailable.
    - `generateSummary` returns generic message when wardrobe is empty (totalItems === 0).
    - `generateSummary` does NOT call Gemini when wardrobe is empty.
    - `generateSummary` logs successful usage to ai_usage_log with feature "analytics_summary".
    - `generateSummary` logs failure to ai_usage_log when Gemini fails.
    - `generateSummary` handles unparseable Gemini JSON gracefully.
    - `generateSummary` truncates summary to 500 characters.
    - `generateSummary` fetches all 6 analytics datasets in parallel.
    - `generateSummary` handles empty neglected/top-worn arrays gracefully in prompt.

- [x] Task 4: API - Integration tests for GET /v1/analytics/ai-summary (AC: 1, 2, 4, 5, 8)
  - [x] 4.1: In `apps/api/test/modules/analytics/analytics-summary.test.js`:
    - `GET /v1/analytics/ai-summary` returns 200 with summary for premium user.
    - `GET /v1/analytics/ai-summary` returns 401 if unauthenticated.
    - `GET /v1/analytics/ai-summary` returns 403 for non-premium user with correct error body.
    - `GET /v1/analytics/ai-summary` returns 200 with generic message for premium user with empty wardrobe.
    - `GET /v1/analytics/ai-summary` returns 500 when Gemini call fails.
    - `GET /v1/analytics/ai-summary` returns 503 when Gemini is unavailable.
    - Response contains `summary` string and `isGeneric` boolean.

- [x] Task 5: Mobile - Add API method and premium check to ApiClient (AC: 1, 2, 4)
  - [x] 5.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getAiAnalyticsSummary()` method. Calls `GET /v1/analytics/ai-summary` using `_authenticatedGet`. Returns response JSON map. Throws `ApiException` on error (including 403 for non-premium).

- [x] Task 6: Mobile - Create AiInsightsSection widget (AC: 1, 2, 3, 5, 7)
  - [x] 6.1: Create `apps/mobile/lib/src/features/analytics/widgets/ai_insights_section.dart` with an `AiInsightsSection` StatelessWidget. Constructor accepts: `required bool isPremium`, `String? summary`, `bool isLoading = false`, `String? error`, `VoidCallback? onRetry`, `VoidCallback? onUpgrade`.
  - [x] 6.2: **Premium state (summary available):** Display a card (white background, 16px border radius, subtle shadow) containing: (a) header row with `Icons.auto_awesome` icon (20px, #4F46E5) and "AI Insights" title (16px, bold, #1F2937), (b) the summary text (14px, #1F2937, max 6 lines), (c) a "Powered by AI" label (11px, #9CA3AF) at the bottom-right. 16px horizontal padding, 12px vertical spacing.
  - [x] 6.3: **Premium loading state:** Show a shimmer placeholder matching the card dimensions (height ~120px) with the "AI Insights" header visible.
  - [x] 6.4: **Premium error state:** Show the card with "Unable to generate insights right now. Pull to refresh to try again." text (13px, #6B7280) and a "Retry" `TextButton` that calls `onRetry`.
  - [x] 6.5: **Free user teaser state:** Show a card with a frosted/blurred overlay effect (or a gradient overlay #F9FAFB to transparent): (a) `Icons.lock_outline` icon (24px, #9CA3AF), (b) "Unlock AI Wardrobe Insights" title (16px, bold, #1F2937), (c) "Get personalized analysis of your wardrobe habits" subtitle (13px, #6B7280), (d) "Go Premium" button (#4F46E5 background, white text, 12px border radius, 44px height) calling `onUpgrade` (non-functional for now). The teaser does NOT trigger any API call.
  - [x] 6.6: Add `Semantics` labels: "AI wardrobe insights" on the card, "AI generated summary: [text]" on the summary, "Unlock AI insights, upgrade to premium" on the teaser.

- [x] Task 7: Mobile - Integrate AI Insights into AnalyticsDashboardScreen (AC: 1, 2, 3, 5, 7)
  - [x] 7.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `String? _aiSummary`, `bool _isLoadingAiSummary = false`, `String? _aiSummaryError`, `bool _isPremium = false`.
  - [x] 7.2: Add a `_checkPremiumStatus()` method. This calls `GET /v1/analytics/ai-summary`. If the response is 200, the user is premium and we have the summary. If 403, the user is free. Store `_isPremium` accordingly. This approach piggybacks premium detection on the AI summary call -- no separate premium check endpoint is needed.
  - [x] 7.3: Update `_loadAnalytics()`: after the existing 6-endpoint `Future.wait`, call `_loadAiSummary()`. The `_loadAiSummary()` method: (a) sets `_isLoadingAiSummary = true`, (b) calls `apiClient.getAiAnalyticsSummary()`, (c) on success (200), sets `_isPremium = true`, `_aiSummary = response["summary"]`, `_isLoadingAiSummary = false`, (d) on 403, sets `_isPremium = false`, `_isLoadingAiSummary = false` (no error -- expected for free users), (e) on other error, sets `_aiSummaryError`, `_isLoadingAiSummary = false`. Guard all `setState` with `mounted`.
  - [x] 7.4: **Session caching:** Add a flag `bool _aiSummaryLoaded = false`. Once `_loadAiSummary()` succeeds, set `_aiSummaryLoaded = true`. On subsequent `_loadAnalytics()` calls (e.g., returning to the screen), skip `_loadAiSummary()` if `_aiSummaryLoaded` is true. On pull-to-refresh, reset `_aiSummaryLoaded = false` so the AI summary is re-fetched.
  - [x] 7.5: In the `CustomScrollView` slivers, add the `AiInsightsSection` as the FIRST sliver (before `SummaryCardsRow`):
    - `SliverToBoxAdapter` wrapping `AiInsightsSection(isPremium: _isPremium, summary: _aiSummary, isLoading: _isLoadingAiSummary, error: _aiSummaryError, onRetry: _loadAiSummary)`.
    - For free users, show the teaser. For premium users, show the AI summary (or loading/error state).
  - [x] 7.6: The AI summary call is made AFTER the 6 analytics endpoints complete (not in parallel with them). This is because the API generates the summary from the same analytics data -- calling them in parallel would be redundant since the API fetches them again server-side. However, the dashboard still displays the 6 existing sections immediately; the AI summary section shows a loading shimmer until it arrives.

- [x] Task 8: Mobile - Widget tests for AiInsightsSection (AC: 1, 2, 3, 5, 7, 8)
  - [x] 8.1: Create `apps/mobile/test/features/analytics/widgets/ai_insights_section_test.dart`:
    - Renders "AI Insights" header with icon when premium and summary available.
    - Renders summary text in the card.
    - Renders "Powered by AI" label.
    - Renders shimmer/loading state when `isLoading` is true.
    - Renders error message and retry button when `error` is set.
    - Tapping retry calls `onRetry`.
    - Renders free-user teaser with "Unlock AI Wardrobe Insights" when not premium.
    - Renders "Go Premium" button in teaser state.
    - Does NOT render summary text in teaser state.
    - Semantics labels present on all states.

- [x] Task 9: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 2, 7, 8)
  - [x] 9.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`:
    - Dashboard renders AiInsightsSection as first section (above SummaryCardsRow).
    - Premium user sees AI summary after loading.
    - Free user (403 response) sees teaser card.
    - AI summary error shows error state with retry.
    - Pull-to-refresh re-fetches AI summary.
    - Session caching: navigating away and back does not re-fetch AI summary.
    - All existing dashboard tests still pass with the new section.
    - Mock API updated to handle 7th endpoint call.

- [x] Task 10: Regression testing (AC: all)
  - [x] 10.1: Run `flutter analyze` -- zero new issues.
  - [x] 10.2: Run `flutter test` -- all existing 922+ Flutter tests plus new tests pass.
  - [x] 10.3: Run `npm --prefix apps/api test` -- all existing 419+ API tests plus new tests pass.
  - [x] 10.4: Verify existing AnalyticsDashboardScreen tests pass with the new AiInsightsSection added.
  - [x] 10.5: Verify existing CategoryDistributionSection, WearFrequencySection, TopWornSection, NeglectedItemsSection, SummaryCardsRow, and CpwItemRow tests still pass.

## Dev Notes

- This is the **seventh and FINAL story in Epic 5** (Wardrobe Analytics & Wear Logging). It adds the last analytics feature: an AI-generated wardrobe summary using Gemini 2.0 Flash, completing FR-ANA-06.
- This story implements **FR-ANA-06**: "The system shall provide AI-generated wardrobe insights (summary text)."
- This is the **first premium-gated feature on the Analytics dashboard**. Stories 5.1-5.6 are free-tier. The AI summary requires premium status (`profiles.is_premium = true`, added in Story 4.5 migration `014_profiles_is_premium.sql`).
- **This story creates a NEW AI service** in the analytics module. It follows the identical Gemini call pattern established in Story 2.3 (`categorization-service.js`) and Story 4.1 (`outfit-generation-service.js`): construct prompt -> call Gemini with JSON mode -> parse response -> validate -> log usage.
- **The API aggregates all analytics data server-side before calling Gemini.** The mobile client makes a single `GET /v1/analytics/ai-summary` call. The API fetches all 6 analytics datasets using the existing repository methods and passes the aggregated data to Gemini. This avoids sending raw analytics data from the client.
- **No new database migration needed.** All required data exists: `profiles.is_premium` (Story 4.5, migration 014), `ai_usage_log` table (Story 2.3, migration 007), all analytics data (Stories 5.1-5.6).
- **No new Flutter dependencies needed.** Uses existing Material widgets. No shimmer package needed -- a simple `Container` with `LinearGradient` animation or `CircularProgressIndicator` suffices for the loading state.

### Design Decision: AI Summary at Top of Dashboard

The AI Insights section is placed at the TOP of the dashboard (before SummaryCardsRow) because:
1. It provides the highest-value information (personalized narrative) vs raw numbers.
2. Premium users see their premium benefit immediately.
3. Free users see the upgrade prompt prominently, encouraging conversion.
4. The section is lightweight (2-4 sentences) and does not push critical data below the fold.

### Design Decision: Server-Side Analytics Aggregation for Gemini

The API fetches all 6 analytics datasets server-side rather than receiving them from the client because:
1. **Server authority:** Analytics data is computed from the database -- the server has authoritative access.
2. **Tamper-proof:** A malicious client cannot send fake analytics data to influence the AI summary.
3. **Simplicity:** One API call from the client vs sending a complex analytics payload.
4. **Consistency:** The summary always reflects current database state.

### Design Decision: Premium Gating via 403 Response

Rather than a separate "check premium status" endpoint, the AI summary endpoint returns 403 for free users. The mobile client uses this to determine premium status for the teaser display. This approach:
1. Avoids an extra API call to check premium status.
2. Keeps premium enforcement server-side (architecture principle).
3. The 403 is caught and handled gracefully -- it's not an error, it's expected for free users.

### Design Decision: Session Caching on Mobile

The AI summary is cached for the session duration to avoid repeated Gemini calls (which have cost implications). The cache is invalidated on:
1. Pull-to-refresh (user explicitly requests fresh data).
2. App restart (session ends).
This reduces AI costs while keeping data reasonably fresh.

### Design Decision: Generic Message for Empty Wardrobe

When a premium user has zero items, the API returns a hardcoded encouraging message without calling Gemini. This avoids wasting an AI call (with associated cost and latency) on data that cannot produce meaningful insights.

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/analytics/analytics-summary-service.js` (AI summary generation service)
  - `apps/api/test/modules/analytics/analytics-summary-service.test.js`
  - `apps/api/test/modules/analytics/analytics-summary.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/ai_insights_section.dart` (AI insights widget)
  - `apps/mobile/test/features/analytics/widgets/ai_insights_section_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add analyticsSummaryService to createRuntime, add GET /v1/analytics/ai-summary route)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add getAiAnalyticsSummary method)
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add AI summary state fields, _loadAiSummary, session caching, AiInsightsSection sliver)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add AI summary tests, update mock for 7th endpoint)
- No SQL migration files.
- Analytics feature module directory structure after this story (FINAL for Epic 5):
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
      ├── ai_insights_section.dart (NEW)
      ├── category_distribution_section.dart (Story 5.6)
      ├── cpw_item_row.dart (Story 5.4)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── summary_cards_row.dart (Story 5.4)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (Story 5.6)
  ```

### Technical Requirements

- **Analytics summary service:** Follows the factory pattern: `createAnalyticsSummaryService({ geminiClient, analyticsRepository, aiUsageLogRepo, pool })`. The `pool` parameter is needed for the premium status check (query `profiles.is_premium`).
- **Premium check query:** `SELECT id, is_premium FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1`. Uses the existing `pool.connect()` -> set RLS -> query -> release pattern. Throw 403 if not premium.
- **Gemini model:** `gemini-2.0-flash` -- same model used for categorization, outfit generation, and event classification.
- **Gemini JSON mode:** `generationConfig: { responseMimeType: "application/json" }` for structured output.
- **Prompt data preparation:** After fetching all 6 datasets via `Promise.all`, extract key metrics for the prompt: totalItems, totalValue, averageCpw, dominantCurrency, top 3 worn items, neglected count, top 3 categories, most/least active days. Keep the prompt concise (<2000 tokens input) to minimize latency and cost.
- **AI usage logging:** Feature name = `"analytics_summary"`. Log to `ai_usage_log` with model, tokens, latency, cost, status. Follow the estimateCost pattern from `outfit-generation-service.js`.
- **Cost estimation:** Use the same pricing formula as categorization/outfit generation: `(inputTokens * 0.000000125 + outputTokens * 0.000000375)` for Gemini 2.0 Flash.
- **Response shape:** `{ summary: string, isGeneric: boolean }`. `isGeneric` is `true` when the response is a hardcoded message (empty wardrobe), `false` when AI-generated.
- **AiInsightsSection widget:** Accepts `isPremium`, `summary`, `isLoading`, `error`, `onRetry`, `onUpgrade`. Renders one of four states: premium-with-summary, premium-loading, premium-error, free-teaser.
- **Dashboard integration:** The AI summary call is sequential after the 6-endpoint `Future.wait`. This keeps the dashboard responsive (existing sections render immediately) while the AI summary loads asynchronously.

### Architecture Compliance

- **AI calls are brokered only by Cloud Run:** The mobile client calls `GET /v1/analytics/ai-summary`. The API calls Gemini. The mobile client NEVER calls Gemini directly.
- **Server authority for analytics data:** All analytics data is fetched server-side from Cloud SQL. The AI summary is generated from authoritative database data.
- **Server authority for premium gating:** The API checks `profiles.is_premium` before calling Gemini. The client does not enforce premium access.
- **RLS enforces data isolation:** All analytics queries are RLS-scoped. A user can only get insights about their own wardrobe.
- **Mobile boundary owns presentation:** The API returns a summary string. The client handles layout, styling, teaser state, and loading/error UX.
- **AI usage logging:** All Gemini calls are logged to `ai_usage_log` for cost tracking and observability.
- **Graceful AI degradation:** If Gemini fails, the dashboard still shows all 6 existing analytics sections. Only the AI summary section shows an error state.
- **API module placement:** The summary service goes in `apps/api/src/modules/analytics/` alongside the existing analytics repository. The route goes in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/ai-summary` follows the existing analytics endpoint naming convention.

### Library / Framework Requirements

- No new dependencies for mobile or API.
- Mobile uses existing: `flutter/material.dart` (widgets, animations), `cached_network_image` (not directly used by this widget but available).
- API uses existing: `@google-cloud/vertexai` (via shared `geminiClient`), `pg` (via `pool`).

### File Structure Requirements

- New API service goes in `apps/api/src/modules/analytics/` alongside `analytics-repository.js`.
- New API test files go in `apps/api/test/modules/analytics/`.
- New mobile widget goes in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing Story 5.4-5.6 widgets.
- Test files mirror source structure under `apps/mobile/test/features/analytics/widgets/`.

### Testing Requirements

- **API service tests** must verify:
  - Correct prompt construction with all 6 analytics datasets
  - Gemini called with JSON mode (`responseMimeType: "application/json"`)
  - Valid summary text returned from Gemini response
  - 403 thrown for non-premium users
  - 503 thrown when Gemini is unavailable
  - Generic message returned for empty wardrobe (no Gemini call)
  - AI usage logged for success with feature "analytics_summary"
  - AI usage logged for failure
  - Unparseable Gemini JSON handled gracefully
  - Summary truncated to 500 characters
  - All 6 analytics datasets fetched in parallel via Promise.all
  - Empty arrays in top-worn/neglected handled in prompt
- **API endpoint tests** must verify:
  - 200 response with summary string and isGeneric boolean for premium user
  - 401 for unauthenticated requests
  - 403 for non-premium user with correct error body
  - 200 with generic message for premium user with empty wardrobe
  - 500 when Gemini call fails
  - 503 when Gemini is unavailable
- **Mobile widget tests** must verify:
  - AiInsightsSection renders summary card for premium user
  - AiInsightsSection renders loading shimmer when isLoading
  - AiInsightsSection renders error with retry button
  - AiInsightsSection renders free-user teaser with "Go Premium" button
  - Semantics labels on all states
- **Dashboard integration tests** must verify:
  - AiInsightsSection appears as first section (above SummaryCardsRow)
  - Premium user sees summary after loading
  - Free user (403) sees teaser without error
  - Pull-to-refresh re-fetches AI summary
  - All existing 6-section dashboard tests still pass
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 922+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 419+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 5.6** (done) established: `fl_chart` dependency, `CategoryDistributionSection` and `WearFrequencySection` widgets, `getCategoryDistribution` and `getWearFrequency` repository methods, dashboard now fetches 6 endpoints in parallel via `Future.wait`. Test counts: 419 API tests, 922 Flutter tests. Story 5.6 noted: "Story 5.7 (AI summary) is the final analytics section and can add tabs if needed" -- we are NOT adding tabs (vertical scroll continues).
- **Story 5.5** (done) established: `TopWornSection` and `NeglectedItemsSection`, `getTopWornItems(period)` and `getNeglectedItems()` repository methods, 4-endpoint parallel fetch. Story 5.5 noted: "When Story 5.6 (charts) and 5.7 (AI summary) are added, the dashboard may be restructured into tabs."
- **Story 5.4** (done) established: `AnalyticsDashboardScreen` with `CustomScrollView` slivers, `_loadAnalytics()` with `Future.wait`, `SummaryCardsRow`, `CpwItemRow`, `_navigateToItemDetail`, error-retry pattern, `RefreshIndicator`. The analytics repository has 6 methods total after Story 5.6.
- **Story 4.5** (done) established: `profiles.is_premium` column (migration 014), `createUsageLimitService`, 429 rate limit handling, `UsageLimitCard`, `UsageIndicator`. The `is_premium` column is the server-side source of truth for premium status. Manual toggle in DB for testing.
- **Story 4.1** (done) established: `createOutfitGenerationService` pattern (Gemini call with JSON mode, prompt construction, response parsing, AI usage logging), `POST /v1/outfits/generate`, `OutfitSuggestion` model. This story's analytics summary service follows the IDENTICAL Gemini call pattern.
- **Story 2.3** (done) established: `categorization-service.js` with Gemini JSON mode, taxonomy validation, `estimateCost()` pricing formula, AI usage logging pattern, `ai_usage_log` table.
- **Key Gemini call pattern (from `categorization-service.js` and `outfit-generation-service.js`):**
  1. `const model = await geminiClient.getGenerativeModel("gemini-2.0-flash")`
  2. `const result = await model.generateContent({ contents: [...], generationConfig: { responseMimeType: "application/json" } })`
  3. Extract `result.response.candidates[0].content.parts[0].text`
  4. `JSON.parse(text)` and validate
  5. Extract `result.response.usageMetadata` for token counts
  6. Compute `latencyMs = Date.now() - startTime`
  7. Compute `estimatedCostUsd` from token counts
  8. Log to `ai_usage_log`
- **`createRuntime()` currently returns:** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`, `wearLogRepository`, `analyticsRepository`. This story adds `analyticsSummaryService`.
- **`handleRequest` destructuring:** Must add `analyticsSummaryService`.
- **Dashboard state fields (as of Story 5.6):** `_summary`, `_itemsCpw`, `_topWornItems`, `_neglectedItems`, `_categoryDistribution`, `_wearFrequency`, `_topWornPeriod`, `_isLoading`, `_error`. This story adds: `_aiSummary`, `_isLoadingAiSummary`, `_aiSummaryError`, `_isPremium`, `_aiSummaryLoaded`.
- **Dashboard `CustomScrollView` sliver order (as of Story 5.6):** SummaryCardsRow, "Cost-Per-Wear Breakdown" header, CPW SliverList, TopWornSection, NeglectedItemsSection, CategoryDistributionSection, WearFrequencySection, bottom padding. This story inserts AiInsightsSection BEFORE SummaryCardsRow.
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Section headers: 16px bold, #1F2937.
  - "Powered by AI" / "AI" chip pattern from Story 4.1 `OutfitSuggestionCard`.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. The API brokers all AI calls.
- DO NOT send analytics data from the mobile client to the API for summary generation. The API fetches all data server-side.
- DO NOT implement the AI summary for free users. Free users see only the teaser. The API returns 403 and the mobile client displays the teaser state.
- DO NOT call Gemini when the wardrobe is empty. Return a hardcoded generic message.
- DO NOT re-fetch the AI summary on every navigation to the Analytics screen. Use session caching. Only pull-to-refresh should trigger a new call.
- DO NOT fetch the AI summary in parallel with the 6 analytics endpoints from the mobile client. The AI summary is a sequential call after the analytics data loads. The API fetches all data server-side anyway.
- DO NOT create a separate "check premium status" endpoint. Use the 403 from the AI summary endpoint to detect free user status.
- DO NOT restructure the dashboard into tabs. Keep the vertical scroll pattern. Tab restructuring can be done in a future story if the dashboard becomes too long.
- DO NOT modify existing API endpoints, repository methods, or migration files. Only add new files and extend existing ones.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT implement brand value analytics, sustainability scoring, or wardrobe gap analysis. Those are Epic 11.
- DO NOT implement the premium purchase flow. The "Go Premium" button in the teaser is non-functional. Story 7.1 handles RevenueCat integration.
- DO NOT add the AI summary to the `ai_usage_log` count for the daily outfit generation limit. The analytics summary is a separate feature with no rate limit in V1.
- DO NOT use a different Gemini model. Use `gemini-2.0-flash` consistently across all AI features.
- DO NOT create a new analytics service class on mobile. The `ApiClient` method is sufficient for this single GET request.

### Out of Scope

- **Brand Value Analytics (FR-BRD-01, FR-BRD-02, FR-BRD-03):** Epic 11.
- **Sustainability Scoring (FR-SUS-*):** Epic 11.
- **Wardrobe Gap Analysis (FR-GAP-*):** Epic 11.
- **Seasonal Reports and Heatmaps (FR-SEA-*, FR-HMP-*):** Epic 11.
- **Wardrobe Health Score (FR-HLT-*):** Epic 13.
- **Gamification / Style Points:** Epic 6.
- **Premium subscription purchase flow:** Story 7.1 (RevenueCat).
- **Offline analytics viewing:** Out of scope for V1.
- **Rate limiting on AI summary calls:** V1 does not rate-limit this endpoint beyond the premium gate. If abuse becomes a concern, a per-day limit can be added.
- **Personalized style recommendations beyond summary:** The AI summary is informational text only. Actionable recommendations (e.g., "declutter these 5 items") are deferred to future stories.
- **Dashboard tab restructuring:** The vertical scroll pattern continues. Tab restructuring is deferred.
- **Caching AI summary server-side:** V1 generates a fresh summary on each call. Server-side caching (e.g., Redis or DB) could be added as an optimization if AI costs become a concern.

### References

- [Source: epics.md - Story 5.7: AI-Generated Analytics Summary]
- [Source: epics.md - FR-ANA-06: The system shall provide AI-generated wardrobe insights (summary text)]
- [Source: prd.md - Analytics: AI-generated wardrobe insights summary text]
- [Source: architecture.md - AI Orchestration: Vertex AI / Gemini 2.0 Flash, AI calls brokered only by Cloud Run]
- [Source: architecture.md - Server authority for sensitive rules: premium capability checks happen server-side]
- [Source: architecture.md - Subscription and Premium Gating: gated features include advanced analytics]
- [Source: architecture.md - Epic 5 Analytics & Wear Logging -> mobile/features/analytics, api/modules/analytics, infra/sql/functions]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: architecture.md - AI Orchestration: per-user logging of tokens, latency, and cost]
- [Source: ux-design-specification.md - Anti-Patterns: Overwhelming Data Displays -- data must be visualized simply]
- [Source: ux-design-specification.md - Analytics/Sustainability Check: Accomplishment and Pride]
- [Source: 5-6-category-distribution-charts.md - Dashboard with 6 parallel API calls, CategoryDistributionSection, WearFrequencySection, fl_chart, 419 API tests, 922 Flutter tests]
- [Source: 5-5-top-worn-neglected-items-analytics.md - TopWornSection, NeglectedItemsSection, 4-endpoint parallel fetch]
- [Source: 5-4-basic-wardrobe-value-analytics.md - AnalyticsDashboardScreen, analytics-repository.js, Future.wait parallel pattern, SummaryCardsRow]
- [Source: 4-5-ai-usage-limits-enforcement.md - profiles.is_premium column, premium gating pattern, UsageLimitCard teaser pattern]
- [Source: 4-1-daily-ai-outfit-generation.md - Gemini call pattern, outfit-generation-service.js, AI usage logging, "AI" chip UI pattern]
- [Source: apps/api/src/modules/ai/categorization-service.js - Gemini JSON mode, estimateCost pricing formula, AI usage log pattern]
- [Source: apps/api/src/modules/ai/gemini-client.js - isAvailable(), getGenerativeModel()]
- [Source: apps/api/src/modules/ai/ai-usage-log-repository.js - logUsage method with feature, model, tokens, latency, cost, status]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - 6 methods: getWardrobeSummary, getItemsWithCpw, getTopWornItems, getNeglectedItems, getCategoryDistribution, getWearFrequency]
- [Source: apps/api/src/main.js - createRuntime, handleRequest, mapError, existing analytics routes]
- [Source: infra/sql/migrations/014_profiles_is_premium.sql - is_premium BOOLEAN NOT NULL DEFAULT false on profiles]
- [Source: infra/sql/migrations/007_ai_usage_log.sql - ai_usage_log table schema]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- All 441 API tests pass (419 existing + 22 new: 15 unit + 7 integration)
- All 939 Flutter tests pass (922 existing + 17 new: 11 widget + 6 dashboard integration)
- flutter analyze: zero new issues (5 pre-existing warnings in unrelated wear_calendar_screen_test.dart)

### Completion Notes List

- Created analytics summary service following identical Gemini call pattern from outfit-generation-service.js
- Service: factory pattern with geminiClient, analyticsRepository, aiUsageLogRepo, pool dependencies
- Premium check via direct pool query on profiles.is_premium (server-side enforcement)
- All 6 analytics datasets fetched in parallel via Promise.all before Gemini call
- Empty wardrobe returns hardcoded generic message without Gemini call
- Gemini prompt includes top 3 worn items, neglected count, category distribution, wear frequency
- Response parsed, validated, truncated to 500 chars; AI usage logged for success and failure
- GET /v1/analytics/ai-summary endpoint with 403 for non-premium, 503 for Gemini unavailable, 500 for generation failure
- AiInsightsSection widget with 4 states: premium-summary, premium-loading, premium-error, free-teaser
- Dashboard integration: AI section as first sliver, session caching via _aiSummaryLoaded flag
- Pull-to-refresh resets cache and re-fetches AI summary
- 403 from AI endpoint used to detect free user status (no separate premium check endpoint)
- Adjusted scroll offsets in 2 existing dashboard tests to account for new AI section at top

### File List

New files:
- apps/api/src/modules/analytics/analytics-summary-service.js
- apps/api/test/modules/analytics/analytics-summary-service.test.js
- apps/api/test/modules/analytics/analytics-summary.test.js
- apps/mobile/lib/src/features/analytics/widgets/ai_insights_section.dart
- apps/mobile/test/features/analytics/widgets/ai_insights_section_test.dart

Modified files:
- apps/api/src/main.js
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart
- apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart
