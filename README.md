# Vestiaire

Baseline scaffold for the Vestiaire mobile app and API.

## Structure

- `apps/mobile`: Flutter mobile app
- `apps/api`: Cloud Run-targeted API service
- `infra/sql/migrations`: SQL migrations
- `infra/sql/policies`: RLS policy scaffolds
- `infra/sql/functions`: database function scaffolds
- `.github/workflows`: CI validation

## Prerequisites

- Flutter SDK (stable)
- Node.js 22+
- PostgreSQL 15+ or a Cloud SQL Postgres instance for SQL bootstrap validation

## Setup

```bash
cp .env.example .env
```

The API auto-loads `.env` or `.env.local` from the repo root. The Flutter app consumes the same values through `--dart-define` flags.

## Mobile

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test \
  --dart-define=VESTIAIRE_APP_ENV=development \
  --dart-define=VESTIAIRE_API_BASE_URL=http://127.0.0.1:8080
flutter run \
  --dart-define=VESTIAIRE_APP_ENV=development \
  --dart-define=VESTIAIRE_API_BASE_URL=http://127.0.0.1:8080
```

## API

```bash
cd apps/api
npm install
npm test
node src/main.js
```

The API health endpoint is available at `GET /healthz`.
The Story 1.2 protected provisioning endpoint is `GET /v1/profiles/me` and requires:

- `DATABASE_URL`
- `FIREBASE_PROJECT_ID`
- a valid Firebase bearer token in `Authorization: Bearer <token>`

On first successful authenticated access, the API provisions a `profiles` row and returns:

```json
{
  "profile": {
    "id": "uuid",
    "firebaseUid": "firebase-user-id",
    "email": "user@example.com",
    "authProvider": "password",
    "emailVerified": true
  },
  "provisioned": true
}
```

Repeat access for the same authenticated user returns the same profile with `provisioned: false`.

## SQL Bootstrap

Apply the database artifacts in this order:

```bash
psql "$DATABASE_URL" -f infra/sql/migrations/001_initial_scaffold.sql
psql "$DATABASE_URL" -f infra/sql/migrations/002_profiles.sql
psql "$DATABASE_URL" -f infra/sql/functions/001_set_updated_at.sql
psql "$DATABASE_URL" -f infra/sql/policies/001_bootstrap_state.sql
psql "$DATABASE_URL" -f infra/sql/policies/002_profiles_rls.sql
```

Story 1.2 uses a transaction-scoped PostgreSQL setting, `app.current_user_id`, to bridge the authenticated Firebase identity into RLS-protected `profiles` access.

## Firebase Setup (Story 1.3)

The mobile app uses Firebase Auth for authentication. To enable the full auth flow:

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project (or use an existing one).
2. Enable the following sign-in providers under **Authentication > Sign-in method**:
   - Email/Password
   - Apple
   - Google

### 2. Add Firebase Config Files

- **iOS:** Download `GoogleService-Info.plist` from the Firebase Console and place it in `apps/mobile/ios/Runner/`.
- **Android:** Download `google-services.json` from the Firebase Console and place it in `apps/mobile/android/app/`.
- Add both files to `.gitignore` -- they contain project-specific configuration and should not be committed.

### 3. Apple Sign-In (iOS)

Apple Sign-In requires Xcode entitlements:

1. Open `apps/mobile/ios/Runner.xcworkspace` in Xcode.
2. Select the Runner target, go to **Signing & Capabilities**.
3. Click **+ Capability** and add **Sign in with Apple**.
4. This creates `Runner.entitlements` with the `com.apple.developer.applesignin` entitlement.
5. Ensure your Apple Developer account has the Sign in with Apple capability enabled for your App ID.

### 4. Google Sign-In (iOS)

Google Sign-In requires a URL scheme:

1. Open `GoogleService-Info.plist` and find the `REVERSED_CLIENT_ID` value.
2. In Xcode, go to Runner target > **Info > URL Types** and add the reversed client ID as a URL scheme.

### Testing Auth Flows Locally

- Use the [Firebase Local Emulator Suite](https://firebase.google.com/docs/emulator-suite) for local testing without a live Firebase project.
- Run `firebase emulators:start --only auth` to start the Auth emulator.
- Configure the Flutter app to point to the emulator by setting the `FIREBASE_AUTH_EMULATOR_HOST` environment variable or using `FirebaseAuth.instance.useAuthEmulator('localhost', 9099)` in development mode.
- Alternatively, create a dedicated Firebase test project for development.

## Environment

Copy `.env.example` and set real values in your local environment. Do not commit secrets.
