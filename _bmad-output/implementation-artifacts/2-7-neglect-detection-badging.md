# Story 2.7: Neglect Detection & Badging

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to quickly see which items I haven't worn recently,
so that I can decide whether to wear them or declutter them.

## Acceptance Criteria

1. Given I have items in my wardrobe, when the API returns items via `GET /v1/items` or `GET /v1/items/:id`, then each item includes a computed `neglectStatus` field that is either `"neglected"` or `null`, based on whether the item has exceeded the neglect threshold (FR-WRD-14).
2. Given an item has `wearCount = 0` and was created more than 180 days ago (using `created_at` as proxy since wear logging does not exist yet), when the API computes `neglectStatus`, then the item is marked as `"neglected"` (FR-WRD-14).
3. Given an item has `wearCount > 0` and its `lastWornDate` is more than 180 days ago, when the API computes `neglectStatus`, then the item is marked as `"neglected"`. If `lastWornDate` is null but `wearCount = 0`, fallback to `created_at` (FR-WRD-14).
4. Given an item was created fewer than 180 days ago and has never been worn, when the API computes `neglectStatus`, then the item is NOT marked as neglected (it is still "new enough") (FR-WRD-14).
5. Given I view the Wardrobe grid, when an item has `neglectStatus = "neglected"`, then a small amber/orange "Neglected" badge is displayed on the item tile in the bottom-left corner, positioned so it does not overlap with existing warning/info badges (top-right, top-left) or the category label (bottom-center) (FR-WRD-15).
6. Given I view the ItemDetailScreen for a neglected item, when the detail screen loads, then a prominent "Neglected" indicator is displayed in the stats row or as a banner below the photo, clearly communicating the item has not been worn recently (FR-WRD-15).
7. Given I am on the Wardrobe tab with the FilterBar, when I see the filter chips, then a new "Neglect" filter chip is available alongside the existing Category, Color, Season, Occasion, and Brand filters (FR-WRD-10).
8. Given I tap the "Neglect" filter chip, when the filter options appear, then I see two options: "All" (default, clears filter) and "Neglected" (shows only neglected items). Selecting "Neglected" filters the grid to show only items with `neglectStatus = "neglected"` (FR-WRD-10).
9. Given the neglect threshold is configurable, when the API computes neglect status, then it uses a server-side constant of 180 days (default) that can be changed in a single location without code changes to the mobile client (FR-WRD-14).
10. Given the mobile WardrobeItem model, when it parses API responses, then it correctly reads the `neglectStatus` field and exposes an `isNeglected` boolean getter for use by the UI (FR-WRD-14, FR-WRD-15).
11. Given all changes are made, when I run the full test suite, then all existing tests continue to pass and new tests cover neglect computation, badge rendering, and filter behavior.

## Tasks / Subtasks

- [x] Task 1: API - Add computed neglectStatus to item mapping (AC: 1, 2, 3, 4, 9)
  - [x] 1.1: Define a `NEGLECT_THRESHOLD_DAYS` constant (value: `180`) in `apps/api/src/modules/items/repository.js` at the top of the file. This is the single source of truth for the neglect threshold.
  - [x] 1.2: Update `mapItemRow(row)` in `apps/api/src/modules/items/repository.js` to compute and include `neglectStatus`. Logic: (a) if `row.wear_count > 0 && row.last_worn_date != null`, compare `last_worn_date` to current date; if more than `NEGLECT_THRESHOLD_DAYS` ago, set `neglectStatus: "neglected"`, else `null`. (b) if `row.wear_count === 0 || row.last_worn_date == null`, compare `row.created_at` to current date; if more than `NEGLECT_THRESHOLD_DAYS` ago, set `neglectStatus: "neglected"`, else `null`. Use `Date.now() - new Date(dateValue).getTime() > NEGLECT_THRESHOLD_DAYS * 86400000` for the comparison.
  - [x] 1.3: Since `wear_count` and `last_worn_date` columns do not exist on the items table yet (they will be added in Epic 5), the computation in 1.2 must gracefully handle missing columns: treat `row.wear_count` as `0` and `row.last_worn_date` as `null` if they are undefined. This means for MVP, ALL items older than 180 days will be marked as neglected, which is the correct behavior since no wear logging exists.

- [x] Task 2: API - Add neglect_status filter support to GET /v1/items (AC: 8)
  - [x] 2.1: Update `listItems` in `apps/api/src/modules/items/repository.js` to accept an optional `neglectStatus` filter parameter. Since neglect status is computed (not stored), filtering must be done AFTER fetching items. When `neglectStatus` is provided: (a) fetch all items matching other filters, (b) map them through `mapItemRow`, (c) filter the mapped results by `neglectStatus === "neglected"`. This is a post-query filter, not a SQL WHERE clause, because neglect status is computed from `created_at` / `last_worn_date`, not stored as a column.
  - [x] 2.2: Update `listItemsForUser` in `apps/api/src/modules/items/service.js` to accept and pass through the `neglectStatus` option. Validate that if provided, it must be the string `"neglected"` (only valid filter value). Return 400 for any other value.
  - [x] 2.3: Update the `GET /v1/items` route handler in `apps/api/src/main.js` to extract `neglect_status` from `url.searchParams` and pass it as `neglectStatus` to `listItemsForUser`.

- [x] Task 3: Mobile - Update WardrobeItem model (AC: 10)
  - [x] 3.1: Update `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`: Add `neglectStatus` field (`String?`, nullable). Parse from JSON: `neglectStatus: json["neglectStatus"] as String? ?? json["neglect_status"] as String?`.
  - [x] 3.2: Add a computed getter `bool get isNeglected => neglectStatus == "neglected";` for convenient UI use.

- [x] Task 4: Mobile - Update ApiClient to support neglect_status filter (AC: 8)
  - [x] 4.1: Update `listItems` in `apps/mobile/lib/src/core/networking/api_client.dart` to accept an optional `String? neglectStatus` parameter. If provided, append `neglect_status=$value` to the query string.

- [x] Task 5: Mobile - Add "Neglected" badge to wardrobe grid tiles (AC: 5)
  - [x] 5.1: Update `_buildItemTile` in `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`: After the existing category label `Positioned` widget, add a new `Positioned` widget for the neglect badge. Position: `bottom: 0, left: 0`. Only show when `item.isNeglected` is true AND the item is not in a processing/pending state. The badge is a small `Container` with amber/orange background (`Color(0xFFF59E0B)`), rounded corners (top-right: 8), containing a `Row` with a small `Icons.schedule` (clock) icon and "Neglected" text in white, font size 9, compact padding (horizontal: 6, vertical: 2).
  - [x] 5.2: Add a `Semantics` label `"Neglected item"` wrapping the badge for screen reader accessibility.
  - [x] 5.3: Ensure the neglect badge does NOT overlap with: (a) the orange warning badge (top: 8, right: 8) for bg removal failures, (b) the blue info badge (top: 8, left: 8) for categorization failures, (c) the category label (bottom: 0, center, full width). The neglect badge is at bottom-left, overlapping the left portion of the category label is acceptable since both are bottom-positioned but the neglect badge sits on top.

- [x] Task 6: Mobile - Add neglect indicator to ItemDetailScreen (AC: 6)
  - [x] 6.1: Update `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart`: In the stats row section (or just below the photo), add a neglect status indicator when `_item.isNeglected` is true. Display a `Container` with amber background (`Color(0xFFF59E0B)`), 12px border radius, containing a `Row` with `Icons.schedule` icon and text "This item has been neglected -- consider wearing or decluttering it". Use white text, 13px font. Add Semantics label.
  - [x] 6.2: Include the `neglectStatus` in the metadata section as well: show "Neglect Status" row with value "Neglected" (amber text) or "Active" (green text) depending on status.

- [x] Task 7: Mobile - Add "Neglect" filter to FilterBar (AC: 7, 8)
  - [x] 7.1: Update `apps/mobile/lib/src/features/wardrobe/widgets/filter_bar.dart`: Add `"neglect"` to the `_filterDimensions` list. Add `"neglect": "Neglect"` to the `_dimensionLabels` map.
  - [x] 7.2: Update `_getOptionsForDimension` to return `["neglected"]` for the `"neglect"` dimension. The "All" option is already provided by the existing bottom sheet logic.
  - [x] 7.3: The filter chip should show "Neglected" when active (the value `"neglected"` goes through `taxonomyDisplayLabel` which will capitalize it to "Neglected").

- [x] Task 8: Mobile - Integrate neglect filter into WardrobeScreen (AC: 7, 8)
  - [x] 8.1: Update `_loadItems()` and `_pollForUpdates()` in `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`: Pass `neglectStatus: _activeFilters["neglect"]` to `apiClient.listItems()` calls.
  - [x] 8.2: Ensure the neglect filter works alongside existing filters (e.g., category = "tops" AND neglect = "neglected" shows only neglected tops).

- [x] Task 9: Widget tests for neglect badge on wardrobe grid (AC: 5, 11)
  - [x] 9.1: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`:
    - Neglect badge is displayed on items where `neglectStatus = "neglected"`.
    - Neglect badge is NOT displayed on items where `neglectStatus` is null.
    - Neglect badge has correct Semantics label "Neglected item".
    - Neglect badge is not shown on items that are still processing (bg removal pending).
    - Existing tests continue to pass.

- [x] Task 10: Widget tests for neglect indicator on ItemDetailScreen (AC: 6, 11)
  - [x] 10.1: Update `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart`:
    - Neglect banner is displayed when item has `neglectStatus = "neglected"`.
    - Neglect banner is NOT displayed when item has `neglectStatus = null`.
    - Neglect status row in metadata section shows "Neglected" or "Active".
    - Existing tests continue to pass.

- [x] Task 11: Widget tests for neglect filter in FilterBar (AC: 7, 8, 11)
  - [x] 11.1: Update `apps/mobile/test/features/wardrobe/widgets/filter_bar_test.dart`:
    - FilterBar renders 6 filter chips (Category, Color, Season, Occasion, Brand, Neglect).
    - Tapping Neglect chip opens bottom sheet with "All" and "Neglected" options.
    - Selecting "Neglected" calls onFiltersChanged with `{"neglect": "neglected"}`.
    - Existing filter tests continue to pass.

- [x] Task 12: API tests for neglect computation and filter (AC: 1, 2, 3, 4, 8, 9, 11)
  - [x] 12.1: Add tests to `apps/api/test/modules/items/service.test.js`:
    - Item created > 180 days ago with no wear data has `neglectStatus: "neglected"` in response.
    - Item created < 180 days ago with no wear data has `neglectStatus: null` in response.
    - `listItemsForUser` with `neglectStatus: "neglected"` returns only neglected items.
    - `listItemsForUser` with invalid neglectStatus value returns 400 error.
  - [x] 12.2: Add tests to `apps/api/test/items-endpoint.test.js`:
    - `GET /v1/items` returns items with `neglectStatus` field computed correctly.
    - `GET /v1/items?neglect_status=neglected` returns only neglected items.
    - `GET /v1/items?neglect_status=invalid` returns 400 error.
    - `GET /v1/items/:id` returns item with `neglectStatus` field.
    - `GET /v1/items` without neglect_status filter returns all items (backward compatibility).

- [x] Task 13: Regression testing (AC: all)
  - [x] 13.1: Run `flutter analyze` -- zero issues.
  - [x] 13.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 13.3: Run `npm --prefix apps/api test` -- all existing + new tests pass.
  - [x] 13.4: Verify existing wardrobe grid functionality is preserved: shimmer overlays, warning/info badges, category labels, filter chips, long-press context menus, tap navigation to ItemDetailScreen, CachedNetworkImage rendering.
  - [x] 13.5: Verify `GET /v1/items` without `neglect_status` returns all items with the new `neglectStatus` computed field (backward compatible -- additive field only).
  - [x] 13.6: Verify ItemDetailScreen still shows all metadata, favorite toggle, edit, and delete functionality.

## Dev Notes

- This is the SEVENTH and FINAL story in Epic 2 (Digital Wardrobe Core). It builds on Stories 2.1 (upload, wardrobe grid, 5-tab shell), 2.2 (bg removal, shimmer, polling, WardrobeItem model), 2.3 (categorization, taxonomy, category labels on grid), 2.4 (metadata editing, PATCH endpoint, ReviewItemScreen, taxonomy.dart, tag_cloud.dart), 2.5 (filtering, CachedNetworkImage, filter bar), and 2.6 (item detail, favorite, delete). Reuse everything established in those stories.
- The primary FRs covered are FR-WRD-14 (track `neglect_status` for items not worn in configurable days) and FR-WRD-15 (display "Neglected" badge). FR-WRD-10 also references filtering by `neglect status`, which this story fulfills.
- **Critical design decision: Wear logging does not exist yet.** Wear logging is introduced in Epic 5 (FR-LOG-*). The `wear_count` and `last_worn_date` columns are NOT on the items table yet (the WardrobeItem model has them as client-side fields defaulting to 0 / null, but the API does not return them). Therefore, for MVP, neglect detection uses `created_at` as the proxy date. ALL items older than 180 days will be marked as neglected, which is the correct behavior -- the user has never logged wearing them because the feature doesn't exist. When Epic 5 adds wear logging, the neglect computation in `mapItemRow` will automatically use `last_worn_date` if present, requiring NO code changes.
- **Computed vs stored field:** The `neglectStatus` is computed at read time in `mapItemRow`, NOT stored as a database column. This avoids the need for background jobs or triggers to keep the status current. The computation is simple date arithmetic and has negligible performance impact. A database column would require a scheduled job to update it daily, which adds unnecessary complexity for MVP.
- **Post-query filtering for neglect_status:** Since neglect is computed (not a column), the API cannot use a SQL WHERE clause for the neglect filter. Instead, when `neglect_status=neglected` is passed, the API fetches items (with all other SQL filters applied), maps them through `mapItemRow` (which computes neglectStatus), then filters the results in JavaScript. This is acceptable because: (a) the wardrobe is capped at ~200 items per user, and (b) the neglect filter is expected to be used infrequently. When Epic 5 adds `last_worn_date` and wear tracking, this could be optimized to a SQL WHERE clause if needed.
- **Badge positioning:** The wardrobe grid tile currently has badges at: top-right (orange warning for bg removal failure), top-left (blue info for categorization failure), and bottom-center full-width (category label). The neglect badge is placed at bottom-left as a small pill, which partially overlaps the category label. This is acceptable because: (a) both are semi-transparent/opaque containers, (b) the neglect badge is narrow and sits on the left edge, (c) the category label text typically starts from the left but has padding. If visual overlap is undesirable, the dev can offset the category label's left padding by the badge width.

### Project Structure Notes

- New files: None (all changes are to existing files)
- Modified files:
  - `apps/api/src/modules/items/repository.js` (add NEGLECT_THRESHOLD_DAYS constant, update mapItemRow with neglectStatus computation, add neglectStatus post-query filter to listItems)
  - `apps/api/src/modules/items/service.js` (accept and validate neglectStatus filter param)
  - `apps/api/src/main.js` (extract neglect_status query param)
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (add neglectStatus field, isNeglected getter)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add neglectStatus param to listItems)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (add neglect badge to grid tile, pass neglect filter to API)
  - `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` (add neglect indicator/banner)
  - `apps/mobile/lib/src/features/wardrobe/widgets/filter_bar.dart` (add Neglect filter dimension)
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (new neglect badge tests)
  - `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart` (new neglect indicator tests)
  - `apps/mobile/test/features/wardrobe/widgets/filter_bar_test.dart` (new neglect filter tests)
  - `apps/api/test/modules/items/service.test.js` (new neglect computation and filter tests)
  - `apps/api/test/items-endpoint.test.js` (new neglect endpoint tests)

### Technical Requirements

- The `NEGLECT_THRESHOLD_DAYS` constant is defined at the top of `repository.js` as `const NEGLECT_THRESHOLD_DAYS = 180;`. This is the single place to change the threshold.
- The `mapItemRow` function currently returns a plain object with all item fields. The neglectStatus computation adds one more field: `neglectStatus: computeNeglectStatus(row)`. Create a small helper function `computeNeglectStatus(row)` for clarity.
- The `computeNeglectStatus(row)` function logic:
  ```javascript
  function computeNeglectStatus(row) {
    const thresholdMs = NEGLECT_THRESHOLD_DAYS * 24 * 60 * 60 * 1000;
    const now = Date.now();

    // If wear data exists, use last_worn_date
    const wearCount = row.wear_count ?? 0;
    if (wearCount > 0 && row.last_worn_date) {
      const lastWorn = new Date(row.last_worn_date).getTime();
      return (now - lastWorn) > thresholdMs ? "neglected" : null;
    }

    // Fallback to created_at for items never worn
    if (row.created_at) {
      const created = new Date(row.created_at).getTime();
      return (now - created) > thresholdMs ? "neglected" : null;
    }

    return null;
  }
  ```
- For the `listItems` function, the post-query filter approach:
  ```javascript
  async listItems(authContext, { limit, category, color, season, occasion, brand, neglectStatus } = {}) {
    // ... existing SQL query (unchanged) ...
    const mappedItems = result.rows.map(mapItemRow);

    // Post-query filter for neglect status
    if (neglectStatus) {
      return mappedItems.filter(item => item.neglectStatus === neglectStatus);
    }
    return mappedItems;
  }
  ```
  Note: The existing `return result.rows.map(mapItemRow);` at the end of `listItems` is already mapping rows. The change is to capture the mapped result, optionally filter, then return.
- The `GET /v1/items` route in main.js adds: `const neglectStatus = url.searchParams.get("neglect_status");` and passes `neglectStatus: neglectStatus ?? undefined` to `listItemsForUser`.
- The mobile `WardrobeItem` constructor adds `this.neglectStatus` and parses it from JSON. The `isNeglected` getter is a simple equality check.
- The mobile `ApiClient.listItems` adds `String? neglectStatus` parameter and appends `neglect_status` to the query string.
- The `FilterBar` adds the "neglect" dimension. The options list for neglect is `["neglected"]` (just one option besides "All"). The display label "Neglected" comes from `taxonomyDisplayLabel("neglected")`.
- The wardrobe grid neglect badge should NOT show on processing/pending items to avoid visual clutter. Check `!item.isProcessing && !item.isCategorizationPending && item.isNeglected`.

### Architecture Compliance

- All data queries go through the Cloud Run API (architecture: "Cloud Run acts as the only public business API"). Neglect computation is server-side.
- RLS on `items` table ensures users only see their own items. No changes to RLS policy.
- No new database columns or migrations are needed. The `neglectStatus` is computed at read time from existing `created_at` (and future `last_worn_date` / `wear_count`).
- The mobile client owns presentation (badge rendering, filter UI). The API owns business logic (neglect computation, threshold).
- The neglect threshold is defined server-side (not client-side), ensuring consistent behavior across all clients.

### Library / Framework Requirements

- Mobile: No new dependencies. Uses existing packages: `cached_network_image`, `flutter/material.dart`, `http`.
- API: No new dependencies. Uses existing `pg` pool, Date arithmetic.

### File Structure Requirements

- No new files are created. All changes are modifications to existing files.
- No new API modules or directories.
- No new migrations (neglect status is computed, not stored).

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns in existing test files.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient.
- To test neglect computation, create test items with `created_at` dates more than 180 days ago and verify `neglectStatus: "neglected"` in the response. For items less than 180 days old, verify `neglectStatus: null`.
- To test the neglect filter, mock the API response to include both neglected and non-neglected items, then verify the filter shows only the correct subset.
- Target: all existing tests continue to pass (294 Flutter tests, 138 API tests from Story 2.6).

### Previous Story Intelligence

- Story 2.6 established: ItemDetailScreen with photo, stats row (wear count, CPW, last worn), metadata section, favorite toggle, delete with confirmation, edit navigation to ReviewItemScreen, tap handler on wardrobe grid tiles, DELETE /v1/items/:id endpoint, is_favorite column and PATCH support. 294 Flutter tests, 138 API tests.
- Story 2.5 established: FilterBar widget with 5 filter dimensions (category, color, season, occasion, brand), server-side filtering on GET /v1/items, CachedNetworkImage, item count display, filtered empty state. Key pattern: FilterBar accepts `activeFilters` map, `onFiltersChanged` callback, and `availableBrands`. Filter dimensions are defined in `_filterDimensions` list and `_dimensionLabels` map.
- Story 2.5 key learning: Used Icon-based radio indicators instead of deprecated Radio widget.
- Story 2.4 established: ReviewItemScreen, PATCH /v1/items/:id, taxonomy.dart with display labels.
- Story 2.4 key learning: `DropdownButtonFormField.value` deprecated in Flutter 3.33+.
- Story 2.3 established: Category labels on wardrobe grid tiles (Positioned bottom: 0, left: 0, right: 0).
- Story 2.2 established: Shimmer overlays, warning/info badges on grid tiles, polling, long-press context menus.
- Items table current columns after Story 2.6: `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `created_at`, `updated_at`. Note: NO `wear_count`, `last_worn_date`, or `neglect_status` columns exist.
- The `mapItemRow` function (repository.js line 1-26) maps database rows to API response objects. It already handles `is_favorite`. Adding `neglectStatus` follows the same pattern.
- The `listItems` method (repository.js line 282-338) currently returns `result.rows.map(mapItemRow)`. This is the integration point for post-query neglect filtering.
- The FilterBar (filter_bar.dart) uses `_filterDimensions` list and `_dimensionLabels` map. Adding a new dimension is a 2-line change plus updating `_getOptionsForDimension`.
- The `WardrobeItem` model (wardrobe_item.dart) already has `wearCount` (default 0) and `lastWornDate` (default null) from Story 2.6. Adding `neglectStatus` follows the same pattern.

### Key Anti-Patterns to Avoid

- DO NOT add a `neglect_status` column to the database. Neglect status is computed at read time, not stored. A stored column would require a scheduled background job to update daily, adding unnecessary complexity.
- DO NOT compute neglect status on the mobile client. The threshold and logic must be server-side to ensure consistency and configurability without app updates.
- DO NOT use a SQL WHERE clause for the neglect filter. Since neglect status is computed from `created_at` (and future `last_worn_date`), it cannot be filtered in SQL. Use post-query filtering in JavaScript.
- DO NOT hard-code the neglect threshold in multiple places. Define `NEGLECT_THRESHOLD_DAYS` once in repository.js.
- DO NOT change the position of existing badges on the wardrobe grid (warning badge top-right, info badge top-left, category label bottom-center). The neglect badge occupies a NEW position (bottom-left).
- DO NOT show the neglect badge on items that are still processing (bg removal pending, categorization pending). It adds visual clutter to items that are not yet fully set up.
- DO NOT break existing filter behavior. The neglect filter is additive -- it works alongside the existing 5 filters.
- DO NOT modify the `POST /v1/items`, `PATCH /v1/items/:id`, or `DELETE /v1/items/:id` endpoints. Only `GET /v1/items` (list) and `GET /v1/items/:id` (detail) are affected (via mapItemRow).
- DO NOT implement user-configurable neglect thresholds in this story. The threshold is a server-side constant. User-configurable thresholds are a future enhancement.

### Implementation Guidance

- **computeNeglectStatus helper:**
  ```javascript
  const NEGLECT_THRESHOLD_DAYS = 180;

  function computeNeglectStatus(row) {
    const thresholdMs = NEGLECT_THRESHOLD_DAYS * 24 * 60 * 60 * 1000;
    const now = Date.now();

    // Use last_worn_date if available (future Epic 5)
    const wearCount = row.wear_count ?? 0;
    if (wearCount > 0 && row.last_worn_date) {
      const lastWorn = new Date(row.last_worn_date).getTime();
      return (now - lastWorn) > thresholdMs ? "neglected" : null;
    }

    // Fallback: use created_at for items never worn
    if (row.created_at) {
      const created = new Date(row.created_at).getTime();
      return (now - created) > thresholdMs ? "neglected" : null;
    }

    return null;
  }
  ```

- **mapItemRow addition:**
  ```javascript
  function mapItemRow(row) {
    return {
      // ... existing fields ...
      isFavorite: row.is_favorite ?? false,
      neglectStatus: computeNeglectStatus(row),
      createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null
    };
  }
  ```

- **listItems post-query filter:**
  ```javascript
  async listItems(authContext, { limit, category, color, season, occasion, brand, neglectStatus } = {}) {
    // ... existing SQL query code (unchanged) ...

    const mappedItems = result.rows.map(mapItemRow);

    // Post-query filter for computed neglect status
    if (neglectStatus) {
      return mappedItems.filter(item => item.neglectStatus === neglectStatus);
    }

    return mappedItems;
  }
  ```
  Note: change the existing `return result.rows.map(mapItemRow);` to the above.

- **WardrobeItem model addition:**
  ```dart
  // In constructor:
  this.neglectStatus,

  // In fromJson:
  neglectStatus: json["neglectStatus"] as String? ?? json["neglect_status"] as String?,

  // Field:
  final String? neglectStatus;

  // Getter:
  bool get isNeglected => neglectStatus == "neglected";
  ```

- **ApiClient listItems update:**
  ```dart
  Future<Map<String, dynamic>> listItems({
    int? limit,
    String? category,
    String? color,
    String? season,
    String? occasion,
    String? brand,
    String? neglectStatus,
  }) async {
    final params = <String, String>{};
    // ... existing params ...
    if (neglectStatus != null) params["neglect_status"] = neglectStatus;
    // ... rest unchanged ...
  }
  ```

- **Wardrobe grid neglect badge:**
  ```dart
  // In _buildItemTile, inside the Stack children list, after the category label:
  if (!item.isProcessing && !item.isCategorizationPending && item.isNeglected)
    Positioned(
      bottom: 0,
      left: 0,
      child: Semantics(
        label: "Neglected item",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: const BoxDecoration(
            color: Color(0xFFF59E0B),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, color: Colors.white, size: 10),
              SizedBox(width: 2),
              Text(
                "Neglected",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ```

- **ItemDetailScreen neglect banner:**
  ```dart
  // Below the photo, before or within the stats row:
  if (_item.isNeglected)
    Semantics(
      label: "This item is neglected",
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "This item has been neglected \u2014 consider wearing or decluttering it",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  ```

- **FilterBar neglect dimension:**
  ```dart
  // In _filterDimensions list:
  const List<String> _filterDimensions = [
    "category", "color", "season", "occasion", "brand", "neglect",
  ];

  // In _dimensionLabels map:
  const Map<String, String> _dimensionLabels = {
    "category": "Category",
    "color": "Color",
    "season": "Season",
    "occasion": "Occasion",
    "brand": "Brand",
    "neglect": "Neglect",
  };

  // In _getOptionsForDimension:
  case "neglect":
    return ["neglected"];
  ```

- **WardrobeScreen filter passthrough:**
  ```dart
  // In _loadItems, update apiClient.listItems calls:
  widget.apiClient.listItems(
    category: _activeFilters["category"],
    color: _activeFilters["color"],
    season: _activeFilters["season"],
    occasion: _activeFilters["occasion"],
    brand: _activeFilters["brand"],
    neglectStatus: _activeFilters["neglect"],
  ),
  ```

### References

- [Source: epics.md - Story 2.7: Neglect Detection & Badging]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: prd.md - FR-WRD-14: The system shall track `neglect_status` for items not worn in a configurable number of days (default: 180)]
- [Source: prd.md - FR-WRD-15: The system shall display a "Neglected" badge on items exceeding the neglect threshold]
- [Source: prd.md - FR-WRD-10: The wardrobe gallery shall support filtering by: category, color, season, occasion, brand, neglect status, resale status]
- [Source: architecture.md - Server authority for sensitive rules: subscription gating, usage counters, badge grants]
- [Source: architecture.md - Optimistic UI is allowed for wear logging, badge/streak feedback]
- [Source: ux-design-specification.md - Touch targets at least 44x44 points (WCAG AA)]
- [Source: ux-design-specification.md - Semantics widget for screen reader support]
- [Source: 2-6-item-detail-view-management.md - ItemDetailScreen, stats row, favorite toggle, delete, metadata section]
- [Source: 2-5-wardrobe-grid-filtering.md - FilterBar, server-side filtering, CachedNetworkImage]
- [Source: 2-3-ai-item-categorization-tagging.md - Category labels on grid, badge positions]
- [Source: 2-2-ai-background-removal-upload.md - Shimmer overlay, warning badge position, polling]
- [Source: 2-1-upload-item-photo-camera-gallery.md - WardrobeScreen grid, ApiClient]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (Amelia, Senior Software Engineer)

### Debug Log References

- Story drafted by SM agent (Bob/Claude Opus 4.6) from epics.md, architecture.md, ux-design-specification.md, prd.md (FR-WRD-14, FR-WRD-15, FR-WRD-10), and Stories 2.1-2.6 implementation artifacts.
- Codebase analysis performed: read existing wardrobe_screen.dart (642 lines with shimmer, polling, badges, category labels, filter bar, tap navigation), item_detail_screen.dart (stats row, metadata, favorite, delete), filter_bar.dart (5 dimensions, bottom sheet, taxonomy labels), wardrobe_item.dart (161 lines with isFavorite, wearCount, lastWornDate, costPerWear), api_client.dart (335 lines with listItems supporting 5 filter params), items/repository.js (341 lines with mapItemRow, listItems with dynamic WHERE), items/service.js (273 lines with filter validation), main.js (GET /v1/items with searchParams extraction), taxonomy.dart (57 lines with all taxonomy constants).
- Key design decision: neglect status is computed server-side at read time (not stored), using `created_at` as proxy until wear logging (Epic 5) adds `last_worn_date`.

### Completion Notes List

- Tasks 1-6 (API neglect computation, service validation, main.js param extraction, WardrobeItem model, ApiClient, wardrobe grid badge, ItemDetailScreen banner) were already implemented by a prior agent session.
- This session implemented Tasks 7-8 (FilterBar "neglect" dimension, WardrobeScreen filter passthrough) and all test tasks (9-12).
- Task 7: Added "neglect" to `_filterDimensions` and `_dimensionLabels`, added `"neglect"` case to `_getOptionsForDimension` returning `["neglected"]`.
- Task 8: Updated both `_loadItems()` and `_pollForUpdates()` to pass `neglectStatus: _activeFilters["neglect"]` to `apiClient.listItems()`.
- Task 9: 4 wardrobe screen tests (badge shown for neglected, NOT shown for null, Semantics label, NOT shown on processing items).
- Task 10: 4 item detail screen tests (banner shown for neglected, NOT shown for null, metadata row shows "Neglected", metadata row shows "Active").
- Task 11: 3 filter bar tests (bottom sheet options, onFiltersChanged callback, Semantics label).
- Task 12: 4 service tests + 4 endpoint tests for neglect computation and filtering.
- Task 13: `flutter analyze` -- 0 issues. `flutter test` -- 305 pass, 0 fail. `npm --prefix apps/api test` -- 146 pass, 0 fail.
- No issues encountered.

### File List

**Modified files:**
- `apps/api/src/modules/items/repository.js` -- NEGLECT_THRESHOLD_DAYS constant, computeNeglectStatus helper, mapItemRow neglectStatus field, listItems post-query filter (pre-existing from prior session)
- `apps/api/src/modules/items/service.js` -- neglectStatus validation in listItemsForUser (pre-existing from prior session)
- `apps/api/src/main.js` -- neglect_status query param extraction (pre-existing from prior session)
- `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` -- neglectStatus field, isNeglected getter (pre-existing from prior session)
- `apps/mobile/lib/src/core/networking/api_client.dart` -- neglectStatus param in listItems (pre-existing from prior session)
- `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` -- neglect badge on grid tiles (pre-existing), neglect filter passthrough in _loadItems and _pollForUpdates (this session)
- `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` -- neglect banner and metadata row (pre-existing from prior session)
- `apps/mobile/lib/src/features/wardrobe/widgets/filter_bar.dart` -- "neglect" dimension in _filterDimensions, _dimensionLabels, _getOptionsForDimension (this session)
- `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` -- 4 new neglect badge tests (this session)
- `apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart` -- 4 new neglect indicator tests (this session)
- `apps/mobile/test/features/wardrobe/widgets/filter_bar_test.dart` -- 3 new neglect filter tests, updated chip count assertion from 5 to 6 (this session)
- `apps/api/test/modules/items/service.test.js` -- 4 new neglect computation and filter tests (this session)
- `apps/api/test/items-endpoint.test.js` -- 4 new neglect endpoint tests (this session)

## Change Log

- 2026-03-11: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, UX specification, PRD requirements (FR-WRD-14, FR-WRD-15, FR-WRD-10), and Stories 2.1-2.6 implementation context.
