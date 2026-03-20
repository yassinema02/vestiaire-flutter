# Story 8.5: Shopping Match & Insight Display

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see exactly why an item scored the way it did and what I can wear it with,
so that I make an informed purchase decision.

## Acceptance Criteria

1. Given the compatibility scoring is complete (Story 8.4) and the user taps "View Matches & Insights" on the `CompatibilityScoreScreen`, when the button is tapped, then the app calls `POST /v1/shopping/scans/:id/insights` which: (a) fetches the scored scan, (b) fetches all user wardrobe items, (c) constructs a Gemini 2.0 Flash prompt containing the product metadata, the score breakdown, and the wardrobe items, (d) returns structured JSON with top matching items (up to 10) and 3 AI-generated insights. The "View Matches & Insights" button is now enabled (no longer disabled placeholder). (FR-SHP-08, FR-SHP-09)

2. Given the insights endpoint receives a request, when Gemini returns the response, then the API updates the `insights` JSONB column on the `shopping_scans` row with `{ matches: [...], insights: [...] }` and returns `{ scan: { ...updatedScan }, matches: [ { itemId, itemName, itemImageUrl, category, matchReasons: [string] } ], insights: [ { type: "style_feedback"|"gap_assessment"|"value_proposition", title: string, body: string, icon: string } ], status: "analyzed" }`. (FR-SHP-08, FR-SHP-09, FR-SHP-11)

3. Given the top matching items are returned, when the results are displayed, then the matches are shown grouped by category (e.g., "Tops", "Bottoms", "Shoes") in horizontal scrollable rows. Each match card shows the item image (48x48 rounded), item name, and a concise match reason (e.g., "Complementary navy pairs well"). Up to 10 matches total, prioritized by match quality. If no matches are found, a "No close matches found" empty state is shown. (FR-SHP-08)

4. Given the 3 AI-generated insights are returned, when the results are displayed, then each insight is rendered as a card with: an icon (style_feedback = `Icons.palette`, gap_assessment = `Icons.space_dashboard`, value_proposition = `Icons.trending_up`), a title (bold, 16px), and a body paragraph (14px, secondary text). The three insight types are: (a) Style Feedback -- how the item fits the user's overall style, (b) Gap Assessment -- whether the item fills a wardrobe gap or duplicates existing items, (c) Value Proposition -- whether the price is justified given wardrobe utility. (FR-SHP-09)

5. Given the user is on the Match & Insight screen, when the user taps "Save to Wishlist", then the app calls `PATCH /v1/shopping/scans/:id` with `{ wishlisted: true }` and the scan's `wishlisted` column is set to `true`. The button toggles to "Saved" with a filled bookmark icon. Tapping again calls PATCH with `{ wishlisted: false }` to un-wishlist. (FR-SHP-10)

6. Given the user has previously generated insights for a scan (the `insights` JSONB column is not null), when the user navigates back to the Match & Insight screen for the same scan, then the app loads cached insights from the scan object rather than re-calling Gemini. The insights endpoint checks if `insights` is already populated and returns the cached data without making a new AI call. (FR-SHP-11, NFR-PERF-09)

7. Given the user's wardrobe is empty (0 items), when the user attempts to view matches and insights, then the API returns HTTP 422 with `{ error: "Wardrobe Empty", code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first to see matches and insights." }` and the screen shows an empty-state card with an `Icons.checkroom` icon, a message "Add items to your wardrobe first", and a "Go to Wardrobe" button navigating to the Wardrobe tab. (FR-SHP-12)

8. Given the scan has NOT been scored (compatibility_score is NULL), when the insights endpoint is called, then the API returns HTTP 422 with `{ error: "Not Scored", code: "NOT_SCORED", message: "Score the product first before viewing matches and insights." }` and the mobile screen navigates back to the CompatibilityScoreScreen. (FR-SHP-08)

9. Given the Gemini insight generation call fails (timeout, parse error, or no useful response), when the error occurs, then the API returns HTTP 502 with `{ error: "Insight Generation Failed", code: "INSIGHT_FAILED", message: "Unable to generate insights. Please try again." }` and logs the failure to `ai_usage_log` with `feature = "shopping_insight"`. The mobile screen shows a retry button. (NFR-REL-03)

10. Given the API processes an insights request, when the Gemini call is made, then the API logs the request to `ai_usage_log` with `feature = "shopping_insight"`, model name, input/output tokens, latency in ms, estimated cost, and status `"success"` or `"failure"`. This does NOT consume an additional usage quota. (NFR-OBS-02)

11. Given the `wishlisted` field is updated, when the repository updates the scan, then the existing `updateScan` method (Story 8.3) already supports updating fields via the fieldMap. Add `wishlisted` to the `updateScan` fieldMap in the repository. The `validateScanUpdate` function (Story 8.3) also needs to accept `wishlisted` as a boolean field. (FR-SHP-10)

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (802+ API tests, 1227+ Flutter tests) and new tests cover: insights endpoint (success, cached, empty wardrobe, not scored, auth, Gemini failure), insights service logic (prompt construction, response parsing, match extraction, caching), MatchInsightScreen widget (matches grouped by category, insight cards, wishlist toggle, empty wardrobe state, retry on error, cached load), ApiClient insights method, ShoppingScanService insights method, wishlist toggle, and updated repository/validation for `wishlisted` and `insights` fields.

## Tasks / Subtasks

- [x] Task 1: API -- Add insight generation to shopping scan service (AC: 1, 2, 6, 8, 9, 10)
  - [x] 1.1: In `apps/api/src/modules/shopping/shopping-scan-service.js`, add a new method `async generateInsights(authContext, { scanId })` to the service object returned by `createShoppingScanService`. This method: (a) fetches the scan via `shoppingScanRepo.getScanById(authContext, scanId)`, (b) if scan not found, throw 404, (c) if `scan.compatibilityScore === null`, throw 422 with `code: "NOT_SCORED"`, (d) if `scan.insights !== null`, return cached data: `{ scan, matches: scan.insights.matches, insights: scan.insights.insights, status: "analyzed" }` without calling Gemini, (e) fetches all user wardrobe items via `itemRepo.listItems(authContext, { limit: 1000 })`, (f) if items.length === 0, throw 422 with `code: "WARDROBE_EMPTY"`, (g) builds the insight prompt with product metadata, score breakdown, and wardrobe items, (h) calls Gemini 2.0 Flash with `responseMimeType: "application/json"`, (i) parses the structured response, (j) validates matches reference real item IDs from the wardrobe, (k) stores the result in the `insights` JSONB column via `shoppingScanRepo.updateScan(authContext, scanId, { insights: { matches, insights } })`, (l) logs AI usage, (m) returns `{ scan: updatedScan, matches, insights, status: "analyzed" }`.
  - [x] 1.2: Add a `MATCH_INSIGHT_PROMPT` constant. The prompt instructs Gemini to: (1) identify the top matching wardrobe items (up to 10) that pair well with the potential purchase, with a brief reason for each match, and (2) generate exactly 3 insights: one `style_feedback`, one `gap_assessment`, one `value_proposition`. Return structured JSON: `{ "matches": [ { "item_id": "<uuid>", "reason": "<1 sentence>" } ], "insights": [ { "type": "style_feedback", "title": "<short title>", "body": "<2-3 sentence analysis>" }, { "type": "gap_assessment", "title": "...", "body": "..." }, { "type": "value_proposition", "title": "...", "body": "..." } ] }`. The prompt provides the product metadata, compatibility score breakdown, and wardrobe item list (with IDs, names, categories, colors, imageUrls).
  - [x] 1.3: For match validation, filter the returned `matches` array to only include items whose `item_id` exists in the user's wardrobe items array. Discard any matches referencing non-existent IDs (Gemini may hallucinate IDs). Enrich each valid match with the item's `productName` (or item name), `imageUrl`, and `category` from the wardrobe data.
  - [x] 1.4: For insight validation, ensure exactly 3 insights are returned with valid types. If Gemini returns fewer than 3 or invalid types, fill in missing insight types with a generic fallback: `{ type: "<missing_type>", title: "Analysis Unavailable", body: "We couldn't generate this insight for this product." }`.

- [x] Task 2: API -- Wire insights endpoint (AC: 1, 7, 8, 9, 10)
  - [x] 2.1: Add route `POST /v1/shopping/scans/:id/insights` in `apps/api/src/main.js`. This endpoint: (a) authenticates the user via `requireAuth`, (b) extracts `scanId` from URL path using regex `url.pathname.match(/^\/v1\/shopping\/scans\/([^/]+)\/insights$/)`, (c) calls `shoppingScanService.generateInsights(authContext, { scanId })`, (d) returns 200 with the insights result. Error mapping: 404 for not found, 422 for empty wardrobe or not scored, 502 for insight generation failure.
  - [x] 2.2: Place the route BEFORE the existing `POST /v1/shopping/scans/:id/score` route to prevent path conflict. The `/insights` suffix must match before the `/score` suffix regex.

- [x] Task 3: API -- Update repository and validation for `wishlisted` and `insights` (AC: 5, 11)
  - [x] 3.1: In `apps/api/src/modules/shopping/shopping-scan-repository.js`, add `wishlisted: "wishlisted"` and `insights: "insights"` to the `updateScan` fieldMap. For the `insights` field, use `$N::jsonb` type cast in the SET clause (similar to `::text[]` for arrays). For `wishlisted`, no type cast needed (boolean).
  - [x] 3.2: In `apps/api/src/modules/shopping/shopping-scan-service.js`, update `validateScanUpdate(body)` to accept `wishlisted` as an optional boolean field. Validate: if present, must be `true` or `false` (strict boolean). Add to sanitized data.

- [x] Task 4: Mobile -- Add `generateInsights` method to ShoppingScanService (AC: 1)
  - [x] 4.1: In `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart`, add method `Future<MatchInsightResult> generateInsights(String scanId)` that calls `_apiClient.authenticatedPost("/v1/shopping/scans/$scanId/insights")` and returns a parsed `MatchInsightResult`.

- [x] Task 5: Mobile -- Create MatchInsightResult model (AC: 2, 3, 4)
  - [x] 5.1: Create `apps/mobile/lib/src/features/shopping/models/match_insight_result.dart` with classes:
    - `WardrobeMatch`: `String itemId`, `String? itemName`, `String? itemImageUrl`, `String? category`, `List<String> matchReasons`. Factory `fromJson`.
    - `ShoppingInsight`: `String type`, `String title`, `String body`, `IconData icon`. Factory `fromJson` that maps type to icon: `style_feedback` -> `Icons.palette`, `gap_assessment` -> `Icons.space_dashboard`, `value_proposition` -> `Icons.trending_up`.
    - `MatchInsightResult`: `ShoppingScan scan`, `List<WardrobeMatch> matches`, `List<ShoppingInsight> insights`. Factory `fromJson(Map<String, dynamic> json)`.

- [x] Task 6: Mobile -- Add `generateInsights` and `toggleWishlist` methods to ApiClient (AC: 1, 5)
  - [x] 6.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add method `Future<Map<String, dynamic>> generateShoppingInsights(String scanId)` that calls `authenticatedPost("/v1/shopping/scans/$scanId/insights")`. Place adjacent to existing `scoreShoppingScan` method.
  - [x] 6.2: The wishlist toggle reuses the existing `updateShoppingScan` method (Story 8.3) with `{ "wishlisted": true/false }`. No new ApiClient method needed for wishlist.

- [x] Task 7: Mobile -- Create MatchInsightScreen (AC: 1, 3, 4, 5, 6, 7, 8, 9)
  - [x] 7.1: Create `apps/mobile/lib/src/features/shopping/screens/match_insight_screen.dart` with `MatchInsightScreen` StatefulWidget. Constructor: `{ required String scanId, required ShoppingScan scan, required ShoppingScanService shoppingScanService, super.key }`.
  - [x] 7.2: On `initState`, check if `scan.insights != null` (cached). If cached, parse directly from `scan.insights` and display immediately without API call. If not cached, call `shoppingScanService.generateInsights(scanId)` and show a loading state: product image/name at top with "Finding matches & generating insights..." and a pulsing animation.
  - [x] 7.3: On success, display the screen in a `SingleChildScrollView` with these sections in order:
    (a) **Product Header** -- compact product image (80px), name, brand, score badge (tier color circle with score number).
    (b) **Top Matches** section -- heading "Top Wardrobe Matches" with match count. If matches exist, group them by category into horizontal `ListView` rows. Each match card: item image (48x48 rounded, with placeholder if no image), item name (12px), match reason (11px secondary text). If no matches, show an empty state: "No close matches found in your wardrobe."
    (c) **AI Insights** section -- heading "AI Insights". Three insight cards, each with: colored icon on the left (palette=indigo, space_dashboard=teal, trending_up=green), title (bold, 16px), body text (14px, secondary color). Cards have 16px border radius, subtle shadow.
    (d) **Wishlist Button** -- at the bottom: if not wishlisted, show `OutlinedButton.icon` with `Icons.bookmark_border` and text "Save to Wishlist". If wishlisted, show `ElevatedButton.icon` with `Icons.bookmark` (filled) and text "Saved to Wishlist" with primary accent color. Tapping toggles the wishlist state via `shoppingScanService.updateScan(scanId, { "wishlisted": !currentState })` and updates `_isWishlisted` state with `mounted` guard.
  - [x] 7.4: On empty wardrobe (422 WARDROBE_EMPTY), display an empty-state card: icon `Icons.checkroom`, title "Your wardrobe is empty", subtitle "Add items to your wardrobe first to see matches and insights.", and a "Go to Wardrobe" `ElevatedButton` that navigates to the Wardrobe tab.
  - [x] 7.5: On not scored (422 NOT_SCORED), pop back to previous screen (CompatibilityScoreScreen) with a SnackBar: "Score the product first".
  - [x] 7.6: On insight generation failure (502 or other error), display an error card with "Couldn't generate insights" message and a "Retry" `ElevatedButton` that re-triggers `generateInsights`.
  - [x] 7.7: Add `Semantics` labels on: product header ("Product: name, score: X"), each match card ("Match: item name, reason"), each insight card ("Insight: title"), wishlist button, retry button, Go to Wardrobe button.
  - [x] 7.8: Follow Vibrant Soft-UI design: 16px border radius, subtle shadows, tier color for score badge, `#F3F4F6` background, `#1F2937` text, `#6B7280` secondary text, `#4F46E5` primary accent.

- [x] Task 8: Mobile -- Update CompatibilityScoreScreen to enable "View Matches & Insights" button (AC: 1)
  - [x] 8.1: In `apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart`, replace the disabled "View Matches & Insights - Coming Soon" `OutlinedButton` with an enabled `ElevatedButton` styled with primary accent. On tap, navigate to `MatchInsightScreen` passing `scanId`, `scan` (with updated compatibility score from the scoring result), and `shoppingScanService`.
  - [x] 8.2: Remove the "Coming Soon" text. The button label should be "View Matches & Insights".

- [x] Task 9: Mobile -- Add `insights` field to ShoppingScan model (AC: 6)
  - [x] 9.1: In `apps/mobile/lib/src/features/shopping/models/shopping_scan.dart`, the `ShoppingScan` model already has no `insights` field in the Dart class. Add `final Map<String, dynamic>? insights;` field. Update `fromJson` to parse `json["insights"]` as `Map<String, dynamic>?`. Update `copyWith` to include `insights`. The `toJson` method does NOT need to include `insights` (it's server-managed, not user-editable).

- [x] Task 10: API -- Unit tests for insight generation service (AC: 1, 2, 6, 7, 8, 9, 10)
  - [x] 10.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-service.test.js`:
    - `generateInsights` fetches scan, wardrobe items, calls Gemini, returns matches and insights.
    - `generateInsights` throws 404 when scan not found.
    - `generateInsights` throws 422 when wardrobe is empty.
    - `generateInsights` throws 422 when scan has no compatibility score (NOT_SCORED).
    - `generateInsights` returns cached insights without calling Gemini when `scan.insights` is not null.
    - `generateInsights` updates `insights` JSONB column on the scan after generation.
    - `generateInsights` logs AI usage on success with `feature: "shopping_insight"`.
    - `generateInsights` logs AI usage on failure with `feature: "shopping_insight"`.
    - `generateInsights` throws 502 when Gemini returns unparseable response.
    - `generateInsights` filters out matches with non-existent item IDs.
    - `generateInsights` fills in missing insight types with generic fallback.
    - `validateScanUpdate` accepts `wishlisted: true` and `wishlisted: false`.
    - `validateScanUpdate` rejects non-boolean `wishlisted` values.

- [x] Task 11: API -- Integration tests for insights endpoint (AC: 1, 7, 8, 9)
  - [x] 11.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js`:
    - POST /v1/shopping/scans/:id/insights returns 200 with matches and insights on success.
    - POST /v1/shopping/scans/:id/insights returns 200 with cached data when insights already exist.
    - POST /v1/shopping/scans/:id/insights returns 404 for non-existent scan.
    - POST /v1/shopping/scans/:id/insights returns 404 for another user's scan (RLS).
    - POST /v1/shopping/scans/:id/insights returns 422 when wardrobe is empty.
    - POST /v1/shopping/scans/:id/insights returns 422 when scan is not scored.
    - POST /v1/shopping/scans/:id/insights returns 502 when Gemini fails.
    - POST /v1/shopping/scans/:id/insights returns 401 without authentication.
    - PATCH /v1/shopping/scans/:id with `{ wishlisted: true }` updates the wishlisted column.
    - PATCH /v1/shopping/scans/:id with `{ wishlisted: false }` un-wishlists.

- [x] Task 12: Mobile -- Widget tests for MatchInsightScreen (AC: 1, 3, 4, 5, 6, 7, 8, 9)
  - [x] 12.1: Create `apps/mobile/test/features/shopping/screens/match_insight_screen_test.dart`:
    - Renders loading state with product name and "Finding matches" text.
    - Displays match cards grouped by category on success.
    - Each match card shows item image, name, and reason.
    - Shows "No close matches found" when matches list is empty.
    - Displays 3 insight cards with correct icons, titles, and bodies.
    - Wishlist button shows "Save to Wishlist" when not wishlisted.
    - Tapping wishlist button calls updateScan with `{ wishlisted: true }`.
    - Wishlist button toggles to "Saved to Wishlist" after save.
    - Shows empty wardrobe state on 422 WARDROBE_EMPTY error.
    - "Go to Wardrobe" button is present in empty state.
    - Shows retry button on insight generation failure.
    - Retry button re-triggers generateInsights call.
    - Loads cached insights from scan.insights without API call.
    - Semantics labels present on match cards, insight cards, wishlist button.

- [x] Task 13: Mobile -- Model tests for MatchInsightResult (AC: 2, 3, 4)
  - [x] 13.1: Create `apps/mobile/test/features/shopping/models/match_insight_result_test.dart`:
    - `MatchInsightResult.fromJson` parses all fields correctly.
    - `WardrobeMatch.fromJson` parses item fields and match reasons.
    - `ShoppingInsight.fromJson` maps all 3 types to correct icons.
    - Handles edge cases: empty matches array, missing insight body.

- [x] Task 14: Mobile -- Update CompatibilityScoreScreen tests (AC: 1)
  - [x] 14.1: Update `apps/mobile/test/features/shopping/screens/compatibility_score_screen_test.dart`:
    - "View Matches & Insights" button is now enabled (not disabled).
    - Tapping "View Matches & Insights" navigates to MatchInsightScreen.

- [x] Task 15: Mobile -- ShoppingScanService and ApiClient test updates (AC: 1, 5)
  - [x] 15.1: Update `apps/mobile/test/core/networking/api_client_test.dart`: `generateShoppingInsights` calls POST /v1/shopping/scans/:id/insights.
  - [x] 15.2: Add shopping scan service test to verify `generateInsights` calls the correct API endpoint and returns a `MatchInsightResult`.
  - [x] 15.3: Add test verifying wishlist toggle calls `updateShoppingScan` with `{ wishlisted: true/false }`.

- [x] Task 16: Mobile -- ShoppingScan model test updates (AC: 9)
  - [x] 16.1: Update `apps/mobile/test/features/shopping/models/shopping_scan_test.dart`:
    - `fromJson` parses `insights` field as `Map<String, dynamic>?`.
    - `copyWith` updates `insights` field.

- [x] Task 17: Regression testing (AC: all)
  - [x] 17.1: Run `flutter analyze` -- zero new issues.
  - [x] 17.2: Run `flutter test` -- all existing 1227+ tests plus new tests pass.
  - [x] 17.3: Run `npm --prefix apps/api test` -- all existing 802+ API tests plus new tests pass.
  - [x] 17.4: Verify existing URL scan pipeline still works (Story 8.1 functionality unchanged).
  - [x] 17.5: Verify existing screenshot scan pipeline still works (Story 8.2 functionality unchanged).
  - [x] 17.6: Verify existing review/edit pipeline still works (Story 8.3 PATCH endpoint unchanged, now also accepts `wishlisted`).
  - [x] 17.7: Verify existing scoring pipeline still works (Story 8.4 POST /score endpoint unchanged).
  - [x] 17.8: Verify existing wardrobe item listing still works (listItems not broken by new usage).

## Dev Notes

- This is the FIFTH and FINAL story in Epic 8 (Shopping Assistant). It completes the shopping scan pipeline by adding wardrobe match display, AI-generated insights, and wishlist functionality. Stories 8.1-8.4 established: URL/screenshot scanning, metadata review/edit, and compatibility scoring. This story adds the "why" behind the score and actionable intelligence.
- The insights are generated by a single Gemini 2.0 Flash call that receives the product metadata, the score breakdown (from Story 8.4), and the user's wardrobe items (with IDs for match references). Gemini returns both the top matching items and 3 categorized insights in a single structured JSON response.
- The `insights` JSONB column already exists on the `shopping_scans` table (created in Story 8.1, migration 024). This story populates it. The `wishlisted` BOOLEAN column also already exists (default FALSE). This story provides the UI toggle.
- Insight caching is critical for performance: once generated, insights are stored in the `insights` column and returned directly on subsequent requests without re-calling Gemini. The `generateInsights` method checks `scan.insights !== null` before making any AI call.
- AI usage is logged with `feature = "shopping_insight"` (not `"shopping_scan"` or `"shopping_score"`) to distinguish insight generation calls. This does NOT affect usage quota.
- The Gemini prompt includes wardrobe item IDs so that matches can reference specific items. However, Gemini may hallucinate IDs, so the server MUST validate that each returned `item_id` exists in the user's wardrobe array. Invalid matches are silently discarded.
- The 3 insight types are fixed: `style_feedback`, `gap_assessment`, `value_proposition`. If Gemini omits any, the server fills in a generic fallback. This ensures the UI always has 3 cards to display.

### Match & Insight Generation Prompt

```
You are a wardrobe style analyst. Analyze how a potential purchase fits into a user's existing wardrobe.

POTENTIAL PURCHASE:
{productJson}

COMPATIBILITY SCORE BREAKDOWN:
{scoreBreakdown}

USER'S WARDROBE ITEMS:
{wardrobeItems}

Provide two things:

1. TOP MATCHES: Identify up to 10 wardrobe items that would pair best with this purchase. For each, explain briefly why they match well (color coordination, style compatibility, occasion pairing, etc.).

2. THREE INSIGHTS:
   a) style_feedback: How does this item fit the user's overall style? Is it consistent or a new direction?
   b) gap_assessment: Does this item fill a wardrobe gap, or does it duplicate something they already own?
   c) value_proposition: Given the price and how much use they'd likely get, is this a good investment?

Return ONLY valid JSON:
{
  "matches": [
    { "item_id": "<uuid from wardrobe list>", "reason": "<1 sentence>" }
  ],
  "insights": [
    { "type": "style_feedback", "title": "<short title>", "body": "<2-3 sentence analysis>" },
    { "type": "gap_assessment", "title": "<short title>", "body": "<2-3 sentence analysis>" },
    { "type": "value_proposition", "title": "<short title>", "body": "<2-3 sentence analysis>" }
  ]
}
```

### Wardrobe Items for Insight Prompt

Unlike the scoring prompt (Story 8.4) which uses a summarized wardrobe for token efficiency, the insight prompt needs individual item IDs for match references. Use the same 50-item threshold:
- **<= 50 items:** Send each item with `{ id, name, imageUrl, category, color, style, formalityScore }`.
- **> 50 items:** Send the top 50 most relevant items (sorted by category overlap with the product, then by most recently worn). Include the same fields. Also append a distribution summary for the remaining items.

### Insight Caching Strategy

```javascript
// In generateInsights:
if (scan.insights !== null) {
  // Cached -- return immediately, no Gemini call
  return {
    scan,
    matches: scan.insights.matches || [],
    insights: scan.insights.insights || [],
    status: "analyzed"
  };
}
```

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/shopping/models/match_insight_result.dart`
  - `apps/mobile/lib/src/features/shopping/screens/match_insight_screen.dart`
  - `apps/mobile/test/features/shopping/models/match_insight_result_test.dart`
  - `apps/mobile/test/features/shopping/screens/match_insight_screen_test.dart`
- Modified API files:
  - `apps/api/src/modules/shopping/shopping-scan-service.js` (add `generateInsights`, `MATCH_INSIGHT_PROMPT`, `buildInsightWardrobeList`, update `validateScanUpdate` for `wishlisted`)
  - `apps/api/src/modules/shopping/shopping-scan-repository.js` (add `wishlisted` and `insights` to `updateScan` fieldMap with `::jsonb` cast for insights)
  - `apps/api/src/main.js` (add `POST /v1/shopping/scans/:id/insights` route before the `/score` route)
  - `apps/api/test/modules/shopping/shopping-scan-service.test.js` (add insight generation tests, wishlisted validation tests)
  - `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js` (add insight endpoint tests, wishlisted PATCH tests)
- Modified mobile files:
  - `apps/mobile/lib/src/features/shopping/models/shopping_scan.dart` (add `insights` field to model, `fromJson`, `copyWith`)
  - `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart` (add `generateInsights`)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `generateShoppingInsights`)
  - `apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart` (enable "View Matches & Insights" button, navigate to MatchInsightScreen)
  - `apps/mobile/test/features/shopping/screens/compatibility_score_screen_test.dart` (update button enabled/navigation tests)
  - `apps/mobile/test/features/shopping/models/shopping_scan_test.dart` (add insights field tests)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add generateShoppingInsights test)

### Technical Requirements

- **Gemini 2.0 Flash** via existing `geminiClient` singleton. Use `responseMimeType: "application/json"` for structured output. Single call for insights (similar to scoring in Story 8.4).
- **No new database migration.** The `insights` JSONB and `wishlisted` BOOLEAN columns already exist on `shopping_scans` (migration 024, Story 8.1).
- **No new dependencies** on API or mobile.
- **`insights` JSONB column** stores the full matches+insights payload. The `mapScanRow` in the repository already maps `row.insights` (line 35 of `shopping-scan-repository.js`). No repository mapper changes needed.
- **`wishlisted` column** already mapped by `mapScanRow` (line 36). Already present in the `ShoppingScan` Dart model (line 49 of `shopping_scan.dart`). Need to add to `updateScan` fieldMap and `validateScanUpdate`.
- **Match item validation** is critical: Gemini will return `item_id` values, but these MUST be cross-referenced against the actual wardrobe items fetched. Any hallucinated IDs should be silently dropped.

### Architecture Compliance

- **AI calls brokered only by Cloud Run.** The mobile client calls the API endpoint. The API calls Gemini. The mobile client never calls Gemini directly.
- **No additional rate limiting on insights.** The usage quota was already consumed during scan creation (Stories 8.1/8.2). Insight generation is a follow-up operation.
- **RLS on shopping_scans.** The insights endpoint uses `getScanById` which enforces RLS. Users can only generate insights for their own scans.
- **Caching prevents redundant AI calls.** Once insights are generated, they are stored in the JSONB column and returned on subsequent requests without re-calling Gemini. This satisfies NFR-PERF-09.
- **Epic 8 component mapping:** `mobile/features/shopping`, `api/modules/shopping`, `api/modules/ai` (architecture.md).
- **Error handling standard:** 401 for auth, 404 for not found (RLS), 422 for empty wardrobe or not scored, 502 for Gemini failure.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `@google-cloud/vertexai` via `geminiClient`, existing `itemRepo` for wardrobe fetching, existing `shoppingScanRepo` for scan updates, existing `aiUsageLogRepo` for logging.
- **Mobile:** No new dependencies. Uses existing Flutter material widgets (`Card`, `ListView`, `Wrap`, `Image.network`, `CircleAvatar`), existing `api_client.dart`, existing navigation patterns.

### File Structure Requirements

- `apps/mobile/lib/src/features/shopping/models/` already exists. New `match_insight_result.dart` goes here.
- `apps/mobile/lib/src/features/shopping/screens/` already exists. New `match_insight_screen.dart` goes here.
- Test files mirror source structure.
- No new API files. All API changes are modifications to existing files.

### Testing Requirements

- **API tests** extend existing files from Stories 8.1-8.4. Use the same Node.js built-in test runner patterns.
- **Mock the Gemini client** in insight service tests. Return pre-defined JSON responses for different scenarios (valid matches+insights, invalid item IDs, missing insight types, timeout).
- **Mock the `itemRepo`** to return controlled wardrobe item sets (empty, small with known IDs, large).
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Target:** All existing tests continue to pass (802 API tests, 1227 Flutter tests from Story 8.4) plus new tests.

### Previous Story Intelligence

- **Story 8.4** (done, predecessor) established: `scoreCompatibility` method, `COMPATIBILITY_SCORING_PROMPT`, `buildWardrobeSummary`, `computeTier`, `clampScore`, `POST /v1/shopping/scans/:id/score` endpoint (placed BEFORE PATCH route), 502 in `mapError`, `CompatibilityScoreScreen` with animated gauge + breakdown bars + disabled "View Matches & Insights" button, `CompatibilityScoreResult` model, `ScoreBreakdown`, `ScoreTier`. **802 API tests, 1227 Flutter tests.** `createShoppingScanService` accepts `itemRepo`.
- **Story 8.3** (done) established: `PATCH /v1/shopping/scans/:id` endpoint, `updateScan` repository method with fieldMap (currently includes `compatibilityScore` but NOT `wishlisted` or `insights`), `validateScanUpdate` function (does NOT yet accept `wishlisted`), `ProductReviewScreen`, `authenticatedPatch` on ApiClient, `taxonomy_constants.dart`. **774 API tests, 1199 Flutter tests.**
- **Story 8.1** (done) established: `shopping_scans` table (migration 024) with `insights JSONB` (NULL) and `wishlisted BOOLEAN DEFAULT FALSE` columns, `mapScanRow` already maps both `insights` and `wishlisted`, `ShoppingScan` Dart model already has `wishlisted` field. **738 API tests, 1171 Flutter tests.**
- **`createRuntime()` returns 33 services** (as of Story 8.3). No new services needed -- `generateInsights` is added to the existing `createShoppingScanService`.
- **`handleRequest` destructuring** includes `shoppingScanService` from Story 8.1. The new route uses `shoppingScanService.generateInsights` so no changes to the destructuring are needed.
- **`mapError` function** handles 400, 401, 403, 404, 409, 422, 429, 500, 502, 503. 502 was added in Story 8.4. No changes needed.
- **Key patterns from all previous stories:**
  - Factory pattern for API services: `createXxxService({ deps })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories via `mapScanRow`.
  - Semantics labels on all interactive elements.
  - Best-effort for non-critical operations (try/catch around AI logging).
  - `responseMimeType: "application/json"` for structured Gemini responses.
  - AI usage logging with separate feature names per operation type (`shopping_scan`, `shopping_score`, now `shopping_insight`).
  - Route ordering in `main.js`: more specific path patterns (e.g., `/insights`, `/score`) placed BEFORE generic ID patterns.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. All AI insight calls go through the Cloud Run API.
- DO NOT create a new Gemini client or service factory. Add `generateInsights` to the existing `createShoppingScanService`.
- DO NOT create a new database migration. The `insights` JSONB and `wishlisted` BOOLEAN columns already exist.
- DO NOT consume an additional usage quota for insights. The quota was already consumed during scan creation.
- DO NOT re-generate insights if they already exist in the `insights` column. Return cached data.
- DO NOT trust Gemini's item_id references without validation. Cross-check every returned ID against the user's actual wardrobe items.
- DO NOT return fewer than 3 insights to the client. Fill in missing types with generic fallback text.
- DO NOT log insight AI usage with `feature = "shopping_scan"` or `"shopping_score"`. Use `feature = "shopping_insight"`.
- DO NOT modify the existing `scoreCompatibility`, `scanUrl`, `scanScreenshot`, or `validateScanUpdate` methods (except adding `wishlisted` to validation). This story only adds `generateInsights`.
- DO NOT skip AI usage logging on failure. Both success and failure must be logged.
- DO NOT block on Gemini failure. Return a clear 502 error so the mobile app can show a retry button.
- DO NOT send all 500+ items individually in the insight prompt. Use the 50-item relevance threshold with distribution summary for larger wardrobes.
- DO NOT place the `/insights` route AFTER the PATCH `/scans/:id` route in `main.js`. The more specific path must match first.

### Out of Scope

- **Shopping scan history list or deletion** (future enhancement)
- **Re-scoring after edits** (user must re-trigger manually)
- **Offline insights** (requires Gemini API access)
- **Insight re-generation** (once cached, insights are permanent for that scan)
- **Social sharing of scan results** (future enhancement)
- **Push notifications for wishlist price drops** (future enhancement)
- **Wishlist list view screen** (future enhancement -- this story only adds the toggle)

### References

- [Source: epics.md - Story 8.5: Shopping Match & Insight Display]
- [Source: epics.md - Epic 8: Shopping Assistant, FR-SHP-08, FR-SHP-09, FR-SHP-10, FR-SHP-11, FR-SHP-12]
- [Source: prd.md - FR-SHP-08: The system shall display top matching items from the user's wardrobe, grouped by category, with match reasons]
- [Source: prd.md - FR-SHP-09: The system shall generate 3 AI-powered insights per scan: style feedback, wardrobe gap assessment, and value proposition]
- [Source: prd.md - FR-SHP-10: Users shall save scanned products to a shopping wishlist with score, matches, and insights]
- [Source: prd.md - FR-SHP-11: Scanned products shall be stored in shopping_scans for history and re-analysis]
- [Source: prd.md - FR-SHP-12: The system shall display an empty wardrobe CTA when no items exist for scoring]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Epic 8 Shopping Assistant -> mobile/features/shopping, api/modules/shopping, api/modules/ai]
- [Source: architecture.md - Important tables: shopping_scans, shopping_wishlists]
- [Source: architecture.md - Taxonomy validation on structured outputs, safe defaults when AI confidence is low]
- [Source: infra/sql/migrations/024_shopping_scans.sql - insights JSONB column, wishlisted BOOLEAN DEFAULT FALSE]
- [Source: 8-1-product-url-scraping.md - shopping_scans table with insights and wishlisted columns, mapScanRow already maps both]
- [Source: 8-3-review-extracted-product-data.md - PATCH endpoint, validateScanUpdate, updateScan fieldMap]
- [Source: 8-4-purchase-compatibility-scoring.md - scoreCompatibility, buildWardrobeSummary, computeTier, CompatibilityScoreScreen with disabled "View Matches & Insights" button, 802 API tests, 1227 Flutter tests]
- [Source: apps/api/src/modules/shopping/shopping-scan-service.js - existing service with scoreCompatibility, scanUrl, scanScreenshot, validateScanUpdate, buildWardrobeSummary, computeTier, COMPATIBILITY_SCORING_PROMPT]
- [Source: apps/api/src/modules/shopping/shopping-scan-repository.js - createScan, getScanById, listScans, updateScan with fieldMap (needs wishlisted+insights), mapScanRow with insights and wishlisted already mapped]
- [Source: apps/api/src/modules/items/repository.js - listItems with filters, mapItemRow with id/name/imageUrl/category/color/style fields]
- [Source: apps/mobile/lib/src/features/shopping/models/shopping_scan.dart - ShoppingScan with wishlisted field, missing insights field]
- [Source: apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart - disabled "View Matches & Insights - Coming Soon" button at line 347-362]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- API service tests: 65 pass (was 43, +22 new for insight generation, wishlisted validation, buildInsightWardrobeList)
- API endpoint tests: 36 pass (was 25, +11 new for insights endpoint, wishlisted PATCH)
- Full API suite: 828 pass (was 802, +26 net new)
- Flutter tests: 1254 pass (was 1227, +27 net new)
- flutter analyze: 0 new issues (11 pre-existing warnings/infos)

### Completion Notes List

- Implemented `generateInsights` method on `createShoppingScanService` with full Gemini 2.0 Flash integration
- Added `MATCH_INSIGHT_PROMPT` for structured insight/match generation
- Added `buildInsightWardrobeList` for item-level wardrobe data (with 50-item threshold)
- Match validation filters hallucinated item IDs; insight validation ensures exactly 3 insight types with fallbacks
- Insight caching: returns cached data from `insights` JSONB column without re-calling Gemini
- AI usage logged with `feature: "shopping_insight"` on both success and failure
- Added `wishlisted` and `insights` to repository `updateScan` fieldMap (insights with `::jsonb` cast)
- Added `wishlisted` boolean validation to `validateScanUpdate`
- Wired `POST /v1/shopping/scans/:id/insights` route before `/score` route in main.js
- Created `MatchInsightResult`, `WardrobeMatch`, `ShoppingInsight` Dart models with icon mapping
- Created `MatchInsightScreen` with grouped match cards, insight cards, wishlist toggle, empty/error states
- Added `insights` field to `ShoppingScan` Dart model (fromJson, copyWith)
- Enabled "View Matches & Insights" button on CompatibilityScoreScreen (was disabled placeholder)
- Added `generateShoppingInsights` to ApiClient and `generateInsights` to ShoppingScanService
- Epic 8 Shopping Assistant is now feature-complete

### File List

New files:
- apps/mobile/lib/src/features/shopping/models/match_insight_result.dart
- apps/mobile/lib/src/features/shopping/screens/match_insight_screen.dart
- apps/mobile/test/features/shopping/models/match_insight_result_test.dart
- apps/mobile/test/features/shopping/screens/match_insight_screen_test.dart

Modified files:
- apps/api/src/modules/shopping/shopping-scan-service.js (added generateInsights, MATCH_INSIGHT_PROMPT, buildInsightWardrobeList, wishlisted validation)
- apps/api/src/modules/shopping/shopping-scan-repository.js (added wishlisted + insights to updateScan fieldMap)
- apps/api/src/main.js (added POST /v1/shopping/scans/:id/insights route)
- apps/api/test/modules/shopping/shopping-scan-service.test.js (added 22 insight/wishlisted tests)
- apps/api/test/modules/shopping/shopping-scan-endpoint.test.js (added 11 insight/wishlisted endpoint tests)
- apps/mobile/lib/src/features/shopping/models/shopping_scan.dart (added insights field)
- apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart (added generateInsights method)
- apps/mobile/lib/src/core/networking/api_client.dart (added generateShoppingInsights method)
- apps/mobile/lib/src/features/shopping/screens/compatibility_score_screen.dart (enabled View Matches & Insights button)
- apps/mobile/test/features/shopping/screens/compatibility_score_screen_test.dart (updated button tests)
- apps/mobile/test/features/shopping/models/shopping_scan_test.dart (added insights field tests)
- apps/mobile/test/core/networking/api_client_test.dart (added generateShoppingInsights test)
