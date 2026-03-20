# Story 2.5: Wardrobe Grid & Filtering

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to browse my wardrobe in a grid and filter by various attributes,
so that I can easily find specific pieces when I have many items.

## Acceptance Criteria

1. Given I have items in my digital wardrobe, when I view the Wardrobe tab, then I see my items in a fast, scrollable gallery grid with cached images for smooth scrolling (FR-WRD-09, NFR-PERF-07).
2. Given I am on the Wardrobe tab, when I look at the area above the grid, then I see a horizontally scrollable row of filter chips for: Category, Color, Season, Occasion, and Brand.
3. Given I tap a filter chip (e.g., "Category"), when the chip expands or a bottom sheet opens, then I see all valid taxonomy values for that filter dimension (e.g., all valid categories), plus an "All" option to clear the filter.
4. Given I have selected a filter (e.g., category = "tops"), when the grid refreshes, then only items matching the selected filter value are displayed, and the active filter chip is visually highlighted (filled/selected state).
5. Given I have applied multiple filters simultaneously (e.g., category = "tops" AND color = "black"), when the grid refreshes, then only items matching ALL active filters are displayed (AND logic).
6. Given I have active filters, when I tap the highlighted chip again or tap "All" within that filter's options, then that filter is cleared and the grid shows the broader result set.
7. Given I have active filters, when I see the filter bar, then a "Clear All" action is visible that removes all active filters and restores the full wardrobe view.
8. Given I apply filters, when the grid updates, then an item count label is visible showing "X items" (or "X of Y items" when filtered) so the user knows how many items match.
9. Given filters are applied and no items match, when the grid is empty, then a friendly empty state is shown: "No items match your filters" with a "Clear Filters" button.
10. Given the API supports server-side filtering, when the mobile client requests filtered items via `GET /v1/items?category=tops&color=black`, then the API returns only matching items efficiently using SQL WHERE clauses with indexed columns.
11. Given I am on the Wardrobe tab, when I scroll through many items, then images are loaded lazily and cached locally for smooth performance (using Flutter's built-in `Image.network` caching or `CachedNetworkImage`).
12. Given the wardrobe grid is displayed, when items have a category label at the bottom, then the existing category label overlay from Story 2.3 continues to display correctly alongside the new filter UI.

## Tasks / Subtasks

- [x] Task 1: API - Add server-side filtering to GET /v1/items (AC: 10)
  - [x] 1.1: Update `listItems` in `apps/api/src/modules/items/repository.js` to accept optional filter parameters: `category`, `color`, `season`, `occasion`, `brand`. Build dynamic WHERE clauses: scalar fields use `= $N`, array fields (`season`, `occasion`) use `$N = ANY(column_name)`. Ensure all filter values are parameterized (no SQL injection).
  - [x] 1.2: Update `listItemsForUser` in `apps/api/src/modules/items/service.js` to pass filter parameters from options to the repository. Validate filter values against the taxonomy constants from `taxonomy.js` before passing to the repository -- reject invalid values with 400 status.
  - [x] 1.3: Update the `GET /v1/items` route handler in `apps/api/src/main.js` to extract filter query parameters from `url.searchParams`: `category`, `color`, `season`, `occasion`, `brand`. Pass them to `listItemsForUser`. Example: `GET /v1/items?category=tops&color=black&season=winter`.
  - [x] 1.4: Create `infra/sql/migrations/010_items_filter_indexes.sql`: Add indexes on commonly filtered columns for performance: `CREATE INDEX idx_items_category ON app_public.items(category)` (if not already from Story 2.3), `CREATE INDEX idx_items_color ON app_public.items(color)`, `CREATE INDEX idx_items_brand ON app_public.items(brand)`. For array columns (`season`, `occasion`), add GIN indexes: `CREATE INDEX idx_items_season ON app_public.items USING gin(season)`, `CREATE INDEX idx_items_occasion ON app_public.items USING gin(occasion)`.

- [x] Task 2: Mobile - Update ApiClient to support filter parameters (AC: 10)
  - [x] 2.1: Update `listItems` in `apps/mobile/lib/src/core/networking/api_client.dart` to accept optional named parameters: `String? category`, `String? color`, `String? season`, `String? occasion`, `String? brand`. Build query string by appending non-null parameters to the URL path. Example: `/v1/items?category=tops&color=black`.

- [x] Task 3: Mobile - Create FilterBar widget (AC: 2, 3, 4, 5, 6, 7)
  - [x] 3.1: Create `apps/mobile/lib/src/features/wardrobe/widgets/filter_bar.dart` as a `StatelessWidget`. It displays a horizontal scrollable row (`SingleChildScrollView` with `Row`) of `FilterChip` or `ChoiceChip` widgets for each filter dimension: Category, Color, Season, Occasion, Brand. Include a "Clear All" action (small TextButton or IconButton with `Icons.clear_all`) that is only visible when any filter is active.
  - [x] 3.2: Each chip shows the dimension label (e.g., "Category") when no filter is active for that dimension. When a filter is active, the chip shows the selected value (e.g., "Tops") and is visually highlighted (filled background using primary color `#4F46E5`, white text).
  - [x] 3.3: When a chip is tapped, show a `showModalBottomSheet` listing all valid options for that dimension (import from `taxonomy.dart`). For Brand, show a dynamically populated list from the current wardrobe items (extract unique brands from the items list). Include an "All" option at the top to clear that specific filter. Use `ListTile` with radio-style selection for single-select filters (category, color, brand) and checkbox-style for multi-select if needed in future (season, occasion -- but for MVP, use single-select for simplicity).
  - [x] 3.4: The widget accepts: `Map<String, String?> activeFilters`, `ValueChanged<Map<String, String?>> onFiltersChanged`, and `List<String> availableBrands` (derived from the unfiltered item list). Each filter key is one of: `category`, `color`, `season`, `occasion`, `brand`.
  - [x] 3.5: All chips and the bottom sheet options must have `Semantics` labels. Touch targets must be at least 44x44 points (WCAG AA compliance per UX spec).

- [x] Task 4: Mobile - Integrate filtering into WardrobeScreen (AC: 1, 4, 5, 6, 7, 8, 9, 11, 12)
  - [x] 4.1: Refactor `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` to manage filter state. Add a `Map<String, String?> _activeFilters = {}` state variable. When filters change, call `_loadItems()` with the active filters.
  - [x] 4.2: Place the `FilterBar` widget between the AppBar and the `GridView` in the body. Use a `Column` with the `FilterBar` at the top (fixed, not scrolling with the grid) and the grid in an `Expanded` widget below.
  - [x] 4.3: Update `_loadItems()` to pass active filters to `apiClient.listItems(category: ..., color: ..., ...)`. This ensures filtering is done server-side for efficiency with large wardrobes.
  - [x] 4.4: Add an item count display. Show "X items" below the filter bar (or in the AppBar subtitle) when unfiltered, and "X of Y items" when filters are active. Track `_totalItemCount` separately from the filtered list.
  - [x] 4.5: When filters are active and no items match, show the filtered empty state: "No items match your filters" with a "Clear Filters" button that resets `_activeFilters` and reloads.
  - [x] 4.6: Extract unique brand values from the full (unfiltered) item list to pass to `FilterBar.availableBrands`. Cache this list and refresh it when the wardrobe is refreshed (not on every filter change). Load the unfiltered list once to get total count and brands, then apply server-side filters for the displayed results.
  - [x] 4.7: Ensure existing functionality is preserved: shimmer overlays for pending bg removal/categorization, warning/info badges for failed items, category labels on completed items, long-press context menus for retries, and polling for pending items.

- [x] Task 5: Mobile - Image caching for smooth grid scrolling (AC: 1, 11)
  - [x] 5.1: Add `cached_network_image: ^3.4.1` to `apps/mobile/pubspec.yaml`. This provides disk-cached image loading with placeholder and error widgets, significantly improving scroll performance for large wardrobes.
  - [x] 5.2: Replace `Image.network` in the `_buildItemTile` method with `CachedNetworkImage(imageUrl: item.photoUrl, fit: BoxFit.cover, placeholder: ..., errorWidget: ...)`. Use a subtle gray placeholder container during loading. Keep the same error builder (gray container with image icon).
  - [x] 5.3: Alternatively, if avoiding a new dependency is preferred, use Flutter's built-in `Image.network` with `cacheWidth` and `cacheHeight` parameters for memory-efficient rendering, and rely on Flutter's default HTTP cache. The `CachedNetworkImage` approach is recommended for production quality but the built-in approach is acceptable.

- [x] Task 6: Widget tests for FilterBar (AC: 2, 3, 4, 5, 6, 7)
  - [x] 6.1: Create `apps/mobile/test/features/wardrobe/widgets/filter_bar_test.dart`:
    - FilterBar renders all 5 filter chips (Category, Color, Season, Occasion, Brand).
    - Tapping a chip opens a bottom sheet with valid options from taxonomy.
    - Selecting an option calls `onFiltersChanged` with the updated filter map.
    - Active filter chips show the selected value and are visually highlighted.
    - Tapping "All" in the bottom sheet clears that filter.
    - "Clear All" button appears when filters are active and clears all filters.
    - "Clear All" button is hidden when no filters are active.
    - Semantics labels are present on all chips.

- [x] Task 7: Widget tests for updated WardrobeScreen (AC: 1, 4, 5, 8, 9, 11, 12)
  - [x] 7.1: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`:
    - FilterBar is rendered above the grid.
    - Applying a filter calls `apiClient.listItems` with the filter parameter.
    - Item count label shows correct count.
    - Filtered empty state shows "No items match your filters" with "Clear Filters" button.
    - "Clear Filters" button resets filters and reloads items.
    - Existing tests continue to pass (shimmer, badges, polling, empty state, error state).
    - CachedNetworkImage (or Image.network) renders in grid cells.

- [x] Task 8: API tests for server-side filtering (AC: 10)
  - [x] 8.1: Update or create tests in `apps/api/test/modules/items/service.test.js`:
    - `listItemsForUser` passes filter params to repository.
    - Invalid taxonomy filter values return 400 error.
    - Brand filter is passed through without taxonomy validation (it's user-entered data).
  - [x] 8.2: Update `apps/api/test/items-endpoint.test.js`:
    - `GET /v1/items?category=tops` returns only items with category = "tops".
    - `GET /v1/items?category=tops&color=black` returns items matching both.
    - `GET /v1/items?season=winter` returns items where "winter" is in the season array.
    - `GET /v1/items?brand=Nike` returns items with brand = "Nike" (case-sensitive).
    - `GET /v1/items?category=invalid` returns 400 error.
    - `GET /v1/items` without filters returns all items (existing behavior preserved).

- [x] Task 9: Regression testing (AC: all)
  - [x] 9.1: Run `flutter analyze` -- zero issues.
  - [x] 9.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 9.3: Run `npm --prefix apps/api test` -- all existing + new tests pass.
  - [x] 9.4: Verify existing AddItemScreen upload flow still works end-to-end.
  - [x] 9.5: Verify `GET /v1/items` without query params returns all items (backward compatibility).
  - [x] 9.6: Verify polling still works for pending bg removal / categorization items when filters are active.

## Dev Notes

- This is the FIFTH story in Epic 2 (Digital Wardrobe Core). It builds on Stories 2.1 (upload, wardrobe grid, 5-tab shell), 2.2 (bg removal, shimmer, polling, WardrobeItem model), 2.3 (categorization, taxonomy, category labels on grid), and 2.4 (metadata editing, PATCH endpoint, ReviewItemScreen, taxonomy.dart, tag_cloud.dart). Reuse everything established in those stories.
- The primary FRs covered are FR-WRD-09 (scrollable gallery grid) and FR-WRD-10 (filtering by category, color, season, occasion, brand). FR-WRD-10 also mentions filtering by `neglect_status` and `resale_status`, but those features are introduced in Stories 2.7 and Epic 7 respectively. Do NOT add neglect/resale filters in this story.
- The UX design spec emphasizes using a "flat tag/filter system" instead of hierarchical folder structures. The horizontal chip bar is the ideal pattern -- it's compact, scannable, and follows Material Design FilterChip conventions.
- Server-side filtering is strongly preferred over client-side filtering because the wardrobe can grow to hundreds of items. The API already supports a `limit` query parameter on `GET /v1/items`; this story extends it with filter parameters.
- The `listItems` repository method currently only supports `limit`. This story extends it with WHERE clauses for filter parameters. The dynamic query building follows the same pattern as `updateItem` -- build clauses and parameter arrays dynamically.
- For array columns (`season`, `occasion`), PostgreSQL's `ANY()` operator is the correct approach: `WHERE $1 = ANY(season)` checks if the filter value is contained in the array column. For GIN-indexed arrays, this is performant.
- The brand filter does NOT validate against a fixed taxonomy (unlike category, color, etc.) because brand is user-entered freeform text. Instead, the mobile client derives the available brands from the user's existing items.

### Project Structure Notes

- New files:
  - `apps/mobile/lib/src/features/wardrobe/widgets/filter_bar.dart`
  - `apps/mobile/test/features/wardrobe/widgets/filter_bar_test.dart`
  - `infra/sql/migrations/010_items_filter_indexes.sql`
- Modified files:
  - `apps/api/src/modules/items/repository.js` (add filter support to listItems)
  - `apps/api/src/modules/items/service.js` (validate and pass filter params)
  - `apps/api/src/main.js` (extract filter query params from URL)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add filter params to listItems)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (add FilterBar, filter state, item count, image caching)
  - `apps/mobile/pubspec.yaml` (add cached_network_image dependency)
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`
  - `apps/api/test/modules/items/service.test.js`
  - `apps/api/test/items-endpoint.test.js`

### Technical Requirements

- The `GET /v1/items` endpoint currently handles query params via `url.searchParams.get("limit")`. Extend this to also extract `category`, `color`, `season`, `occasion`, `brand`. All are optional string parameters.
- SQL for filtering scalars: `AND i.category = $N` (when category filter is provided). SQL for filtering arrays: `AND $N = ANY(i.season)` (when season filter is provided).
- PostgreSQL GIN indexes for array columns enable efficient `ANY()` lookups. B-tree indexes on scalar columns (`category`, `color`, `brand`) enable efficient equality checks.
- The `cached_network_image` package (^3.4.1) depends on `flutter_cache_manager` internally. It provides disk caching with configurable max age and cache size. No additional configuration is needed for basic usage.
- FilterChip or ChoiceChip from Material Design is the correct widget choice. Use `FilterChip(selected: isActive, label: Text(...), onSelected: ...)` for each dimension.

### Architecture Compliance

- All data queries go through the Cloud Run API (architecture: "Cloud Run acts as the only public business API"). Filtering is server-side, not client-side.
- RLS on `items` table ensures users only see their own items. The existing `listItems` query already joins on `profiles.firebase_uid`.
- Filter parameters are validated server-side against the taxonomy before being used in queries.
- The mobile client owns presentation and local state (filter selections). The API owns query logic and data access.
- New indexes are additive and do not break existing functionality.

### Library / Framework Requirements

- Mobile new dependency: `cached_network_image: ^3.4.1` for disk-cached image loading in the grid. This is the most widely used Flutter image caching package (10K+ pub.dev likes). If the team prefers zero new dependencies, use Flutter's built-in `Image.network` with `cacheWidth`/`cacheHeight` instead.
- API: No new dependencies. Uses existing `pg`, taxonomy constants from `taxonomy.js`.
- Mobile existing dependencies used: `http` (API calls), `image_picker` (not directly in this story), `flutter/material.dart` (FilterChip, ChoiceChip, showModalBottomSheet).

### File Structure Requirements

- The `filter_bar.dart` widget lives in `apps/mobile/lib/src/features/wardrobe/widgets/` alongside existing `tag_cloud.dart` and `tag_selection_sheet.dart`.
- Migration file follows sequential numbering: 010 (after existing 009_items_optional_metadata.sql).
- No new API modules or directories. Changes are to existing items module files.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns in existing `apps/api/test/modules/items/service.test.js` and `apps/api/test/items-endpoint.test.js`.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient.
- Test filter combinations: single filter, multiple filters, clear individual filter, clear all filters, invalid filter value (API), empty results.
- Target: all existing tests continue to pass (263 Flutter tests, 114 API tests from Story 2.4).

### Previous Story Intelligence

- Story 2.4 established: ReviewItemScreen with Tag Cloud editing, PATCH /v1/items/:id endpoint, GET /v1/items/:id endpoint, taxonomy.dart with `validCategories`/`validColors`/etc. constants and `taxonomyDisplayLabel()` helper, TagCloud and TagSelectionSheet reusable widgets, `WardrobeItem.toJson()`. 263 Flutter tests, 114 API tests.
- Story 2.4 key learning: The `DropdownButtonFormField.value` parameter was deprecated in Flutter 3.33+; use `initialValue` instead. Keep this in mind for any dropdown/selection widgets.
- Story 2.3 established: AI categorization pipeline, taxonomy constants in `apps/api/src/modules/ai/taxonomy.js` (shared module), categorization_status field, category label chips on wardrobe grid, extended polling for both bg removal and categorization pending items. `WardrobeItem` model with `isCategorizationPending/Failed/Completed` getters and `displayLabel` getter.
- Story 2.2 established: Shimmer overlay using `AnimationController` + `ShaderMask` (the `_ShimmerOverlay` private widget in wardrobe_screen.dart), polling with `Timer.periodic(Duration(seconds: 3))` capped at 10 retries, long-press context menu for failed items.
- Story 2.1 established: `MainShellScreen` with 5-tab navigation, `WardrobeScreen` with basic `GridView.builder` (2 columns, 8px spacing), `AddItemScreen` with camera/gallery, `ApiClient.listItems()` with optional `limit` parameter.
- Items table current columns after Story 2.4: `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `created_at`, `updated_at`.
- The existing `listItems` repository method (line 243 of repository.js) accepts `{ limit }` options and builds a simple SELECT with ORDER BY `created_at desc`. This story extends it with dynamic WHERE clauses.

### Key Anti-Patterns to Avoid

- DO NOT filter client-side by downloading all items and filtering in Dart. Use server-side filtering via query parameters for scalability.
- DO NOT add neglect_status or resale_status filters in this story. Those features do not exist yet (Stories 2.7 and Epic 7).
- DO NOT create a new API endpoint for filtered items. Extend the existing `GET /v1/items` with query parameters.
- DO NOT use a search bar for filtering. Use the chip/filter bar pattern per the UX design spec's recommendation of a "flat tag/filter system."
- DO NOT break the existing wardrobe grid UI. The shimmer overlays, warning/info badges, category labels, and long-press context menus from Stories 2.2-2.3 must all continue to work.
- DO NOT change the `POST /v1/items`, `PATCH /v1/items/:id`, or `GET /v1/items/:id` endpoints. Only `GET /v1/items` (list) is modified.
- DO NOT validate the `brand` filter against a taxonomy. Brand is user-entered freeform text, not a fixed taxonomy. Accept any string for brand filtering.
- DO NOT use `LIKE` or `ILIKE` for filter matching. Use exact equality (`=`) for scalar filters and `= ANY()` for array filters. Fuzzy search is out of scope.
- DO NOT remove the existing `limit` query parameter support. It should continue to work alongside the new filter parameters.

### Implementation Guidance

- **Repository filter query building:**
  ```javascript
  async listItems(authContext, { limit, category, color, season, occasion, brand } = {}) {
    // ... existing setup ...
    const whereClauses = ["p.firebase_uid = $1"];
    const values = [authContext.userId];
    let paramIndex = 2;

    if (category) {
      whereClauses.push(`i.category = $${paramIndex++}`);
      values.push(category);
    }
    if (color) {
      whereClauses.push(`i.color = $${paramIndex++}`);
      values.push(color);
    }
    if (season) {
      whereClauses.push(`$${paramIndex++} = ANY(i.season)`);
      values.push(season);
    }
    if (occasion) {
      whereClauses.push(`$${paramIndex++} = ANY(i.occasion)`);
      values.push(occasion);
    }
    if (brand) {
      whereClauses.push(`i.brand = $${paramIndex++}`);
      values.push(brand);
    }

    const queryLimit = limit && Number.isInteger(limit) && limit > 0 ? limit : 200;
    values.push(queryLimit);

    const result = await client.query(
      `SELECT i.* FROM app_public.items i
       JOIN app_public.profiles p ON p.id = i.profile_id
       WHERE ${whereClauses.join(" AND ")}
       ORDER BY i.created_at DESC
       LIMIT $${paramIndex}`,
      values
    );
  }
  ```
  Note: Increase the default limit from 50 to 200 for the wardrobe grid view to accommodate larger wardrobes.

- **ApiClient filter params:**
  ```dart
  Future<Map<String, dynamic>> listItems({
    int? limit,
    String? category,
    String? color,
    String? season,
    String? occasion,
    String? brand,
  }) async {
    final params = <String, String>{};
    if (limit != null) params["limit"] = limit.toString();
    if (category != null) params["category"] = category;
    if (color != null) params["color"] = color;
    if (season != null) params["season"] = season;
    if (occasion != null) params["occasion"] = occasion;
    if (brand != null) params["brand"] = brand;

    final query = params.isNotEmpty
        ? "?${params.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&")}"
        : "";
    return _authenticatedGet("/v1/items$query");
  }
  ```

- **FilterBar widget structure:**
  ```dart
  class FilterBar extends StatelessWidget {
    const FilterBar({
      required this.activeFilters,
      required this.onFiltersChanged,
      required this.availableBrands,
      super.key,
    });
    final Map<String, String?> activeFilters;
    final ValueChanged<Map<String, String?>> onFiltersChanged;
    final List<String> availableBrands;
  }
  ```

- **WardrobeScreen layout change:**
  Replace the current `Padding > GridView.builder` body with:
  ```dart
  Column(
    children: [
      FilterBar(activeFilters: _activeFilters, onFiltersChanged: _onFiltersChanged, availableBrands: _availableBrands),
      Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text("$_displayedCount items")),
      Expanded(child: Padding(padding: EdgeInsets.all(8), child: GridView.builder(...))),
    ],
  )
  ```

- **Filter bottom sheet options:** Import `validCategories`, `validColors`, etc. from `taxonomy.dart`. For the brand filter, derive the list from `_allItems.map((i) => i.brand).whereType<String>().toSet().toList()..sort()`. Use `taxonomyDisplayLabel()` for displaying taxonomy values in title case.

### References

- [Source: epics.md - Story 2.5: Wardrobe Grid & Filtering]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: prd.md - FR-WRD-09: Users shall view their wardrobe in a scrollable gallery grid]
- [Source: prd.md - FR-WRD-10: The wardrobe gallery shall support filtering by: category, color, season, occasion, brand, neglect status, resale status]
- [Source: prd.md - NFR-PERF-07: Wardrobe gallery initial render]
- [Source: architecture.md - Cached local data supports wardrobe browsing]
- [Source: architecture.md - Mobile Client: portrait-only, tablet may scale grid density]
- [Source: architecture.md - Project Structure: mobile/features/wardrobe, api/modules/wardrobe]
- [Source: ux-design-specification.md - Avoid complex hierarchical folder structures. Use a flat tag/filter system instead.]
- [Source: ux-design-specification.md - Pinterest visual grid for wardrobe browsing]
- [Source: ux-design-specification.md - Touch targets at least 44x44 points (WCAG AA)]
- [Source: ux-design-specification.md - Semantics widget for screen reader support]
- [Source: 2-4-manual-metadata-editing-creation.md - taxonomy.dart, tag_cloud.dart, PATCH endpoint, ReviewItemScreen]
- [Source: 2-3-ai-item-categorization-tagging.md - Category labels on grid, taxonomy constants, categorization status]
- [Source: 2-2-ai-background-removal-upload.md - Shimmer overlay, polling pattern, WardrobeItem model]
- [Source: 2-1-upload-item-photo-camera-gallery.md - WardrobeScreen grid, MainShellScreen, ApiClient.listItems]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Story drafted by SM agent (Bob/Claude Opus 4.6) from epics.md, architecture.md, ux-design-specification.md, prd.md, and Stories 2.1-2.4 implementation artifacts.
- Codebase analysis performed: read existing wardrobe_screen.dart (469 lines with shimmer, polling, badges, category labels), api_client.dart (310 lines with listItems method accepting limit param), items/repository.js (275 lines with listItems query), items/service.js (219 lines with listItemsForUser), main.js (GET /v1/items route with limit search param), wardrobe_item.dart (135 lines with full model), taxonomy.dart (57 lines with all taxonomy constants).

### Completion Notes List

- All 9 tasks completed. 280 Flutter tests passing (17 new), 127 API tests passing (13 new).
- Used Icon-based radio indicators instead of deprecated Radio widget (groupValue/onChanged deprecated in Flutter 3.33+).
- Used CachedNetworkImage for disk-cached image loading in the wardrobe grid.
- Fixed 2 existing tests that used `find.byType(GestureDetector).first` which broke when FilterBar added more GestureDetectors to the tree; switched to Semantics-based finders.
- Default listItems limit increased from 50 to 200 per story guidance.

### File List

**New files:**
- `apps/mobile/lib/src/features/wardrobe/widgets/filter_bar.dart`
- `apps/mobile/test/features/wardrobe/widgets/filter_bar_test.dart`
- `infra/sql/migrations/010_items_filter_indexes.sql`

**Modified files:**
- `apps/api/src/modules/items/repository.js` (dynamic WHERE clauses for filters)
- `apps/api/src/modules/items/service.js` (filter validation against taxonomy)
- `apps/api/src/main.js` (extract filter query params from URL)
- `apps/mobile/lib/src/core/networking/api_client.dart` (filter params on listItems)
- `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (FilterBar, filter state, item count, CachedNetworkImage, filtered empty state)
- `apps/mobile/pubspec.yaml` (added cached_network_image dependency)
- `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (7 new tests, 2 fixed existing tests)
- `apps/api/test/modules/items/service.test.js` (7 new filter tests)
- `apps/api/test/items-endpoint.test.js` (6 new endpoint filter tests)

## Change Log

- 2026-03-11: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, UX specification, PRD requirements, and Stories 2.1-2.4 implementation context.
- 2026-03-11: Implementation completed by Dev Agent (Amelia/Claude Opus 4.6). All 9 tasks done. 280 Flutter tests (17 new), 127 API tests (13 new). Status -> review.
