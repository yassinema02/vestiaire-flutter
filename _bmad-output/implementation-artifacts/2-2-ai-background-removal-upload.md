# Story 2.2: AI Background Removal & Upload

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the background of my clothing photo to be automatically removed after upload,
so that my digital wardrobe looks clean and consistent with professional-looking item images.

## Acceptance Criteria

1. Given I have uploaded a photo via the Add Item flow (Story 2.1), when the image is stored in Cloud Storage, then the Cloud Run API triggers Gemini 2.0 Flash to perform background removal on the uploaded image server-side.
2. Given the Gemini background removal succeeds, when the cleaned image is produced, then the API stores the cleaned image (transparent/white background) back in Cloud Storage under the same user's items path with a `_cleaned` suffix (e.g., `users/{uid}/items/{uuid}_cleaned.png`) and updates the item's `photo_url` to point to the cleaned image.
3. Given the Gemini background removal succeeds, when the item record is updated, then the item's `original_photo_url` column preserves the original uploaded image URL so the user can always revert or compare.
4. Given the Gemini background removal fails (timeout, rate limit, API error), when the error occurs, then the API logs the failure to `ai_usage_log`, keeps the original photo as the item's `photo_url`, sets `bg_removal_status` to `'failed'`, and returns a success response for the item creation (do NOT block item creation on AI failure).
5. Given the background removal is processing, when the mobile client polls or receives the updated item, then the client displays a shimmer/skeleton loading state on the item image in the wardrobe grid until the cleaned image is available.
6. Given the background removal completes (success or failure), when the mobile client fetches the item, then the `bg_removal_status` field indicates `'completed'`, `'failed'`, or `'pending'` so the client can show appropriate UI (cleaned image, original with retry option, or loading state).
7. Given a background removal failed, when the user views the item, then they see a "Retry" option that triggers `POST /v1/items/:id/remove-background` to re-attempt background removal.
8. Given the API processes a background removal request, when the Gemini call is made, then the API logs the request to `ai_usage_log` with model name, token count, latency, and cost estimate (FR: NFR-OBS-02).
9. Given the entire upload + background removal pipeline runs, when measured end-to-end, then the total time from photo selection to cleaned image available is under 5 seconds for typical images (NFR-PERF-01).

## Tasks / Subtasks

- [x] Task 1: Database migration for background removal columns and AI usage log (AC: 3, 4, 6, 8)
  - [x] 1.1: Create `infra/sql/migrations/006_items_bg_removal.sql`: ALTER TABLE `app_public.items` ADD COLUMN `original_photo_url` TEXT, ADD COLUMN `bg_removal_status` TEXT CHECK (`bg_removal_status` IN ('pending', 'completed', 'failed')) DEFAULT NULL. When `bg_removal_status` is NULL, no background removal has been attempted.
  - [x] 1.2: Create `infra/sql/migrations/007_ai_usage_log.sql`: CREATE TABLE `app_public.ai_usage_log` with columns: `id` UUID PK, `profile_id` UUID FK to profiles, `feature` TEXT NOT NULL (e.g., 'background_removal'), `model` TEXT NOT NULL (e.g., 'gemini-2.0-flash'), `input_tokens` INTEGER, `output_tokens` INTEGER, `latency_ms` INTEGER, `estimated_cost_usd` NUMERIC(10,6), `status` TEXT CHECK IN ('success', 'failure'), `error_message` TEXT, `created_at` TIMESTAMPTZ DEFAULT NOW(). Add RLS policy allowing users to read only their own logs.
  - [x] 1.3: Create `infra/sql/policies/004_ai_usage_log_rls.sql`: Enable RLS on `ai_usage_log`, policy for SELECT where `profile_id` matches the authenticated user's profile. INSERT allowed by the API service role.

- [x] Task 2: Integrate Vertex AI / Gemini SDK on the API server (AC: 1, 8)
  - [x] 2.1: Add `@google-cloud/vertexai` to `apps/api/package.json` dependencies. This is the official Google Cloud Vertex AI SDK for Node.js that provides access to Gemini models.
  - [x] 2.2: Add `VERTEX_AI_LOCATION` to `apps/api/src/config/env.js` (`resolvedEnv.VERTEX_AI_LOCATION ?? "europe-west1"`), and `GCP_PROJECT_ID` (`resolvedEnv.GCP_PROJECT_ID ?? ""`). These are required by the Vertex AI SDK.
  - [x] 2.3: Create `apps/api/src/modules/ai/gemini-client.js`: A thin wrapper around `@google-cloud/vertexai` that initializes `VertexAI({ project: config.gcpProjectId, location: config.vertexAiLocation })` and exposes a `getGenerativeModel(modelName)` method. This is the single AI client for ALL future AI features (categorization, outfit generation, etc.).
  - [x] 2.4: Create `apps/api/src/modules/ai/background-removal-service.js`: Export `createBackgroundRemovalService({ geminiClient, uploadService, aiUsageLogRepo })`. The service has a single method `removeBackground(authContext, { itemId, imageUrl })` that: (a) downloads the image from Cloud Storage (or local path), (b) calls Gemini 2.0 Flash with an image editing prompt to remove the background, (c) uploads the cleaned image back to storage, (d) logs the AI call to `ai_usage_log`, (e) returns `{ cleanedImageUrl, status }`.
  - [x] 2.5: Create `apps/api/src/modules/ai/ai-usage-log-repository.js`: Export `createAiUsageLogRepository({ pool })` with a `logUsage(authContext, { feature, model, inputTokens, outputTokens, latencyMs, estimatedCostUsd, status, errorMessage })` method that inserts into `ai_usage_log`.

- [x] Task 3: API endpoint for background removal (AC: 1, 4, 7, 9)
  - [x] 3.1: Modify `apps/api/src/modules/items/service.js`: Update `createItemForUser` to accept the new fields and after creating the item, trigger background removal asynchronously (fire-and-forget, do NOT await). Set `bg_removal_status = 'pending'` on the newly created item.
  - [x] 3.2: Modify `apps/api/src/modules/items/repository.js`: Update `createItem` to include `original_photo_url` and `bg_removal_status` in the INSERT. Update `mapItemRow` to include the new columns in the response. Add an `updateItem(authContext, itemId, fields)` method for updating `photo_url`, `bg_removal_status` after background removal completes.
  - [x] 3.3: Add route `POST /v1/items/:id/remove-background` in `apps/api/src/main.js`. This endpoint: authenticates the user, looks up the item (ensuring ownership via profile_id), and triggers `backgroundRemovalService.removeBackground(authContext, { itemId, imageUrl: item.originalPhotoUrl || item.photoUrl })`. Returns `{ status: 'processing' }` immediately (202 Accepted).
  - [x] 3.4: Wire up the `backgroundRemovalService` in `createRuntime()` in `main.js`: create the gemini client, AI usage log repo, and background removal service. Pass it to the items service for auto-triggering on item creation.
  - [x] 3.5: Update `GET /v1/items` response to include `originalPhotoUrl` and `bgRemovalStatus` fields in each item.

- [x] Task 4: Mobile client - update item model and display logic (AC: 5, 6, 7)
  - [x] 4.1: Update `ApiClient.createItem` return type handling to parse `originalPhotoUrl` and `bgRemovalStatus` from the API response. Update `listItems` similarly.
  - [x] 4.2: Create an item model class `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` with fields: `id`, `profileId`, `photoUrl`, `originalPhotoUrl`, `name`, `bgRemovalStatus`, `createdAt`, `updatedAt`. Include `fromJson` factory and a getter `isProcessing` that returns `bgRemovalStatus == 'pending'`.
  - [x] 4.3: Update `WardrobeScreen` grid to show a shimmer/skeleton overlay on items where `bgRemovalStatus == 'pending'`. Use a simple animated `LinearGradient` shimmer effect (no new dependency needed -- implement with `AnimationController` and `ShaderMask`).
  - [x] 4.4: Add a polling mechanism in `WardrobeScreen`: if any visible items have `bgRemovalStatus == 'pending'`, re-fetch items every 3 seconds (max 10 retries, then stop). When the status changes, rebuild the grid.
  - [x] 4.5: Add `retryBackgroundRemoval(String itemId)` method to `ApiClient` that calls `POST /v1/items/$itemId/remove-background`. Returns the response map.
  - [x] 4.6: In the wardrobe grid, for items with `bgRemovalStatus == 'failed'`, show a small warning badge/icon overlay. When tapped (future Story 2.6 will add the detail view), the retry will be accessible. For now, add a long-press context menu on failed items with a "Retry Background Removal" option.

- [x] Task 5: Update AddItemScreen upload flow (AC: 1, 5, 9)
  - [x] 5.1: Update `AddItemScreen._handleImage` to pass through the response from `createItem` and check for `bgRemovalStatus`. The upload flow itself does NOT change -- the server auto-triggers background removal. But the success SnackBar should say "Item added! Background is being cleaned..." instead of just "Item added!" when `bgRemovalStatus == 'pending'`.
  - [x] 5.2: After successful upload, when switching to the Wardrobe tab, the `WardrobeScreen` should refresh and show the new item with shimmer overlay while background removal is pending.

- [x] Task 6: Widget tests for new mobile functionality (AC: all)
  - [x] 6.1: Create/update `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart`: Test `WardrobeItem.fromJson`, `isProcessing` getter for all status values (null, pending, completed, failed).
  - [x] 6.2: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`: Test shimmer overlay appears for pending items. Test failed items show warning badge. Test polling refreshes the list. Test polling stops after status changes.
  - [x] 6.3: Update `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`: Test updated success SnackBar message includes "Background is being cleaned..." when response has bgRemovalStatus = pending.
  - [x] 6.4: Test `ApiClient.retryBackgroundRemoval` calls the correct endpoint.

- [x] Task 7: API tests for background removal (AC: 1, 4, 7, 8)
  - [x] 7.1: Create `apps/api/test/modules/ai/background-removal-service.test.js`: Test that `removeBackground` calls gemini client, uploads cleaned image, logs to `ai_usage_log`, and returns status. Test failure path: gemini call fails, logs error, returns failed status.
  - [x] 7.2: Create `apps/api/test/modules/ai/ai-usage-log-repository.test.js`: Test `logUsage` inserts a row with correct fields.
  - [x] 7.3: Update `apps/api/test/modules/items/service.test.js` (if exists) or create: Test that `createItemForUser` sets `bg_removal_status` to `'pending'` and fires background removal asynchronously.
  - [x] 7.4: Test the `POST /v1/items/:id/remove-background` endpoint returns 202, triggers background removal, and returns error for items not owned by the user.

- [x] Task 8: Regression testing (AC: all)
  - [x] 8.1: Run `flutter analyze` -- zero issues.
  - [x] 8.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 8.3: Run `npm --prefix apps/api test` -- all existing + new tests pass.
  - [x] 8.4: Verify the existing AddItemScreen upload flow still works end-to-end (camera + gallery paths).
  - [x] 8.5: Verify `GET /v1/items` returns backward-compatible response (new fields are nullable, old clients can ignore them).

## Dev Notes

- This is the SECOND story in Epic 2. It introduces the first AI feature in the entire application. The AI module (`apps/api/src/modules/ai/`) does not yet exist and must be created from scratch. This module will be reused by Stories 2.3 (categorization), 4.x (outfit generation), 8.x (shopping analysis), and others.
- The architecture mandates ALL AI calls go through Vertex AI / Gemini 2.0 Flash, brokered only by Cloud Run. Never expose AI API keys or calls to the mobile client.
- The `@google-cloud/vertexai` npm package is the official SDK. On Cloud Run with Application Default Credentials, it auto-authenticates. For local dev, set `GOOGLE_APPLICATION_CREDENTIALS` env var pointing to a service account JSON. Add this to `.env.example`.
- Background removal with Gemini 2.0 Flash uses the image generation/editing capability. The prompt should be: "Remove the background from this clothing item photo. Replace the background with a clean white background. Keep the clothing item intact with clean edges." Send the image as inline data with the prompt.
- The items table currently has: `id`, `profile_id`, `photo_url`, `name`, `created_at`, `updated_at`. This story adds `original_photo_url` and `bg_removal_status` via ALTER TABLE. Story 2.3 will add categorization columns (category, color, material, etc.). Do NOT add categorization columns in this story.
- Background removal is fire-and-forget from the item creation flow. `POST /v1/items` returns immediately with `bgRemovalStatus: 'pending'`. A background async process (or in-process promise) handles the Gemini call, image re-upload, and item update. This keeps the upload fast (< 1s for item creation) while allowing up to 5s total for the background removal pipeline.
- For local development without GCP credentials, the Gemini client should gracefully degrade: if `GCP_PROJECT_ID` is not set, skip background removal and set `bg_removal_status` to `null` (not attempted). Log a warning. This prevents local dev from requiring Vertex AI credentials.
- The `ai_usage_log` table is a cross-cutting concern used by ALL AI features. Create it now with a general schema. Every AI call in future stories (categorization, outfit gen, etc.) will log to this table.

### Project Structure Notes

- New directories:
  - `apps/api/src/modules/ai/` -- AI module (gemini client, background removal service, usage log repo)
  - `apps/api/test/modules/ai/` -- AI module tests
  - `apps/mobile/lib/src/features/wardrobe/models/` -- wardrobe data models
  - `apps/mobile/test/features/wardrobe/models/` -- model tests
- New files:
  - `infra/sql/migrations/006_items_bg_removal.sql`
  - `infra/sql/migrations/007_ai_usage_log.sql`
  - `infra/sql/policies/004_ai_usage_log_rls.sql`
  - `apps/api/src/modules/ai/gemini-client.js`
  - `apps/api/src/modules/ai/background-removal-service.js`
  - `apps/api/src/modules/ai/ai-usage-log-repository.js`
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`
- Modified files:
  - `apps/api/package.json` (add `@google-cloud/vertexai`)
  - `apps/api/src/config/env.js` (add `vertexAiLocation`, `gcpProjectId`)
  - `apps/api/src/main.js` (add AI services to runtime, add POST /v1/items/:id/remove-background route)
  - `apps/api/src/modules/items/service.js` (trigger bg removal on create)
  - `apps/api/src/modules/items/repository.js` (new columns, updateItem method)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add retryBackgroundRemoval method)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (shimmer, polling, failed badge)
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (updated success message)
  - `.env.example` (add GOOGLE_APPLICATION_CREDENTIALS, VERTEX_AI_LOCATION, GCP_PROJECT_ID)

### Technical Requirements

- `@google-cloud/vertexai` -- latest stable version. This is the ONLY AI dependency. Do NOT use `@google/generative-ai` (that's the non-Vertex consumer SDK, not suitable for server-side Cloud Run usage with ADC).
- Gemini 2.0 Flash model identifier: `gemini-2.0-flash`. Use `generateContent` with image inline data (base64) and a text prompt for background removal.
- Image format: The cleaned image should be PNG (to support transparency) or JPEG with white background. Upload with `contentType: 'image/png'` for the cleaned version.
- The `@google-cloud/storage` package is NOT yet installed. For this story, the background removal service can download/upload images using the existing upload service's local fallback pattern. For production GCS, add `@google-cloud/storage` to package.json and use it in the background removal service to download the original and upload the cleaned image.

### Architecture Compliance

- AI calls are brokered ONLY by Cloud Run (architecture: "AI calls are brokered only by Cloud Run"). The mobile client never calls Gemini directly.
- All AI workloads route through Vertex AI / Gemini 2.0 Flash (architecture: "Single AI provider").
- AI orchestration includes taxonomy validation, safe defaults on failure, retry/backoff, and per-user logging (architecture: AI Orchestration Guardrails).
- Media remains private, delivered via signed URLs (architecture: Media and Storage).
- RLS on `ai_usage_log` ensures users only see their own data (architecture: Database rules).
- Item creation remains transactional; background removal is async and does not block the main flow.

### Library / Framework Requirements

- API new dependency: `@google-cloud/vertexai` (latest stable, currently ^1.x)
- API new dependency: `@google-cloud/storage` (latest stable, currently ^7.x) -- for downloading/uploading images from/to GCS
- Mobile: No new dependencies. Shimmer effect is implemented with Flutter's built-in `AnimationController` + `ShaderMask`.
- Existing dependencies used: `pg` (database), `firebase-admin` (auth), `image_picker` (mobile), `http` (mobile API calls).

### File Structure Requirements

- The `apps/api/src/modules/ai/` directory is the canonical location for ALL AI-related server code (architecture: Epic-to-Component Mapping: Epic 2 -> `api/modules/ai`).
- The `gemini-client.js` is a singleton-style factory that ALL AI features will import. Do NOT create separate Gemini clients per feature.
- The `ai-usage-log-repository.js` is a shared repository. Future stories (2.3, 4.x, etc.) will import and reuse it.
- Migration files follow sequential numbering: 006, 007 (after existing 005_push_notifications.sql).
- RLS policy files follow sequential numbering: 004 (after existing 003_items_rls.sql).

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow the same patterns as existing tests in `apps/api/test/`.
- Mock the Gemini client in background removal service tests. Do NOT make real API calls in tests.
- Mock the file system / storage in tests. Use in-memory or stub responses.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient.
- Test the graceful degradation path: when Gemini fails, item creation still succeeds with original photo.
- Test polling: verify that `WardrobeScreen` re-fetches when pending items exist and stops when resolved.
- Target: all existing tests continue to pass (191 Flutter tests, 46 API tests from Story 2.1).

### Previous Story Intelligence

- Story 2.1 established: `AddItemScreen` with camera/gallery, 3-step upload pipeline (`getSignedUploadUrl` -> `uploadImage` -> `createItem`), `MainShellScreen` with 5-tab navigation, `WardrobeScreen` with basic grid, `ApiClient` methods for items. 191 Flutter tests, 46 API tests.
- Story 2.1 key pattern: Image compression is handled by `image_picker` with `maxWidth: 512, imageQuality: 85`. This produces JPEG images. The background removal service receives JPEG and outputs PNG (for transparency).
- Story 2.1 completion note: Widget tests use `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + `_TestAuthService` override. Use `tester.runAsync()` for tests involving real I/O.
- Story 1.5 established: The upload service (`apps/api/src/modules/uploads/service.js`) with `generateSignedUploadUrl` supporting `item_photo` purpose. The upload path pattern is `users/{uid}/items/{uuid}.jpg`.
- Story 1.7 established: `firebase-admin` SDK integration. 167 Flutter tests, 46 API tests at that point.
- The `mapItemRow` function in `items/repository.js` currently maps: `id`, `profileId`, `photoUrl`, `name`, `createdAt`, `updatedAt`. It MUST be extended to include `originalPhotoUrl` and `bgRemovalStatus`.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. All AI calls go through the Cloud Run API.
- DO NOT block item creation on background removal. The `POST /v1/items` endpoint must return immediately. Background removal is async.
- DO NOT use `@google/generative-ai` package. Use `@google-cloud/vertexai` for server-side Vertex AI access with Application Default Credentials.
- DO NOT add item categorization (category, color, material columns) in this story. That is Story 2.3.
- DO NOT create a separate Gemini client per AI feature. Create one shared client in `modules/ai/gemini-client.js`.
- DO NOT require GCP credentials for local dev to work. Gracefully degrade when `GCP_PROJECT_ID` is not set.
- DO NOT use a third-party shimmer package on mobile. Implement with built-in Flutter animation primitives.
- DO NOT break the existing `POST /v1/items` or `GET /v1/items` API contracts. New fields are additive and nullable.
- DO NOT await the background removal promise in the item creation handler. Use fire-and-forget (`.catch(err => log(err))`).

### Implementation Guidance

- **Gemini client initialization:** `const { VertexAI } = require('@google-cloud/vertexai'); const vertexAI = new VertexAI({ project: config.gcpProjectId, location: config.vertexAiLocation }); const model = vertexAI.getGenerativeModel({ model: 'gemini-2.0-flash' });`
- **Background removal prompt:** Send the image as `inlineData` (base64-encoded) with the prompt: "Remove the background from this clothing item image. Replace the background with solid white (#FFFFFF). Preserve the clothing item with clean, natural edges. Output only the processed image."
- **Fire-and-forget pattern in item service:** After `repo.createItem(...)`, call `backgroundRemovalService.removeBackground(authContext, { itemId: item.id, imageUrl: item.photoUrl }).catch(err => console.error('[bg-removal] Failed:', err))`. Do NOT await this.
- **Polling on mobile:** In `WardrobeScreen`, use a `Timer.periodic(Duration(seconds: 3))` that calls `apiClient.listItems()` when any item has `bgRemovalStatus == 'pending'`. Cancel the timer in `dispose()` and when no more pending items exist. Cap at 10 retries to avoid infinite polling.
- **Shimmer effect:** Use `AnimationController(duration: Duration(milliseconds: 1500), vsync: this)..repeat()` with a `LinearGradient` that translates across the image placeholder. Wrap in a `ShaderMask` or use `AnimatedBuilder` with `Opacity`.
- **Route pattern for items/:id:** In `main.js`, parse the URL pathname to extract the item ID: `const match = url.pathname.match(/^\/v1\/items\/([^/]+)\/remove-background$/); if (req.method === 'POST' && match) { ... }`.

### References

- [Source: epics.md - Story 2.2: AI Background Removal & Upload]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: architecture.md - AI Orchestration: Vertex AI / Gemini 2.0 Flash]
- [Source: architecture.md - Media and Storage: signed URLs, private buckets]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 2 -> api/modules/ai]
- [Source: architecture.md - AI Guardrails: taxonomy validation, safe defaults, retry/backoff, per-user logging]
- [Source: prd.md - FR-WRD-03: Private cloud storage scoped to user ID]
- [Source: prd.md - FR-WRD-04: Background removal via Gemini 2.0 Flash server-side]
- [Source: prd.md - NFR-PERF-01: Image upload + background removal < 5 seconds]
- [Source: prd.md - NFR-OBS-02: AI API costs logged per-user in ai_usage_log]
- [Source: prd.md - NFR-SEC-01: All API keys stored server-side only]
- [Source: ux-design-specification.md - Shimmer skeleton screens for AI loading states]
- [Source: ux-design-specification.md - Micro-animations during AI categorization to feel magical]
- [Source: ux-design-specification.md - Always provide manual fallback on AI failure]
- [Source: 2-1-upload-item-photo-camera-gallery.md - Upload pipeline, items table schema, test patterns]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None required.

### Completion Notes List

- All 8 tasks completed successfully with all subtasks.
- Flutter tests: 211 passing (was 191, added 20 new tests).
- API tests: 64 passing (was 46, added 18 new tests).
- Flutter analyze: zero issues.
- Gemini client gracefully degrades when GCP_PROJECT_ID is not set.
- Background removal is fire-and-forget; item creation never blocked.
- Shimmer animation uses built-in Flutter primitives (AnimationController + ShaderMask).
- Polling stops after 10 retries or when no pending items remain.
- Failed items show warning badge with long-press context menu for retry.

### File List

**New files:**
- `infra/sql/migrations/006_items_bg_removal.sql`
- `infra/sql/migrations/007_ai_usage_log.sql`
- `infra/sql/policies/004_ai_usage_log_rls.sql`
- `apps/api/src/modules/ai/gemini-client.js`
- `apps/api/src/modules/ai/background-removal-service.js`
- `apps/api/src/modules/ai/ai-usage-log-repository.js`
- `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`
- `apps/api/test/modules/ai/background-removal-service.test.js`
- `apps/api/test/modules/ai/ai-usage-log-repository.test.js`
- `apps/api/test/modules/items/service.test.js`
- `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart`

**Modified files:**
- `apps/api/package.json`
- `apps/api/src/config/env.js`
- `apps/api/src/main.js`
- `apps/api/src/modules/items/service.js`
- `apps/api/src/modules/items/repository.js`
- `apps/mobile/lib/src/core/networking/api_client.dart`
- `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`
- `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`
- `apps/api/test/items-endpoint.test.js`
- `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`
- `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`
- `apps/mobile/test/core/networking/api_client_test.dart`
