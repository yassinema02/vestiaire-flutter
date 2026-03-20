# Story 4.2: Outfit Generation Swipe UI

Status: done

## Story

As a User,
I want to quickly review and accept or reject outfit suggestions by swiping through them,
so that I can find a look I like interactively and save it to my outfits list.

## Acceptance Criteria

1. Given the AI has generated outfit suggestions (3 suggestions from Story 4.1), when I view the Home screen, then the single static `OutfitSuggestionCard` is replaced with a swipeable card stack showing all suggestions (not just the first one), with a visual indicator showing the current position (e.g., "1 of 3") (FR-OUT-04).

2. Given I am viewing an outfit suggestion card in the swipe stack, when I swipe right (or the card passes the 40% horizontal threshold), then the card animates off-screen to the right with a green "Save" overlay effect, the outfit is persisted to the `outfits` and `outfit_items` tables via `POST /v1/outfits`, and the next suggestion is shown (or "all done" state if last) (FR-OUT-02, FR-OUT-04).

3. Given I am viewing an outfit suggestion card in the swipe stack, when I swipe left (or the card passes the 40% horizontal threshold), then the card animates off-screen to the left with a red "Skip" overlay effect, the suggestion is discarded without persistence, and the next suggestion is shown (FR-OUT-04).

4. Given I am dragging a card horizontally, when the drag distance is less than the 40% threshold and I release, then the card animates back to center with a spring animation, no action is taken, and the overlay fades away (FR-OUT-04).

5. Given I am dragging a card to the right, when the card passes 20% horizontal offset, then a semi-transparent green overlay with a checkmark icon and "Save" label gradually appears on the card. Similarly, dragging left shows a semi-transparent red overlay with an X icon and "Skip" label. The overlay opacity increases proportionally to the drag distance (FR-OUT-04).

6. Given I swipe right on a suggestion, when the API call `POST /v1/outfits` succeeds, then the outfit is saved with `source = 'ai'`, the outfit name, explanation, and occasion from the suggestion are persisted, and all item associations are created in `outfit_items` with correct `position` values. A success snackbar appears: "Outfit saved!" (FR-OUT-02).

7. Given I swipe right on a suggestion, when the API call `POST /v1/outfits` fails (network error, server error), then the error is handled gracefully: a snackbar shows "Failed to save outfit. Please try again.", the card does NOT advance (stays on current suggestion so the user can retry), and the error is logged (FR-OUT-02).

8. Given the API receives a `POST /v1/outfits` request, when the request body contains `{ name, explanation, occasion, source, items: [{ itemId, position }] }`, then the API creates a row in `app_public.outfits` with the authenticated user's `profile_id` and creates rows in `app_public.outfit_items` for each item, all within a single database transaction. The API returns the created outfit with its generated UUID `id` and HTTP 201 (FR-OUT-02).

9. Given the API receives a `POST /v1/outfits` request, when any `itemId` in the items array does not belong to the authenticated user, then the API returns HTTP 400 with `{ error: "Bad Request", code: "INVALID_ITEM", message: "One or more items not found" }`. Item ownership is validated by joining `items` to `profiles` using the auth context (FR-OUT-02).

10. Given I have swiped through all 3 suggestions (saved or skipped each one), when the last card is actioned, then the swipe stack shows a completion state: "All suggestions reviewed" with an option to "Generate new suggestions" (pull to refresh) or a summary of saved outfits count (e.g., "You saved 2 outfits today") (FR-OUT-04).

11. Given I tap the "Save" or "Skip" buttons below the card (accessible alternative to swiping), when I tap "Save", then the same save logic as swipe-right is triggered. When I tap "Skip", then the same skip logic as swipe-left is triggered. These buttons provide accessibility for users who cannot or prefer not to swipe (FR-OUT-04, WCAG AA).

12. Given I have haptic feedback enabled on my device, when I swipe right to save an outfit, then a medium impact haptic is triggered on the save action. When I swipe left to skip, a light impact haptic is triggered (FR-OUT-04).

13. Given a screen reader is active, when the swipe card is focused, then the `Semantics` widget announces: "Outfit suggestion [N] of [total]: [outfit name]. Swipe right to save, swipe left to skip." The save and skip buttons have appropriate `Semantics` labels (WCAG AA).

14. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (208 API tests, 583 Flutter tests) and new tests cover: outfit save API endpoint (success, validation, auth), outfit repository CRUD, swipeable card widget (gestures, animations, overlays, completion state), outfit persistence service, HomeScreen integration (swipe stack replaces single card), and accessibility.

## Tasks / Subtasks

- [x] Task 1: API - Create outfit repository for CRUD operations (AC: 8, 9)
  - [x]1.1: Create `apps/api/src/modules/outfits/outfit-repository.js` with `createOutfitRepository({ pool })`. Follow the exact factory pattern of `createItemRepository` and `createCalendarEventRepository`.
  - [x]1.2: Implement `async createOutfit(authContext, { name, explanation, occasion, source, items })` method. Steps: (a) begin transaction, (b) set `app.current_user_id` via `set_config`, (c) get the user's `profile_id` from `app_public.profiles` where `firebase_uid = authContext.userId`, (d) validate all item IDs belong to the user by querying `SELECT id FROM app_public.items WHERE id = ANY($1::uuid[]) AND profile_id = $2` -- if count doesn't match `items.length`, throw `{ statusCode: 400, message: "One or more items not found", code: "INVALID_ITEM" }`, (e) insert into `app_public.outfits` with columns `(profile_id, name, explanation, occasion, source)` and `RETURNING *`, (f) for each item in `items`, insert into `app_public.outfit_items` with `(outfit_id, item_id, position)`, (g) commit transaction, (h) return the created outfit row with the items array.
  - [x]1.3: Implement `async getOutfit(authContext, outfitId)` method that fetches a single outfit by ID with its items joined. Query: `SELECT o.*, json_agg(json_build_object('id', oi.item_id, 'position', oi.position, 'name', i.name, 'category', i.category, 'color', i.color, 'photoUrl', i.photo_url) ORDER BY oi.position) as items FROM app_public.outfits o LEFT JOIN app_public.outfit_items oi ON oi.outfit_id = o.id LEFT JOIN app_public.items i ON i.id = oi.item_id WHERE o.id = $1 GROUP BY o.id`. RLS enforces user scope.
  - [x]1.4: All queries must set `app.current_user_id` via `set_config` before executing, wrapped in a transaction with `begin`/`commit`/`rollback`. Follow the exact pattern in `calendar-event-repository.js` and `ai-usage-log-repository.js`.
  - [x]1.5: Map database row to camelCase response using a `mapOutfitRow(row)` helper function. Map: `id`, `profileId` (from `profile_id`), `name`, `explanation`, `occasion`, `source`, `isFavorite` (from `is_favorite`), `createdAt` (from `created_at`), `updatedAt` (from `updated_at`), `items` (parsed from JSON aggregate or the items array).

- [x]Task 2: API - Add `POST /v1/outfits` endpoint (AC: 8, 9)
  - [x]2.1: Wire up `outfitRepository` in `createRuntime()` in `apps/api/src/main.js`: instantiate `createOutfitRepository({ pool })` and add it to the runtime object.
  - [x]2.2: Update `handleRequest` destructuring (line 200) to include `outfitRepository`.
  - [x]2.3: Add route `POST /v1/outfits` to `apps/api/src/main.js`, placed BEFORE the existing `POST /v1/outfits/generate` route (more specific routes first). The route: (a) authenticates via `requireAuth`, (b) reads the request body, (c) validates required fields: `name` (string), `items` (array with >= 1 entry, each with `itemId` string and `position` number), (d) calls `outfitRepository.createOutfit(authContext, { name: body.name, explanation: body.explanation, occasion: body.occasion, source: body.source || 'ai', items: body.items })`, (e) returns 201 with the created outfit.
  - [x]2.4: Request body shape: `{ name: string, explanation?: string, occasion?: string, source?: "ai" | "manual", items: [{ itemId: string, position: number }] }`. `name` and `items` are required. `explanation`, `occasion`, `source` are optional (defaults: `source = "ai"`).
  - [x]2.5: Add validation: if `!body.name || typeof body.name !== 'string'`, return 400 "Name is required". If `!Array.isArray(body.items) || body.items.length === 0`, return 400 "At least one item is required". If `body.items.length > 7`, return 400 "Maximum 7 items per outfit".

- [x]Task 3: Mobile - Create OutfitPersistenceService (AC: 6, 7)
  - [x]3.1: Create `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` with an `OutfitPersistenceService` class. Constructor accepts `ApiClient`.
  - [x]3.2: Implement `Future<Map<String, dynamic>?> saveOutfit(OutfitSuggestion suggestion)` that: (a) maps the suggestion to the API request body: `{ "name": suggestion.name, "explanation": suggestion.explanation, "occasion": suggestion.occasion, "source": "ai", "items": suggestion.items.asMap().entries.map((e) => { "itemId": e.value.id, "position": e.key }).toList() }`, (b) calls `_apiClient.authenticatedPost("/v1/outfits", body: requestBody)`, (c) returns the parsed response map on success, (d) returns `null` on any error (catch `ApiException` and other exceptions, do not throw -- follows the same error-swallowing pattern as `OutfitGenerationService.generateOutfits()`).
  - [x]3.3: Add `Future<Map<String, dynamic>> saveOutfitToApi(Map<String, dynamic> body)` method to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedPost("/v1/outfits", body: body)`. This is a simple pass-through; the `OutfitPersistenceService` handles the mapping and error handling.

- [x]Task 4: Mobile - Create SwipeableOutfitStack widget (AC: 1, 2, 3, 4, 5, 10, 11, 12, 13)
  - [x]4.1: Create `apps/mobile/lib/src/features/home/widgets/swipeable_outfit_stack.dart` with a `SwipeableOutfitStack` StatefulWidget. Constructor accepts: `List<OutfitSuggestion> suggestions`, `Future<bool> Function(OutfitSuggestion) onSave` callback (returns true if save succeeded), `VoidCallback? onAllReviewed` callback.
  - [x]4.2: State fields: `int _currentIndex = 0`, `double _dragOffset = 0.0`, `bool _isSaving = false`. Use an `AnimationController` for the card exit animation (duration: 300ms) and a separate one for the spring-back animation (duration: 200ms).
  - [x]4.3: Build the card stack. Show the current card at the front with a slightly scaled-down next card behind it (scale 0.95, offset 8px down) for a visual depth effect. Use `Stack` with `Positioned` widgets. The front card wraps the existing `OutfitSuggestionCard` widget in a `GestureDetector` with `onHorizontalDragUpdate` and `onHorizontalDragEnd` handlers.
  - [x]4.4: Implement drag handling. On `onHorizontalDragUpdate`: update `_dragOffset` in state, which drives a `Transform.translate` and `Transform.rotate` (slight rotation proportional to drag: `_dragOffset * 0.001` radians, max 0.15 radians). On `onHorizontalDragEnd`: if `_dragOffset.abs() > screenWidth * 0.4`, trigger save (right) or skip (left) animation; otherwise, spring back to center.
  - [x]4.5: Implement swipe overlays. Wrap the card content in a `Stack`. Add a positioned overlay container that shows: (a) when dragging right (offset > 20px): a semi-transparent green overlay (`Color(0xFF10B981).withOpacity(opacity)`) with a white checkmark icon (`Icons.check_circle_outline`, 48px) and "Save" text. Opacity = `min(1.0, _dragOffset.abs() / (screenWidth * 0.4))`. (b) when dragging left (offset < -20px): a semi-transparent red overlay (`Color(0xFFEF4444).withOpacity(opacity)`) with a white X icon (`Icons.cancel_outlined`, 48px) and "Skip" text.
  - [x]4.6: Implement exit animation. When threshold is met, animate the card off-screen using `AnimationController.forward()` driving a `Tween<Offset>` from current position to `Offset(screenWidth * 1.5, 0)` (right) or `Offset(-screenWidth * 1.5, 0)` (left). On animation complete: execute the save/skip action, increment `_currentIndex`, reset `_dragOffset`.
  - [x]4.7: Implement save action. When swiping right: set `_isSaving = true`, call `widget.onSave(currentSuggestion)`. If returns `true`, advance. If returns `false`, spring card back (save failed). Set `_isSaving = false`.
  - [x]4.8: Add position indicator. Below the card stack, show "N of M" text (e.g., "1 of 3") using `Text("${_currentIndex + 1} of ${suggestions.length}", style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)))`. Center-aligned.
  - [x]4.9: Add Save and Skip buttons below the position indicator. Two buttons side by side: (a) Skip button: `OutlinedButton` with `Icons.close` and "Skip" text, `Color(0xFFEF4444)` border and text, 44px height. (b) Save button: `ElevatedButton` with `Icons.check` and "Save" text, `Color(0xFF4F46E5)` background, white text, 44px height. Both buttons trigger the same logic as swipe gestures. Disable both when `_isSaving` is true.
  - [x]4.10: Implement completion state. When `_currentIndex >= suggestions.length`, display a completion card (same card styling as existing cards: white background, 16px border radius, subtle shadow): centered checkmark icon (`Icons.check_circle`, 48px, `Color(0xFF10B981)`), title "All suggestions reviewed" (16px, #111827, bold), subtitle showing count of saved outfits (e.g., "You saved 2 outfits today") (13px, #6B7280), and a "Pull to refresh for new suggestions" hint text (12px, #9CA3AF).
  - [x]4.11: Add haptic feedback. Import `package:flutter/services.dart`. On save action: `HapticFeedback.mediumImpact()`. On skip action: `HapticFeedback.lightImpact()`.
  - [x]4.12: Add `Semantics` labels. Wrap the swipeable card in `Semantics(label: "Outfit suggestion ${_currentIndex + 1} of ${suggestions.length}: ${currentSuggestion.name}. Swipe right to save, swipe left to skip.")`. Save button: `Semantics(label: "Save outfit: ${currentSuggestion.name}")`. Skip button: `Semantics(label: "Skip outfit: ${currentSuggestion.name}")`.

- [x]Task 5: Mobile - Integrate SwipeableOutfitStack into HomeScreen (AC: 1, 6, 7)
  - [x]5.1: Add `OutfitPersistenceService` as an optional constructor parameter to `HomeScreen`. Add `OutfitPersistenceService? outfitPersistenceService` field. Initialize in `initState`: `_outfitPersistenceService = widget.outfitPersistenceService;`.
  - [x]5.2: Add `int _savedOutfitCount = 0` state field to `HomeScreenState` to track how many outfits were saved in this session (for the completion message).
  - [x]5.3: Update `_buildOutfitSection()`: replace the current success state block (lines 645-649 in current `home_screen.dart` -- the `OutfitSuggestionCard(suggestion: _outfitResult!.suggestions.first)`) with `SwipeableOutfitStack(suggestions: _outfitResult!.suggestions, onSave: _handleOutfitSave, onAllReviewed: null)`.
  - [x]5.4: Implement `Future<bool> _handleOutfitSave(OutfitSuggestion suggestion)` method. Steps: (a) if `_outfitPersistenceService` is null, return `false`, (b) call `_outfitPersistenceService!.saveOutfit(suggestion)`, (c) if result is not null (success): increment `_savedOutfitCount`, show snackbar "Outfit saved!", return `true`, (d) if result is null (failure): show snackbar "Failed to save outfit. Please try again.", return `false`.
  - [x]5.5: When pull-to-refresh regenerates outfits (existing `_handleRefresh`), reset `_savedOutfitCount = 0` so the completion state count reflects only the current session.
  - [x]5.6: Import the new widgets and services: `import '../widgets/swipeable_outfit_stack.dart';` and `import '../../outfits/services/outfit_persistence_service.dart';`.

- [x]Task 6: API - Unit tests for outfit repository (AC: 8, 9, 14)
  - [x]6.1: Create `apps/api/test/modules/outfits/outfit-repository.test.js`:
    - `createOutfit` inserts outfit row with correct profile_id, name, explanation, occasion, source.
    - `createOutfit` creates outfit_items rows with correct item_id and position.
    - `createOutfit` returns the created outfit with generated UUID id.
    - `createOutfit` validates item ownership -- throws 400 when itemId doesn't belong to user.
    - `createOutfit` rolls back transaction on item validation failure (no orphan outfit row).
    - `createOutfit` sets `app.current_user_id` for RLS.
    - `getOutfit` returns outfit with joined items array.
    - `getOutfit` returns null/throws when outfit does not exist.
    - RLS prevents accessing another user's outfits.

- [x]Task 7: API - Integration tests for POST /v1/outfits endpoint (AC: 8, 9, 14)
  - [x]7.1: Create `apps/api/test/modules/outfits/outfit-save.test.js`:
    - `POST /v1/outfits` requires authentication (401 without token).
    - `POST /v1/outfits` returns 201 with created outfit on success.
    - `POST /v1/outfits` returns outfit with correct structure (id, name, explanation, occasion, source, items).
    - `POST /v1/outfits` returns 400 when name is missing.
    - `POST /v1/outfits` returns 400 when items array is empty.
    - `POST /v1/outfits` returns 400 when items array has more than 7 items.
    - `POST /v1/outfits` returns 400 when itemId doesn't belong to user.
    - `POST /v1/outfits` defaults source to "ai" when not provided.
    - `POST /v1/outfits` persists outfit and items to database (verify with GET).

- [x]Task 8: Mobile - Unit tests for OutfitPersistenceService (AC: 6, 7, 14)
  - [x]8.1: Create `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart`:
    - `saveOutfit` calls API with correct request body (name, explanation, occasion, source, items with itemId and position).
    - `saveOutfit` returns parsed response map on success.
    - `saveOutfit` returns null on API error.
    - `saveOutfit` returns null on network error.
    - `saveOutfit` maps item positions correctly (0-indexed).

- [x]Task 9: Mobile - Widget tests for SwipeableOutfitStack (AC: 1, 2, 3, 4, 5, 10, 11, 12, 13, 14)
  - [x]9.1: Create `apps/mobile/test/features/home/widgets/swipeable_outfit_stack_test.dart`:
    - Renders the first suggestion's outfit name.
    - Shows position indicator "1 of 3".
    - Renders Save and Skip buttons.
    - Swiping right past threshold calls onSave callback.
    - Swiping left past threshold does NOT call onSave callback.
    - Swiping right and onSave returns true advances to next card.
    - Swiping right and onSave returns false keeps current card.
    - Tapping Save button calls onSave callback.
    - Tapping Skip button advances to next card without calling onSave.
    - After all cards reviewed, shows "All suggestions reviewed" completion state.
    - Completion state shows saved outfit count.
    - Dragging below threshold springs card back (card is still visible).
    - Green overlay appears when dragging right.
    - Red overlay appears when dragging left.
    - Save and Skip buttons are disabled during save operation.
    - Semantics labels are present for card, save button, and skip button.

- [x]Task 10: Mobile - Widget tests for HomeScreen swipe integration (AC: 1, 6, 7, 14)
  - [x]10.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When generation succeeds with multiple suggestions, SwipeableOutfitStack is displayed (not single OutfitSuggestionCard).
    - When outfit save succeeds, snackbar "Outfit saved!" is shown.
    - When outfit save fails, snackbar "Failed to save outfit" is shown.
    - All existing HomeScreen tests continue to pass (permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, cache-first loading, pull-to-refresh, staleness indicator, event override, outfit generation trigger, loading state, error state, minimum items threshold).

- [x]Task 11: Regression testing (AC: all)
  - [x]11.1: Run `flutter analyze` -- zero issues.
  - [x]11.2: Run `flutter test` -- all existing + new tests pass.
  - [x]11.3: Run `npm --prefix apps/api test` -- all existing + new API tests pass.
  - [x]11.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, event override, cache-first loading, pull-to-refresh, staleness indicator, outfit generation trigger, loading state, error state, minimum items threshold.
  - [x]11.5: Verify the swipeable outfit stack renders correctly and does not interfere with existing layout elements.
  - [x]11.6: Verify the `OutfitSuggestionCard` widget is still used (it is composed inside the swipeable stack, not removed).

## Dev Notes

- This is the SECOND story in Epic 4 (AI Outfit Engine). It builds on Story 4.1 which established the AI outfit generation pipeline (Gemini prompt, API endpoint, mobile service, OutfitSuggestionCard, HomeScreen integration). This story replaces the single static card with a Tinder-style swipeable card stack and adds outfit persistence.
- The primary FRs covered are FR-OUT-02 (persist accepted outfits to `outfits` and `outfit_items` tables) and FR-OUT-04 (swipe right = save, swipe left = skip).
- **FR-OUT-05 (manual outfit building) is OUT OF SCOPE.** Story 4.3 covers this.
- **FR-OUT-06, FR-OUT-07, FR-OUT-08 (outfit history, favorites, delete) are OUT OF SCOPE.** Story 4.4 covers this.
- **FR-OUT-09, FR-OUT-10 (usage limits) are OUT OF SCOPE.** Story 4.5 covers this.
- **FR-OUT-11 (recency bias / avoid recently worn items) is OUT OF SCOPE.** Story 4.6 covers this.
- **The `outfits` and `outfit_items` tables already exist** from Story 4.1's migration (`013_outfits.sql`). Do NOT create a new migration. This story only reads/writes to those tables.
- **The OutfitSuggestionCard widget is NOT removed.** It is reused as the visual content inside each swipeable card in the stack. The `SwipeableOutfitStack` wraps it with gesture handling, animations, and overlays.
- **Story 4.1 already returns 3 suggestions.** This story makes all 3 browsable via swipe rather than displaying only the first.

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/outfits/outfit-repository.js` (outfit CRUD repository)
  - `apps/api/test/modules/outfits/outfit-repository.test.js`
  - `apps/api/test/modules/outfits/outfit-save.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` (OutfitPersistenceService)
  - `apps/mobile/lib/src/features/home/widgets/swipeable_outfit_stack.dart` (SwipeableOutfitStack)
  - `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart`
  - `apps/mobile/test/features/home/widgets/swipeable_outfit_stack_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add POST /v1/outfits route, wire up outfitRepository in createRuntime and handleRequest)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add saveOutfitToApi method)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add OutfitPersistenceService DI, replace single card with SwipeableOutfitStack, add _handleOutfitSave, add _savedOutfitCount)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add swipe integration tests)

### Technical Requirements

- **New API endpoint:** `POST /v1/outfits` -- accepts `{ name: string, explanation?: string, occasion?: string, source?: string, items: [{ itemId: string, position: number }] }`, returns `{ outfit: { id, name, explanation, occasion, source, isFavorite, createdAt, updatedAt, items: [...] } }` with HTTP 201. Requires authentication.
- **No new database migration.** The `outfits` and `outfit_items` tables were created in Story 4.1's `013_outfits.sql`. This story writes to them for the first time.
- **Transaction boundary:** The outfit creation (insert into `outfits` + insert into `outfit_items`) must happen within a single database transaction. If item validation fails or any insert fails, the entire transaction is rolled back.
- **Item ownership validation:** Before creating an outfit, the API must verify that ALL item IDs in the request belong to the authenticated user. This is done by querying the `items` table joined to `profiles` using the auth context's `userId`. This prevents a user from creating an outfit with another user's items.
- **Swipe animation:** The card exit animation should take ~300ms, using a `Tween<Offset>` driven by an `AnimationController`. The spring-back animation (when below threshold) should take ~200ms with a `Curves.elasticOut` or `Curves.easeOutBack` for a natural feel.
- **Drag threshold:** 40% of screen width. This matches common swipe-to-action patterns and ensures deliberate intent (avoids accidental swipes).
- **Overlay opacity formula:** `min(1.0, dragOffset.abs() / (screenWidth * 0.4))` -- this means the overlay reaches full opacity exactly at the action threshold.

### Architecture Compliance

- **Server authority for persistence:** The API validates item ownership and persists outfits. The mobile client does NOT write directly to the database. This follows the architecture principle: "Server authority for sensitive rules."
- **API boundary owns transactional mutations:** Outfit creation with items is an atomic transaction on the server. This follows: "API Boundary: Owns validation, orchestration, authorization, AI calls, notification initiation, and transactional mutations."
- **Database boundary owns canonical state:** Outfits are stored in Cloud SQL with RLS. This follows: "Database Boundary: Owns canonical relational state and transactional consistency."
- **Mobile boundary owns presentation and gestures:** The swipe UI, animations, and drag handling are entirely client-side. This follows: "Mobile App Boundary: Owns presentation, gestures, local caching, optimistic updates."
- **Epic 4 component mapping:** `mobile/features/outfits`, `mobile/features/home`, `api/modules/outfits` -- matches the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `flutter/material.dart` (GestureDetector, AnimationController, Transform, Stack), `flutter/services.dart` (HapticFeedback), `http` package (via ApiClient).
- No new API dependencies. Uses existing `pg` (PostgreSQL client), `crypto` (built-in Node.js).
- The `OutfitSuggestionCard` widget from Story 4.1 is reused as-is inside the swipeable stack. No modifications to it.

### File Structure Requirements

- New API file: `apps/api/src/modules/outfits/outfit-repository.js` -- sits alongside `outfit-generation-service.js` in the same module directory.
- New mobile service: `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` -- sits alongside `outfit_generation_service.dart`.
- New mobile widget: `apps/mobile/lib/src/features/home/widgets/swipeable_outfit_stack.dart` -- sits alongside `outfit_suggestion_card.dart` and `outfit_minimum_items_card.dart`.
- Test files mirror source structure under `apps/api/test/` and `apps/mobile/test/`.

### Testing Requirements

- API unit tests must verify:
  - Outfit repository creates outfit and outfit_items in a transaction
  - Item ownership validation rejects foreign item IDs
  - Transaction rolls back on validation failure
  - RLS enforces user-scoped access
  - mapOutfitRow correctly maps database columns to camelCase
- API integration tests must verify:
  - POST /v1/outfits requires authentication (401)
  - POST /v1/outfits returns 201 with correct response structure
  - POST /v1/outfits validates required fields (name, items)
  - POST /v1/outfits validates item ownership
  - POST /v1/outfits defaults source to "ai"
  - Existing POST /v1/outfits/generate endpoint still works
- Mobile unit tests must verify:
  - OutfitPersistenceService maps suggestion to correct API request body
  - OutfitPersistenceService returns null on error
  - Item positions are correctly mapped (0-indexed)
- Mobile widget tests must verify:
  - SwipeableOutfitStack renders suggestions with position indicator
  - Swipe right triggers onSave callback
  - Swipe left advances without saving
  - Save/Skip buttons work as alternatives to swiping
  - Completion state shows after all cards reviewed
  - Overlay appears on drag with correct color
  - Card springs back on insufficient drag
  - Save/Skip buttons disable during saving
  - Semantics labels present
- HomeScreen integration tests must verify:
  - SwipeableOutfitStack replaces single OutfitSuggestionCard when multiple suggestions exist
  - Save success shows snackbar
  - Save failure shows error snackbar
  - All existing HomeScreen tests continue to pass
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new API tests pass)

### Previous Story Intelligence

- **Story 4.1 (direct predecessor)** completed with 208 API tests and 583 Flutter tests. All must continue to pass.
- **Story 4.1** established: `POST /v1/outfits/generate` endpoint, `OutfitGenerationService`, `OutfitSuggestion` model, `OutfitSuggestionCard` widget, `OutfitMinimumItemsCard` widget, `OutfitGenerationResult` model, `outfitGenerationService` in `createRuntime()`, HomeScreen outfit integration (generation trigger, loading state, display first suggestion, error state, minimum items threshold).
- **Story 4.1 key code:** The success state in `_buildOutfitSection()` (lines 645-649 of `home_screen.dart`) currently shows `OutfitSuggestionCard(suggestion: _outfitResult!.suggestions.first)`. This story replaces this with `SwipeableOutfitStack`.
- **Story 4.1 key note:** "Story 4.2 (swipe UI with save) will use the `outfits` and `outfit_items` tables to persist accepted outfits." -- confirming this story writes to those tables.
- **Story 4.1 `createRuntime()`** returns: `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`. This story adds `outfitRepository`.
- **Story 4.1 `handleRequest` destructuring** (line 200): Currently destructures `config`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `calendarService`, `outfitGenerationService`. This story adds `outfitRepository`.
- **HomeScreen constructor parameters (as of Story 4.1):** `locationService` (required), `weatherService` (required), `sharedPreferences` (optional), `weatherCacheService` (optional), `outfitContextService` (optional), `calendarService` (optional), `calendarPreferencesService` (optional), `calendarEventService` (optional), `outfitGenerationService` (optional), `onNavigateToAddItem` (optional). This story adds `outfitPersistenceService` (optional).
- **HomeScreen state (as of Story 4.1):** `_state`, `_calendarState`, `_weatherData`, `_forecastData`, `_errorMessage`, `_lastUpdatedLabel`, `outfitContext`, `_dressingTip`, `_calendarEvents`, `_outfitResult`, `_isGeneratingOutfit`, `_outfitError`, `_wardrobeItems`. This story adds: `_savedOutfitCount`, `_outfitPersistenceService`.
- **`mapError` function** currently handles 400, 401, 403, 404, 500, 503. No new error codes needed for this story.
- **API route ordering in `main.js`:** Routes are matched top-down using `if` statements. The new `POST /v1/outfits` route must be placed BEFORE `POST /v1/outfits/generate` to avoid the `/generate` path being treated as a match first. Actually, since the routes use exact `url.pathname` comparison (`=== "/v1/outfits"` vs `=== "/v1/outfits/generate"`), order doesn't strictly matter, but placing the shorter path first is cleaner.
- **Key learning from Story 2.5:** `CachedNetworkImage` is already available in the project (added in Story 2.5). It is used in `OutfitSuggestionCard` for item thumbnails via `Image.network` (Story 4.1 used `Image.network` not `CachedNetworkImage` -- either is acceptable).
- **Key learning from Story 3.6:** When testing HomeScreen with snackbars, wrap the widget in a `MaterialApp` with a `Scaffold` ancestor to avoid "No ScaffoldMessenger widget found" errors. Use `find.text(...)` to verify snackbar content.
- **Key learning from Story 4.1:** HomeScreen tests mock the `OutfitGenerationService` and inject it via the constructor. Follow the same pattern for `OutfitPersistenceService`.
- **Existing repository patterns:** `createItemRepository`, `createCalendarEventRepository`, `createAiUsageLogRepository` all follow the same factory pattern with `{ pool }` constructor, transaction wrapping, and `set_config` for RLS. Follow this EXACTLY.

### Key Anti-Patterns to Avoid

- DO NOT create a new database migration. The `outfits` and `outfit_items` tables already exist from Story 4.1's `013_outfits.sql`.
- DO NOT remove or modify the `OutfitSuggestionCard` widget. It is reused as the visual content inside the swipeable stack.
- DO NOT implement outfit history/favorites/delete UI. That is Story 4.4.
- DO NOT enforce usage limits (3/day for free users). Story 4.5 handles usage limits.
- DO NOT persist skipped outfits. Only swiped-right (saved) outfits are persisted.
- DO NOT call the AI generation endpoint from the save flow. Generation and saving are separate actions: generation happens on page load (Story 4.1), saving happens on swipe right (this story).
- DO NOT use optimistic UI for the save action. Wait for the API response before advancing the card. If the save fails, the card stays so the user can retry. This ensures data consistency.
- DO NOT add a separate "Outfits" tab or screen for viewing saved outfits. That is Story 4.4. Saving is fire-and-confirm in this story -- the user saves and moves on.
- DO NOT block the HomeScreen load on outfit persistence. Persistence is triggered by user action (swipe/tap), not on page load.
- DO NOT modify the existing `OutfitGenerationService` or `POST /v1/outfits/generate` endpoint. They are consumed as-is.
- DO NOT use third-party swipe card packages (like `flutter_card_swiper`). Build the swipe UI from scratch using Flutter's built-in `GestureDetector`, `AnimationController`, and `Transform` widgets. This keeps the dependency footprint minimal and gives full control over the animation behavior.
- DO NOT forget to handle the case where the user pulls to refresh while in the middle of swiping. When `_outfitResult` changes (new generation), the swipe stack should reset to show the new suggestions from index 0.

### References

- [Source: epics.md - Story 4.2: Outfit Generation Swipe UI]
- [Source: epics.md - Epic 4: AI Outfit Engine]
- [Source: prd.md - FR-OUT-02: Generated outfits shall be stored in the `outfits` table with linked items in `outfit_items`]
- [Source: prd.md - FR-OUT-04: Users shall swipe through multiple outfit suggestions (swipe right to save, left to skip)]
- [Source: architecture.md - API boundary owns transactional mutations]
- [Source: architecture.md - Server authority for sensitive rules]
- [Source: architecture.md - Data Architecture: outfits, outfit_items tables]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures]
- [Source: architecture.md - Epic 4 AI Outfit Engine -> mobile/features/outfits, api/modules/outfits, api/modules/ai]
- [Source: ux-design-specification.md - The Daily Outfit Swipe Card: primary interaction surface]
- [Source: ux-design-specification.md - Swipe Right (Save/Accept) and Swipe Left (Discard/Next) for outfit suggestions]
- [Source: ux-design-specification.md - Interaction: Draggable horizontally. Releases trigger actions based on threshold distance]
- [Source: ux-design-specification.md - States: Default (centered), Swiping Right (overlay turns green/shows 'Wear'), Swiping Left (overlay turns red/shows 'Skip')]
- [Source: ux-design-specification.md - Haptic feedback on successful actions (saving an outfit)]
- [Source: ux-design-specification.md - Optimistic UI is allowed for save actions, but must reconcile with server results]
- [Source: ux-design-specification.md - Positive Reinforcement: Haptic vibration + floating snackbar overlay]
- [Source: 4-1-daily-ai-outfit-generation.md - OutfitSuggestion model, OutfitSuggestionCard, HomeScreen integration]
- [Source: 4-1-daily-ai-outfit-generation.md - "Story 4.2 (swipe UI with save) will use the outfits and outfit_items tables"]
- [Source: 4-1-daily-ai-outfit-generation.md - outfitGenerationService in createRuntime]
- [Source: infra/sql/migrations/013_outfits.sql - outfits and outfit_items table schema]
- [Source: apps/api/src/main.js - existing routes, createRuntime, handleRequest, mapError]
- [Source: apps/mobile/lib/src/features/home/screens/home_screen.dart - _buildOutfitSection, HomeScreenState]
- [Source: apps/mobile/lib/src/features/home/widgets/outfit_suggestion_card.dart - OutfitSuggestionCard widget]
- [Source: apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart - OutfitSuggestion, OutfitSuggestionItem]
- [Source: apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart - error-swallowing pattern]
- [Source: apps/mobile/lib/src/core/networking/api_client.dart - authenticatedPost pattern]

## Dev Agent Record

- **Agent:** Amelia (Senior Software Engineer)
- **Date:** 2026-03-15
- **Duration:** Single session
- **All 11 tasks completed** in order with implementation and passing tests.
- **Test counts:** 228 API tests (208 original + 20 new), 608 Flutter tests (583 original + 25 new). All pass.
- **flutter analyze:** Zero issues.
- **Issues resolved:**
  - Fixed Dart syntax error in OutfitPersistenceService (arrow function with curly braces misinterpreted as Set literal).
  - Fixed SwipeableOutfitStack to set `_isSaving = true` immediately on Save button tap (before exit animation) so buttons disable correctly during save.
  - Fixed HomeScreen integration tests to scroll before tapping Save button (button was off-screen in 600px test viewport).
  - Removed unused import of `outfit_suggestion_card.dart` from `home_screen.dart` (now imported via `swipeable_outfit_stack.dart`).

## File List

### New Files
- `apps/api/src/modules/outfits/outfit-repository.js` - Outfit CRUD repository with createOutfit and getOutfit
- `apps/api/test/modules/outfits/outfit-repository.test.js` - 10 unit tests for outfit repository
- `apps/api/test/modules/outfits/outfit-save.test.js` - 10 integration tests for POST /v1/outfits
- `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` - OutfitPersistenceService
- `apps/mobile/lib/src/features/home/widgets/swipeable_outfit_stack.dart` - SwipeableOutfitStack widget
- `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart` - 5 unit tests
- `apps/mobile/test/features/home/widgets/swipeable_outfit_stack_test.dart` - 17 widget tests

### Modified Files
- `apps/api/src/main.js` - Added outfitRepository to createRuntime, handleRequest; added POST /v1/outfits route
- `apps/mobile/lib/src/core/networking/api_client.dart` - Added saveOutfitToApi method
- `apps/mobile/lib/src/features/home/screens/home_screen.dart` - Added OutfitPersistenceService DI, _handleOutfitSave, _savedOutfitCount, replaced single card with SwipeableOutfitStack
- `apps/mobile/test/features/home/screens/home_screen_test.dart` - Added 3 swipe integration tests, mock persistence service
