# Story 1.6: Push Notification Permissions & Preferences

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to control notification permission and notification categories during setup and later in settings,
so that the app can notify me when useful without spamming me.

## Acceptance Criteria

1. Given I am completing the initial profile setup or editing notification settings later, when I reach the notifications step, then the system requests iOS push notification permission via the Firebase Cloud Messaging SDK (APNs).
2. Given I have granted push notification permission, when the system receives the FCM push token, then the token is securely saved to my profile record in the `profiles` table via `PUT /v1/profiles/me`.
3. Given I have denied push notification permission, when the notifications step completes, then I can still proceed through onboarding / use the app, and no token is stored. A visual indicator shows notifications are disabled.
4. Given I am on the notification preferences screen (accessible from onboarding or later from profile/settings), when I view my notification categories, then I see toggles for each supported category: outfit_reminders, wear_logging, analytics, social.
5. Given I toggle a notification category on or off, when I save, then the preference is persisted to my profile via `PUT /v1/profiles/me` and the change is immediately reflected in the UI.
6. Given notification preferences are stored server-side, when a future notification-sending service checks preferences, then disabled categories are never sent (enforced server-side per architecture: "Preference enforcement occurs server-side so disabled notifications are never sent").
7. Given I previously denied push notification permission at the OS level, when I visit the notification preferences screen, then the screen shows a message explaining notifications are off with a button to open iOS Settings so I can re-enable them.
8. Given I sign out or delete my account, when the session ends, then the FCM push token is cleared from the `profiles` table.
9. Given the notification preferences screen exists, when I access it from the profile/settings area of the app, then navigation to the screen works from the BootstrapHomeScreen Profile tab (or a settings entry point).

## Tasks / Subtasks

- [x] Task 1: Database migration — add push_token and notification_preferences to profiles (AC: 2, 4, 5, 6)
  - [x] 1.1: Create `infra/sql/migrations/005_push_notifications.sql` that adds to `app_public.profiles`:
    - `push_token text` — the FCM device token
    - `notification_preferences jsonb not null default '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":true}'::jsonb` — per-category toggles
  - [x] 1.2: Add column comments documenting each field.
  - [x] 1.3: Ensure migration applies cleanly on top of 004_items_baseline.sql using `ALTER TABLE` inside `begin/commit`.

- [x] Task 2: API — extend profile repository and service to handle push_token and notification_preferences (AC: 2, 5, 6, 8)
  - [x] 2.1: In `apps/api/src/modules/profiles/repository.js`, extend `mapProfileRow()` to include `pushToken` (from `push_token`) and `notificationPreferences` (from `notification_preferences`).
  - [x] 2.2: In `apps/api/src/modules/profiles/repository.js`, extend `updateProfile()` to handle `push_token` and `notification_preferences` update clauses (same parameterized UPDATE pattern as existing fields).
  - [x] 2.3: In `apps/api/src/modules/profiles/service.js`, extend `updateProfileForAuthenticatedUser()` validation to accept `push_token` (string or null) and `notification_preferences` (object with boolean values for known keys: `outfit_reminders`, `wear_logging`, `analytics`, `social`). Reject unknown preference keys.
  - [x] 2.4: Validate `notification_preferences` shape: each key must be one of `outfit_reminders`, `wear_logging`, `analytics`, `social`; each value must be boolean. Unknown keys are rejected with 400.

- [x] Task 3: API — add endpoint to clear push token on sign-out (AC: 8)
  - [x] 3.1: In `apps/api/src/main.js`, add `DELETE /v1/profiles/me/push-token` that sets `push_token = null` on the authenticated user's profile. Reuse the existing `updateProfile` repository method with `{ push_token: null }`.
  - [x] 3.2: Alternatively, the mobile client can call `PUT /v1/profiles/me` with `{ "push_token": null }` on sign-out. Choose whichever is simpler — the dedicated DELETE endpoint is cleaner but the PUT approach reuses existing code. Document the chosen approach.

- [x] Task 4: API tests for new notification fields (AC: 2, 4, 5, 8)
  - [x] 4.1: Add `apps/api/test/notification-preferences.test.js` testing:
    - PUT /v1/profiles/me with `push_token` saves and returns the token
    - PUT /v1/profiles/me with `push_token: null` clears the token
    - PUT /v1/profiles/me with valid `notification_preferences` saves and returns preferences
    - PUT /v1/profiles/me with invalid `notification_preferences` (unknown key) returns 400
    - PUT /v1/profiles/me with invalid `notification_preferences` (non-boolean value) returns 400
    - GET /v1/profiles/me returns `notificationPreferences` with defaults for a new profile
    - Unauthenticated access returns 401
  - [x] 4.2: Ensure existing API tests still pass: `npm --prefix apps/api test`.

- [x] Task 5: Mobile — add firebase_messaging dependency and notification permission service (AC: 1, 2, 3, 7)
  - [x] 5.1: Add `firebase_messaging: ^15.x` to `apps/mobile/pubspec.yaml`.
  - [x] 5.2: Create `apps/mobile/lib/src/core/notifications/notification_service.dart` with:
    - `Future<bool> requestPermission()` — calls `FirebaseMessaging.instance.requestPermission()`, returns true if authorized/provisional.
    - `Future<String?> getToken()` — calls `FirebaseMessaging.instance.getToken()`, returns the FCM token or null.
    - `Future<void> deleteToken()` — calls `FirebaseMessaging.instance.deleteToken()` to revoke the token locally.
    - `Stream<String> get onTokenRefresh` — exposes `FirebaseMessaging.instance.onTokenRefresh` so the app can re-register tokens when they rotate.
    - Constructor accepts optional `FirebaseMessaging` instance for test injection.
  - [x] 5.3: Add `app_settings_uri` helper (using `app_settings` or `url_launcher` to open iOS Settings) OR use a platform channel. The simplest approach: show the user instructions and use `openAppSettings()` from the `permission_handler` package, OR just use a descriptive message with no external dependency. Choose the approach that avoids adding a new dependency if possible.

- [x] Task 6: Mobile — extend ApiClient with notification methods (AC: 2, 5, 8)
  - [x] 6.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add method:
    - `Future<Map<String, dynamic>> updatePushToken(String? token)` — calls `PUT /v1/profiles/me` with `{ "push_token": token }`.
    - `Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, bool> preferences)` — calls `PUT /v1/profiles/me` with `{ "notification_preferences": preferences }`.
  - [x] 6.2: These methods reuse the existing `authenticatedPut` / `updateProfile` pattern. Consider extending `updateProfile` to accept these fields directly, or create separate convenience methods. The key requirement: the dev must NOT create a new endpoint — reuse `PUT /v1/profiles/me`.

- [x] Task 7: Mobile — build NotificationPermissionScreen (AC: 1, 2, 3, 7)
  - [x] 7.1: Create `apps/mobile/lib/src/features/notifications/screens/notification_permission_screen.dart`:
    - Bell icon or notification illustration at top.
    - Title: "Stay in the Loop" or similar motivational copy.
    - Explanation text: what notifications the app will send (outfit reminders, wear logging prompts, style insights, social updates).
    - Primary "Enable Notifications" button (50px height, #4F46E5, 12px radius) — triggers OS permission dialog via NotificationService.requestPermission().
    - "Skip" or "Not Now" text button — proceeds without requesting permission.
    - If permission granted: obtain FCM token, send to API via updatePushToken(), then proceed.
    - If permission denied: proceed gracefully, no token sent.
    - Semantics labels on all interactive elements.
    - Follow Vibrant Soft-UI: #F3F4F6 background, #1F2937 text, white cards with #D1D5DB borders.

- [x] Task 8: Mobile — build NotificationPreferencesScreen (AC: 4, 5, 7, 9)
  - [x] 8.1: Create `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`:
    - Title: "Notification Preferences"
    - Check current OS notification permission status on screen load. If denied at OS level, show a banner: "Notifications are turned off. Tap to open Settings." with a tap handler that opens iOS Settings (or shows instructions).
    - Four toggle switches (SwitchListTile) for categories:
      - "Outfit Reminders" (outfit_reminders) — morning outfit suggestions
      - "Wear Logging" (wear_logging) — evening reminders to log outfits
      - "Style Insights" (analytics) — wardrobe analytics and tips
      - "Social Updates" (social) — squad posts and reactions
    - Each toggle has a subtitle explaining what notifications it controls.
    - Toggles reflect current server-side preferences (loaded from profile on screen init).
    - On toggle change: immediately call API to persist (optimistic UI update with rollback on failure).
    - Follow Vibrant Soft-UI styling throughout.
    - Semantics labels on all toggles.

- [x] Task 9: Mobile — integrate notification permission into onboarding flow (AC: 1, 2, 3)
  - [x] 9.1: In `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart`, add a new step AFTER the photo step and BEFORE the first-5-items step: the NotificationPermissionScreen.
  - [x] 9.2: Update the step enum/counter to include the notification step.
  - [x] 9.3: Pass the NotificationService and ApiClient (or callbacks) to the onboarding flow so the permission screen can request permission and register the token.
  - [x] 9.4: The "Skip" action on the notification step must proceed to the first-5-items step without requesting permission.

- [x] Task 10: Mobile — add settings navigation to notification preferences (AC: 9)
  - [x] 10.1: Add a "Notification Preferences" entry point accessible from the Profile tab / BootstrapHomeScreen. This can be a simple gear icon or "Settings" button that navigates to NotificationPreferencesScreen.
  - [x] 10.2: The preferences screen must load the current profile (GET /v1/profiles/me) to populate the toggle states from `notificationPreferences`.

- [x] Task 11: Mobile — clear push token on sign-out (AC: 8)
  - [x] 11.1: In `apps/mobile/lib/src/app.dart`, update `_handleSignOut()` to:
    - Call `apiClient.updatePushToken(null)` to clear the token server-side (best effort, don't block sign-out on failure).
    - Call `notificationService.deleteToken()` to revoke the local FCM token.
  - [x] 11.2: Wrap in try/catch so sign-out always completes even if token clearing fails.

- [x] Task 12: Widget tests for notification screens (AC: 1, 3, 4, 5, 7)
  - [x] 12.1: Create `apps/mobile/test/features/notifications/screens/notification_permission_screen_test.dart`:
    - Renders bell icon / illustration, title, explanation text.
    - "Enable Notifications" button renders with correct styling.
    - "Skip" button renders and calls skip callback.
    - Semantics labels present on interactive elements.
  - [x] 12.2: Create `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart`:
    - Renders all four category toggles with labels.
    - Toggles reflect initial state.
    - Toggling a switch triggers API call.
    - OS-denied banner renders when appropriate.
    - Semantics labels present on all toggles.

- [x] Task 13: Unit tests for NotificationService and ApiClient extensions (AC: 2, 5, 8)
  - [x] 13.1: Create `apps/mobile/test/core/notifications/notification_service_test.dart` testing:
    - requestPermission() returns true when authorized.
    - requestPermission() returns false when denied.
    - getToken() returns a token string.
    - deleteToken() calls through to FirebaseMessaging.
  - [x] 13.2: In `apps/mobile/test/core/networking/api_client_test.dart`, add tests for:
    - updatePushToken(token) sends correct PUT body.
    - updatePushToken(null) sends null token.
    - updateNotificationPreferences() sends correct PUT body.

- [x] Task 14: Update onboarding flow tests (AC: 1, 3)
  - [x] 14.1: Update `apps/mobile/test/features/onboarding/onboarding_flow_test.dart` to verify the notification step exists between photo and first-5-items steps.
  - [x] 14.2: Verify skip on notification step advances to first-5-items.

- [x] Task 15: Regression testing and documentation (AC: all)
  - [x] 15.1: Run `flutter analyze` and ensure zero issues.
  - [x] 15.2: Run `flutter test` and ensure all existing + new tests pass.
  - [x] 15.3: Run `npm --prefix apps/api test` and ensure all API tests still pass.
  - [x] 15.4: Add `FIREBASE_CLOUD_MESSAGING` setup notes to README if not already present.

## Dev Notes

- This story adds the first push notification infrastructure. It does NOT implement actual sending of notifications (no Cloud Functions, no server-side push delivery). It only covers: (1) requesting permission, (2) storing the FCM token, (3) storing per-category preferences, and (4) UI for managing those preferences. Actual notification delivery is handled by later stories (4.7 morning outfit, 5.2 wear logging reminders, etc.).
- The `notification_preferences` column uses JSONB rather than separate boolean columns. This makes it easy to add new notification categories in future stories without database migrations. The categories for this story are: `outfit_reminders`, `wear_logging`, `analytics`, `social`.
- FR-PSH-03 through FR-PSH-05 (actual notification sending at specific times) are OUT OF SCOPE for this story. This story only sets up the plumbing (token + preferences). Sending is a backend concern for later epics.
- FR-PSH-06 ("All notification types shall be independently toggleable in settings") IS in scope — this is the preferences screen with per-category toggles.
- The `push_token` column stores the raw FCM token string. FCM tokens rotate periodically; the `onTokenRefresh` stream should be wired up so the app re-registers when the token changes. For this story, wire the listener in app initialization but do not over-engineer — just update the token via the API when it rotates.
- Token cleanup on sign-out is important for security: a signed-out user should not receive notifications for a different account that subsequently signs in on the same device.
- The notification permission request should happen ONCE during onboarding. If the user skips it, the preferences screen in settings provides a path to enable notifications later (directing to iOS Settings if previously denied).
- iOS requires APNs entitlement and a provisioning profile with push notification capability. The Firebase project must have the APNs key uploaded. For local development and testing, push notification permission can be requested but actual token delivery requires a physical device (not simulator). Tests should mock FirebaseMessaging.

### Project Structure Notes

- New mobile directories:
  - `apps/mobile/lib/src/core/notifications/`
  - `apps/mobile/lib/src/features/notifications/screens/`
  - `apps/mobile/test/features/notifications/screens/`
  - `apps/mobile/test/core/notifications/`
- New SQL artifacts:
  - `infra/sql/migrations/005_push_notifications.sql`
- Alignment with existing patterns:
  - NotificationService follows the same DI pattern as AuthService (injectable dependency, mockable for tests).
  - API methods on ApiClient follow the existing `authenticatedPut` pattern.
  - New screens follow Vibrant Soft-UI design system established in Stories 1.3-1.5.
  - Onboarding step integration follows the existing multi-step flow pattern from Story 1.5.

### Technical Requirements

- `firebase_messaging: ^15.x` requires `firebase_core` (already in pubspec.yaml as `^3.12.1`).
- iOS setup: requires APNs capability in the Xcode project (`Runner.xcodeproj`), and the APNs authentication key must be uploaded to the Firebase console. The `GoogleService-Info.plist` must be present in the iOS Runner.
- The FCM token is device-specific and can be up to 250 characters. The `push_token text` column has no length constraint (text is unlimited in PostgreSQL).
- `notification_preferences` JSONB allows partial updates: the API should merge incoming preferences with existing ones (not replace the entire object) so that future categories added server-side are not wiped out by an older client sending only known keys.
- Server-side preference enforcement: when future stories implement notification sending, they MUST check `notification_preferences` before sending. This story creates the data model; enforcement is downstream.

### Architecture Compliance

- Push token is stored server-side in `profiles` table per FR-PSH-02 and architecture doc: "Push tokens: Device identifier, Cloud SQL profiles table."
- Notification preferences are stored server-side per architecture: "Quiet hours and notification-type toggles are modeled as profile or settings data and enforced before fanout."
- All profile updates go through Cloud Run API (not direct DB writes from client) per architecture boundary.
- FCM SDK is used for token acquisition and permission request per architecture: "Delivery: Firebase Cloud Messaging."

### Library / Framework Requirements

- New mobile dependencies:
  - `firebase_messaging: ^15.x` — FCM token acquisition and permission request
- Existing packages reused:
  - `firebase_core: ^3.12.1` — already in pubspec.yaml, required by firebase_messaging
  - `firebase_auth: ^5.5.2` — auth context
  - `http: ^1.3.0` — API calls
- No new API (Node.js) dependencies required — existing `pg` pool handles JSONB natively.

### File Structure Requirements

- Expected new files:
  - `infra/sql/migrations/005_push_notifications.sql`
  - `apps/mobile/lib/src/core/notifications/notification_service.dart`
  - `apps/mobile/lib/src/features/notifications/screens/notification_permission_screen.dart`
  - `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`
  - `apps/mobile/test/features/notifications/screens/notification_permission_screen_test.dart`
  - `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart`
  - `apps/mobile/test/core/notifications/notification_service_test.dart`
  - `apps/api/test/notification-preferences.test.js`
- Expected modified files:
  - `apps/api/src/modules/profiles/repository.js` (mapProfileRow + updateProfile for push_token, notification_preferences)
  - `apps/api/src/modules/profiles/service.js` (validation for push_token, notification_preferences)
  - `apps/api/src/main.js` (optional: DELETE /v1/profiles/me/push-token route)
  - `apps/mobile/pubspec.yaml` (add firebase_messaging)
  - `apps/mobile/lib/src/app.dart` (inject NotificationService, clear token on sign-out)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (updatePushToken, updateNotificationPreferences)
  - `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart` (add notification permission step)
  - `apps/mobile/test/features/onboarding/onboarding_flow_test.dart` (update for new step)
  - `apps/mobile/test/core/networking/api_client_test.dart` (new tests)

### Testing Requirements

- API tests must verify:
  - PUT /v1/profiles/me with push_token saves and returns token
  - PUT /v1/profiles/me with notification_preferences saves and returns preferences
  - Validation rejects unknown preference keys (400)
  - Validation rejects non-boolean preference values (400)
  - GET /v1/profiles/me returns default notification_preferences for new profiles
  - Unauthenticated access returns 401
- Widget tests must verify:
  - NotificationPermissionScreen renders motivational copy, enable button, skip button
  - NotificationPreferencesScreen renders four category toggles
  - Toggle changes trigger callbacks/API calls
  - OS-denied state shows appropriate banner
- Unit tests must verify:
  - NotificationService.requestPermission() delegates to FirebaseMessaging
  - NotificationService.getToken() returns token
  - NotificationService.deleteToken() clears local token
  - ApiClient.updatePushToken() sends correct PUT body
  - ApiClient.updateNotificationPreferences() sends correct PUT body
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new tests pass)

### Previous Story Intelligence

- Story 1.1 established:
  - Flutter app scaffold with `AppConfig.fromEnvironment()` pattern
  - Cloud Run API with health endpoint and config loading from `apps/api/src/config/env.js`
  - SQL baseline under `infra/sql/migrations/001_initial_scaffold.sql`
  - `app_private.set_updated_at()` trigger function
- Story 1.2 established:
  - `profiles` table with: id, firebase_uid, email, auth_provider, email_verified, created_at, updated_at
  - `GET /v1/profiles/me` with idempotent profile provisioning
  - Profile repository uses `set_config('app.current_user_id', ...)` for RLS context
  - `mapProfileRow()` maps snake_case DB columns to camelCase JS
- Story 1.3 established:
  - `AuthService` with DI for FirebaseAuth, GoogleSignIn, AppleSignInDelegate
  - `SessionManager` for token persistence in flutter_secure_storage
  - `ApiClient` with `getOrCreateProfile()`, Bearer token attachment, 401-retry logic
  - All screens follow Vibrant Soft-UI: #F3F4F6 bg, #4F46E5 primary, 50px buttons, 12px radius, Semantics labels
- Story 1.4 established:
  - `ApiClient` generalized `_authenticatedRequest` supporting GET/POST/PUT/DELETE with double-401 session expiry
  - `onSessionExpired` callback pattern on ApiClient
  - ForgotPasswordScreen following Vibrant Soft-UI pattern
  - Sign-out in BootstrapHomeScreen app bar
- Story 1.5 established:
  - Onboarding flow: 3-step (profile -> photo -> first-5-items) with skip at every step
  - `PUT /v1/profiles/me` with field validation
  - `updateProfile()` in repository handles dynamic SET clauses with parameterized queries
  - `mapProfileRow()` extended for display_name, photo_url, style_preferences, onboarding_completed_at
  - `image_picker` added to pubspec.yaml
  - Onboarding detection via `onboardingCompletedAt == null` after profile provisioning
  - 118 Flutter tests, 28 API tests passing

### Key Anti-Patterns to Avoid

- DO NOT create a separate `notification_settings` table. Use the `profiles` table per FR-PSH-02 and architecture guidance.
- DO NOT implement actual push notification sending (Cloud Functions, cron jobs, FCM send API). This story is CLIENT-SIDE permission + preference storage only.
- DO NOT add `permission_handler` package if it can be avoided. `firebase_messaging` already handles the iOS permission dialog via `requestPermission()`. Only consider `permission_handler` if checking the current permission status requires it.
- DO NOT duplicate the `updateProfile` API endpoint. Reuse `PUT /v1/profiles/me` for token and preference updates.
- DO NOT replace the entire `notification_preferences` JSONB on update — MERGE incoming keys with existing keys to prevent data loss when new categories are added.

### Implementation Guidance

- For the JSONB merge in the repository: use PostgreSQL's `||` operator: `notification_preferences = notification_preferences || $N::jsonb`. This merges the incoming keys with existing keys, preserving any server-added keys not in the client payload.
- For the onboarding flow update: the existing `OnboardingFlow` uses a step enum. Add a `notifications` step between `photo` and `firstFiveItems`. The step count changes from 3 to 4; update the step indicator accordingly.
- For the NotificationPreferencesScreen: load the profile on init to get current preferences. Use `setState` for immediate toggle feedback. On toggle, fire the API call. If the API call fails, revert the toggle state (optimistic UI with rollback).
- For token refresh: in `app.dart` initState (after the user is authenticated), listen to `notificationService.onTokenRefresh` and call `apiClient.updatePushToken(newToken)`. Guard with a check that the user is still authenticated.
- For the settings entry point: a simple approach is adding a gear icon to the BootstrapHomeScreen app bar (next to the sign-out button) that navigates to NotificationPreferencesScreen. A more complete settings screen can be built in later stories.

### Project Context Reference

- Epic source: [epics.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md)
  - `## Epic 1: Foundation & Authentication`
  - `### Story 1.6: Push Notification Permissions & Preferences`
- Architecture source: [architecture.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/architecture.md)
  - `### Notifications and Async Work`
  - `## Responsibility Boundaries` — API owns notification initiation
- UX source: [ux-design-specification.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/ux-design-specification.md)
  - `### Chosen Direction` (Vibrant Soft-UI)
  - `### Color Palette`
- PRD source: [prd.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md)
  - `FR-PSH-01`, `FR-PSH-02`, `FR-PSH-06`
- Requirements source: [functional-requirements.md](/Users/yassine/vestiaire2.0/docs/functional-requirements.md)
  - `### 3.23 Push Notifications`
  - `### 10.2 Data Classification` — Push tokens as device identifiers
- Previous implementation context:
  - [1-1-greenfield-project-bootstrap.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-1-greenfield-project-bootstrap.md)
  - [1-2-authentication-data-foundation.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-2-authentication-data-foundation.md)
  - [1-3-user-registration-native-sign-in.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-3-user-registration-native-sign-in.md)
  - [1-4-password-reset-session-refresh-and-sign-out.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-4-password-reset-session-refresh-and-sign-out.md)
  - [1-5-onboarding-profile-setup-first-5-items.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-5-onboarding-profile-setup-first-5-items.md)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None.

### Completion Notes List

- All 15 tasks completed successfully.
- Backend: 37 API tests pass (9 new for notification fields).
- Mobile: 147 Flutter tests pass (29 new for notification screens, service, API client, onboarding).
- `flutter analyze` reports zero issues.
- Chose dedicated `DELETE /v1/profiles/me/push-token` endpoint AND support via `PUT /v1/profiles/me` with `push_token: null`.
- NotificationService uses DI pattern with optional `FirebaseMessaging` parameter for testability.
- JSONB merge via `||` operator preserves server-side keys not in client payload.
- Onboarding flow now has 4 steps: profile -> photo -> notifications -> firstFiveItems.
- Notification preferences accessible from BootstrapHomeScreen via bell icon in app bar.
- Push token cleared on sign-out (server-side + local) with try/catch to not block sign-out.

### File List

**New files:**
- `infra/sql/migrations/005_push_notifications.sql`
- `apps/mobile/lib/src/core/notifications/notification_service.dart`
- `apps/mobile/lib/src/features/notifications/screens/notification_permission_screen.dart`
- `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`
- `apps/api/test/notification-preferences.test.js`
- `apps/mobile/test/features/notifications/screens/notification_permission_screen_test.dart`
- `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart`
- `apps/mobile/test/core/notifications/notification_service_test.dart`

**Modified files:**
- `apps/api/src/modules/profiles/repository.js`
- `apps/api/src/modules/profiles/service.js`
- `apps/api/src/main.js`
- `apps/mobile/pubspec.yaml`
- `apps/mobile/lib/src/app.dart`
- `apps/mobile/lib/src/core/networking/api_client.dart`
- `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart`
- `apps/mobile/test/core/networking/api_client_test.dart`
- `apps/mobile/test/features/onboarding/onboarding_flow_test.dart`

## Change Log

- 2026-03-10: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, UX specification, functional requirements, and Stories 1.1-1.5 implementation context.
- 2026-03-10: All 15 tasks implemented by Dev Agent (Amelia/Claude Opus 4.6). 37 API tests pass, 147 Flutter tests pass, flutter analyze zero issues. Story moved to review.
