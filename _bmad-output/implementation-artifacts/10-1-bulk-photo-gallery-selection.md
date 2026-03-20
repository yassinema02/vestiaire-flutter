# Story 10.1: Bulk Photo Gallery Selection

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to select multiple photos at once from my camera roll,
So that I can batch process images containing my clothes.

## Acceptance Criteria

1. Given I am on the Wardrobe tab, when I look at the screen actions, then I see a "Bulk Import" button (alongside the existing "Add Item" flow) that launches the bulk import flow. (FR-EXT-01)

2. Given I tap "Bulk Import", when the native multi-image gallery picker opens, then I can select up to 50 photos from my device gallery using `ImagePicker.pickMultiImage()`. (FR-EXT-01)

3. Given I am selecting photos in the native gallery picker, when I have selected some photos, then the picker respects the platform's native multi-select UI (checkmarks, counter). If the user selects more than 50 photos, the app truncates to the first 50 and shows a SnackBar: "Maximum 50 photos. Only the first 50 were selected." (FR-EXT-01)

4. Given I have selected photos and returned to the app, when the selection is confirmed, then the app displays a "Bulk Import Preview" screen showing thumbnails of all selected photos in a scrollable grid with the total count displayed prominently (e.g., "12 photos selected"). (FR-EXT-01)

5. Given I am on the Bulk Import Preview screen, when I review my selections, then I can deselect individual photos by tapping them (toggle off), and the count updates accordingly. (FR-EXT-01)

6. Given I am on the Bulk Import Preview screen, when I tap "Start Import", then the app compresses each selected photo (maxWidth: 512, imageQuality: 85 -- same as single-item upload), uploads all photos to Cloud Storage via the signed URL pattern, and creates a `wardrobe_extraction_job` record on the server via `POST /v1/extraction-jobs`. (FR-EXT-01, FR-EXT-08)

7. Given the upload process begins, when photos are being uploaded, then a progress indicator shows "Uploading X of Y photos..." with a progress bar. Individual photo failures do not block the entire batch -- failed photos are skipped with a warning, and the job proceeds with successfully uploaded photos. (FR-EXT-01, FR-EXT-07)

8. Given all photos are uploaded and the extraction job is created, when the server responds with the job ID, then the user is navigated to the extraction status screen (placeholder for Story 10.3) showing "Processing... This may take a few minutes" with the job ID stored locally for tracking. (FR-EXT-07, FR-EXT-08)

9. Given I am on the Bulk Import Preview screen, when I tap the back button or "Cancel", then I return to the Wardrobe tab with no side effects (no uploads, no job created). (FR-EXT-01)

10. Given I have no photos in my gallery or deny photo library permission, when I tap "Bulk Import", then the app shows a graceful message explaining the issue and suggesting to grant access in Settings. (FR-EXT-01)

## Tasks / Subtasks

- [x] Task 1: Database migration for `wardrobe_extraction_jobs` table (AC: 6, 8)
  - [x] 1.1: Create `infra/sql/migrations/030_wardrobe_extraction_jobs.sql`: CREATE TABLE `app_public.wardrobe_extraction_jobs` with columns: `id` UUID PK DEFAULT gen_random_uuid(), `profile_id` UUID NOT NULL FK to profiles ON DELETE CASCADE, `status` TEXT NOT NULL CHECK (status IN ('uploading', 'processing', 'completed', 'failed', 'partial')) DEFAULT 'uploading', `total_photos` INTEGER NOT NULL, `uploaded_photos` INTEGER NOT NULL DEFAULT 0, `processed_photos` INTEGER NOT NULL DEFAULT 0, `total_items_found` INTEGER NOT NULL DEFAULT 0, `error_message` TEXT, `created_at` TIMESTAMPTZ DEFAULT NOW(), `updated_at` TIMESTAMPTZ DEFAULT NOW(). Add index on `(profile_id, created_at DESC)`.
  - [x] 1.2: Create `infra/sql/migrations/031_extraction_job_photos.sql`: CREATE TABLE `app_public.extraction_job_photos` with columns: `id` UUID PK DEFAULT gen_random_uuid(), `job_id` UUID NOT NULL FK to wardrobe_extraction_jobs ON DELETE CASCADE, `photo_url` TEXT NOT NULL, `original_filename` TEXT, `status` TEXT NOT NULL CHECK (status IN ('uploaded', 'processing', 'completed', 'failed')) DEFAULT 'uploaded', `items_found` INTEGER NOT NULL DEFAULT 0, `error_message` TEXT, `created_at` TIMESTAMPTZ DEFAULT NOW(). Add index on `(job_id)`.
  - [x] 1.3: Create `infra/sql/policies/005_extraction_jobs_rls.sql`: Enable RLS on both tables. SELECT/INSERT/UPDATE/DELETE policy where `profile_id` matches authenticated user's profile (same pattern as items RLS in `003_items_rls.sql`). For `extraction_job_photos`, policy uses a subquery joining to `wardrobe_extraction_jobs.profile_id`.

- [x] Task 2: API endpoint for creating extraction jobs (AC: 6, 7, 8)
  - [x] 2.1: Create `apps/api/src/modules/extraction/repository.js`: Export `createExtractionRepository({ pool })` with methods: `createJob(authContext, { totalPhotos })` returns the new job row; `getJob(authContext, jobId)` returns the job with RLS; `updateJobStatus(authContext, jobId, { status, uploadedPhotos, processedPhotos, totalItemsFound, errorMessage })` updates job fields; `addJobPhoto(authContext, { jobId, photoUrl, originalFilename })` inserts into `extraction_job_photos`.
  - [x] 2.2: Create `apps/api/src/modules/extraction/service.js`: Export `createExtractionService({ extractionRepo })` with method `createExtractionJob(authContext, { totalPhotos, photos })` that: (a) creates the job record, (b) inserts each photo record, (c) updates job status to 'processing', (d) returns the job with photos. The actual AI processing (item detection, categorization, background removal) is deferred to Story 10.2.
  - [x] 2.3: Add route `POST /v1/extraction-jobs` in `apps/api/src/main.js`. Request body: `{ totalPhotos: number, photos: [{ photoUrl: string, originalFilename?: string }] }`. Validates: `totalPhotos` matches `photos.length`, `totalPhotos` between 1 and 50. Returns 201 with `{ job: { id, status, totalPhotos, ... } }`.
  - [x] 2.4: Add route `GET /v1/extraction-jobs/:id` in `apps/api/src/main.js`. Returns the job with all photo records. 404 if not found or not owned by user (RLS enforced).
  - [x] 2.5: Wire up `extractionRepository` and `extractionService` in `createRuntime()` in `main.js`.

- [x] Task 3: API endpoint for bulk signed URL generation (AC: 6, 7)
  - [x] 3.1: Add route `POST /v1/uploads/signed-urls` (note: plural) in `apps/api/src/main.js`. Request body: `{ purposes: [{ purpose: "extraction_photo", index: number }], count: number }`. Validates count between 1 and 50. Returns `{ urls: [{ index, uploadUrl, publicUrl }] }`. This reuses the existing `uploadService.generateSignedUploadUrl()` but calls it N times. The upload path pattern is `users/{uid}/extractions/{jobId}/{uuid}.jpg`.
  - [x] 3.2: Update `apps/api/src/modules/uploads/service.js` to accept `purpose: "extraction_photo"` as a valid purpose alongside `"item_photo"`. The extraction path pattern uses a subfolder under the user's directory.

- [x] Task 4: Mobile -- Bulk Import entry point on Wardrobe screen (AC: 1, 10)
  - [x] 4.1: Update `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`: Add a "Bulk Import" action button in the AppBar (or as a secondary FAB/action alongside the existing add flow). Use `Icons.photo_library_outlined` icon with label "Bulk Import". Tapping it launches the `BulkImportPreviewScreen`.
  - [x] 4.2: Before launching the bulk import flow, call `ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 512)`. If the result is null or empty, do nothing. If more than 50 images returned, truncate to 50 and show SnackBar warning.
  - [x] 4.3: Handle `PlatformException` for photo library permission denied: show SnackBar with "Photo library access required. Please grant access in Settings."

- [x] Task 5: Mobile -- BulkImportPreviewScreen (AC: 4, 5, 6, 7, 8, 9)
  - [x] 5.1: Create `apps/mobile/lib/src/features/wardrobe/screens/bulk_import_preview_screen.dart` as a `StatefulWidget`. Constructor accepts: `required List<String> photoPaths`, `required ApiClient apiClient`, `VoidCallback? onImportComplete`. Displays a scrollable grid of selected photo thumbnails with a header showing "X photos selected".
  - [x] 5.2: Each photo in the grid is wrapped with a tappable overlay. Tapping a photo toggles its selection (deselected photos show a semi-transparent grey overlay with a deselected icon). The count in the header updates dynamically. If all photos are deselected, the "Start Import" button is disabled.
  - [x] 5.3: Add a "Start Import" button at the bottom (fixed position, full width, Vibrant Soft-UI primary style: #4F46E5 background, white text, 50px height, 12px radius). When tapped, trigger the upload flow.
  - [x] 5.4: Implement the upload flow: (a) Show a modal progress overlay with "Uploading X of Y photos..." and a `LinearProgressIndicator`. (b) Call `POST /v1/uploads/signed-urls` with count = number of selected photos. (c) For each photo, read the file, upload to the signed URL via `apiClient.uploadImage()`. Update progress after each upload. (d) If an individual upload fails, mark it as failed, log the error, and continue with remaining photos. (e) After all uploads complete, call `POST /v1/extraction-jobs` with the successfully uploaded photo URLs. (f) On success, invoke `onImportComplete` callback and navigate to an "Import Started" confirmation screen (or pop back with success SnackBar for now, pending Story 10.3 for the full progress/review screen).
  - [x] 5.5: Cancel/back button: if upload is not in progress, simply pop the screen. If upload IS in progress, show a confirmation dialog: "Cancel import? Uploaded photos will be discarded." On confirm, cancel remaining uploads and pop.
  - [x] 5.6: Semantics labels: "Bulk Import Preview", "X photos selected", "Toggle photo selection" on each photo, "Start Import", "Cancel Import".

- [x] Task 6: Mobile -- ApiClient methods for bulk operations (AC: 6, 7, 8)
  - [x] 6.1: Add `Future<List<Map<String, dynamic>>> getBulkSignedUploadUrls({ required int count })` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `POST /v1/uploads/signed-urls` with `{ purposes: List.generate(count, (i) => { "purpose": "extraction_photo", "index": i }), count: count }`. Returns the list of `{ index, uploadUrl, publicUrl }` maps.
  - [x] 6.2: Add `Future<Map<String, dynamic>> createExtractionJob({ required int totalPhotos, required List<Map<String, String>> photos })` to ApiClient. Calls `POST /v1/extraction-jobs`. Returns the job map.
  - [x] 6.3: Add `Future<Map<String, dynamic>> getExtractionJob(String jobId)` to ApiClient. Calls `GET /v1/extraction-jobs/:id`. Returns the job map with photos.

- [x] Task 7: Widget tests for BulkImportPreviewScreen (AC: 2, 3, 4, 5, 6, 7, 8, 9, 10)
  - [x] 7.1: Create `apps/mobile/test/features/wardrobe/screens/bulk_import_preview_screen_test.dart`:
    - Screen renders photo grid with correct count header.
    - Tapping a photo toggles its selection (deselected overlay appears/disappears).
    - Count header updates when photos are toggled.
    - "Start Import" button is disabled when all photos deselected.
    - Upload flow: mock `getBulkSignedUploadUrls` and `uploadImage` and `createExtractionJob`. Verify progress indicator appears. Verify `onImportComplete` is called on success.
    - Upload failure: individual photo failure does not block entire batch. SnackBar warning shown for failed photos.
    - Cancel during upload shows confirmation dialog.
    - Back button pops screen when not uploading.
    - Semantics labels present on all interactive elements.

- [x] Task 8: Widget tests for Wardrobe screen Bulk Import entry (AC: 1, 10)
  - [x] 8.1: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`:
    - "Bulk Import" button is visible on the wardrobe screen.
    - Tapping "Bulk Import" calls `ImagePicker.pickMultiImage`.
    - When picker returns > 50 images, truncation SnackBar is shown.
    - When picker returns empty list, no navigation occurs.
    - When picker throws `PlatformException`, permission error SnackBar shown.

- [x] Task 9: API tests for extraction endpoints (AC: 6, 7, 8)
  - [x] 9.1: Create `apps/api/test/modules/extraction/repository.test.js`: Test `createJob`, `getJob`, `updateJobStatus`, `addJobPhoto`. Test RLS prevents access to other users' jobs.
  - [x] 9.2: Create `apps/api/test/modules/extraction/service.test.js`: Test `createExtractionJob` creates job and photo records, returns correct structure.
  - [x] 9.3: Test `POST /v1/extraction-jobs` endpoint: validates totalPhotos (1-50), validates photos array, returns 201 with job. Test 401 for unauthenticated.
  - [x] 9.4: Test `GET /v1/extraction-jobs/:id` endpoint: returns job with photos, 404 for non-existent or other user's job.
  - [x] 9.5: Test `POST /v1/uploads/signed-urls` endpoint: returns correct number of signed URLs, validates count (1-50).

- [x] Task 10: Regression testing (AC: all)
  - [x] 10.1: Run `flutter analyze` -- zero issues.
  - [x] 10.2: Run `flutter test` -- all existing 1459+ tests plus new tests pass.
  - [x] 10.3: Run `npm --prefix apps/api test` -- all existing 989+ API tests plus new tests pass.
  - [x] 10.4: Verify existing AddItemScreen single-photo upload flow still works (camera + gallery paths unchanged).
  - [x] 10.5: Verify existing wardrobe grid, filtering, and item detail views are unaffected.

## Dev Notes

- This is the FIRST story in Epic 10 (AI Wardrobe Extraction / Bulk Import). It focuses ONLY on the client-side photo selection, upload to cloud storage, and creation of the extraction job record on the server. The actual AI processing (item detection, categorization, background removal per extracted item) is Story 10.2. The progress tracking and review/confirm flow is Story 10.3.
- The `image_picker` package (already installed at `^1.1.2`) supports `pickMultiImage()` for selecting multiple photos from the gallery. This returns a `List<XFile>`. It does NOT support multi-select from the camera. The `imageQuality` and `maxWidth` parameters work the same as `pickImage`.
- The existing single-item upload uses `ImagePicker.pickImage()` with `ImageSource.gallery` (one photo). This story uses `ImagePicker.pickMultiImage()` (multiple photos). These are different methods on the same package -- no new dependency needed.
- The `image_picker` package's `pickMultiImage()` does NOT enforce a maximum count natively. The 50-photo limit must be enforced client-side after the picker returns. If the user selects more than 50, truncate the list and show a warning.
- Photo compression follows the SAME pattern as Story 2.1: `maxWidth: 512, imageQuality: 85`. The `pickMultiImage` method accepts the same compression parameters. This produces JPEG files suitable for upload.
- The upload pipeline per photo follows the SAME 3-step signed URL pattern from Story 2.1: (1) get signed URL, (2) upload image bytes to signed URL, (3) record the public URL. For bulk, we batch the signed URL requests into a single `POST /v1/uploads/signed-urls` call for efficiency.
- The `wardrobe_extraction_jobs` table is a NEW table. It does NOT exist yet. The next migration number is 030 (after 029_social_notification_mode.sql).
- The extraction module (`apps/api/src/modules/extraction/`) is NEW and does not yet exist. It follows the same repository + service pattern as other modules (items, squads, shopping, etc.).
- This story creates the extraction job with status `'uploading'` -> `'processing'` but does NOT implement the actual AI processing. Story 10.2 will add the background processing pipeline that reads from `extraction_job_photos` and uses Gemini to detect/extract individual items from each photo.
- Story 10.3 will add the mobile progress tracking screen (polling the job status) and the review/confirm flow where users toggle Keep/Remove on extracted items.

### Project Structure Notes

- New directories:
  - `apps/api/src/modules/extraction/` -- extraction job module (repository, service)
  - `apps/api/test/modules/extraction/` -- extraction module tests
- New files:
  - `infra/sql/migrations/030_wardrobe_extraction_jobs.sql`
  - `infra/sql/migrations/031_extraction_job_photos.sql`
  - `infra/sql/policies/005_extraction_jobs_rls.sql`
  - `apps/api/src/modules/extraction/repository.js`
  - `apps/api/src/modules/extraction/service.js`
  - `apps/mobile/lib/src/features/wardrobe/screens/bulk_import_preview_screen.dart`
  - `apps/mobile/test/features/wardrobe/screens/bulk_import_preview_screen_test.dart`
- Modified files:
  - `apps/api/src/main.js` (add extraction routes, wire extraction services)
  - `apps/api/src/modules/uploads/service.js` (add `extraction_photo` purpose)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add bulk upload URL and extraction job methods)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (add Bulk Import entry point)
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart` (add Bulk Import button tests)
- Alignment with architecture: Epic 10 maps to `mobile/features/wardrobe`, `api/modules/ai`, `api/jobs/extraction` (architecture.md Epic-to-Component Mapping). The extraction module lives in `api/modules/extraction` following the established module pattern.

### Technical Requirements

- `image_picker: ^1.1.2` -- already in pubspec.yaml. `pickMultiImage()` is available in this version. No new Flutter dependencies needed.
- `pickMultiImage(imageQuality: 85, maxWidth: 512)` returns `List<XFile>`. Each `XFile` provides `.path` for the compressed file. This handles FR-WRD-02 compression requirements.
- The bulk signed URL endpoint returns multiple URLs in one request to minimize round trips. Each URL follows the same pattern as single uploads: `users/{uid}/extractions/{jobId}/{uuid}.jpg`.
- The `wardrobe_extraction_jobs` table tracks the overall job lifecycle. The `extraction_job_photos` table tracks individual photo upload and processing status. This two-table design allows parallel photo processing in Story 10.2.

### Architecture Compliance

- Photo uploads go through Cloud Run API (signed URL pattern) -- same architecture as single-item uploads. Client never writes directly to Cloud Storage.
- RLS on `wardrobe_extraction_jobs` and `extraction_job_photos` ensures users can only access their own extraction data.
- The extraction module follows the repository + service pattern established across all API modules.
- AI processing is deferred to Story 10.2, keeping this story focused on the upload and job creation pipeline. The architecture mandates AI calls are brokered only by Cloud Run (not triggered here).
- Media remains private, delivered via signed URLs with bounded TTL.

### Library / Framework Requirements

- No new dependencies. All required packages are already installed:
  - `image_picker: ^1.1.2` (Flutter, pubspec.yaml) -- supports `pickMultiImage()`
  - `http` (Flutter, for API calls via ApiClient)
  - `pg` (API, for database operations)
  - Existing upload service handles signed URL generation for the new `extraction_photo` purpose.

### File Structure Requirements

- `apps/api/src/modules/extraction/` is the canonical location for all extraction-related server code.
- `repository.js` + `service.js` pattern follows the same convention as `items/`, `squads/`, `shopping/` modules.
- Migration files: 030, 031 (after existing 029_social_notification_mode.sql).
- RLS policy file: 005 (after existing 004_ai_usage_log_rls.sql).
- Mobile screen goes in `features/wardrobe/screens/` since extraction is a wardrobe sub-feature.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns from `apps/api/test/`.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient. Use `tester.runAsync()` for tests involving real I/O.
- Mock `ImagePicker` for bulk selection tests (inject via constructor parameter on BulkImportPreviewScreen caller).
- Test the 50-photo truncation edge case: pass 60 photos, verify only 50 are used.
- Test individual upload failure resilience: mock one `uploadImage` to throw, verify remaining uploads continue.
- Test baselines (from Story 9.6): 989 API tests, 1459 Flutter tests.

### Previous Story Intelligence

- **Story 9.6** (done, latest): Social Notification Preferences. 989 API tests, 1459 Flutter tests. Migration 029 is the latest. All tests passing.
- **Story 2.1** (done): Established `AddItemScreen` with camera/gallery, `ImagePicker.pickImage()` with `maxWidth: 512, imageQuality: 85`, 3-step upload pipeline (`getSignedUploadUrl` -> `uploadImage` -> `createItem`), `MainShellScreen` with 5-tab navigation, `WardrobeScreen` with grid. The Bulk Import button is added alongside this existing flow.
- **Story 2.2** (done): Established AI module (`apps/api/src/modules/ai/`), Gemini client, background removal service, `ai_usage_log` table. The extraction processing in Story 10.2 will reuse these components.
- **Story 2.3** (done): Established AI categorization pipeline. Story 10.2 will reuse categorization for extracted items.
- **Story 2.5** (done): Established wardrobe grid with filtering via `FilterBar`. The Bulk Import entry point must not break the existing AppBar layout.
- **Story 2.6** (done): Established `ItemDetailScreen`. Extracted items (from Story 10.3) will eventually appear in the same wardrobe grid and be viewable in the detail screen.
- **Key pattern -- upload service**: `apps/api/src/modules/uploads/service.js` uses `generateSignedUploadUrl(authContext, { purpose })` where purpose is currently only `"item_photo"`. This story adds `"extraction_photo"` as a valid purpose.
- **Key pattern -- route wiring in main.js**: Routes are added as `if (method === 'POST' && url.pathname === '/v1/...')` blocks. New extraction routes follow this pattern. Place extraction routes after existing item routes.
- **Key pattern -- module wiring in createRuntime()**: Each module's repository is created with `{ pool }`, services with `{ repo, ... }`. Follow the same DI pattern for extraction.

### Key Anti-Patterns to Avoid

- DO NOT implement AI processing (item detection, categorization, background removal) in this story. That is Story 10.2.
- DO NOT implement the progress tracking / review flow UI. That is Story 10.3.
- DO NOT use a new image picker package. The existing `image_picker: ^1.1.2` supports `pickMultiImage()`.
- DO NOT create a separate upload path that bypasses the signed URL pattern. Reuse the existing upload service with a new `"extraction_photo"` purpose.
- DO NOT add a `creation_method` column to the items table in this story. That is Story 10.3 when extracted items are actually saved to the wardrobe.
- DO NOT block the UI during bulk upload. Show progress and allow cancellation.
- DO NOT fail the entire batch if one photo upload fails. Continue with remaining photos and report partial success.
- DO NOT modify the existing `AddItemScreen` or single-item upload flow. The "Bulk Import" is a separate entry point.
- DO NOT add `pickMultiImage()` support to the `AddItemScreen`. The bulk flow launches from the WardrobeScreen, not from AddItemScreen.

### Implementation Guidance

- **Multi-image picker**: `final images = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 512);` returns `List<XFile>`. If `images.length > 50`, truncate: `final selected = images.take(50).toList();` and show SnackBar.
- **Bulk Import entry in WardrobeScreen**: Add an `IconButton` or `PopupMenuButton` in the AppBar actions. If using PopupMenu, include "Bulk Import" as an option. If using a direct button, place it in the AppBar actions: `IconButton(icon: Icon(Icons.photo_library_outlined), tooltip: 'Bulk Import', onPressed: _startBulkImport)`.
- **Upload progress**: Use a `ValueNotifier<double>` (0.0 to 1.0) to track upload progress. After each successful upload, increment: `progress.value = completedCount / totalCount`. Display with `ValueListenableBuilder` and `LinearProgressIndicator`.
- **Signed URL batch request**: Single request returns all URLs. Then upload each photo in parallel (up to 3 concurrent) using `Future.wait` with error handling per photo. Use `Stream.fromIterable(photos).asyncMap(...)` or a simple for-loop with try/catch for sequential uploads.
- **Error resilience**: Wrap each individual upload in try/catch. Collect successful URLs in a list. At the end, if `successfulUrls.length > 0`, proceed to create the extraction job with whatever uploaded successfully. If zero succeeded, show error and allow retry.
- **BulkImportPreviewScreen grid**: Use `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4)`. Show thumbnails using `Image.file(File(path), fit: BoxFit.cover)`. 3 columns for compact preview of many photos.
- **Route ordering in main.js**: Add extraction routes AFTER existing item routes but BEFORE catch-all handlers. Pattern: `/v1/extraction-jobs` for POST, `/v1/extraction-jobs/:id` for GET.

### References

- [Source: epics.md - Story 10.1: Bulk Photo Gallery Selection]
- [Source: epics.md - Epic 10: AI Wardrobe Extraction (Bulk Import)]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 10 -> mobile/features/wardrobe, api/modules/ai, api/jobs/extraction]
- [Source: architecture.md - Media and Storage: signed URLs, private buckets]
- [Source: architecture.md - Data Architecture: wardrobe_extraction_jobs table]
- [Source: prd.md - FR-EXT-01: Users shall bulk-upload up to 50 photos from their gallery for AI extraction]
- [Source: prd.md - FR-EXT-08: Extraction jobs shall be tracked in wardrobe_extraction_jobs table]
- [Source: prd.md - NFR-PERF-05: Bulk photo extraction 20 photos < 2 minutes]
- [Source: ux-design-specification.md - Wardrobe Digitization Flow: Bulk Import path]
- [Source: 2-1-upload-item-photo-camera-gallery.md - image_picker usage, upload pipeline, WardrobeScreen grid]
- [Source: 2-2-ai-background-removal-upload.md - AI module, Gemini client, upload service patterns]
- [Source: 9-6-social-notification-preferences.md - 989 API tests, 1459 Flutter tests, migration 029 latest]
- [Source: functional-requirements.md - wardrobe_extraction_jobs table definition]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None required.

### Completion Notes List

- Implemented full bulk photo gallery selection flow for Epic 10 (AI Wardrobe Extraction)
- Created wardrobe_extraction_jobs and extraction_job_photos tables with RLS policies
- Created extraction API module (repository + service) with POST/GET endpoints
- Added bulk signed URL generation endpoint (POST /v1/uploads/signed-urls)
- Added "extraction_photo" as valid upload purpose in upload service
- Built BulkImportPreviewScreen with photo grid, toggle selection, upload progress, error resilience
- Added "Bulk Import" entry point to WardrobeScreen AppBar with injectable ImagePicker for testing
- Added 3 ApiClient methods: getBulkSignedUploadUrls, createExtractionJob, getExtractionJob
- API tests: 1018 total (989 baseline + 29 new), all passing
- Flutter tests: 1474 total (1459 baseline + 15 new), all passing
- flutter analyze: 0 new issues (15 pre-existing deprecation/unused warnings in other files)
- No regressions: AddItemScreen (22 tests), ItemDetailScreen (29 tests), WardrobeScreen (35 tests) all passing

### Change Log

- 2026-03-19: Story 10.1 implementation complete -- bulk photo gallery selection, upload pipeline, extraction job creation

### File List

New files:
- infra/sql/migrations/030_wardrobe_extraction_jobs.sql
- infra/sql/migrations/031_extraction_job_photos.sql
- infra/sql/policies/005_extraction_jobs_rls.sql
- apps/api/src/modules/extraction/repository.js
- apps/api/src/modules/extraction/service.js
- apps/mobile/lib/src/features/wardrobe/screens/bulk_import_preview_screen.dart
- apps/api/test/modules/extraction/repository.test.js
- apps/api/test/modules/extraction/service.test.js
- apps/api/test/modules/extraction/extraction-endpoint.test.js
- apps/mobile/test/features/wardrobe/screens/bulk_import_preview_screen_test.dart

Modified files:
- apps/api/src/main.js (added extraction imports, routes, wiring in createRuntime)
- apps/api/src/modules/uploads/service.js (added "extraction_photo" purpose)
- apps/mobile/lib/src/core/networking/api_client.dart (added bulk upload/extraction job methods)
- apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart (added Bulk Import button + ImagePicker injection)
- apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart (added 7 Bulk Import tests)
