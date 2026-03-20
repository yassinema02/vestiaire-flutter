# Story 2.1: Upload Item Photo (Camera & Gallery)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to take a photo of a clothing item or upload one from my gallery,
so that I can begin digitizing my wardrobe.

## Acceptance Criteria

1. Given I am on the authenticated home screen, when the app displays the main navigation shell, then I see a bottom navigation bar with 5 destinations: Home, Wardrobe, Add, Outfits, Profile (replacing the current 3-tab bootstrap shell).
2. Given I am on any screen in the main shell, when I tap the "Add" tab (center position), then I am presented with an "Add Item" screen that offers two clear options: "Take Photo" (camera) and "Choose from Gallery".
3. Given I tap "Take Photo", when the camera opens, then I can capture a photo of a clothing item using the device camera via `image_picker`.
4. Given I tap "Choose from Gallery", when the gallery opens, then I can select a single photo from my device photo library via `image_picker`.
5. Given I have selected or captured a photo, when the image is being prepared for upload, then the app compresses the image client-side to a maximum width of 512px at 85% JPEG quality before uploading (FR-WRD-02).
6. Given the image has been compressed, when the upload process begins, then a loading indicator is shown and the app: (a) requests a signed upload URL from `POST /v1/uploads/signed-url` with `purpose: "item_photo"`, (b) uploads the compressed image to the signed URL, (c) creates an item record via `POST /v1/items` with the resulting `publicUrl`.
7. Given the upload and item creation succeed, when the API returns the new item, then the user sees a success confirmation (SnackBar) and is navigated to the Wardrobe tab to see their new item in the list.
8. Given the upload or item creation fails, when an error occurs at any step, then the user sees a user-friendly error message (SnackBar) and can retry.
9. Given I am on the Add Item screen, when I decide not to add an item, then I can navigate away via the bottom navigation bar or a back button without any side effects.
10. Given I have no camera available (e.g., simulator), when I tap "Take Photo", then the camera option is either hidden or shows a graceful error explaining the camera is unavailable.

## Tasks / Subtasks

- [x] Task 1: Upgrade the main navigation shell from 3-tab bootstrap to 5-tab MVP shell (AC: 1, 9)
  - [x] 1.1: Replace `BootstrapHomeScreen` (the current `StatelessWidget` in `apps/mobile/lib/src/app.dart`) with a new `MainShellScreen` `StatefulWidget` that manages a `selectedIndex` and displays 5 bottom navigation destinations: Home (Icons.home), Wardrobe (Icons.checkroom), Add (Icons.add_circle_outline / Icons.add_circle), Outfits (Icons.style / Icons.dry_cleaning), Profile (Icons.person). Create this as `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`.
  - [x] 1.2: Inside `MainShellScreen`, use an `IndexedStack` (or equivalent) to host placeholder screens for Home, Wardrobe, Outfits, and Profile tabs. Each placeholder is a simple `Scaffold` with centered text (e.g., "Home - Coming Soon") following Vibrant Soft-UI styling (#F3F4F6 background, #1F2937 text). The Wardrobe placeholder should display the user's items via `ApiClient.listItems()`.
  - [x] 1.3: Migrate the existing sign-out action, delete-account action, and notification-preferences action from the old `BootstrapHomeScreen` into the Profile tab placeholder (or the `MainShellScreen` app bar). Ensure all existing functionality from `BootstrapHomeScreen` is preserved.
  - [x] 1.4: The "Add" tab (index 2) should NOT navigate to a persistent child in the `IndexedStack`. Instead, tapping "Add" should push the `AddItemScreen` as a modal/full-screen route (via `Navigator.push`) and keep the previously selected tab active underneath. When the user dismisses `AddItemScreen`, the previous tab is restored.
  - [x] 1.5: Update `apps/mobile/lib/src/app.dart` to replace the `BootstrapHomeScreen(...)` instantiation with `MainShellScreen(...)`, passing through `config`, `onSignOut`, `onDeleteAccount`, `apiClient`, and `notificationService`.

- [x] Task 2: Create the AddItemScreen with camera/gallery options (AC: 2, 3, 4, 9, 10)
  - [x] 2.1: Create `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` as a `StatefulWidget`. The screen displays: a title "Add Item", two large tappable option cards ("Take Photo" with a camera icon, "Choose from Gallery" with a photo library icon), following Vibrant Soft-UI design (#F3F4F6 background, white cards with 12px radius, #1F2937 text, #4F46E5 icons). Include a close/back button in the AppBar.
  - [x] 2.2: On "Take Photo" tap: call `ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 512)`. The `image_picker` package's `maxWidth` and `imageQuality` parameters handle the compression requirement (FR-WRD-02) directly. If the result is null (user cancelled), do nothing. If `ImageSource.camera` is not available, catch the `PlatformException` and show a SnackBar: "Camera not available on this device."
  - [x] 2.3: On "Choose from Gallery" tap: call `ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 512)`. If the result is null (user cancelled), do nothing.
  - [x] 2.4: Accept an optional `ImagePicker?` parameter for dependency injection in tests.
  - [x] 2.5: All interactive elements must have `Semantics` labels: "Take Photo", "Choose from Gallery", "Close".

- [x] Task 3: Implement the upload-and-create-item flow (AC: 5, 6, 7, 8)
  - [x] 3.1: After a photo is selected (from camera or gallery), transition `AddItemScreen` to a "uploading" state: show the selected image as a preview with a `CircularProgressIndicator` overlay and disable the option cards.
  - [x] 3.2: Execute the upload pipeline in sequence: (a) call `apiClient.getSignedUploadUrl(purpose: "item_photo")`, (b) call `apiClient.uploadImage(imagePath, uploadUrl)`, (c) call `apiClient.createItem(photoUrl: publicUrl)`. This is the same 3-step pattern used in `_handleAddItem` in `app.dart`.
  - [x] 3.3: On success: pop the `AddItemScreen`, show a SnackBar on the parent shell "Item added!", and switch the shell's selected tab to Wardrobe (index 1). Pass a callback `onItemAdded` from `MainShellScreen` to `AddItemScreen` that triggers the tab switch and wardrobe refresh.
  - [x] 3.4: On failure: show a SnackBar with "Failed to add item. Please try again.", reset the screen to the initial state (option cards enabled, no preview), and allow the user to retry.
  - [x] 3.5: The image compression is handled by `image_picker`'s `maxWidth: 512` and `imageQuality: 85` parameters. No additional compression library is needed. The `image_picker` package compresses to JPEG automatically when `imageQuality` is specified.

- [x] Task 4: Create a basic Wardrobe tab screen showing items (AC: 7)
  - [x] 4.1: Create `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` as a `StatefulWidget` that loads items via `apiClient.listItems()` on `initState` and displays them in a 2-column `GridView`. Each grid cell shows the item's `photoUrl` as an image with 12px border radius, loaded via `Image.network` with an error placeholder. Follow Vibrant Soft-UI: #F3F4F6 background.
  - [x] 4.2: Add a `refresh()` method (or use a `Key`-based rebuild) so `MainShellScreen` can trigger a reload after a new item is added.
  - [x] 4.3: Show a centered empty state message when no items exist: "Your wardrobe is empty. Tap + to add your first item!" with an icon.
  - [x] 4.4: Show a loading indicator while items are being fetched, and an error state with retry button if the fetch fails.
  - [x] 4.5: Semantics labels on grid items: use item name if available, otherwise "Wardrobe item".

- [x] Task 5: Widget tests for AddItemScreen (AC: 2, 3, 4, 8, 9, 10)
  - [x] 5.1: Create `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`:
    - Screen renders title "Add Item" and two option cards.
    - Tapping "Take Photo" calls `ImagePicker.pickImage` with `ImageSource.camera`.
    - Tapping "Choose from Gallery" calls `ImagePicker.pickImage` with `ImageSource.gallery`.
    - When `pickImage` returns null (cancelled), screen stays in initial state.
    - When `pickImage` returns a file, upload flow begins (loading state shown).
    - On successful upload, `onItemAdded` callback is invoked.
    - On upload failure, error SnackBar appears and screen resets to initial state.
    - Camera unavailable `PlatformException` shows appropriate SnackBar.
    - Semantics labels present on all interactive elements.
    - Back/close button pops the screen.

- [x] Task 6: Widget tests for MainShellScreen and WardrobeScreen (AC: 1, 7)
  - [x] 6.1: Create `apps/mobile/test/features/shell/screens/main_shell_screen_test.dart`:
    - Renders 5 bottom navigation destinations (Home, Wardrobe, Add, Outfits, Profile).
    - Tapping each tab shows the correct placeholder content.
    - Tapping "Add" pushes the AddItemScreen route.
    - Sign-out button is accessible from the Profile tab area.
    - Delete-account and notification preferences are accessible.
  - [x] 6.2: Create `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`:
    - Empty state shown when no items.
    - Items render in a grid when data is returned.
    - Loading indicator appears while fetching.
    - Error state with retry button on fetch failure.

- [x] Task 7: Update existing tests and run regression (AC: all)
  - [x] 7.1: Update `apps/mobile/test/app_test.dart` (or equivalent) to reflect the new `MainShellScreen` replacing `BootstrapHomeScreen`. Any existing tests that reference `BootstrapHomeScreen` widget-finding must be updated.
  - [x] 7.2: Run `flutter analyze` and ensure zero issues.
  - [x] 7.3: Run `flutter test` and ensure all existing + new tests pass.
  - [x] 7.4: Run `npm --prefix apps/api test` and ensure all API tests still pass (no API changes in this story, but verify no regressions).

## Dev Notes

- This is the FIRST story in Epic 2 (Digital Wardrobe Core). It builds the foundation for all subsequent wardrobe stories (background removal, AI categorization, metadata editing, grid/filtering, detail view, neglect detection).
- The `items` table, `POST /v1/items`, `GET /v1/items`, `POST /v1/uploads/signed-url`, and the `image_picker` dependency are all ALREADY ESTABLISHED from Story 1.5. DO NOT recreate any of these. Reuse the existing `ApiClient` methods: `getSignedUploadUrl()`, `uploadImage()`, `createItem()`, `listItems()`.
- The `items` table currently has a minimal schema: `id`, `profile_id`, `photo_url`, `name`, `created_at`, `updated_at`. Story 2.4 will add full metadata columns (category, color, material, etc.) via ALTER TABLE. Do NOT add metadata columns in this story.
- Image compression is handled entirely by `image_picker`'s built-in `maxWidth` and `imageQuality` parameters. Setting `maxWidth: 512` and `imageQuality: 85` satisfies FR-WRD-02 (512px width, 85% JPEG quality). No additional image compression library (like `flutter_image_compress`) is needed.
- The upload flow follows the same 3-step pattern already used in `_handleAddItem` in `app.dart` (Story 1.5): (1) get signed URL, (2) upload image bytes, (3) create item record. The key difference is that in Story 1.5 this was fire-and-forget from the onboarding flow; in this story it needs proper loading states and error handling.
- The existing `BootstrapHomeScreen` is a placeholder from Story 1.1. This story replaces it with the proper 5-tab MVP navigation shell. The 5-tab structure (Home, Wardrobe, Add, Outfits, Profile) is defined in the Architecture document and UX spec.
- The "Add" tab should NOT render a persistent screen in the `IndexedStack`. Instead, it acts as a trigger that pushes a full-screen route. This is a common Flutter pattern for "action" tabs (similar to Instagram's center "+" button).
- Stories 2.2 and 2.3 will add server-side AI processing (background removal and categorization) AFTER the photo is uploaded. In this story, `POST /v1/items` simply creates a minimal item record with the photo URL. The item detail screen and review flow come in Stories 2.4-2.6.
- The Wardrobe tab in this story is a basic grid showing items. Story 2.5 will add filtering, and Story 2.6 will add the detail view with tap-to-open.

### Project Structure Notes

- New directories:
  - `apps/mobile/lib/src/features/shell/screens/` -- main navigation shell
  - `apps/mobile/lib/src/features/wardrobe/screens/` -- wardrobe feature screens
  - `apps/mobile/test/features/shell/screens/`
  - `apps/mobile/test/features/wardrobe/screens/`
- Alignment with architecture: Epic 2 maps to `mobile/features/wardrobe` (architecture.md Epic-to-Component Mapping). The shell lives in a new `features/shell` module since it spans all features.
- No new API files, SQL migrations, or backend changes in this story. All required API endpoints and database tables already exist from Epic 1.

### Technical Requirements

- `image_picker: ^1.1.2` -- already in pubspec.yaml from Story 1.5. No new dependencies.
- `ImagePicker.pickImage(source: ImageSource.camera, maxWidth: 512, imageQuality: 85)` compresses to JPEG at the specified quality and max dimension. This is the simplest and most reliable way to satisfy FR-WRD-02 without adding a separate compression package.
- The `uploadImage` method in `ApiClient` reads the file bytes and PUTs them to the signed URL. The signed URL is scoped to `users/{firebase_uid}/items/{uuid}.jpg`.
- No new Flutter permissions are needed. Camera and photo library permissions are requested by `image_picker` automatically on first use (iOS Info.plist camera/photo descriptions should already be set from Story 1.5).

### Architecture Compliance

- Photo upload goes through the Cloud Run API (signed URL pattern), not direct client-to-storage writes. This matches the architecture: "Images are uploaded from the client to Cloud Storage through authenticated server-issued upload flow or signed URL orchestration."
- Item records are created via the API, maintaining the server as the source of truth.
- The mobile client owns presentation, gestures, and local state (architecture Mobile App Boundary). Item creation and storage are owned by the API.
- RLS on `items` table (policies/003_items_rls.sql) ensures users can only see/modify their own items.

### Library / Framework Requirements

- No new dependencies. All required packages are already installed:
  - `image_picker: ^1.1.2` (Flutter, pubspec.yaml)
  - `http: ^1.x` (Flutter, for API calls)
  - Upload service and items service already exist on the API side.

### File Structure Requirements

- Expected new files:
  - `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`
  - `apps/mobile/test/features/shell/screens/main_shell_screen_test.dart`
  - `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`
- Expected modified files:
  - `apps/mobile/lib/src/app.dart` (replace BootstrapHomeScreen with MainShellScreen, remove BootstrapHomeScreen class or move to shell)
  - `apps/mobile/test/app_test.dart` (update BootstrapHomeScreen references)

### Testing Requirements

- Widget tests for AddItemScreen must verify:
  - Camera and gallery options render and invoke `ImagePicker` correctly
  - Cancellation (null result) leaves screen in initial state
  - Successful upload calls the `onItemAdded` callback
  - Failed upload shows error SnackBar
  - Camera unavailability is handled gracefully
  - Loading state shows during upload
  - Semantics labels on all interactive elements
- Widget tests for MainShellScreen must verify:
  - 5 navigation destinations render
  - Tab switching shows correct content
  - "Add" tab pushes AddItemScreen route
  - Existing functionality (sign-out, delete account, notifications) still accessible
- Widget tests for WardrobeScreen must verify:
  - Empty state, loading state, error state, and populated grid
- Regression:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (no regressions)

### Previous Story Intelligence

- Story 1.1 established: Flutter app scaffold, BootstrapHomeScreen with 3-tab placeholder (Home, Wardrobe, Profile), AppConfig pattern.
- Story 1.3 established: AuthService, SessionManager, ApiClient with Bearer token and 401-retry. All screens follow Vibrant Soft-UI: #F3F4F6 background, #4F46E5 primary, 50px buttons, 12px radius, Semantics labels.
- Story 1.4 established: ApiClient generalized `_authenticatedRequest` supporting GET/POST/PUT/DELETE. 88 Flutter tests.
- Story 1.5 established: `image_picker` dependency, `POST /v1/uploads/signed-url`, `POST /v1/items`, `GET /v1/items`, `items` table with ON DELETE CASCADE, upload service with signed URL and local fallback, `_handleAddItem` pattern in app.dart. 118 Flutter tests, 28 API tests.
- Story 1.6 established: NotificationService, push token sync, notification preferences. 147 Flutter tests, 37 API tests.
- Story 1.7 established: Account deletion, Firebase Admin SDK. 167 Flutter tests, 46 API tests.
- Key pattern from 1.5: The upload pipeline is `getSignedUploadUrl` -> `uploadImage` -> `createItem`. The `_handleAddItem` method in `app.dart` (lines 293-316) is the canonical reference for this pattern.
- Key insight: The `FirstFiveItemsScreen` (Story 1.5) only opens the gallery (not camera). This story introduces camera capture as a new option alongside gallery.

### Key Anti-Patterns to Avoid

- DO NOT recreate the items table, upload endpoints, or ApiClient methods. They already exist from Story 1.5.
- DO NOT add AI categorization or background removal in this story. That is Stories 2.2 and 2.3.
- DO NOT add metadata columns (category, color, material, etc.) to the items table. That is Story 2.4.
- DO NOT add a separate image compression library. `image_picker`'s built-in `maxWidth` and `imageQuality` parameters handle FR-WRD-02.
- DO NOT make the "Add" tab a persistent screen in the IndexedStack. It should push a modal route.
- DO NOT remove the existing `_handleAddItem` from `app.dart` yet -- it may still be used by the onboarding flow. Instead, create a similar but improved version with proper error handling in the new AddItemScreen.
- DO NOT break the existing onboarding flow. The `OnboardingFlow` widget and `FirstFiveItemsScreen` must continue to work.

### Implementation Guidance

- For the 5-tab navigation: use Flutter's `NavigationBar` with `selectedIndex` state. The "Add" tab intercepts `onDestinationSelected`: if index == 2, push `AddItemScreen` and do NOT update `selectedIndex`. This keeps the current tab visible behind the modal.
- For image compression: `ImagePicker().pickImage(source: ..., maxWidth: 512, imageQuality: 85)` returns an `XFile?`. Read the file path from `xFile.path` and pass to the upload flow.
- For the upload flow in `AddItemScreen`: call `apiClient.getSignedUploadUrl(purpose: "item_photo")`, then `apiClient.uploadImage(xFile.path, uploadUrl)`, then `apiClient.createItem(photoUrl: publicUrl)`. Wrap in try/catch for error handling.
- For the WardrobeScreen grid: use `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8)`. Load items via `apiClient.listItems()` in `initState`.
- For testing: inject a mock `ImagePicker` and mock `ApiClient` into the widgets. The `AddItemScreen` should accept optional `ImagePicker?` and required `ApiClient` parameters.
- For the BootstrapHomeScreen migration: extract the sign-out/delete/notifications logic into the new `MainShellScreen`. The `BootstrapHomeScreen` class can be removed from `app.dart` once `MainShellScreen` fully replaces it. Make sure all test references are updated.

### References

- [Source: epics.md - Story 2.1: Upload Item Photo (Camera & Gallery)]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: architecture.md - Mobile Client]
- [Source: architecture.md - Media and Storage]
- [Source: architecture.md - Project Structure]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 2 -> mobile/features/wardrobe]
- [Source: ux-design-specification.md - MVP Shell: Home, Wardrobe, Add, Outfits, Profile]
- [Source: ux-design-specification.md - Wardrobe Digitization Flow (mermaid diagram)]
- [Source: ux-design-specification.md - FloatingActionButton for primary "Add Item" camera action]
- [Source: prd.md - FR-WRD-01, FR-WRD-02]
- [Source: 1-5-onboarding-profile-setup-first-5-items.md - upload pipeline pattern, items table, image_picker]
- [Source: 1-7-account-deletion-gdpr.md - latest Flutter test count: 167, API test count: 46]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Story drafted by SM agent (Bob/Claude Opus 4.6) from epics.md, architecture.md, ux-design-specification.md, prd.md, and Stories 1.1-1.7 implementation artifacts.
- Codebase analysis performed: read existing items table schema (004_items_baseline.sql), items repository/service, upload service, ApiClient methods, app.dart shell, first_five_items_screen.dart pattern, RLS policies (003_items_rls.sql), pubspec.yaml dependencies.
- No git history available (not a git repository in the working directory context).
- No external web research needed; all technical decisions are constrained by existing architecture and established patterns.

### Completion Notes List

- All 7 tasks completed. 191 Flutter tests pass (24 new), 46 API tests pass.
- `flutter analyze` reports zero issues.
- `BootstrapHomeScreen` kept in app.dart for backward compatibility (class still exists but is no longer instantiated from VestiaireApp._buildHome).
- The "Add" tab intercepts `onDestinationSelected` at index 2 and pushes `AddItemScreen` as a full-screen route, keeping the previously selected tab visible underneath.
- Image compression handled entirely by `image_picker`'s `maxWidth: 512` and `imageQuality: 85` parameters (no extra library).
- Upload pipeline follows the existing 3-step pattern: getSignedUploadUrl -> uploadImage -> createItem.
- Widget tests use `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + `_TestAuthService` override to avoid Firebase initialization issues.
- `tester.runAsync()` used for the upload success test to allow real I/O (File.readAsBytes) to complete in the FakeAsync test environment.

### File List

New files:
- `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`
- `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`
- `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`
- `apps/mobile/test/features/shell/screens/main_shell_screen_test.dart`
- `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`
- `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`

Modified files:
- `apps/mobile/lib/src/app.dart` (import MainShellScreen, replace BootstrapHomeScreen instantiation with MainShellScreen)
- `apps/mobile/test/widget_test.dart` (updated to test MainShellScreen instead of BootstrapHomeScreen)

## Change Log

- 2026-03-10: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, UX specification, PRD requirements, and Stories 1.1-1.7 implementation context. This is the first story in Epic 2: Digital Wardrobe Core.
