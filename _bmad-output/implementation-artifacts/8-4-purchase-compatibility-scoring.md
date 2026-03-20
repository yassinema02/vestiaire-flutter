# Story 8.4: Purchase Compatibility Scoring

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want a potential purchase scored against my wardrobe,
so that I can tell whether it is a smart buy before spending money.

## Acceptance Criteria

1. Given a validated potential purchase (reviewed or skipped in Story 8.3) and I have at least 1 wardrobe item, when the scoring is triggered, then the API calls `POST /v1/shopping/scans/:id/score` which fetches all of the user's wardrobe items (via `itemRepo.listItems`), constructs a Gemini 2.0 Flash prompt containing the product metadata and a compact summary of wardrobe items (category, color, style, formality per item), and receives a structured JSON response with a compatibility score (0-100) based on five weighted factors: color harmony (30%), style consistency (25%), gap filling (20%), versatility (15%), formality match (10%). (FR-SHP-06, NFR-PERF-09)

2. Given the Gemini scoring response is received, when the API processes it, then the `compatibility_score` column on the `shopping_scans` row is updated with the integer score (0-100), and the response includes `{ scan: { ...updatedScan }, score: { total, breakdown: { colorHarmony, styleConsistency, gapFilling, versatility, formalityMatch }, tier, tierLabel, tierColor, tierIcon }, status: "scored" }`. (FR-SHP-06, FR-SHP-07)

3. Given the compatibility score has been calculated, when the result is returned, then the score is mapped to one of five tiers: Perfect Match (90-100, green `#22C55E`, icon `Icons.stars`), Great Choice (75-89, blue `#3B82F6`, icon `Icons.thumb_up`), Good Fit (60-74, amber `#F59E0B`, icon `Icons.check_circle`), Might Work (40-59, orange `#F97316`, icon `Icons.help_outline`), Careful (0-39, red `#EF4444`, icon `Icons.warning`). The tier mapping is computed both server-side (returned in the score response) and client-side (for rendering). (FR-SHP-07)

4. Given the user is on the `ProductReviewScreen` and taps "Confirm" or "Skip Review", when the action completes, then instead of showing a SnackBar placeholder, the app calls the scoring endpoint `POST /v1/shopping/scans/:id/score` and navigates to a new `CompatibilityScoreScreen` displaying: (a) the product image and name at the top, (b) the overall score as a large animated circular gauge, (c) the tier label and icon with tier color, (d) a breakdown section showing each of the 5 scoring factors as a horizontal bar with score and label, (e) a "View Matches & Insights" button (disabled placeholder for Story 8.5). (FR-SHP-06, FR-SHP-07)

5. Given the scoring endpoint receives a request, when processing, then it enforces authentication and verifies the scan belongs to the authenticated user via RLS (returning 404 if not). The endpoint does NOT consume an additional usage quota -- the quota was already consumed during the scan creation (Stories 8.1/8.2). (FR-SHP-06)

6. Given the user's wardrobe is empty (0 items), when scoring is triggered, then the API returns HTTP 422 with `{ error: "Wardrobe Empty", code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first to get compatibility scores." }` and the mobile screen displays an empty-state card with a "Go to Wardrobe" button navigating to the Wardrobe tab. (FR-SHP-12)

7. Given the user has a large wardrobe (500+ items), when scoring is triggered, then the API summarizes the wardrobe by aggregating items into category/color/style distribution counts rather than sending every item individually to Gemini. This keeps the prompt within token limits and ensures the scoring completes even for large wardrobes. (NFR-PERF-09)

8. Given the Gemini scoring call fails (timeout, parse error, or no useful response), when the error occurs, then the API returns HTTP 502 with `{ error: "Scoring Failed", code: "SCORING_FAILED", message: "Unable to calculate compatibility score. Please try again." }` and logs the failure to `ai_usage_log`. The mobile screen shows a retry button. (NFR-REL-03)

9. Given the API processes a scoring request, when the Gemini call is made, then the API logs the request to `ai_usage_log` with `feature = "shopping_score"`, model name, input/output tokens, latency in ms, estimated cost, and status `"success"` or `"failure"`. Note: this uses `"shopping_score"` (not `"shopping_scan"`) to distinguish scoring AI calls from extraction AI calls. (NFR-OBS-02)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (774+ API tests, 1199+ Flutter tests) and new tests cover: scoring endpoint (success, empty wardrobe, large wardrobe, auth, Gemini failure), scoring service logic (prompt construction, response parsing, score calculation, tier mapping, wardrobe summarization), CompatibilityScoreScreen widget (score display, breakdown bars, tier colors, empty wardrobe state, retry on error), ApiClient score method, and ShoppingScanService score method.

## Tasks / Subtasks

- [x] Task 1: API -- Create compatibility scoring service (AC: 1, 2, 3, 7, 8, 9)
  - [x] 1.1: In `apps/api/src/modules/shopping/shopping-scan-service.js`, add a new method `async scoreCompatibility(authContext, { scanId })` to the service object. This method: (a) fetches the scan via `shoppingScanRepo.getScanById(authContext, scanId)`, (b) if scan not found, throw 404, (c) fetches all user wardrobe items via `itemRepo.listItems(authContext, {})` (no filters, get all), (d) if items.length === 0, throw 422 with `code: "WARDROBE_EMPTY"`, (e) builds the wardrobe summary (see Task 2), (f) constructs the Gemini scoring prompt with product metadata + wardrobe summary, (g) calls Gemini 2.0 Flash with `responseMimeType: "application/json"`, (h) parses the structured score response, (i) validates score is integer 0-100 and each factor score is 0-100, (j) computes tier from total score, (k) updates the scan's `compatibility_score` via `shoppingScanRepo.updateScan`, (l) logs AI usage, (m) returns `{ scan, score, status: "scored" }`.
  - [x] 1.2: The `createShoppingScanService` factory must now also accept `itemRepo` as a dependency: `createShoppingScanService({ urlScraperService, geminiClient, aiUsageLogRepo, shoppingScanRepo, itemRepo, pool })`. Update the factory signature and the `createRuntime()` wiring.
  - [x] 1.3: Add a `COMPATIBILITY_SCORING_PROMPT` constant. The prompt instructs Gemini to score a potential purchase against the user's wardrobe across 5 factors. Return structured JSON: `{ "total": <0-100>, "color_harmony": <0-100>, "style_consistency": <0-100>, "gap_filling": <0-100>, "versatility": <0-100>, "formality_match": <0-100>, "reasoning": "<brief 1-2 sentence explanation>" }`. The weighted total is: `total = round(color_harmony * 0.30 + style_consistency * 0.25 + gap_filling * 0.20 + versatility * 0.15 + formality_match * 0.10)`. Ask Gemini to apply these exact weights and return both the factor scores and the computed total.
  - [x] 1.4: Add `computeTier(score)` utility function that maps score to tier: `{ tier: "perfect_match"|"great_choice"|"good_fit"|"might_work"|"careful", label: "Perfect Match"|..., color: "#22C55E"|..., icon: "stars"|... }`. Export for reuse by mobile.
  - [x] 1.5: Validate the Gemini response: total must be integer 0-100, each factor must be integer 0-100. If Gemini returns out-of-range or invalid values, clamp to [0, 100]. If the response is completely unparseable, throw 502 with `code: "SCORING_FAILED"`.

- [x] Task 2: API -- Wardrobe summarization for large wardrobes (AC: 7)
  - [x] 2.1: Add a `buildWardrobeSummary(items)` function in `shopping-scan-service.js`. If `items.length <= 50`, serialize each item as a compact JSON line: `{ category, color, style, formalityScore, season, occasion }` (omit nulls). If `items.length > 50`, aggregate into a distribution summary: count by category, count by color, count by style, formality score histogram (1-3: casual, 4-6: mid, 7-10: formal), season coverage, occasion coverage. This keeps the Gemini prompt token-efficient for large wardrobes.
  - [x] 2.2: The summarization boundary (50 items) balances token cost vs. detail. For wardrobes with 50 or fewer items, Gemini gets per-item granularity. For larger wardrobes, it gets statistical distributions which are sufficient for color harmony, style consistency, and gap analysis.

- [x] Task 3: API -- Wire scoring endpoint (AC: 1, 5, 6, 8, 9)
  - [x] 3.1: Add route `POST /v1/shopping/scans/:id/score` in `apps/api/src/main.js`. This endpoint: (a) authenticates the user via `requireAuth`, (b) extracts `scanId` from URL path using regex `url.pathname.match(/^\/v1\/shopping\/scans\/([^/]+)\/score$/)`, (c) calls `shoppingScanService.scoreCompatibility(authContext, { scanId })`, (d) returns 200 with the score result. Error mapping: 404 for not found, 422 for empty wardrobe, 502 for scoring failure.
  - [x] 3.2: Place the route BEFORE the existing PATCH `/v1/shopping/scans/:id` route to prevent the `:id/score` path from being matched by the generic `scanIdMatch` regex. Alternatively, make the scanIdMatch regex more restrictive (exclude paths with trailing segments).
  - [x] 3.3: Add 502 to `mapError` if not already present.
  - [x] 3.4: Update `createRuntime()` to pass `itemRepo` to `createShoppingScanService`. The `itemRepo` is already created as part of `itemService` setup -- extract it: `const itemRepo = createItemRepository({ pool })`. NOTE: `itemRepo` is already created separately in `createRuntime()` (used by `createItemService`). Verify this and simply pass the existing `itemRepo` reference. If `itemRepo` is not a separate variable (i.e., it's inlined into `createItemService`), extract it.

- [x] Task 4: Mobile -- Add `scoreCompatibility` method to ShoppingScanService (AC: 4)
  - [x] 4.1: In `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart`, add method `Future<CompatibilityScoreResult> scoreCompatibility(String scanId)` that calls `_apiClient.authenticatedPost("/v1/shopping/scans/$scanId/score")` and returns a parsed `CompatibilityScoreResult`.

- [x] Task 5: Mobile -- Create CompatibilityScoreResult model (AC: 2, 3)
  - [x] 5.1: Create `apps/mobile/lib/src/features/shopping/models/compatibility_score_result.dart` with classes:
    - `ScoreBreakdown`: `int colorHarmony`, `int styleConsistency`, `int gapFilling`, `int versatility`, `int formalityMatch`. Factory `fromJson`.
    - `ScoreTier`: `String tier`, `String label`, `Color color`, `IconData icon`. Factory `fromTierString(String tier)` that maps tier name to color/icon.
    - `CompatibilityScoreResult`: `ShoppingScan scan`, `int total`, `ScoreBreakdown breakdown`, `ScoreTier tier`, `String? reasoning`. Factory `fromJson(Map<String, dynamic> json)`.

- [x] Task 6: Mobile -- Add `scoreShoppingScan` method to ApiClient (AC: 4)
  - [x] 6.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add method `Future<Map<String, dynamic>> scoreShoppingScan(String scanId)` that calls `authenticatedPost("/v1/shopping/scans/$scanId/score")`. Place adjacent to existing shopping methods.

- [x] Task 7: Mobile -- Create CompatibilityScoreScreen (AC: 4, 6, 8)
  - [x] 7.1: Create `apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart` with `CompatibilityScoreScreen` StatefulWidget. Constructor: `{ required String scanId, required ShoppingScan scan, required ShoppingScanService shoppingScanService, super.key }`.
  - [x] 7.2: On `initState`, immediately call `shoppingScanService.scoreCompatibility(scanId)` to trigger server-side scoring. Show a loading state with the product image/name and "Calculating compatibility..." text with a pulsing animation.
  - [x] 7.3: On success, display: (a) Product image and name at the top (compact, 100px height), (b) Overall score as a large circular gauge widget (`CustomPainter` or `CircularProgressIndicator` styled as gauge, 150px diameter) with score number in center and tier label below, colored with tier color, (c) Tier icon beside tier label, (d) Brief reasoning text (1-2 sentences from Gemini), (e) A "Score Breakdown" section with 5 horizontal bars, each showing factor name, bar fill proportional to score (0-100), and numeric score. Bar colors use a gradient from red (0) to green (100). Labels: "Color Harmony", "Style Consistency", "Gap Filling", "Versatility", "Formality Match". (f) A "View Matches & Insights" `OutlinedButton` at the bottom (disabled/placeholder for Story 8.5, text: "Coming Soon").
  - [x] 7.4: On empty wardrobe (422 WARDROBE_EMPTY), display an empty-state card: icon `Icons.checkroom`, title "Your wardrobe is empty", subtitle "Add some items to your wardrobe first so we can score how well this purchase matches.", and a "Go to Wardrobe" `ElevatedButton` that navigates to the Wardrobe tab.
  - [x] 7.5: On scoring failure (502 or other error), display an error card with "Scoring failed" message and a "Retry" `ElevatedButton` that re-triggers `scoreCompatibility`.
  - [x] 7.6: Add `Semantics` labels on: score gauge ("Compatibility score: X out of 100"), tier label, each breakdown bar ("Color harmony: X out of 100"), retry button, Go to Wardrobe button, View Matches button.
  - [x] 7.7: Follow Vibrant Soft-UI design: 16px border radius, subtle shadows, tier color for gauge accent, `#F3F4F6` background, `#1F2937` text, `#6B7280` secondary text.

- [x] Task 8: Mobile -- Update ProductReviewScreen to navigate to CompatibilityScoreScreen (AC: 4)
  - [x] 8.1: In `apps/mobile/lib/src/features/shopping/screens/product_review_screen.dart`, replace the SnackBar placeholder in `_onConfirm` and `_onSkipReview` with navigation to `CompatibilityScoreScreen`, passing `scanId: widget.initialScan.id`, `scan: _editedScan` (or `widget.initialScan` for skip), and `shoppingScanService: widget.shoppingScanService`.

- [x] Task 9: API -- Unit tests for scoring service (AC: 1, 2, 3, 7, 8, 9)
  - [x] 9.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-service.test.js`:
    - `scoreCompatibility` fetches scan and wardrobe items, calls Gemini, returns scored result.
    - `scoreCompatibility` throws 404 when scan not found.
    - `scoreCompatibility` throws 422 when wardrobe is empty.
    - `scoreCompatibility` updates `compatibility_score` on the scan after scoring.
    - `scoreCompatibility` logs AI usage on success with `feature: "shopping_score"`.
    - `scoreCompatibility` logs AI usage on failure with `feature: "shopping_score"`.
    - `scoreCompatibility` throws 502 when Gemini returns unparseable response.
    - `scoreCompatibility` clamps out-of-range scores to [0, 100].
    - `computeTier` maps scores to correct tiers (test all 5 boundary conditions: 0, 39, 40, 59, 60, 74, 75, 89, 90, 100).
    - `buildWardrobeSummary` returns per-item details for <= 50 items.
    - `buildWardrobeSummary` returns aggregated distributions for > 50 items.
    - `scoreCompatibility` works with 500+ items (uses summarized wardrobe).

- [x] Task 10: API -- Integration tests for scoring endpoint (AC: 1, 5, 6, 8)
  - [x] 10.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js`:
    - POST /v1/shopping/scans/:id/score returns 200 with score data on success.
    - POST /v1/shopping/scans/:id/score returns 404 for non-existent scan.
    - POST /v1/shopping/scans/:id/score returns 404 for another user's scan (RLS).
    - POST /v1/shopping/scans/:id/score returns 422 when wardrobe is empty.
    - POST /v1/shopping/scans/:id/score returns 502 when Gemini fails.
    - POST /v1/shopping/scans/:id/score returns 401 without authentication.
    - POST /v1/shopping/scans/:id/score does NOT consume usage quota.

- [x] Task 11: Mobile -- Widget tests for CompatibilityScoreScreen (AC: 4, 6, 8)
  - [x] 11.1: Create `apps/mobile/test/features/shopping/screens/compatibility_score_screen_test.dart`:
    - Renders loading state with product name and "Calculating compatibility..." text.
    - Displays score gauge with correct score on success.
    - Displays correct tier label, color, and icon.
    - Displays all 5 breakdown bars with correct labels and scores.
    - Displays reasoning text.
    - "View Matches & Insights" button is present but disabled.
    - Shows empty wardrobe state on 422 WARDROBE_EMPTY error.
    - "Go to Wardrobe" button is present in empty state.
    - Shows retry button on scoring failure.
    - Retry button re-triggers scoring call.
    - Semantics labels present on score gauge, tier, breakdown bars, buttons.

- [x] Task 12: Mobile -- Model tests for CompatibilityScoreResult (AC: 2, 3)
  - [x] 12.1: Create `apps/mobile/test/features/shopping/models/compatibility_score_result_test.dart`:
    - `CompatibilityScoreResult.fromJson` parses all fields correctly.
    - `ScoreBreakdown.fromJson` parses all 5 factor scores.
    - `ScoreTier.fromTierString` maps all 5 tiers to correct colors and icons.
    - Handles edge cases: score of 0, score of 100, missing reasoning.

- [x] Task 13: Mobile -- Update ProductReviewScreen tests (AC: 4)
  - [x] 13.1: Update `apps/mobile/test/features/shopping/screens/product_review_screen_test.dart`:
    - Tapping "Confirm" navigates to CompatibilityScoreScreen (not SnackBar placeholder).
    - Tapping "Skip Review" navigates to CompatibilityScoreScreen (not SnackBar placeholder).

- [x] Task 14: Mobile -- ShoppingScanService and ApiClient test updates (AC: 4)
  - [x] 14.1: Update `apps/mobile/test/core/networking/api_client_test.dart`: `scoreShoppingScan` calls POST /v1/shopping/scans/:id/score.
  - [x] 14.2: Add shopping scan service test to verify `scoreCompatibility` calls the correct API endpoint and returns a `CompatibilityScoreResult`.

- [x] Task 15: Regression testing (AC: all)
  - [x] 15.1: Run `flutter analyze` -- zero new issues.
  - [x] 15.2: Run `flutter test` -- all existing 1199+ tests plus new tests pass.
  - [x] 15.3: Run `npm --prefix apps/api test` -- all existing 774+ API tests plus new tests pass.
  - [x] 15.4: Verify existing URL scan pipeline still works (Story 8.1 functionality unchanged).
  - [x] 15.5: Verify existing screenshot scan pipeline still works (Story 8.2 functionality unchanged).
  - [x] 15.6: Verify existing review/edit pipeline still works (Story 8.3 PATCH endpoint unchanged).
  - [x] 15.7: Verify existing wardrobe item listing still works (listItems not broken by new usage).

## Dev Notes

- This is the FOURTH story in Epic 8 (Shopping Assistant). It adds the core AI-powered compatibility scoring engine that analyzes a potential purchase against the user's wardrobe. Stories 8.1-8.3 established the scan pipeline (URL/screenshot extraction, review/edit). This story adds the scoring. Story 8.5 will add match display, AI insights, and wishlist.
- The scoring is performed by a single Gemini 2.0 Flash call with a structured JSON response. The prompt provides the product metadata and a wardrobe summary, and Gemini returns scores for 5 weighted factors. The server computes (or validates) the weighted total and maps it to a 5-tier rating.
- The five scoring factors and weights are specified by FR-SHP-06: color harmony (30%), style consistency (25%), gap filling (20%), versatility (15%), formality match (10%). These weights are hardcoded in the prompt and validated server-side.
- For large wardrobes (>50 items), the wardrobe is summarized as distribution counts rather than per-item details. This keeps the Gemini prompt within token limits and satisfies NFR-PERF-09 (scales to 500+ item wardrobes). The 50-item boundary is a practical threshold: 50 items * ~60 tokens/item = ~3000 tokens, which is well within Gemini's context window. Above 50, distribution summaries (~500 tokens) are used instead.
- The `compatibility_score` column already exists on the `shopping_scans` table (created in Story 8.1, migration 024) as `INTEGER CHECK (compatibility_score BETWEEN 0 AND 100)` with a default of NULL. This story populates it.
- Scoring does NOT consume an additional usage quota. The `premiumGuard.checkUsageQuota` was already called during scan creation (Stories 8.1/8.2). The scoring endpoint only requires authentication and scan ownership (via RLS).
- AI usage is logged with `feature = "shopping_score"` (not `"shopping_scan"`) to distinguish scoring calls from extraction calls in the `ai_usage_log` table. This does NOT affect the usage quota which counts by `"shopping_scan"`.

### Compatibility Scoring Prompt

```
You are a wardrobe compatibility analyst. Score how well a potential purchase matches a user's existing wardrobe.

POTENTIAL PURCHASE:
{productJson}

USER'S WARDROBE:
{wardrobeSummary}

Score the purchase on these 5 factors (each 0-100):
1. color_harmony (30% weight): How well does the item's color coordinate with existing wardrobe colors? Consider complementary colors, neutral compatibility, and color palette diversity.
2. style_consistency (25% weight): How well does the item's style match the user's existing style profile? Consider style variety vs. cohesion.
3. gap_filling (20% weight): Does this item fill a gap in the wardrobe? Consider missing categories, underrepresented colors, or missing formality levels.
4. versatility (15% weight): How many existing items could this be paired with? Consider cross-category matching potential.
5. formality_match (10% weight): Does the item's formality level complement the wardrobe's formality range?

Calculate the weighted total: total = round(color_harmony * 0.30 + style_consistency * 0.25 + gap_filling * 0.20 + versatility * 0.15 + formality_match * 0.10)

Return ONLY valid JSON:
{
  "total": <integer 0-100>,
  "color_harmony": <integer 0-100>,
  "style_consistency": <integer 0-100>,
  "gap_filling": <integer 0-100>,
  "versatility": <integer 0-100>,
  "formality_match": <integer 0-100>,
  "reasoning": "<1-2 sentence explanation of the overall score>"
}
```

### Tier Mapping

```javascript
function computeTier(score) {
  if (score >= 90) return { tier: "perfect_match", label: "Perfect Match", color: "#22C55E", icon: "stars" };
  if (score >= 75) return { tier: "great_choice", label: "Great Choice", color: "#3B82F6", icon: "thumb_up" };
  if (score >= 60) return { tier: "good_fit", label: "Good Fit", color: "#F59E0B", icon: "check_circle" };
  if (score >= 40) return { tier: "might_work", label: "Might Work", color: "#F97316", icon: "help_outline" };
  return { tier: "careful", label: "Careful", color: "#EF4444", icon: "warning" };
}
```

### Wardrobe Summarization Strategy

For wardrobes with **<= 50 items**, serialize each item compactly:
```json
[
  { "category": "tops", "color": "navy", "style": "casual", "formality": 3, "season": ["fall", "winter"] },
  { "category": "bottoms", "color": "black", "style": "formal", "formality": 7, "season": ["all"] }
]
```

For wardrobes with **> 50 items**, aggregate into distributions:
```json
{
  "totalItems": 127,
  "categories": { "tops": 35, "bottoms": 28, "dresses": 12, "outerwear": 15, "shoes": 20, "accessories": 17 },
  "colors": { "black": 22, "navy": 18, "white": 15, "gray": 12, "beige": 10, "blue": 8, "other": 42 },
  "styles": { "casual": 45, "smart-casual": 30, "formal": 20, "sporty": 15, "other": 17 },
  "formalityRange": { "casual_1_3": 50, "mid_4_6": 52, "formal_7_10": 25 },
  "seasonCoverage": { "spring": 80, "summer": 65, "fall": 90, "winter": 70, "all": 40 },
  "occasionCoverage": { "everyday": 95, "work": 60, "formal": 30, "party": 25, "outdoor": 45 }
}
```

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/shopping/models/compatibility_score_result.dart`
  - `apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart`
  - `apps/mobile/test/features/shopping/models/compatibility_score_result_test.dart`
  - `apps/mobile/test/features/shopping/screens/compatibility_score_screen_test.dart`
- Modified API files:
  - `apps/api/src/modules/shopping/shopping-scan-service.js` (add `scoreCompatibility`, `buildWardrobeSummary`, `computeTier`, `COMPATIBILITY_SCORING_PROMPT`, update factory to accept `itemRepo`)
  - `apps/api/src/main.js` (add `POST /v1/shopping/scans/:id/score` route, update `createShoppingScanService` wiring to include `itemRepo`, add 502 to mapError if not present)
  - `apps/api/test/modules/shopping/shopping-scan-service.test.js` (add scoring tests)
  - `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js` (add scoring endpoint tests)
- Modified mobile files:
  - `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart` (add `scoreCompatibility`)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `scoreShoppingScan`)
  - `apps/mobile/lib/src/features/shopping/screens/product_review_screen.dart` (replace SnackBar placeholder with navigation to CompatibilityScoreScreen)
  - `apps/mobile/test/features/shopping/screens/product_review_screen_test.dart` (update confirm/skip tests)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add scoreShoppingScan test)

### Technical Requirements

- **Gemini 2.0 Flash** via existing `geminiClient` singleton. Use `responseMimeType: "application/json"` for structured output. Single call for scoring (not multiple parallel calls like Story 8.2).
- **Same taxonomy validation** for wardrobe items used in prompt construction. Import taxonomy constants from `apps/api/src/modules/ai/taxonomy.js` if needed for building summaries.
- **`itemRepo.listItems(authContext, {})`** fetches all user wardrobe items with no filters. The `listItems` method defaults to a limit of 200. For large wardrobes, this may need to be passed with an explicit higher limit (e.g., `{ limit: 1000 }`). Verify the default and adjust if needed to ensure all items are fetched.
- **No new database migration.** The `compatibility_score` column already exists on `shopping_scans` (migration 024, Story 8.1).
- **No new dependencies** on API or mobile.
- **`mapError` needs 502** for scoring failures. Check if 502 already exists in `mapError`. If not, add: `case 502: res.writeHead(502, headers); res.end(JSON.stringify({ error: body.error || "Bad Gateway", code: body.code, message: body.message })); break;`.

### Architecture Compliance

- **AI calls brokered only by Cloud Run.** The mobile client calls the API endpoint. The API calls Gemini. The mobile client never calls Gemini directly.
- **No additional rate limiting on scoring.** The usage quota was already consumed during scan creation. Scoring is a follow-up operation on an existing scan.
- **RLS on shopping_scans.** The scoring endpoint uses `getScanById` which enforces RLS. Users can only score their own scans.
- **Server-side score computation.** The weighted total is computed/validated server-side, not trusted from Gemini alone. If Gemini's reported total doesn't match the weighted calculation, use the server-computed value.
- **Epic 8 component mapping:** `mobile/features/shopping`, `api/modules/shopping`, `api/modules/ai` (architecture.md).
- **Error handling standard:** 401 for auth, 404 for not found (RLS), 422 for empty wardrobe, 502 for Gemini failure.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `@google-cloud/vertexai` via `geminiClient`, existing `itemRepo` for wardrobe fetching, existing `shoppingScanRepo` for scan updates.
- **Mobile:** No new dependencies. Uses existing Flutter material widgets (`CircularProgressIndicator`, `LinearProgressIndicator` or `CustomPainter` for gauge, `Card`, `ListView`), existing `api_client.dart`, existing navigation patterns.

### File Structure Requirements

- `apps/mobile/lib/src/features/shopping/models/` already exists from Story 8.1. New `compatibility_score_result.dart` goes here.
- `apps/mobile/lib/src/features/shopping/screens/` already exists from Story 8.1. New `compatibility_score_screen.dart` goes here.
- Test files mirror source structure.
- No new API files. All API changes are modifications to existing files.

### Testing Requirements

- **API tests** extend existing files from Stories 8.1-8.3. Use the same Node.js built-in test runner patterns.
- **Mock the Gemini client** in scoring service tests. Return pre-defined JSON responses for different scenarios (high score, low score, invalid response, timeout).
- **Mock the `itemRepo`** to return controlled wardrobe item sets (empty, small, large).
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Target:** All existing tests continue to pass (774 API tests, 1199 Flutter tests from Story 8.3) plus new tests.

### Previous Story Intelligence

- **Story 8.3** (done, predecessor) established: `PATCH /v1/shopping/scans/:id` endpoint, `updateScan` repository method, `validateScanUpdate` function, `ProductReviewScreen` with chips/slider/text fields, `ShoppingScan.copyWith` and `toJson` methods, `authenticatedPatch` on ApiClient, `taxonomy_constants.dart` mobile file. The Confirm and Skip Review buttons currently show SnackBar placeholders for Story 8.4. **774 API tests, 1199 Flutter tests.** 33 services in `createRuntime()`.
- **Story 8.2** (done) established: `scanScreenshot` method, parallel Gemini calls via `Promise.all`, `SCREENSHOT_TEXT_PROMPT`, screenshot upload flow. 750 API tests, 1178 Flutter tests.
- **Story 8.1** (done) established: `shopping_scans` table (024 migration) with `compatibility_score INTEGER CHECK (compatibility_score BETWEEN 0 AND 100)` column (NULL by default, populated by this story), `shopping-scan-service.js` with `scanUrl()` + `downloadImage()` + `PRODUCT_IMAGE_PROMPT` + `validateFormalityScore()` + `estimateCost()`, `shopping-scan-repository.js` with `createScan()` / `getScanById()` / `listScans()` / `updateScan()` / `mapScanRow()`, `ShoppingScan` Dart model, `ShoppingScanService`, `ShoppingScanScreen`. **738 API tests, 1171 Flutter tests.**
- **Story 4.1** (done) established: Gemini outfit generation pattern -- sending wardrobe item data to Gemini for AI analysis. Similar concept but for outfit generation rather than scoring. Use as a reference for prompt construction patterns.
- **`createRuntime()` returns 33 services** (as of Story 8.3). This story adds `itemRepo` as a dependency to `shoppingScanService` but does NOT create a new service. Verify that `itemRepo` is available as a standalone variable in `createRuntime()`. Looking at `main.js`, `createItemService({ repo: itemRepo })` indicates `itemRepo` is created separately. Pass it to `createShoppingScanService`.
- **`handleRequest` destructuring** includes `shoppingScanService`, `shoppingScanRepo`, `itemService` from previous stories. The new route uses `shoppingScanService.scoreCompatibility` so no changes to the destructuring are needed.
- **`mapError` function** handles 400, 401, 403, 404, 409, 422, 429, 500, 503. This story adds 502 for Gemini scoring failures.
- **Key patterns from all previous stories:**
  - Factory pattern for API services: `createXxxService({ deps })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories.
  - Semantics labels on all interactive elements.
  - Best-effort for non-critical operations (try/catch).
  - Taxonomy validation with safe defaults for all Gemini output.
  - `responseMimeType: "application/json"` for structured Gemini responses.
  - AI usage logging with separate feature names per operation type.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. All AI scoring calls go through the Cloud Run API.
- DO NOT create a new Gemini client or service factory. Add `scoreCompatibility` to the existing `createShoppingScanService`.
- DO NOT create a new database migration. The `compatibility_score` column already exists on `shopping_scans`.
- DO NOT consume an additional usage quota for scoring. The quota was already consumed during scan creation.
- DO NOT send the full wardrobe item list directly to Gemini for large wardrobes. Summarize items >50 into distribution counts to stay within token limits.
- DO NOT trust Gemini's weighted total without validation. Compute the weighted total server-side from the individual factor scores and use that value if it differs from Gemini's reported total.
- DO NOT log scoring AI usage with `feature = "shopping_scan"`. Use `feature = "shopping_score"` to distinguish scoring calls.
- DO NOT implement match display, AI insights, or wishlist. Those are Story 8.5.
- DO NOT modify the existing `scanUrl`, `scanScreenshot`, or `validateScanUpdate` methods. This story only adds `scoreCompatibility`, `buildWardrobeSummary`, and `computeTier`.
- DO NOT skip AI usage logging on failure. Both success and failure must be logged for observability.
- DO NOT block on Gemini failure. Return a clear 502 error so the mobile app can show a retry button.
- DO NOT use `items.length > 50` as a hard failure. The summarization strategy handles any wardrobe size gracefully.
- DO NOT re-fetch the scan after updating `compatibility_score`. The `updateScan` method returns the updated scan, use that directly.

### Out of Scope

- **Match display (top matching items from wardrobe)** (Story 8.5 -- FR-SHP-08)
- **AI-generated insights (style feedback, gap assessment, value proposition)** (Story 8.5 -- FR-SHP-09)
- **Wishlist save functionality** (Story 8.5 -- FR-SHP-10)
- **Empty wardrobe CTA on initial scan screen** (Story 8.5 -- FR-SHP-12)
- **Re-scoring after metadata edits** -- user must re-trigger scoring manually
- **Offline scoring** -- requires Gemini API access
- **Score history or trends** -- future enhancement

### References

- [Source: epics.md - Story 8.4: Purchase Compatibility Scoring]
- [Source: epics.md - Epic 8: Shopping Assistant, FR-SHP-06, FR-SHP-07]
- [Source: prd.md - FR-SHP-06: The system shall calculate a compatibility score (0-100) based on: color harmony (30%), style consistency (25%), gap filling (20%), versatility (15%), formality match (10%)]
- [Source: prd.md - FR-SHP-07: The compatibility score shall be displayed with a 5-tier rating system: Perfect Match (90-100), Great Choice (75-89), Good Fit (60-74), Might Work (40-59), Careful (0-39), each with distinct color and icon]
- [Source: prd.md - NFR-PERF-09: Compatibility scoring algorithm scales to 500+ item wardrobes]
- [Source: prd.md - FR-SHP-12: The system shall display an empty wardrobe CTA when no items exist for scoring]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Epic 8 Shopping Assistant -> mobile/features/shopping, api/modules/shopping, api/modules/ai]
- [Source: architecture.md - Taxonomy validation on structured outputs, safe defaults when AI confidence is low]
- [Source: architecture.md - Important tables: shopping_scans, shopping_wishlists]
- [Source: 8-1-product-url-scraping.md - shopping_scans table with compatibility_score column, PRODUCT_IMAGE_PROMPT, downloadImage, validateFormalityScore, estimateCost, ShoppingScan model, 738 API tests, 1171 Flutter tests]
- [Source: 8-2-product-screenshot-upload.md - parallel Gemini calls, screenshot analysis, shared quota, 750 API tests, 1178 Flutter tests]
- [Source: 8-3-review-extracted-product-data.md - PATCH endpoint, ProductReviewScreen with Confirm/Skip placeholders for Story 8.4, validateScanUpdate, taxonomy_constants.dart, 774 API tests, 1199 Flutter tests]
- [Source: apps/api/src/modules/shopping/shopping-scan-service.js - existing service with scanUrl, scanScreenshot, validateScanUpdate, PRODUCT_IMAGE_PROMPT, estimateCost, downloadImage, validateFormalityScore]
- [Source: apps/api/src/modules/shopping/shopping-scan-repository.js - createScan, getScanById, listScans, updateScan, mapScanRow]
- [Source: apps/api/src/modules/items/repository.js - listItems with filters, mapItemRow with category/color/style/season/occasion/formalityScore fields]
- [Source: apps/api/src/modules/ai/taxonomy.js - VALID_CATEGORIES, VALID_COLORS, VALID_STYLES, etc.]
- [Source: apps/api/src/main.js - createRuntime with 33 services, handleRequest destructuring, mapError, shopping routes]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None -- no halts or issues encountered.

### Completion Notes List

- Implemented Gemini-based compatibility scoring service (`scoreCompatibility`) with 5-factor weighted scoring (color harmony 30%, style consistency 25%, gap filling 20%, versatility 15%, formality match 10%).
- Server-side weighted total computation validates/overrides Gemini's reported total. All factor scores clamped to [0, 100].
- `buildWardrobeSummary` uses per-item detail for <= 50 items, aggregated distribution counts for > 50 items (NFR-PERF-09).
- `computeTier` maps score to 5-tier rating system (Perfect Match, Great Choice, Good Fit, Might Work, Careful) with colors and icons.
- Added `POST /v1/shopping/scans/:id/score` endpoint before the PATCH route; 502 added to mapError.
- `createShoppingScanService` factory now accepts `itemRepo` dependency; wired in `createRuntime()`.
- `compatibilityScore` field added to `updateScan` repository fieldMap.
- Created `CompatibilityScoreResult` model (Dart) with `ScoreBreakdown` and `ScoreTier` classes.
- Created `CompatibilityScoreScreen` with animated circular gauge (CustomPainter), tier display, 5-factor breakdown bars, empty wardrobe state, error/retry state, Semantics labels.
- `ProductReviewScreen` Confirm/Skip now navigate to `CompatibilityScoreScreen` instead of showing SnackBar placeholder.
- Added `scoreShoppingScan` to ApiClient and `scoreCompatibility` to ShoppingScanService (Dart).
- AI usage logged with `feature: "shopping_score"` (distinct from `"shopping_scan"`).
- No usage quota consumed for scoring -- quota already consumed during scan creation.
- 802 API tests passing (774 baseline + 28 new). 1227 Flutter tests passing (1199 baseline + 28 new).

### Change Log

- 2026-03-19: Story 8.4 implementation complete -- Gemini compatibility scoring service, POST /v1/shopping/scans/:id/score endpoint, CompatibilityScoreScreen with animated gauge and 5-factor breakdown.

### File List

New files:
- apps/mobile/lib/src/features/shopping/models/compatibility_score_result.dart
- apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart
- apps/mobile/test/features/shopping/models/compatibility_score_result_test.dart
- apps/mobile/test/features/shopping/screens/compatibility_score_screen_test.dart
- apps/mobile/test/features/shopping/services/shopping_scan_service_test.dart

Modified files:
- apps/api/src/modules/shopping/shopping-scan-service.js (added scoreCompatibility, buildWardrobeSummary, computeTier, COMPATIBILITY_SCORING_PROMPT, clampScore; updated factory to accept itemRepo)
- apps/api/src/modules/shopping/shopping-scan-repository.js (added compatibilityScore to updateScan fieldMap)
- apps/api/src/main.js (added POST /v1/shopping/scans/:id/score route, 502 to mapError, itemRepo to createShoppingScanService wiring)
- apps/api/test/modules/shopping/shopping-scan-service.test.js (added 22 scoring tests)
- apps/api/test/modules/shopping/shopping-scan-endpoint.test.js (added 7 scoring endpoint tests)
- apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart (added scoreCompatibility method)
- apps/mobile/lib/src/core/networking/api_client.dart (added scoreShoppingScan method)
- apps/mobile/lib/src/features/shopping/screens/product_review_screen.dart (replaced SnackBar placeholders with CompatibilityScoreScreen navigation)
- apps/mobile/test/features/shopping/screens/product_review_screen_test.dart (updated confirm/skip tests for navigation)
- apps/mobile/test/core/networking/api_client_test.dart (added scoreShoppingScan test)
