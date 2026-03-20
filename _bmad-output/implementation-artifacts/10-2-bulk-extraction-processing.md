# Story 10.2: Bulk Extraction Processing

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want bulk photo uploads processed reliably in the background,
So that I can import many wardrobe items without the app hanging or timing out.

## Acceptance Criteria

1. Given the user has submitted a bulk upload (Story 10.1 created extraction job with status `'processing'`), when the photos reach the Cloud Run backend, then the system processes each photo in `extraction_job_photos` by calling Gemini Vision to detect up to 5 individual clothing items within each single photo. (FR-EXT-02)

2. Given Gemini Vision detects one or more clothing items in a photo, when detection completes, then each detected item is recorded in a new `extraction_job_items` table with bounding description, cropped image data, and the source photo reference. (FR-EXT-02, FR-EXT-09)

3. Given a clothing item is detected within a photo, when the item is extracted, then the system auto-categorizes it using the existing categorization pipeline (category, color, secondary_colors, pattern, material, style, season, occasion) with taxonomy validation and safe defaults. (FR-EXT-03)

4. Given a clothing item is detected within a photo, when the item is extracted, then background removal is applied to the cropped/extracted item image using the existing background removal service, producing a clean white-background image stored in Cloud Storage. (FR-EXT-04)

5. Given the system is processing a batch of photos, when each photo completes processing, then `extraction_job_photos.status` is updated to `'completed'` (or `'failed'`), `extraction_job_photos.items_found` is set to the detected item count, `wardrobe_extraction_jobs.processed_photos` is incremented, and `wardrobe_extraction_jobs.total_items_found` is updated with the cumulative count. (FR-EXT-08)

6. Given the system is processing all photos in a job, when all photos have been processed (or failed), then `wardrobe_extraction_jobs.status` is updated to `'completed'` (all succeeded or partial) or `'failed'` (zero photos succeeded). If some photos succeeded and some failed, set status to `'partial'`. (FR-EXT-08)

7. Given a 20-photo extraction job is submitted, when processing runs, then the entire job (detection + categorization + background removal for all items across all photos) completes in under 2 minutes. (NFR-PERF-05)

8. Given an individual photo fails during processing (Gemini error, timeout, unparseable response), when the error occurs, then that photo is marked as `'failed'` with error details, and processing continues with the remaining photos -- individual failures do not block the batch. (FR-EXT-08)

9. Given the extraction processing pipeline runs, when Gemini AI calls are made, then each call is logged to `ai_usage_log` with feature `'extraction_detection'` or `'extraction_bg_removal'` or `'extraction_categorization'`, model name, token counts, latency, and cost estimate. (NFR-OBS-02)

10. Given the API has a `POST /v1/extraction-jobs/:id/process` endpoint (or the processing is triggered automatically after job creation), when called, then it initiates the background processing pipeline. The endpoint returns immediately (202 Accepted) and processing runs asynchronously. (FR-EXT-08)

## Tasks / Subtasks

- [x] Task 1: Database migration for `extraction_job_items` table (AC: 2, 5)
  - [x] 1.1: Create `infra/sql/migrations/032_extraction_job_items.sql`: CREATE TABLE `app_public.extraction_job_items` with columns: `id` UUID PK DEFAULT gen_random_uuid(), `job_id` UUID NOT NULL FK to wardrobe_extraction_jobs ON DELETE CASCADE, `photo_id` UUID NOT NULL FK to extraction_job_photos ON DELETE CASCADE, `item_index` INTEGER NOT NULL (0-based index within the photo, 0-4), `photo_url` TEXT NOT NULL (cleaned/extracted item image URL), `original_crop_url` TEXT (pre-bg-removal crop URL), `category` TEXT, `color` TEXT, `secondary_colors` TEXT[], `pattern` TEXT, `material` TEXT, `style` TEXT, `season` TEXT[], `occasion` TEXT[], `bg_removal_status` TEXT CHECK (bg_removal_status IN ('pending', 'completed', 'failed')) DEFAULT 'pending', `categorization_status` TEXT CHECK (categorization_status IN ('pending', 'completed', 'failed')) DEFAULT 'pending', `detection_confidence` REAL (0.0-1.0 confidence score from Gemini), `created_at` TIMESTAMPTZ DEFAULT NOW(). Add index on `(job_id)` and `(photo_id)`.
  - [x] 1.2: Update `infra/sql/policies/005_extraction_jobs_rls.sql`: Add RLS policy for `extraction_job_items` using subquery joining through `extraction_job_photos` -> `wardrobe_extraction_jobs.profile_id` to match authenticated user.

- [x] Task 2: Create extraction processing service (AC: 1, 2, 3, 4, 5, 6, 7, 8, 9)
  - [x] 2.1: Create `apps/api/src/modules/extraction/processing-service.js`: Export `createExtractionProcessingService({ extractionRepo, geminiClient, backgroundRemovalService, aiUsageLogRepo, uploadService })`. This is the core processing engine.
  - [x] 2.2: Implement `processExtractionJob(authContext, jobId)` method:
    - (a) Load the job and all its photos via `extractionRepo.getJob(authContext, jobId)`.
    - (b) Validate job status is `'processing'`.
    - (c) For each photo with status `'uploaded'`, call `processPhoto(authContext, job, photo)`.
    - (d) Process photos sequentially (NOT in parallel) to avoid Gemini rate limits. Sequential processing of 20 photos at ~6s each = ~2 min.
    - (e) After all photos processed, compute final job status (`'completed'`, `'partial'`, or `'failed'`) and update via `extractionRepo.updateJobStatus()`.
  - [x] 2.3: Implement `processPhoto(authContext, job, photo)` method:
    - (a) Read image data from `photo.photoUrl` (same `readImageData` pattern as bg-removal-service.js).
    - (b) Call Gemini with a multi-item detection prompt (see Dev Notes for prompt). Use JSON mode (`responseMimeType: 'application/json'`).
    - (c) Parse the JSON response to get an array of detected items (0-5 items).
    - (d) For each detected item: run background removal, run categorization, store the extracted item image, insert into `extraction_job_items`.
    - (e) Update `extraction_job_photos` status and `items_found` count.
    - (f) Update `wardrobe_extraction_jobs.processed_photos` and `total_items_found`.
    - (g) Log each Gemini call to `ai_usage_log`.
    - (h) Wrap in try/catch: on failure, mark photo as `'failed'` with error_message and continue.
  - [x] 2.4: Implement `extractAndProcessItem(authContext, jobId, photoId, itemData, imageData, itemIndex)` method:
    - (a) Crop or isolate the item from the photo using the bounding box or description from Gemini's detection response. If Gemini returns a full-image item (single item), use the original image.
    - (b) Call background removal on the item image. Store cleaned image to Cloud Storage path: `users/{uid}/extractions/{jobId}/{photoId}_{itemIndex}_cleaned.png`. Use `uploadService` signed URL pattern with `purpose: "extraction_photo"`.
    - (c) Call categorization using the existing `validateTaxonomy()` function from `taxonomy.js` (do NOT create a new categorization pipeline -- reuse the prompt and validation logic).
    - (d) Insert into `extraction_job_items` with all metadata.
    - (e) Log each AI call separately.

- [x] Task 3: Update extraction repository with item operations (AC: 2, 5, 6)
  - [x] 3.1: Add to `apps/api/src/modules/extraction/repository.js`: `addJobItem(authContext, { jobId, photoId, itemIndex, photoUrl, originalCropUrl, category, color, secondaryColors, pattern, material, style, season, occasion, bgRemovalStatus, categorizationStatus, detectionConfidence })` that inserts into `extraction_job_items` and returns the mapped row.
  - [x] 3.2: Add `getJobItems(authContext, jobId)` that returns all items for a job, ordered by `photo_id, item_index`.
  - [x] 3.3: Add `updatePhotoStatus(authContext, photoId, { status, itemsFound, errorMessage })` that updates a single `extraction_job_photos` row.
  - [x] 3.4: Add `mapItemRow(row)` function for `extraction_job_items` mapping (snake_case -> camelCase).
  - [x] 3.5: Update `getJob()` to also fetch items from `extraction_job_items` (joined via job_id) and include them nested under each photo or as a flat `items` array on the job.

- [x] Task 4: API endpoint for triggering and checking processing (AC: 10)
  - [x] 4.1: Add route `POST /v1/extraction-jobs/:id/process` in `apps/api/src/main.js`. Authenticates user, verifies job ownership and status is `'processing'`, then fires `extractionProcessingService.processExtractionJob(authContext, jobId)` as fire-and-forget (do NOT await). Returns 202 `{ status: 'processing' }`.
  - [x] 4.2: Update `GET /v1/extraction-jobs/:id` response to include the `items` array (extracted items with all metadata, image URLs, and per-item status).
  - [x] 4.3: Wire up `extractionProcessingService` in `createRuntime()` in `main.js`: create with `{ extractionRepo, geminiClient, backgroundRemovalService, aiUsageLogRepo, uploadService }`.
  - [x] 4.4: Modify the existing `POST /v1/extraction-jobs` handler (from Story 10.1) to automatically trigger processing after job creation. After `extractionService.createExtractionJob()` returns, fire `extractionProcessingService.processExtractionJob(authContext, job.id).catch(err => console.error('[extraction-processing] Failed:', err))` as fire-and-forget.

- [x] Task 5: Mobile -- Update ApiClient for extraction items (AC: 2, 5)
  - [x] 5.1: Update `getExtractionJob(String jobId)` response parsing in `apps/mobile/lib/src/core/networking/api_client.dart` to include the `items` array. Each item has: `id`, `photoId`, `itemIndex`, `photoUrl`, `originalCropUrl`, `category`, `color`, `secondaryColors`, `pattern`, `material`, `style`, `season`, `occasion`, `bgRemovalStatus`, `categorizationStatus`, `detectionConfidence`.
  - [x] 5.2: Add `Future<Map<String, dynamic>> triggerExtractionProcessing(String jobId)` to ApiClient that calls `POST /v1/extraction-jobs/$jobId/process`. Returns the response map. (This is a fallback trigger; normally processing starts automatically.)

- [x] Task 6: API tests for extraction processing (AC: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
  - [x] 6.1: Create `apps/api/test/modules/extraction/processing-service.test.js`:
    - Test `processExtractionJob` processes all photos and updates job status to `'completed'`.
    - Test multi-item detection: mock Gemini to return 3 items for a photo, verify 3 `extraction_job_items` records created.
    - Test single-item detection: mock Gemini to return 1 item, verify 1 record.
    - Test zero-item detection: mock Gemini to return empty items array, verify photo marked completed with `items_found = 0`.
    - Test photo failure: mock Gemini to throw on one photo, verify that photo is `'failed'` and remaining photos still process.
    - Test all photos fail: verify job status is `'failed'`.
    - Test partial failure: some photos succeed, some fail, verify job status is `'partial'`.
    - Test taxonomy validation: verify extracted item metadata is validated against taxonomy with safe defaults.
    - Test AI usage logging: verify calls to `aiUsageLogRepo.logUsage` with correct feature names.
    - Test background removal is called for each detected item.
    - Test `processedPhotos` and `totalItemsFound` counters update correctly.
  - [x] 6.2: Test `POST /v1/extraction-jobs/:id/process` endpoint: returns 202, triggers processing. Test 404 for non-existent job. Test 401 for unauthenticated.
  - [x] 6.3: Test `GET /v1/extraction-jobs/:id` includes items array with all metadata fields.
  - [x] 6.4: Test repository methods: `addJobItem`, `getJobItems`, `updatePhotoStatus`.

- [x] Task 7: Widget tests for updated mobile ApiClient (AC: 2, 5)
  - [x] 7.1: Update `apps/mobile/test/core/networking/api_client_test.dart`: Test `getExtractionJob` returns items array with all metadata fields. Test `triggerExtractionProcessing` calls correct endpoint.

- [x] Task 8: Regression testing (AC: all)
  - [x] 8.1: Run `flutter analyze` -- zero issues.
  - [x] 8.2: Run `flutter test` -- all existing 1474+ tests plus new tests pass.
  - [x] 8.3: Run `npm --prefix apps/api test` -- all existing 1018+ API tests plus new tests pass.
  - [x] 8.4: Verify existing single-item upload + background removal + categorization pipeline is unaffected.
  - [x] 8.5: Verify existing extraction job creation flow (Story 10.1) still works -- creating a job and uploading photos.
  - [x] 8.6: Verify existing wardrobe grid, filtering, and item detail views are unaffected.

## Dev Notes

- This is the SECOND story in Epic 10 (AI Wardrobe Extraction / Bulk Import). Story 10.1 built the photo selection, upload, job creation pipeline. This story adds the server-side AI processing that takes uploaded photos, detects individual clothing items within each photo, runs background removal and categorization on each detected item, and stores results. Story 10.3 will build the mobile progress tracking and review/confirm flow.
- The `wardrobe_extraction_jobs` and `extraction_job_photos` tables already exist (created in Story 10.1, migrations 030-031). The extraction module (`apps/api/src/modules/extraction/`) already has `repository.js` and `service.js`.
- The AI module (`apps/api/src/modules/ai/`) already has: `gemini-client.js` (shared singleton), `background-removal-service.js`, `categorization-service.js`, `ai-usage-log-repository.js`, `taxonomy.js` (shared taxonomy constants and validation). REUSE these -- do NOT duplicate AI logic.
- The key new component is the **multi-item detection** capability. Unlike Story 2.2/2.3 which process a single item per photo, this story must detect MULTIPLE items in a single photo (e.g., a flat-lay photo of an outfit might contain a shirt, pants, shoes, and a bag).
- Processing must be sequential per photo (not parallel) to stay within Gemini rate limits. For 20 photos, budget ~6 seconds per photo (detection ~3s + bg removal ~2s + categorization ~1s per item). This fits within the 2-minute NFR-PERF-05 target.
- The `extraction_job_items` table is NEW and stores each individual detected item. This is a child of `extraction_job_photos`. One photo can produce 0-5 items. Items in this table are NOT yet in the main `items` table -- they are staged for user review (Story 10.3).
- The processing is triggered automatically when `POST /v1/extraction-jobs` creates the job (fire-and-forget). The `POST /v1/extraction-jobs/:id/process` endpoint exists as a manual retry/trigger mechanism.
- For the multi-item detection prompt, use Gemini's JSON mode to get structured output describing each detected item (position, description). Then process each item individually through the existing bg removal and categorization pipelines.
- The `extraction_job_items.photo_url` stores the final cleaned image URL. The `original_crop_url` stores the pre-bg-removal crop. Both go to Cloud Storage under `users/{uid}/extractions/{jobId}/`.

### Gemini Multi-Item Detection Prompt

```
Analyze this photo and identify all individual clothing items visible.
For each item detected, provide its details as a JSON array.
Return ONLY valid JSON with this structure:
{
  "items": [
    {
      "description": "Brief description of the item (e.g., 'blue denim jacket')",
      "confidence": 0.95,
      "category": "one of: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other",
      "color": "primary color, one of: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown",
      "secondary_colors": ["array of additional colors, empty if solid"],
      "pattern": "one of: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other",
      "material": "best guess, one of: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown",
      "style": "one of: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other",
      "season": ["suitable seasons: spring, summer, fall, winter, all"],
      "occasion": ["suitable occasions: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge"]
    }
  ]
}

Rules:
- Detect up to 5 clothing items maximum.
- If the photo shows a single item clearly, return an array with 1 item.
- If the photo contains no recognizable clothing, return {"items": []}.
- Do NOT include people, backgrounds, or non-clothing objects.
- Each item should be a distinct garment or accessory.
```

### Processing Pipeline Flow

1. `POST /v1/extraction-jobs` creates job (Story 10.1) -> status `'processing'`
2. Fire-and-forget: `processExtractionJob(authContext, jobId)` starts
3. For each photo in the job:
   a. Call Gemini with multi-item detection prompt + image -> get items array
   b. For each detected item:
      - Call Gemini bg removal on the full photo (for single-item photos) or use the original image (multi-item photos where Gemini identifies but cannot crop)
      - Validate categorization from detection response using `validateTaxonomy()` from `taxonomy.js`
      - Upload cleaned image to Cloud Storage
      - Insert into `extraction_job_items`
   c. Update `extraction_job_photos.status` and `items_found`
   d. Increment `wardrobe_extraction_jobs.processed_photos` and `total_items_found`
4. After all photos: set final job status (`completed`/`partial`/`failed`)
5. Mobile polls `GET /v1/extraction-jobs/:id` (Story 10.3) to see progress

### Project Structure Notes

- New files:
  - `infra/sql/migrations/032_extraction_job_items.sql`
  - `apps/api/src/modules/extraction/processing-service.js`
  - `apps/api/test/modules/extraction/processing-service.test.js`
- Modified files:
  - `apps/api/src/modules/extraction/repository.js` (add item CRUD, update getJob to include items)
  - `apps/api/src/main.js` (add processing-service import/wiring, add POST /v1/extraction-jobs/:id/process route, auto-trigger processing on job creation)
  - `infra/sql/policies/005_extraction_jobs_rls.sql` (add extraction_job_items RLS)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (update getExtractionJob response parsing, add triggerExtractionProcessing)
  - `apps/mobile/test/core/networking/api_client_test.dart` (update extraction job tests)
- Alignment with architecture: Epic 10 maps to `mobile/features/wardrobe`, `api/modules/ai`, `api/jobs/extraction` (architecture.md). The processing service lives in `api/modules/extraction/` alongside the existing repository and service.

### Technical Requirements

- Gemini 2.0 Flash model (`gemini-2.0-flash`) via the existing `geminiClient` singleton in `apps/api/src/modules/ai/gemini-client.js`. Do NOT create a new Gemini client.
- Use Gemini JSON mode (`responseMimeType: 'application/json'`) for multi-item detection to get structured output.
- Taxonomy validation uses the existing `validateTaxonomy()` from `apps/api/src/modules/ai/categorization-service.js` and constants from `apps/api/src/modules/ai/taxonomy.js`.
- Background removal uses the existing `backgroundRemovalService.removeBackground()` pattern but adapted: instead of updating an `items` table record, it returns the cleaned image data/URL for storage in `extraction_job_items`.
- Image storage: cleaned extraction item images go to `users/{uid}/extractions/{jobId}/{photoId}_{itemIndex}_cleaned.png` in Cloud Storage. Use the existing `uploadService` or local file write pattern from `background-removal-service.js`.
- Sequential photo processing to respect Gemini rate limits. Process one photo fully (detect + bg removal + categorize for all items) before moving to the next.
- The `extraction_job_items` table stores staged items -- they are NOT yet in the main `items` table. Story 10.3 handles the user review and promotion to the `items` table.

### Architecture Compliance

- AI calls are brokered ONLY by Cloud Run. Mobile client never calls Gemini directly.
- All AI workloads route through Vertex AI / Gemini 2.0 Flash via the shared `geminiClient`.
- AI orchestration includes taxonomy validation, safe defaults on failure, retry/backoff, and per-user logging.
- RLS on `extraction_job_items` ensures users can only access their own extraction data (via subquery to `wardrobe_extraction_jobs.profile_id`).
- Media remains private, stored in user-scoped Cloud Storage paths, delivered via signed URLs.
- Processing is async/fire-and-forget from the API endpoint -- does NOT block the HTTP response.
- Individual photo failures do NOT block the batch (resilient processing).

### Library / Framework Requirements

- No new dependencies. All required packages are already installed:
  - `@google-cloud/vertexai` (API, via gemini-client.js)
  - `@google-cloud/storage` (API, for image upload)
  - `pg` (API, for database operations)
  - Existing AI module services for bg removal and categorization.
- Mobile: No new dependencies. Only updating ApiClient response parsing.

### File Structure Requirements

- `apps/api/src/modules/extraction/processing-service.js` is the new core file. It lives alongside `repository.js` and `service.js` in the extraction module.
- Migration file: 032 (after existing 031_extraction_job_photos.sql from Story 10.1).
- RLS policy update: append to existing `005_extraction_jobs_rls.sql` (or create a new segment -- follow the pattern established).
- The processing service imports from `../ai/taxonomy.js` for validation constants and from `../ai/categorization-service.js` for `validateTaxonomy()`. It does NOT duplicate these.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns from `apps/api/test/modules/extraction/`.
- Mock `geminiClient` in processing service tests. Do NOT make real Gemini API calls.
- Mock file system / storage for image read/write operations.
- Test the full pipeline: detection -> bg removal -> categorization -> item insertion -> photo status update -> job status update.
- Test edge cases: 0 items detected in a photo, 5 items detected (max), Gemini returns invalid JSON, Gemini times out.
- Test resilience: one photo fails mid-processing, others continue.
- Test final job status logic: all succeed -> `'completed'`, mix -> `'partial'`, all fail -> `'failed'`.
- Test baselines (from Story 10.1): 1018 API tests, 1474 Flutter tests.

### Previous Story Intelligence

- **Story 10.1** (done, predecessor): Created `wardrobe_extraction_jobs` table (migration 030), `extraction_job_photos` table (migration 031), RLS policies (005), extraction module with `repository.js` and `service.js`, API endpoints (`POST /v1/extraction-jobs`, `GET /v1/extraction-jobs/:id`), mobile `BulkImportPreviewScreen`, ApiClient methods (`getBulkSignedUploadUrls`, `createExtractionJob`, `getExtractionJob`). 1018 API tests, 1474 Flutter tests. The extraction service creates jobs with status `'uploading'` -> `'processing'` but does NOT process photos. **This story picks up where 10.1 left off.**
- **Story 2.2** (done): Established AI module, `gemini-client.js` singleton, `background-removal-service.js` pattern (readImageData, call Gemini, extract image from response, upload cleaned image, update record, log AI usage). This story's bg removal per extracted item follows the same pattern.
- **Story 2.3** (done): Established `categorization-service.js` with `validateTaxonomy()`, taxonomy constants in `taxonomy.js`, JSON mode Gemini calls, safe defaults. This story reuses `validateTaxonomy()` directly for extraction item categorization.
- **Story 2.4** (done): Refactored taxonomy constants to shared `taxonomy.js`. Both categorization-service.js and items/service.js import from this shared file.
- **Key pattern -- fire-and-forget:** `service.doWork(authContext, args).catch(err => console.error('[tag] Failed:', err))`. Do NOT await in the request handler.
- **Key pattern -- readImageData:** Both `background-removal-service.js` and `categorization-service.js` have `readImageData()`. Extract or import from one -- do NOT duplicate a third copy. Consider importing from `background-removal-service.js` or extracting to a shared util.
- **Key pattern -- estimateCost:** Both bg removal and categorization services have identical `estimateCost()` functions. Import from one or extract to shared util.
- **Key pattern -- route wiring in main.js:** Routes use `if (method === 'POST' && url.pathname.match(...))` pattern. Place the new process route near the existing extraction routes.
- **Key pattern -- module wiring in createRuntime():** Each service is constructed with DI: `createService({ repo, client, ... })`. Follow the same pattern for `createExtractionProcessingService`.

### Key Anti-Patterns to Avoid

- DO NOT create a new Gemini client or a new categorization/bg-removal pipeline. Reuse the existing `geminiClient`, `backgroundRemovalService`, and `validateTaxonomy()`.
- DO NOT process photos in parallel. Sequential processing avoids Gemini rate limits and keeps resource usage predictable.
- DO NOT add items directly to the `items` table. Extraction results go to `extraction_job_items` as staged items. Story 10.3 handles user review and promotion.
- DO NOT add a `creation_method` column to items in this story. That is Story 10.3.
- DO NOT implement the mobile progress tracking UI or review flow. That is Story 10.3.
- DO NOT duplicate `readImageData()` or `estimateCost()` -- import from existing modules or extract to a shared utility.
- DO NOT duplicate taxonomy constants or validation logic. Import from `taxonomy.js` and `categorization-service.js`.
- DO NOT block the HTTP response on processing. The processing endpoint returns 202 immediately; processing runs async.
- DO NOT fail the entire job if one photo fails. Mark the individual photo as failed and continue.
- DO NOT modify the existing single-item upload/bg-removal/categorization flow. The extraction processing is a separate pipeline.
- DO NOT await the fire-and-forget processing call in the route handler.

### Implementation Guidance

- **Multi-item detection call:**
  ```javascript
  const model = await geminiClient.getGenerativeModel('gemini-2.0-flash');
  const result = await model.generateContent({
    contents: [{
      role: 'user',
      parts: [
        { inlineData: { mimeType: 'image/jpeg', data: imageData.toString('base64') } },
        { text: MULTI_ITEM_DETECTION_PROMPT }
      ]
    }],
    generationConfig: { responseMimeType: 'application/json' }
  });
  const parsed = JSON.parse(result.response.candidates[0].content.parts[0].text);
  const detectedItems = parsed.items || [];
  ```
- **Combined detection + categorization:** The multi-item detection prompt already requests categorization metadata for each item. This means we get detection AND categorization in a single Gemini call (saving time and cost). Only background removal requires a separate Gemini call per item.
- **Background removal per item:** For single-item photos, pass the full photo to bg removal. For multi-item photos, pass the full photo with a prompt specifying which item to isolate (e.g., "Remove the background and isolate only the [description] from this image"). Alternatively, if Gemini cannot crop, run bg removal on the full photo and accept that multi-item photos may produce less-clean results.
- **Processing service constructor:**
  ```javascript
  export function createExtractionProcessingService({
    extractionRepo, geminiClient, backgroundRemovalService, aiUsageLogRepo, uploadService
  }) { ... }
  ```
- **Job status calculation:**
  ```javascript
  const succeededPhotos = photos.filter(p => p.status === 'completed').length;
  const failedPhotos = photos.filter(p => p.status === 'failed').length;
  if (succeededPhotos === photos.length) finalStatus = 'completed';
  else if (succeededPhotos === 0) finalStatus = 'failed';
  else finalStatus = 'partial';
  ```
- **Auto-trigger in existing POST /v1/extraction-jobs handler:**
  ```javascript
  // After extractionService.createExtractionJob() returns:
  extractionProcessingService.processExtractionJob(authContext, result.id)
    .catch(err => console.error('[extraction-processing] Failed:', err));
  ```
- **Cleaned image upload path pattern:** `users/{uid}/extractions/{jobId}/{photoId}_{itemIndex}_cleaned.png`. Use the same local file write pattern as `background-removal-service.js` for dev, and GCS signed URLs for production.
- **Repository mapItemRow for extraction_job_items:**
  ```javascript
  function mapExtractedItemRow(row) {
    return {
      id: row.id, jobId: row.job_id, photoId: row.photo_id,
      itemIndex: row.item_index, photoUrl: row.photo_url,
      originalCropUrl: row.original_crop_url ?? null,
      category: row.category, color: row.color,
      secondaryColors: row.secondary_colors ?? [],
      pattern: row.pattern, material: row.material,
      style: row.style, season: row.season ?? [],
      occasion: row.occasion ?? [],
      bgRemovalStatus: row.bg_removal_status,
      categorizationStatus: row.categorization_status,
      detectionConfidence: row.detection_confidence ?? null,
      createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null
    };
  }
  ```

### References

- [Source: epics.md - Story 10.2: Bulk Extraction Processing]
- [Source: epics.md - Epic 10: AI Wardrobe Extraction (Bulk Import)]
- [Source: architecture.md - AI Orchestration: Vertex AI / Gemini 2.0 Flash, taxonomy validation, safe defaults]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 10 -> mobile/features/wardrobe, api/modules/ai, api/jobs/extraction]
- [Source: architecture.md - Media and Storage: signed URLs, private buckets]
- [Source: architecture.md - Notifications and Async Work: bulk extraction job progression]
- [Source: prd.md - FR-EXT-02: Detect multiple clothing items within a single photo (up to 5 items per photo)]
- [Source: prd.md - FR-EXT-03: Each detected item shall be auto-categorized with category, color, style, material, and pattern]
- [Source: prd.md - FR-EXT-04: Background removal shall be applied to each extracted item]
- [Source: prd.md - FR-EXT-08: Extraction jobs tracked in wardrobe_extraction_jobs table with status progression]
- [Source: prd.md - FR-EXT-09: Items created via extraction tagged with creation_method = 'ai_extraction']
- [Source: prd.md - NFR-PERF-05: Bulk photo extraction (20 photos) < 2 minutes]
- [Source: prd.md - NFR-OBS-02: AI API costs logged per-user in ai_usage_log]
- [Source: functional-requirements.md - wardrobe_extraction_jobs table definition]
- [Source: 10-1-bulk-photo-gallery-selection.md - Extraction module, tables, API endpoints, 1018 API tests, 1474 Flutter tests]
- [Source: 2-2-ai-background-removal-upload.md - AI module, Gemini client, bg removal service pattern, readImageData, estimateCost]
- [Source: 2-3-ai-item-categorization-tagging.md - categorization-service.js, validateTaxonomy(), taxonomy.js, JSON mode]
- [Source: 2-4-manual-metadata-editing-creation.md - taxonomy.js shared constants refactor]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None required.

### Completion Notes List

- Implemented migration 032 for `extraction_job_items` table with all required columns, constraints, and indexes
- Added RLS policies for `extraction_job_items` (SELECT, INSERT, UPDATE, DELETE) via subquery through extraction_job_photos -> wardrobe_extraction_jobs -> profiles
- Created `processing-service.js` with `processExtractionJob`, `processPhoto`, and `extractAndProcessItem` methods implementing sequential photo processing pipeline
- Multi-item detection uses Gemini JSON mode with structured prompt returning up to 5 items per photo
- Background removal per detected item uses item-specific isolation prompt
- Taxonomy validation reuses `validateTaxonomy()` from categorization-service.js with safe defaults
- AI usage logged with features: `extraction_detection`, `extraction_bg_removal`, `extraction_categorization`
- Repository extended with `addJobItem`, `getJobItems`, `updatePhotoStatus`, `mapItemRow`; `getJob` now includes items array
- `POST /v1/extraction-jobs/:id/process` endpoint returns 202, validates job ownership and status
- Auto-trigger processing on job creation (fire-and-forget pattern)
- Mobile ApiClient updated with `triggerExtractionProcessing` method
- Job status calculation: all succeed -> completed, mixed -> partial, all fail -> failed
- Individual photo failures do not block the batch (resilient processing)
- API tests: 1046 total (28 new), all passing
- Flutter tests: 1476 total (2 new), all passing
- Flutter analyze: 13 pre-existing warnings, 0 new issues

### Change Log

- 2026-03-19: Story 10.2 implementation complete -- bulk extraction processing pipeline

### File List

New files:
- `infra/sql/migrations/032_extraction_job_items.sql`
- `apps/api/src/modules/extraction/processing-service.js`
- `apps/api/test/modules/extraction/processing-service.test.js`
- `apps/api/test/fixtures/test-photo.jpg`

Modified files:
- `infra/sql/policies/005_extraction_jobs_rls.sql` (added extraction_job_items RLS)
- `apps/api/src/modules/extraction/repository.js` (added addJobItem, getJobItems, updatePhotoStatus, mapItemRow; updated getJob to include items)
- `apps/api/src/main.js` (added processing-service import/wiring, POST /v1/extraction-jobs/:id/process route, auto-trigger processing on job creation)
- `apps/mobile/lib/src/core/networking/api_client.dart` (added triggerExtractionProcessing method)
- `apps/mobile/test/core/networking/api_client_test.dart` (added getExtractionJob items test, triggerExtractionProcessing test)
- `apps/api/test/modules/extraction/extraction-endpoint.test.js` (added process endpoint tests, items in GET response test, auto-trigger test)
- `apps/api/test/modules/extraction/repository.test.js` (added addJobItem, getJobItems, updatePhotoStatus tests, updated getJob to verify items)
