# Story 10.3: Extraction Progress & Review Flow

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see the progress of my bulk import and review the results before adding them,
So that I can delete mistakes or duplicates before they clutter my wardrobe.

## Acceptance Criteria

1. Given a bulk extraction job was just created (navigated from BulkImportPreviewScreen in Story 10.1), when I land on the Extraction Progress Screen, then I see a real-time progress view showing: job status text (e.g., "Processing photo 3 of 12..."), a `LinearProgressIndicator` based on `processedPhotos / totalPhotos`, the count of items found so far (`totalItemsFound`), and estimated time remaining (based on ~6 seconds per unprocessed photo). (FR-EXT-07)

2. Given the extraction job is still processing, when the screen polls the server (every 3 seconds via `GET /v1/extraction-jobs/:id`), then the progress UI updates automatically with the latest `processedPhotos`, `totalItemsFound`, and `status`. Polling stops when job status is `'completed'`, `'partial'`, or `'failed'`. (FR-EXT-07, FR-EXT-08)

3. Given the extraction job completes with status `'completed'` or `'partial'`, when the results are ready, then the screen automatically transitions to the Extraction Review Screen showing all extracted items in a scrollable list/grid. Each item card displays: the cleaned item image (`photoUrl`), category label, color label, and a prominent Keep/Remove toggle (defaulting to Keep). (FR-EXT-05, FR-EXT-06)

4. Given I am on the Extraction Review Screen, when I view an individual extracted item, then I can tap it to expand/edit its metadata: name (auto-generated from category + color, e.g., "Blue Denim Jacket"), category, color, secondary colors, pattern, material, style, season, and occasion. All editable fields use the same taxonomy validation as the existing item editing flow. (FR-EXT-06)

5. Given the system has detected a potential duplicate (an extracted item whose category AND color match an existing wardrobe item), when I view the extraction review list, then a "Possible duplicate" warning badge appears on that item card with a tap-to-compare action showing the existing wardrobe item side-by-side. (FR-EXT-10)

6. Given I have toggled Keep/Remove on extracted items and am satisfied with my selections, when I tap "Add to Wardrobe", then the app calls `POST /v1/extraction-jobs/:id/confirm` with the list of kept item IDs and any metadata edits. The server creates real `items` table records for each kept item with `creation_method = 'ai_extraction'` and `extraction_job_id` linking back to the source job. (FR-EXT-05, FR-EXT-09)

7. Given the confirmation endpoint processes kept items, when items are added to the wardrobe, then each new item record includes: `photo_url` (from extraction item's cleaned image), `name`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `bg_removal_status = 'completed'`, `categorization_status = 'completed'`, `creation_method = 'ai_extraction'`, and `extraction_job_id`. The extraction job status is updated to `'confirmed'`. (FR-EXT-09)

8. Given the confirmation succeeds, when I return to the Wardrobe screen, then I see all newly added items in the wardrobe grid alongside existing items, with proper filtering and detail view support. A success SnackBar shows "X items added to your wardrobe!" (FR-EXT-05)

9. Given the extraction job failed (status `'failed'` -- zero photos succeeded), when I view the progress screen, then I see an error message with a "Retry" button that calls `POST /v1/extraction-jobs/:id/process` to re-trigger processing. (FR-EXT-08)

10. Given I am on the Extraction Review Screen, when I toggle ALL items to "Remove" and tap "Add to Wardrobe", then the app shows a confirmation dialog: "No items selected. Discard all extracted items?" On confirm, the job is marked as `'confirmed'` with zero items added. (FR-EXT-05, FR-EXT-06)

## Tasks / Subtasks

- [x] Task 1: Database migration for `creation_method` and `extraction_job_id` on items table (AC: 6, 7)
  - [ ] 1.1: Create `infra/sql/migrations/033_items_creation_method.sql`: `ALTER TABLE app_public.items ADD COLUMN IF NOT EXISTS creation_method TEXT CHECK (creation_method IN ('manual', 'ai_extraction')) DEFAULT 'manual'; ALTER TABLE app_public.items ADD COLUMN IF NOT EXISTS extraction_job_id UUID REFERENCES app_public.wardrobe_extraction_jobs(id) ON DELETE SET NULL;` Add index on `extraction_job_id`.
  - [ ] 1.2: Add `'confirmed'` to the `wardrobe_extraction_jobs.status` CHECK constraint. Create migration `infra/sql/migrations/034_extraction_job_confirmed_status.sql`: `ALTER TABLE app_public.wardrobe_extraction_jobs DROP CONSTRAINT IF EXISTS wardrobe_extraction_jobs_status_check; ALTER TABLE app_public.wardrobe_extraction_jobs ADD CONSTRAINT wardrobe_extraction_jobs_status_check CHECK (status IN ('uploading', 'processing', 'completed', 'failed', 'partial', 'confirmed'));`

- [x] Task 2: API endpoint for confirming extraction results (AC: 6, 7, 8, 10)
  - [ ] 2.1: Add `confirmExtractionJob(authContext, jobId, { keptItemIds, metadataEdits })` to `apps/api/src/modules/extraction/service.js`. This method: (a) loads the job and verifies status is `'completed'` or `'partial'`, (b) validates `keptItemIds` are valid extraction_job_items IDs belonging to this job, (c) for each kept item, applies any metadata edits from the `metadataEdits` map (keyed by item ID), (d) creates a real `items` table record via `itemRepo.createItemFromExtraction()` with all metadata + `creation_method = 'ai_extraction'` + `extraction_job_id`, (e) updates job status to `'confirmed'`, (f) returns `{ confirmedCount, items }`.
  - [ ] 2.2: Add `createItemFromExtraction(authContext, { photoUrl, name, originalPhotoUrl, category, color, secondaryColors, pattern, material, style, season, occasion, bgRemovalStatus, categorizationStatus, creationMethod, extractionJobId })` to `apps/api/src/modules/items/repository.js`. This inserts into `items` with all provided fields including the new `creation_method` and `extraction_job_id` columns.
  - [ ] 2.3: Add route `POST /v1/extraction-jobs/:id/confirm` in `apps/api/src/main.js`. Request body: `{ keptItemIds: string[], metadataEdits?: { [itemId]: { name?, category?, color?, ... } } }`. Validates job ownership, status, and item IDs. Returns 200 with `{ confirmedCount, items }`. If `keptItemIds` is empty, still marks job as `'confirmed'` and returns `{ confirmedCount: 0, items: [] }`.
  - [ ] 2.4: Add `getExtractionItemsByIds(authContext, jobId, itemIds)` to `apps/api/src/modules/extraction/repository.js` for validating that requested item IDs belong to the specified job.

- [x] Task 3: API endpoint for duplicate detection (AC: 5)
  - [ ] 3.1: Add `checkDuplicates(authContext, jobId)` to `apps/api/src/modules/extraction/service.js`. This method: (a) loads extraction job items, (b) loads user's existing wardrobe items via `itemRepo.listItems(authContext, {})`, (c) for each extraction item, checks if any existing wardrobe item has matching `category` AND `color`, (d) returns `{ duplicates: [{ extractionItemId, matchingItemId, matchingItemPhotoUrl, matchingItemName }] }`.
  - [ ] 3.2: Add route `GET /v1/extraction-jobs/:id/duplicates` in `apps/api/src/main.js`. Returns the duplicate detection results. This is called once when the review screen loads.

- [x] Task 4: Mobile -- ExtractionProgressScreen (AC: 1, 2, 9)
  - [ ] 4.1: Create `apps/mobile/lib/src/features/wardrobe/screens/extraction_progress_screen.dart` as a `StatefulWidget`. Constructor accepts: `required String jobId`, `required ApiClient apiClient`. This screen polls `GET /v1/extraction-jobs/:id` every 3 seconds using a `Timer.periodic`.
  - [ ] 4.2: Display progress UI: job status text ("Processing photo X of Y..."), `LinearProgressIndicator(value: processedPhotos / totalPhotos)`, "Items found: N" counter, estimated time remaining text (calculated as `(totalPhotos - processedPhotos) * 6` seconds). Show a pulsing animation or `CircularProgressIndicator` alongside the text.
  - [ ] 4.3: When job status becomes `'completed'` or `'partial'`, stop polling and auto-navigate to `ExtractionReviewScreen` with the job data (items array).
  - [ ] 4.4: When job status becomes `'failed'`, stop polling and show error UI: error icon, "Extraction failed" message with `job.errorMessage` if available, and a "Retry" button that calls `apiClient.triggerExtractionProcessing(jobId)` and restarts polling.
  - [ ] 4.5: Back button behavior: show confirmation dialog "Processing will continue in the background. You can return to check progress later." On confirm, pop to wardrobe screen.

- [x] Task 5: Mobile -- ExtractionReviewScreen (AC: 3, 4, 5, 6, 8, 10)
  - [ ] 5.1: Create `apps/mobile/lib/src/features/wardrobe/screens/extraction_review_screen.dart` as a `StatefulWidget`. Constructor accepts: `required String jobId`, `required Map<String, dynamic> jobData`, `required ApiClient apiClient`. Manages a local state map of `{ itemId: { kept: bool, edits: Map } }` for each extraction item.
  - [ ] 5.2: Display extracted items in a scrollable list. Each item card shows: `Image.network(item.photoUrl)` thumbnail (80x80), category chip, color chip, Keep/Remove toggle (`Switch` widget, default: true/Keep). Show a header with "X items found" and "Y items selected" counters.
  - [ ] 5.3: On screen load, call `GET /v1/extraction-jobs/:id/duplicates` to fetch duplicate matches. For items with duplicates, overlay a "Possible duplicate" badge (amber warning icon). Tapping the badge opens a dialog showing side-by-side comparison: extraction item image + metadata vs existing wardrobe item image + metadata.
  - [ ] 5.4: Tapping an item card expands it (or navigates to an edit sub-screen) showing editable metadata fields: name (TextField, auto-generated as "${color} ${category}" if null), category (DropdownButton with taxonomy values), color (DropdownButton), pattern (DropdownButton), material (DropdownButton), style (DropdownButton), season (multi-select chips), occasion (multi-select chips). Changes are stored in local state, not sent to server until confirmation.
  - [ ] 5.5: "Add to Wardrobe" button at bottom (fixed, full-width, primary style: #4F46E5 background). When tapped: if zero items kept, show "No items selected. Discard all extracted items?" dialog. If items kept, call `POST /v1/extraction-jobs/:id/confirm` with `keptItemIds` and `metadataEdits`. On success, navigate back to WardrobeScreen and show SnackBar "X items added to your wardrobe!".
  - [ ] 5.6: "Select All" / "Deselect All" toggle in the header for quick batch operations.
  - [ ] 5.7: Semantics labels: "Extraction Review", "X items found, Y selected", "Keep item" / "Remove item" on each toggle, "Edit item metadata" on each card, "Possible duplicate warning", "Add to Wardrobe", "Select All", "Deselect All".

- [x] Task 6: Mobile -- Update BulkImportPreviewScreen navigation (AC: 1, 8)
  - [ ] 6.1: Update `apps/mobile/lib/src/features/wardrobe/screens/bulk_import_preview_screen.dart`: After successful job creation, navigate to `ExtractionProgressScreen(jobId: jobId, apiClient: apiClient)` instead of the current placeholder behavior (pop with SnackBar).
  - [ ] 6.2: Pass an `onImportComplete` callback that navigates back to WardrobeScreen with a refresh trigger.

- [x] Task 7: Mobile -- ApiClient methods for review flow (AC: 2, 5, 6)
  - [ ] 7.1: Add `Future<Map<String, dynamic>> confirmExtractionJob(String jobId, { required List<String> keptItemIds, Map<String, Map<String, dynamic>>? metadataEdits })` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `POST /v1/extraction-jobs/$jobId/confirm`.
  - [ ] 7.2: Add `Future<Map<String, dynamic>> getExtractionDuplicates(String jobId)` to ApiClient. Calls `GET /v1/extraction-jobs/$jobId/duplicates`.

- [x] Task 8: Mobile -- Update item repository/mappers for new fields (AC: 7, 8)
  - [ ] 8.1: Update `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`: Add `creationMethod` (String?) and `extractionJobId` (String?) fields. Update `fromJson` factory to parse these from API responses.
  - [ ] 8.2: Verify that items created via extraction appear correctly in the existing `WardrobeScreen` grid, `ItemDetailScreen`, and filter flows. The `creation_method` and `extraction_job_id` fields are informational -- they should not break existing UI.

- [x] Task 9: Widget tests for ExtractionProgressScreen (AC: 1, 2, 9)
  - [ ] 9.1: Create `apps/mobile/test/features/wardrobe/screens/extraction_progress_screen_test.dart`:
    - Screen renders progress indicator with correct status text and progress value.
    - Polling updates progress when mock API returns updated job data.
    - Auto-navigates to review screen when job completes.
    - Shows error UI with retry button when job fails.
    - Retry button re-triggers processing and restarts polling.
    - Back button shows confirmation dialog.
    - Estimated time remaining updates correctly.
    - Semantics labels present.

- [x] Task 10: Widget tests for ExtractionReviewScreen (AC: 3, 4, 5, 6, 8, 10)
  - [ ] 10.1: Create `apps/mobile/test/features/wardrobe/screens/extraction_review_screen_test.dart`:
    - Screen renders all extracted items with images, categories, and Keep toggles.
    - Toggling an item updates the selected count.
    - Duplicate warning badge appears for items with duplicates.
    - Tapping duplicate badge shows comparison dialog.
    - Tapping item card expands metadata editor with correct taxonomy dropdowns.
    - Editing metadata stores changes locally.
    - "Add to Wardrobe" calls confirm endpoint with correct keptItemIds and metadataEdits.
    - Confirmation success shows SnackBar and navigates to wardrobe.
    - Zero items selected shows discard confirmation dialog.
    - "Select All" / "Deselect All" toggle works.
    - Semantics labels present on all interactive elements.

- [x] Task 11: API tests for confirmation and duplicate endpoints (AC: 5, 6, 7, 10)
  - [ ] 11.1: Create `apps/api/test/modules/extraction/confirm-endpoint.test.js`:
    - `POST /v1/extraction-jobs/:id/confirm` creates real items for kept IDs.
    - Confirmed items have `creation_method = 'ai_extraction'` and `extraction_job_id` set.
    - Metadata edits are applied to confirmed items.
    - Job status updated to `'confirmed'`.
    - Empty `keptItemIds` still marks job confirmed with zero items.
    - 404 for non-existent job, 400 for invalid item IDs, 401 for unauthenticated.
    - Cannot confirm a job that is still `'processing'` (returns 400).
  - [ ] 11.2: Test `GET /v1/extraction-jobs/:id/duplicates`:
    - Returns duplicates array matching extraction items by category+color.
    - Returns empty array when no duplicates found.
    - 404 for non-existent job.
  - [ ] 11.3: Test `createItemFromExtraction` repository method: inserts item with creation_method and extraction_job_id.
  - [ ] 11.4: Test `getExtractionItemsByIds` repository method: returns only items matching provided IDs within the job.

- [x] Task 12: Update BulkImportPreviewScreen tests (AC: 1)
  - [ ] 12.1: Update `apps/mobile/test/features/wardrobe/screens/bulk_import_preview_screen_test.dart`: Verify that after successful job creation, navigation goes to ExtractionProgressScreen (not just a SnackBar pop).

- [x] Task 13: Regression testing (AC: all)
  - [ ] 13.1: Run `flutter analyze` -- zero new issues.
  - [ ] 13.2: Run `flutter test` -- all existing 1476+ tests plus new tests pass.
  - [ ] 13.3: Run `npm --prefix apps/api test` -- all existing 1046+ API tests plus new tests pass.
  - [ ] 13.4: Verify existing single-item upload flow (AddItemScreen) still works -- camera, gallery, bg removal, categorization all unaffected.
  - [ ] 13.5: Verify existing wardrobe grid, filtering, and item detail views show extraction-created items correctly alongside manual items.
  - [ ] 13.6: Verify existing extraction job creation (Story 10.1) and processing (Story 10.2) flows are unaffected.
  - [ ] 13.7: Verify items created via extraction appear in outfit generation, wear logging, and analytics (they are normal `items` records).

## Dev Notes

- This is the FINAL story in Epic 10 (AI Wardrobe Extraction / Bulk Import). Story 10.1 built photo selection, upload, and job creation. Story 10.2 built the server-side AI processing pipeline (detection, categorization, background removal). This story closes the loop by building the mobile progress tracking UI, the review/confirm flow, duplicate detection, and the promotion of staged extraction items into real wardrobe items.
- The `extraction_job_items` table (migration 032, Story 10.2) stores staged items that are NOT yet in the main `items` table. This story adds the "confirmation" step that promotes kept items to the `items` table with `creation_method = 'ai_extraction'` and `extraction_job_id`.
- The existing `items` table does NOT have `creation_method` or `extraction_job_id` columns. Migration 033 adds these. Default `creation_method` is `'manual'` so all existing items remain backward-compatible.
- The items repository already has `createItem(authContext, { photoUrl, name, originalPhotoUrl, bgRemovalStatus, categorizationStatus })`. This story adds `createItemFromExtraction()` which accepts additional fields: `creation_method`, `extraction_job_id`, plus all taxonomy fields (category, color, etc.) so they are set on INSERT rather than via separate AI pipeline calls (since extraction already ran AI in Story 10.2).
- The `wardrobe_extraction_jobs.status` CHECK constraint currently allows: `'uploading'`, `'processing'`, `'completed'`, `'failed'`, `'partial'`. This story adds `'confirmed'` via migration 034 to track that the user has reviewed and confirmed the extraction results.
- Duplicate detection is a simple category+color match against existing wardrobe items. This is NOT a visual similarity search -- just metadata comparison. It runs once when the review screen loads. Future improvements could use image embeddings for visual matching, but that is out of scope.
- The review screen stores all edit state locally (Flutter state) until the user taps "Add to Wardrobe". Only then does a single API call send all kept item IDs and metadata edits. This minimizes network calls and allows quick undo/redo of decisions.
- Polling interval: 3 seconds is a good balance between responsiveness and server load. For a 20-photo job (~2 min processing), that's about 40 polls max. The `GET /v1/extraction-jobs/:id` endpoint is lightweight (single DB query with RLS).
- Estimated time remaining: `(totalPhotos - processedPhotos) * 6` seconds. The 6-second-per-photo estimate comes from Story 10.2's pipeline timing (detection ~3s + bg removal ~2s + categorization ~1s).
- Auto-generated item names: When extraction items have no name, generate one from `"${color} ${category}"` (e.g., "Blue Tops" -> "Blue Top", "Black Outerwear" -> "Black Outerwear"). This gives users a default they can edit.

### Project Structure Notes

- New files:
  - `infra/sql/migrations/033_items_creation_method.sql`
  - `infra/sql/migrations/034_extraction_job_confirmed_status.sql`
  - `apps/mobile/lib/src/features/wardrobe/screens/extraction_progress_screen.dart`
  - `apps/mobile/lib/src/features/wardrobe/screens/extraction_review_screen.dart`
  - `apps/mobile/test/features/wardrobe/screens/extraction_progress_screen_test.dart`
  - `apps/mobile/test/features/wardrobe/screens/extraction_review_screen_test.dart`
  - `apps/api/test/modules/extraction/confirm-endpoint.test.js`
- Modified files:
  - `apps/api/src/modules/extraction/service.js` (add `confirmExtractionJob`, `checkDuplicates`)
  - `apps/api/src/modules/extraction/repository.js` (add `getExtractionItemsByIds`)
  - `apps/api/src/modules/items/repository.js` (add `createItemFromExtraction`)
  - `apps/api/src/main.js` (add POST /v1/extraction-jobs/:id/confirm and GET /v1/extraction-jobs/:id/duplicates routes)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `confirmExtractionJob`, `getExtractionDuplicates`)
  - `apps/mobile/lib/src/features/wardrobe/screens/bulk_import_preview_screen.dart` (update navigation to ExtractionProgressScreen)
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (add `creationMethod`, `extractionJobId` fields)
  - `apps/mobile/test/features/wardrobe/screens/bulk_import_preview_screen_test.dart` (update navigation expectations)
- Alignment with architecture: Epic 10 maps to `mobile/features/wardrobe`, `api/modules/ai`, `api/jobs/extraction` (architecture.md). The mobile screens live in `features/wardrobe/screens/` since extraction is a wardrobe sub-feature. API changes extend the existing extraction module.

### Technical Requirements

- Polling uses `Timer.periodic(Duration(seconds: 3), ...)` in a `StatefulWidget`. Cancel the timer in `dispose()` and when job reaches terminal status.
- The review screen must handle potentially large item lists (up to 250 items: 50 photos x 5 items each). Use `ListView.builder` with efficient image loading (consider `CachedNetworkImage` if available, or `Image.network` with `cacheWidth`/`cacheHeight` constraints).
- Taxonomy dropdown values must use the SAME constants as the existing item editing flow. Import from the shared taxonomy constants used in `review_item_screen.dart` and `add_item_screen.dart`.
- The `POST /v1/extraction-jobs/:id/confirm` endpoint must be transactional: if creating any item fails, the entire confirmation should roll back (no partial state).
- The `creation_method` column default is `'manual'` so all 1000+ existing items automatically get the correct value without a data migration.

### Architecture Compliance

- Items created via extraction go through the standard `items` table with proper RLS. They are first-class wardrobe items indistinguishable from manually added items (except for the `creation_method` and `extraction_job_id` metadata).
- No new AI calls in this story. All AI processing was completed in Story 10.2. This story only reads and promotes the results.
- RLS is enforced on all new queries. The confirmation endpoint uses the same auth pattern as all other extraction endpoints.
- Media URLs from extraction items are already stored in Cloud Storage (from Story 10.2). The confirm endpoint copies the `photo_url` from `extraction_job_items` to `items` -- no re-upload needed.
- The duplicate detection query runs against the user's own items only (RLS-scoped).

### Library / Framework Requirements

- No new dependencies. All required packages are already installed:
  - `image_picker: ^1.1.2` (Flutter, already in pubspec.yaml)
  - `http` (Flutter, for API calls via ApiClient)
  - `pg` (API, for database operations)
  - Existing extraction module for job management
  - Existing items module for item creation
- Mobile: No new packages. Timer.periodic is from `dart:async` (built-in).

### File Structure Requirements

- Mobile screens go in `apps/mobile/lib/src/features/wardrobe/screens/` following established pattern.
- Migration files: 033, 034 (after existing 032_extraction_job_items.sql from Story 10.2).
- API test file: `confirm-endpoint.test.js` in existing `apps/api/test/modules/extraction/` directory.
- The extraction review screen is a separate screen from the progress screen. Both are in the wardrobe screens directory.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns from `apps/api/test/modules/extraction/`.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient. Use `tester.runAsync()` for timer-based tests.
- Mock `Timer.periodic` in progress screen tests by using `fakeAsync` and `tick()` to advance time.
- Test the complete flow: progress screen -> polling -> auto-transition to review -> edit metadata -> confirm -> navigate to wardrobe.
- Test edge cases: job fails, retry works, zero items kept, all items have duplicates, metadata edits with taxonomy validation.
- Test baselines (from Story 10.2): 1046 API tests, 1476 Flutter tests.

### Previous Story Intelligence

- **Story 10.2** (done, predecessor): Created `extraction_job_items` table (migration 032), `processing-service.js`, auto-trigger processing on job creation, `POST /v1/extraction-jobs/:id/process` endpoint, repository methods `addJobItem`, `getJobItems`, `updatePhotoStatus`. `getJob()` now returns items array. 1046 API tests, 1476 Flutter tests. **This story picks up where 10.2 left off.**
- **Story 10.1** (done): Created `wardrobe_extraction_jobs` and `extraction_job_photos` tables, `BulkImportPreviewScreen` (needs navigation update), extraction module with repository + service, API endpoints for job creation and retrieval, ApiClient methods. The BulkImportPreviewScreen currently navigates to a placeholder -- this story replaces that with `ExtractionProgressScreen`.
- **Story 2.4** (done): Established `review_item_screen.dart` with metadata editing UI (taxonomy dropdowns, multi-select chips for season/occasion). The extraction review screen's metadata editing should follow the same UX patterns and use the same taxonomy constants.
- **Story 2.6** (done): Established `ItemDetailScreen` which displays all item fields. Extraction-created items will appear in this screen unchanged.
- **Story 8.3** (done): Established `review_extracted_product_screen.dart` for shopping scan review. This is a similar "review AI results before saving" pattern. The extraction review screen can reference this for UX consistency (card layout, keep/remove toggles).
- **Key pattern -- item creation**: `itemRepo.createItem(authContext, { photoUrl, name, originalPhotoUrl, bgRemovalStatus, categorizationStatus })` in `items/repository.js`. The new `createItemFromExtraction` method extends this with additional columns.
- **Key pattern -- mapItemRow**: `items/repository.js` has `mapItemRow(row)` that maps all item columns to camelCase. Must update to include `creationMethod` and `extractionJobId`.
- **Key pattern -- route wiring**: Routes in `main.js` use `if (method === 'POST' && url.pathname.match(...))` pattern. Add confirm route near existing extraction routes.
- **Key pattern -- taxonomy constants**: Imported from `apps/api/src/modules/ai/taxonomy.js`. Use the same VALID_CATEGORIES, VALID_COLORS, etc. for validating metadata edits in the confirm endpoint.
- **Key pattern -- Flutter screen navigation**: Use `Navigator.pushReplacement` when transitioning from progress to review (no back to progress screen). Use `Navigator.popUntil` to return to WardrobeScreen after confirmation.

### Key Anti-Patterns to Avoid

- DO NOT make new AI calls in this story. All AI processing was completed in Story 10.2. This story only reads results and promotes items.
- DO NOT re-upload images. The `photo_url` from `extraction_job_items` is already in Cloud Storage. Copy the URL to the new `items` record directly.
- DO NOT create a new item service. Extend the existing `items/repository.js` with `createItemFromExtraction()`.
- DO NOT modify the existing `createItem()` or `createItemForUser()` methods. The extraction flow uses a separate creation path that skips bg removal / categorization (already done).
- DO NOT use WebSocket or SSE for progress updates. Simple polling at 3-second intervals is sufficient for this use case and consistent with the architecture.
- DO NOT implement visual similarity search for duplicate detection. Use simple category+color metadata matching only. Visual matching is out of scope.
- DO NOT store metadata edits on the server during review. Keep them in Flutter state until the final "Add to Wardrobe" action.
- DO NOT allow confirming a job that is still `'processing'`. The confirm endpoint must validate that job status is `'completed'` or `'partial'`.
- DO NOT modify the existing wardrobe grid, filtering, or detail screens. Extraction-created items are standard `items` rows -- they just happen to have extra metadata fields.
- DO NOT use `Navigator.push` from progress to review. Use `Navigator.pushReplacement` so the user cannot go back to a stale progress screen.

### Implementation Guidance

- **ExtractionProgressScreen polling:**
  ```dart
  Timer? _pollTimer;
  Map<String, dynamic>? _jobData;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final job = await widget.apiClient.getExtractionJob(widget.jobId);
      setState(() { _jobData = job; });
      if (['completed', 'partial', 'failed'].contains(job['status'])) {
        _pollTimer?.cancel();
        if (job['status'] != 'failed') _navigateToReview(job);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
  ```

- **Estimated time remaining:**
  ```dart
  String _estimatedTimeRemaining(Map<String, dynamic> job) {
    final remaining = (job['totalPhotos'] - job['processedPhotos']) * 6;
    if (remaining <= 0) return 'Almost done...';
    if (remaining < 60) return '~$remaining seconds remaining';
    return '~${(remaining / 60).ceil()} minutes remaining';
  }
  ```

- **Confirm endpoint handler in main.js:**
  ```javascript
  if (method === 'POST' && url.pathname.match(/^\/v1\/extraction-jobs\/[^/]+\/confirm$/)) {
    const jobId = url.pathname.split('/')[3];
    const { keptItemIds, metadataEdits } = body;
    const result = await extractionService.confirmExtractionJob(
      authContext, jobId, { keptItemIds: keptItemIds || [], metadataEdits: metadataEdits || {} }
    );
    return sendJson(res, 200, result);
  }
  ```

- **createItemFromExtraction in items/repository.js:**
  ```javascript
  async createItemFromExtraction(authContext, {
    photoUrl, name, originalPhotoUrl, category, color, secondaryColors,
    pattern, material, style, season, occasion,
    bgRemovalStatus, categorizationStatus, creationMethod, extractionJobId
  }) {
    // Same transaction pattern as createItem but with additional columns
    // INSERT INTO app_public.items (profile_id, photo_url, name, original_photo_url,
    //   bg_removal_status, categorization_status, category, color, secondary_colors,
    //   pattern, material, style, season, occasion, creation_method, extraction_job_id)
    // VALUES ($1, $2, ..., $15, $16) RETURNING *
  }
  ```

- **Duplicate detection query:**
  ```javascript
  async checkDuplicates(authContext, jobId) {
    // 1. Get all extraction items for this job
    const extractionItems = await extractionRepo.getJobItems(authContext, jobId);
    // 2. Get all user's wardrobe items
    const { items: wardrobeItems } = await itemService.listItemsForUser(authContext, {});
    // 3. Match by category + color
    const duplicates = [];
    for (const ei of extractionItems) {
      const match = wardrobeItems.find(wi =>
        wi.category === ei.category && wi.color === ei.color
      );
      if (match) {
        duplicates.push({
          extractionItemId: ei.id,
          matchingItemId: match.id,
          matchingItemPhotoUrl: match.photoUrl,
          matchingItemName: match.name
        });
      }
    }
    return { duplicates };
  }
  ```

- **Review screen Keep/Remove toggle:**
  ```dart
  Switch(
    value: _keepState[item['id']] ?? true,
    onChanged: (val) => setState(() { _keepState[item['id']] = val; }),
    activeColor: const Color(0xFF4F46E5),
    semanticLabel: val ? 'Keep item' : 'Remove item',
  )
  ```

- **Navigation from progress to review:**
  ```dart
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => ExtractionReviewScreen(
        jobId: widget.jobId,
        jobData: jobData,
        apiClient: widget.apiClient,
      ),
    ),
  );
  ```

- **Navigation after confirmation back to wardrobe:**
  ```dart
  Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == '/wardrobe');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$confirmedCount items added to your wardrobe!')),
  );
  ```

- **Update mapItemRow in items/repository.js:**
  Add to existing mapItemRow: `creationMethod: row.creation_method ?? 'manual'`, `extractionJobId: row.extraction_job_id ?? null`.

### References

- [Source: epics.md - Story 10.3: Extraction Progress & Review Flow]
- [Source: epics.md - Epic 10: AI Wardrobe Extraction (Bulk Import)]
- [Source: architecture.md - Data Architecture: items table, wardrobe_extraction_jobs]
- [Source: architecture.md - AI Orchestration: taxonomy validation, safe defaults]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 10 -> mobile/features/wardrobe, api/modules/ai, api/jobs/extraction]
- [Source: architecture.md - Media and Storage: signed URLs, private buckets]
- [Source: prd.md - FR-EXT-05: Users shall review all extracted items in a confirmation screen before adding to wardrobe]
- [Source: prd.md - FR-EXT-06: Each extracted item shall have Keep/Remove toggles and editable metadata]
- [Source: prd.md - FR-EXT-07: The system shall display extraction progress with status updates and estimated time remaining]
- [Source: prd.md - FR-EXT-09: Items created via extraction shall be tagged with creation_method = 'ai_extraction' and linked to source photo]
- [Source: prd.md - FR-EXT-10: The system shall detect potential duplicate items during extraction and warn the user]
- [Source: ux-design-specification.md - Wardrobe Digitization Flow: Bulk Import -> Review -> Save]
- [Source: 10-1-bulk-photo-gallery-selection.md - BulkImportPreviewScreen, extraction module, API endpoints, ApiClient methods]
- [Source: 10-2-bulk-extraction-processing.md - extraction_job_items table, processing pipeline, getJob includes items, 1046 API tests, 1476 Flutter tests]
- [Source: 2-4-manual-metadata-editing-creation.md - taxonomy constants, review_item_screen.dart metadata editing patterns]
- [Source: 8-3-review-extracted-product-data.md - Similar review-before-save UX pattern]
- [Source: items/repository.js - createItem, mapItemRow patterns for extending with new columns]
- [Source: items/service.js - taxonomy validation for metadata edits (VALID_CATEGORIES, VALID_COLORS, etc.)]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None required.

### Completion Notes List

- Task 1: Created migrations 033 (items.creation_method + extraction_job_id) and 034 (extraction_jobs 'confirmed' status).
- Task 2: Implemented `confirmExtractionJob` service method with transactional item creation, metadata edit application, and auto-generated names. Added `createItemFromExtraction` to items repository. Added `getExtractionItemsByIds` to extraction repository. Wired POST /v1/extraction-jobs/:id/confirm route.
- Task 3: Implemented `checkDuplicates` service method with category+color matching. Wired GET /v1/extraction-jobs/:id/duplicates route.
- Task 4: Created ExtractionProgressScreen with 3-second Timer.periodic polling, LinearProgressIndicator, estimated time remaining, auto-navigate to review on completion, error UI with retry, back button confirmation dialog.
- Task 5: Created ExtractionReviewScreen with scrollable item list, Keep/Remove Switch toggles, Select All/Deselect All, duplicate warning badges with comparison dialog, expandable metadata editor (name, category, color, pattern, material, style, season, occasion), "Add to Wardrobe" confirmation with zero-item discard dialog, SnackBar success feedback.
- Task 6: Updated BulkImportPreviewScreen to navigate to ExtractionProgressScreen via pushReplacement after successful job creation.
- Task 7: Added `confirmExtractionJob` and `getExtractionDuplicates` to ApiClient.
- Task 8: Added `creationMethod` and `extractionJobId` fields to WardrobeItem model with fromJson parsing. Fields are informational and do not break existing UI.
- Task 9: Created 8 widget tests for ExtractionProgressScreen covering progress display, polling, auto-navigation, error/retry, back dialog, time estimation, semantics.
- Task 10: Created 9 widget tests for ExtractionReviewScreen covering item rendering, toggle count, duplicates, metadata editor, confirm endpoint, discard dialog, select all, semantics.
- Task 11: Created 13 API tests for confirm and duplicates endpoints covering success/error/auth/validation scenarios.
- Task 12: Updated 2 BulkImportPreviewScreen tests to verify navigation to ExtractionProgressScreen instead of onImportComplete callback.
- Task 13: Full regression passed. flutter analyze: 15 issues (all pre-existing, 0 new). flutter test: 1493 pass (1476 baseline + 17 new). npm test: 1059 pass (1046 baseline + 13 new). Existing mapItemRow updated to include creationMethod/extractionJobId with backwards-compatible defaults.

### Change Log

- 2026-03-19: Implemented Story 10.3 -- Extraction Progress & Review Flow (all 13 tasks, all ACs satisfied)

### File List

**New files:**
- infra/sql/migrations/033_items_creation_method.sql
- infra/sql/migrations/034_extraction_job_confirmed_status.sql
- apps/mobile/lib/src/features/wardrobe/screens/extraction_progress_screen.dart
- apps/mobile/lib/src/features/wardrobe/screens/extraction_review_screen.dart
- apps/mobile/test/features/wardrobe/screens/extraction_progress_screen_test.dart
- apps/mobile/test/features/wardrobe/screens/extraction_review_screen_test.dart
- apps/api/test/modules/extraction/confirm-endpoint.test.js

**Modified files:**
- apps/api/src/modules/extraction/service.js
- apps/api/src/modules/extraction/repository.js
- apps/api/src/modules/items/repository.js
- apps/api/src/main.js
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/wardrobe/screens/bulk_import_preview_screen.dart
- apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart
- apps/mobile/test/features/wardrobe/screens/bulk_import_preview_screen_test.dart
