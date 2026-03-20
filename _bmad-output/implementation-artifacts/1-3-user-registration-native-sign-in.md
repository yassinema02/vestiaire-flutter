# Story 1.3: User Registration & Native Sign-In

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a New User,
I want to register for a new account using Email, Apple, or Google,
so that I can securely access my personal digital wardrobe.

## Acceptance Criteria

1. Given I am on the launch screen, when I tap "Sign up with Email", then I can enter my email and password, the system creates a Firebase Auth account, sends an email verification link, and displays a verification-pending screen informing me to check my inbox before full app access is granted.
2. Given I registered with email and password, when I tap the verification link in my email and return to the app, then the app detects the verified state (via Firebase Auth reload) and navigates me to the authenticated home shell with a provisioned Cloud SQL profile.
3. Given I am on the launch screen, when I tap "Sign in with Apple", then the native Apple Sign-In sheet appears, and upon successful completion my Firebase session is established and a Cloud SQL profile is provisioned automatically.
4. Given I am on the launch screen, when I tap "Sign in with Google", then the Google Sign-In flow completes via the native sheet, my Firebase session is established, and a Cloud SQL profile is provisioned automatically.
5. Given I have authenticated via any provider, when the session is established, then the Firebase ID token and refresh token are securely stored in the iOS Keychain via `flutter_secure_storage`, and subsequent app launches restore the session without re-authentication.
6. Given I am on the launch screen, when I tap "Already have an account? Sign in", then I can enter my email and password to sign in, and the app navigates to the authenticated home shell if my email is verified, or shows the verification-pending screen if not.
7. Given any authentication error occurs (invalid credentials, network failure, cancelled native sheet), when the error is caught, then the app displays a user-friendly error message and remains on the auth screen without crashing.
8. Given I am authenticated, when I am on the home shell, then the bottom navigation bar displays Home, Wardrobe, and Profile tabs matching the current scaffold layout.

## Tasks / Subtasks

- [x] Task 1: Add Flutter authentication dependencies and configure Firebase. (AC: 1, 2, 3, 4, 5)
  - [x] Add `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, and `flutter_secure_storage` to `pubspec.yaml`.
  - [x] Create `apps/mobile/lib/src/core/auth/` directory for auth domain code.
  - [ ] Add Firebase configuration files (`GoogleService-Info.plist` for iOS, `google-services.json` for Android) to the appropriate platform directories, with `.gitignore` entries and documented setup in README. *(Deferred: no iOS/Android platform directories exist yet; documented in README)*
  - [x] Initialize Firebase in `main.dart` before `runApp` using `Firebase.initializeApp()`.
  - [x] Update `.env.example` with any new Firebase-related environment variables if needed. *(No new vars needed; existing FIREBASE_PROJECT_ID suffices)*

- [x] Task 2: Implement the auth state management and session persistence layer. (AC: 2, 5, 8)
  - [x] Create `apps/mobile/lib/src/core/auth/auth_service.dart` wrapping `FirebaseAuth` with methods: `signUpWithEmail`, `signInWithEmail`, `signInWithApple`, `signInWithGoogle`, `signOut`, `reloadUser`, and a `Stream<User?>` for auth state changes.
  - [x] Create `apps/mobile/lib/src/core/auth/session_manager.dart` to persist and retrieve the Firebase ID token in `flutter_secure_storage` on auth state changes.
  - [x] Create `apps/mobile/lib/src/core/auth/auth_state.dart` defining auth state types: `unauthenticated`, `authenticatedUnverified`, `authenticated`.
  - [x] Wire `auth_service.dart` to listen for `FirebaseAuth.authStateChanges()` and `idTokenChanges()` to keep session state current.
  - [x] Ensure the app root widget listens to auth state and routes to the correct screen (launch/verification-pending/home shell).

- [x] Task 3: Implement the API client with authenticated requests. (AC: 2, 3, 4, 5)
  - [x] Create `apps/mobile/lib/src/core/networking/api_client.dart` that attaches the Firebase ID token as a `Bearer` header to all authenticated requests.
  - [x] Implement a `getOrCreateProfile()` method that calls `GET /v1/profiles/me` on the Cloud Run API after successful authentication.
  - [x] Handle 401/403 responses from the API gracefully, including the `EMAIL_VERIFICATION_REQUIRED` code from Story 1.2 backend.
  - [x] Integrate profile provisioning into the post-authentication flow so every successful sign-in or sign-up triggers profile resolution.

- [x] Task 4: Build the launch/welcome screen UI. (AC: 1, 3, 4, 6, 7)
  - [x] Create `apps/mobile/lib/src/features/auth/screens/welcome_screen.dart` as the unauthenticated entry point.
  - [x] Design the screen with the Vestiaire branding, a brief value proposition, and three sign-in options: "Continue with Apple", "Continue with Google", and "Sign up with Email".
  - [x] Add a "Already have an account? Sign in" link at the bottom.
  - [x] Follow the Vibrant Soft-UI design direction: #F3F4F6 background, #4F46E5 primary accent, 44x44 minimum touch targets, `Semantics` labels on all interactive elements.
  - [x] Social sign-in buttons should follow Apple and Google brand guidelines (Apple: black/white system button, Google: branded button).

- [x] Task 5: Build the email registration screen. (AC: 1, 7)
  - [x] Create `apps/mobile/lib/src/features/auth/screens/email_sign_up_screen.dart` with email and password fields.
  - [x] Implement client-side validation: email format, password minimum 8 characters.
  - [x] On submit, call `auth_service.signUpWithEmail(email, password)` which creates the Firebase user and sends the verification email.
  - [x] On success, navigate to the verification-pending screen.
  - [x] On error, display a contextual error message (email already in use, weak password, network error).

- [x] Task 6: Build the email sign-in screen. (AC: 6, 7)
  - [x] Create `apps/mobile/lib/src/features/auth/screens/email_sign_in_screen.dart` with email and password fields.
  - [x] On submit, call `auth_service.signInWithEmail(email, password)`.
  - [x] If the user's email is not yet verified, navigate to the verification-pending screen.
  - [x] If verified, trigger profile provisioning via the API client and navigate to the home shell.
  - [x] On error, display a contextual error message (wrong password, user not found, network error).

- [x] Task 7: Build the verification-pending screen. (AC: 1, 2)
  - [x] Create `apps/mobile/lib/src/features/auth/screens/verification_pending_screen.dart`.
  - [x] Display a clear message explaining that the user needs to verify their email.
  - [x] Provide a "Resend verification email" button that calls `FirebaseAuth.currentUser.sendEmailVerification()`.
  - [x] Provide a "I've verified my email" button that calls `FirebaseAuth.currentUser.reload()` and checks `emailVerified`.
  - [x] On successful verification detection, trigger profile provisioning and navigate to the home shell.
  - [x] Provide a "Sign out" or "Use a different account" option to return to the welcome screen.

- [x] Task 8: Implement Apple Sign-In flow. (AC: 3)
  - [x] In `auth_service.dart`, implement `signInWithApple()` using the `sign_in_with_apple` package.
  - [x] Generate a nonce, request Apple credentials, create a Firebase `OAuthCredential`, and sign in with Firebase.
  - [x] Handle user cancellation gracefully (do not show an error for deliberate cancellation).
  - [ ] Configure the Apple Sign-In capability in Xcode and the `Runner.entitlements` file. *(Deferred: no iOS platform directory exists yet; documented in README)*

- [x] Task 9: Implement Google Sign-In flow. (AC: 4)
  - [x] In `auth_service.dart`, implement `signInWithGoogle()` using the `google_sign_in` package.
  - [x] Obtain `GoogleSignInAuthentication`, create a Firebase `OAuthCredential`, and sign in with Firebase.
  - [x] Handle user cancellation gracefully.
  - [x] Ensure the Google Sign-In client ID is configured via Firebase config files (not hardcoded).

- [x] Task 10: Update app routing and navigation to support auth flow. (AC: 2, 5, 8)
  - [x] Refactor `apps/mobile/lib/src/app.dart` to use a root-level auth state listener that conditionally renders: WelcomeScreen (unauthenticated), VerificationPendingScreen (authenticated but unverified email/password), or the existing BootstrapHomeScreen (fully authenticated).
  - [x] Preserve the existing bottom navigation bar in the home shell (Home, Wardrobe, Profile).
  - [x] Ensure deep-link or cold-start restores session from `flutter_secure_storage` and skips the welcome screen if a valid session exists.

- [x] Task 11: Add unit and widget tests for auth flows. (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x] Add widget tests for `WelcomeScreen` verifying all three sign-in buttons render and are tappable.
  - [x] Add widget tests for `EmailSignUpScreen` verifying client-side validation (invalid email, short password).
  - [x] Add widget tests for `EmailSignInScreen` verifying error display on failed sign-in.
  - [x] Add widget tests for `VerificationPendingScreen` verifying resend and check-verification button behavior.
  - [x] Add unit tests for `AuthService` methods using mocked `FirebaseAuth`, `GoogleSignIn`, and Apple sign-in.
  - [x] Add unit tests for `SessionManager` verifying token persistence and retrieval from secure storage.
  - [x] Add unit tests for `ApiClient` verifying Bearer header attachment and error handling.
  - [x] Ensure all existing tests (`flutter test`, `flutter analyze`, `npm --prefix apps/api test`) continue to pass.

- [x] Task 12: Update documentation and environment setup. (AC: all)
  - [x] Update `README.md` with Firebase project setup prerequisites (creating a Firebase project, downloading config files, enabling Email/Password, Apple, and Google sign-in providers).
  - [x] Update `.env.example` if any new variables are required. *(No new variables needed)*
  - [x] Document the Xcode entitlements setup required for Apple Sign-In.
  - [x] Document how to test auth flows locally (Firebase emulator or test project).

## Dev Notes

- This story is the first mobile-facing feature story. Stories 1.1 and 1.2 established the backend and scaffold foundations. This story builds the full client-side authentication experience on top of those foundations.
- The Cloud Run API already validates Firebase JWTs and provisions profiles idempotently via `GET /v1/profiles/me` (Story 1.2). This story's mobile code must call that endpoint after every successful authentication to ensure the profile exists.
- For email/password sign-in, the API enforces email verification server-side (returns 403 with code `EMAIL_VERIFICATION_REQUIRED` for unverified email identities). The mobile app should also check `FirebaseAuth.currentUser.emailVerified` client-side to provide immediate UX feedback without waiting for an API round-trip.
- Apple Sign-In and Google Sign-In users are treated as verified by Firebase (no email verification step needed). The app should navigate directly to the home shell after social provider sign-in.
- Do not implement password reset, sign-out, onboarding profile setup, or notification permissions in this story. Those belong to Stories 1.4, 1.5, and 1.6 respectively.
- Do not implement dark mode or landscape orientation support. MVP is light mode, portrait only.
- The existing `BootstrapHomeScreen` in `app.dart` serves as the authenticated home shell placeholder. Refactor routing around it but do not replace it with a full home screen implementation.

### Project Structure Notes

- Architecture target for mobile auth code:
  - `apps/mobile/lib/src/core/auth/` for auth service, session management, and state
  - `apps/mobile/lib/src/core/networking/` for the authenticated API client
  - `apps/mobile/lib/src/features/auth/screens/` for auth UI screens
  - `apps/mobile/lib/src/features/auth/widgets/` for reusable auth widgets if needed
- The current mobile scaffold is thin (`main.dart`, `app.dart`, `config/app_config.dart`). This story will expand it significantly into the feature-based structure described in the architecture document.
- API-side code from Story 1.2 (`apps/api/src/modules/auth/`, `apps/api/src/modules/profiles/`) should not need changes for this story. The backend is already ready.

### Technical Requirements

- Firebase Auth SDK must be the identity provider for all three sign-in methods (email, Apple, Google).
- All Firebase tokens must be stored in the iOS Keychain via `flutter_secure_storage`, not in `SharedPreferences` or plain storage.
- The `sign_in_with_apple` package requires iOS 13+ and Xcode entitlements for the Sign in with Apple capability.
- The `google_sign_in` package requires a valid `GoogleService-Info.plist` with the correct reversed client ID configured as a URL scheme.
- The app must call `GET /v1/profiles/me` with the Firebase ID token after every successful authentication to trigger server-side profile provisioning.
- Client-side email validation should use basic format checks; the authoritative validation is Firebase's own.
- Password requirements: minimum 8 characters (Firebase's own minimum is 6, but the app enforces 8 for security).

### Architecture Compliance

- The mobile app owns presentation, gesture handling, local session persistence, and optimistic auth state display.
- The mobile app does not own profile provisioning logic; that remains server-side via the Cloud Run API.
- Firebase Auth is the identity provider; Cloud Run validates Firebase JWTs and injects authenticated user context into downstream operations.
- Session tokens in the Keychain are for session restoration only; the Firebase SDK manages token refresh automatically.
- No secrets (API keys, service accounts) should be hardcoded in the mobile app or committed to source control.

### Library / Framework Requirements

- `firebase_core: ^3.x` -- Firebase initialization
- `firebase_auth: ^5.x` -- Firebase Authentication SDK
- `google_sign_in: ^6.x` -- Google Sign-In for Flutter
- `sign_in_with_apple: ^6.x` -- Apple Sign-In for Flutter
- `flutter_secure_storage: ^9.x` -- Keychain-backed secure token storage
- `http: ^1.x` or `dio: ^5.x` -- HTTP client for API calls (prefer lightweight `http` for MVP)
- Continue using the existing Flutter `AppConfig` pattern from Story 1.1 for environment-based configuration.
- Continue using the existing Node.js test runner for any API-side test additions (none expected in this story).

### File Structure Requirements

- Expected new files/directories for this story:
  - `apps/mobile/lib/src/core/auth/auth_service.dart`
  - `apps/mobile/lib/src/core/auth/auth_state.dart`
  - `apps/mobile/lib/src/core/auth/session_manager.dart`
  - `apps/mobile/lib/src/core/networking/api_client.dart`
  - `apps/mobile/lib/src/features/auth/screens/welcome_screen.dart`
  - `apps/mobile/lib/src/features/auth/screens/email_sign_up_screen.dart`
  - `apps/mobile/lib/src/features/auth/screens/email_sign_in_screen.dart`
  - `apps/mobile/lib/src/features/auth/screens/verification_pending_screen.dart`
  - `apps/mobile/test/core/auth/auth_service_test.dart`
  - `apps/mobile/test/core/auth/session_manager_test.dart`
  - `apps/mobile/test/core/networking/api_client_test.dart`
  - `apps/mobile/test/features/auth/screens/welcome_screen_test.dart`
  - `apps/mobile/test/features/auth/screens/email_sign_up_screen_test.dart`
  - `apps/mobile/test/features/auth/screens/email_sign_in_screen_test.dart`
  - `apps/mobile/test/features/auth/screens/verification_pending_screen_test.dart`
- Expected modified files:
  - `apps/mobile/pubspec.yaml` (new dependencies)
  - `apps/mobile/lib/main.dart` (Firebase initialization)
  - `apps/mobile/lib/src/app.dart` (auth-aware routing)
  - `.env.example` (if new variables needed)
  - `README.md` (Firebase setup documentation)
  - `apps/mobile/ios/Runner.xcodeproj/project.pbxproj` (Apple Sign-In capability)
  - `apps/mobile/ios/Runner/Runner.entitlements` (Apple Sign-In entitlement)
- Do not modify `_bmad-output` except for this story file and `sprint-status.yaml`.

### Testing Requirements

- Widget tests must verify:
  - WelcomeScreen renders all three sign-in options and the sign-in link
  - EmailSignUpScreen validates email format and password length before submission
  - EmailSignInScreen displays error messages on failed authentication
  - VerificationPendingScreen offers resend and check-verification actions
- Unit tests must verify:
  - AuthService correctly delegates to FirebaseAuth for each provider
  - AuthService handles cancellation without throwing user-facing errors
  - SessionManager stores and retrieves tokens from flutter_secure_storage
  - ApiClient attaches Bearer token and handles 401/403 responses
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all API tests still pass)

### Previous Story Intelligence

- Story 1.1 established:
  - Flutter app scaffold with `AppConfig.fromEnvironment()` pattern using `--dart-define`
  - `BootstrapHomeScreen` as the placeholder home with bottom navigation (Home, Wardrobe, Profile)
  - Cloud Run API with health endpoint and config loading
  - SQL baseline under `infra/sql/migrations/001_initial_scaffold.sql`
- Story 1.2 established:
  - Firebase JWT validation middleware in `apps/api/src/middleware/authenticate.js`
  - Auth service with email verification enforcement in `apps/api/src/modules/auth/service.js`
  - Profile provisioning via `GET /v1/profiles/me` in `apps/api/src/modules/profiles/`
  - `profiles` table with `firebase_uid` unique constraint, RLS via `app.current_user_id`
  - Idempotent profile creation with `ON CONFLICT (firebase_uid) DO NOTHING`
- Key implementation details from Story 1.2:
  - The auth service extracts `sign_in_provider` from Firebase token claims (`claims.firebase.sign_in_provider`)
  - For `password` provider, `email_verified` must be true or a 403 `EMAIL_VERIFICATION_REQUIRED` is returned
  - The profile repository sets `app.current_user_id` via `set_config` for RLS enforcement
  - Profile provisioning stores `firebase_uid`, `email`, `auth_provider`, and `email_verified`

### Implementation Guidance

- Firebase initialization must happen before `runApp`. Use `WidgetsFlutterBinding.ensureInitialized()` then `await Firebase.initializeApp()`.
- For auth state management, consider a simple `ValueNotifier<AuthState>` or `ChangeNotifier` pattern rather than introducing a heavy state management library. Keep it composable for Story 1.4+ additions.
- The `SessionManager` should listen to `FirebaseAuth.idTokenChanges()` and persist each new ID token. On cold start, check `flutter_secure_storage` for a token, but also check `FirebaseAuth.currentUser` since the Firebase SDK handles its own persistence.
- For Apple Sign-In, the `rawNonce` must be SHA-256 hashed before sending to Apple, and the raw nonce passed to the Firebase `OAuthCredential`. The `sign_in_with_apple` package handles most of this.
- For the verification-pending screen, polling is not required. A manual "I've verified my email" button that calls `currentUser.reload()` then checks `currentUser.emailVerified` is sufficient for MVP.
- API client should handle token expiration by calling `currentUser.getIdToken(true)` to force a refresh before retrying failed 401 requests.

### Project Context Reference

- Epic source: [epics.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md)
  - `## Epic 1: Foundation & Authentication`
  - `### Story 1.3: User Registration & Native Sign-In`
- Architecture source: [architecture.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/architecture.md)
  - `### Authentication and Authorization`
  - `### Mobile Client`
  - `### State Management and Client Data`
  - `### API Architecture`
  - `## Project Structure`
- UX source: [ux-design-specification.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/ux-design-specification.md)
  - `## Design System Foundation`
  - `### Chosen Direction` (Vibrant Soft-UI)
  - `### Color Palette`
- PRD source: [prd.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md)
  - `FR-AUTH-01`, `FR-AUTH-02`, `FR-AUTH-03`, `FR-AUTH-05`
- Previous implementation context:
  - [1-1-greenfield-project-bootstrap.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-1-greenfield-project-bootstrap.md)
  - [1-2-authentication-data-foundation.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-2-authentication-data-foundation.md)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- Story drafted by SM agent from epics.md, architecture.md, ux-design-specification.md, prd.md, and Story 1.1/1.2 implementation artifacts.
- No git history available in the workspace.
- No external web research performed; repository-local planning and implementation artifacts were sufficient.

### Completion Notes List

- All 12 tasks implemented. 66 tests pass (flutter test), 16 API tests pass (npm test), flutter analyze reports zero issues.
- Firebase config files (GoogleService-Info.plist, google-services.json) and Xcode entitlements are documented as setup prerequisites but not created, since the iOS/Android platform directories do not exist in the workspace yet (they are generated by `flutter create`).
- AuthService uses dependency injection for FirebaseAuth, GoogleSignIn, and AppleSignInDelegate to enable testability. An `AppleSignInDelegate` abstraction was created for Apple Sign-In testability.
- The API client uses the `http` package with a `TestableApiClient` pattern in tests to avoid Firebase SDK initialization in the test environment.
- VestiaireApp accepts optional injected `authService`, `sessionManager`, and `apiClient` for testing.
- The existing `BootstrapHomeScreen` is preserved as the authenticated home shell with the original bottom navigation bar (Home, Wardrobe, Profile).
- All screens follow the Vibrant Soft-UI design: #F3F4F6 background, #4F46E5 primary accent, Semantics labels, 50px button height (exceeding 44x44 touch target minimum).

### File List

**New files created:**
- `apps/mobile/lib/src/core/auth/auth_state.dart`
- `apps/mobile/lib/src/core/auth/auth_service.dart`
- `apps/mobile/lib/src/core/auth/session_manager.dart`
- `apps/mobile/lib/src/core/networking/api_client.dart`
- `apps/mobile/lib/src/features/auth/screens/welcome_screen.dart`
- `apps/mobile/lib/src/features/auth/screens/email_sign_up_screen.dart`
- `apps/mobile/lib/src/features/auth/screens/email_sign_in_screen.dart`
- `apps/mobile/lib/src/features/auth/screens/verification_pending_screen.dart`
- `apps/mobile/test/core/auth/auth_state_test.dart`
- `apps/mobile/test/core/auth/auth_service_test.dart`
- `apps/mobile/test/core/auth/session_manager_test.dart`
- `apps/mobile/test/core/networking/api_client_test.dart`
- `apps/mobile/test/features/auth/screens/welcome_screen_test.dart`
- `apps/mobile/test/features/auth/screens/email_sign_up_screen_test.dart`
- `apps/mobile/test/features/auth/screens/email_sign_in_screen_test.dart`
- `apps/mobile/test/features/auth/screens/verification_pending_screen_test.dart`
- `_bmad-output/sprint-status.yaml`

**Modified files:**
- `apps/mobile/pubspec.yaml` (added firebase_core, firebase_auth, google_sign_in, sign_in_with_apple, flutter_secure_storage, http, crypto)
- `apps/mobile/lib/main.dart` (added Firebase initialization with WidgetsFlutterBinding.ensureInitialized + Firebase.initializeApp)
- `apps/mobile/lib/src/app.dart` (refactored to auth-aware routing with VestiaireApp StatefulWidget, auth state listener, profile provisioning)
- `apps/mobile/test/widget_test.dart` (updated to test BootstrapHomeScreen directly without Firebase initialization)

## Change Log

- 2026-03-10: Story file created by Scrum Master (Bob) based on epic breakdown, architecture, UX specification, and Stories 1.1/1.2 implementation context.
