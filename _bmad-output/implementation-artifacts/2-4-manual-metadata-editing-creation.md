# Story 2.4: Manual Metadata Editing & Item Creation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to review and edit the AI-generated tags and add custom details (name, brand, purchase price, purchase date),
so that my item records are perfectly accurate and complete before saving.

## Acceptance Criteria

1. Given the AI has categorized my new item (or categorization is still pending/failed), when the AddItemScreen upload completes, then I am navigated to a "Review Item" screen instead of popping back to the wardrobe grid.
2. Given I am on the Review Item screen, when it loads, then I see the item photo at the top, and below it a Tag Cloud UI showing all AI-assigned metadata as selectable chips: category, color, secondary colors, pattern, material, style, season (multi-select), and occasion (multi-select).
3. Given AI-assigned tags are displayed as chips, when I tap a chip, then a bottom sheet opens showing all valid taxonomy values for that field, with the current value pre-selected, allowing me to change the selection.
4. Given I am on the Review Item screen, when I scroll down, then I see text input fields for optional metadata: item name (max 200 chars), brand (max 100 chars), purchase price (numeric), purchase date (date picker), and currency (dropdown: GBP, EUR, USD, default GBP).
5. Given I have made my edits (or accepted the AI defaults), when I tap "Save Item", then the app calls `PATCH /v1/items/:id` with all metadata fields and navigates back to the wardrobe grid, triggering a refresh.
6. Given categorization is still pending when I reach the Review Item screen, when the screen loads, then AI tag chips show shimmer placeholders, and the screen polls for categorization completion, populating chips when data arrives.
7. Given categorization failed, when the Review Item screen loads, then all tag chips show their safe default values (category: other, color: unknown, etc.) and a subtle banner says "AI couldn't identify this item -- please set the details manually."
8. Given I am on the wardrobe grid and tap an existing item, when the item detail view opens (Story 2.6 future), then the same Tag Cloud editing UI is reusable for editing existing items via `PATCH /v1/items/:id`. (NOTE: The editing widget must be built as a reusable component for this future use.)
9. Given the API receives a `PATCH /v1/items/:id` request, when it processes the body, then it validates all taxonomy fields against the fixed taxonomy (same validation as categorization service), validates optional fields (name max 200 chars, brand max 100 chars, purchase_price >= 0, currency in allowed list), and returns 400 with specific error messages for invalid values.
10. Given I save the item, when the API updates the record, then `updated_at` is set to NOW() and all provided fields are persisted atomically.

## Tasks / Subtasks

- [x] Task 1: Database migration for optional metadata columns (AC: 4, 5, 10)
  - [x] 1.1: Create `infra/sql/migrations/009_items_optional_metadata.sql`: ALTER TABLE `app_public.items` ADD COLUMN `brand` TEXT DEFAULT NULL, ADD COLUMN `purchase_price` NUMERIC(10,2) DEFAULT NULL, ADD COLUMN `purchase_date` DATE DEFAULT NULL, ADD COLUMN `currency` TEXT DEFAULT 'GBP' CHECK (currency IS NULL OR currency IN ('GBP', 'EUR', 'USD')). Add SQL comments on each new column.
  - [x] 1.2: Add CHECK constraint on `purchase_price`: `purchase_price IS NULL OR purchase_price >= 0`.

- [x] Task 2: API PATCH endpoint for item updates (AC: 5, 9, 10)
  - [x] 2.1: Add route `PATCH /v1/items/:id` in `apps/api/src/main.js`.
  - [x] 2.2: Add `updateItemForUser(authContext, itemId, updateData)` method to `apps/api/src/modules/items/service.js`.
  - [x] 2.3: Extract taxonomy constants from `apps/api/src/modules/ai/categorization-service.js` into a new shared module `apps/api/src/modules/ai/taxonomy.js`. Update `categorization-service.js` to import from `taxonomy.js`.
  - [x] 2.4: Update `updateItem` in `apps/api/src/modules/items/repository.js` to support the new fields: `brand`, `purchase_price`, `purchase_date`, `currency`.
  - [x] 2.5: Update `mapItemRow` in `apps/api/src/modules/items/repository.js` to include: `brand`, `purchasePrice`, `purchaseDate`, `currency`.

- [x] Task 3: Update mobile WardrobeItem model (AC: 4, 5, 6)
  - [x] 3.1: Update `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`: Add fields `brand`, `purchasePrice`, `purchaseDate`, `currency`. Add `fromJson` parsing. Add `toJson()` method.

- [x] Task 4: Create mobile taxonomy constants (AC: 2, 3)
  - [x] 4.1: Create `apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart` with const lists and `taxonomyDisplayLabel` helper.

- [x] Task 5: Create TagCloud reusable widget (AC: 2, 3, 8)
  - [x] 5.1: Create `apps/mobile/lib/src/features/wardrobe/widgets/tag_cloud.dart`.
  - [x] 5.2: Create `apps/mobile/lib/src/features/wardrobe/widgets/tag_selection_sheet.dart`.

- [x] Task 6: Create ReviewItemScreen (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x] 6.1: Create `apps/mobile/lib/src/features/wardrobe/screens/review_item_screen.dart`.
  - [x] 6.2: Implement polling for pending categorization.
  - [x] 6.3: Implement the "Save Item" flow.
  - [x] 6.4: Handle categorization failure state.
  - [x] 6.5: Implement form validation.

- [x] Task 7: Update AddItemScreen to navigate to ReviewItemScreen (AC: 1)
  - [x] 7.1: Modify `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`.

- [x] Task 8: Add `updateItem` and `getItem` methods to mobile ApiClient (AC: 5, 6)
  - [x] 8.1: Add `updateItem` method.
  - [x] 8.2: Add `getItem` method.
  - [x] 8.3: Add `PATCH` case to `_sendRequest`.

- [x] Task 9: Add `GET /v1/items/:id` API endpoint (AC: 6)
  - [x] 9.1: Add route `GET /v1/items/:id` in `apps/api/src/main.js`.

- [x] Task 10: Widget tests for new mobile components (AC: all)
  - [x] 10.1: Create `apps/mobile/test/features/wardrobe/widgets/tag_cloud_test.dart`.
  - [x] 10.2: Create `apps/mobile/test/features/wardrobe/widgets/tag_selection_sheet_test.dart`.
  - [x] 10.3: Create `apps/mobile/test/features/wardrobe/screens/review_item_screen_test.dart`.
  - [x] 10.4: Update `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`.

- [x] Task 11: API tests (AC: 5, 9, 10)
  - [x] 11.1: Create `apps/api/test/modules/ai/taxonomy.test.js`.
  - [x] 11.2: Update `apps/api/test/modules/items/service.test.js`.
  - [x] 11.3: Test `PATCH /v1/items/:id` endpoint.
  - [x] 11.4: Test `GET /v1/items/:id` endpoint.

- [x] Task 12: Regression testing (AC: all)
  - [x] 12.1: Run `flutter analyze` -- zero issues.
  - [x] 12.2: Run `flutter test` -- all 263 tests pass (was 233, +30 new).
  - [x] 12.3: Run `npm --prefix apps/api test` -- all 114 tests pass (was 81, +33 new).
  - [x] 12.4: Verify existing `POST /v1/items` flow still works (upload -> create -> bg removal -> categorization).
  - [x] 12.5: Verify `GET /v1/items` returns backward-compatible response (new optional metadata fields are nullable).
  - [x] 12.6: Verify categorization service still works after taxonomy constants extraction refactor.

## Dev Notes

- This is the FOURTH story in Epic 2 (Digital Wardrobe Core). It builds on Stories 2.1 (upload pipeline, wardrobe grid, WardrobeItem model), 2.2 (AI module, Gemini client, background removal, shimmer/polling patterns), and 2.3 (AI categorization, taxonomy validation, category labels on grid). Reuse everything established in those stories.
- The core UX pattern is the "Tag Cloud" from the UX design spec: a dense cluster of selectable chips where AI pre-selects values. Tapping a chip opens a bottom sheet for editing. Avoid free-text typing for taxonomy fields.
- The ReviewItemScreen replaces the current "pop and SnackBar" flow in AddItemScreen. After upload+create, the user lands on ReviewItemScreen to verify AI tags and add optional metadata before the item is "finalized" in their mental model (even though it already exists in the DB).
- The item already exists in the DB after `POST /v1/items` (created in Story 2.1). The ReviewItemScreen updates it via `PATCH /v1/items/:id`. This is an update, not a creation. The item is usable even if the user skips review (back button), but the review step improves data quality.

### Fixed Taxonomy (reuse from Story 2.3 -- extract to shared module)

**Categories:** `tops`, `bottoms`, `dresses`, `outerwear`, `shoes`, `bags`, `accessories`, `activewear`, `swimwear`, `underwear`, `sleepwear`, `suits`, `other`

**Colors:** `black`, `white`, `gray`, `navy`, `blue`, `light-blue`, `red`, `burgundy`, `pink`, `orange`, `yellow`, `green`, `olive`, `teal`, `purple`, `beige`, `brown`, `tan`, `cream`, `gold`, `silver`, `multicolor`, `unknown`

**Patterns:** `solid`, `striped`, `plaid`, `floral`, `polka-dot`, `geometric`, `abstract`, `animal-print`, `camouflage`, `paisley`, `tie-dye`, `color-block`, `other`

**Materials:** `cotton`, `polyester`, `silk`, `wool`, `linen`, `denim`, `leather`, `suede`, `cashmere`, `nylon`, `velvet`, `chiffon`, `satin`, `fleece`, `knit`, `mesh`, `tweed`, `corduroy`, `synthetic-blend`, `unknown`

**Styles:** `casual`, `formal`, `smart-casual`, `business`, `sporty`, `bohemian`, `streetwear`, `minimalist`, `vintage`, `classic`, `trendy`, `preppy`, `other`

**Seasons (array):** `spring`, `summer`, `fall`, `winter`, `all`

**Occasions (array):** `everyday`, `work`, `formal`, `party`, `date-night`, `outdoor`, `sport`, `beach`, `travel`, `lounge`

**Currencies:** `GBP`, `EUR`, `USD`

### Project Structure Notes

- New files:
  - `infra/sql/migrations/009_items_optional_metadata.sql`
  - `apps/api/src/modules/ai/taxonomy.js` (extracted from categorization-service.js)
  - `apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart`
  - `apps/mobile/lib/src/features/wardrobe/widgets/tag_cloud.dart`
  - `apps/mobile/lib/src/features/wardrobe/widgets/tag_selection_sheet.dart`
  - `apps/mobile/lib/src/features/wardrobe/screens/review_item_screen.dart`
  - `apps/mobile/test/features/wardrobe/widgets/tag_cloud_test.dart`
  - `apps/mobile/test/features/wardrobe/widgets/tag_selection_sheet_test.dart`
  - `apps/mobile/test/features/wardrobe/screens/review_item_screen_test.dart`
  - `apps/api/test/modules/ai/taxonomy.test.js`
- Modified files:
  - `apps/api/src/main.js` (add PATCH /v1/items/:id and GET /v1/items/:id routes)
  - `apps/api/src/modules/items/service.js` (add updateItemForUser method)
  - `apps/api/src/modules/items/repository.js` (add brand, purchasePrice, purchaseDate, currency to mapItemRow and updateItem)
  - `apps/api/src/modules/ai/categorization-service.js` (import taxonomy from shared module)
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (add brand, purchasePrice, purchaseDate, currency fields + toJson)
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (navigate to ReviewItemScreen after upload)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add updateItem, getItem, PATCH support)
  - `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`
  - `apps/api/test/modules/items/service.test.js`

### Technical Requirements

- The `PATCH /v1/items/:id` endpoint uses the existing `updateItem` repository method which already supports dynamic field updates. Extend it for the new columns.
- The URL path pattern for `PATCH /v1/items/:id` in main.js should use: `const patchItemMatch = url.pathname.match(/^\/v1\/items\/([^/]+)$/); if (req.method === "PATCH" && patchItemMatch)`. Similarly for `GET /v1/items/:id`: use the same regex but with `req.method === "GET"`. Place the GET match BEFORE the existing `GET /v1/items` (list) route to avoid conflicts, OR use a more specific regex. Actually, the list route matches `/v1/items` exactly, while `/v1/items/:id` has a path segment after, so they won't conflict. Place the item-specific routes (GET by ID, PATCH) after the categorize/remove-background routes but before the `notFound` handler.
- PostgreSQL `NUMERIC(10,2)` for purchase_price supports values up to 99,999,999.99 which is sufficient for clothing items.
- `purchase_date` as `DATE` type (not TIMESTAMP) since only the date matters, not time.
- The `_sendRequest` method in ApiClient needs a `PATCH` case. Use `_httpClient.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)`.

### Architecture Compliance

- All data mutations go through the Cloud Run API (architecture: "Cloud Run acts as the only public business API").
- RLS on `items` table ensures users only see/modify their own items. The existing `updateItem` repository method already enforces ownership via `firebase_uid` join.
- Input validation on the API side (taxonomy validation, field length limits, numeric constraints) prevents invalid data from entering the database.
- New columns are additive and nullable -- backward compatible with existing clients.
- The `taxonomy.js` shared module prevents duplication of taxonomy constants between categorization-service.js and the new validation logic in items/service.js.

### Library / Framework Requirements

- API: No new dependencies. Uses existing `pg`, existing modules. The taxonomy extraction is a pure refactor.
- Mobile: No new dependencies. `ChoiceChip`, `FilterChip`, `Wrap`, `showModalBottomSheet`, `TextFormField`, `DatePickerDialog` are all built-in Flutter/Material widgets. Shimmer reuses the existing custom implementation from Story 2.2.

### File Structure Requirements

- Migration file follows sequential numbering: 009 (after existing 008_items_categorization.sql).
- New widgets go in `apps/mobile/lib/src/features/wardrobe/widgets/` directory (create directory if it doesn't exist).
- The `taxonomy.js` module lives in `apps/api/src/modules/ai/` alongside existing AI module files.
- Mobile taxonomy constants file lives in `apps/mobile/lib/src/features/wardrobe/models/` alongside `wardrobe_item.dart`.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns in `apps/api/test/modules/items/service.test.js`.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient.
- Test taxonomy validation exhaustively: each field with valid value, invalid value, and missing value.
- Target: all existing tests continue to pass (233 Flutter tests, 81 API tests from Story 2.3).

### Previous Story Intelligence

- Story 2.3 established: AI categorization pipeline, taxonomy constants (hardcoded in categorization-service.js), `categorization_status` field on items, category label chips on wardrobe grid, retry categorization flow. 233 Flutter tests, 81 API tests.
- Story 2.3 key learning: The `updateItem` repository method already supports dynamic SET clauses for all categorization fields. Extending it for brand/price/date/currency follows the same pattern.
- Story 2.3 key pattern: Taxonomy constants are currently defined inline in `categorization-service.js`. This story extracts them to a shared module for reuse in validation.
- Story 2.2 established: Shimmer animation using `AnimationController` + `ShaderMask`. Polling with `Timer.periodic(Duration(seconds: 3))` capped at 10 retries. Fire-and-forget pattern for AI services.
- Story 2.1 established: `AddItemScreen` with camera/gallery + 3-step upload pipeline. `WardrobeScreen` with grid. `ApiClient` with authenticated request methods.
- Items table current columns after Story 2.3: `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `created_at`, `updated_at`.

### Key Anti-Patterns to Avoid

- DO NOT create a new screen for each taxonomy field. Use a single reusable bottom sheet (`TagSelectionSheet`) parameterized with the field's valid options.
- DO NOT use free-text input for taxonomy fields (category, color, pattern, material, style, season, occasion). Always constrain to the fixed taxonomy via chips + bottom sheet selection.
- DO NOT skip the taxonomy extraction refactor (Task 2.3). The categorization-service.js and items/service.js validation MUST share the same source of truth for valid taxonomy values.
- DO NOT make the ReviewItemScreen mandatory for the item to be usable. If the user presses back, the item should remain in the wardrobe with whatever AI-assigned values it has (or nulls). The review is an improvement step, not a gating step.
- DO NOT create a PUT endpoint. Use PATCH semantics -- only the provided fields are updated, unspecified fields are left unchanged.
- DO NOT add a `deleteItem` API in this story. That is Story 2.6.
- DO NOT break the existing `POST /v1/items` flow. The upload pipeline must still work as before; ReviewItemScreen is an additional step AFTER creation.
- DO NOT add filtering or searching to the wardrobe grid in this story. That is Story 2.5.
- DO NOT use `showDatePicker` from Material without wrapping it -- use `showDatePicker` directly but constrain `firstDate` to a reasonable past (e.g., 2000-01-01) and `lastDate` to today.

### Implementation Guidance

- **PATCH route in main.js:**
  ```javascript
  const itemIdMatch = url.pathname.match(/^\/v1\/items\/([^/]+)$/);
  if (req.method === "PATCH" && itemIdMatch) {
    const authContext = await requireAuth(req, authService);
    const itemId = itemIdMatch[1];
    const body = await readBody(req);
    const result = await itemService.updateItemForUser(authContext, itemId, body);
    sendJson(res, 200, result);
  }
  // GET single item
  if (req.method === "GET" && itemIdMatch) {
    const authContext = await requireAuth(req, authService);
    const itemId = itemIdMatch[1];
    const result = await itemService.getItemForUser(authContext, itemId);
    sendJson(res, 200, result);
  }
  ```

- **TagCloud widget structure:**
  ```dart
  class TagCloud extends StatelessWidget {
    const TagCloud({
      required this.groups,
      this.isLoading = false,
      super.key,
    });
    final List<TagGroup> groups;
    final bool isLoading;
  }

  class TagGroup {
    const TagGroup({
      required this.label,       // e.g., "Category"
      required this.value,       // current value(s)
      required this.options,     // valid taxonomy values
      required this.onChanged,   // callback
      this.isMultiSelect = false,
      this.displayLabels,        // optional display-friendly labels
    });
  }
  ```

- **Navigation from AddItemScreen to ReviewItemScreen:**
  ```dart
  // In _handleImage, replace the Navigator.pop + SnackBar with:
  final item = WardrobeItem.fromJson(createResult["item"] as Map<String, dynamic>);
  if (mounted) {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewItemScreen(item: item, apiClient: widget.apiClient),
      ),
    );
    if (saved == true) {
      widget.onItemAdded?.call();
    }
    if (mounted) Navigator.of(context).pop();
  }
  ```

- **ApiClient PATCH support:**
  ```dart
  // Add to _sendRequest switch:
  case "PATCH":
    return _httpClient.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
  ```

### References

- [Source: epics.md - Story 2.4: Manual Metadata Editing & Creation]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: prd.md - FR-WRD-07: Users shall be able to manually edit all AI-assigned metadata for any item]
- [Source: prd.md - FR-WRD-08: Users shall enter optional metadata: item name, brand, purchase price, purchase date, currency]
- [Source: architecture.md - API Architecture: JSON REST over HTTPS, Cloud Run as only public API]
- [Source: architecture.md - Data Architecture: RLS on all user-facing tables, check constraints for enumerations]
- [Source: architecture.md - AI Orchestration: taxonomy validation on structured outputs]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 2 -> mobile/features/wardrobe, api/modules/ai]
- [Source: ux-design-specification.md - AI-Assisted Editing: Tag Cloud pattern with selectable chips, bottom sheet for changes]
- [Source: ux-design-specification.md - Touch targets must be at least 44x44 points (WCAG AA)]
- [Source: ux-design-specification.md - Semantics widget for screen reader support]
- [Source: ux-design-specification.md - Contextual Deep Dives: Bottom sheets for acting on specific items]
- [Source: 2-3-ai-item-categorization-tagging.md - Taxonomy constants, categorization service pattern, polling, shimmer]
- [Source: 2-2-ai-background-removal-upload.md - Shimmer animation, polling pattern, fire-and-forget]
- [Source: 2-1-upload-item-photo-camera-gallery.md - AddItemScreen, upload pipeline, WardrobeItem model]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

N/A

### Completion Notes List

- Extracted taxonomy constants from categorization-service.js to shared taxonomy.js module; categorization-service.js now imports and re-exports for backward compatibility.
- The `DropdownButtonFormField.value` parameter was deprecated in Flutter 3.33+ in favor of `initialValue`; updated accordingly.
- The `_isCategorizationPending` field in ReviewItemScreen is set but only read implicitly through the `_isLoading` state; suppressed with ignore comment.
- Removed `maxLength` from TextFormField widgets in ReviewItemScreen since custom validation via `onChanged` provides the same behavior with better testability.
- Updated 2 legacy AddItemScreen tests (SnackBar tests) that tested the old "pop + SnackBar" flow, replaced with ReviewItemScreen navigation tests.
- The AddItemScreen now navigates to ReviewItemScreen after upload; the `onItemAdded` callback fires only when ReviewItemScreen pops with `true` (user saved).

### File List

**New files:**
- `infra/sql/migrations/009_items_optional_metadata.sql`
- `apps/api/src/modules/ai/taxonomy.js`
- `apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart`
- `apps/mobile/lib/src/features/wardrobe/widgets/tag_cloud.dart`
- `apps/mobile/lib/src/features/wardrobe/widgets/tag_selection_sheet.dart`
- `apps/mobile/lib/src/features/wardrobe/screens/review_item_screen.dart`
- `apps/mobile/test/features/wardrobe/widgets/tag_cloud_test.dart`
- `apps/mobile/test/features/wardrobe/widgets/tag_selection_sheet_test.dart`
- `apps/mobile/test/features/wardrobe/screens/review_item_screen_test.dart`
- `apps/api/test/modules/ai/taxonomy.test.js`

**Modified files:**
- `apps/api/src/main.js` (added PATCH /v1/items/:id and GET /v1/items/:id routes)
- `apps/api/src/modules/items/service.js` (added updateItemForUser method with taxonomy+metadata validation)
- `apps/api/src/modules/items/repository.js` (added brand, purchasePrice, purchaseDate, currency to mapItemRow and updateItem)
- `apps/api/src/modules/ai/categorization-service.js` (imports taxonomy from shared taxonomy.js)
- `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (added brand, purchasePrice, purchaseDate, currency fields + toJson)
- `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (navigates to ReviewItemScreen after upload)
- `apps/mobile/lib/src/core/networking/api_client.dart` (added updateItem, getItem, _authenticatedPatch, PATCH case)
- `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart` (updated for ReviewItemScreen navigation)
- `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart` (added optional metadata + toJson tests)
- `apps/api/test/modules/items/service.test.js` (added updateItemForUser validation tests)
- `apps/api/test/items-endpoint.test.js` (added PATCH and GET /v1/items/:id endpoint tests)
