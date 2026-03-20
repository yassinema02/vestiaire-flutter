# Story 1.5: Onboarding Profile Setup & First 5 Items

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to complete or skip a lightweight onboarding flow after my first sign-in,
so that I can personalize the app quickly and be encouraged to start building my wardrobe without being blocked from using it.

## Acceptance Criteria

1. Given I have authenticated successfully for the first time (profile was just provisioned), when the home shell loads, then the app detects that my profile is incomplete (no display name set) and presents the onboarding flow instead of the regular home screen.
2. Given I am on the onboarding profile step, when I enter my display name and optionally select style preferences (casual, streetwear, minimalist, classic, bohemian, sporty, vintage, glamorous), then I can proceed to the next step with the data saved to the `profiles` table via PUT /v1/profiles/me.
3. Given I am on the onboarding photo step, when I tap to add a profile photo, then I can select from my device gallery, the image is uploaded via the API, and my profile photo URL is persisted to the `profiles` table.
4. Given I am on the onboarding photo step, when I choose to skip the photo, then I can proceed without a photo and a default avatar placeholder is shown.
5. Given I have completed the profile setup steps, when the onboarding transitions to the "First 5 Items" challenge screen, then I see an encouraging card explaining the challenge with a progress indicator (0/5 items) and a prominent "Add Your First Item" button.
6. Given I am on the "First 5 Items" challenge screen, when I tap "Add Item", then I can take a photo or select from gallery, the image is uploaded to Cloud Storage via the API, and a minimal item record is created in the `items` table with just the photo URL and profile reference (no AI categorization in this story).
7. Given I have added items via the challenge, when I view the challenge screen, then the progress indicator updates in real-time (e.g., "3/5 items added") and items I have added are shown as thumbnails.
8. Given I am at any point in the onboarding flow, when I tap "Skip" or "Skip for now", then the onboarding is dismissed, my `onboarding_completed_at` timestamp is set on the profile, and I land on the regular home shell.
9. Given I have completed all 5 items (or tapped "Done" after adding at least 1 item), when the challenge completes, then a success animation plays, `onboarding_completed_at` is set, and I land on the regular home shell.
10. Given I have previously completed onboarding (onboarding_completed_at is set), when I launch the app on subsequent sessions, then the onboarding flow is not shown and I go directly to the home shell.
11. Given I update my display name or photo, when the API responds successfully, then the change is reflected immediately in the app UI without requiring a restart.

## Tasks / Subtasks

- [x] Task 1: Add profile onboarding columns to the database. (AC: 1, 2, 3, 4, 8, 10)
  - [x]1.1: Create `infra/sql/migrations/003_profile_onboarding.sql` that adds the following columns to `app_public.profiles`: `display_name text`, `photo_url text`, `style_preferences text[] default '{}'`, `onboarding_completed_at timestamptz`.
  - [x]1.2: Add a comment on each new column for documentation.
  - [x]1.3: Ensure the migration applies cleanly on top of 002_profiles.sql. Use `ALTER TABLE` inside a `begin/commit` transaction block.

- [x] Task 2: Create the items table for wardrobe items (minimal schema for onboarding). (AC: 6, 7)
  - [x]2.1: Create `infra/sql/migrations/004_items_baseline.sql` with the `app_public.items` table containing: `id uuid primary key default gen_random_uuid()`, `profile_id uuid not null references app_public.profiles(id) on delete cascade`, `photo_url text not null`, `name text`, `created_at timestamptz not null default timezone('utc', now())`, `updated_at timestamptz not null default timezone('utc', now())`.
  - [x]2.2: Add an index on `profile_id` for efficient per-user queries.
  - [x]2.3: Apply the `app_private.set_updated_at()` trigger to the `items` table for automatic `updated_at` maintenance.
  - [x]2.4: Create `infra/sql/policies/003_items_rls.sql` enabling RLS on `app_public.items` with SELECT/INSERT/UPDATE/DELETE policies scoped to `current_setting('app.current_user_id', true)` matching the item's profile `firebase_uid` via a join to `profiles`, OR scoped via `profile_id` matching the profile whose `firebase_uid` equals `current_setting('app.current_user_id', true)`.

- [x] Task 3: Add API endpoint PUT /v1/profiles/me for profile updates. (AC: 2, 3, 4, 8, 11)
  - [x]3.1: In `apps/api/src/modules/profiles/repository.js`, add an `updateProfile(authContext, updates)` method that accepts a partial update object (`display_name`, `style_preferences`, `onboarding_completed_at`) and applies it to the authenticated user's profile row using a parameterized UPDATE query with RLS context set.
  - [x]3.2: In `apps/api/src/modules/profiles/service.js`, add an `updateProfileForAuthenticatedUser(authContext, updates)` method that validates the update payload (display_name max 100 chars, style_preferences is array of known values, onboarding_completed_at is valid timestamp or null) and delegates to the repository.
  - [x]3.3: In `apps/api/src/main.js`, register `PUT /v1/profiles/me` as a new route that reads the JSON body, calls the profile service update method, and returns the updated profile.
  - [x]3.4: Add input validation: reject unknown fields, enforce display_name length <= 100, validate style_preferences against allowed values (casual, streetwear, minimalist, classic, bohemian, sporty, vintage, glamorous).

- [x] Task 4: Add API endpoint for photo upload to Cloud Storage. (AC: 3, 6)
  - [x]4.1: Create `apps/api/src/modules/uploads/service.js` with a `generateSignedUploadUrl(authContext, { purpose, contentType })` method. For MVP, this generates a signed URL for Google Cloud Storage, scoped to the user's directory (`users/{firebase_uid}/profile/` for profile photos, `users/{firebase_uid}/items/` for item photos). If Cloud Storage is not yet configured, implement a local-storage fallback that saves to a configurable upload directory and returns a local URL.
  - [x]4.2: In `apps/api/src/main.js`, register `POST /v1/uploads/signed-url` that accepts `{ purpose: "profile_photo" | "item_photo", contentType: "image/jpeg" }` and returns `{ uploadUrl, publicUrl }`.
  - [x]4.3: Document in README that Cloud Storage signed URL generation requires `GOOGLE_CLOUD_STORAGE_BUCKET` environment variable. Add it to `.env.example`.

- [x] Task 5: Add API endpoints for items CRUD (minimal for onboarding). (AC: 6, 7)
  - [x]5.1: Create `apps/api/src/modules/items/repository.js` with methods: `createItem(authContext, { photoUrl, name })` that inserts into `app_public.items` with RLS context, and `listItems(authContext, { limit })` that returns the user's items ordered by `created_at desc`.
  - [x]5.2: Create `apps/api/src/modules/items/service.js` with methods: `createItemForUser(authContext, itemData)` and `listItemsForUser(authContext, options)`.
  - [x]5.3: In `apps/api/src/main.js`, register `POST /v1/items` (creates item, returns the new item) and `GET /v1/items` (returns the user's items with optional `?limit=N` query parameter).
  - [x]5.4: Wire the items module into `createRuntime()` in main.js following the existing pattern for profiles.

- [x] Task 6: Add API tests for new endpoints. (AC: 2, 3, 6, 7, 8)
  - [x]6.1: Add `apps/api/test/profile-update.test.js` testing: successful profile update with display_name, style_preferences, and onboarding_completed_at; validation rejection of too-long display_name; validation rejection of invalid style_preferences; partial update (only display_name without touching other fields); unauthenticated access returns 401.
  - [x]6.2: Add `apps/api/test/items-endpoint.test.js` testing: creating an item with photoUrl returns the created item; listing items returns the user's items; unauthenticated access returns 401.
  - [x]6.3: Ensure existing tests continue to pass: `npm --prefix apps/api test`.

- [x] Task 7: Build the mobile onboarding flow screens. (AC: 1, 2, 3, 4, 5, 8, 9, 10, 11)
  - [x]7.1: Create `apps/mobile/lib/src/features/onboarding/screens/onboarding_profile_screen.dart` with: display name text field (required, validated non-empty), style preferences multi-select chip grid (8 options: casual, streetwear, minimalist, classic, bohemian, sporty, vintage, glamorous), "Continue" button, "Skip" button. Follow Vibrant Soft-UI: #F3F4F6 background, #4F46E5 primary, 50px button height, 12px border radius, Semantics labels.
  - [x]7.2: Create `apps/mobile/lib/src/features/onboarding/screens/onboarding_photo_screen.dart` with: a circular avatar placeholder (large, 120px), a "Choose Photo" button that opens the device gallery via `image_picker`, a preview of the selected photo, "Continue" button, and "Skip" button.
  - [x]7.3: Create `apps/mobile/lib/src/features/onboarding/screens/first_five_items_screen.dart` with: a motivational header ("Build your wardrobe!"), a progress indicator bar (X/5 items), a grid showing thumbnails of added items, an "Add Item" button that opens the camera/gallery via `image_picker`, and "Done" / "Skip" buttons. The "Done" button is enabled after at least 1 item is added.
  - [x]7.4: Create `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart` as a coordinating widget that manages the multi-step flow (profile -> photo -> first-5-items) with a step indicator and back navigation. Track current step with an enum.

- [x] Task 8: Integrate onboarding with the app shell and API client. (AC: 1, 8, 9, 10, 11)
  - [x]8.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add methods: `updateProfile({String? displayName, List<String>? stylePreferences, DateTime? onboardingCompletedAt})` calling `PUT /v1/profiles/me`, `getSignedUploadUrl({required String purpose, String contentType = 'image/jpeg'})` calling `POST /v1/uploads/signed-url`, `createItem({required String photoUrl, String? name})` calling `POST /v1/items`, and `listItems({int? limit})` calling `GET /v1/items`.
  - [x]8.2: Add an `uploadImage(String filePath, String uploadUrl)` method to ApiClient (or a separate upload helper) that reads the file and PUTs it to the signed URL.
  - [x]8.3: In `apps/mobile/lib/src/app.dart`, modify `_provisionProfile()` to store the profile response. After profile provisioning, check if `onboarding_completed_at` is null; if so, set `_currentScreen` to an `_AuthScreen.onboarding` value (or a new `_AppScreen` enum for post-auth flow).
  - [x]8.4: When onboarding completes (either by finishing or skipping), call `updateProfile(onboardingCompletedAt: DateTime.now())` and transition to the home shell.
  - [x]8.5: Add `image_picker` dependency to `pubspec.yaml`.

- [x] Task 9: Add widget tests for onboarding screens. (AC: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
  - [x]9.1: Create `apps/mobile/test/features/onboarding/screens/onboarding_profile_screen_test.dart` verifying: display name field renders, style preference chips render all 8 options, tapping chips toggles selection, "Continue" requires non-empty display name, "Skip" button calls the skip callback, Semantics labels are present.
  - [x]9.2: Create `apps/mobile/test/features/onboarding/screens/onboarding_photo_screen_test.dart` verifying: avatar placeholder renders, "Choose Photo" button renders, "Skip" button calls the skip callback, "Continue" button is present.
  - [x]9.3: Create `apps/mobile/test/features/onboarding/screens/first_five_items_screen_test.dart` verifying: progress indicator starts at 0/5, "Add Item" button renders, "Skip" and "Done" buttons render, "Done" is disabled with 0 items (if applicable).
  - [x]9.4: Create `apps/mobile/test/features/onboarding/onboarding_flow_test.dart` verifying: flow starts at profile step, step indicator renders, navigation between steps works.

- [x] Task 10: Add unit tests for new ApiClient methods. (AC: 2, 6, 11)
  - [x]10.1: In `apps/mobile/test/core/networking/api_client_test.dart`, add tests for: `updateProfile` sends PUT to /v1/profiles/me with correct body, `createItem` sends POST to /v1/items with correct body, `listItems` sends GET to /v1/items, `getSignedUploadUrl` sends POST to /v1/uploads/signed-url.

- [x] Task 11: Regression testing and documentation. (AC: all)
  - [x]11.1: Run `flutter analyze` and ensure zero issues.
  - [x]11.2: Run `flutter test` and ensure all existing + new tests pass.
  - [x]11.3: Run `npm --prefix apps/api test` and ensure all API tests still pass.
  - [x]11.4: Update `README.md` with notes about onboarding flow, new API endpoints, and Cloud Storage setup.
  - [x]11.5: Update `.env.example` with `GOOGLE_CLOUD_STORAGE_BUCKET` placeholder.

## Dev Notes

- This story bridges the auth-only profile (Story 1.2) with a richer user profile and introduces the first wardrobe data table. It creates the onboarding entry point that will be expanded by later epics (gamification challenges in Epic 6, full wardrobe CRUD in Epic 2).
- The "First 5 Items" challenge in this story is deliberately scoped to PHOTO CAPTURE ONLY. Items are created with just a photo URL and optional name. AI background removal (FR-WRD-04) and AI categorization (FR-WRD-05) belong to Epic 2 stories. The items created here will be retroactively processed when those capabilities are built.
- The `items` table schema in this story is intentionally minimal. Epic 2 (Story 2.4) will add the full metadata columns (category, color, material, pattern, brand, price, etc.) via a later migration. Design the initial table so those columns can be added non-destructively with ALTER TABLE.
- Cloud Storage integration may not be fully available in local development. The upload service should have a fallback path (local file storage or a mock) so the onboarding flow can be developed and tested without GCP credentials.
- FR-ONB-03 (Closet Safari 7-day challenge) and FR-ONB-04 (Premium trial grant) are NOT in scope for this story. They belong to Epic 6 (Gamification System). This story only covers FR-ONB-01, FR-ONB-02, FR-ONB-05, and FR-AUTH-08.
- The style preferences field uses a TEXT[] PostgreSQL array. The allowed values are enforced at the API validation layer, not via database CHECK constraint, to allow adding new style options without a migration.
- Profile photo upload uses a two-step flow: (1) get a signed upload URL from the API, (2) upload the image directly to Cloud Storage from the mobile client. This avoids routing large binary payloads through the API server.

### Project Structure Notes

- New mobile directories:
  - `apps/mobile/lib/src/features/onboarding/screens/`
  - `apps/mobile/lib/src/features/onboarding/`
  - `apps/mobile/test/features/onboarding/screens/`
- New API modules:
  - `apps/api/src/modules/items/`
  - `apps/api/src/modules/uploads/`
- New SQL artifacts:
  - `infra/sql/migrations/003_profile_onboarding.sql`
  - `infra/sql/migrations/004_items_baseline.sql`
  - `infra/sql/policies/003_items_rls.sql`

### Technical Requirements

- Profile photo uploads require `image_picker` Flutter package for camera/gallery access.
- Signed URLs for Cloud Storage require the `@google-cloud/storage` npm package on the API side (or equivalent). If this dependency is too heavy for MVP, a direct multipart upload endpoint on the API is an acceptable alternative.
- The `items` table must use UUID primary keys and reference `profiles(id)` with `ON DELETE CASCADE` for GDPR compliance.
- RLS on the `items` table must prevent users from reading or modifying other users' items.
- The onboarding flow must not block app access. The "Skip" option must be available at every step.

### Architecture Compliance

- Profile updates go through the Cloud Run API, not direct database writes from the client.
- Image uploads use signed URLs for direct-to-storage upload, keeping the API server stateless.
- The `items` table follows the same RLS pattern as `profiles`: transaction-scoped `app.current_user_id` setting.
- The mobile client does not store sensitive data (Cloud Storage credentials, database connection strings). All sensitive operations are API-mediated.

### Library / Framework Requirements

- New mobile dependencies:
  - `image_picker: ^1.x` -- camera/gallery photo selection
- New API dependencies (conditional on Cloud Storage approach):
  - `@google-cloud/storage: ^7.x` -- signed URL generation (only if using GCS signed URLs)
- Existing packages reused:
  - `http: ^1.x` -- API calls from mobile
  - `pg` -- database queries from API
  - `firebase_auth` -- auth context for API calls

### File Structure Requirements

- Expected new files:
  - `infra/sql/migrations/003_profile_onboarding.sql`
  - `infra/sql/migrations/004_items_baseline.sql`
  - `infra/sql/policies/003_items_rls.sql`
  - `apps/api/src/modules/items/repository.js`
  - `apps/api/src/modules/items/service.js`
  - `apps/api/src/modules/uploads/service.js`
  - `apps/api/test/profile-update.test.js`
  - `apps/api/test/items-endpoint.test.js`
  - `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart`
  - `apps/mobile/lib/src/features/onboarding/screens/onboarding_profile_screen.dart`
  - `apps/mobile/lib/src/features/onboarding/screens/onboarding_photo_screen.dart`
  - `apps/mobile/lib/src/features/onboarding/screens/first_five_items_screen.dart`
  - `apps/mobile/test/features/onboarding/screens/onboarding_profile_screen_test.dart`
  - `apps/mobile/test/features/onboarding/screens/onboarding_photo_screen_test.dart`
  - `apps/mobile/test/features/onboarding/screens/first_five_items_screen_test.dart`
  - `apps/mobile/test/features/onboarding/onboarding_flow_test.dart`
- Expected modified files:
  - `apps/api/src/main.js` (new routes: PUT /v1/profiles/me, POST /v1/uploads/signed-url, POST /v1/items, GET /v1/items)
  - `apps/api/src/modules/profiles/repository.js` (add updateProfile method)
  - `apps/api/src/modules/profiles/service.js` (add updateProfileForAuthenticatedUser method)
  - `apps/mobile/lib/src/app.dart` (onboarding routing after first-time auth)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (new API methods for profile update, upload, items)
  - `apps/mobile/pubspec.yaml` (add image_picker)
  - `.env.example` (add GOOGLE_CLOUD_STORAGE_BUCKET)
  - `README.md` (onboarding flow docs, new endpoints, Cloud Storage setup)
  - `apps/mobile/test/core/networking/api_client_test.dart` (new tests for new methods)

### Testing Requirements

- API tests must verify:
  - PUT /v1/profiles/me updates display_name, style_preferences, onboarding_completed_at
  - PUT /v1/profiles/me rejects invalid payloads (too-long name, unknown style preferences)
  - PUT /v1/profiles/me returns 401 for unauthenticated requests
  - POST /v1/items creates an item and returns it
  - GET /v1/items returns the user's items
  - POST /v1/uploads/signed-url returns upload and public URLs
- Widget tests must verify:
  - OnboardingProfileScreen renders name field, style chips, continue/skip buttons
  - OnboardingPhotoScreen renders avatar placeholder, choose-photo/skip/continue buttons
  - FirstFiveItemsScreen renders progress indicator, add-item button, skip/done buttons
  - OnboardingFlow manages step progression correctly
- Unit tests must verify:
  - ApiClient.updateProfile sends correct PUT request
  - ApiClient.createItem sends correct POST request
  - ApiClient.listItems sends correct GET request
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new tests pass)

### Previous Story Intelligence

- Story 1.1 established:
  - Flutter app scaffold with `AppConfig.fromEnvironment()` pattern
  - Cloud Run API with health endpoint and config loading from `apps/api/src/config/env.js`
  - SQL baseline under `infra/sql/migrations/001_initial_scaffold.sql`
  - `app_private.set_updated_at()` trigger function in `infra/sql/functions/001_set_updated_at.sql`
- Story 1.2 established:
  - `profiles` table with: `id uuid`, `firebase_uid text unique`, `email text`, `auth_provider text`, `email_verified boolean`, `created_at`, `updated_at`
  - `GET /v1/profiles/me` with idempotent profile provisioning via `ON CONFLICT (firebase_uid) DO NOTHING`
  - Profile repository uses `set_config('app.current_user_id', ...)` for RLS context
  - `mapProfileRow()` in repository maps snake_case DB columns to camelCase JS
  - Profile service returns `{ profile, provisioned }` shape
- Story 1.3 established:
  - `AuthService` with DI for FirebaseAuth, GoogleSignIn, AppleSignInDelegate
  - `SessionManager` for token persistence in flutter_secure_storage
  - `ApiClient` with `getOrCreateProfile()`, Bearer token attachment, 401-retry logic
  - `VestiaireApp` with `_AuthScreen` enum, `_provisionProfile()` method, auth state listener
  - All screens follow Vibrant Soft-UI: #F3F4F6 background, #4F46E5 primary, 50px buttons, 12px radius, Semantics labels, #1F2937 text, white input fields with #D1D5DB borders
  - 66 Flutter tests, 16 API tests
- Story 1.4 established:
  - `ApiClient` generalized `_authenticatedRequest` supporting GET/POST/PUT/DELETE with double-401 session expiry
  - Public methods: `authenticatedPost`, `authenticatedPut`, `authenticatedDelete`
  - `onSessionExpired` callback pattern on ApiClient
  - ForgotPasswordScreen following same Vibrant Soft-UI pattern
  - Sign-out button on BootstrapHomeScreen app bar
  - 88 Flutter tests, 16 API tests

### Implementation Guidance

- For the onboarding detection in `app.dart`: after `_provisionProfile()`, check the returned profile for `onboardingCompletedAt == null`. If null, navigate to onboarding. Store the profile data in a local variable or state so the onboarding screens can pre-populate fields.
- For the `PUT /v1/profiles/me` handler in `main.js`: parse the request body using the same JSON body reading pattern as other endpoints. Validate the fields, then delegate to profileService.updateProfileForAuthenticatedUser(authContext, updates).
- For the `mapProfileRow` function in `repository.js`: extend it to include the new columns (`displayName`, `photoUrl`, `stylePreferences`, `onboardingCompletedAt`). Keep backward compatibility so GET still works even before the migration is applied.
- For the `items` repository: follow the same pattern as profiles — `pool.connect()`, `begin`, `set_config('app.current_user_id', ...)`, query, `commit`, `release`. Use `returning *` on INSERT to get the created row.
- For the onboarding UI: use a `PageView` or simple state-based switching (like the existing `_AuthScreen` enum pattern) to manage steps. A `PageView` with `physics: NeverScrollableScrollPhysics()` gives smooth animation while keeping programmatic control.
- For image picking: `ImagePicker.pickImage(source: ImageSource.gallery)` for gallery, `ImagePicker.pickImage(source: ImageSource.camera)` for camera. Compress to reasonable size client-side before upload.
- For the style preference chips: use Flutter `FilterChip` widgets in a `Wrap` layout. Selected chips get the #4F46E5 primary color fill; unselected get a light border style.

### Project Context Reference

- Epic source: [epics.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md)
  - `## Epic 1: Foundation & Authentication`
  - `### Story 1.5: Onboarding Profile Setup & First 5 Items`
- Architecture source: [architecture.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/architecture.md)
  - `### Mobile Client`
  - `### State Management and Client Data`
  - `### API Architecture`
  - `### Data Architecture`
  - `## Project Structure` (features/onboarding/, modules/items/)
  - `## Epic-to-Component Mapping`
- UX source: [ux-design-specification.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/ux-design-specification.md)
  - `### Chosen Direction` (Vibrant Soft-UI)
  - `### Color Palette`
  - `### 2. The "Closet Safari" (Onboarding/Digitization)` flow diagram
- PRD source: [prd.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md)
  - `FR-AUTH-08`, `FR-ONB-01`, `FR-ONB-02`, `FR-ONB-05`
- Requirements source: [functional-requirements.md](/Users/yassine/vestiaire2.0/docs/functional-requirements.md)
  - `### 3.2 Onboarding`
  - `### 7.1 Database Tables` (profiles, items)
- Previous implementation context:
  - [1-1-greenfield-project-bootstrap.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-1-greenfield-project-bootstrap.md)
  - [1-2-authentication-data-foundation.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-2-authentication-data-foundation.md)
  - [1-3-user-registration-native-sign-in.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-3-user-registration-native-sign-in.md)
  - [1-4-password-reset-session-refresh-and-sign-out.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-4-password-reset-session-refresh-and-sign-out.md)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (Amelia, Senior Software Engineer)

### Debug Log References

- Story drafted by SM agent (Bob) from epics.md, architecture.md, ux-design-specification.md, prd.md, functional-requirements.md, and Stories 1.1/1.2/1.3/1.4 implementation artifacts.
- No git history available in the workspace.
- No external web research performed; repository-local planning and implementation artifacts were sufficient.

### Completion Notes List

- All 11 tasks implemented and verified with passing tests.
- Database migrations for profile onboarding columns and items table created.
- RLS policies for items table follow the same pattern as profiles (via profile_id join).
- PUT /v1/profiles/me endpoint with field validation (display_name max 100 chars, style_preferences against allowed values).
- POST /v1/uploads/signed-url with local-storage fallback for dev (no GCS dependency required).
- Items CRUD (POST /v1/items, GET /v1/items) with profile_id lookup and RLS.
- Mobile onboarding flow: 3-step (profile -> photo -> first-5-items) with skip at every step.
- Onboarding detection in app.dart via onboardingCompletedAt == null check after profile provisioning.
- image_picker dependency added to pubspec.yaml.
- GOOGLE_CLOUD_STORAGE_BUCKET added to .env.example.
- Existing profile repository test updated to match `select *` query pattern.
- flutter analyze: 0 issues. flutter test: 118 pass. API test: 28 pass.

### File List

**New files created:**
- `infra/sql/migrations/003_profile_onboarding.sql`
- `infra/sql/migrations/004_items_baseline.sql`
- `infra/sql/policies/003_items_rls.sql`
- `apps/api/src/modules/items/repository.js`
- `apps/api/src/modules/items/service.js`
- `apps/api/src/modules/uploads/service.js`
- `apps/api/test/profile-update.test.js`
- `apps/api/test/items-endpoint.test.js`
- `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart`
- `apps/mobile/lib/src/features/onboarding/screens/onboarding_profile_screen.dart`
- `apps/mobile/lib/src/features/onboarding/screens/onboarding_photo_screen.dart`
- `apps/mobile/lib/src/features/onboarding/screens/first_five_items_screen.dart`
- `apps/mobile/test/features/onboarding/onboarding_flow_test.dart`
- `apps/mobile/test/features/onboarding/screens/onboarding_profile_screen_test.dart`
- `apps/mobile/test/features/onboarding/screens/onboarding_photo_screen_test.dart`
- `apps/mobile/test/features/onboarding/screens/first_five_items_screen_test.dart`

**Modified files:**
- `apps/api/src/main.js` (new routes, items/uploads wiring, readBody helper, 400 error mapping)
- `apps/api/src/modules/profiles/repository.js` (updateProfile method, mapProfileRow extended, select *)
- `apps/api/src/modules/profiles/service.js` (updateProfileForAuthenticatedUser, ValidationError, allowed fields/styles)
- `apps/api/src/config/env.js` (gcsBucket config)
- `apps/mobile/lib/src/app.dart` (onboarding flow integration, _showOnboarding state, _completeOnboarding)
- `apps/mobile/lib/src/core/networking/api_client.dart` (updateProfile, getSignedUploadUrl, uploadImage, createItem, listItems)
- `apps/mobile/pubspec.yaml` (image_picker dependency)
- `apps/mobile/test/core/networking/api_client_test.dart` (new tests for updateProfile, createItem, listItems, getSignedUploadUrl)
- `apps/api/test/profile-repository.test.js` (updated regex for select * query)
- `.env.example` (GOOGLE_CLOUD_STORAGE_BUCKET)

## Change Log

- 2026-03-10: Story file created by Scrum Master (Bob) based on epic breakdown, architecture, UX specification, functional requirements, and Stories 1.1-1.4 implementation context.
- 2026-03-10: Story implemented by Dev Agent (Amelia/Claude Opus 4.6). All 11 tasks completed. 118 Flutter tests, 28 API tests, 0 analyze issues.
