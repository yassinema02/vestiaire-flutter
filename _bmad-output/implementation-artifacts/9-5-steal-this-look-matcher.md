# Story 9.5: "Steal This Look" Matcher

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to tap "Steal This Look" on a friend's OOTD post to find similar items in my own wardrobe,
So that I can recreate their outfit without buying new clothes.

## Acceptance Criteria

1. Given I am viewing an OOTD post (OotdPostDetailScreen) that has at least 1 tagged item, when I tap the "Steal This Look" button, then the app calls `POST /v1/squads/posts/:postId/steal-look` which: (a) fetches the post's tagged items with full metadata (category, color, style, material, pattern, season, occasion) from `ootd_post_items` joined to `items`, (b) fetches all of the current user's wardrobe items (via `itemRepo.listItems`), (c) constructs a Gemini 2.0 Flash prompt containing the friend's tagged items and the user's wardrobe inventory, (d) receives a structured JSON response mapping each tagged item to the user's best matching wardrobe items with a match quality score (0-100). (FR-SOC-12)

2. Given the Gemini matching response is received, when the API processes it, then for each of the friend's tagged items it returns: `{ sourceItem: { id, name, category, color, photoUrl }, matches: [{ itemId, name, category, color, photoUrl, matchScore, matchReason }] }`. Each match has a `matchScore` (0-100) and a brief `matchReason` string (1 sentence). Matches are sorted by `matchScore` descending. A maximum of 3 matches per source item are returned. If no match exists for an item (score < 30), the matches array is empty for that source item. (FR-SOC-12, FR-SOC-13)

3. Given the match results are returned, when the StealThisLookScreen displays them, then each source item from the friend's post is shown with its matches color-coded by match quality tier: Excellent (80-100, green `#22C55E`), Good (60-79, blue `#3B82F6`), Partial (30-59, amber `#F59E0B`). Items with no matches show a "No match found" placeholder with an option to "Shop for similar" (disabled placeholder for future shopping integration). (FR-SOC-13)

4. Given the match results contain at least one match per source item (or the user is satisfied with partial matches), when I tap "Save as Outfit", then the app calls `POST /v1/outfits` (existing outfit creation endpoint from Story 4.3) with the user's selected matching items to create a new outfit in the `outfits` table with `source = 'steal_look'`. On success, a SnackBar confirms "Outfit saved!" and the user can view it in their outfit history. (FR-SOC-13)

5. Given the OOTD post has NO tagged items, when I view the post detail screen, then the "Steal This Look" button is hidden or disabled with a tooltip "No items tagged on this post". The button is only shown/enabled when `post.taggedItems.length > 0`. (FR-SOC-12)

6. Given my wardrobe is empty (0 items), when I tap "Steal This Look", then the API returns HTTP 422 with `{ error: "Wardrobe Empty", code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first to find matches." }` and the mobile screen displays an empty-state card with a "Go to Wardrobe" button. (FR-SOC-12)

7. Given the Gemini matching call fails (timeout, parse error, or unavailable), when the error occurs, then the API returns HTTP 502 with `{ error: "Matching Failed", code: "MATCHING_FAILED" }`, logs the failure to `ai_usage_log` with `feature = "steal_look"`, and the mobile screen shows a retry button. (FR-SOC-12)

8. Given the API processes a steal-look request, when the Gemini call is made, then the API logs the request to `ai_usage_log` with `feature = "steal_look"`, model name, input/output tokens, latency in ms, estimated cost, and status `"success"` or `"failure"`. (NFR-OBS-02)

9. Given a user with a large wardrobe (50+ items), when steal-look is triggered, then the API sends per-item detail for wardrobes <= 50 items, or uses the distribution summary strategy (established in Story 8.4 `buildWardrobeSummary`) for > 50 items. The summarized mode returns matches based on category/color/style distributions rather than per-item IDs, and the API maps distribution matches back to actual wardrobe items by best-fit selection. (NFR-PERF-09)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (939+ API tests, 1387+ Flutter tests) and new tests cover: steal-look endpoint (success, empty wardrobe, no tagged items, Gemini failure, auth), steal-look service logic (prompt construction, response parsing, match tier mapping, wardrobe summarization fallback), StealThisLookScreen widget (match display, color-coded tiers, save as outfit, empty wardrobe state, retry on error, no-match placeholders), ApiClient steal-look method, OotdService steal-look method, and StealLookResult model parsing.

## Tasks / Subtasks

- [x] Task 1: API -- Add steal-look matching method to ootd-service.js (AC: 1, 2, 6, 7, 8, 9)
  - [x] 1.1: In `apps/api/src/modules/squads/ootd-service.js`, the `createOotdService` factory must now also accept `itemRepo`, `geminiClient`, and `aiUsageLogRepo` as dependencies: `createOotdService({ ootdRepo, squadRepo, itemRepo, geminiClient, aiUsageLogRepo })`. Update the factory signature.
  - [x] 1.2: Add `async stealThisLook(authContext, { postId })` method. Steps: (a) fetch the post via `ootdRepo.getPostById(authContext, postId)` -- 404 if not found, (b) check `post.taggedItems.length > 0` -- throw 400 with `code: "NO_TAGGED_ITEMS"` if empty, (c) fetch friend's tagged item details with full metadata from `items` table via `ootdRepo.getPostItemsWithDetails(postId)` (new repo method), (d) fetch user's wardrobe items via `itemRepo.listItems(authContext, { limit: 1000 })` -- 422 with `code: "WARDROBE_EMPTY"` if empty, (e) build wardrobe representation using `buildWardrobeSummary` pattern from Story 8.4 (per-item for <= 50, distribution for > 50), (f) construct Gemini prompt (see Task 1.4), (g) call Gemini 2.0 Flash with `responseMimeType: "application/json"`, (h) parse and validate response (see Task 1.5), (i) log AI usage with `feature: "steal_look"`, (j) return `{ sourceItems, matches }`.
  - [x] 1.3: Add a `STEAL_LOOK_PROMPT` constant. Prompt template:
    ```
    You are a wardrobe matching expert. A user wants to recreate a friend's outfit using items from their own wardrobe.

    FRIEND'S OUTFIT ITEMS:
    {sourceItemsJson}

    USER'S WARDROBE:
    {wardrobeSummary}

    For each of the friend's outfit items, find up to 3 best matching items from the user's wardrobe. Match based on:
    1. Category match (must be same or very similar category, e.g., tops/blouses, bottoms/trousers)
    2. Color similarity (exact match scores highest, complementary or neutral substitutes score lower)
    3. Style similarity (casual/formal/sporty alignment)
    4. Material and pattern similarity (bonus factor)

    Score each match 0-100 where:
    - 80-100: Excellent match (very similar item)
    - 60-79: Good match (similar category and style, different color/detail)
    - 30-59: Partial match (same category, different style)
    - Below 30: Do not include (not a useful match)

    Return ONLY valid JSON:
    {
      "matches": [
        {
          "sourceItemId": "<friend's item UUID>",
          "matchedItems": [
            {
              "itemId": "<user's wardrobe item UUID>",
              "matchScore": <integer 0-100>,
              "matchReason": "<1 sentence explaining why this is a match>"
            }
          ]
        }
      ]
    }

    RULES:
    - Use ONLY item IDs from the user's wardrobe list. Do NOT invent IDs.
    - If no good match exists (all below 30), return an empty matchedItems array for that source item.
    - Maximum 3 matches per source item, sorted by matchScore descending.
    - Category must be compatible (don't match shoes to tops).
    ```
  - [x] 1.4: For large wardrobes (> 50 items) using distribution summaries, the prompt changes to describe available category/color/style distributions instead of per-item IDs. In this case, Gemini returns `matchedItems` with descriptive placeholders instead of specific IDs: `{ "category": "tops", "color": "cream", "style": "casual", "matchScore": 75, "matchReason": "..." }`. The API then performs a server-side best-fit selection: query the user's wardrobe items matching the returned category+color+style and pick the top matches. Use `itemRepo.listItems(authContext, { category, color, style, limit: 3 })` for each.
  - [x] 1.5: Parse and validate the Gemini response: (a) validate `matches` is an array, (b) for each match group, validate `sourceItemId` exists in the friend's tagged items, (c) for per-item mode: validate each `itemId` exists in user's wardrobe (build a Set of valid IDs), discard invalid IDs, (d) clamp all `matchScore` values to [0, 100], (e) filter out matches with `matchScore < 30`, (f) sort each group by `matchScore` descending, limit to 3, (g) enrich with full item data: map each matched `itemId` to `{ id, name, category, color, photoUrl }` from the user's fetched items.
  - [x] 1.6: Error handling: wrap the Gemini call in try/catch. On failure, log usage with `status: "failure"` to `ai_usage_log` and throw with `{ statusCode: 502, code: "MATCHING_FAILED", message: "Unable to find matches. Please try again." }`.
  - [x] 1.7: AI usage logging: follow the exact pattern from `outfit-generation-service.js` and `shopping-scan-service.js`. Extract `usageMetadata` from Gemini response, compute `estimateCost()`, call `aiUsageLogRepo.logUsage(authContext, { feature: "steal_look", model: "gemini-2.0-flash", inputTokens, outputTokens, latencyMs, estimatedCostUsd, status })`.

- [x] Task 2: API -- Add repository method for tagged item details (AC: 1)
  - [x] 2.1: In `apps/api/src/modules/squads/ootd-repository.js`, add method `getPostItemsWithDetails(postId)` that joins `ootd_post_items` with `app_public.items` to return full item metadata for each tagged item: `id` (item ID), `name`, `category`, `color`, `secondaryColors`, `pattern`, `material`, `style`, `season`, `occasion`, `photoUrl`. SQL: `SELECT i.id, i.name, i.category, i.color, i.secondary_colors, i.pattern, i.material, i.style, i.season, i.occasion, i.photo_url FROM app_public.ootd_post_items opi JOIN app_public.items i ON i.id = opi.item_id WHERE opi.post_id = $1`.

- [x] Task 3: API -- Wire steal-look endpoint in main.js (AC: 1, 5, 6, 7, 8)
  - [x] 3.1: Add route `POST /v1/squads/posts/:postId/steal-look` in `apps/api/src/main.js`. Requires `requireAuth`. Use regex: `/^\/v1\/squads\/posts\/([^/]+)\/steal-look$/`. Place this BEFORE the existing `ootdPostIdMatch` regex (alongside the reaction/comment routes from Story 9.4).
  - [x] 3.2: Route handler: extract `postId` from regex match, call `ootdService.stealThisLook(authContext, { postId })`, return 200 with the match result.
  - [x] 3.3: Update `createRuntime()`: pass `itemRepo`, `geminiClient`, and `aiUsageLogRepo` to `createOotdService`. These already exist as variables in `createRuntime()` -- verify and pass them. NOTE: `itemRepo` is already created separately in `createRuntime()` (used by `createItemService` and `createShoppingScanService`). `geminiClient` and `aiUsageLogRepo` are also already available.
  - [x] 3.4: Error mapping: 400 for no tagged items, 404 for not found, 422 for empty wardrobe, 502 for Gemini failure. These status codes are already in `mapError` (400, 404, 422, 502 all added in previous stories).

- [x] Task 4: Mobile -- Create StealLookResult model (AC: 2, 3)
  - [x] 4.1: Create `apps/mobile/lib/src/features/squads/models/steal_look_result.dart` with classes:
    - `StealLookMatch`: `String itemId`, `String? name`, `String? category`, `String? color`, `String? photoUrl`, `int matchScore`, `String? matchReason`. Factory `fromJson`. Getter `MatchTier get tier` that maps matchScore to tier (Excellent 80-100, Good 60-79, Partial 30-59).
    - `StealLookSourceMatch`: `StealLookSourceItem sourceItem`, `List<StealLookMatch> matches`. Factory `fromJson`.
    - `StealLookSourceItem`: `String id`, `String? name`, `String? category`, `String? color`, `String? photoUrl`. Factory `fromJson`.
    - `StealLookResult`: `List<StealLookSourceMatch> sourceMatches`. Factory `fromJson(Map<String, dynamic> json)`.
  - [x] 4.2: Add `MatchTier` enum: `excellent` (color `#22C55E`), `good` (color `#3B82F6`), `partial` (color `#F59E0B`). Include `Color get color` and `String get label` getters.

- [x] Task 5: Mobile -- Add steal-look methods to OotdService and ApiClient (AC: 1)
  - [x] 5.1: In `apps/mobile/lib/src/features/squads/services/ootd_service.dart`, add: `Future<StealLookResult> stealThisLook(String postId)` that calls `_apiClient.stealThisLook(postId)` and returns parsed `StealLookResult`.
  - [x] 5.2: In `apps/mobile/lib/src/core/networking/api_client.dart`, add: `Future<Map<String, dynamic>> stealThisLook(String postId)` that calls `authenticatedPost("/v1/squads/posts/$postId/steal-look")`. Place adjacent to existing OOTD methods.

- [x] Task 6: Mobile -- Create StealThisLookScreen (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x] 6.1: Create `apps/mobile/lib/src/features/squads/screens/steal_this_look_screen.dart` with `StealThisLookScreen` StatefulWidget. Constructor: `{ required String postId, required OotdPost post, required OotdService ootdService, super.key }`.
  - [x] 6.2: On `initState`, immediately call `ootdService.stealThisLook(postId)`. Show a loading state: the friend's post photo at top (compact, 120px), title "Finding matches in your wardrobe...", and a pulsing/shimmer animation.
  - [x] 6.3: On success, display a scrollable list. For each source item from the friend's post:
    - **Source item header**: thumbnail (48x48 rounded), name, category label. Light gray background row.
    - **Matches below**: For each match, show: thumbnail (56x56 rounded), name, category, match score badge (circular, colored by tier), match reason text (12px, `#6B7280`). The score badge background uses the tier color. If no matches, show "No match found" with a muted icon and a "Shop for similar" placeholder text (non-interactive, styled as disabled chip).
  - [x] 6.4: At the bottom, add a "Save as Outfit" `ElevatedButton` (primary color `#4F46E5`, white text, 44px height). This button is enabled when at least one source item has at least one match. On tap, collect the best match (highest score) for each source item that has matches, and call `POST /v1/outfits` via the existing outfit creation pattern from Story 4.3 (use ApiClient `authenticatedPost("/v1/outfits", body: { "itemIds": [...], "name": "Inspired by {authorName}'s look", "source": "steal_look" })`) to save as a new outfit. On success, show SnackBar "Outfit saved!" and pop back to the post detail screen.
  - [x] 6.5: On empty wardrobe (422), display: icon `Icons.checkroom`, title "Your wardrobe is empty", subtitle "Add items to your wardrobe first to find matches.", "Go to Wardrobe" button navigating to Wardrobe tab.
  - [x] 6.6: On matching failure (502 or other error), display error card with "Unable to find matches" and a "Retry" button that re-triggers `stealThisLook`.
  - [x] 6.7: Add `Semantics` labels on: each source item row ("Source item: {name}"), each match row ("Match: {name}, {score}% match"), score badge, save button, retry button, Go to Wardrobe button.
  - [x] 6.8: Follow Vibrant Soft-UI design: 16px border radius, subtle shadows, `#F3F4F6` background, `#1F2937` primary text, `#6B7280` secondary text, tier colors for score badges.

- [x] Task 7: Mobile -- Update OotdPostDetailScreen with "Steal This Look" button (AC: 1, 5)
  - [x] 7.1: In `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart`, add a "Steal This Look" button below the tagged items section. Use an `OutlinedButton.icon` with `Icons.style` icon and text "Steal This Look". Style: `#4F46E5` border and text color, 44px height, full width.
  - [x] 7.2: The button is ONLY visible when `widget.post.taggedItems.isNotEmpty`. When `taggedItems` is empty, hide the button entirely.
  - [x] 7.3: On tap, navigate to `StealThisLookScreen(postId: widget.post.id, post: widget.post, ootdService: widget.ootdService)`.
  - [x] 7.4: Add `Semantics` label: "Steal this look - find similar items in your wardrobe".

- [x] Task 8: Mobile -- Update OotdPostCard with "Steal This Look" quick action (AC: 1, 5)
  - [x] 8.1: In `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart`, add a small "Steal This Look" text button or icon button (Icons.style, 20px) next to the existing reaction and comment buttons in the engagement row. Only show when `post.taggedItems.isNotEmpty`.
  - [x] 8.2: Add constructor parameter: `VoidCallback? onStealLookTap`. When tapped, call `onStealLookTap` callback which navigates to the post detail screen or directly to StealThisLookScreen.
  - [x] 8.3: Add `Semantics` label: "Steal this look".

- [x] Task 9: Mobile -- Wire steal-look callbacks in feed and squad screens (AC: 1)
  - [x] 9.1: In `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart`, pass `onStealLookTap` callback to each `OotdPostCard` that navigates to `StealThisLookScreen` with the post's data and ootdService.
  - [x] 9.2: In `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart`, pass `onStealLookTap` callback to inline `OotdPostCard` widgets using the same pattern.

- [x] Task 10: API -- Unit tests for steal-look service (AC: 1, 2, 6, 7, 8, 9, 10)
  - [x] 10.1: Add tests to `apps/api/test/modules/squads/ootd-service.test.js` (or create new `ootd-steal-look.test.js`):
    - `stealThisLook` fetches post, tagged items, and user wardrobe, calls Gemini, returns match results.
    - `stealThisLook` throws 404 when post not found.
    - `stealThisLook` throws 400 when post has no tagged items.
    - `stealThisLook` throws 422 when user wardrobe is empty.
    - `stealThisLook` logs AI usage on success with `feature: "steal_look"`.
    - `stealThisLook` logs AI usage on failure with `feature: "steal_look"`.
    - `stealThisLook` throws 502 when Gemini returns unparseable response.
    - `stealThisLook` clamps out-of-range match scores to [0, 100].
    - `stealThisLook` filters out matches with score < 30.
    - `stealThisLook` limits to 3 matches per source item.
    - `stealThisLook` validates matched item IDs exist in user's wardrobe.
    - `stealThisLook` discards matches with invalid item IDs.
    - `stealThisLook` works with large wardrobe (> 50 items, uses summarized mode).
    - `stealThisLook` returns empty matches array for source items with no good matches.
    - `getPostItemsWithDetails` returns full item metadata for tagged items.

- [x] Task 11: API -- Integration tests for steal-look endpoint (AC: 1, 5, 6, 7, 10)
  - [x] 11.1: Add tests to `apps/api/test/modules/squads/ootd-endpoint.test.js` (or create new file):
    - POST /v1/squads/posts/:postId/steal-look returns 200 with match data on success.
    - POST /v1/squads/posts/:postId/steal-look returns 404 for non-existent post.
    - POST /v1/squads/posts/:postId/steal-look returns 400 for post with no tagged items.
    - POST /v1/squads/posts/:postId/steal-look returns 422 when wardrobe is empty.
    - POST /v1/squads/posts/:postId/steal-look returns 502 when Gemini fails.
    - POST /v1/squads/posts/:postId/steal-look returns 401 without authentication.
    - POST /v1/squads/posts/:postId/steal-look returns 404 for post in squad user doesn't belong to (RLS).

- [x] Task 12: Mobile -- Widget tests for StealThisLookScreen (AC: 2, 3, 4, 6, 7, 10)
  - [x] 12.1: Create `apps/mobile/test/features/squads/screens/steal_this_look_screen_test.dart`:
    - Renders loading state with friend's post photo and "Finding matches" text.
    - Displays source items with their matches on success.
    - Match score badges use correct tier colors (green for Excellent, blue for Good, amber for Partial).
    - Displays match reason text for each match.
    - "No match found" placeholder shown for source items with no matches.
    - "Save as Outfit" button is enabled when at least one match exists.
    - "Save as Outfit" button calls outfit creation endpoint.
    - Shows SnackBar "Outfit saved!" on successful save.
    - Shows empty wardrobe state on 422 error.
    - "Go to Wardrobe" button present in empty state.
    - Shows retry button on matching failure.
    - Retry button re-triggers steal-look call.
    - Semantics labels present on source items, matches, score badges, buttons.

- [x] Task 13: Mobile -- Model tests for StealLookResult (AC: 2, 3, 10)
  - [x] 13.1: Create `apps/mobile/test/features/squads/models/steal_look_result_test.dart`:
    - `StealLookResult.fromJson` parses all fields correctly.
    - `StealLookMatch.fromJson` parses matchScore, matchReason, item fields.
    - `StealLookMatch.tier` returns correct tier for scores: 85 -> Excellent, 65 -> Good, 40 -> Partial.
    - `MatchTier` enum has correct colors and labels for all 3 tiers.
    - `StealLookSourceMatch.fromJson` handles empty matches array.
    - Handles edge cases: score of 0, score of 100, null matchReason, null name/photoUrl.

- [x] Task 14: Mobile -- Update OotdPostDetailScreen tests (AC: 5, 10)
  - [x] 14.1: Update `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart`:
    - "Steal This Look" button is visible when post has tagged items.
    - "Steal This Look" button is hidden when post has no tagged items.
    - Tapping "Steal This Look" navigates to StealThisLookScreen.
    - Semantics label present on button.

- [x] Task 15: Mobile -- Update OotdPostCard tests and OotdService/ApiClient tests (AC: 1, 10)
  - [x] 15.1: Update `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart`:
    - "Steal This Look" icon/button visible when post has tagged items.
    - "Steal This Look" icon/button hidden when post has no tagged items.
    - Tapping steal-look triggers onStealLookTap callback.
  - [x] 15.2: Update `apps/mobile/test/features/squads/services/ootd_service_test.dart`:
    - `stealThisLook` calls correct API endpoint.
  - [x] 15.3: Update `apps/mobile/test/core/networking/api_client_test.dart`:
    - `stealThisLook` calls POST /v1/squads/posts/:postId/steal-look.

- [x] Task 16: Regression testing (AC: all)
  - [x] 16.1: Run `flutter analyze` -- zero new issues.
  - [x] 16.2: Run `flutter test` -- all existing 1387+ tests plus new tests pass.
  - [x] 16.3: Run `npm --prefix apps/api test` -- all existing 939+ API tests plus new tests pass.
  - [x] 16.4: Verify existing feed, post detail, post card, squad detail flows still work.
  - [x] 16.5: Verify existing reaction and comment flows still work (no regression from updated OotdPostCard/OotdPostDetailScreen).
  - [x] 16.6: Verify existing outfit creation flow still works (the save-as-outfit uses the same endpoint).

## Dev Notes

- This is Story 9.5 in Epic 9 (Social OOTD Feed / Style Squads). It builds on Story 9.1 (squad infrastructure, done), Story 9.2 (OOTD post creation with item tagging, done), Story 9.3 (feed display, done), and Story 9.4 (reactions/comments, done). This story adds the "Steal This Look" feature that uses Gemini AI to match a friend's tagged outfit items against the user's own wardrobe.
- **FRs covered:** FR-SOC-12 (Steal This Look on any OOTD post to find similar items in own wardrobe, AI-powered matching and fallback), FR-SOC-13 (results color-coded by match quality, saveable as a new outfit).
- This story spans **both API and mobile**. A new API endpoint, Gemini AI integration, and a new mobile screen are required.

### Current State of the Codebase

- The `ootd_post_items` table (migration 026) links posts to wardrobe items. `getPostItemsByPostId(postId)` in `ootd-repository.js` returns tagged items with basic info (`itemId`, `itemName`, `itemPhotoUrl`, `itemCategory`). A new method `getPostItemsWithDetails` is needed to return full metadata (color, style, material, pattern, season, occasion) for Gemini prompt construction.
- `OotdPostDetailScreen` shows tagged items as thumbnail chips below the photo. The "Steal This Look" button needs to be added below this section.
- `OotdPostCard` has `onReactionTap` and `onCommentTap` callbacks (from Stories 9.3-9.4). A new `onStealLookTap` callback is needed.
- The `outfits` table (migration 013) and `outfit_items` join table exist with `source` column (`CHECK (source IN ('ai', 'manual'))`). This story adds `'steal_look'` as a new valid source value. A migration is needed to ALTER the CHECK constraint to include `'steal_look'`.
- `createOotdService({ ootdRepo, squadRepo })` currently does NOT have access to `itemRepo`, `geminiClient`, or `aiUsageLogRepo`. These must be added as dependencies.
- The `buildWardrobeSummary` function exists in `apps/api/src/modules/shopping/shopping-scan-service.js` (from Story 8.4). It should be extracted to a shared utility or imported. Alternatively, duplicate it in the ootd service (simpler but less DRY). Recommended: import from shopping module or extract to `apps/api/src/modules/ai/wardrobe-utils.js`.
- The `estimateCost` function is available in `apps/api/src/modules/ai/categorization-service.js` (used by Story 4.1 and 8.4). Reuse the same function for AI usage logging.

### IMPORTANT: Database Migration for outfit source constraint

The `outfits` table (migration 013) has: `source TEXT NOT NULL DEFAULT 'ai' CHECK (source IN ('ai', 'manual'))`. To save steal-look outfits with `source = 'steal_look'`, the CHECK constraint must be updated. Create `infra/sql/migrations/028_outfit_source_steal_look.sql`:
```sql
-- Add 'steal_look' as a valid outfit source
ALTER TABLE app_public.outfits DROP CONSTRAINT IF EXISTS outfits_source_check;
ALTER TABLE app_public.outfits ADD CONSTRAINT outfits_source_check CHECK (source IN ('ai', 'manual', 'steal_look'));
COMMENT ON COLUMN app_public.outfits.source IS 'How the outfit was created: ai (generated), manual (user-built), steal_look (inspired by friend''s post)';
```

### Database Schema (existing tables used)

```sql
-- ootd_post_items (from migration 026 -- already exists)
-- Used to get friend's tagged items
CREATE TABLE app_public.ootd_post_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  UNIQUE (post_id, item_id)
);

-- items table (from migration 003 -- already exists)
-- Joined with ootd_post_items to get full item metadata for Gemini prompt
-- Key columns: id, name, category, color, secondary_colors, pattern, material, style, season, occasion, photo_url

-- outfits table (from migration 013 -- already exists)
-- Used to save the steal-look result as a new outfit
-- source column needs CHECK constraint update to include 'steal_look'

-- ai_usage_log (from migration 006 -- already exists)
-- Used to log AI usage with feature = "steal_look"
```

### API Endpoint Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /v1/squads/posts/:postId/steal-look | Yes | Find matching wardrobe items for friend's outfit |

### Route Ordering in main.js

The new route `/v1/squads/posts/:postId/steal-look` must be matched BEFORE the existing `ootdPostIdMatch` regex, alongside the reaction and comment routes from Story 9.4.

```javascript
// Story 9.5: Steal This Look (BEFORE ootdPostIdMatch)
const ootdStealLookMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/steal-look$/);

if (req.method === "POST" && ootdStealLookMatch) {
  const authContext = await requireAuth(req, authService);
  const result = await ootdService.stealThisLook(authContext, { postId: ootdStealLookMatch[1] });
  res.writeHead(200, headers);
  res.end(JSON.stringify(result));
  return;
}
```

### Match Quality Tier Mapping

| Tier | Score Range | Color | Label |
|------|-----------|-------|-------|
| Excellent | 80-100 | `#22C55E` (green) | "Excellent Match" |
| Good | 60-79 | `#3B82F6` (blue) | "Good Match" |
| Partial | 30-59 | `#F59E0B` (amber) | "Partial Match" |
| No Match | < 30 | N/A | Filtered out by API |

### Wardrobe Summarization Strategy

Reuse the pattern from Story 8.4 (`buildWardrobeSummary`):
- **<= 50 items**: Send per-item detail (id, category, color, style, material, pattern, season, occasion). Gemini returns specific item IDs.
- **> 50 items**: Send aggregated distributions (category counts, color counts, style counts). Gemini returns descriptive matches (category + color + style). API performs a server-side best-fit item selection query.

### Saving as Outfit

The "Save as Outfit" flow reuses the existing outfit creation API from Story 4.3:
- `POST /v1/outfits` with `{ name, itemIds, source }` where `source = "steal_look"`.
- The `name` should be auto-generated: "Inspired by {authorDisplayName}'s look".
- Only the user's matched items are included (not the friend's items).
- The outfit is saved to the `outfits` and `outfit_items` tables.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/028_outfit_source_steal_look.sql` (ALTER CHECK constraint on outfits.source)
- New mobile files:
  - `apps/mobile/lib/src/features/squads/models/steal_look_result.dart`
  - `apps/mobile/lib/src/features/squads/screens/steal_this_look_screen.dart`
  - `apps/mobile/test/features/squads/models/steal_look_result_test.dart`
  - `apps/mobile/test/features/squads/screens/steal_this_look_screen_test.dart`
- Modified API files:
  - `apps/api/src/modules/squads/ootd-repository.js` (add `getPostItemsWithDetails` method)
  - `apps/api/src/modules/squads/ootd-service.js` (add `stealThisLook` method, `STEAL_LOOK_PROMPT`, update factory to accept `itemRepo`, `geminiClient`, `aiUsageLogRepo`)
  - `apps/api/src/main.js` (add `POST /v1/squads/posts/:postId/steal-look` route, update `createOotdService` wiring to include `itemRepo`, `geminiClient`, `aiUsageLogRepo`)
  - `apps/api/test/modules/squads/ootd-service.test.js` (add steal-look tests)
  - `apps/api/test/modules/squads/ootd-endpoint.test.js` (add steal-look endpoint tests)
- Modified mobile files:
  - `apps/mobile/lib/src/features/squads/services/ootd_service.dart` (add `stealThisLook` method)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `stealThisLook` method)
  - `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart` (add "Steal This Look" button, conditional on tagged items)
  - `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart` (add steal-look icon/button, `onStealLookTap` callback)
  - `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart` (pass `onStealLookTap` callback)
  - `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart` (pass `onStealLookTap` callback)
  - `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart` (add steal-look button tests)
  - `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart` (add steal-look button tests)
  - `apps/mobile/test/features/squads/services/ootd_service_test.dart` (add `stealThisLook` test)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add `stealThisLook` test)

### Alignment with Unified Project Structure

- Steal-look is part of the squads feature. All code stays in `apps/api/src/modules/squads/` and `apps/mobile/lib/src/features/squads/`.
- New model `StealLookResult` goes in `apps/mobile/lib/src/features/squads/models/` alongside existing `OotdPost`, `OotdComment`, and `Squad` models.
- New screen `StealThisLookScreen` goes in `apps/mobile/lib/src/features/squads/screens/` alongside existing screens.
- No new API module directories needed. Extend existing `ootd-repository.js` and `ootd-service.js`.
- Test files mirror source structure exactly.

### Technical Requirements

- **Gemini 2.0 Flash** via existing `geminiClient` singleton. Use `responseMimeType: "application/json"` for structured output. Single call per steal-look request.
- **PostgreSQL 16** with RLS. No new tables. One migration to update CHECK constraint on `outfits.source`.
- **Flutter / Dart**: No new dependencies. Uses existing Material widgets, `CachedNetworkImage` for item thumbnails.
- **No new API dependencies**. Uses existing `@google-cloud/vertexai`, `pg` pool, existing repositories.
- **No new Flutter dependencies**. All UI uses existing widgets and patterns.
- **AI usage logging** with `feature = "steal_look"` (distinct from other AI features).

### Architecture Compliance

- **AI calls brokered only by Cloud Run.** The mobile client calls the steal-look API endpoint. The API calls Gemini. The mobile client never calls Gemini directly.
- **RLS on all user-facing tables.** Post visibility is enforced via existing RLS on `ootd_posts` (user must be in a squad that the post was shared to). The user's own wardrobe items are fetched via `listItems` which applies RLS.
- **Squad membership gates social operations.** The steal-look endpoint implicitly checks squad membership via `getPostById` which uses RLS (posts are only visible to squad members).
- **Server-side enforcement.** Match validation (item ID existence, score clamping, threshold filtering) all happens server-side. The mobile client receives pre-validated results.
- **Accessibility.** Semantics labels on all interactive elements. 44x44 touch targets for buttons. Color-coded tiers also include text labels (not color-only).
- **Error handling standard.** 400 for no tagged items, 404 for not found, 422 for empty wardrobe, 502 for Gemini failure.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `geminiClient`, `itemRepo`, `aiUsageLogRepo`, and `ootdRepo`.
- **Mobile:** No new dependencies. Uses existing Flutter Material widgets, existing navigation patterns, existing `ApiClient` and `OotdService`.

### File Structure Requirements

- New model in `apps/mobile/lib/src/features/squads/models/steal_look_result.dart`.
- New screen in `apps/mobile/lib/src/features/squads/screens/steal_this_look_screen.dart`.
- New migration: `infra/sql/migrations/028_outfit_source_steal_look.sql`.
- All other changes are modifications to existing files.
- Test files mirror source structure.

### Testing Requirements

- **API tests** extend existing files. Mock the Gemini client in service tests. Return pre-defined JSON responses for different scenarios (multiple matches, no matches, invalid IDs, Gemini failure).
- **Mock `itemRepo`** to return controlled wardrobe item sets (empty, small, large).
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Mock `OotdService`** in widget tests for steal-look operation.
- **Target:** All existing tests pass (939 API, 1387 Flutter) plus new tests for steal-look service, endpoint, screen, model, and integration.

### Previous Story Intelligence

- **Story 9.4** (done, predecessor): Added reactions/comments with `ootd_reactions`/`ootd_comments` tables (migration 027), 4 new API routes in main.js (reaction toggle, comment CRUD), OotdPostCard interactive reaction toggle with optimistic UI, OotdPostDetailScreen comments list with add/delete, notification stub for comments. **939 API tests, 1387 Flutter tests.** Key patterns: `mounted` guard, optimistic UI, route ordering before `ootdPostIdMatch`.
- **Story 9.3** (done): Created `OotdPostCard` (StatefulWidget with callbacks), `OotdFeedScreen` (cursor-based pagination, squad filter chips), `OotdPostDetailScreen` (full post detail). `time_utils.dart` shared utility.
- **Story 9.2** (done): Created `ootd_posts`, `ootd_post_squads`, `ootd_post_items` tables (migration 026). `ootd-repository.js` with `createPost`, `getPostById`, `getPostItemsByPostId`, `mapPostRow`, `mapPostItemRow`. `ootd-service.js` with post CRUD. **Item tagging is optional** -- posts can have zero tagged items.
- **Story 9.1** (done): Squad infrastructure. `getProfileIdForUser`, `getMembership` in `squad-repository.js`. 7 squad API routes. Bottom nav with Social tab.
- **Story 8.4** (done): Established `buildWardrobeSummary(items)` pattern for sending wardrobe data to Gemini. Per-item detail for <= 50, distribution summary for > 50. `computeTier(score)` utility. `COMPATIBILITY_SCORING_PROMPT` pattern. Gemini JSON mode for structured scoring. AI usage logging with distinct feature names. 802 API tests, 1227 Flutter tests.
- **Story 4.1** (done): Established outfit generation Gemini pattern. `outfit-generation-service.js` with Gemini prompt, JSON parsing, item ID validation, usage logging. `estimateCost()` formula. The `outfits` and `outfit_items` tables.
- **Story 4.3** (done): Manual outfit building. `POST /v1/outfits` endpoint for creating outfits with `{ name, itemIds, source }`. This is the endpoint reused by "Save as Outfit".
- **Key pattern from 8.4**: Server-side weighted total validation -- do NOT trust Gemini's scores without clamping to [0, 100].
- **Key pattern from 4.1**: Validate all returned item IDs against the user's actual wardrobe. Discard any match referencing an invalid ID.
- **Key pattern from 9.4**: Route ordering -- new routes with longer paths MUST be matched BEFORE `ootdPostIdMatch`.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. All AI matching calls go through the Cloud Run API.
- DO NOT create a new Gemini client or AI service. Add `stealThisLook` to the existing `ootd-service.js`.
- DO NOT create new database tables for steal-look results. Results are ephemeral (returned in-memory). Only the saved outfit persists via the existing `outfits` table.
- DO NOT send the friend's actual item photos to Gemini. Send structured metadata only (category, color, style, etc.). Gemini matches based on attributes, not visual similarity.
- DO NOT trust Gemini's match scores without validation. Clamp all scores to [0, 100] and filter out scores < 30.
- DO NOT allow matching against the friend's wardrobe items. Only match against the CURRENT USER's wardrobe.
- DO NOT show the "Steal This Look" button on posts with no tagged items. The feature requires tagged items to function.
- DO NOT implement real-time matching or WebSocket updates. Use standard request-response with loading state.
- DO NOT create a separate outfit creation endpoint for steal-look. Reuse the existing `POST /v1/outfits` from Story 4.3.
- DO NOT skip the migration to update the `outfits.source` CHECK constraint. Without it, saving with `source = 'steal_look'` will fail with a constraint violation.
- DO NOT forget to add `itemRepo`, `geminiClient`, and `aiUsageLogRepo` to `createOotdService` factory. Without them, the steal-look method cannot access wardrobe data or AI services.
- DO NOT import `buildWardrobeSummary` without verifying it's exported. If it's not exported from `shopping-scan-service.js`, either export it or duplicate the logic.
- DO NOT forget the `mounted` guard before `setState` in async callbacks on StealThisLookScreen.
- DO NOT implement "Shop for similar" functionality. That's a future integration with the Shopping Assistant (Epic 8).
- DO NOT include matches with score < 30 in the response. These are filtered out server-side.
- DO NOT use Supabase client or direct database access from Flutter.

### Out of Scope

- **"Shop for similar" integration** with Shopping Assistant (future)
- **Visual image similarity matching** (using Gemini Vision to compare actual photos). This story matches on structured metadata only.
- **Social notification for steal-look actions** (Story 9.6 handles notification preferences)
- **Steal-look history or analytics** (future)
- **Multiple outfit variations from one steal-look** (user can re-trigger for different results)
- **Steal-look on posts from non-members** (posts are gated by squad membership)
- **Real-time match updates** (standard request-response)
- **Partial outfit save** (user saves all best matches as one outfit, or nothing)

### References

- [Source: epics.md - Story 9.5: "Steal This Look" Matcher]
- [Source: epics.md - Epic 9: Social OOTD Feed (Style Squads), FR-SOC-12, FR-SOC-13]
- [Source: prd.md - FR-SOC-12: Users shall use "Steal This Look" on any OOTD post to find similar items in their own wardrobe, with AI-powered matching and fallback]
- [Source: prd.md - FR-SOC-13: "Steal This Look" results shall be color-coded by match quality and saveable as a new outfit]
- [Source: prd.md - Amira persona: "Steal This Look" -- AI scans friend's outfit, finds similar items (85% match cream blouse, 72% match navy trousers)]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Single AI provider: all AI workloads route through Vertex AI / Gemini 2.0 Flash]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Squad membership and role checks gate social operations]
- [Source: architecture.md - ai_usage_log for AI cost telemetry]
- [Source: architecture.md - Epic 9 Social OOTD -> mobile/features/squads, api/modules/squads]
- [Source: ux-design-specification.md - "Steal This Look" interaction: extract items from friend's post, trigger AI similarity search, generate match list, display "Recreate Look" modal]
- [Source: ux-design-specification.md - UX flow: has enough matches -> save as custom outfit, missing key item -> save to shopping wishlist (future)]
- [Source: ux-design-specification.md - Phase 3 Social: OOTD feed cards featuring "Steal This Look" button and reaction clusters]
- [Source: 9-4-reactions-comments.md - OotdPostCard with onReactionTap/onCommentTap, OotdPostDetailScreen with comments, route ordering before ootdPostIdMatch, 939 API tests, 1387 Flutter tests]
- [Source: 9-2-ootd-post-creation.md - ootd_post_items table, getPostItemsByPostId, mapPostItemRow, item tagging is optional]
- [Source: 9-1-squad-creation-management.md - squad-repository.js, getMembership, 7 squad routes]
- [Source: 8-4-purchase-compatibility-scoring.md - buildWardrobeSummary pattern, computeTier, Gemini JSON scoring, AI usage logging with distinct feature names, wardrobe summarization for large wardrobes]
- [Source: 4-1-daily-ai-outfit-generation.md - outfit-generation-service.js Gemini pattern, item ID validation, estimateCost, outfits/outfit_items tables, source column]
- [Source: 4-3-manual-outfit-building.md - POST /v1/outfits endpoint for outfit creation]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented Gemini-based "Steal This Look" matching: `POST /v1/squads/posts/:postId/steal-look` endpoint
- Added `stealThisLook` method to `ootd-service.js` with full Gemini prompt construction, response parsing, score validation (clamp 0-100, filter <30), item ID validation, and AI usage logging
- Imported `buildWardrobeSummary` from `shopping-scan-service.js` for large wardrobe (>50 items) distribution summarization
- Added `getPostItemsWithDetails` repo method for full item metadata retrieval
- Created migration 028 to add 'steal_look' to outfits.source CHECK constraint
- Created `StealLookResult` model with `MatchTier` enum (Excellent/Good/Partial with color codes)
- Created `StealThisLookScreen` with loading state, match results display, color-coded tier badges, save-as-outfit flow, empty wardrobe state, retry on error, Semantics labels
- Added "Steal This Look" button to `OotdPostDetailScreen` (visible only when tagged items exist)
- Added steal-look icon to `OotdPostCard` engagement row with `onStealLookTap` callback
- Wired steal-look navigation in `OotdFeedScreen` and `SquadDetailScreen`
- 22 new API tests: 15 service unit tests + 7 endpoint integration tests
- 44 new Flutter tests: 14 screen widget tests + 22 model tests + 4 detail screen tests + 4 post card tests + 1 ootd service test + 1 api client test
- All 961 API tests pass (939 existing + 22 new), all 1431 Flutter tests pass (1387 existing + 44 new)
- `flutter analyze` shows 11 issues, all pre-existing (0 new issues introduced)

### Change Log

- 2026-03-19: Story 9.5 implementation complete. Added "Steal This Look" Gemini AI matching, migration 028, StealThisLookScreen, and comprehensive tests.

### File List

**New files:**
- `infra/sql/migrations/028_outfit_source_steal_look.sql`
- `apps/mobile/lib/src/features/squads/models/steal_look_result.dart`
- `apps/mobile/lib/src/features/squads/screens/steal_this_look_screen.dart`
- `apps/mobile/test/features/squads/models/steal_look_result_test.dart`
- `apps/mobile/test/features/squads/screens/steal_this_look_screen_test.dart`

**Modified files:**
- `apps/api/src/modules/squads/ootd-service.js` (added stealThisLook method, STEAL_LOOK_PROMPT, updated factory to accept itemRepo/geminiClient/aiUsageLogRepo)
- `apps/api/src/modules/squads/ootd-repository.js` (added getPostItemsWithDetails method)
- `apps/api/src/main.js` (added steal-look route, updated createOotdService wiring)
- `apps/mobile/lib/src/features/squads/services/ootd_service.dart` (added stealThisLook and saveStealLookOutfit methods)
- `apps/mobile/lib/src/core/networking/api_client.dart` (added stealThisLook method)
- `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart` (added Steal This Look button)
- `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart` (added onStealLookTap callback and steal-look icon)
- `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart` (wired onStealLookTap callback)
- `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart` (wired onStealLookTap callback)
- `apps/api/test/modules/squads/ootd-service.test.js` (added 15 steal-look service tests)
- `apps/api/test/modules/squads/ootd-endpoint.test.js` (added 7 steal-look endpoint tests)
- `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart` (added 4 steal-look button tests)
- `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart` (added 4 steal-look icon tests)
- `apps/mobile/test/features/squads/services/ootd_service_test.dart` (added stealThisLook test)
- `apps/mobile/test/core/networking/api_client_test.dart` (added stealThisLook test)
