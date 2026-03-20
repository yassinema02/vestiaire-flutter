# Story 2.6: Item Detail View & Management

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to view the full details of a wardrobe item and manage it (edit, favorite, delete),
so that I can see all metadata at a glance, maintain my wardrobe, and remove items I no longer own.

## Acceptance Criteria

1. Given I am on the Wardrobe grid, when I tap on an item tile, then I navigate to an ItemDetailScreen showing the item's full-size photo, all metadata (category, color, pattern, material, style, season, occasion, brand, name, purchase price, purchase date, currency), and timestamps (created, last updated) (FR-WRD-11).
2. Given I am on the ItemDetailScreen, when I look at the metadata section below the photo, then I see the item's wear count (displayed as "0 wears" for now -- wear logging is a future epic), cost-per-wear (calculated as purchasePrice / wearCount, or "N/A" if no price or zero wears), and last worn date (displayed as "Never" for now) (FR-WRD-11).
3. Given I am on the ItemDetailScreen, when I tap the "Edit" button, then I navigate to the ReviewItemScreen (reused from Story 2.4) pre-populated with the item's current metadata, allowing me to edit and save via PATCH /v1/items/:id (FR-WRD-07).
4. Given I am on the ItemDetailScreen, when I tap the favorite/heart icon in the AppBar, then the item's `isFavorite` field is toggled via `PATCH /v1/items/:id` with `{ isFavorite: true/false }`, the heart icon fills/unfills immediately (optimistic UI), and a brief SnackBar confirms the action (FR-WRD-13).
5. Given I am on the ItemDetailScreen, when I tap the "Delete" button, then a confirmation dialog appears: "Delete this item? This action cannot be undone." with "Cancel" and "Delete" buttons (FR-WRD-12).
6. Given the delete confirmation dialog is showing, when I tap "Delete", then the app calls `DELETE /v1/items/:id` on the API, the item is permanently removed from the database (including its image from Cloud Storage), the screen pops back to the wardrobe grid, and a SnackBar confirms "Item deleted" (FR-WRD-12).
7. Given the delete confirmation dialog is showing, when I tap "Cancel", then the dialog is dismissed and no deletion occurs.
8. Given the API receives a `DELETE /v1/items/:id` request, when it processes the request, then it verifies ownership (via firebase_uid join), deletes the item row (cascading any future FK references), and returns 200 with `{ deleted: true }`. If the item is not found or not owned by the user, it returns 404.
9. Given the API receives a `PATCH /v1/items/:id` request with `{ isFavorite: true }`, when it processes the request, then it updates the `is_favorite` boolean column on the items table and returns the updated item.
10. Given I am on the Wardrobe grid after returning from ItemDetailScreen, when the grid refreshes, then any changes (edits, deletions, favorites) are reflected in the grid.
11. Given I am on the ItemDetailScreen, when all interactive elements render, then each button and icon has appropriate Semantics labels for screen reader accessibility, and touch targets are at least 44x44 points (WCAG AA).
12. Given the wardrobe grid currently has no tap handler on items, when this story is complete, then tapping any item in the grid navigates to the ItemDetailScreen for that item.

## Tasks / Subtasks

- [x] Task 1: Database migration for is_favorite column (AC: 4, 9)
  - [x] 1.1: Create `infra/sql/migrations/011_items_favorite.sql`: `ALTER TABLE app_public.items ADD COLUMN is_favorite BOOLEAN NOT NULL DEFAULT FALSE;` Add a comment: `COMMENT ON COLUMN app_public.items.is_favorite IS 'User-toggled favorite status for quick access filtering';`.
  - [x] 1.2: Add index for future favorite filtering: `CREATE INDEX idx_items_is_favorite ON app_public.items(is_favorite) WHERE is_favorite = TRUE;` (partial index, efficient for sparse favorites).

- [x] Task 2: API - Add DELETE /v1/items/:id endpoint (AC: 5, 6, 8)
  - [x] 2.1: Add `deleteItem(authContext, itemId)` method to `apps/api/src/modules/items/repository.js`. Use the same ownership check pattern as `getItem` (JOIN profiles ON firebase_uid). Execute `DELETE FROM app_public.items WHERE id = $1 AND profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $2)`. Return `{ deleted: true }` if `rowCount > 0`, otherwise return `null` (item not found/not owned).
  - [x] 2.2: Add `deleteItemForUser(authContext, itemId)` method to `apps/api/src/modules/items/service.js`. Call `repo.deleteItem(authContext, itemId)`. If result is null, throw a 404 error with code `NOT_FOUND`. Return `{ deleted: true }`.
  - [x] 2.3: Add route `DELETE /v1/items/:id` in `apps/api/src/main.js`. Use the existing `itemIdMatch` regex (`/^\/v1\/items\/([^/]+)$/`). Add the handler: `if (req.method === "DELETE" && itemIdMatch) { ... }`. Place it after the existing PATCH and GET handlers for the same path pattern.

- [x] Task 3: API - Add is_favorite support to existing PATCH/GET endpoints (AC: 4, 9)
  - [x] 3.1: Update `mapItemRow` in `apps/api/src/modules/items/repository.js` to include `isFavorite: row.is_favorite ?? false`.
  - [x] 3.2: Update `updateItem` in `apps/api/src/modules/items/repository.js` to handle `fields.isFavorite !== undefined`: add `setClauses.push(\`is_favorite = $\${paramIndex++}\`); values.push(fields.isFavorite);`.
  - [x] 3.3: Update `updateItemForUser` in `apps/api/src/modules/items/service.js` to validate `isFavorite`: if provided, it must be a boolean. Add `validatedFields.isFavorite = updateData.isFavorite;`.

- [x] Task 4: Mobile - Update WardrobeItem model (AC: 1, 2, 4)
  - [x] 4.1: Update `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`: Add `isFavorite` field (`bool`, default `false`). Add `wearCount` field (`int`, default `0`). Add `lastWornDate` field (`String?`, nullable). Parse these in `fromJson`: `isFavorite: json["isFavorite"] as bool? ?? json["is_favorite"] as bool? ?? false`, `wearCount: (json["wearCount"] as num?)?.toInt() ?? (json["wear_count"] as num?)?.toInt() ?? 0`, `lastWornDate: json["lastWornDate"] as String? ?? json["last_worn_date"] as String?`.
  - [x] 4.2: Add computed getter `String get costPerWear`: if `purchasePrice != null && wearCount > 0` return `(purchasePrice! / wearCount).toStringAsFixed(2)`, else return `null`. Add `String get costPerWearDisplay`: returns formatted CPW with currency symbol or "N/A".
  - [x] 4.3: Update `toJson()` to include `isFavorite` when true.

- [x] Task 5: Mobile - Add deleteItem method to ApiClient (AC: 6, 8)
  - [x] 5.1: Add `deleteItem(String itemId)` method to `apps/mobile/lib/src/core/networking/api_client.dart`: calls `authenticatedDelete("/v1/items/$itemId")`. Returns `Map<String, dynamic>`.

- [x] Task 6: Mobile - Create ItemDetailScreen (AC: 1, 2, 3, 4, 5, 6, 7, 10, 11)
  - [x] 6.1: Create `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` as a `StatefulWidget`. Constructor accepts `WardrobeItem item` and `ApiClient apiClient`. The screen fetches the latest item data via `apiClient.getItem(item.id)` on init to ensure freshness.
  - [x] 6.2: Build the AppBar with: back button (Semantics label "Back"), item name or "Item Detail" as title, a favorite toggle IconButton (filled heart `Icons.favorite` when favorited, outline `Icons.favorite_border` when not, color `Color(0xFFEF4444)` red when favorited), and a PopupMenuButton with "Edit" and "Delete" options.
  - [x] 6.3: Build the body as a `SingleChildScrollView` with: (a) full-width item photo using `CachedNetworkImage` with `ClipRRect(borderRadius: 12)`, max height 400px; (b) a "Stats" row showing wear count, cost-per-wear, and last worn date in a horizontal card layout; (c) a "Details" section displaying all metadata as labeled rows (Category, Color, Secondary Colors, Pattern, Material, Style, Season, Occasion, Brand, Purchase Price, Purchase Date, Currency, Added on, Last Updated).
  - [x] 6.4: Implement the favorite toggle: on tap, immediately update local state (optimistic UI), call `apiClient.updateItem(item.id, {"isFavorite": !currentValue})`. On error, revert local state and show error SnackBar.
  - [x] 6.5: Implement the "Edit" action: navigate to `ReviewItemScreen(item: currentItem, apiClient: apiClient)`. When ReviewItemScreen pops with `true`, refresh item data via `apiClient.getItem(item.id)` and update local state. Set a result flag so the wardrobe grid knows to refresh.
  - [x] 6.6: Implement the "Delete" action: show `showDialog` with `AlertDialog` containing title "Delete Item", content "Delete this item? This action cannot be undone.", and two actions: TextButton "Cancel" (pops dialog) and TextButton "Delete" (styled with red text color `Color(0xFFEF4444)`). On delete confirmation, call `apiClient.deleteItem(item.id)`, pop back to wardrobe grid with a result indicating deletion, and show SnackBar "Item deleted".
  - [x] 6.7: Handle errors gracefully: if `getItem` fails on init, show error state with retry button. If delete fails, show error SnackBar. If favorite toggle fails, revert optimistic state.
  - [x] 6.8: All metadata values use `taxonomyDisplayLabel()` for display formatting. Null/empty values show "Not set" in gray text. Season and occasion arrays are joined with ", ".

- [x] Task 7: Mobile - Add tap handler to wardrobe grid (AC: 10, 12)
  - [x] 7.1: Update `_buildItemTile` in `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`: wrap the existing tile content in a `GestureDetector` (or `InkWell`) with an `onTap` handler that navigates to `ItemDetailScreen(item: item, apiClient: widget.apiClient)`. Wrap with `Semantics(label: "View ${item.displayLabel}")` for accessibility.
  - [x] 7.2: When `ItemDetailScreen` pops back (via `Navigator.push` returning a result), check if the result indicates changes were made (edit or delete). If so, call `refresh()` to reload the wardrobe grid.
  - [x] 7.3: Ensure the existing `GestureDetector` for long-press on failed items continues to work alongside the new tap handler. The long-press handler should remain on failed items; the tap handler should be on ALL items.

- [x] Task 8: Widget tests for ItemDetailScreen (AC: 1, 2, 3, 4, 5, 6, 7, 11)
  - [x] 8.1: Create `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart`:
    - ItemDetailScreen renders item photo, name, and all metadata fields.
    - Stats row shows wear count "0 wears", CPW "N/A", last worn "Never" for a new item.
    - Stats row shows formatted CPW when purchasePrice and wearCount are set.
    - Tapping favorite icon calls apiClient.updateItem with isFavorite toggled.
    - Favorite icon updates optimistically (filled/unfilled state changes immediately).
    - Tapping "Edit" in PopupMenu navigates to ReviewItemScreen.
    - Tapping "Delete" in PopupMenu shows confirmation dialog.
    - Confirming delete calls apiClient.deleteItem and pops the screen.
    - Canceling delete dismisses the dialog without calling API.
    - Semantics labels are present on all interactive elements.
    - Error state renders when getItem fails.
    - Taxonomy values are displayed with proper formatting via taxonomyDisplayLabel.

- [x] Task 9: Widget tests for wardrobe grid tap navigation (AC: 10, 12)
  - [x] 9.1: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`:
    - Tapping an item tile navigates to ItemDetailScreen.
    - After returning from ItemDetailScreen with a "changed" result, wardrobe grid refreshes.
    - Existing long-press behavior on failed items still works.
    - Existing tests continue to pass.

- [x] Task 10: API tests for DELETE /v1/items/:id and isFavorite (AC: 6, 8, 9)
  - [x] 10.1: Add tests to `apps/api/test/modules/items/service.test.js`:
    - `deleteItemForUser` calls repo.deleteItem and returns `{ deleted: true }`.
    - `deleteItemForUser` throws 404 when item not found.
    - `updateItemForUser` accepts isFavorite boolean and passes to repo.
    - `updateItemForUser` rejects non-boolean isFavorite with 400 error.
  - [x] 10.2: Add tests to `apps/api/test/items-endpoint.test.js`:
    - `DELETE /v1/items/:id` returns 200 with `{ deleted: true }` for owned item.
    - `DELETE /v1/items/:id` returns 404 for non-existent item.
    - `DELETE /v1/items/:id` returns 404 for item owned by another user.
    - `DELETE /v1/items/:id` returns 401 without auth token.
    - `PATCH /v1/items/:id` with `{ isFavorite: true }` returns updated item with `isFavorite: true`.
    - `GET /v1/items/:id` returns `isFavorite` field in response.
    - `GET /v1/items` list endpoint returns `isFavorite` field on each item.

- [x] Task 11: Regression testing (AC: all)
  - [x] 11.1: Run `flutter analyze` -- zero issues.
  - [x] 11.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 11.3: Run `npm --prefix apps/api test` -- all existing + new tests pass.
  - [x] 11.4: Verify existing AddItemScreen upload flow still works end-to-end (upload -> ReviewItemScreen -> save -> wardrobe grid).
  - [x] 11.5: Verify `GET /v1/items` returns backward-compatible response (new `isFavorite` field defaults to false).
  - [x] 11.6: Verify wardrobe grid filters, shimmer overlays, badges, category labels, and long-press menus all continue to work after adding tap navigation.
  - [x] 11.7: Verify ReviewItemScreen can be opened both from AddItemScreen (new item flow) and from ItemDetailScreen (edit existing item flow).

## Dev Notes

- This is the SIXTH story in Epic 2 (Digital Wardrobe Core). It builds on Stories 2.1 (upload, wardrobe grid, 5-tab shell), 2.2 (bg removal, shimmer, polling, WardrobeItem model), 2.3 (categorization, taxonomy, category labels on grid), 2.4 (metadata editing, PATCH endpoint, ReviewItemScreen, taxonomy.dart, tag_cloud.dart), and 2.5 (filtering, CachedNetworkImage, filter bar). Reuse everything established in those stories.
- The primary FRs covered are FR-WRD-11 (item detail screen with image, metadata, wear count, CPW, last worn date), FR-WRD-12 (delete items), and FR-WRD-13 (favorite items). The epics.md also references wear history display, but wear logging is Epic 4 (FR-LOG-*). For now, display placeholder values: wear count = 0, last worn = "Never", CPW = "N/A".
- The `wearCount` and `lastWornDate` fields do NOT exist on the items table yet. They will be added in the wear logging epic (Epic 4). For now, parse them from the API response if present (future-proofing), but default to 0 / null. The ItemDetailScreen should display these fields even though they are always default values in this story -- the UI is being built ahead of the data.
- The ReviewItemScreen from Story 2.4 was explicitly designed to be reusable (AC 8 of Story 2.4: "The editing widget must be built as a reusable component for this future use"). This story fulfills that requirement by navigating to ReviewItemScreen from the ItemDetailScreen's "Edit" action.
- There is NO `DELETE /v1/items/:id` endpoint yet. This story adds it. The existing `DELETE /v1/profiles/me` handles account-level deletion with cascading item cleanup, but there is no single-item delete.
- The wardrobe grid currently has NO tap handler on items. The only interaction is long-press on failed items for retry context menus. This story adds `onTap` navigation to ItemDetailScreen for ALL items while preserving the existing long-press behavior.
- Cloud Storage image cleanup on item deletion is an optional enhancement. For MVP, deleting the database row is sufficient since signed URLs will expire. If the team wants immediate cleanup, the API can call `uploadService.deleteFile(item.photoUrl)` in the delete handler -- but this is not required for this story. Note it as a future optimization.

### Project Structure Notes

- New files:
  - `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart`
  - `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart`
  - `infra/sql/migrations/011_items_favorite.sql`
- Modified files:
  - `apps/api/src/modules/items/repository.js` (add deleteItem, isFavorite to mapItemRow and updateItem)
  - `apps/api/src/modules/items/service.js` (add deleteItemForUser, isFavorite validation in updateItemForUser)
  - `apps/api/src/main.js` (add DELETE /v1/items/:id route)
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (add isFavorite, wearCount, lastWornDate, costPerWear)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add deleteItem method)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (add onTap navigation to ItemDetailScreen)
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (add tap navigation tests)
  - `apps/api/test/modules/items/service.test.js` (add deleteItemForUser and isFavorite tests)
  - `apps/api/test/items-endpoint.test.js` (add DELETE endpoint and isFavorite PATCH tests)

### Technical Requirements

- The `DELETE /v1/items/:id` endpoint reuses the existing `itemIdMatch` regex in main.js. The match is already computed before the PATCH/GET blocks, so add the DELETE handler alongside them: `if (req.method === "DELETE" && itemIdMatch) { ... }`.
- The `deleteItem` repository method should use a single DELETE statement with a subquery for ownership: `DELETE FROM app_public.items WHERE id = $1 AND profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $2) RETURNING id`. This avoids needing a separate ownership check query.
- The `is_favorite` column is `BOOLEAN NOT NULL DEFAULT FALSE`. This is a simple, non-nullable column -- no need for a CHECK constraint since BOOLEAN is self-constraining.
- The partial index `WHERE is_favorite = TRUE` is optimal for the "show favorites" filter use case (future story) since typically only a small fraction of items are favorited.
- Cost-per-wear calculation: `purchasePrice / wearCount`. Display format: `"£12.50/wear"` (using the item's currency symbol). Handle division by zero gracefully (show "N/A").
- The `wearCount` and `lastWornDate` fields are forward-looking model additions. The API does not return these fields yet (they will be added in Epic 4). The model defaults them to 0 and null respectively.
- For the ItemDetailScreen photo, use `CachedNetworkImage` (already added as a dependency in Story 2.5) for consistency with the wardrobe grid.

### Architecture Compliance

- All mutations (delete, favorite toggle) go through the Cloud Run API. No direct database access from the client.
- RLS on `items` table ensures users only delete/modify their own items. The `deleteItem` repository method enforces ownership via `firebase_uid` join.
- The delete operation is permanent and irreversible (no soft-delete). This aligns with the GDPR right to erasure pattern already established in Story 1.7 for account deletion.
- Optimistic UI for favorite toggle follows the architecture principle of "Progressive enhancement: optimistic UI improves UX without weakening source-of-truth guarantees."
- The mobile client owns presentation and local state. The API owns data integrity and business rules.

### Library / Framework Requirements

- Mobile: No new dependencies. Uses existing `cached_network_image` (from Story 2.5), `flutter/material.dart` (AlertDialog, PopupMenuButton, IconButton), existing `api_client.dart`, existing `review_item_screen.dart`.
- API: No new dependencies. Uses existing `pg` pool, existing modules.

### File Structure Requirements

- The `item_detail_screen.dart` lives in `apps/mobile/lib/src/features/wardrobe/screens/` alongside existing `wardrobe_screen.dart`, `add_item_screen.dart`, and `review_item_screen.dart`.
- Migration file follows sequential numbering: 011 (after existing 010_items_filter_indexes.sql).
- No new API modules or directories. Changes are to existing items module files.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns in existing `apps/api/test/modules/items/service.test.js` and `apps/api/test/items-endpoint.test.js`.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient.
- Test the complete delete flow: tap Delete -> dialog appears -> confirm -> API called -> screen pops.
- Test favorite toggle: optimistic update, API call, and error revert.
- Test navigation: grid tap -> detail screen -> edit -> ReviewItemScreen -> back -> detail refreshed -> back -> grid refreshed.
- Target: all existing tests continue to pass (280 Flutter tests, 127 API tests from Story 2.5).

### Previous Story Intelligence

- Story 2.5 established: FilterBar widget, server-side filtering on GET /v1/items, CachedNetworkImage dependency, item count display, filtered empty state. 280 Flutter tests, 127 API tests.
- Story 2.4 established: ReviewItemScreen with Tag Cloud editing, PATCH /v1/items/:id endpoint, GET /v1/items/:id endpoint, taxonomy.dart with constants and `taxonomyDisplayLabel()` helper, TagCloud and TagSelectionSheet reusable widgets, `WardrobeItem.toJson()`. AC 8 explicitly stated the editing UI must be reusable for this story.
- Story 2.4 key learning: `DropdownButtonFormField.value` deprecated in Flutter 3.33+; use `initialValue` instead.
- Story 2.5 key learning: Used Icon-based radio indicators instead of deprecated Radio widget (`groupValue`/`onChanged` deprecated in Flutter 3.33+).
- Story 2.3 established: AI categorization pipeline, taxonomy constants in shared `taxonomy.js` module.
- Story 2.2 established: Shimmer overlay, polling with Timer.periodic, long-press context menu for failed items.
- Story 2.1 established: MainShellScreen with 5-tab navigation, WardrobeScreen with GridView.builder, AddItemScreen, ApiClient.
- Items table current columns after Story 2.5: `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `created_at`, `updated_at`. Indexes on: `category`, `color`, `brand` (B-tree), `season`, `occasion` (GIN).
- The `_buildItemTile` method in `wardrobe_screen.dart` currently wraps the tile in a `GestureDetector` only for failed items (long-press). To add tap navigation for ALL items, restructure: wrap the entire tile in a GestureDetector with onTap, and nest the existing long-press GestureDetector inside it for failed items only.

### Key Anti-Patterns to Avoid

- DO NOT implement soft-delete. The requirement (FR-WRD-12) says "delete items from their wardrobe" -- this is permanent deletion. Soft-delete adds unnecessary complexity.
- DO NOT add wear logging or wear count increment logic in this story. Those features belong to Epic 4 (FR-LOG-*). Only display placeholder UI for wear stats.
- DO NOT create a separate favorites filter in this story. The `is_favorite` column and toggle are added here, but filtering by favorites is a future enhancement.
- DO NOT skip the confirmation dialog for delete. Permanent data loss requires explicit user confirmation.
- DO NOT use a BottomSheet for the item detail view. The epics.md and PRD describe this as a full "detail screen" (FR-WRD-11: "tap an item to view its detail screen"), not a bottom sheet.
- DO NOT break the existing ReviewItemScreen. It must continue to work from both AddItemScreen (new item flow) and ItemDetailScreen (edit existing item flow).
- DO NOT change the existing `POST /v1/items`, `PATCH /v1/items/:id`, or `GET /v1/items/:id` behavior. Only add the new DELETE endpoint and extend PATCH/GET with `isFavorite`.
- DO NOT implement Cloud Storage cleanup on delete in this story. Let signed URLs expire naturally. This is a future optimization.
- DO NOT add `favorite` as a filter dimension to the FilterBar. That is out of scope for this story.

### Implementation Guidance

- **Repository deleteItem:**
  ```javascript
  async deleteItem(authContext, itemId) {
    const client = await pool.connect();
    try {
      await client.query("begin");
      await client.query(
        "select set_config('app.current_user_id', $1, true)",
        [authContext.userId]
      );

      const result = await client.query(
        `DELETE FROM app_public.items
         WHERE id = $1
           AND profile_id = (
             SELECT id FROM app_public.profiles WHERE firebase_uid = $2
           )
         RETURNING id`,
        [itemId, authContext.userId]
      );

      await client.query("commit");

      if (result.rows.length === 0) {
        return null;
      }
      return { deleted: true };
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }
  }
  ```

- **DELETE route in main.js:**
  ```javascript
  // DELETE /v1/items/:id - Delete item
  if (req.method === "DELETE" && itemIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = itemIdMatch[1];
      const result = await itemService.deleteItemForUser(authContext, itemId);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }
  ```

- **ApiClient deleteItem:**
  ```dart
  /// Delete a wardrobe item permanently.
  ///
  /// Calls DELETE /v1/items/$itemId.
  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    return authenticatedDelete("/v1/items/$itemId");
  }
  ```

- **WardrobeItem additions:**
  ```dart
  final bool isFavorite;
  final int wearCount;
  final String? lastWornDate;

  String? get costPerWear {
    if (purchasePrice == null || wearCount == 0) return null;
    return (purchasePrice! / wearCount).toStringAsFixed(2);
  }

  String get costPerWearDisplay {
    final cpw = costPerWear;
    if (cpw == null) return "N/A";
    final symbol = currency == "EUR" ? "€" : currency == "USD" ? "\$" : "£";
    return "$symbol$cpw/wear";
  }
  ```

- **Wardrobe grid tap handler:**
  ```dart
  // In _buildItemTile, wrap the entire tile:
  Widget tile = Semantics(
    label: "View ${item.displayLabel}",
    child: GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              item: item,
              apiClient: widget.apiClient,
            ),
          ),
        );
        if (result == true) {
          refresh();
        }
      },
      child: /* existing ClipRRect + Stack content */,
    ),
  );

  // Then wrap with long-press handler if failed:
  if (item.isFailed || item.isCategorizationFailed) {
    tile = GestureDetector(
      onLongPress: () { /* existing context menu */ },
      child: tile,
    );
  }
  ```

- **ItemDetailScreen stats row:**
  ```dart
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _buildStatCard("Wears", "${_item.wearCount}"),
      _buildStatCard("CPW", _item.costPerWearDisplay),
      _buildStatCard("Last Worn", _item.lastWornDate ?? "Never"),
    ],
  )
  ```

- **ItemDetailScreen metadata section:** Use a `Column` of `_buildMetadataRow(String label, String? value)` widgets, each showing a label on the left and value on the right in a `Row`. For array fields (season, occasion, secondaryColors), join with ", " and format each with `taxonomyDisplayLabel()`.

### References

- [Source: epics.md - Story 2.6: Item Detail View & Management]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: prd.md - FR-WRD-11: Users shall tap an item to view its detail screen showing: image, all metadata, wear count, cost-per-wear, last worn date, wear history]
- [Source: prd.md - FR-WRD-12: Users shall be able to delete items from their wardrobe]
- [Source: prd.md - FR-WRD-13: Users shall be able to favorite items for quick access]
- [Source: architecture.md - Cloud Run acts as the only public business API]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Progressive enhancement: optimistic UI]
- [Source: architecture.md - Mobile Client: portrait-only, feature-facing wrapper widgets]
- [Source: ux-design-specification.md - Contextual Deep Dives: Bottom sheets for acting on a specific item (editing)]
- [Source: ux-design-specification.md - Touch targets at least 44x44 points (WCAG AA)]
- [Source: ux-design-specification.md - Semantics widget for screen reader support]
- [Source: 2-5-wardrobe-grid-filtering.md - CachedNetworkImage, FilterBar, wardrobe grid structure]
- [Source: 2-4-manual-metadata-editing-creation.md - ReviewItemScreen (reusable editing), PATCH endpoint, taxonomy.dart, TagCloud, AC 8 reusable component]
- [Source: 2-3-ai-item-categorization-tagging.md - Taxonomy constants, categorization status]
- [Source: 2-2-ai-background-removal-upload.md - Shimmer overlay, long-press context menu]
- [Source: 2-1-upload-item-photo-camera-gallery.md - WardrobeScreen grid, ApiClient]

## Change Log

- 2026-03-11: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, UX specification, PRD requirements (FR-WRD-11, FR-WRD-12, FR-WRD-13), and Stories 2.1-2.5 implementation context.
