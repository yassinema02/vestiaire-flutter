# Story 8.2: Product Screenshot Upload

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to upload a screenshot of an item I found on Instagram or a shopping app,
so that the app can extract its details when a URL isn't available.

## Acceptance Criteria

1. Given I am on the Shopping Assistant screen (established in Story 8.1), when the screen loads, then the "Upload Screenshot" card (currently a disabled placeholder with `opacity: 0.5` and "Coming Soon" text) is now fully active, tappable, and visually prominent at full opacity. The card shows `Icons.camera_alt`, title "Upload Screenshot", and subtitle "Analyze from photo or screenshot". (FR-SHP-01)

2. Given I tap the "Upload Screenshot" card, when the selection options appear, then I see two choices: "Take Photo" (camera) and "Choose from Gallery", following the same UX pattern established in Story 2.1's `AddItemScreen`. Tapping either option opens the device camera or gallery respectively via `image_picker` with `maxWidth: 1024` and `imageQuality: 90` (higher quality than wardrobe uploads since we need to read text/details from screenshots). (FR-SHP-01)

3. Given I select or capture a screenshot image, when the image is ready, then the app compresses it client-side (via `image_picker` parameters), uploads it to Cloud Storage via the existing signed URL pattern (`POST /v1/uploads/signed-url` with `purpose: "shopping_screenshot"`), and then calls `POST /v1/shopping/scan-screenshot` with `{ imageUrl: "<public_url>" }`. (FR-SHP-01, FR-SHP-04)

4. Given the API receives a screenshot scan request, when it processes the image, then it calls Gemini 2.0 Flash vision analysis on the uploaded image using the same `PRODUCT_IMAGE_PROMPT` from Story 8.1's `shopping-scan-service.js` to extract: `category`, `color`, `secondaryColors`, `pattern`, `material`, `style`, `season`, `occasion`, and `formalityScore` (1-10). Additionally, the API sends a second prompt to extract visible text metadata: `productName`, `brand`, `price`, `currency` from the screenshot. The complete analysis pipeline completes within 5 seconds. (FR-SHP-01, FR-SHP-04, NFR-PERF-03)

5. Given the screenshot analysis succeeds, when the response is returned, then it includes: `{ scan: { id, url: null, scanType: "screenshot", imageUrl, productName, brand, price, currency, category, color, secondaryColors, pattern, material, style, season, occasion, formalityScore, extractionMethod: "screenshot_vision", createdAt }, status: "completed" }`. The scan is persisted to the existing `shopping_scans` table with `scan_type = 'screenshot'`. (FR-SHP-04, FR-SHP-11)

6. Given the API processes a screenshot scan request, when the request is received, then it enforces the same usage limits as URL scanning via `premiumGuard.checkUsageQuota(authContext, { feature: "shopping_scan", freeLimit: 3, period: "day" })`. Screenshot scans and URL scans share the same daily quota. Free users get 3 total scans per day (URL + screenshot combined); premium users get unlimited. If the limit is reached, the API returns 429 with the same rate limit response format as Story 8.1. (FR-SHP-01, NFR-SEC-05)

7. Given the screenshot image has no recognizable clothing or the Gemini analysis returns no useful data, when the extraction fails, then the API returns HTTP 422 with `{ error: "Could not extract product data", code: "EXTRACTION_FAILED", message: "Unable to identify clothing in this image. Try a clearer photo or paste a product URL instead." }`. (NFR-REL-03)

8. Given the mobile app is showing the screenshot upload flow, when the upload or analysis is in progress, then the screen shows a loading state with the selected image as a preview, a shimmer overlay, and text "Analyzing screenshot...". On success, the scan result is displayed using the same `_buildResultCard()` widget from Story 8.1 (showing product image, name, brand, price, metadata chips). On 429 error, the `PremiumGateCard` is shown. On 422 error, an error card with "Try a URL instead" suggestion is shown. (FR-SHP-01)

9. Given the API processes a screenshot scan, when any AI call is made (Gemini vision), then the API logs the request to `ai_usage_log` with `feature = "shopping_scan"`, model name, input/output tokens, latency in ms, estimated cost, and status `"success"` or `"failure"`. (NFR-OBS-02)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (738+ API tests, 1171+ Flutter tests) and new tests cover: screenshot scan endpoint (success, failure, rate limits), screenshot analysis in shopping-scan-service (Gemini vision, text extraction), upload purpose validation, ShoppingScanScreen screenshot flow, ApiClient screenshot methods, and ShoppingScanService screenshot method.

## Tasks / Subtasks

- [x] Task 1: API -- Add `shopping_screenshot` upload purpose (AC: 3)
  - [x] 1.1: In `apps/api/src/modules/uploads/service.js`, add `"shopping_screenshot"` to the list of valid upload purposes in the `generateSignedUploadUrl` method. The upload path pattern should be `users/{uid}/shopping/{uuid}.jpg`. Follow the exact pattern of `"item_photo"` purpose.
  - [x] 1.2: Verify the upload service returns `{ uploadUrl, publicUrl }` for the new purpose, consistent with existing behavior.

- [x] Task 2: API -- Add `scanScreenshot` method to shopping scan service (AC: 4, 5, 7, 9)
  - [x] 2.1: In `apps/api/src/modules/shopping/shopping-scan-service.js`, add a new method `async scanScreenshot(authContext, { imageUrl })` to the service object returned by `createShoppingScanService`. This method: (a) downloads the image from the provided `imageUrl` using the existing `downloadImage()` utility in the same file, (b) calls Gemini 2.0 Flash vision with the `PRODUCT_IMAGE_PROMPT` (already defined in the file) to extract taxonomy fields (category, color, style, etc.), (c) calls Gemini 2.0 Flash with a NEW screenshot text extraction prompt to extract visible text metadata (productName, brand, price, currency), (d) merges taxonomy + text results, (e) persists to `shopping_scans` with `scan_type = 'screenshot'` and `extraction_method = 'screenshot_vision'`, (f) logs AI usage for each Gemini call, (g) returns `{ scan, status: "completed" }`.
  - [x] 2.2: Define a new `SCREENSHOT_TEXT_PROMPT` constant in the same file:
    ```
    Analyze this product screenshot and extract any visible text information as JSON.
    This may be a screenshot from Instagram, a shopping app, or a website.
    Return ONLY valid JSON with these keys (use null for missing/not visible values):
    {
      "name": "product name if visible",
      "brand": "brand name if visible",
      "price": numeric price value if visible (just the number),
      "currency": "3-letter currency code if visible (GBP, USD, EUR, etc.)"
    }
    ```
  - [x] 2.3: In `scanScreenshot`, call Gemini vision TWICE (in parallel using `Promise.all`): once with `PRODUCT_IMAGE_PROMPT` for taxonomy extraction, once with `SCREENSHOT_TEXT_PROMPT` for text metadata. This parallelizes the two AI calls to stay within the 5-second NFR-PERF-03 budget.
  - [x] 2.4: Log AI usage separately for each Gemini call (two `aiUsageLogRepo.logUsage` calls). Both use `feature: "shopping_scan"`.
  - [x] 2.5: Validate all taxonomy fields using the existing `validateTaxonomy()` function imported from `categorization-service.js`. Validate `formalityScore` using the existing `validateFormalityScore()` function.
  - [x] 2.6: If the image download fails OR both Gemini calls return no useful data (no taxonomy AND no text), throw a 422 error with `code: "EXTRACTION_FAILED"` and message: "Unable to identify clothing in this image. Try a clearer photo or paste a product URL instead."

- [x] Task 3: API -- Wire screenshot scan endpoint (AC: 3, 6, 7, 9)
  - [x] 3.1: Add route `POST /v1/shopping/scan-screenshot` in `apps/api/src/main.js`. This endpoint: (a) authenticates the user via `requireAuth`, (b) validates request body has `imageUrl` (string, required), (c) calls `premiumGuard.checkUsageQuota(authContext, { feature: "shopping_scan", freeLimit: FREE_LIMITS.SHOPPING_SCAN_DAILY, period: "day" })` -- SAME quota as URL scanning so URL + screenshot scans count together, (d) if not allowed, return 429 with rate limit details (same format as scan-url), (e) call `shoppingScanService.scanScreenshot(authContext, { imageUrl: body.imageUrl })`, (f) return 200 with the scan result. Use 422 for extraction failures.
  - [x] 3.2: Place the new route adjacent to the existing `POST /v1/shopping/scan-url` route for code organization. The route follows the exact same auth, quota check, error handling, and response pattern.

- [x] Task 4: Mobile -- Add `scanScreenshot` method to ShoppingScanService (AC: 3, 8)
  - [x] 4.1: In `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart`, add method `Future<ShoppingScan> scanScreenshot(String imageUrl)` that calls `_apiClient.authenticatedPost("/v1/shopping/scan-screenshot", body: {"imageUrl": imageUrl})` and returns `ShoppingScan.fromJson(response["scan"])`.

- [x] Task 5: Mobile -- Add `scanProductScreenshot` method to ApiClient (AC: 3)
  - [x] 5.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add method `Future<Map<String, dynamic>> scanProductScreenshot(String imageUrl)` that calls `authenticatedPost("/v1/shopping/scan-screenshot", body: {"imageUrl": imageUrl})`. Place it adjacent to the existing `scanProductUrl` method.

- [x] Task 6: Mobile -- Update ShoppingScanScreen with screenshot upload flow (AC: 1, 2, 3, 8)
  - [x] 6.1: Replace the disabled screenshot placeholder (the `Opacity(opacity: 0.5, ...)` widget wrapping the "Upload Screenshot / Coming Soon" card) with a fully active, tappable card at full opacity. Update text from "Coming Soon" to "Analyze from photo or screenshot". Make the card a `GestureDetector` or `InkWell` that triggers the screenshot selection flow.
  - [x] 6.2: On tap of the screenshot card, show a `showModalBottomSheet` with two options: "Take Photo" (camera icon, `ImageSource.camera`) and "Choose from Gallery" (photo icon, `ImageSource.gallery`). Follow the same Vibrant Soft-UI styling as the rest of the screen. Use `ImagePicker().pickImage(source: selectedSource, maxWidth: 1024, imageQuality: 90)`.
  - [x] 6.3: After the user selects/captures an image, execute the upload + scan pipeline: (a) show loading state with the selected image as preview and "Analyzing screenshot..." text, (b) call `apiClient.getSignedUploadUrl(purpose: "shopping_screenshot")` to get signed URL, (c) call `apiClient.uploadImage(xFile.path, uploadUrl)` to upload the image, (d) call `widget.shoppingScanService.scanScreenshot(publicUrl)` to trigger server-side AI analysis, (e) on success, show the result using the existing `_buildResultCard()` method, (f) on 429, show `PremiumGateCard`, (g) on 422, show error message with "Try a URL instead" suggestion, (h) on other errors, show generic retry.
  - [x] 6.4: Add a `_screenshotImagePath` state variable to hold the selected image file path for preview display during loading. Show the image preview using `Image.file(File(_screenshotImagePath))` overlaid with a shimmer while analysis is in progress.
  - [x] 6.5: The `ShoppingScanScreen` constructor must now also accept an `ApiClient` parameter for the signed URL upload flow (in addition to `ShoppingScanService` and `SubscriptionService`). Update: `const ShoppingScanScreen({ required this.shoppingScanService, required this.subscriptionService, required this.apiClient, super.key })`.
  - [x] 6.6: Accept an optional `ImagePicker?` parameter for dependency injection in tests: `this.imagePicker`.
  - [x] 6.7: Add `Semantics` labels: "Upload Screenshot" on the card, "Take Photo" and "Choose from Gallery" on bottom sheet options, "Screenshot preview" on the image preview.

- [x] Task 7: Mobile -- Update navigation to pass ApiClient to ShoppingScanScreen (AC: 1)
  - [x] 7.1: In `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (or wherever `ShoppingScanScreen` is instantiated), update the navigation to pass the `apiClient` parameter to `ShoppingScanScreen`. The `apiClient` is already available in the navigation context from Story 8.1's wiring.

- [x] Task 8: API -- Unit tests for screenshot scan (AC: 4, 5, 7, 9)
  - [x] 8.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-service.test.js` (extending the existing file):
    - `scanScreenshot` downloads image and calls Gemini vision for taxonomy extraction.
    - `scanScreenshot` calls Gemini vision for text metadata extraction.
    - `scanScreenshot` runs both Gemini calls in parallel.
    - `scanScreenshot` validates taxonomy against fixed taxonomy with safe defaults.
    - `scanScreenshot` persists scan with `scan_type = 'screenshot'` and `extraction_method = 'screenshot_vision'`.
    - `scanScreenshot` logs AI usage for each Gemini call (2 log entries on success).
    - `scanScreenshot` throws 422 when image download fails.
    - `scanScreenshot` throws 422 when no data extractable from Gemini.
    - `scanScreenshot` handles partial data gracefully (taxonomy succeeds but text fails, or vice versa).
    - `scanScreenshot` validates formalityScore as integer 1-10.

- [x] Task 9: API -- Integration tests for screenshot scan endpoint (AC: 3, 6, 7)
  - [x] 9.1: Add tests to `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js` (extending the existing file):
    - POST /v1/shopping/scan-screenshot returns 200 with scan data on success.
    - POST /v1/shopping/scan-screenshot returns 422 on extraction failure.
    - POST /v1/shopping/scan-screenshot returns 429 when free daily limit reached (shared quota with URL scans).
    - POST /v1/shopping/scan-screenshot returns 401 without authentication.
    - POST /v1/shopping/scan-screenshot returns 400 when imageUrl is missing.
    - Premium user bypasses daily limit for screenshot scans.
    - URL scan + screenshot scan share the same daily quota (e.g., 2 URL scans + 1 screenshot scan = 3 total = limit reached).

- [x] Task 10: API -- Upload purpose test (AC: 3)
  - [x] 10.1: Update upload service tests to verify `"shopping_screenshot"` is a valid purpose and returns correct upload path pattern `users/{uid}/shopping/{uuid}.jpg`.

- [x] Task 11: Mobile -- Widget tests for screenshot flow (AC: 1, 2, 8)
  - [x] 11.1: Update `apps/mobile/test/features/shopping/screens/shopping_scan_screen_test.dart` (extending the existing file):
    - Screenshot card is fully visible (not dimmed) and tappable.
    - Tapping screenshot card shows bottom sheet with "Take Photo" and "Choose from Gallery".
    - Selecting gallery option calls `ImagePicker.pickImage` with `ImageSource.gallery`, `maxWidth: 1024`, `imageQuality: 90`.
    - Selecting camera option calls `ImagePicker.pickImage` with `ImageSource.camera`.
    - When image is selected, loading state shows image preview with "Analyzing screenshot..." text.
    - On successful scan, result card is displayed with extracted metadata.
    - On 429 error, PremiumGateCard is shown.
    - On 422 error, error message with "Try a URL instead" suggestion is shown.
    - Cancellation (null from ImagePicker) returns to initial state.
    - Semantics labels present on screenshot card, bottom sheet options, and preview.

- [x] Task 12: Mobile -- ShoppingScanService and ApiClient test updates (AC: 3)
  - [x] 12.1: Update `apps/mobile/test/core/networking/api_client_test.dart`: `scanProductScreenshot` calls POST /v1/shopping/scan-screenshot with correct body.
  - [x] 12.2: Create or update shopping scan service test to verify `scanScreenshot` calls the correct API endpoint and returns a `ShoppingScan`.

- [x] Task 13: Regression testing (AC: all)
  - [x] 13.1: Run `flutter analyze` -- zero new issues.
  - [x] 13.2: Run `flutter test` -- all existing 1171+ tests plus new tests pass.
  - [x] 13.3: Run `npm --prefix apps/api test` -- all existing 738+ API tests plus new tests pass.
  - [x] 13.4: Verify existing URL scan pipeline still works (Story 8.1 functionality unchanged).
  - [x] 13.5: Verify existing wardrobe upload pipeline still works (signed URL upload pattern not broken).
  - [x] 13.6: Verify existing premium gating still works (shared quota between URL and screenshot scans).

## Dev Notes

- This is the SECOND story in Epic 8 (Shopping Assistant). It adds screenshot-based product analysis alongside the URL-based scanning from Story 8.1. The screenshot path targets users who find products on Instagram, TikTok, or other platforms where a direct product URL may not be available.
- The screenshot scan reuses almost everything from Story 8.1: the `shopping_scans` table (with `scan_type = 'screenshot'`), the `ShoppingScan` model, the same Gemini product image prompt, the same taxonomy validation, the same `PremiumGateCard`, the same rate limiting (shared quota), and the same result display card. The key NEW elements are: (a) image upload via signed URL, (b) a second Gemini prompt for text extraction from screenshots, (c) activating the disabled placeholder on the mobile screen.
- The `shopping_scans` table already supports `scan_type IN ('url', 'screenshot')` from Story 8.1's migration (024_shopping_scans.sql). No schema changes needed.
- Screenshot scans and URL scans SHARE the same daily quota. The `premiumGuard.checkUsageQuota` counts ALL entries in `ai_usage_log` with `feature = "shopping_scan"` regardless of scan type. This is by design: 3 total scans per day for free users.
- Image quality for screenshots is set higher than wardrobe photos (`maxWidth: 1024, imageQuality: 90` vs `maxWidth: 512, imageQuality: 85`) because screenshots contain text (prices, brand names) that must remain legible for Gemini vision to extract.
- The two Gemini calls (taxonomy extraction + text extraction) should run in **parallel** via `Promise.all` to meet the 5-second NFR-PERF-03 budget. Each call typically takes 2-3 seconds, so sequential calls would risk exceeding the budget.

### Screenshot Text Extraction Prompt

```
Analyze this product screenshot and extract any visible text information as JSON.
This may be a screenshot from Instagram, a shopping app, or a website.
Return ONLY valid JSON with these keys (use null for missing/not visible values):
{
  "name": "product name if visible",
  "brand": "brand name if visible",
  "price": numeric price value if visible (just the number),
  "currency": "3-letter currency code if visible (GBP, USD, EUR, etc.)"
}
```

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/shopping/shopping-scan-service.js` (add `scanScreenshot` method, add `SCREENSHOT_TEXT_PROMPT` constant)
  - `apps/api/src/modules/uploads/service.js` (add `"shopping_screenshot"` to valid purposes)
  - `apps/api/src/main.js` (add `POST /v1/shopping/scan-screenshot` route)
  - `apps/api/test/modules/shopping/shopping-scan-service.test.js` (add screenshot scan tests)
  - `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js` (add screenshot endpoint tests)
- Modified mobile files:
  - `apps/mobile/lib/src/features/shopping/screens/shopping_scan_screen.dart` (activate screenshot card, add upload+scan flow, add ImagePicker+ApiClient params)
  - `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart` (add `scanScreenshot` method)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `scanProductScreenshot` method)
  - `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (pass `apiClient` to ShoppingScanScreen)
  - `apps/mobile/test/features/shopping/screens/shopping_scan_screen_test.dart` (add screenshot flow tests)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add scanProductScreenshot test)
- No new files. No new directories. No new dependencies. No new migrations.

### Technical Requirements

- **image_picker** (already installed, ^1.1.2) for camera and gallery selection on mobile. Use `maxWidth: 1024` and `imageQuality: 90` for screenshots (higher than wardrobe's 512/85 to preserve text legibility).
- **Signed URL upload pattern** (established in Story 1.5, reused in Story 2.1) for uploading the screenshot to Cloud Storage. New purpose: `"shopping_screenshot"`, path: `users/{uid}/shopping/{uuid}.jpg`.
- **Gemini 2.0 Flash** via existing `geminiClient` singleton for both taxonomy and text extraction. Use `responseMimeType: "application/json"` for structured output. Run both calls in `Promise.all` for parallel execution.
- **Same taxonomy validation** as Story 2.3 and 8.1. Import `validateTaxonomy` from `categorization-service.js`. Validate `formalityScore` with existing `validateFormalityScore` function.
- **No new dependencies** on API or mobile. Everything needed is already installed.

### Architecture Compliance

- **AI calls brokered only by Cloud Run.** The mobile client uploads the image and calls the API endpoint. The API calls Gemini. The mobile client never calls Gemini directly.
- **Server-side rate limiting.** Usage quotas enforced via `premiumGuard.checkUsageQuota` on the API. Client shows the gate but does not enforce limits. URL + screenshot scans share the same quota.
- **Epic 8 component mapping:** `mobile/features/shopping`, `api/modules/shopping`, `api/modules/ai` (architecture.md).
- **Media upload via signed URLs.** Screenshots follow the same upload pattern as wardrobe photos: client gets signed URL from API, uploads directly to storage, then sends the public URL to the API for processing.
- **Error handling standard:** 400 for validation, 401 for auth, 422 for extraction failures, 429 for rate limits.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `@google-cloud/vertexai` via `geminiClient`, `pg` via pool, upload service for signed URLs.
- **Mobile:** No new dependencies. Uses existing `image_picker` (^1.1.2), existing `api_client.dart`, existing `PremiumGateCard`, existing `SubscriptionService`.

### File Structure Requirements

- No new files or directories. All changes are modifications to existing files created in Story 8.1 and earlier.
- The `apps/api/src/modules/shopping/` directory already exists from Story 8.1.
- The `apps/mobile/lib/src/features/shopping/` directory already exists from Story 8.1.
- Test additions go into existing test files created in Story 8.1.

### Testing Requirements

- **API tests** extend existing files from Story 8.1. Use the same Node.js built-in test runner patterns.
- **Mock the Gemini client** in shopping scan service tests. Do NOT make real API calls.
- **Mock the upload service** signed URL generation. Return a mock `{ uploadUrl, publicUrl }`.
- **Flutter widget tests** extend existing files. Use existing `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services pattern.
- **Mock ImagePicker** in widget tests. Inject via optional constructor parameter.
- **Target:** All existing tests continue to pass (738 API tests, 1171 Flutter tests from Story 8.1) plus new tests.

### Previous Story Intelligence

- **Story 8.1** (done, predecessor) established: `shopping_scans` table (024 migration) with `scan_type IN ('url', 'screenshot')`, `shopping-scan-service.js` with `scanUrl()` + `downloadImage()` + `mergeProductData()` + `PRODUCT_IMAGE_PROMPT` + `AI_FALLBACK_PROMPT` + `validateFormalityScore()`, `shopping-scan-repository.js` with `createScan()` / `getScanById()` / `listScans()`, `url-scraper-service.js`, `ShoppingScan` Dart model, `ShoppingScanService` Dart service, `ShoppingScanScreen` with URL input + disabled screenshot placeholder + result card display + PremiumGateCard. **738 API tests, 1171 Flutter tests.** 33 services in `createRuntime()`.
- **Story 8.1 key patterns:**
  - `ShoppingScanScreen` constructor takes `{ shoppingScanService, subscriptionService }`. This story adds `apiClient` and optional `imagePicker`.
  - The disabled screenshot placeholder is an `Opacity(opacity: 0.5, ...)` widget with "Coming Soon" text at line 213-259 of `shopping_scan_screen.dart`.
  - The `_buildResultCard()` method displays scan results and is reused for screenshot results.
  - `downloadImage(imageUrl)` utility (exported) downloads image and converts to base64 for Gemini.
  - `estimateCost(usageMetadata)` utility for AI usage logging.
  - The service factory pattern: `createShoppingScanService({ urlScraperService, geminiClient, aiUsageLogRepo, shoppingScanRepo, pool })`.
- **Story 2.1** (done) established: `image_picker` usage pattern with `pickImage(source:, maxWidth:, imageQuality:)`, `AddItemScreen` camera/gallery selection UX, signed URL upload pipeline (getSignedUploadUrl -> uploadImage -> API call).
- **Story 2.2** (done) established: Gemini vision analysis pattern, `ai_usage_log` table, AI usage logging pattern, fire-and-forget for non-blocking AI, `@google-cloud/vertexai` SDK.
- **Story 1.5** (done) established: Upload service with `generateSignedUploadUrl` accepting `purpose` parameter, `"item_photo"` purpose pattern. Upload path: `users/{uid}/items/{uuid}.jpg`.
- **`createRuntime()` returns 33 services** (as of Story 8.1). No new services needed for this story -- `shoppingScanService` already exists and gets the new `scanScreenshot` method.
- **`handleRequest` destructuring** includes `shoppingScanService`, `shoppingScanRepo` from Story 8.1. No changes to destructuring needed.
- **`mapError` function** handles 400, 401, 403, 404, 409, 422, 429, 500, 503. No changes needed.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. The mobile client uploads the image to Cloud Storage and sends the public URL to the API. The API downloads the image and calls Gemini.
- DO NOT create a new Gemini client or service. Add the `scanScreenshot` method to the existing `createShoppingScanService` factory.
- DO NOT create new files. All changes are to existing files.
- DO NOT create a new database migration. The `shopping_scans` table already supports `scan_type = 'screenshot'` from Story 8.1.
- DO NOT use a separate rate limit quota for screenshots. URL scans and screenshot scans share the same `shopping_scan` quota.
- DO NOT implement compatibility scoring, insights, or wishlist. Those are Stories 8.4 and 8.5.
- DO NOT implement the review/edit flow for extracted data. That is Story 8.3. This story just shows the raw extraction result.
- DO NOT skip AI usage logging on failure. Both success and failure must be logged.
- DO NOT use free-text for taxonomy fields. Always validate against the fixed taxonomy arrays from Story 2.3.
- DO NOT run the two Gemini calls sequentially. Use `Promise.all` to parallelize taxonomy + text extraction and meet the 5-second performance budget.
- DO NOT block on missing text extraction. If Gemini cannot extract product name/brand/price from the screenshot, persist the scan with whatever taxonomy data is available (category, color, etc.) and set text fields to NULL.
- DO NOT add a new upload dependency. Use the existing signed URL upload pattern via `apiClient.getSignedUploadUrl` and `apiClient.uploadImage`.
- DO NOT modify the existing `scanUrl` method. The `scanScreenshot` method is a new, separate method in the same service.

### Out of Scope

- **Review/edit extracted product data** (Story 8.3)
- **Compatibility scoring** (Story 8.4)
- **Match display, insights, wishlist** (Story 8.5)
- **Empty wardrobe CTA** (Story 8.5 -- FR-SHP-12)
- **Video or multi-image screenshot analysis** -- single image only
- **OCR or text recognition beyond Gemini vision** -- Gemini handles all text extraction

### References

- [Source: epics.md - Story 8.2: Product Screenshot Upload]
- [Source: epics.md - Epic 8: Shopping Assistant, FR-SHP-01, FR-SHP-04]
- [Source: prd.md - FR-SHP-01: Users shall analyze potential purchases by uploading a screenshot from gallery or camera]
- [Source: prd.md - FR-SHP-04: The system shall extract structured product data: name, category, color, secondary colors, style, material, pattern, season, formality score (1-10), brand, price]
- [Source: prd.md - NFR-PERF-03: Screenshot product analysis < 5 seconds]
- [Source: prd.md - FR-SHP-11: Scanned products shall be stored in shopping_scans for history and re-analysis]
- [Source: prd.md - Free tier: 3 shopping scans/day, Premium: unlimited shopping scans]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Epic 8 Shopping Assistant -> mobile/features/shopping, api/modules/shopping, api/modules/ai]
- [Source: architecture.md - Important tables: shopping_scans, shopping_wishlists]
- [Source: architecture.md - Gated features include shopping scans]
- [Source: architecture.md - Taxonomy validation on structured outputs, safe defaults when AI confidence is low]
- [Source: 8-1-product-url-scraping.md - shopping_scans table, PRODUCT_IMAGE_PROMPT, downloadImage, validateFormalityScore, validateTaxonomy, ShoppingScanScreen placeholder, PremiumGateCard, shared quota]
- [Source: 2-1-upload-item-photo-camera-gallery.md - image_picker pattern, camera/gallery UX, signed URL upload pipeline]
- [Source: 2-2-ai-background-removal-upload.md - Gemini vision analysis pattern, ai_usage_log, AI usage logging]
- [Source: 1-5-onboarding-profile-setup-first-5-items.md - upload service, generateSignedUploadUrl, purpose parameter]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented `scanScreenshot` method in `shopping-scan-service.js` with parallel Gemini calls (taxonomy + text extraction) via `Promise.all`
- Added `SCREENSHOT_TEXT_PROMPT` constant for text metadata extraction from screenshots
- Added `shopping_screenshot` to ALLOWED_PURPOSES in upload service with `users/{uid}/shopping/{uuid}.jpg` path
- Wired `POST /v1/shopping/scan-screenshot` endpoint with shared quota enforcement (URL + screenshot scans count together)
- Added `scanScreenshot` to mobile `ShoppingScanService` and `scanProductScreenshot` to `ApiClient`
- Replaced disabled screenshot placeholder with active card (GestureDetector, full opacity, indigo icon, "Analyze from photo or screenshot" subtitle)
- Implemented screenshot upload flow: bottom sheet (Take Photo / Choose from Gallery) -> ImagePicker -> signed URL upload -> server-side AI analysis -> result display
- Added `apiClient` and optional `imagePicker` parameters to `ShoppingScanScreen` constructor
- Updated profile screen navigation to pass `apiClient` to `ShoppingScanScreen`
- All error states handled: 429 -> PremiumGateCard, 422 -> "Try a URL instead" suggestion, generic -> retry
- Semantics labels on all interactive elements
- 750 API tests pass (738 baseline + 12 new), 1178 Flutter tests pass (1171 baseline + 7 new)
- Zero new flutter analyze issues

### Change Log

- 2026-03-19: Story 8.2 implemented -- Product screenshot upload with parallel Gemini vision analysis

### File List

- `apps/api/src/modules/uploads/service.js` (modified: added "shopping_screenshot" purpose)
- `apps/api/src/modules/shopping/shopping-scan-service.js` (modified: added SCREENSHOT_TEXT_PROMPT, scanScreenshot method)
- `apps/api/src/main.js` (modified: added POST /v1/shopping/scan-screenshot route)
- `apps/api/test/modules/shopping/shopping-scan-service.test.js` (modified: added scanScreenshot unit tests)
- `apps/api/test/modules/shopping/shopping-scan-endpoint.test.js` (modified: added screenshot endpoint integration tests)
- `apps/api/test/items-endpoint.test.js` (modified: added shopping_screenshot upload purpose test)
- `apps/mobile/lib/src/features/shopping/screens/shopping_scan_screen.dart` (modified: activated screenshot card, added upload+scan flow, added apiClient/imagePicker params)
- `apps/mobile/lib/src/features/shopping/services/shopping_scan_service.dart` (modified: added scanScreenshot method)
- `apps/mobile/lib/src/core/networking/api_client.dart` (modified: added scanProductScreenshot method)
- `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (modified: pass apiClient to ShoppingScanScreen)
- `apps/mobile/test/features/shopping/screens/shopping_scan_screen_test.dart` (modified: added screenshot flow widget tests)
- `apps/mobile/test/core/networking/api_client_test.dart` (modified: added scanProductScreenshot test)
