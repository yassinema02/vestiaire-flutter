# Story 4.1: Daily AI Outfit Generation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the app to suggest a daily outfit based on my wardrobe, the weather, and my calendar events,
so that I don't have to spend time deciding what to wear each morning.

## Acceptance Criteria

1. Given I have at least 3 categorized items in my wardrobe (at least one top-category item and one bottom-category item), when I open the Home screen or pull to refresh, then the system calls `POST /v1/outfits/generate` which invokes Gemini 2.0 Flash to generate 3 outfit suggestions using my wardrobe items, the OutfitContext (weather + calendar events), and returns them as a structured JSON response (FR-OUT-01).

2. Given the API receives a generation request, when it processes the request, then it fetches all the user's wardrobe items from the `items` table (only items with `categorization_status = 'completed'`), serializes the OutfitContext from the request body, constructs a Gemini prompt containing: the item inventory (id, name, category, color, material, pattern, style, season, occasion), the weather context (temperature, feels-like, weather description, clothing constraints), the calendar events (title, event type, formality score), and the current date/day-of-week/season, and sends it to Gemini 2.0 Flash with `responseMimeType: "application/json"` (FR-OUT-01).

3. Given Gemini returns a response, when the API processes it, then each outfit suggestion contains: a list of item IDs (referencing actual items in the user's wardrobe), an outfit name/title, a "why this outfit" explanation string (1-2 sentences explaining the reasoning), and an occasion tag. The API validates that all returned item IDs exist in the user's wardrobe and discards any suggestion with invalid IDs. Each suggestion must contain between 2 and 7 items (FR-OUT-01, FR-OUT-03).

4. Given the generation succeeds, when the API returns the response, then it returns `{ suggestions: [{ id: string, name: string, items: [{ id, name, category, color, photoUrl }], explanation: string, occasion: string }], generatedAt: string }` with HTTP 200. Each suggestion has a temporary UUID generated server-side. The items array contains full item metadata (not just IDs) so the mobile client can display them without additional API calls (FR-OUT-01, FR-OUT-03).

5. Given the generation succeeds, when the API logs the AI call, then it writes to `ai_usage_log` with `feature = "outfit_generation"`, model name, input/output tokens, latency in ms, estimated cost, and status "success" (NFR-OBS-02).

6. Given the Gemini call fails (network error, rate limit, timeout, unparseable response), when the API handles the error, then it returns HTTP 500 with `{ error: "Outfit generation failed", code: "GENERATION_FAILED", message: "..." }`, logs the failure to `ai_usage_log` with status "failure", and the mobile client shows a user-friendly error message: "Unable to generate outfit suggestions right now. Pull to refresh to try again." (FR-OUT-01, NFR-REL-03).

7. Given I have fewer than 3 categorized items in my wardrobe, when I open the Home screen, then the mobile client does NOT call the generation endpoint and instead shows a prompt card: "Add at least 3 items to get outfit suggestions" with a "Add Items" button that navigates to the Add Item screen. The threshold check happens client-side based on the items already loaded by the wardrobe service (FR-OUT-01).

8. Given the generation succeeds and I have at least 3 items, when the Home screen displays the result, then the placeholder "Daily outfit suggestions coming soon" card is replaced with an OutfitSuggestionCard showing: the outfit name, a horizontal scrollable row of item thumbnail images (circular or rounded square, 64x64), the "Why this outfit?" explanation text, and a subtle "AI-generated" indicator. Only the FIRST suggestion is displayed (Story 4.2 adds swipe UI for browsing all 3) (FR-OUT-03).

9. Given the OutfitSuggestionCard is displayed, when I tap on an individual item thumbnail in the card, then nothing happens in this story (Story 4.4 will add item detail navigation). The thumbnails are non-interactive for now (FR-OUT-03).

10. Given I have weather loaded but no calendar events (calendar not connected or no events today), when the generation is triggered, then the OutfitContext is sent with an empty `calendarEvents` array, and the AI generates suggestions based on weather and wardrobe data alone. The generation should NOT fail due to missing calendar data (FR-OUT-01).

11. Given I have weather denied (no weather data available), when I open the Home screen, then the outfit generation is NOT triggered. Outfit generation requires at minimum weather context. The placeholder or "Add items" card is shown instead (FR-OUT-01).

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (188 API tests, 550 Flutter tests) and new tests cover: outfit generation API endpoint (success, failure, validation), Gemini prompt construction, response parsing and validation, AI usage logging, mobile OutfitGenerationService, OutfitSuggestion model, OutfitSuggestionCard widget, HomeScreen integration (generation trigger, loading state, display, error state, minimum items threshold), and API unit tests for the outfit generation service.

## Tasks / Subtasks

- [x] Task 1: API - Create `outfits` and `outfit_items` database migration (AC: 4)
  - [x] 1.1: Create `infra/sql/migrations/013_outfits.sql` with the `outfits` table in `app_public` schema. Columns: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `name TEXT`, `explanation TEXT`, `occasion TEXT`, `source TEXT NOT NULL DEFAULT 'ai' CHECK (source IN ('ai', 'manual'))`, `is_favorite BOOLEAN DEFAULT false`, `created_at TIMESTAMPTZ DEFAULT now()`, `updated_at TIMESTAMPTZ DEFAULT now()`. Add RLS policy: `CREATE POLICY outfits_user_policy ON app_public.outfits FOR ALL USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`. Add updated_at trigger reusing `set_updated_at()`.
  - [x] 1.2: Create `outfit_items` join table in the same migration. Columns: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `outfit_id UUID NOT NULL REFERENCES app_public.outfits(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE`, `position INTEGER NOT NULL DEFAULT 0`, `created_at TIMESTAMPTZ DEFAULT now()`. Add UNIQUE constraint on `(outfit_id, item_id)`. Add RLS policy using same pattern (join through outfits to profiles). Add index: `CREATE INDEX idx_outfit_items_outfit ON app_public.outfit_items(outfit_id)`.
  - [x] 1.3: Add index: `CREATE INDEX idx_outfits_profile ON app_public.outfits(profile_id, created_at DESC)` for efficient user-scoped queries ordered by date.
  - [x] 1.4: Note: This migration creates the tables for future use by Stories 4.2-4.4. Story 4.1 does NOT persist outfits -- it generates suggestions in-memory. Story 4.2 (swipe UI with save) will use the `outfits` and `outfit_items` tables to persist accepted outfits.

- [x] Task 2: API - Create outfit generation service (AC: 1, 2, 3, 5, 6)
  - [x] 2.1: Create `apps/api/src/modules/outfits/outfit-generation-service.js` with `createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo })`. Follow the exact factory pattern of `createCategorizationService` in `apps/api/src/modules/ai/categorization-service.js`.
  - [x] 2.2: Implement `async generateOutfits(authContext, { outfitContext })` method. Steps: (a) check `geminiClient.isAvailable()` -- if false, throw `{ statusCode: 503, message: "AI service unavailable" }`, (b) fetch all user items via `itemRepo.listItems(authContext, {})`, (c) filter to only items with `categorizationStatus === "completed"`, (d) if fewer than 3 categorized items, throw `{ statusCode: 400, message: "At least 3 categorized items required" }`, (e) build the Gemini prompt (see Task 2.4), (f) call Gemini, (g) parse and validate the response (see Task 2.5), (h) log usage to `ai_usage_log`, (i) return the validated suggestions.
  - [x] 2.3: Serialize items for the prompt. For each item, include: `{ id, name, category, color, secondaryColors, pattern, material, style, season, occasion, photoUrl }`. Strip fields that are null. Limit to 200 items maximum (use the first 200 by `created_at DESC`).
  - [x] 2.4: Construct the Gemini prompt. Use this template:
    ```
    You are a personal stylist AI. Generate 3 outfit suggestions for today based on the user's wardrobe and context.

    TODAY'S CONTEXT:
    - Date: {date} ({dayOfWeek})
    - Season: {season}
    - Weather: {weatherDescription}, {temperature}°C (feels like {feelsLike}°C)
    - Location: {locationName}
    - Clothing constraints: {JSON.stringify(clothingConstraints)}
    - Calendar events: {calendarEvents as JSON array, or "No events scheduled" if empty}

    WARDROBE ITEMS (pick from these ONLY — use exact item IDs):
    {items as JSON array}

    RULES:
    1. Each outfit must contain 2-7 items from the wardrobe list above.
    2. Use ONLY item IDs that exist in the wardrobe list. Do NOT invent IDs.
    3. Create complete, wearable outfits (at minimum: a top + bottom, or a dress).
    4. Respect the weather constraints: avoid materials in the "avoidMaterials" list, prefer materials in "preferredMaterials", include required categories.
    5. If calendar events exist, make at least one outfit appropriate for the most formal event.
    6. Vary the suggestions — do not repeat the same items across all 3 outfits.
    7. For each outfit, provide a 1-2 sentence explanation of WHY this outfit works for today.

    Return ONLY valid JSON with this exact structure:
    {
      "suggestions": [
        {
          "name": "Short descriptive outfit name",
          "itemIds": ["uuid-1", "uuid-2", "uuid-3"],
          "explanation": "Why this outfit works for today...",
          "occasion": "one of: everyday, work, formal, party, date-night, outdoor, sport, casual"
        }
      ]
    }
    ```
  - [x] 2.5: Parse and validate the Gemini response. Steps: (a) extract JSON text from `response.candidates[0].content.parts[0].text`, (b) `JSON.parse` the text, (c) validate `suggestions` is an array of 1-3 items, (d) for each suggestion: validate `itemIds` is an array of 2-7 strings, validate each ID exists in the user's item list (build a Set of valid IDs), validate `name` is a non-empty string, validate `explanation` is a non-empty string, default `occasion` to "everyday" if missing. (e) discard any suggestion where ANY itemId is invalid. (f) if zero valid suggestions remain after filtering, throw an error. (g) for each valid suggestion, enrich with full item data: map each `itemId` to `{ id, name, category, color, photoUrl }` from the fetched items list. (h) assign a `crypto.randomUUID()` as the suggestion `id`.
  - [x] 2.6: Log AI usage. Follow the exact pattern from `categorization-service.js`: extract `usageMetadata` from the Gemini response, compute `estimateCost()` using the same pricing formula, call `aiUsageLogRepo.logUsage(authContext, { feature: "outfit_generation", model: "gemini-2.0-flash", inputTokens, outputTokens, latencyMs, estimatedCostUsd, status: "success" })`. On failure, log with `status: "failure"` and `errorMessage`.
  - [x] 2.7: Error handling: wrap the entire method in try/catch. On Gemini failure, log usage with "failure" status and re-throw with `{ statusCode: 500, message: "Outfit generation failed" }`. Do NOT swallow errors -- let the route handler return the error to the client.

- [x] Task 3: API - Add `POST /v1/outfits/generate` endpoint (AC: 1, 4, 6)
  - [x] 3.1: Add route `POST /v1/outfits/generate` to `apps/api/src/main.js`. Place it after the calendar event routes and before `notFound`. The route: authenticates the user via `requireAuth`, reads the request body, calls `outfitGenerationService.generateOutfits(authContext, { outfitContext: body.outfitContext })`, and returns 200 with the result.
  - [x] 3.2: Wire up `outfitGenerationService` in `createRuntime()`: instantiate `createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo })` and add it to the runtime object. Destructure it in `handleRequest`.
  - [x] 3.3: Handle errors using the existing `mapError` pattern. Add support for `statusCode: 503` mapping: `{ statusCode: 503, body: { error: "Service Unavailable", code: "SERVICE_UNAVAILABLE", message: error.message } }`.
  - [x] 3.4: Request body shape: `{ outfitContext: { temperature, feelsLike, weatherCode, weatherDescription, clothingConstraints: {...}, locationName, date, dayOfWeek, season, temperatureCategory, calendarEvents: [...] } }`. The `outfitContext` matches the `OutfitContext.toJson()` output from the mobile client.

- [x] Task 4: Mobile - Create OutfitSuggestion model (AC: 4, 8)
  - [x] 4.1: Create `apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart` with an `OutfitSuggestion` class. Fields: `String id`, `String name`, `List<OutfitSuggestionItem> items`, `String explanation`, `String occasion`. Include `factory OutfitSuggestion.fromJson(Map<String, dynamic> json)` and `Map<String, dynamic> toJson()`.
  - [x] 4.2: Create `OutfitSuggestionItem` class in the same file. Fields: `String id`, `String? name`, `String? category`, `String? color`, `String? photoUrl`. Include `factory OutfitSuggestionItem.fromJson(Map<String, dynamic> json)` and `Map<String, dynamic> toJson()`.
  - [x] 4.3: Create `OutfitGenerationResult` class in the same file. Fields: `List<OutfitSuggestion> suggestions`, `DateTime generatedAt`. Include `factory OutfitGenerationResult.fromJson(Map<String, dynamic> json)`.

- [x] Task 5: Mobile - Create OutfitGenerationService (AC: 1, 7, 10, 11)
  - [x] 5.1: Create `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart` with an `OutfitGenerationService` class. Constructor accepts `ApiClient`.
  - [x] 5.2: Implement `Future<OutfitGenerationResult?> generateOutfits(OutfitContext context)` that: (a) serializes the context via `context.toJson()`, (b) calls `_apiClient.authenticatedPost("/v1/outfits/generate", body: { "outfitContext": contextJson })`, (c) parses the response into `OutfitGenerationResult`, (d) returns `null` on any error (catch `ApiException` and other exceptions, do not throw).
  - [x] 5.3: Implement `bool hasEnoughItems(List<dynamic> items)` static helper that returns `true` if the list has >= 3 items with `categorizationStatus == 'completed'`. This is used by HomeScreen to decide whether to show the "add more items" prompt vs triggering generation.

- [x] Task 6: Mobile - Add `generateOutfits` method to ApiClient (AC: 1)
  - [x] 6.1: Add `Future<Map<String, dynamic>> generateOutfits(Map<String, dynamic> outfitContext)` method to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedPost("/v1/outfits/generate", body: { "outfitContext": outfitContext })`. This is a simple pass-through; the OutfitGenerationService handles the response parsing.

- [x] Task 7: Mobile - Create OutfitSuggestionCard widget (AC: 8, 9)
  - [x] 7.1: Create `apps/mobile/lib/src/features/home/widgets/outfit_suggestion_card.dart` with an `OutfitSuggestionCard` StatelessWidget. Constructor accepts `OutfitSuggestion suggestion`.
  - [x] 7.2: Card layout following Vibrant Soft-UI design system (white background, 16px border radius, subtle shadow matching existing cards on HomeScreen): (a) Card header: outfit name (16px, #111827, bold) with a small "AI" chip/badge (12px, #4F46E5 text, #EEF2FF background, 8px border radius) to the right. (b) Item thumbnails: a horizontal `SingleChildScrollView` row of item images. Each image is a 64x64 rounded square (`ClipRRect` with 10px border radius) using `CachedNetworkImage` (or `Image.network` with placeholder). Show a gray placeholder container if `photoUrl` is null. Below each image, show the item's category label (11px, #6B7280, max 1 line). (c) Explanation section: the "Why this outfit?" label (13px, #4F46E5, semibold) followed by the explanation text (13px, #4B5563). (d) All sections have 16px horizontal padding and 12px vertical spacing.
  - [x] 7.3: Add `Semantics` labels: "Outfit suggestion: [name]" on the card, "Outfit item: [category or name]" on each item thumbnail, "Outfit explanation: [explanation text]" on the explanation section.
  - [x] 7.4: Item thumbnails are NOT tappable in this story (AC 9). Do not add `GestureDetector` or `InkWell` to them.

- [x] Task 8: Mobile - Create OutfitMinimumItemsCard widget (AC: 7)
  - [x] 8.1: Create `apps/mobile/lib/src/features/home/widgets/outfit_minimum_items_card.dart` with an `OutfitMinimumItemsCard` StatelessWidget. Constructor accepts `VoidCallback onAddItems`.
  - [x] 8.2: Display a card matching the HomeScreen placeholder style (white background, 16px border radius, 20px padding, subtle shadow): (a) A wardrobe icon (Icons.checkroom, 32px, #9CA3AF). (b) Title: "Build your wardrobe" (16px, #111827, bold). (c) Subtitle: "Add at least 3 items to get AI outfit suggestions" (13px, #6B7280). (d) A primary button "Add Items" (#4F46E5 background, white text, 12px border radius, 44px height) that calls `onAddItems`.
  - [x] 8.3: Add `Semantics` label: "Add more items to receive outfit suggestions".

- [x] Task 9: Mobile - Integrate outfit generation into HomeScreen (AC: 1, 7, 8, 10, 11)
  - [x] 9.1: Add `OutfitGenerationService` as an optional constructor parameter to `HomeScreen` (following existing DI pattern). Default creates a new instance using the app's ApiClient.
  - [x] 9.2: Add state fields to `HomeScreenState`: `OutfitGenerationResult? _outfitResult`, `bool _isGeneratingOutfit = false`, `String? _outfitError`, `List<dynamic>? _wardrobeItems` (cached from a listItems call).
  - [x] 9.3: Add `_fetchWardrobeItemCount()` async method that calls `ApiClient.listItems()` and stores the result in `_wardrobeItems`. Call this in `_initialize()` after weather loads. This is used to check the minimum-items threshold client-side.
  - [x] 9.4: Add `_generateOutfits()` async method that: (a) checks `outfitContext != null` (weather must be loaded), (b) checks `_wardrobeItems` has >= 3 categorized items using `OutfitGenerationService.hasEnoughItems()`, (c) sets `_isGeneratingOutfit = true` in state, (d) calls `_outfitGenerationService.generateOutfits(outfitContext!)`, (e) on success, sets `_outfitResult` in state and clears error, (f) on failure/null result, sets `_outfitError` in state, (g) sets `_isGeneratingOutfit = false` in state. Call this in `_initialize()` after weather loads AND wardrobe items are fetched, but only if weather is available (AC 11).
  - [x] 9.5: Update `_handleRefresh()`: after existing weather and calendar refresh, call `_generateOutfits()` to regenerate suggestions on pull-to-refresh.
  - [x] 9.6: Update `build()`: replace the static placeholder card with dynamic content based on state:
    - If `_state != _HomeState.weatherLoaded`: keep the existing placeholder (or show nothing -- weather is required for generation).
    - If weather loaded but `_wardrobeItems == null` or has < 3 categorized items: show `OutfitMinimumItemsCard(onAddItems: _navigateToAddItem)`.
    - If `_isGeneratingOutfit`: show a shimmer/loading card (matching card dimensions, with shimmer overlay pattern from Story 2.2 or a simple `CircularProgressIndicator` centered in a card).
    - If `_outfitResult != null` and has suggestions: show `OutfitSuggestionCard(suggestion: _outfitResult!.suggestions.first)` (display first suggestion only -- Story 4.2 adds swipe for all 3).
    - If `_outfitError != null`: show an error card with "Unable to generate outfit suggestions right now. Pull to refresh to try again." text and a retry button.
  - [x] 9.7: Add `_navigateToAddItem()` method that switches to the Add tab (index 2) in the MainShellScreen. Since HomeScreen is inside a `MainShellScreen` with a `NavigationBar`, find the `MainShellScreenState` ancestor and call its tab-switching method, OR navigate to the AddItemScreen directly via `Navigator.push`.

- [x] Task 10: API - Unit tests for outfit generation service (AC: 1, 2, 3, 5, 6, 12)
  - [x] 10.1: Create `apps/api/test/modules/outfits/outfit-generation-service.test.js`:
    - `generateOutfits` calls Gemini with correct prompt structure containing weather context and item inventory.
    - `generateOutfits` returns validated suggestions with enriched item data.
    - `generateOutfits` discards suggestions with invalid item IDs.
    - `generateOutfits` throws error when fewer than 3 categorized items.
    - `generateOutfits` throws 503 when Gemini is unavailable.
    - `generateOutfits` logs successful usage to ai_usage_log.
    - `generateOutfits` logs failure to ai_usage_log when Gemini call fails.
    - `generateOutfits` handles Gemini returning unparseable JSON gracefully.
    - `generateOutfits` handles Gemini returning empty suggestions array.
    - `generateOutfits` works with empty calendarEvents array.
    - `generateOutfits` limits items to 200 in the prompt.
    - Suggestion validation: filters out suggestions with < 2 or > 7 items.
    - Each suggestion gets a UUID id assigned.

- [x] Task 11: API - Integration tests for POST /v1/outfits/generate endpoint (AC: 1, 4, 6, 12)
  - [x] 11.1: Create `apps/api/test/modules/outfits/outfit-generation.test.js`:
    - `POST /v1/outfits/generate` requires authentication (401 without token).
    - `POST /v1/outfits/generate` returns 200 with suggestions on success.
    - `POST /v1/outfits/generate` returns suggestions with correct structure (id, name, items, explanation, occasion).
    - `POST /v1/outfits/generate` returns error when user has fewer than 3 categorized items.
    - `POST /v1/outfits/generate` returns 503 when Gemini is unavailable.
    - `POST /v1/outfits/generate` works with empty calendarEvents.
    - `POST /v1/outfits/generate` returns 500 when Gemini call fails.

- [x] Task 12: Mobile - Unit tests for OutfitSuggestion model (AC: 4, 12)
  - [x] 12.1: Create `apps/mobile/test/features/outfits/models/outfit_suggestion_test.dart`:
    - `OutfitSuggestion.fromJson()` correctly parses all fields.
    - `OutfitSuggestion.toJson()` serializes all fields.
    - `OutfitSuggestionItem.fromJson()` correctly parses all fields.
    - `OutfitSuggestionItem.fromJson()` handles null name and photoUrl.
    - `OutfitGenerationResult.fromJson()` parses suggestions array and generatedAt.
    - Round-trip: toJson then fromJson returns equivalent object.

- [x] Task 13: Mobile - Unit tests for OutfitGenerationService (AC: 1, 7, 10, 12)
  - [x] 13.1: Create `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart`:
    - `generateOutfits` calls API with serialized OutfitContext.
    - `generateOutfits` returns parsed OutfitGenerationResult on success.
    - `generateOutfits` returns null on API error.
    - `generateOutfits` returns null on network error.
    - `hasEnoughItems` returns true when >= 3 categorized items.
    - `hasEnoughItems` returns false when < 3 categorized items.
    - `hasEnoughItems` excludes items without completed categorization.

- [x] Task 14: Mobile - Widget tests for OutfitSuggestionCard (AC: 8, 9, 12)
  - [x] 14.1: Create `apps/mobile/test/features/home/widgets/outfit_suggestion_card_test.dart`:
    - Renders outfit name.
    - Renders "AI" badge/chip.
    - Renders item thumbnails in a horizontal scrollable row.
    - Shows category label below each item thumbnail.
    - Renders "Why this outfit?" label and explanation text.
    - Renders gray placeholder for items with null photoUrl.
    - Semantics labels are present for card, items, and explanation.
    - Item thumbnails are NOT tappable (no gesture handler).

- [x] Task 15: Mobile - Widget tests for OutfitMinimumItemsCard (AC: 7, 12)
  - [x] 15.1: Create `apps/mobile/test/features/home/widgets/outfit_minimum_items_card_test.dart`:
    - Renders "Build your wardrobe" title.
    - Renders "Add at least 3 items" subtitle.
    - "Add Items" button calls onAddItems callback.
    - Semantics label is present.

- [x] Task 16: Mobile - Widget tests for HomeScreen outfit integration (AC: 1, 7, 8, 10, 11, 12)
  - [x] 16.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When weather loaded and >= 3 categorized items, outfit generation is triggered.
    - When generation succeeds, OutfitSuggestionCard is displayed.
    - When generation fails, error card with "Unable to generate" message is shown.
    - When < 3 categorized items, OutfitMinimumItemsCard is shown.
    - When weather is denied, no outfit generation is triggered.
    - Pull-to-refresh triggers outfit re-generation.
    - Loading state shows shimmer/loading indicator during generation.
    - All existing HomeScreen tests continue to pass (permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, cache-first loading, pull-to-refresh, staleness indicator, event override).

- [x] Task 17: Regression testing (AC: all)
  - [x] 17.1: Run `flutter analyze` -- zero issues.
  - [x] 17.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 17.3: Run `npm --prefix apps/api test` -- all existing + new API tests pass.
  - [x] 17.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, event override, cache-first loading, pull-to-refresh, staleness indicator.
  - [x] 17.5: Verify the outfit suggestion card renders correctly and does not interfere with existing layout elements.
  - [x] 17.6: Verify the placeholder card is removed and replaced with the appropriate outfit state widget.

## Dev Notes

- This is the FIRST story in Epic 4 (AI Outfit Engine). It introduces the core AI outfit generation capability, building on all the context infrastructure created in Epic 3 (weather, calendar events, OutfitContext) and the wardrobe data from Epic 2 (items with full taxonomy).
- The primary FRs covered are FR-OUT-01 (generate outfit suggestions using Gemini AI with wardrobe + weather + calendar + preferences) and FR-OUT-03 (display primary daily outfit with "Why this outfit?" explanation).
- **FR-OUT-02 (persist outfits to `outfits` table) is PARTIALLY covered** -- this story creates the database tables but does NOT persist generated suggestions. Persistence happens in Story 4.2 when the user swipes right to save an outfit.
- **FR-OUT-04 (swipe UI) is OUT OF SCOPE.** Story 4.2 handles the Tinder-style swipe interface for browsing multiple suggestions. This story displays only the first suggestion.
- **FR-OUT-05 (manual outfit building) is OUT OF SCOPE.** Story 4.3 covers this.
- **FR-OUT-06, FR-OUT-07, FR-OUT-08 (outfit history, favorites, delete) are OUT OF SCOPE.** Story 4.4 covers this.
- **FR-OUT-09, FR-OUT-10 (usage limits) are OUT OF SCOPE.** Story 4.5 covers this. This story does NOT enforce generation limits.
- **FR-OUT-11 (recency bias / avoid recently worn items) is OUT OF SCOPE.** Story 4.6 covers this. The Gemini prompt in this story does not include wear history data.
- **NFR-PERF-02 (< 6 second end-to-end generation)** is a target. The Gemini call should complete within this budget. The prompt is designed to be concise to minimize latency.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/013_outfits.sql` (outfits + outfit_items tables, RLS, indexes)
  - `apps/api/src/modules/outfits/outfit-generation-service.js` (generation service)
  - `apps/api/test/modules/outfits/outfit-generation-service.test.js`
  - `apps/api/test/modules/outfits/outfit-generation.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart` (OutfitSuggestion, OutfitSuggestionItem, OutfitGenerationResult)
  - `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart` (OutfitGenerationService)
  - `apps/mobile/lib/src/features/home/widgets/outfit_suggestion_card.dart` (OutfitSuggestionCard)
  - `apps/mobile/lib/src/features/home/widgets/outfit_minimum_items_card.dart` (OutfitMinimumItemsCard)
  - `apps/mobile/test/features/outfits/models/outfit_suggestion_test.dart`
  - `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart`
  - `apps/mobile/test/features/home/widgets/outfit_suggestion_card_test.dart`
  - `apps/mobile/test/features/home/widgets/outfit_minimum_items_card_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add POST /v1/outfits/generate route, wire up outfitGenerationService in createRuntime, add 503 to mapError)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add generateOutfits method)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add OutfitGenerationService DI, generation logic, state fields, replace placeholder card)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add outfit generation integration tests)

### Technical Requirements

- **New API endpoint:** `POST /v1/outfits/generate` -- accepts `{ outfitContext: {...} }`, returns `{ suggestions: [...], generatedAt: "..." }` with HTTP 200. Requires authentication.
- **Gemini 2.0 Flash model identifier:** `gemini-2.0-flash` -- same model used for categorization and event classification.
- **Gemini JSON mode:** Use `generationConfig: { responseMimeType: "application/json" }` for structured output, matching the pattern in `categorization-service.js`.
- **AI usage logging:** Feature name = `"outfit_generation"`. Log to `ai_usage_log` with the same fields as categorization (model, tokens, latency, cost, status).
- **New database tables:** `outfits` and `outfit_items` in `app_public` schema with RLS. These tables are created in this story but populated by Story 4.2.
- **OutfitContext serialization:** The mobile client serializes the existing `OutfitContext` (from Story 3.3) via `toJson()` and sends it as the `outfitContext` field in the request body. The API uses this directly in the Gemini prompt -- it does NOT re-derive weather or calendar data server-side.
- **Item data flow:** The API fetches items from the database (not from the client request). The client sends only the context; the API has authoritative access to the user's wardrobe. This prevents client-side tampering.
- **Suggestion IDs are ephemeral:** Each suggestion gets a `crypto.randomUUID()` on generation. These are NOT database IDs -- they are used for client-side tracking. Story 4.2 will persist suggestions to the `outfits` table when the user accepts them.

### Architecture Compliance

- **AI calls are brokered only by Cloud Run:** The mobile client sends the context to the API; the API calls Gemini. The mobile client NEVER calls Gemini directly. This follows the architecture principle.
- **Server authority for item data:** The API fetches the user's items from Cloud SQL. The mobile client does not send item data in the generation request. This ensures the AI uses authoritative wardrobe data.
- **Database boundary owns canonical state:** The `outfits` and `outfit_items` tables will store persistent outfits (Story 4.2). RLS policies enforce user-scoped access.
- **Mobile boundary owns presentation:** The `OutfitSuggestionCard` widget, loading states, and error handling are entirely client-side presentation concerns.
- **Graceful AI degradation:** If Gemini fails, the mobile client shows a user-friendly error with retry capability. The API logs the failure. The app does not crash.
- **Epic 4 component mapping:** `mobile/features/outfits`, `mobile/features/home`, `api/modules/outfits`, `api/modules/ai` -- matches the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `http`, `cached_network_image` (for item thumbnails in the suggestion card), and Material widgets.
- No new API dependencies. Uses existing `@google-cloud/vertexai` (via the shared `geminiClient`), `pg`, `crypto` (built-in Node.js module for `randomUUID()`).

### File Structure Requirements

- New API module: `apps/api/src/modules/outfits/` -- follows the pattern of `modules/ai/`, `modules/items/`, `modules/calendar/`.
- New mobile feature: `apps/mobile/lib/src/features/outfits/` with `models/` and `services/` subdirectories. This is a new feature module per the architecture's project structure.
- New widgets in `apps/mobile/lib/src/features/home/widgets/` -- follows existing pattern of home-feature widgets (weather_widget, dressing_tip_widget, event_summary_widget, calendar_permission_card, etc.).
- Migration file: `013_outfits.sql` -- follows sequential numbering after `012_calendar_events.sql`.
- Test files mirror source structure under `apps/api/test/` and `apps/mobile/test/`.

### Testing Requirements

- API unit tests must verify:
  - Gemini prompt contains weather context, item inventory, and calendar events
  - Response parsing validates item IDs against the user's wardrobe
  - Invalid item IDs cause suggestion to be discarded
  - Minimum item count is enforced (400 for < 3 items)
  - AI unavailability returns 503
  - AI usage is logged for both success and failure
  - Unparseable Gemini response is handled gracefully
  - Empty calendarEvents array is handled correctly
  - Items are limited to 200 in the prompt
- API integration tests must verify:
  - POST /v1/outfits/generate requires authentication
  - POST /v1/outfits/generate returns correct response structure
  - POST /v1/outfits/generate handles various error scenarios
- Mobile unit tests must verify:
  - OutfitSuggestion model serialization round-trip
  - OutfitGenerationService calls API correctly
  - OutfitGenerationService returns null on error
  - hasEnoughItems threshold logic
- Mobile widget tests must verify:
  - OutfitSuggestionCard renders all components (name, items, explanation, AI badge)
  - OutfitMinimumItemsCard renders prompt and button
  - HomeScreen integration: generation trigger, loading state, success display, error display, minimum items check
  - All existing HomeScreen tests continue to pass
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new API tests pass)

### Previous Story Intelligence

- **Story 3.6 (final Epic 3 story)** completed with 188 API tests and 550 Flutter tests. All must continue to pass.
- **Story 3.6** established: PATCH /v1/calendar/events/:id endpoint, EventDetailBottomSheet, `authenticatedPatch` public wrapper on ApiClient, CalendarEvent `copyWith` method. HomeScreen constructor now has 8 optional DI parameters.
- **Story 3.5** established: `calendar_events` table, CalendarEvent + CalendarEventContext models, CalendarEventService, EventSummaryWidget, POST /v1/calendar/events/sync and GET /v1/calendar/events endpoints. The OutfitContext now includes `calendarEvents` field.
- **Story 3.3** established: OutfitContext model with `toJson()`/`fromJson()`, OutfitContextService, WeatherClothingMapper, ClothingConstraints with `primaryTip`, DressingTipWidget. OutfitContext was explicitly designed as "the contract for Story 4.1" -- its `toJson()` output is what this story sends to the API.
- **Story 3.3 key quote:** "Story 4.1 will import and use `OutfitContextService.getCurrentContext()` to get the weather-aware context, then add calendar data (from Stories 3.5-3.6), wardrobe items, and wear history before sending to Gemini."
- **Story 2.3** established: `categorization-service.js` pattern (Gemini call with JSON mode, taxonomy validation, AI usage logging), `ai_usage_log` table, `geminiClient` singleton. This story's outfit generation service follows the IDENTICAL pattern.
- **Story 2.5** established: `listItems` repository method with dynamic WHERE clauses, server-side filtering. This story calls `listItems(authContext, {})` with no filters to get all items.
- **Story 2.3 key pattern:** Fire-and-forget categorization uses `.catch()`. Outfit generation is NOT fire-and-forget -- it is synchronous request-response because the mobile client needs the result immediately.
- **HomeScreen constructor parameters (as of Story 3.6):** `locationService` (required), `weatherService` (required), `sharedPreferences` (optional), `weatherCacheService` (optional), `outfitContextService` (optional), `calendarService` (optional), `calendarPreferencesService` (optional), `calendarEventService` (optional). This story adds `outfitGenerationService` (optional).
- **HomeScreen state (as of Story 3.6):** `_state` (_HomeState enum), `_calendarState` (_CalendarState enum), `_weatherData`, `_forecastData`, `_errorMessage`, `_lastUpdatedLabel`, `outfitContext`, `_dressingTip`, `_calendarEvents`. This story adds: `_outfitResult`, `_isGeneratingOutfit`, `_outfitError`, `_wardrobeItems`.
- **The static placeholder card** in HomeScreen (lines 484-507 in the current `home_screen.dart`) says "Daily outfit suggestions coming soon". This story replaces it with the dynamic outfit state widget.
- **API `createRuntime()` currently returns:** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`. This story adds `outfitGenerationService`.
- **API `handleRequest` destructuring (line 180):** Currently destructures `config`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `calendarService`. This story adds `outfitGenerationService`.
- **`mapError` function** currently handles 400, 401, 403, 404, and 500. This story adds 503 for AI service unavailable.
- **Key learning from Story 2.3:** The Gemini JSON mode (`responseMimeType: "application/json"`) is critical for getting parseable structured output. Without it, responses may contain markdown formatting.
- **Key learning from Story 3.5:** Mock `DeviceCalendarPlugin` issues -- `Result.isSuccess` is a computed getter. For HomeScreen tests, mock the CalendarEventService rather than the plugin directly.
- **Key learning from Story 3.6:** When testing HomeScreen with bottom sheets, use `showModalBottomSheet` with `isScrollControlled: true`. The `Navigator.pop(context)` call closes the sheet.

### Key Anti-Patterns to Avoid

- DO NOT persist generated outfit suggestions to the database in this story. Persistence is Story 4.2. Generated suggestions are returned in-memory.
- DO NOT implement the swipe UI. Story 4.2 handles the Tinder-style swipe interface. This story shows only the first suggestion in a static card.
- DO NOT enforce usage limits (3/day for free users). Story 4.5 handles usage limits. This story generates without checking quotas.
- DO NOT include wear history in the Gemini prompt. Story 4.6 handles recency bias mitigation by adding recently-worn items to the context.
- DO NOT send wardrobe item data from the mobile client. The API fetches items from the database server-side. Only the OutfitContext is sent from the client.
- DO NOT call Gemini from the mobile client. All AI calls go through the Cloud Run API.
- DO NOT block the HomeScreen load on outfit generation. Generation is async -- show loading state while generating, and display results when ready.
- DO NOT trigger outfit generation when weather is not available. Weather context is required for meaningful suggestions.
- DO NOT create a separate Gemini client. Reuse the existing `geminiClient` singleton from `createRuntime()`.
- DO NOT make the generation endpoint fire-and-forget. Unlike categorization and background removal, outfit generation is synchronous -- the client waits for the response.
- DO NOT add a new tab or screen for outfit display in this story. The outfit suggestion is displayed on the HomeScreen in place of the placeholder card.
- DO NOT modify the existing `OutfitContext` model or `OutfitContextService`. They are consumed as-is. The `toJson()` output is the request payload.
- DO NOT create the `outfits/` API module directory path with any additional service files beyond the generation service. The outfit repository (for CRUD on the `outfits` table) will be created in Story 4.2.

### References

- [Source: epics.md - Story 4.1: Daily AI Outfit Generation]
- [Source: epics.md - Epic 4: AI Outfit Engine]
- [Source: prd.md - FR-OUT-01: Generate outfit suggestions using Gemini AI considering wardrobe, weather, calendar, preferences, wear history]
- [Source: prd.md - FR-OUT-03: Home screen shall display primary daily outfit with "Why this outfit?" explanation]
- [Source: prd.md - NFR-PERF-02: AI outfit generation end-to-end < 6 seconds]
- [Source: prd.md - NFR-OBS-02: AI API costs logged per-user in ai_usage_log]
- [Source: prd.md - NFR-REL-03: AI service degradation: graceful fallback]
- [Source: architecture.md - AI Orchestration: outfit generation, Gemini 2.0 Flash]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Data Architecture: outfits, outfit_items tables]
- [Source: architecture.md - Epic 4 AI Outfit Engine -> mobile/features/outfits, api/modules/outfits, api/modules/ai]
- [Source: ux-design-specification.md - Daily Outfit Swipe Card: primary interaction surface for viewing outfit]
- [Source: ux-design-specification.md - Context Over Catalog: show what to wear right now]
- [Source: ux-design-specification.md - Zero-State Avoidance: never show blank Home screen, explain why and provide action]
- [Source: ux-design-specification.md - Loading States: shimmer skeleton screens matching expected content shape]
- [Source: ux-design-specification.md - Error Recovery: clear non-judgmental inline error, always provide manual fallback]
- [Source: 3-3-practical-weather-aware-outfit-context.md - OutfitContext model, "contract for Story 4.1"]
- [Source: 3-5-calendar-event-fetching-classification.md - CalendarEventContext, OutfitContext.calendarEvents extension]
- [Source: 2-3-ai-item-categorization-tagging.md - categorization-service.js pattern, Gemini JSON mode, AI usage logging]
- [Source: 2-5-wardrobe-grid-filtering.md - listItems with server-side filtering]
- [Source: apps/api/src/modules/ai/categorization-service.js - Gemini call pattern, taxonomy validation, estimateCost]
- [Source: apps/api/src/modules/ai/gemini-client.js - isAvailable(), getGenerativeModel()]
- [Source: apps/api/src/modules/items/repository.js - listItems, mapItemRow]
- [Source: apps/api/src/main.js - createRuntime, handleRequest, mapError, route patterns]
- [Source: apps/mobile/lib/src/core/weather/outfit_context.dart - OutfitContext.toJson()]
- [Source: apps/mobile/lib/src/core/weather/outfit_context_service.dart - buildContextFromWeather]
- [Source: apps/mobile/lib/src/core/networking/api_client.dart - authenticatedPost pattern]
- [Source: apps/mobile/lib/src/features/home/screens/home_screen.dart - HomeScreenState, placeholder card, DI pattern]
