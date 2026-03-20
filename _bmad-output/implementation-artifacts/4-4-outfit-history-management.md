# Story 4.4: Outfit History & Management

Status: done

## Story

As a User,
I want to view, filter, and manage my saved outfits,
so that I can quickly re-wear proven looks, mark favorites for easy access, and keep my outfit history clean.

## Acceptance Criteria

1. Given I tap the "Outfits" tab in the main navigation bar, when the screen loads, then an `OutfitHistoryScreen` replaces the current "Outfits - Coming Soon" placeholder. The screen has an `AppBar` with title "Outfits" and displays my saved outfits in a vertically scrollable list, ordered by `created_at` descending (newest first). Each outfit card shows: the outfit name, a horizontal row of item thumbnails (48x48, rounded), the occasion tag (if present), a source indicator ("AI" chip for `source = 'ai'`, "Manual" chip for `source = 'manual'`), the created date in relative format (e.g., "Today", "Yesterday", "3 days ago", "Mar 12"), and a favorite icon (filled heart if `isFavorite = true`, outlined heart if `false`) (FR-OUT-06).

2. Given I am on the `OutfitHistoryScreen`, when the screen loads, then it calls `GET /v1/outfits` which returns all outfits for the authenticated user with their associated items, ordered by `created_at DESC`. The API response shape is `{ outfits: [{ id, name, explanation, occasion, source, isFavorite, createdAt, updatedAt, items: [{ id, name, category, color, photoUrl, position }] }] }` (FR-OUT-06).

3. Given I am on the `OutfitHistoryScreen`, when I tap the favorite icon (heart) on an outfit card, then the app calls `PATCH /v1/outfits/:id` with `{ isFavorite: true }` (or `false` to unfavorite). On success (HTTP 200), the heart icon toggles to filled/outlined with an optimistic UI update. On failure, the toggle reverts and a snackbar shows "Failed to update favorite. Please try again." (FR-OUT-07).

4. Given I am on the `OutfitHistoryScreen`, when I swipe left on an outfit card (or tap a delete button in the card's trailing actions), then a confirmation dialog appears: "Delete this outfit?" with "Cancel" and "Delete" buttons. Tapping "Delete" calls `DELETE /v1/outfits/:id`. On success (HTTP 200), the outfit is removed from the list with a slide-out animation. On failure, a snackbar shows "Failed to delete outfit. Please try again." (FR-OUT-08).

5. Given I am on the `OutfitHistoryScreen`, when I tap on an outfit card, then I navigate to an `OutfitDetailScreen` showing: the outfit name (large, 18px, bold), the "Why this outfit?" explanation (if present), a vertical list of item cards (each showing the item photo at 80x80, item name/category, and color), the occasion tag, the source indicator, and the created date. A favorite toggle button is in the AppBar. A "Delete" text button is at the bottom of the screen (FR-OUT-06).

6. Given I am on the `OutfitHistoryScreen` and I have no saved outfits, when the screen loads, then an empty state is displayed: a centered icon (`Icons.dry_cleaning`, 48px, `Color(0xFF9CA3AF)`), text "No outfits saved yet" (16px, `Color(0xFF111827)`, bold), subtitle "Create outfits from the Home screen or build your own" (13px, `Color(0xFF6B7280)`), and a "Create Outfit" primary button that navigates to `CreateOutfitScreen` (FR-OUT-06).

7. Given the API receives `GET /v1/outfits`, when the request is authenticated, then the `outfitRepository.listOutfits(authContext)` method queries `app_public.outfits` joined with `app_public.outfit_items` and `app_public.items`, filtered by RLS to the authenticated user's outfits, ordered by `created_at DESC`. The response includes full item metadata (id, name, category, color, photoUrl, position) for each outfit (FR-OUT-06).

8. Given the API receives `PATCH /v1/outfits/:id` with `{ isFavorite: true|false }`, when the request is authenticated and the outfit belongs to the user (enforced by RLS), then the `outfitRepository.updateOutfit(authContext, outfitId, { isFavorite })` method updates the outfit's `is_favorite` column and returns the updated outfit. Returns HTTP 200 on success, 404 if the outfit is not found (FR-OUT-07).

9. Given the API receives `DELETE /v1/outfits/:id`, when the request is authenticated and the outfit belongs to the user (enforced by RLS), then the `outfitRepository.deleteOutfit(authContext, outfitId)` method deletes the outfit row. The `outfit_items` rows are cascade-deleted by the FK constraint. Returns HTTP 200 with `{ deleted: true }`. Returns 404 if the outfit is not found (FR-OUT-08).

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (228 API tests, 647 Flutter tests) and new tests cover: `GET /v1/outfits` endpoint (success, empty, auth), `PATCH /v1/outfits/:id` endpoint (toggle favorite, not found, auth), `DELETE /v1/outfits/:id` endpoint (success, not found, auth), outfit repository methods (`listOutfits`, `updateOutfit`, `deleteOutfit`), `OutfitHistoryScreen` widget (loading, list rendering, empty state, favorite toggle, delete flow, navigation to detail, error states, accessibility), `OutfitDetailScreen` widget (outfit info display, favorite toggle, delete, accessibility), `MainShellScreen` integration (Outfits tab shows `OutfitHistoryScreen`), `OutfitPersistenceService` new methods (`listOutfits`, `toggleFavorite`, `deleteOutfit`), and `ApiClient` new methods (`listOutfits`, `updateOutfit`, `deleteOutfit`).

11. Given the `OutfitHistoryScreen` and `OutfitDetailScreen` are displayed, when a screen reader is active, then all interactive elements have appropriate `Semantics` labels: outfit cards announce "Outfit: [name], [source], created [date]", favorite buttons announce "Mark [name] as favorite" or "Remove [name] from favorites", delete actions announce "Delete outfit: [name]", item thumbnails announce "[category or name]", and the empty state is announced appropriately (WCAG AA).

## Tasks / Subtasks

- [x] Task 1: API - Add `listOutfits`, `updateOutfit`, and `deleteOutfit` to outfit repository (AC: 7, 8, 9)
  - [x] 1.1: Open `apps/api/src/modules/outfits/outfit-repository.js`. Add a new method `async listOutfits(authContext)` to the returned object. Steps: (a) acquire client from pool, (b) `begin` transaction, (c) `set_config('app.current_user_id', authContext.userId, true)`, (d) query:
    ```sql
    SELECT o.*,
           json_agg(
             json_build_object(
               'id', oi.item_id,
               'position', oi.position,
               'name', i.name,
               'category', i.category,
               'color', i.color,
               'photoUrl', i.photo_url
             ) ORDER BY oi.position
           ) as items
    FROM app_public.outfits o
    LEFT JOIN app_public.outfit_items oi ON oi.outfit_id = o.id
    LEFT JOIN app_public.items i ON i.id = oi.item_id
    GROUP BY o.id
    ORDER BY o.created_at DESC
    ```
    (e) `commit`, (f) map each row with `mapOutfitRow(row)`, (g) handle the case where an outfit has no items (LEFT JOIN may produce `[null]` in json_agg -- filter these: if `items` is `[null]`, set to `[]`), (h) return the array of mapped outfits. On error, `rollback` and re-throw. Always `client.release()` in `finally`.
  - [x] 1.2: Add `async updateOutfit(authContext, outfitId, { isFavorite })` method. Steps: (a) acquire client, (b) begin, (c) set_config, (d) build a dynamic UPDATE query on `app_public.outfits` setting only the provided fields. For now, only `is_favorite` is supported: `UPDATE app_public.outfits SET is_favorite = $1 WHERE id = $2 RETURNING *`. (e) if `result.rows.length === 0`, throw `{ statusCode: 404, message: "Outfit not found", code: "NOT_FOUND" }`. (f) commit, (g) return `mapOutfitRow(result.rows[0])`. On error rollback. Always release.
  - [x] 1.3: Add `async deleteOutfit(authContext, outfitId)` method. Steps: (a) acquire client, (b) begin, (c) set_config, (d) `DELETE FROM app_public.outfits WHERE id = $1 RETURNING id`, (e) if `result.rows.length === 0`, throw `{ statusCode: 404, message: "Outfit not found", code: "NOT_FOUND" }`, (f) commit, (g) return `{ deleted: true, id: outfitId }`. On error rollback. Always release. Note: `outfit_items` rows are cascade-deleted by the FK constraint `ON DELETE CASCADE`.

- [x] Task 2: API - Add `GET /v1/outfits`, `PATCH /v1/outfits/:id`, `DELETE /v1/outfits/:id` endpoints (AC: 2, 8, 9)
  - [x] 2.1: Open `apps/api/src/main.js`. Add `GET /v1/outfits` route BEFORE the existing `POST /v1/outfits` route (line 518). The route: (a) authenticates via `requireAuth`, (b) calls `outfitRepository.listOutfits(authContext)`, (c) returns `sendJson(res, 200, { outfits: result })`.
  - [x] 2.2: Add a regex matcher for outfit ID routes. After the existing `POST /v1/outfits/generate` route (line 583), add: `const outfitIdMatch = url.pathname.match(/^\/v1\/outfits\/([^/]+)$/);`. Place this BEFORE the `notFound` call.
  - [x] 2.3: Add `PATCH /v1/outfits/:id` route using `outfitIdMatch`. The route: (a) authenticates via `requireAuth`, (b) reads the body, (c) validates that at least `isFavorite` is provided (if `body.isFavorite === undefined`, return 400 "No valid fields to update"), (d) calls `outfitRepository.updateOutfit(authContext, outfitIdMatch[1], { isFavorite: body.isFavorite })`, (e) returns `sendJson(res, 200, { outfit: result })`.
  - [x] 2.4: Add `DELETE /v1/outfits/:id` route using `outfitIdMatch`. The route: (a) authenticates via `requireAuth`, (b) calls `outfitRepository.deleteOutfit(authContext, outfitIdMatch[1])`, (c) returns `sendJson(res, 200, result)`.
  - [x] 2.5: Route ordering in `main.js` must be: `GET /v1/outfits` (exact match), then `POST /v1/outfits` (exact match, existing), then `POST /v1/outfits/generate` (exact match, existing), then `outfitIdMatch` regex for `PATCH` and `DELETE` on `/v1/outfits/:id`. This prevents `/v1/outfits/generate` from matching the regex as an ID.

- [x] Task 3: Mobile - Add API methods to `ApiClient` (AC: 2, 3, 4)
  - [x] 3.1: Open `apps/mobile/lib/src/core/networking/api_client.dart`. Add method `Future<Map<String, dynamic>> listOutfits() async` that calls `_authenticatedGet("/v1/outfits")` and returns the response map.
  - [x] 3.2: Add method `Future<Map<String, dynamic>> updateOutfit(String outfitId, Map<String, dynamic> fields) async` that calls `authenticatedPatch("/v1/outfits/$outfitId", body: fields)`.
  - [x] 3.3: Add method `Future<Map<String, dynamic>> deleteOutfit(String outfitId) async` that calls `authenticatedDelete("/v1/outfits/$outfitId")`.

- [x] Task 4: Mobile - Create `SavedOutfit` model (AC: 1, 2, 5)
  - [x] 4.1: Create `apps/mobile/lib/src/features/outfits/models/saved_outfit.dart` with a `SavedOutfit` class. Fields: `String id`, `String? name`, `String? explanation`, `String? occasion`, `String source` (default "ai"), `bool isFavorite` (default false), `DateTime createdAt`, `DateTime? updatedAt`, `List<OutfitSuggestionItem> items`. Include `factory SavedOutfit.fromJson(Map<String, dynamic> json)` that parses: `id` from `json["id"]`, `name` from `json["name"]`, `explanation` from `json["explanation"]`, `occasion` from `json["occasion"]`, `source` from `json["source"] ?? "ai"`, `isFavorite` from `json["isFavorite"] ?? false`, `createdAt` from `DateTime.parse(json["createdAt"])`, `updatedAt` from `json["updatedAt"] != null ? DateTime.parse(json["updatedAt"]) : null`, `items` from `(json["items"] as List<dynamic>? ?? []).map((e) => OutfitSuggestionItem.fromJson(e)).toList()`. Import `OutfitSuggestionItem` from `outfit_suggestion.dart` to reuse the existing item model.
  - [x] 4.2: Add a `SavedOutfit copyWith({ bool? isFavorite })` method for optimistic UI updates.
  - [x] 4.3: Add a `String get relativeDate` getter that returns: "Today" if `createdAt` is today, "Yesterday" if yesterday, "[N] days ago" if within 7 days, or formatted date "MMM d" (e.g., "Mar 12") otherwise. Use `DateTime.now()` for comparison. Import `package:intl/intl.dart` for date formatting.

- [x] Task 5: Mobile - Add methods to `OutfitPersistenceService` (AC: 2, 3, 4)
  - [x] 5.1: Open `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart`. Add method `Future<List<SavedOutfit>> listOutfits() async` that: (a) calls `_apiClient.listOutfits()`, (b) parses the `outfits` array from the response, (c) maps each entry to `SavedOutfit.fromJson(outfit)`, (d) returns the list. On any error, return an empty list `[]`. Import `SavedOutfit` from `saved_outfit.dart`.
  - [x] 5.2: Add method `Future<SavedOutfit?> toggleFavorite(String outfitId, bool isFavorite) async` that: (a) calls `_apiClient.updateOutfit(outfitId, {"isFavorite": isFavorite})`, (b) parses the `outfit` from the response, (c) returns `SavedOutfit.fromJson(response["outfit"])` on success, (d) returns `null` on any error.
  - [x] 5.3: Add method `Future<bool> deleteOutfit(String outfitId) async` that: (a) calls `_apiClient.deleteOutfit(outfitId)`, (b) returns `true` on success, (c) returns `false` on any error.

- [x] Task 6: Mobile - Create `OutfitHistoryScreen` widget (AC: 1, 2, 3, 4, 6, 11)
  - [x] 6.1: Create `apps/mobile/lib/src/features/outfits/screens/outfit_history_screen.dart` with an `OutfitHistoryScreen` `StatefulWidget`. Constructor accepts: `required OutfitPersistenceService outfitPersistenceService`, `ApiClient? apiClient` (for navigation to CreateOutfitScreen).
  - [x] 6.2: State fields: `List<SavedOutfit>? _outfits` (null = loading), `bool _isLoading = true`, `String? _error`.
  - [x] 6.3: In `initState`, call `_loadOutfits()` which: (a) sets `_isLoading = true` in state, (b) calls `widget.outfitPersistenceService.listOutfits()`, (c) stores the result in `_outfits`, (d) sets `_isLoading = false`. On error, set `_error = "Failed to load outfits"` and `_isLoading = false`.
  - [x] 6.4: Build the `AppBar` with title "Outfits" and no back button (it's a tab).
  - [x] 6.5: Build the body. When `_isLoading`, show centered `CircularProgressIndicator(color: Color(0xFF4F46E5))`. When `_error != null`, show error state with retry button (matching HomeScreen error card pattern). When `_outfits != null && _outfits!.isEmpty`, show the empty state (AC 6). When `_outfits != null && _outfits!.isNotEmpty`, show a `ListView.builder` with outfit cards.
  - [x] 6.6: Build each outfit card as a `Dismissible` widget (swipe left to delete). The card is a white `Container` with 16px border radius, subtle shadow (`Colors.black.withValues(alpha: 0.05)`, blur 10, offset 0,2), and 16px padding. Card contents in a `Column`: (a) Row with outfit name (16px, `Color(0xFF111827)`, bold, `Expanded`) and favorite icon button (`Icons.favorite` filled red `Color(0xFFEF4444)` if favorite, `Icons.favorite_border` gray `Color(0xFF9CA3AF)` if not). (b) `SizedBox(height: 8)`. (c) Horizontal `SingleChildScrollView` with item thumbnails: 48x48 rounded (8px radius) `CachedNetworkImage` for each item, with 8px spacing. Gray placeholder if `photoUrl` is null. (d) `SizedBox(height: 8)`. (e) Row with: source chip (small `Container` with text "AI" or "Manual", 10px font, `Color(0xFF4F46E5)` text on `Color(0xFFEEF2FF)` background for AI, `Color(0xFF059669)` text on `Color(0xFFECFDF5)` background for Manual, 6px horizontal/2px vertical padding, 6px border radius), occasion chip (if present, similar styling in gray `Color(0xFF6B7280)` text on `Color(0xFFF3F4F6)` background), `Spacer()`, date text (12px, `Color(0xFF9CA3AF)`).
  - [x] 6.7: The `Dismissible` widget: `key: ValueKey(outfit.id)`, `direction: DismissDirection.endToStart`, `background` is a red container with white trash icon aligned right, `confirmDismiss` shows a confirmation `AlertDialog` ("Delete this outfit?" with Cancel/Delete buttons), `onDismissed` calls `_handleDelete(outfit)`.
  - [x] 6.8: Implement `_handleDelete(SavedOutfit outfit)`. Steps: (a) call `widget.outfitPersistenceService.deleteOutfit(outfit.id)`, (b) if `true`: remove from `_outfits` in state (already removed by Dismissible animation), (c) if `false`: reload outfits (to revert the Dismissible), show snackbar "Failed to delete outfit. Please try again."
  - [x] 6.9: Implement `_handleFavoriteToggle(SavedOutfit outfit)`. Steps: (a) optimistic update: immediately toggle `isFavorite` in `_outfits` via `setState`, (b) call `widget.outfitPersistenceService.toggleFavorite(outfit.id, !outfit.isFavorite)`, (c) if result is `null` (failure): revert the toggle in state, show snackbar "Failed to update favorite. Please try again."
  - [x] 6.10: Implement card tap: `onTap` navigates to `OutfitDetailScreen` via `Navigator.push`, passing the `SavedOutfit` and the `outfitPersistenceService`. When the detail screen pops with a result, reload outfits to reflect any changes (favorite toggled or outfit deleted from detail).
  - [x] 6.11: Build the empty state (AC 6): centered `Column` with dry cleaning icon, "No outfits saved yet" title, subtitle, and "Create Outfit" primary button (if `widget.apiClient != null`, navigate to `CreateOutfitScreen`; otherwise hide the button).
  - [x] 6.12: Add `Semantics` labels throughout: outfit cards `Semantics(label: "Outfit: ${outfit.name ?? 'Untitled'}, ${outfit.source}, created ${outfit.relativeDate}")`, favorite buttons `Semantics(label: outfit.isFavorite ? "Remove ${outfit.name ?? 'outfit'} from favorites" : "Mark ${outfit.name ?? 'outfit'} as favorite")`, delete dismiss `Semantics(label: "Delete outfit: ${outfit.name ?? 'Untitled'}")`, empty state `Semantics(label: "No outfits saved. Create outfits from the Home screen.")`.
  - [x] 6.13: Add `RefreshIndicator` wrapping the `ListView` so the user can pull to refresh the outfit list.

- [x] Task 7: Mobile - Create `OutfitDetailScreen` widget (AC: 5, 11)
  - [x] 7.1: Create `apps/mobile/lib/src/features/outfits/screens/outfit_detail_screen.dart` with an `OutfitDetailScreen` `StatefulWidget`. Constructor accepts: `required SavedOutfit outfit`, `required OutfitPersistenceService outfitPersistenceService`.
  - [x] 7.2: State fields: `late SavedOutfit _outfit` (initialized from widget), `bool _isDeleting = false`.
  - [x] 7.3: Build the `AppBar` with: back button, title "Outfit Details", and a favorite icon button in the `actions` (same toggle behavior as the list screen -- calls `_handleFavoriteToggle`).
  - [x] 7.4: Build the body as a `SingleChildScrollView` with `Padding(all: 16)` containing a `Column`: (a) Outfit name (18px, `Color(0xFF111827)`, bold). Default to "Untitled Outfit" if name is null. (b) `SizedBox(height: 4)`. (c) Row with source chip and occasion chip (same styling as list card). (d) `SizedBox(height: 4)`. (e) Date text: "Created ${_outfit.relativeDate}" (13px, `Color(0xFF9CA3AF)`). (f) `SizedBox(height: 16)`. (g) If `_outfit.explanation != null && _outfit.explanation!.isNotEmpty`: "Why this outfit?" label (13px, `Color(0xFF4F46E5)`, semibold) followed by explanation text (13px, `Color(0xFF4B5563)`), then `SizedBox(height: 16)`. (h) "Items" section header (14px, `Color(0xFF374151)`, semibold). (i) `SizedBox(height: 8)`. (j) A `Column` of item cards: each item is a white `Container` (12px border radius, subtle shadow) with a `Row`: `ClipRRect` with 10px radius wrapping `CachedNetworkImage` (80x80, gray placeholder), `SizedBox(width: 12)`, `Expanded` `Column` with item name or "Unnamed Item" (14px, `Color(0xFF111827)`), category (12px, `Color(0xFF6B7280)`), and color (12px, `Color(0xFF9CA3AF)`). Items are separated by `SizedBox(height: 8)`. (k) `SizedBox(height: 24)`. (l) "Delete Outfit" text button (`Color(0xFFDC2626)`, centered) that calls `_handleDelete`.
  - [x] 7.5: Implement `_handleFavoriteToggle`. Steps: (a) optimistic update: toggle `_outfit.isFavorite` in state via `copyWith`, (b) call `widget.outfitPersistenceService.toggleFavorite(_outfit.id, _outfit.isFavorite)`, (c) if null (failure): revert, show snackbar.
  - [x] 7.6: Implement `_handleDelete`. Steps: (a) show confirmation dialog, (b) if confirmed: set `_isDeleting = true`, (c) call `widget.outfitPersistenceService.deleteOutfit(_outfit.id)`, (d) if `true`: pop with `true` result (signals list to reload), (e) if `false`: set `_isDeleting = false`, show snackbar "Failed to delete outfit. Please try again."
  - [x] 7.7: Add `Semantics` labels: outfit name `Semantics(label: "Outfit name: ${_outfit.name ?? 'Untitled'}")`, explanation `Semantics(label: "Outfit explanation: ${_outfit.explanation}")`, each item `Semantics(label: "Item: ${item.category ?? item.name ?? 'Unknown'}")`, favorite button (same as list), delete button `Semantics(label: "Delete this outfit")`.

- [x] Task 8: Mobile - Integrate `OutfitHistoryScreen` into `MainShellScreen` (AC: 1)
  - [x] 8.1: Open `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`. Replace the `_buildOutfitsTab()` method body. Instead of the placeholder, return `OutfitHistoryScreen(outfitPersistenceService: OutfitPersistenceService(apiClient: widget.apiClient!), apiClient: widget.apiClient)`. Guard with a null check on `widget.apiClient` -- if null, keep the existing placeholder.
  - [x] 8.2: Add imports at the top of `main_shell_screen.dart`: `import '../../outfits/screens/outfit_history_screen.dart';`, `import '../../outfits/services/outfit_persistence_service.dart';`.
  - [x] 8.3: Verify that the `IndexedStack` index mapping still works correctly. The "Outfits" tab is at `_selectedIndex = 3`, which maps to `IndexedStack` index 2 (since Add at index 2 is skipped). This is unchanged.

- [x] Task 9: API - Unit tests for outfit repository new methods (AC: 7, 8, 9, 10)
  - [x] 9.1: Update `apps/api/test/modules/outfits/outfit-repository.test.js` with new tests:
    - `listOutfits` returns all outfits for the authenticated user ordered by created_at DESC.
    - `listOutfits` includes items array with full metadata (id, name, category, color, photoUrl, position).
    - `listOutfits` returns empty array when user has no outfits.
    - `listOutfits` sets `app.current_user_id` for RLS.
    - `listOutfits` handles outfits with no items (empty items array, not `[null]`).
    - `updateOutfit` toggles `is_favorite` to true.
    - `updateOutfit` toggles `is_favorite` to false.
    - `updateOutfit` returns updated outfit with new isFavorite value.
    - `updateOutfit` throws 404 when outfit not found.
    - `updateOutfit` sets `app.current_user_id` for RLS (cannot update another user's outfit).
    - `deleteOutfit` removes the outfit and returns `{ deleted: true }`.
    - `deleteOutfit` cascade-deletes associated outfit_items.
    - `deleteOutfit` throws 404 when outfit not found.
    - `deleteOutfit` sets `app.current_user_id` for RLS (cannot delete another user's outfit).

- [x] Task 10: API - Integration tests for new endpoints (AC: 2, 8, 9, 10)
  - [x] 10.1: Create `apps/api/test/modules/outfits/outfit-list.test.js`:
    - `GET /v1/outfits` requires authentication (401 without token).
    - `GET /v1/outfits` returns 200 with outfits array.
    - `GET /v1/outfits` returns outfits ordered by created_at DESC.
    - `GET /v1/outfits` includes items with full metadata for each outfit.
    - `GET /v1/outfits` returns empty array when no outfits exist.
    - `GET /v1/outfits` does not return other users' outfits (RLS).
  - [x] 10.2: Create `apps/api/test/modules/outfits/outfit-update.test.js`:
    - `PATCH /v1/outfits/:id` requires authentication (401 without token).
    - `PATCH /v1/outfits/:id` toggles isFavorite to true and returns 200.
    - `PATCH /v1/outfits/:id` toggles isFavorite to false and returns 200.
    - `PATCH /v1/outfits/:id` returns 404 for non-existent outfit.
    - `PATCH /v1/outfits/:id` returns 400 when no valid fields provided.
    - `PATCH /v1/outfits/:id` cannot update another user's outfit (RLS).
  - [x] 10.3: Create `apps/api/test/modules/outfits/outfit-delete.test.js`:
    - `DELETE /v1/outfits/:id` requires authentication (401 without token).
    - `DELETE /v1/outfits/:id` deletes outfit and returns 200.
    - `DELETE /v1/outfits/:id` cascade-deletes outfit_items.
    - `DELETE /v1/outfits/:id` returns 404 for non-existent outfit.
    - `DELETE /v1/outfits/:id` cannot delete another user's outfit (RLS).

- [x] Task 11: Mobile - Unit tests for `SavedOutfit` model (AC: 1, 10)
  - [x] 11.1: Create `apps/mobile/test/features/outfits/models/saved_outfit_test.dart`:
    - `SavedOutfit.fromJson()` correctly parses all fields.
    - `SavedOutfit.fromJson()` handles null name, explanation, occasion.
    - `SavedOutfit.fromJson()` defaults `source` to "ai" when missing.
    - `SavedOutfit.fromJson()` defaults `isFavorite` to false when missing.
    - `SavedOutfit.fromJson()` handles empty items list.
    - `SavedOutfit.copyWith()` creates a copy with toggled isFavorite.
    - `relativeDate` returns "Today" for today's date.
    - `relativeDate` returns "Yesterday" for yesterday.
    - `relativeDate` returns "N days ago" for dates within 7 days.
    - `relativeDate` returns formatted date for older dates.

- [x] Task 12: Mobile - Unit tests for `OutfitPersistenceService` new methods (AC: 2, 3, 4, 10)
  - [x] 12.1: Update `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart`:
    - `listOutfits` calls API and returns parsed list of SavedOutfit.
    - `listOutfits` returns empty list on API error.
    - `listOutfits` returns empty list when response has no outfits.
    - `toggleFavorite` calls API with correct outfitId and isFavorite value.
    - `toggleFavorite` returns parsed SavedOutfit on success.
    - `toggleFavorite` returns null on API error.
    - `deleteOutfit` calls API with correct outfitId.
    - `deleteOutfit` returns true on success.
    - `deleteOutfit` returns false on API error.

- [x] Task 13: Mobile - Widget tests for `OutfitHistoryScreen` (AC: 1, 2, 3, 4, 6, 11, 10)
  - [x] 13.1: Create `apps/mobile/test/features/outfits/screens/outfit_history_screen_test.dart`:
    - Renders loading state with CircularProgressIndicator while outfits load.
    - Renders outfit list after outfits load.
    - Outfit cards show name, item thumbnails, source chip, occasion, date, and favorite icon.
    - Empty state is shown when no outfits exist.
    - Empty state shows "Create Outfit" button when apiClient is provided.
    - Tapping favorite icon calls toggleFavorite with correct parameters.
    - Favorite icon toggles optimistically on tap.
    - Favorite toggle reverts on API failure.
    - Swiping left on an outfit shows confirmation dialog.
    - Confirming delete calls deleteOutfit and removes the outfit.
    - Delete failure shows error snackbar.
    - Tapping an outfit card navigates to OutfitDetailScreen.
    - Pull to refresh reloads the outfit list.
    - Renders error state with retry button when loading fails.
    - Semantics labels are present on outfit cards, favorite buttons, and empty state.

- [x] Task 14: Mobile - Widget tests for `OutfitDetailScreen` (AC: 5, 11, 10)
  - [x] 14.1: Create `apps/mobile/test/features/outfits/screens/outfit_detail_screen_test.dart`:
    - Renders outfit name, source chip, occasion, and created date.
    - Renders explanation section when explanation is present.
    - Does not render explanation section when explanation is null.
    - Renders item list with photo, name, category, and color.
    - Renders gray placeholder for items with null photoUrl.
    - Favorite icon in AppBar toggles on tap.
    - Favorite toggle reverts on API failure.
    - Tapping "Delete Outfit" shows confirmation dialog.
    - Confirming delete calls deleteOutfit and pops screen.
    - Delete failure shows error snackbar.
    - Semantics labels are present on all elements.

- [x] Task 15: Mobile - Widget tests for MainShellScreen Outfits tab integration (AC: 1, 10)
  - [x] 15.1: Update `apps/mobile/test/features/shell/screens/main_shell_screen_test.dart`:
    - Tapping "Outfits" tab displays OutfitHistoryScreen (not placeholder text).
    - OutfitHistoryScreen is rendered when apiClient is provided.
    - Placeholder is shown when apiClient is null.
    - All existing MainShellScreen tests continue to pass.

- [x] Task 16: Regression testing (AC: all)
  - [x] 16.1: Run `flutter analyze` -- zero issues.
  - [x] 16.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 16.3: Run `npm --prefix apps/api test` -- all existing + new API tests pass.
  - [x] 16.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, cache-first loading, pull-to-refresh, staleness indicator, event override, outfit generation trigger, loading state, error state, minimum items threshold, swipeable outfit stack, outfit save/fail snackbars, Create Outfit FAB.
  - [x] 16.5: Verify existing POST /v1/outfits and POST /v1/outfits/generate endpoints still work correctly.
  - [x] 16.6: Verify the Outfits tab in MainShellScreen no longer shows the placeholder and correctly renders the OutfitHistoryScreen.

## Dev Notes

- This is the FOURTH story in Epic 4 (AI Outfit Engine). It adds the outfit history/management UI and the remaining CRUD API endpoints, building on Stories 4.1-4.3 which established outfit generation, persistence, and manual creation.
- The primary FRs covered are FR-OUT-06 (outfit history view), FR-OUT-07 (favorite outfits), and FR-OUT-08 (delete outfits).
- **FR-OUT-09, FR-OUT-10 (usage limits) are OUT OF SCOPE.** Story 4.5 covers this.
- **FR-OUT-11 (recency bias) is OUT OF SCOPE.** Story 4.6 covers this.
- **FR-PSH-04 (morning outfit notifications) is OUT OF SCOPE.** Story 4.7 covers this.
- **No new database migration needed.** The `outfits` and `outfit_items` tables from Story 4.1's `013_outfits.sql` already have all necessary columns including `is_favorite`. The `updated_at` trigger already exists.
- **The outfit list does NOT include filtering in this story.** FR-OUT-06 mentions filters (AI vs manual, occasion, season, date range), but the initial implementation focuses on the core list/detail/favorite/delete flows. Filtering can be added as an enhancement once the base screen is working. The API returns all outfits; client-side filtering can be layered on top later without API changes.

### Project Structure Notes

- New API files:
  - `apps/api/test/modules/outfits/outfit-list.test.js` (integration tests for GET /v1/outfits)
  - `apps/api/test/modules/outfits/outfit-update.test.js` (integration tests for PATCH /v1/outfits/:id)
  - `apps/api/test/modules/outfits/outfit-delete.test.js` (integration tests for DELETE /v1/outfits/:id)
- New mobile files:
  - `apps/mobile/lib/src/features/outfits/models/saved_outfit.dart` (SavedOutfit model)
  - `apps/mobile/lib/src/features/outfits/screens/outfit_history_screen.dart` (OutfitHistoryScreen)
  - `apps/mobile/lib/src/features/outfits/screens/outfit_detail_screen.dart` (OutfitDetailScreen)
  - `apps/mobile/test/features/outfits/models/saved_outfit_test.dart`
  - `apps/mobile/test/features/outfits/screens/outfit_history_screen_test.dart`
  - `apps/mobile/test/features/outfits/screens/outfit_detail_screen_test.dart`
- Modified API files:
  - `apps/api/src/modules/outfits/outfit-repository.js` (add `listOutfits`, `updateOutfit`, `deleteOutfit`)
  - `apps/api/src/main.js` (add GET /v1/outfits, PATCH /v1/outfits/:id, DELETE /v1/outfits/:id routes)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `listOutfits`, `updateOutfit`, `deleteOutfit`)
  - `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` (add `listOutfits`, `toggleFavorite`, `deleteOutfit`)
  - `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` (replace Outfits tab placeholder with OutfitHistoryScreen)
  - `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart` (add new method tests)
  - `apps/mobile/test/features/shell/screens/main_shell_screen_test.dart` (add Outfits tab integration tests)

### Technical Requirements

- **New API endpoints:**
  - `GET /v1/outfits` -- returns `{ outfits: [...] }` with HTTP 200. Requires authentication.
  - `PATCH /v1/outfits/:id` -- accepts `{ isFavorite: boolean }`, returns `{ outfit: {...} }` with HTTP 200. Requires authentication.
  - `DELETE /v1/outfits/:id` -- returns `{ deleted: true, id: "..." }` with HTTP 200. Requires authentication.
- **No new database migration.** All columns already exist in `013_outfits.sql`.
- **RLS enforcement:** All three new endpoints rely on RLS policies already defined on `outfits` and `outfit_items` tables. Setting `app.current_user_id` before queries ensures the user can only access their own outfits.
- **Cascade delete:** When an outfit is deleted, the `ON DELETE CASCADE` foreign key constraint on `outfit_items.outfit_id` automatically deletes the associated rows.
- **Optimistic UI for favorites:** The favorite toggle updates the UI immediately before the API call completes. On failure, the toggle reverts. This follows the architecture principle: "Optimistic UI is allowed for save actions, but must reconcile with server results."
- **json_agg null handling:** When a `LEFT JOIN` matches no rows, `json_agg` returns `[null]` rather than `[]`. The `listOutfits` method must filter this: `if (items && items.length === 1 && items[0] === null) items = []`.
- **SavedOutfit vs OutfitSuggestion:** `OutfitSuggestion` represents ephemeral AI-generated suggestions (not yet persisted). `SavedOutfit` represents persisted outfits from the `outfits` table (both AI and manual). They share the same `OutfitSuggestionItem` for item metadata since the shape is identical.
- **Date formatting:** The `relativeDate` getter uses `package:intl` which is already a dependency in the project (used for locale-aware formatting). Import `DateFormat` for the "MMM d" format.

### Architecture Compliance

- **Server authority for mutations:** Favorite toggle, outfit deletion, and outfit listing are all server-side operations via the API. The mobile client does NOT modify the database directly. This follows: "Server authority for sensitive rules."
- **API boundary owns CRUD:** The outfit repository handles all data access within transactions with RLS. This follows: "API Boundary: Owns validation, orchestration, authorization."
- **Database boundary owns canonical state:** Outfits are the authoritative data source. Optimistic UI on the client is reconciled with server results. This follows: "Database Boundary: Owns canonical relational state and transactional consistency."
- **Mobile boundary owns presentation and gestures:** The outfit list, detail screen, swipe-to-delete, and favorite toggle animations are all client-side. This follows: "Mobile App Boundary: Owns presentation, gestures, local caching, optimistic updates."
- **Navigation shell update:** The architecture specifies `Home`, `Wardrobe`, `Add`, `Outfits`, `Profile` as the canonical MVP shell. This story activates the `Outfits` tab with real functionality.
- **Epic 4 component mapping:** `mobile/features/outfits`, `api/modules/outfits` -- matches the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `flutter/material.dart` (ListView, Dismissible, AlertDialog), `cached_network_image` (for item thumbnails), `http` package (via ApiClient), `intl` package (for date formatting).
- No new API dependencies. Uses existing `pg` (PostgreSQL client).
- Reuses existing `OutfitSuggestionItem` model from `apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart`.
- Reuses existing `OutfitPersistenceService` from `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart`.
- Reuses existing `CreateOutfitScreen` from `apps/mobile/lib/src/features/outfits/screens/create_outfit_screen.dart` (for empty state navigation).

### File Structure Requirements

- New screens in `apps/mobile/lib/src/features/outfits/screens/` -- alongside existing `create_outfit_screen.dart` and `name_outfit_screen.dart`.
- New model in `apps/mobile/lib/src/features/outfits/models/` -- alongside existing `outfit_suggestion.dart`.
- Test files mirror source structure under `apps/api/test/` and `apps/mobile/test/`.

### Testing Requirements

- API unit tests must verify:
  - `listOutfits` returns user-scoped outfits with items, ordered by date
  - `listOutfits` handles empty results and null items in json_agg
  - `updateOutfit` toggles isFavorite and returns updated outfit
  - `updateOutfit` throws 404 for missing outfits
  - `deleteOutfit` removes outfit and cascades to outfit_items
  - `deleteOutfit` throws 404 for missing outfits
  - RLS prevents cross-user access for all three methods
- API integration tests must verify:
  - GET /v1/outfits requires auth, returns correct structure, handles empty
  - PATCH /v1/outfits/:id requires auth, toggles favorite, handles 404 and validation
  - DELETE /v1/outfits/:id requires auth, deletes outfit, handles 404
- Mobile unit tests must verify:
  - SavedOutfit model parsing, copyWith, relativeDate logic
  - OutfitPersistenceService new methods (listOutfits, toggleFavorite, deleteOutfit)
  - ApiClient new methods (listOutfits, updateOutfit, deleteOutfit)
- Mobile widget tests must verify:
  - OutfitHistoryScreen: loading, list, empty state, favorite toggle with optimistic UI, delete with confirmation, error handling, navigation, pull-to-refresh, accessibility
  - OutfitDetailScreen: outfit info display, items list, favorite toggle, delete with confirmation, accessibility
  - MainShellScreen: Outfits tab renders OutfitHistoryScreen instead of placeholder
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new API tests pass)

### Previous Story Intelligence

- **Story 4.3 (direct predecessor)** completed with 228 API tests and 647 Flutter tests. All must continue to pass.
- **Story 4.3** established: `CreateOutfitScreen`, `NameOutfitScreen`, `saveManualOutfit` method in OutfitPersistenceService, FAB on HomeScreen for manual outfit creation.
- **Story 4.2** established: `POST /v1/outfits` endpoint, `outfit-repository.js` with `createOutfit` and `getOutfit`, `OutfitPersistenceService` with `saveOutfit(OutfitSuggestion)`, `SwipeableOutfitStack` widget.
- **Story 4.1** established: `outfits` and `outfit_items` tables (`013_outfits.sql`), `POST /v1/outfits/generate` endpoint, `OutfitGenerationService`, `OutfitSuggestion` model, `OutfitSuggestionCard` widget.
- **Story 4.2 `outfit-repository.js`** already has `createOutfit` and `getOutfit`. This story adds `listOutfits`, `updateOutfit`, and `deleteOutfit` to the same repository.
- **Story 4.2 `OutfitPersistenceService`** has `saveOutfit(OutfitSuggestion)` and `saveManualOutfit(...)`. This story adds `listOutfits()`, `toggleFavorite(id, bool)`, and `deleteOutfit(id)`.
- **Story 4.2 `ApiClient`** has `saveOutfitToApi(body)` and `generateOutfits(context)`. This story adds `listOutfits()`, `updateOutfit(id, fields)`, and `deleteOutfit(id)`.
- **Story 4.2 `mapOutfitRow(row)`** is the standard row-to-camelCase mapper. It already handles `is_favorite -> isFavorite`. Reuse it for all new methods.
- **Story 4.2 route pattern in `main.js`:** Routes use exact `url.pathname` comparison. The new `GET /v1/outfits` uses the same pattern. The `PATCH` and `DELETE` routes need a regex matcher like `itemIdMatch` for `/v1/items/:id`.
- **Story 2.6 item detail pattern:** The `ItemDetailScreen` follows a similar pattern to `OutfitDetailScreen` -- display item data, allow actions (edit, delete), use `CachedNetworkImage` for photos.
- **Story 2.6 delete pattern:** Item deletion uses a confirmation dialog, calls the API, and pops the screen on success. Follow the same pattern for outfit deletion.
- **MainShellScreen `_buildOutfitsTab()`** currently returns a static placeholder. This story replaces it with `OutfitHistoryScreen`. The `IndexedStack` mapping (index 3 -> stack index 2) is already correct and does not change.
- **MainShellScreen has `widget.apiClient`** available. The `OutfitHistoryScreen` needs an `OutfitPersistenceService` which requires an `ApiClient`. Instantiate the service in `_buildOutfitsTab()`.
- **Key learning from Story 3.6:** When testing screens with snackbars, wrap the widget in a `MaterialApp` with a `Scaffold` ancestor.
- **Key learning from Story 4.2:** HomeScreen tests mock the `OutfitPersistenceService` and inject it via the constructor. Follow the same pattern for `OutfitHistoryScreen` tests.
- **Key learning from Story 4.3:** Used `LinkedHashSet` for selection order. Not relevant here, but the `CachedNetworkImage` pattern and card styling from `CreateOutfitScreen` can be reused.
- **Key pattern for Dismissible:** See Flutter docs. Use `ValueKey` for the key, `confirmDismiss` for showing a dialog before delete, and `onDismissed` for executing the action.

### Key Anti-Patterns to Avoid

- DO NOT create a new database migration. The `outfits` table already has `is_favorite`, `created_at`, `updated_at`, and the cascade FK on `outfit_items`.
- DO NOT modify the existing `POST /v1/outfits` or `POST /v1/outfits/generate` endpoints. They are consumed as-is.
- DO NOT modify `createOutfit` or `getOutfit` in `outfit-repository.js`. Add new methods alongside them.
- DO NOT modify the `OutfitSuggestionCard` or `SwipeableOutfitStack` widgets. They are not affected by this story.
- DO NOT implement outfit filtering in the initial version. FR-OUT-06 mentions filters, but the core list/detail/favorite/delete flows are the priority. Filtering can be layered on top later.
- DO NOT implement usage limits. Story 4.5 handles usage limits.
- DO NOT implement recency bias. Story 4.6 handles this.
- DO NOT modify the `OutfitSuggestion` model. Create a separate `SavedOutfit` model for persisted outfits.
- DO NOT show outfit history on the HomeScreen. The outfit history is accessed via the "Outfits" tab in the bottom navigation.
- DO NOT forget to handle the `json_agg` null case: when an outfit has no items (edge case if items were deleted), `json_agg` returns `[null]`. Filter this to `[]`.
- DO NOT use the `outfitIdMatch` regex before the exact-match `/v1/outfits/generate` route in `main.js`, or the regex will match "generate" as an ID. Place the regex AFTER the generate route.
- DO NOT forget to guard `_buildOutfitsTab()` against null `apiClient`. If `apiClient` is null, keep the placeholder (this is the existing behavior for WardrobeScreen as well).

### References

- [Source: epics.md - Story 4.4: Outfit History & Management]
- [Source: epics.md - Epic 4: AI Outfit Engine]
- [Source: prd.md - FR-OUT-06: Users shall view their outfit history with filters]
- [Source: prd.md - FR-OUT-07: Users shall favorite outfits for quick access]
- [Source: prd.md - FR-OUT-08: Users shall be able to delete outfits from their history]
- [Source: architecture.md - Server authority for sensitive rules]
- [Source: architecture.md - Navigation: Home, Wardrobe, Add, Outfits, Profile]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures, optimistic updates]
- [Source: architecture.md - API Boundary: Owns validation, orchestration, authorization, transactional mutations]
- [Source: architecture.md - Database Boundary: Owns canonical relational state]
- [Source: architecture.md - Epic 4 AI Outfit Engine -> mobile/features/outfits, api/modules/outfits]
- [Source: ux-design-specification.md - Bottom tab bar for core MVP destinations (Home, Wardrobe, Add, Outfits, Profile)]
- [Source: ux-design-specification.md - Vibrant Soft-UI design direction]
- [Source: ux-design-specification.md - Zero-State Avoidance: never show blank screen, explain why and provide action]
- [Source: ux-design-specification.md - Positive Reinforcement: Haptic vibration + floating snackbar overlay]
- [Source: ux-design-specification.md - Contextual Deep Dives: Bottom Sheets or detail screens]
- [Source: 4-3-manual-outfit-building.md - CreateOutfitScreen, OutfitPersistenceService.saveManualOutfit]
- [Source: 4-2-outfit-generation-swipe-ui.md - POST /v1/outfits endpoint, outfit-repository.js, OutfitPersistenceService]
- [Source: 4-1-daily-ai-outfit-generation.md - outfits and outfit_items tables, 013_outfits.sql, OutfitSuggestion model]
- [Source: apps/api/src/main.js - existing routes, createRuntime, handleRequest, mapError, outfitRepository]
- [Source: apps/api/src/modules/outfits/outfit-repository.js - createOutfit, getOutfit, mapOutfitRow]
- [Source: apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart - OutfitSuggestion, OutfitSuggestionItem]
- [Source: apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart - saveOutfit, saveManualOutfit]
- [Source: apps/mobile/lib/src/core/networking/api_client.dart - authenticatedPost, authenticatedPatch, authenticatedDelete]
- [Source: apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart - _buildOutfitsTab placeholder, IndexedStack mapping]
- [Source: apps/mobile/lib/src/features/home/screens/home_screen.dart - HomeScreen state, CreateOutfitScreen FAB]
- [Source: infra/sql/migrations/013_outfits.sql - outfits table with is_favorite, FK cascades]

## Dev Agent Record

### Test Results
- API tests: 259 pass, 0 fail (was 228, +31 new)
- Flutter tests: 697 pass, 0 fail (was 647, +50 new)
- Flutter analyze: 0 issues

### Files Created
- `apps/mobile/lib/src/features/outfits/models/saved_outfit.dart` - SavedOutfit model with fromJson, copyWith, relativeDate
- `apps/mobile/lib/src/features/outfits/screens/outfit_history_screen.dart` - OutfitHistoryScreen with list, empty state, favorite toggle, swipe-to-delete
- `apps/mobile/lib/src/features/outfits/screens/outfit_detail_screen.dart` - OutfitDetailScreen with detail view, favorite toggle, delete
- `apps/api/test/modules/outfits/outfit-list.test.js` - Integration tests for GET /v1/outfits (6 tests)
- `apps/api/test/modules/outfits/outfit-update.test.js` - Integration tests for PATCH /v1/outfits/:id (6 tests)
- `apps/api/test/modules/outfits/outfit-delete.test.js` - Integration tests for DELETE /v1/outfits/:id (5 tests)
- `apps/mobile/test/features/outfits/models/saved_outfit_test.dart` - SavedOutfit model unit tests (10 tests)
- `apps/mobile/test/features/outfits/screens/outfit_history_screen_test.dart` - OutfitHistoryScreen widget tests (17 tests)
- `apps/mobile/test/features/outfits/screens/outfit_detail_screen_test.dart` - OutfitDetailScreen widget tests (11 tests)

### Files Modified
- `apps/api/src/modules/outfits/outfit-repository.js` - Added listOutfits, updateOutfit, deleteOutfit methods
- `apps/api/src/main.js` - Added GET /v1/outfits, PATCH /v1/outfits/:id, DELETE /v1/outfits/:id routes
- `apps/mobile/lib/src/core/networking/api_client.dart` - Added listOutfits, updateOutfit, deleteOutfit methods
- `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` - Added listOutfits, toggleFavorite, deleteOutfit methods
- `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` - Replaced Outfits tab placeholder with OutfitHistoryScreen
- `apps/mobile/pubspec.yaml` - Added intl dependency
- `apps/api/test/modules/outfits/outfit-repository.test.js` - Added 14 new unit tests for listOutfits, updateOutfit, deleteOutfit
- `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart` - Added 9 new tests for listOutfits, toggleFavorite, deleteOutfit
- `apps/mobile/test/features/shell/screens/main_shell_screen_test.dart` - Updated Outfits tab test, added apiClient null test

### Issues Resolved
- Dismissible swipe-to-delete with failure revert: Moved delete API call into confirmDismiss callback so that if deletion fails, confirmDismiss returns false and the Dismissible does not dismiss. This avoids the "dismissed Dismissible widget is still part of the tree" error that occurs when trying to re-add a dismissed item.
- json_agg null handling: When an outfit has no items, LEFT JOIN produces [null] from json_agg; this is filtered to [] in listOutfits.
- intl package: Added to pubspec.yaml as it was not a pre-existing dependency (needed for DateFormat in relativeDate getter).
- Route ordering: GET /v1/outfits placed before POST /v1/outfits; outfitIdMatch regex placed after /v1/outfits/generate to avoid matching "generate" as an ID.
