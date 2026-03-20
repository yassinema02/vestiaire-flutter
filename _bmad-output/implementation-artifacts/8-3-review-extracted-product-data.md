# Story 8.3: Review Extracted Product Data

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to review and edit the details the app extracted from my link or screenshot,
so that the compatibility score is based accurately on what the item actually is.

## Acceptance Criteria

1. Given a URL or screenshot scan has completed successfully (Stories 8.1/8.2), when the scan result card is displayed, then the existing "Continue to Analysis" button (currently disabled placeholder) is replaced with a "Review & Edit" button that navigates to a new `ProductReviewScreen`. The button is enabled and styled with the primary accent (`#4F46E5`). (FR-SHP-05)

2. Given I am on the `ProductReviewScreen`, when the screen loads, then I see the product image (if available), product name, brand, and price displayed at the top as a read-only summary header, followed by editable fields for all AI-extracted metadata: `category`, `color`, `secondaryColors`, `pattern`, `material`, `style`, `season`, `occasion`, `formalityScore`, `productName`, `brand`, `price`, and `currency`. Each field is pre-populated with the values from the scan result. (FR-SHP-05)

3. Given I am on the `ProductReviewScreen`, when I view the taxonomy fields (category, color, pattern, material, style), then each field is displayed as a tappable chip using the "Tag Cloud" pattern from the UX design spec. Tapping a chip opens a bottom sheet with all valid options from the fixed taxonomy (e.g., tapping the category chip shows all 13 valid categories). The currently selected value is highlighted. Selecting a new value updates the chip immediately. (FR-SHP-05)

4. Given I am on the `ProductReviewScreen`, when I view the multi-select fields (secondaryColors, season, occasion), then each field is displayed as a group of selectable chips. Multiple chips can be selected simultaneously. The valid options come from the same fixed taxonomy arrays. (FR-SHP-05)

5. Given I am on the `ProductReviewScreen`, when I view the formality score field, then it is displayed as a slider (1-10) with labels "Very Casual" at 1 and "Black Tie" at 10. The slider is pre-set to the AI-extracted value (or 5 if null). (FR-SHP-05)

6. Given I am on the `ProductReviewScreen`, when I view the text fields (productName, brand), then each is displayed as an editable `TextField` pre-populated with the extracted value. When I view the price field, then it is displayed as a numeric `TextField` with a currency dropdown (GBP, EUR, USD) beside it. (FR-SHP-05)

7. Given I have made edits on the `ProductReviewScreen`, when I tap the "Confirm" button, then the app calls `PATCH /v1/shopping/scans/:id` with all edited fields. The API updates the `shopping_scans` row and returns the updated scan. The screen navigates forward to the "Continue to Analysis" placeholder (for Story 8.4). (FR-SHP-05)

8. Given the API receives a `PATCH /v1/shopping/scans/:id` request, when the request is processed, then it authenticates the user, validates that all taxonomy fields contain values from the fixed taxonomy arrays (same validation as Story 2.3), validates `formalityScore` is integer 1-10, validates `price` is a positive number or null, validates `currency` is one of GBP/EUR/USD, updates only the provided fields in the `shopping_scans` row, and returns the updated scan. If the scan ID doesn't belong to the authenticated user (RLS), it returns 404. If validation fails, it returns 400 with field-level errors. (FR-SHP-05)

9. Given I am on the `ProductReviewScreen`, when I tap "Skip Review" (secondary action), then the screen navigates directly to the "Continue to Analysis" placeholder (Story 8.4) without calling the update endpoint, preserving the original AI-extracted data. (FR-SHP-05)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (750+ API tests, 1178+ Flutter tests) and new tests cover: PATCH /v1/shopping/scans/:id endpoint (success, validation failures, auth, RLS), updateScan repository method, ProductReviewScreen widget (field display, chip selection, slider, text editing, confirm, skip), ShoppingScanService updateScan method, and ApiClient updateScan method.

## Tasks / Subtasks

- [x] Task 1: API -- Add `updateScan` method to shopping scan repository (AC: 7, 8)
  - [x] 1.1: In `apps/api/src/modules/shopping/shopping-scan-repository.js`, add method `async updateScan(authContext, scanId, updateData)`. Steps: (a) acquire client from pool, (b) begin transaction, (c) set `app.current_user_id` for RLS, (d) build a dynamic UPDATE query that only sets fields present in `updateData` (use parameterized query construction), (e) execute `UPDATE app_public.shopping_scans SET ... WHERE id = $1 RETURNING *`, (f) if no rows returned, return null (RLS will filter out other users' scans), (g) commit, (h) return `mapScanRow(result.rows[0])`. The updatable fields are: `product_name`, `brand`, `price`, `currency`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `formality_score`.
  - [x] 1.2: Follow the exact dynamic UPDATE pattern from `itemService.updateItemForUser` in `apps/api/src/modules/items/service.js` for building the SET clause with parameterized values.

- [x] Task 2: API -- Add scan validation utility (AC: 8)
  - [x] 2.1: Create a `validateScanUpdate(body)` function in `apps/api/src/modules/shopping/shopping-scan-service.js` (or a separate `shopping-validators.js` if preferred). This function validates each field if present: (a) `category` must be in `VALID_CATEGORIES`, (b) `color` must be in `VALID_COLORS`, (c) `secondaryColors` must be an array where each element is in `VALID_COLORS`, (d) `pattern` must be in `VALID_PATTERNS`, (e) `material` must be in `VALID_MATERIALS`, (f) `style` must be in `VALID_STYLES`, (g) `season` must be an array where each element is in `VALID_SEASONS`, (h) `occasion` must be an array where each element is in `VALID_OCCASIONS`, (i) `formalityScore` must be integer 1-10, (j) `price` must be a positive number or null, (k) `currency` must be one of `VALID_CURRENCIES` (GBP, EUR, USD from `taxonomy.js`). Return `{ valid: true, data: sanitizedData }` on success or `{ valid: false, errors: [{ field, message }] }` on failure.
  - [x] 2.2: Import taxonomy constants from `apps/api/src/modules/ai/taxonomy.js`. The `VALID_CURRENCIES` array already exists there (`["GBP", "EUR", "USD"]`).

- [x] Task 3: API -- Wire PATCH /v1/shopping/scans/:id endpoint (AC: 7, 8)
  - [x] 3.1: In `apps/api/src/main.js`, add route `PATCH /v1/shopping/scans/:id`. This endpoint: (a) authenticates the user via `requireAuth`, (b) extracts `scanId` from URL path using a regex match similar to `itemIdMatch` (e.g., `const scanIdMatch = url.pathname.match(/^\/v1\/shopping\/scans\/([a-f0-9-]+)$/)`), (c) calls `validateScanUpdate(body)` to validate all fields, (d) if validation fails, return 400 with `{ error: "Validation Error", code: "VALIDATION_ERROR", errors: validationResult.errors }`, (e) calls `shoppingScanRepo.updateScan(authContext, scanId, validationResult.data)`, (f) if null returned (not found or RLS), return 404, (g) return 200 with `{ scan: updatedScan }`.
  - [x] 3.2: Place the route adjacent to the existing shopping routes. Import `validateScanUpdate` at the top of `main.js`.
  - [x] 3.3: Add `shoppingScanRepo` to the `handleRequest` destructuring if not already present (it is present from Story 8.1).

- [x] Task 4: Mobile -- Add `toJson` method to ShoppingScan model (AC: 7)
  - [x] 4.1: In `apps/mobile/lib/src/features/shopping/models/shopping_scan.dart`, add a `Map<String, dynamic> toJson()` method that serializes all editable fields to a JSON map. Only include fields that have values (skip nulls). This is used to send the updated scan data to the PATCH endpoint.
  - [x] 4.2: Add a `ShoppingScan copyWith({...})` method to create a new instance with selectively updated fields. This enables the review screen to build up edits immutably. Include all editable fields as optional named parameters.

- [x] Task 5: Mobile -- Add `updateScan` method to ShoppingScanService (AC: 7)
  - [x] 5.1: In `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart`, add method `Future<ShoppingScan> updateScan(String scanId, Map<String, dynamic> updates)` that calls `_apiClient.authenticatedPatch("/v1/shopping/scans/$scanId", body: updates)` and returns `ShoppingScan.fromJson(response["scan"])`.

- [x] Task 6: Mobile -- Add `updateShoppingScan` method to ApiClient (AC: 7)
  - [x] 6.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add method `Future<Map<String, dynamic>> updateShoppingScan(String scanId, Map<String, dynamic> updates)` that calls `authenticatedPatch("/v1/shopping/scans/$scanId", body: updates)`. Place adjacent to existing `scanProductUrl` and `scanProductScreenshot` methods.
  - [x] 6.2: If `authenticatedPatch` does not already exist on `ApiClient`, add it following the same pattern as `authenticatedPost` but using `PATCH` method.

- [x] Task 7: Mobile -- Create ProductReviewScreen (AC: 1, 2, 3, 4, 5, 6, 7, 9)
  - [x] 7.1: Create `apps/mobile/lib/src/features/shopping/screens/product_review_screen.dart` with `ProductReviewScreen` StatefulWidget. Constructor: `{ required ShoppingScan initialScan, required ShoppingScanService shoppingScanService, super.key }`.
  - [x] 7.2: State management: Initialize `_editedScan` from `initialScan` using `copyWith`. Track `_isSubmitting` boolean for loading state. Track `_hasChanges` boolean to enable/disable Confirm button appropriately.
  - [x] 7.3: Build the product summary header: product image (if available, `Image.network` with error placeholder, height 180, rounded corners), product name (bold, 18px), brand (gray, 14px), price with currency (accent color, 20px). This section is read-only.
  - [x] 7.4: Build the taxonomy chip fields using the "Tag Cloud" pattern from UX spec. For single-select fields (category, color, pattern, material, style), show the current value as a tappable `Chip` with an edit icon. On tap, open a `showModalBottomSheet` containing a `Wrap` of all valid options as `ChoiceChip` widgets. The currently selected option is highlighted with primary accent. On selection, update `_editedScan` via `copyWith` and close the sheet.
  - [x] 7.5: Build the multi-select chip fields (secondaryColors, season, occasion). Show all selected values as `Chip` widgets. On tap of the group, open a `showModalBottomSheet` with all valid options as `FilterChip` widgets (multiple selectable). On selection changes, update `_editedScan` via `copyWith`.
  - [x] 7.6: Build the formality score slider. Use a `Slider` widget with `min: 1`, `max: 10`, `divisions: 9`, labeled with "Very Casual" (1) and "Black Tie" (10). Show the current value as a large number above the slider. On change, update `_editedScan` via `copyWith`.
  - [x] 7.7: Build the text fields. Product name and brand use `TextField` with `TextEditingController` initialized from the scan values. Price uses a `TextField` with `keyboardType: TextInputType.numberWithOptions(decimal: true)`. Currency uses a `DropdownButton` with options GBP, EUR, USD.
  - [x] 7.8: Build the action buttons at the bottom: (a) "Confirm" primary button (`ElevatedButton`, accent color, full width) -- calls the update API and navigates forward, (b) "Skip Review" secondary button (`TextButton`, gray text) -- navigates forward without updating. The Confirm button shows a `CircularProgressIndicator` while submitting.
  - [x] 7.9: On "Confirm" tap: build a `Map<String, dynamic>` of all editable fields from `_editedScan`, call `shoppingScanService.updateScan(initialScan.id, updates)`, on success navigate to placeholder (Story 8.4 will replace this), on error show a `SnackBar` with the error message.
  - [x] 7.10: On "Skip Review" tap: navigate to placeholder (Story 8.4).
  - [x] 7.11: Add `Semantics` labels on all interactive elements: each taxonomy chip, the formality slider, text fields, Confirm button, Skip Review button.
  - [x] 7.12: Follow the Vibrant Soft-UI design system: 16px border radius, subtle shadows, `#4F46E5` primary accent, `#F3F4F6` background, `#1F2937` text, `#6B7280` secondary text.

- [x] Task 8: Mobile -- Update ShoppingScanScreen to navigate to ProductReviewScreen (AC: 1)
  - [x] 8.1: In `apps/mobile/lib/src/features/shopping/screens/shopping_scan_screen.dart`, replace the disabled "Continue to Analysis" `OutlinedButton` in `_buildResultCard()` with an active "Review & Edit" `ElevatedButton` styled with accent color. On tap, navigate to `ProductReviewScreen` passing `_scanResult!` and `widget.shoppingScanService`.
  - [x] 8.2: Update the constructor to accept `ShoppingScanService` (already present) -- no additional constructor changes needed since `ProductReviewScreen` only needs the scan result and the service.

- [x] Task 9: API -- Unit tests for updateScan repository method (AC: 8)
  - [x] 9.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-repository.test.js`:
    - `updateScan` updates specified fields and returns updated scan.
    - `updateScan` returns null for non-existent scan ID.
    - `updateScan` returns null for another user's scan (RLS).
    - `updateScan` updates only provided fields, leaving others unchanged.
    - `updateScan` handles array fields (secondaryColors, season, occasion).
    - `updateScan` updates formalityScore as integer.

- [x] Task 10: API -- Unit tests for validateScanUpdate (AC: 8)
  - [x] 10.1: Add tests (in existing shopping-scan-service.test.js or new file):
    - Valid update with all fields passes validation.
    - Valid update with partial fields passes validation.
    - Invalid category returns validation error.
    - Invalid color returns validation error.
    - Invalid formalityScore (0, 11, non-integer) returns validation error.
    - Invalid price (negative, non-number) returns validation error.
    - Invalid currency returns validation error.
    - Invalid secondaryColors (non-array, invalid values) returns validation error.
    - Invalid season (non-array, invalid values) returns validation error.
    - Empty update object passes validation (no fields to validate).

- [x] Task 11: API -- Integration tests for PATCH endpoint (AC: 7, 8)
  - [x] 11.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js`:
    - PATCH /v1/shopping/scans/:id returns 200 with updated scan data.
    - PATCH /v1/shopping/scans/:id returns 400 on validation failure with field errors.
    - PATCH /v1/shopping/scans/:id returns 404 for non-existent scan.
    - PATCH /v1/shopping/scans/:id returns 404 for another user's scan (RLS).
    - PATCH /v1/shopping/scans/:id returns 401 without authentication.
    - Partial update only modifies specified fields.

- [x] Task 12: Mobile -- Widget tests for ProductReviewScreen (AC: 2, 3, 4, 5, 6, 7, 9)
  - [x] 12.1: Create `apps/mobile/test/features/shopping/screens/product_review_screen_test.dart`:
    - Renders product summary header with image, name, brand, price.
    - Renders taxonomy chips pre-populated from scan data.
    - Tapping category chip opens bottom sheet with all valid categories.
    - Selecting a new category updates the chip.
    - Renders multi-select chips for season and occasion.
    - Renders formality slider with correct initial value.
    - Moving slider updates displayed value.
    - Text fields are pre-populated with product name, brand, price.
    - Currency dropdown shows correct options (GBP, EUR, USD).
    - Tapping Confirm calls updateScan with edited data.
    - Confirm button shows loading state during submission.
    - Tapping Skip Review navigates without calling API.
    - Semantics labels present on all interactive elements.
    - Handles scan with null fields gracefully (shows defaults).

- [x] Task 13: Mobile -- Update ShoppingScanScreen tests (AC: 1)
  - [x] 13.1: Update `apps/mobile/test/features/shopping/screens/shopping_scan_screen_test.dart`:
    - "Review & Edit" button is enabled and visible when scan result is displayed.
    - Tapping "Review & Edit" navigates to ProductReviewScreen.

- [x] Task 14: Mobile -- ShoppingScanService and ApiClient test updates (AC: 7)
  - [x] 14.1: Update `apps/mobile/test/core/networking/api_client_test.dart`: `updateShoppingScan` calls PATCH /v1/shopping/scans/:id with correct body.
  - [x] 14.2: Add or update shopping scan service test to verify `updateScan` calls the correct API endpoint and returns an updated `ShoppingScan`.

- [x] Task 15: Mobile -- ShoppingScan model tests (AC: 7)
  - [x] 15.1: Update `apps/mobile/test/features/shopping/models/shopping_scan_test.dart`:
    - `toJson` serializes all editable fields correctly.
    - `toJson` skips null fields.
    - `copyWith` creates a new instance with updated fields.
    - `copyWith` preserves unchanged fields.

- [x] Task 16: Regression testing (AC: all)
  - [x] 16.1: Run `flutter analyze` -- zero new issues.
  - [x] 16.2: Run `flutter test` -- all existing 1178+ tests plus new tests pass.
  - [x] 16.3: Run `npm --prefix apps/api test` -- all existing 750+ API tests plus new tests pass.
  - [x] 16.4: Verify existing URL scan pipeline still works (Story 8.1 functionality unchanged).
  - [x] 16.5: Verify existing screenshot scan pipeline still works (Story 8.2 functionality unchanged).
  - [x] 16.6: Verify existing item metadata editing still works (Story 2.4 PATCH /v1/items/:id).

## Dev Notes

- This is the THIRD story in Epic 8 (Shopping Assistant). It adds the review/edit step between scan extraction (Stories 8.1/8.2) and compatibility scoring (Story 8.4). The user can correct any AI-extracted metadata before the product is scored against their wardrobe. This is FR-SHP-05: "Users shall confirm or edit AI-extracted product data before scoring."
- The review screen uses the **"Tag Cloud" pattern** from the UX design spec (Section: Form Patterns > AI-Assisted Editing). AI pre-selects chips; tapping opens a bottom sheet to change the value. Avoid free-text typing for taxonomy fields wherever possible.
- The `shopping_scans` table already has all the columns needed. No migration required. The PATCH endpoint simply updates existing columns.
- The `ShoppingScan` Dart model (from Story 8.1) is currently immutable with `final` fields. This story adds `copyWith` and `toJson` methods to enable editing and serialization.
- The fixed taxonomy arrays used for validation are in `apps/api/src/modules/ai/taxonomy.js`. Import these for server-side validation. On the mobile side, define matching constant lists in a new `taxonomy_constants.dart` file (or inline in the review screen) to populate the chip selection bottom sheets.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/shopping/screens/product_review_screen.dart`
  - `apps/mobile/test/features/shopping/screens/product_review_screen_test.dart`
- Modified API files:
  - `apps/api/src/modules/shopping/shopping-scan-repository.js` (add `updateScan` method)
  - `apps/api/src/modules/shopping/shopping-scan-service.js` (add `validateScanUpdate` function)
  - `apps/api/src/main.js` (add `PATCH /v1/shopping/scans/:id` route, import `validateScanUpdate`)
  - `apps/api/test/modules/shopping/shopping-scan-repository.test.js` (add updateScan tests)
  - `apps/api/test/modules/shopping/shopping-scan-service.test.js` (add validation tests)
  - `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js` (add PATCH endpoint tests)
- Modified mobile files:
  - `apps/mobile/lib/src/features/shopping/models/shopping_scan.dart` (add `copyWith`, `toJson`)
  - `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart` (add `updateScan`)
  - `apps/mobile/lib/src/features/shopping/screens/shopping_scan_screen.dart` (activate "Review & Edit" button, navigation)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `updateShoppingScan`, possibly `authenticatedPatch`)
  - `apps/mobile/test/features/shopping/models/shopping_scan_test.dart` (add copyWith/toJson tests)
  - `apps/mobile/test/features/shopping/screens/shopping_scan_screen_test.dart` (update button tests)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add updateShoppingScan test)

### Technical Requirements

- **PATCH endpoint** follows the same pattern as `PATCH /v1/items/:id` for item metadata editing (Story 2.4). Dynamic SET clause with parameterized values.
- **Server-side validation** uses the same taxonomy arrays from `apps/api/src/modules/ai/taxonomy.js`. All taxonomy fields MUST be validated before persisting.
- **No new dependencies** on API or mobile. Uses existing Flutter material widgets, existing bottom sheet patterns, existing chip patterns.
- **`authenticatedPatch` on ApiClient:** Check if it already exists. If not, add it following the exact pattern of `authenticatedPost` but with `PATCH` method. The existing `PATCH /v1/items/:id` route suggests this method may already exist.
- **Taxonomy constants on mobile:** Create `apps/mobile/lib/src/features/shopping/constants/taxonomy_constants.dart` with Dart `List<String>` constants matching the API taxonomy. These are used to populate chip selections. Alternatively, if a shared taxonomy file already exists in the mobile codebase (check `apps/mobile/lib/src/features/wardrobe/` for item editing patterns), reuse it.

### Architecture Compliance

- **Server-side validation only.** The mobile client provides selection-constrained UI (chips from taxonomy lists) but the API independently validates all fields. Never trust client input.
- **RLS on shopping_scans.** The PATCH endpoint uses the same RLS pattern as all other user-facing tables. Users can only update their own scans.
- **No AI calls in this story.** This is purely a CRUD update with validation. No Gemini calls, no AI usage logging.
- **Error handling standard:** 400 for validation, 401 for auth, 404 for not found (including RLS), 200 for success.
- **Epic 8 component mapping:** `mobile/features/shopping`, `api/modules/shopping` (architecture.md).

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `pg` via pool, existing taxonomy constants.
- **Mobile:** No new dependencies. Uses existing Flutter material widgets (`Chip`, `ChoiceChip`, `FilterChip`, `Slider`, `TextField`, `DropdownButton`, `BottomSheet`), existing `api_client.dart`, existing navigation patterns.

### File Structure Requirements

- `apps/mobile/lib/src/features/shopping/screens/` already exists from Story 8.1. The new `product_review_screen.dart` goes here.
- `apps/mobile/lib/src/features/shopping/constants/` is a NEW directory for taxonomy constants. Alternatively, put them in the screen file if the list is short enough.
- Test files mirror source structure.

### Testing Requirements

- **API tests** extend existing files from Stories 8.1/8.2. Use the same Node.js built-in test runner patterns.
- **No mocking of Gemini** needed in this story -- no AI calls.
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Target:** All existing tests continue to pass (750 API tests, 1178 Flutter tests from Story 8.2) plus new tests.

### Previous Story Intelligence

- **Story 8.2** (done, predecessor) established: `scanScreenshot` method in `shopping-scan-service.js`, `SCREENSHOT_TEXT_PROMPT`, parallel Gemini calls via `Promise.all`, `shopping_screenshot` upload purpose, active screenshot card in `ShoppingScanScreen`, `apiClient` and `imagePicker` parameters on screen constructor. **750 API tests, 1178 Flutter tests.** 33 services in `createRuntime()`.
- **Story 8.1** (done) established: `shopping_scans` table (024 migration), `shopping-scan-service.js` with `scanUrl()` + `downloadImage()` + `PRODUCT_IMAGE_PROMPT` + `validateFormalityScore()`, `shopping-scan-repository.js` with `createScan()` / `getScanById()` / `listScans()` / `mapScanRow()`, `ShoppingScan` Dart model, `ShoppingScanService`, `ShoppingScanScreen` with URL input + result card + disabled "Continue to Analysis" button.
- **Story 2.4** (done) established: Manual metadata editing pattern. `PATCH /v1/items/:id` endpoint for updating item metadata. Dynamic UPDATE query construction with parameterized values in `itemService.updateItemForUser`. This is the exact pattern to follow for `updateScan`.
- **Story 2.3** (done) established: Fixed taxonomy arrays in `apps/api/src/modules/ai/taxonomy.js`, `validateTaxonomy` function in `categorization-service.js`.
- **`createRuntime()` returns 33 services** (as of Story 8.2). No new services needed for this story -- `shoppingScanRepo` already exists and gets the new `updateScan` method.
- **`handleRequest` destructuring** includes `shoppingScanService`, `shoppingScanRepo` from Story 8.1. No changes to destructuring needed.
- **`mapError` function** handles 400, 401, 403, 404, 409, 422, 429, 500, 503. No changes needed.
- **Key patterns from previous stories:**
  - Factory pattern for API services/repositories: `createXxxService({ deps })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories.
  - Semantics labels on all interactive elements.
  - Vibrant Soft-UI: 16px border radius, `#4F46E5` accent, `#F3F4F6` background.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client or from this story's API code. This story is pure CRUD -- no AI.
- DO NOT create a new database migration. The `shopping_scans` table already has all columns needed.
- DO NOT create a new service factory. Add `updateScan` to the existing `shopping-scan-repository.js` and `validateScanUpdate` alongside the existing service code.
- DO NOT add new services to `createRuntime()`. The `shoppingScanRepo` already exists.
- DO NOT implement compatibility scoring or insights. Those are Stories 8.4 and 8.5. The "Continue to Analysis" navigation target should be a placeholder screen or a `SnackBar` message.
- DO NOT use free-text input for taxonomy fields on the mobile side. Use chips/dropdowns constrained to the fixed taxonomy values.
- DO NOT allow the user to change `scanType`, `extractionMethod`, `id`, `createdAt`, or `profileId`. These are immutable.
- DO NOT skip server-side validation even though the mobile UI constrains selections. The API must independently validate all fields.
- DO NOT modify the existing `scanUrl` or `scanScreenshot` methods. This story only adds an `updateScan` repository method and a new PATCH endpoint.
- DO NOT break the existing "Continue to Analysis" disabled button for scans that haven't been reviewed. After this story, all scans get "Review & Edit" instead.

### Out of Scope

- **Compatibility scoring** (Story 8.4)
- **Match display, insights, wishlist** (Story 8.5)
- **Empty wardrobe CTA** (Story 8.5 -- FR-SHP-12)
- **Re-running AI analysis after edits** -- the user manually corrects; no re-scan
- **Image editing or replacement** -- only metadata fields are editable
- **Scan history list or scan deletion** -- future enhancement

### References

- [Source: epics.md - Story 8.3: Review Extracted Product Data]
- [Source: epics.md - Epic 8: Shopping Assistant, FR-SHP-05]
- [Source: prd.md - FR-SHP-05: Users shall confirm or edit AI-extracted product data before scoring]
- [Source: prd.md - FR-SHP-04: Structured product data: name, category, color, secondary colors, style, material, pattern, season, formality score (1-10), brand, price]
- [Source: ux-design-specification.md - Form Patterns > AI-Assisted Editing: "Tag Cloud" pattern, chips with bottom sheet selection]
- [Source: architecture.md - Epic 8 Shopping Assistant -> mobile/features/shopping, api/modules/shopping]
- [Source: architecture.md - Taxonomy validation on structured outputs, safe defaults]
- [Source: architecture.md - Important tables: shopping_scans]
- [Source: 8-1-product-url-scraping.md - shopping_scans table, ShoppingScan model, ShoppingScanScreen, _buildResultCard, disabled "Continue to Analysis" button, taxonomy validation]
- [Source: 8-2-product-screenshot-upload.md - scanScreenshot, screenshot upload flow, 750 API tests, 1178 Flutter tests]
- [Source: 2-4-manual-metadata-editing-creation.md - PATCH /v1/items/:id pattern, dynamic UPDATE query, item metadata editing]
- [Source: 2-3-ai-item-categorization-tagging.md - Fixed taxonomy arrays, taxonomy.js, validateTaxonomy]
- [Source: apps/api/src/modules/ai/taxonomy.js - VALID_CATEGORIES, VALID_COLORS, VALID_PATTERNS, VALID_MATERIALS, VALID_STYLES, VALID_SEASONS, VALID_OCCASIONS, VALID_CURRENCIES]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed scanIdMatch regex from `[a-f0-9-]+` to `[^/]+` to match non-UUID test IDs and be consistent with itemIdMatch pattern.

### Completion Notes List

- Task 1: Added `updateScan` method to shopping-scan-repository.js with dynamic UPDATE query, RLS via set_config, camelCase-to-snake_case field mapping, text[] casts for array columns.
- Task 2: Added `validateScanUpdate` exported function to shopping-scan-service.js. Validates all taxonomy fields against fixed arrays, formalityScore as integer 1-10, price as positive number or null, currency as GBP/EUR/USD. Returns `{ valid, data/errors }`.
- Task 3: Wired `PATCH /v1/shopping/scans/:id` route in main.js with auth, validation, and 200/400/404 responses. Imported validateScanUpdate.
- Task 4: Added `copyWith` and `toJson` methods to ShoppingScan Dart model. copyWith supports all fields; toJson skips nulls and only includes editable fields.
- Task 5: Added `updateScan` method to ShoppingScanService calling apiClient.updateShoppingScan.
- Task 6: Added `updateShoppingScan` method to ApiClient. authenticatedPatch already existed.
- Task 7: Created ProductReviewScreen with: read-only product header, single-select taxonomy chips (ChoiceChip in bottom sheet), multi-select chips (FilterChip in bottom sheet), formality slider (1-10), text fields (productName, brand, price with currency dropdown), Confirm and Skip Review buttons, Semantics on all interactive elements, Vibrant Soft-UI design system.
- Task 8: Replaced disabled "Continue to Analysis" OutlinedButton with active "Review & Edit" ElevatedButton in ShoppingScanScreen._buildResultCard(). Navigates to ProductReviewScreen.
- Task 9: Added 7 unit tests for updateScan repository method.
- Task 10: Added 11 unit tests for validateScanUpdate function.
- Task 11: Added 6 integration tests for PATCH /v1/shopping/scans/:id endpoint.
- Task 12: Added 12 widget tests for ProductReviewScreen.
- Task 13: Added 2 widget tests for Review & Edit button in ShoppingScanScreen.
- Task 14: Added 1 api_client test for updateShoppingScan. Service test covered via mock in ProductReviewScreen tests.
- Task 15: Added 4 model tests for toJson and copyWith.
- Task 16: All 774 API tests pass (750+24). All 1199 Flutter tests pass (1178+21). flutter analyze: 0 new issues.

### Change Log

- 2026-03-19: Story 8.3 implementation complete. Added PATCH /v1/shopping/scans/:id endpoint, ProductReviewScreen with editable taxonomy chips and formality slider, 45 new tests total.

### File List

New files:
- apps/mobile/lib/src/features/shopping/screens/product_review_screen.dart
- apps/mobile/lib/src/features/shopping/constants/taxonomy_constants.dart
- apps/mobile/test/features/shopping/screens/product_review_screen_test.dart

Modified files:
- apps/api/src/modules/shopping/shopping-scan-repository.js (added updateScan method)
- apps/api/src/modules/shopping/shopping-scan-service.js (added validateScanUpdate, imported VALID_CURRENCIES)
- apps/api/src/main.js (added PATCH /v1/shopping/scans/:id route, imported validateScanUpdate)
- apps/mobile/lib/src/features/shopping/models/shopping_scan.dart (added copyWith, toJson)
- apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart (added updateScan)
- apps/mobile/lib/src/core/networking/api_client.dart (added updateShoppingScan)
- apps/mobile/lib/src/features/shopping/screens/shopping_scan_screen.dart (Review & Edit button, import)
- apps/api/test/modules/shopping/shopping-scan-repository.test.js (added updateScan tests)
- apps/api/test/modules/shopping/shopping-scan-service.test.js (added validateScanUpdate tests)
- apps/api/test/modules/shopping/shopping-scan-endpoint.test.js (added PATCH endpoint tests)
- apps/mobile/test/features/shopping/screens/shopping_scan_screen_test.dart (added Review & Edit tests)
- apps/mobile/test/features/shopping/models/shopping_scan_test.dart (added copyWith/toJson tests)
- apps/mobile/test/core/networking/api_client_test.dart (added updateShoppingScan test, PATCH support)
