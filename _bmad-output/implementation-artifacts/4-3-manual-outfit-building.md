# Story 4.3: Manual Outfit Building

Status: done

## Story

As a User,
I want to create my own outfits manually by selecting items from my wardrobe,
so that I can save my favorite combinations without relying strictly on AI.

## Acceptance Criteria

1. Given I am on the Home screen, when I tap a "Create Outfit" floating action button (FAB), then I navigate to a `CreateOutfitScreen` that presents my wardrobe items in a categorized selection interface, allowing me to pick items to assemble an outfit (FR-OUT-05).

2. Given I am on the `CreateOutfitScreen`, when the screen loads, then my wardrobe items are fetched via `GET /v1/items` and displayed in a grid grouped by category tabs (Tops, Bottoms, Dresses, Outerwear, Shoes, Bags, Accessories, Other). Only items with `categorizationStatus = 'completed'` are shown. Each category tab shows its item count (FR-OUT-05).

3. Given I am viewing items on the `CreateOutfitScreen`, when I tap an item in the grid, then the item is visually marked as selected (blue border overlay with a checkmark badge). Tapping a selected item deselects it. I can select items across multiple category tabs. The total selected count is displayed prominently (e.g., "3 items selected") (FR-OUT-05).

4. Given I have selected at least 1 item, when I look at the bottom of the screen, then a "Selected Items" preview strip is visible showing horizontal thumbnail previews (48x48, rounded) of all selected items. Tapping an item in the preview strip deselects it. When no items are selected, the strip is hidden (FR-OUT-05).

5. Given I have selected between 1 and 7 items, when I tap the "Next" button, then I navigate to a `NameOutfitScreen` where I can enter an optional outfit name (text field, max 100 characters) and select an optional occasion tag from a dropdown (everyday, work, formal, party, date-night, outdoor, sport, casual). A "Save Outfit" primary button is visible (FR-OUT-05).

6. Given I am on the `NameOutfitScreen`, when I tap "Save Outfit", then the app calls `POST /v1/outfits` with `{ name: enteredName || "My Outfit", source: "manual", occasion: selectedOccasion, items: [{ itemId, position }] }`, where position is the selection order (0-indexed). On success (HTTP 201), the screen pops back to the Home screen and a snackbar shows "Outfit created!" (FR-OUT-05, FR-OUT-02).

7. Given I am on the `NameOutfitScreen`, when the save API call fails, then a snackbar shows "Failed to create outfit. Please try again." and the "Save Outfit" button re-enables so the user can retry (FR-OUT-05).

8. Given I am on the `CreateOutfitScreen`, when I have 0 items selected and look at the "Next" button, then the button is disabled (grayed out). If I have more than 7 items selected, the button is also disabled and a hint text shows "Maximum 7 items per outfit" (FR-OUT-05).

9. Given I am on the `CreateOutfitScreen`, when items are loading, then a centered `CircularProgressIndicator` is shown. If the item fetch fails, an error state with "Failed to load items" and a "Retry" button is shown (FR-OUT-05).

10. Given I have no categorized items in my wardrobe, when I open the `CreateOutfitScreen`, then an empty state is shown: "No items available. Add and categorize items in your wardrobe first." with a button "Go to Wardrobe" that navigates back (FR-OUT-05).

11. Given the `CreateOutfitScreen` and `NameOutfitScreen` are displayed, when a screen reader is active, then all interactive elements have appropriate `Semantics` labels: item tiles announce "Select [item name or category]", selected items announce "Selected: [item name or category]. Tap to deselect.", category tabs announce "Category: [name], [count] items", and buttons have descriptive labels (WCAG AA).

12. Given I save a manual outfit, when the API receives `POST /v1/outfits` with `source = "manual"`, then the existing `POST /v1/outfits` endpoint (from Story 4.2) handles it correctly -- no API changes are needed. The `source` field distinguishes manual from AI-generated outfits (FR-OUT-05, FR-OUT-02).

13. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (228 API tests, 608 Flutter tests) and new tests cover: `CreateOutfitScreen` widget (item loading, category tabs, selection/deselection, selected count, preview strip, next button states, empty state, error state, accessibility), `NameOutfitScreen` widget (name input, occasion selection, save flow, error handling), HomeScreen FAB integration, and `OutfitPersistenceService.saveManualOutfit()`.

## Tasks / Subtasks

- [x] Task 1: Mobile - Add `saveManualOutfit` method to `OutfitPersistenceService` (AC: 6, 7, 12)
  - [x] 1.1: Open `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart`. Add a new method `Future<Map<String, dynamic>?> saveManualOutfit({ required String name, String? occasion, required List<Map<String, dynamic>> items })` that: (a) builds the request body: `{ "name": name, "source": "manual", "occasion": occasion, "items": items }`, (b) calls `_apiClient.authenticatedPost("/v1/outfits", body: requestBody)`, (c) returns the parsed response map on success, (d) returns `null` on any error (catch all exceptions, matching the existing `saveOutfit` pattern). The `items` parameter is a list of `{ "itemId": string, "position": int }` maps.
  - [x] 1.2: Note: The existing `POST /v1/outfits` endpoint already supports `source = "manual"` -- the `source` field defaults to `"ai"` but accepts `"manual"`. The database `CHECK (source IN ('ai', 'manual'))` constraint validates it. No API changes needed.

- [x] Task 2: Mobile - Create `CreateOutfitScreen` widget (AC: 1, 2, 3, 4, 8, 9, 10, 11)
  - [x] 2.1: Create `apps/mobile/lib/src/features/outfits/screens/create_outfit_screen.dart` with a `CreateOutfitScreen` `StatefulWidget`. Constructor accepts: `required ApiClient apiClient`, `required OutfitPersistenceService outfitPersistenceService`.
  - [x] 2.2: State fields: `List<WardrobeItem>? _items` (all categorized items), `bool _isLoading = true`, `String? _error`, `Set<String> _selectedItemIds = {}` (selected item IDs in insertion order -- use `LinkedHashSet`), `int _selectedTabIndex = 0`.
  - [x] 2.3: In `initState`, call `_loadItems()` which: (a) sets `_isLoading = true`, (b) calls `widget.apiClient.listItems()`, (c) parses the response items using `WardrobeItem.fromJson()`, (d) filters to only items where `categorizationStatus == 'completed'`, (e) stores in `_items`, (f) sets `_isLoading = false`. On error, sets `_error = "Failed to load items"` and `_isLoading = false`.
  - [x] 2.4: Define the category groups as a constant list of maps: `[ { "key": "tops", "label": "Tops" }, { "key": "bottoms", "label": "Bottoms" }, { "key": "dresses", "label": "Dresses" }, { "key": "outerwear", "label": "Outerwear" }, { "key": "shoes", "label": "Shoes" }, { "key": "bags", "label": "Bags" }, { "key": "accessories", "label": "Accessories" }, { "key": "other", "label": "Other" } ]`. The "Other" tab includes items whose category is `activewear`, `swimwear`, `underwear`, `sleepwear`, `suits`, `other`, or `null`.
  - [x] 2.5: Build the `AppBar` with: back button, title "Create Outfit", and a subtitle showing selected count (e.g., "3 items selected") in `Color(0xFF6B7280)` 13px text. If 0 selected, show "Select items".
  - [x] 2.6: Build the body using a `Column` containing: (a) a `TabBar` (using `DefaultTabController` with length = category count) with horizontally scrollable category tabs. Each tab shows the category label and item count in parentheses (e.g., "Tops (5)"). Only show tabs that have at least 1 item. Use `Color(0xFF4F46E5)` for the selected tab indicator and label. (b) A `TabBarView` containing a grid for each category. Each grid uses `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8)` and 8px padding.
  - [x] 2.7: Build each item tile in the grid. Use `GestureDetector` wrapping a `ClipRRect(borderRadius: 12)` containing: (a) `CachedNetworkImage` filling the tile, with gray placeholder and error containers. (b) If the item is selected: a semi-transparent blue overlay `Color(0xFF4F46E5).withOpacity(0.3)` covering the entire tile, and a positioned checkmark icon (`Icons.check_circle`, 24px, white, `Color(0xFF4F46E5)` background circle) at the top-right corner (offset 4px). (c) A bottom label showing the item's `displayLabel` (name or category) in 10px white text on a `Colors.black54` background strip. (d) `Semantics` label: if selected, "Selected: [displayLabel]. Tap to deselect." else "Select [displayLabel]".
  - [x] 2.8: Implement selection logic. On tap: if already selected, remove from `_selectedItemIds`; if not selected and `_selectedItemIds.length < 7`, add to `_selectedItemIds`. If at 7 items and trying to add another, show a snackbar "Maximum 7 items per outfit". Call `setState` to rebuild.
  - [x] 2.9: Build the "Selected Items" preview strip. Below the `TabBarView` (in the outer `Column`), show a `Container` with height 72, visible only when `_selectedItemIds.isNotEmpty`. Background `Colors.white`, top border `Color(0xFFE5E7EB)`. Contents: a horizontal `SingleChildScrollView` with `Row` containing 48x48 rounded (8px radius) item thumbnails using `CachedNetworkImage`. Each thumbnail has an `InkWell` that removes the item from `_selectedItemIds` on tap. Wrap each with `Semantics(label: "Remove [displayLabel] from outfit")`.
  - [x] 2.10: Build the "Next" button. Below the preview strip, a full-width `Padding(horizontal: 16, bottom: 16)` containing an `ElevatedButton` with text "Next" and a right arrow icon. Background `Color(0xFF4F46E5)`, white text, 12px border radius, 48px height. Disabled (gray background `Color(0xFFD1D5DB)`) when: `_selectedItemIds.isEmpty` or `_selectedItemIds.length > 7`. Below the button, if `_selectedItemIds.length > 7`, show hint text "Maximum 7 items per outfit" in `Color(0xFFEF4444)` 12px.
  - [x] 2.11: Handle loading state: when `_isLoading`, show centered `CircularProgressIndicator(color: Color(0xFF4F46E5))`.
  - [x] 2.12: Handle error state: when `_error != null`, show centered `Column` with error icon (`Icons.error_outline`, 48px, `Color(0xFF9CA3AF)`), error text, and "Retry" `ElevatedButton` (same style as primary button) calling `_loadItems()`.
  - [x] 2.13: Handle empty state: when `_items != null && _items!.isEmpty`, show centered `Column` with wardrobe icon (`Icons.checkroom`, 48px, `Color(0xFF9CA3AF)`), text "No items available. Add and categorize items in your wardrobe first." in 14px `Color(0xFF6B7280)`, and "Go to Wardrobe" `ElevatedButton` that calls `Navigator.pop(context)`.
  - [x] 2.14: The "Next" button `onPressed` navigates to `NameOutfitScreen` via `Navigator.push`, passing: the list of selected `WardrobeItem` objects (preserving selection order from `_selectedItemIds`), and the `outfitPersistenceService`. When `NameOutfitScreen` pops with `true`, the `CreateOutfitScreen` also pops with `true`.

- [x] Task 3: Mobile - Create `NameOutfitScreen` widget (AC: 5, 6, 7, 11)
  - [x] 3.1: Create `apps/mobile/lib/src/features/outfits/screens/name_outfit_screen.dart` with a `NameOutfitScreen` `StatefulWidget`. Constructor accepts: `required List<WardrobeItem> selectedItems`, `required OutfitPersistenceService outfitPersistenceService`.
  - [x] 3.2: State fields: `TextEditingController _nameController`, `String? _selectedOccasion`, `bool _isSaving = false`.
  - [x] 3.3: Build the `AppBar` with: back button and title "Name Your Outfit".
  - [x] 3.4: Build the body as a `SingleChildScrollView` with `Padding(all: 16)` containing a `Column`: (a) "Selected Items" preview: a horizontal `SingleChildScrollView` showing the selected items as 64x64 rounded thumbnails with category labels below (11px, `Color(0xFF6B7280)`). Non-interactive (display only). (b) `SizedBox(height: 24)`. (c) "Outfit Name" label (14px, `Color(0xFF374151)`, semibold). (d) `TextField` with `_nameController`, `hintText: "My Outfit"`, `maxLength: 100`, `decoration: InputDecoration(border: OutlineInputBorder(borderRadius: 12), filled: true, fillColor: Colors.white)`. (e) `SizedBox(height: 16)`. (f) "Occasion" label (14px, `Color(0xFF374151)`, semibold). (g) `DropdownButtonFormField<String>` with items from `validOccasions` (import from `taxonomy.dart`): `["everyday", "work", "formal", "party", "date-night", "outdoor", "sport"]`. Display labels use `taxonomyDisplayLabel()`. Include a null/"None" option that clears the selection. Decoration matches the text field styling. (h) `SizedBox(height: 32)`. (i) Full-width "Save Outfit" `ElevatedButton` (48px height, `Color(0xFF4F46E5)` background, white text, 12px border radius). Shows `CircularProgressIndicator(color: Colors.white, strokeWidth: 2)` when `_isSaving`. Disabled when `_isSaving`.
  - [x] 3.5: Implement save logic in `_handleSave()`. Steps: (a) set `_isSaving = true` in state, (b) build the items list: `widget.selectedItems.asMap().entries.map((e) => { "itemId": e.value.id, "position": e.key }).toList()`, (c) determine the name: `_nameController.text.trim().isEmpty ? "My Outfit" : _nameController.text.trim()`, (d) call `widget.outfitPersistenceService.saveManualOutfit(name: name, occasion: _selectedOccasion, items: itemsList)`, (e) if result is not null (success): show snackbar "Outfit created!", pop with `true`, (f) if result is null (failure): show snackbar "Failed to create outfit. Please try again.", set `_isSaving = false`.
  - [x] 3.6: Add `Semantics` labels: name field `Semantics(label: "Outfit name input")`, occasion dropdown `Semantics(label: "Select occasion for this outfit")`, save button `Semantics(label: "Save outfit")`.
  - [x] 3.7: Dispose `_nameController` in `dispose()`.

- [x] Task 4: Mobile - Add FAB to HomeScreen for "Create Outfit" (AC: 1)
  - [x] 4.1: Open `apps/mobile/lib/src/features/home/screens/home_screen.dart`. In the `build()` method's `Scaffold`, add a `floatingActionButton` property. The FAB: `FloatingActionButton(onPressed: _navigateToCreateOutfit, backgroundColor: Color(0xFF4F46E5), child: Icon(Icons.add, color: Colors.white), tooltip: "Create Outfit")`. Wrap with `Semantics(label: "Create a new outfit manually")`.
  - [x] 4.2: Implement `Future<void> _navigateToCreateOutfit() async` method. Steps: (a) create an `ApiClient` instance or reuse the one available (check if `_outfitPersistenceService` has one -- if not, the FAB should only appear when persistence service is available). (b) Navigate via `Navigator.push` to `CreateOutfitScreen(apiClient: apiClient, outfitPersistenceService: _outfitPersistenceService!)`. (c) When the screen returns with `true`, show snackbar "Outfit created!" (actually the snackbar is already shown by NameOutfitScreen, so no duplicate is needed).
  - [x] 4.3: The FAB should only be visible when `_state == _HomeState.weatherLoaded` and `_outfitPersistenceService != null`. Hide it in other states to avoid confusion before the user has set up weather/location.
  - [x] 4.4: Add `ApiClient? apiClient` as an optional constructor parameter to `HomeScreen`, for dependency injection in the CreateOutfitScreen flow. Default to null (callers that don't need manual outfit building don't need to pass it).
  - [x] 4.5: Add imports at the top of `home_screen.dart`: `import '../../outfits/screens/create_outfit_screen.dart';`.

- [x] Task 5: Mobile - Unit tests for `OutfitPersistenceService.saveManualOutfit` (AC: 6, 7, 13)
  - [x] 5.1: Update `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart`:
    - `saveManualOutfit` calls API with correct request body (name, source "manual", occasion, items with itemId and position).
    - `saveManualOutfit` returns parsed response map on success.
    - `saveManualOutfit` returns null on API error.
    - `saveManualOutfit` returns null on network error.
    - `saveManualOutfit` sends `source: "manual"` (not "ai").
    - `saveManualOutfit` sends null occasion when not provided.

- [x] Task 6: Mobile - Widget tests for `CreateOutfitScreen` (AC: 2, 3, 4, 8, 9, 10, 11, 13)
  - [x] 6.1: Create `apps/mobile/test/features/outfits/screens/create_outfit_screen_test.dart`:
    - Renders loading state with CircularProgressIndicator while items load.
    - Renders category tabs after items load.
    - Renders items in grid within the active tab.
    - Only shows items with `categorizationStatus == 'completed'`.
    - Tapping an item selects it (blue overlay and checkmark appear).
    - Tapping a selected item deselects it (overlay removed).
    - Selected count text updates when items are selected/deselected.
    - Selected items preview strip appears when items are selected.
    - Selected items preview strip is hidden when no items selected.
    - Tapping a thumbnail in the preview strip deselects the item.
    - "Next" button is disabled when no items are selected.
    - "Next" button is enabled when 1-7 items are selected.
    - Tapping "Next" navigates to NameOutfitScreen.
    - Shows "Maximum 7 items" hint when > 7 items selected (or prevents selection at 7).
    - Renders error state with "Retry" button when item fetch fails.
    - Renders empty state with "Go to Wardrobe" when no categorized items.
    - Category tabs show correct item counts.
    - Semantics labels are present on item tiles (selected and unselected states).

- [x] Task 7: Mobile - Widget tests for `NameOutfitScreen` (AC: 5, 6, 7, 11, 13)
  - [x] 7.1: Create `apps/mobile/test/features/outfits/screens/name_outfit_screen_test.dart`:
    - Renders selected items preview.
    - Renders outfit name text field with "My Outfit" hint.
    - Renders occasion dropdown with valid occasions from taxonomy.
    - Name field accepts text input (max 100 characters).
    - Tapping "Save Outfit" calls `outfitPersistenceService.saveManualOutfit` with correct parameters.
    - Uses default name "My Outfit" when name field is empty.
    - Uses entered name when name field has text.
    - Passes selected occasion to save call.
    - On save success, pops screen with `true` result.
    - On save failure, shows error snackbar and re-enables button.
    - "Save Outfit" button shows loading spinner during save.
    - "Save Outfit" button is disabled during save.
    - Semantics labels are present on name field, occasion dropdown, and save button.

- [x] Task 8: Mobile - Widget tests for HomeScreen FAB integration (AC: 1, 13)
  - [x] 8.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When weather is loaded and outfitPersistenceService is provided, FAB "Create Outfit" is visible.
    - When weather is not loaded, FAB is not visible.
    - Tapping FAB navigates to CreateOutfitScreen.
    - All existing HomeScreen tests continue to pass (permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, cache-first loading, pull-to-refresh, staleness indicator, event override, outfit generation trigger, loading state, error state, minimum items threshold, swipe stack, save/fail snackbars).

- [x] Task 9: Regression testing (AC: all)
  - [x] 9.1: Run `flutter analyze` -- zero issues.
  - [x] 9.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 9.3: Run `npm --prefix apps/api test` -- all existing API tests pass (228 tests, no API changes in this story).
  - [x] 9.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, event override, cache-first loading, pull-to-refresh, staleness indicator, outfit generation trigger, loading state, error state, minimum items threshold, swipeable outfit stack, outfit save/fail snackbars.
  - [x] 9.5: Verify the FAB does not interfere with existing layout elements or the swipeable outfit stack.
  - [x] 9.6: Verify the `POST /v1/outfits` endpoint correctly handles `source = "manual"` (manual test or verify via existing API tests that already cover source field).

## Dev Notes

- This is the THIRD story in Epic 4 (AI Outfit Engine). It adds the manual outfit creation flow, building on Story 4.2's outfit persistence infrastructure (POST /v1/outfits endpoint, outfit-repository.js, OutfitPersistenceService).
- The primary FR covered is FR-OUT-05 (Users shall be able to manually build outfits by selecting items from categorized lists).
- **FR-OUT-06, FR-OUT-07, FR-OUT-08 (outfit history, favorites, delete) are OUT OF SCOPE.** Story 4.4 covers this.
- **FR-OUT-09, FR-OUT-10 (usage limits) are OUT OF SCOPE.** Story 4.5 covers this.
- **FR-OUT-11 (recency bias) is OUT OF SCOPE.** Story 4.6 covers this.
- **No new database migration needed.** The `outfits` and `outfit_items` tables from Story 4.1's `013_outfits.sql` already support `source = 'manual'`.
- **No API changes needed.** The existing `POST /v1/outfits` endpoint from Story 4.2 already accepts `source: "manual"` and validates it against the database CHECK constraint.
- **This story is purely mobile (Flutter) work.** All changes are in the mobile app. The API and database are consumed as-is.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/outfits/screens/create_outfit_screen.dart` (CreateOutfitScreen)
  - `apps/mobile/lib/src/features/outfits/screens/name_outfit_screen.dart` (NameOutfitScreen)
  - `apps/mobile/test/features/outfits/screens/create_outfit_screen_test.dart`
  - `apps/mobile/test/features/outfits/screens/name_outfit_screen_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` (add `saveManualOutfit` method)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add FAB, `apiClient` constructor param, `_navigateToCreateOutfit` method)
  - `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart` (add `saveManualOutfit` tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add FAB integration tests)

### Technical Requirements

- **No new API endpoint.** Reuse `POST /v1/outfits` from Story 4.2 with `source = "manual"`.
- **No new database migration.** Reuse `outfits` + `outfit_items` tables from `013_outfits.sql`.
- **Item filtering:** Only show items with `categorizationStatus == 'completed'` in the selection grid. Items pending categorization or with failed categorization are excluded since they lack proper metadata.
- **Category grouping:** Items are grouped by their `category` field into tabs. The "Other" tab is a catch-all for categories not in the primary list (activewear, swimwear, underwear, sleepwear, suits, other, null).
- **Selection order preservation:** Use `LinkedHashSet<String>` for `_selectedItemIds` to preserve the order items were selected. This order determines the `position` field when saving (first selected = position 0).
- **Maximum 7 items:** Enforced client-side in the selection UI (prevent selecting more than 7) and server-side by the existing `POST /v1/outfits` validation (`body.items.length > 7` returns 400).
- **Default outfit name:** If the user leaves the name blank, default to "My Outfit" on the client side before sending to the API.
- **FAB placement:** The FAB is placed on the Home screen's `Scaffold.floatingActionButton`. It uses the standard Material FAB pattern. It is positioned at the bottom-right by default.

### Architecture Compliance

- **Server authority for persistence:** The API validates item ownership and persists outfits. The mobile client does NOT write directly to the database. This follows: "Server authority for sensitive rules."
- **API boundary owns transactional mutations:** Outfit creation with items is an atomic transaction on the server. This follows: "API Boundary: Owns validation, orchestration, authorization, AI calls, notification initiation, and transactional mutations."
- **Mobile boundary owns presentation and gestures:** The item selection UI, category tabs, and form flow are entirely client-side presentation concerns. This follows: "Mobile App Boundary: Owns presentation, gestures, local caching, optimistic updates."
- **Reuse existing infrastructure:** No new endpoints or tables. The `POST /v1/outfits` endpoint and `outfits`/`outfit_items` tables are reused from Stories 4.1 and 4.2.
- **Epic 4 component mapping:** `mobile/features/outfits`, `mobile/features/home` -- matches the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `flutter/material.dart` (TabBar, TabBarView, GridView, TextField, DropdownButtonFormField, FloatingActionButton), `cached_network_image` (for item thumbnails in the selection grid), `http` package (via ApiClient).
- No new API dependencies. API is consumed as-is.
- Reuses existing `WardrobeItem` model from `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`.
- Reuses existing `taxonomy.dart` constants for occasion dropdown values and display labels.
- Reuses existing `OutfitPersistenceService` from `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart`.

### File Structure Requirements

- New screens in `apps/mobile/lib/src/features/outfits/screens/` -- this is a new `screens/` directory within the outfits feature module. Follows the pattern of `wardrobe/screens/` and `home/screens/`.
- Test files mirror source structure under `apps/mobile/test/`.

### Testing Requirements

- Mobile unit tests must verify:
  - `saveManualOutfit` sends correct request body with `source: "manual"`
  - `saveManualOutfit` returns null on error
  - `saveManualOutfit` handles null occasion correctly
- Mobile widget tests for `CreateOutfitScreen` must verify:
  - Loading, error, and empty states render correctly
  - Category tabs show correct items and counts
  - Item selection/deselection toggles visual state
  - Selected count updates in AppBar subtitle
  - Preview strip shows/hides based on selection
  - "Next" button enables/disables based on selection count
  - Navigation to NameOutfitScreen with correct data
  - Semantics labels on all interactive elements
- Mobile widget tests for `NameOutfitScreen` must verify:
  - Name field, occasion dropdown, and save button render
  - Save calls `saveManualOutfit` with correct parameters
  - Default name "My Outfit" used when field is empty
  - Success and failure states handle correctly
  - Loading state on save button
  - Semantics labels present
- HomeScreen integration tests must verify:
  - FAB visible when weather loaded and persistence service available
  - FAB hidden when weather not loaded
  - FAB tap navigates to CreateOutfitScreen
  - All existing HomeScreen tests continue to pass
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing API tests pass -- no API changes)

### Previous Story Intelligence

- **Story 4.2 (direct predecessor)** completed with 228 API tests and 608 Flutter tests. All must continue to pass.
- **Story 4.2** established: `POST /v1/outfits` endpoint, `outfit-repository.js` with `createOutfit` and `getOutfit`, `OutfitPersistenceService` with `saveOutfit(OutfitSuggestion)`, `SwipeableOutfitStack` widget, `_handleOutfitSave` in HomeScreen, `_savedOutfitCount` state field.
- **Story 4.2 key code:** The `POST /v1/outfits` endpoint in `main.js` (lines 518-566) validates: `name` required, `items` array required with 1-7 entries, `source` defaults to `"ai"`. The `outfit-repository.js` `createOutfit` method validates item ownership. All of this works as-is for `source = "manual"`.
- **Story 4.2 `OutfitPersistenceService`** currently has one method: `saveOutfit(OutfitSuggestion suggestion)` which maps a suggestion model to the API request body. This story adds a second method `saveManualOutfit()` that builds the request body directly from parameters.
- **HomeScreen constructor parameters (as of Story 4.2):** `locationService` (required), `weatherService` (required), `sharedPreferences` (optional), `weatherCacheService` (optional), `outfitContextService` (optional), `calendarService` (optional), `calendarPreferencesService` (optional), `calendarEventService` (optional), `outfitGenerationService` (optional), `outfitPersistenceService` (optional), `onNavigateToAddItem` (optional). This story adds `apiClient` (optional).
- **HomeScreen state (as of Story 4.2):** `_state`, `_calendarState`, `_weatherData`, `_forecastData`, `_errorMessage`, `_lastUpdatedLabel`, `outfitContext`, `_dressingTip`, `_calendarEvents`, `_outfitResult`, `_isGeneratingOutfit`, `_outfitError`, `_wardrobeItems`, `_savedOutfitCount`, services. This story does NOT add new state fields -- only a new FAB and navigation method.
- **WardrobeScreen patterns (Story 2.5):** The wardrobe grid uses `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2)`, `CachedNetworkImage` for item photos, `WardrobeItem.fromJson()` for parsing, and `FilterBar` for filtering. The `CreateOutfitScreen` reuses the same `WardrobeItem` model and `CachedNetworkImage` pattern but with a 3-column grid (items are smaller since this is a selection interface, not a browsing interface).
- **ApiClient.listItems()** (Story 2.5): Already available with filter support. The `CreateOutfitScreen` calls it without filters to get all items, then filters client-side by `categorizationStatus`.
- **Key learning from Story 3.6:** When testing HomeScreen with snackbars, wrap the widget in a `MaterialApp` with a `Scaffold` ancestor to avoid "No ScaffoldMessenger widget found" errors.
- **Key learning from Story 4.2:** HomeScreen tests mock the `OutfitPersistenceService` and inject it via the constructor. Follow the same pattern for the FAB tests.
- **Taxonomy constants** are defined in `apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart`. The `validOccasions` list and `taxonomyDisplayLabel()` function are used for the occasion dropdown in `NameOutfitScreen`.

### Key Anti-Patterns to Avoid

- DO NOT create a new API endpoint. The existing `POST /v1/outfits` handles manual outfits via the `source` field.
- DO NOT create a new database migration. The `outfits` and `outfit_items` tables already support `source = 'manual'`.
- DO NOT implement outfit history/favorites/delete. That is Story 4.4.
- DO NOT enforce usage limits. Story 4.5 handles usage limits.
- DO NOT modify the existing `OutfitPersistenceService.saveOutfit()` method. Add a new method instead -- the existing one maps from `OutfitSuggestion`, the new one builds from raw parameters.
- DO NOT modify the `SwipeableOutfitStack` or `OutfitSuggestionCard` widgets. They are not affected by this story.
- DO NOT use the wardrobe grid's filter functionality in the `CreateOutfitScreen`. The item selection uses category tabs (client-side grouping), not server-side filtering. All items are fetched once and grouped locally.
- DO NOT allow uncategorized items in the selection grid. Only items with `categorizationStatus == 'completed'` are shown. This ensures the category grouping works correctly.
- DO NOT add a separate "Outfits" tab or screen for viewing saved outfits. That is Story 4.4.
- DO NOT forget to handle the case where `_outfitPersistenceService` is null in HomeScreen -- the FAB should not appear in that case.
- DO NOT add any API-side changes. This story is purely mobile (Flutter) work.

### References

- [Source: epics.md - Story 4.3: Manual Outfit Building]
- [Source: epics.md - Epic 4: AI Outfit Engine]
- [Source: prd.md - FR-OUT-05: Users shall be able to manually build outfits by selecting items from categorized lists]
- [Source: prd.md - FR-OUT-02: Generated outfits shall be stored in the `outfits` table with linked items in `outfit_items`]
- [Source: architecture.md - Server authority for sensitive rules]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures]
- [Source: architecture.md - Epic 4 AI Outfit Engine -> mobile/features/outfits, api/modules/outfits]
- [Source: ux-design-specification.md - AI-Assisted Editing: Tag Cloud Pattern]
- [Source: ux-design-specification.md - Bottom tab bar for core MVP destinations]
- [Source: ux-design-specification.md - Vibrant Soft-UI design direction]
- [Source: 4-2-outfit-generation-swipe-ui.md - POST /v1/outfits endpoint, OutfitPersistenceService, outfit-repository.js]
- [Source: 4-1-daily-ai-outfit-generation.md - outfits and outfit_items tables, 013_outfits.sql]
- [Source: 2-5-wardrobe-grid-filtering.md - WardrobeScreen grid pattern, CachedNetworkImage, listItems]
- [Source: 2-6-item-detail-view-management.md - WardrobeItem model with isFavorite, wearCount]
- [Source: apps/api/src/main.js - POST /v1/outfits route handler, validation, createRuntime]
- [Source: apps/api/src/modules/outfits/outfit-repository.js - createOutfit, item ownership validation]
- [Source: apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart - saveOutfit pattern]
- [Source: apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart - OutfitSuggestion model]
- [Source: apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart - WardrobeItem model]
- [Source: apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart - validOccasions, taxonomyDisplayLabel]
- [Source: apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart - grid pattern, CachedNetworkImage usage]
- [Source: apps/mobile/lib/src/features/home/screens/home_screen.dart - HomeScreen constructor, state machine, _buildOutfitSection]
- [Source: apps/mobile/lib/src/core/networking/api_client.dart - listItems, authenticatedPost]
- [Source: infra/sql/migrations/013_outfits.sql - outfits table CHECK constraint on source]

## Dev Agent Record

- **Implementation Date:** 2026-03-15
- **All 9 tasks completed** with full test coverage.
- **flutter analyze:** 0 issues
- **flutter test:** 647 tests pass (608 existing + 39 new)
- **npm --prefix apps/api test:** 228 tests pass (no API changes)
- No API or database changes were made (purely mobile work).
- Used `LinkedHashSet` for selection order preservation as specified.
- Used `initialValue` instead of deprecated `value` on `DropdownButtonFormField`.
- Used `.withValues(alpha:)` instead of deprecated `.withOpacity()`.

## File List

### New Files
- `apps/mobile/lib/src/features/outfits/screens/create_outfit_screen.dart` - CreateOutfitScreen widget
- `apps/mobile/lib/src/features/outfits/screens/name_outfit_screen.dart` - NameOutfitScreen widget
- `apps/mobile/test/features/outfits/screens/create_outfit_screen_test.dart` - 17 widget tests
- `apps/mobile/test/features/outfits/screens/name_outfit_screen_test.dart` - 13 widget tests

### Modified Files
- `apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart` - Added `saveManualOutfit` method
- `apps/mobile/lib/src/features/home/screens/home_screen.dart` - Added FAB, `apiClient` constructor param, `_navigateToCreateOutfit` method
- `apps/mobile/test/features/outfits/services/outfit_persistence_service_test.dart` - Added 6 `saveManualOutfit` tests
- `apps/mobile/test/features/home/screens/home_screen_test.dart` - Added 3 FAB integration tests
