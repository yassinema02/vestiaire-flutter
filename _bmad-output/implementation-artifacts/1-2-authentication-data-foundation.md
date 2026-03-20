# Story 1.2: Authentication Data Foundation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a New User,
I want my account record provisioned securely the first time I authenticate,
so that all of my app data can be stored and isolated correctly from the start.

## Acceptance Criteria

1. Given the GCP environment is configured, when a client sends a valid Firebase JWT to a protected Cloud Run API endpoint for the first time, then the API automatically creates a corresponding row in the `profiles` table in Cloud SQL before completing the request.
2. Given the authenticated provider is email/password, when the Firebase token represents an unverified email identity, then the API rejects protected access and does not provision a `profiles` row until the identity is verified; the user-facing verification UX remains in Story 1.3.
3. Given the `profiles` table exists, when authenticated profile access occurs, then Row-Level Security (RLS) using the Cloud Run to Cloud SQL identity propagation pattern ensures users can only read and write their own profile data.
4. Given duplicate provisioning attempts occur for the same authenticated user, when the provisioning flow runs again, then the behavior is idempotent and does not create duplicate profile records.

## Tasks / Subtasks

- [x] Establish the `profiles` data model and database ownership rules. (AC: 1, 2, 3, 4)
  - [x] Add the next SQL migration under `infra/sql/migrations` to create the `profiles` table on top of the Story 1.1 baseline schemas.
  - [x] Use UUID primary keys, timestamps, and a stable external auth identifier so Firebase-authenticated users map 1:1 to profile records.
  - [x] Add the minimum unique/index/constraint set needed to make profile provisioning safe and idempotent without pulling onboarding scope into this story.
- [x] Implement authenticated API provisioning flow in the Cloud Run service. (AC: 1, 2, 4)
  - [x] Add Firebase JWT validation middleware that derives the authenticated user identity server-side and never trusts a client-supplied user ID.
  - [x] Enforce the email/password verification gate server-side so unverified email identities cannot trigger protected profile provisioning.
  - [x] Create the initial API auth/profile modules and repository/service structure aligned to the architecture.
  - [x] Implement first-auth profile provisioning as an idempotent operation that returns the existing profile on repeat execution.
- [x] Enforce profile ownership at the database layer. (AC: 3)
  - [x] Add RLS policies for `profiles` that scope reads and writes to the authenticated user context.
  - [x] Use a transaction-scoped Cloud Run + Cloud SQL compatible RLS pattern based on `app.current_user_id` rather than Supabase-specific helpers such as `auth.uid()`.
  - [x] Reuse shared SQL helpers from Story 1.1 where appropriate instead of recreating timestamp logic or bootstrap objects.
- [x] Add developer-facing tests and validation for the foundation flow. (AC: 1, 2, 3, 4)
  - [x] Add API tests for valid auth context extraction, unauthorized access rejection, unverified email rejection, and repeat provisioning behavior.
  - [x] Add migration/policy validation proving the `profiles` schema and policies apply cleanly and enforce one-user ownership through `app.current_user_id`.
  - [x] Update bootstrap/run documentation only where the new auth data foundation changes Firebase Admin setup, verification commands, or local auth test prerequisites.

## Dev Notes

- This story establishes the backend and data foundation for authenticated users. It should not implement registration UI, Apple/Google sign-in screens, session persistence UX, onboarding forms, or notification/profile-edit features; those belong to later stories.
- The highest-value outcome is a reliable server-side path from Firebase-authenticated identity to a single Cloud SQL `profiles` row with enforceable ownership rules.
- Firebase Auth is the identity provider, but Cloud Run remains the authority for request validation and provisioning side effects.
- For email/password identities, this story must preserve the email verification requirement by refusing protected API access until Firebase reports the identity as verified. Story 1.3 owns the user-facing verification flow.
- Keep the implementation thin and composable for Story 1.3. Avoid prebuilding unrelated auth features such as password reset, sign-out UX, onboarding steps, or push token storage.
- This repository is still not a Git repository, so workflow automation must not depend on git metadata.

### Project Structure Notes

- Architecture target for this epic points to:
  - `apps/api/src/modules/auth`
  - `apps/api/src/modules/profiles`
  - `apps/api/src/db`
  - `infra/sql/migrations`
  - `infra/sql/policies`
- Current scaffold from Story 1.1 is thinner than the target architecture:
  - API is currently Node.js ESM JavaScript, not TypeScript.
  - Mobile currently exposes `lib/main.dart`, `lib/src/app.dart`, and `lib/src/config/app_config.dart`.
  - SQL baseline already exists under `infra/sql/migrations`, `infra/sql/functions`, and `infra/sql/policies`.
- Do not spend this story migrating the scaffold to TypeScript or fully expanding the mobile feature tree. Extend the existing scaffold in-place unless a small structural addition is required for auth/profile clarity.

### Technical Requirements

- API runtime remains the current Cloud Run-targeted Node.js 22 ESM service created in Story 1.1.
- Authentication middleware must validate Firebase-issued JWTs and derive the authenticated subject server-side on every protected request.
- The provisioning trigger for this story is the first successful call to a protected API path after JWT validation; do not invent a separate client-managed provisioning job or direct database write path.
- For email/password sign-in, the middleware or auth service must check the verified-email claim before allowing provisioning or protected profile access.
- The server must provision profile data through the API layer, not through client-direct database writes.
- The `profiles` table should be the single root table for user-owned application data, designed so later tables can reference it cleanly.
- Idempotency is mandatory. Repeat first-login or retry flows must not create duplicate `profiles` rows.
- Favor deterministic SQL and explicit constraints over application-only duplicate checks.

### Architecture Compliance

- Respect the architecture rule that Cloud Run validates Firebase JWTs and injects authenticated `user_id` into downstream operations.
- Respect the database boundary: RLS protects user-facing tables, while sensitive authorization logic remains server-driven.
- Because this stack uses Firebase Auth + Cloud SQL, do not assume Supabase-only helpers like `auth.uid()` exist in PostgreSQL; use the transaction-scoped `app.current_user_id` session setting pattern for `profiles` access control.
- Keep client responsibility minimal in this story. Mobile may only gain the smallest shared auth contract/helper needed by the server-driven foundation, and only if implementation truly requires it.
- Do not add social, wardrobe, subscription, notification, or onboarding business logic here.

### Library / Framework Requirements

- Continue using the existing Node.js built-in test runner for API tests unless a new dependency is explicitly approved.
- Continue using the existing Flutter scaffold and `AppConfig` pattern from Story 1.1 if any mobile-side contract changes are needed.
- Reuse the SQL helper function introduced in Story 1.1 (`app_private.set_updated_at()`) for timestamp maintenance where appropriate.
- If an HTTP/auth helper is added, keep it compatible with the current JSON REST API shape and future Firebase token-based requests.
- Reuse the existing repo-level environment loading pattern and wire any Firebase Admin credentials through `.env` / `.env.local` rather than hardcoding service-account data.

### File Structure Requirements

- Expected new or updated areas for this story:
  - `apps/api/src/middleware/` for auth enforcement
  - `apps/api/src/modules/auth/`
  - `apps/api/src/modules/profiles/`
  - `apps/api/src/db/`
  - `apps/api/test/`
  - `infra/sql/migrations/`
  - `infra/sql/policies/`
  - `README.md` only if setup/verification steps change
- Likely file additions:
  - `apps/api/src/middleware/auth*.js`
  - `apps/api/src/modules/auth/*.js`
  - `apps/api/src/modules/profiles/*.js`
  - `apps/api/src/db/*.js`
  - `apps/api/test/*auth*.test.js`
  - `apps/api/test/*profiles*.test.js`
  - `infra/sql/migrations/002_profiles*.sql`
  - `infra/sql/policies/002_profiles*.sql`
- Do not modify `_bmad-output` except for the story file bookkeeping the workflow requires.

### Testing Requirements

- Add automated API tests proving:
  - authenticated identity is derived from validated auth context
  - unauthenticated requests are rejected
  - unverified email/password identities are rejected before provisioning
  - first provisioning creates a profile
  - second provisioning for the same user returns a single existing profile outcome
- Add validation for the database foundation:
  - migration applies cleanly after Story 1.1 SQL baseline
  - `profiles` ownership policies restrict read/write access to the current authenticated user context via `app.current_user_id`
  - unique constraints prevent duplicate provisioning
- Preserve existing regressions:
  - `npm --prefix apps/api test`
  - `flutter analyze`
  - `flutter test`
- Prefer local deterministic tests over hand-wavy manual claims. If policy verification depends on a DB session variable pattern, test that pattern explicitly.

### Previous Story Intelligence

- Story 1.1 established these foundations and should be extended, not replaced:
  - API config loading from `apps/api/src/config/env.js`
  - Cloud Run-safe API startup in `apps/api/src/main.js`
  - Mobile `AppConfig` bootstrapping in `apps/mobile/lib/src/config/app_config.dart`
  - SQL baseline artifacts:
    - `infra/sql/migrations/001_initial_scaffold.sql`
    - `infra/sql/functions/001_set_updated_at.sql`
    - `infra/sql/policies/001_bootstrap_state.sql`
- Review fixes from Story 1.1 already corrected:
  - `0.0.0.0` binding for Cloud Run
  - `.env` loading for the API
  - mobile `--dart-define` usage for app config
- Reuse those patterns. Do not reintroduce placeholder-only SQL or hardcoded localhost-only runtime assumptions.

### Implementation Guidance

- The architecture and stack docs imply a Firebase-to-Cloud-SQL ownership bridge:
  - Firebase token is validated in Cloud Run
  - Cloud Run determines the authenticated user ID
  - Cloud Run sets the database auth context for the transaction/query
  - PostgreSQL RLS policies enforce row ownership using that context
- Standardize this story on a transaction-scoped PostgreSQL setting such as `app.current_user_id`, referenced inside RLS policies with `current_setting('app.current_user_id', true)`, so the developer does not need to invent a different Firebase-to-Postgres ownership bridge.
- Keep the protected API surface small. A conventional implementation is to provision on the first authenticated profile/me-style request, but any protected route is acceptable if it is server-owned, documented, and covered by tests.
- Keep the first provisioning payload minimal. This story only needs the fields required to establish identity and future ownership; richer onboarding/profile attributes belong to Stories 1.3 and 1.5.

### Project Context Reference

- Epic source: [epics.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md)
  - `## Epic 1: Foundation & Authentication`
  - `### Story 1.2: Authentication Data Foundation`
- Architecture source: [architecture.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/architecture.md)
  - `### Authentication and Authorization`
  - `### API Architecture`
  - `### Data Architecture`
  - `## Project Structure`
  - `## Epic-to-Component Mapping`
- PRD source: [prd.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md)
  - `## Tech Stack Reference`
  - `## Non-Functional Requirements`
- Requirements source: [functional-requirements.md](/Users/yassine/vestiaire2.0/docs/functional-requirements.md)
  - `FR-AUTH-10`
  - `NFR-SEC-02`
  - `## 7. Data Model / Database Schema`
- Stack source: [stack_recommendation.md](/Users/yassine/vestiaire2.0/docs/stack_recommendation.md)
  - `## 🏗️ Backend: GCP Hybrid Stack`
  - `### Cloud Run API Design (Multi-Tenant)`
  - `## ⚠️ Key Risks`
- Previous implementation context: [1-1-greenfield-project-bootstrap.md](/Users/yassine/vestiaire2.0/_bmad-output/implementation-artifacts/1-1-greenfield-project-bootstrap.md)
  - `### Previous Story Intelligence`
  - `### Completion Notes List`
  - `## Senior Developer Review (AI)`

## Dev Agent Record

### Agent Model Used

GPT-5

### Debug Log References

- Story drafted from `epics.md` plus architecture, PRD, functional requirements, stack recommendation, and Story 1.1 implementation learnings.
- No project-level `project-context.md` file was present in the workspace.
- No git history was available in the workspace.
- No external web research was performed; repository-local planning and implementation artifacts were sufficient for this story draft.
- 2026-03-10: Added `profiles` migration/policy artifacts and SQL validation tests; `npm --prefix apps/api test`, `flutter analyze`, and `flutter test` passed after Task 1.
- 2026-03-10: Installed `pg`, added Firebase JWT validation/auth middleware, created `GET /v1/profiles/me`, implemented idempotent `profiles` provisioning, added repository/service/endpoint tests, and re-ran `npm --prefix apps/api test`, `flutter analyze`, and `flutter test` successfully.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story scope is intentionally limited to authenticated profile provisioning, RLS enforcement, and idempotent server-side auth data foundations.
- Guidance includes explicit protection against using Supabase-only RLS helpers in a Firebase Auth + Cloud SQL stack.
- Implemented the `profiles` schema foundation with UUID primary key, Firebase UID uniqueness, timestamp fields, and transaction-scoped RLS using `app.current_user_id`.
- Added a real `pg`-backed repository flow that sets `app.current_user_id`, provisions on first authenticated `GET /v1/profiles/me`, and returns existing profiles idempotently on repeat access.
- Added auth service coverage for bearer-token extraction, verified-email enforcement for password identities, protected-route behavior, and repository/session-setting behavior.
- Updated `README.md` with Story 1.2 API setup, protected-route verification, and SQL artifact order.

### File List

- README.md
- apps/api/package-lock.json
- apps/api/package.json
- apps/api/src/config/env.js
- apps/api/src/db/pool.js
- apps/api/src/http/json.js
- apps/api/src/main.js
- apps/api/src/middleware/authenticate.js
- apps/api/src/modules/auth/firebaseTokenVerifier.js
- apps/api/src/modules/auth/service.js
- apps/api/src/modules/profiles/repository.js
- apps/api/src/modules/profiles/service.js
- apps/api/test/auth-service.test.js
- apps/api/test/config.test.js
- apps/api/test/health.test.js
- apps/api/test/profile-endpoint.test.js
- apps/api/test/profile-repository.test.js
- apps/api/test/profile-service.test.js
- apps/api/test/sql-foundation.test.js
- infra/sql/migrations/002_profiles.sql
- infra/sql/policies/002_profiles_rls.sql

## Change Log

- 2026-03-10: Implemented Story 1.2 auth/profile foundation with Firebase JWT validation, idempotent profile provisioning, `profiles` RLS enforcement, SQL validation tests, API behavior tests, and updated setup/verification docs.
