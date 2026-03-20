# Story 1.1: Greenfield Project Bootstrap

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Team,
I want the Flutter app, Cloud Run API, database migrations, and CI foundations scaffolded consistently,
so that every subsequent feature story can be implemented on a stable baseline.

## Acceptance Criteria

1. Given the repository is cloned into a new development environment, when the bootstrap instructions are followed, then the Flutter mobile app and Cloud Run API both install and start successfully with example environment variables.
2. Given a pull request is opened, when CI runs, then the initial mobile and API validation workflows execute successfully.
3. Given a fresh environment, when the first database migration and policy scaffolding are applied, then the baseline schema/policy foundation exists for follow-on auth work.

## Tasks / Subtasks

- [x] Establish the initial repo layout aligned to architecture.
  - [x] Create `apps/mobile`, `apps/api`, `packages`, and `infra` top-level directories only as needed for the baseline scaffold.
  - [x] Keep planning artifacts under `_bmad-output` untouched.
- [x] Scaffold the Flutter mobile application baseline.
  - [x] Initialize the Flutter app in `apps/mobile`.
  - [x] Add the first app shell, environment loading approach, and placeholder theme/navigation entrypoint.
  - [x] Confirm the app boots locally with documented commands.
- [x] Scaffold the API baseline for Cloud Run.
  - [x] Initialize the API service in `apps/api`.
  - [x] Add config loading, a health endpoint, and the base middleware layout for future auth enforcement.
  - [x] Confirm the API boots locally with documented commands.
- [x] Create initial infrastructure scaffolding for data and policy work.
  - [x] Add the first SQL migration location under `infra/sql/migrations`.
  - [x] Add policy/function scaffolding under `infra/sql/policies` and `infra/sql/functions`.
  - [x] Limit this story to baseline scaffolding; Story 1.2 owns actual auth data provisioning behavior.
- [x] Add baseline developer and CI support.
  - [x] Create `.env.example` with non-secret placeholders only.
  - [x] Add GitHub workflow files for mobile and API validation.
  - [x] Document bootstrap and run commands in the repo `README.md`.

## Dev Notes

- This story is an enabling foundation story. It should create the minimum stable scaffold required for Stories 1.2 and 1.3, not prebuild unrelated product features.
- The architecture document is now the canonical source for structure and boundaries. Follow it exactly unless a later approved story changes it.
- MVP scope constraints already decided:
  - light mode only
  - portrait-only mobile UX
  - no home-screen widget
  - Flutter mobile + Cloud Run API + Cloud SQL + Firebase Auth + RevenueCat + FCM + Gemini
- Do not hardcode secrets or commit provider credentials. Use placeholder environment variables and documented setup only.
- This repo is not currently a Git repository, so local workflow automation should not assume `git` metadata exists.

### Project Structure Notes

- Target baseline structure comes from the architecture document:
  - `apps/mobile`
  - `apps/api`
  - `packages/shared-types`
  - `infra/cloud-run`
  - `infra/sql/migrations`
  - `infra/sql/policies`
  - `infra/sql/functions`
- Keep the structure thin. If a directory is not needed to satisfy this story's acceptance criteria, do not create it yet.
- Story 1.2 will build on this scaffold to provision `profiles` and RLS behavior. Avoid stealing that scope.

### Technical Requirements

- Mobile framework: Flutter.
- API runtime: Cloud Run-targeted service (`Node.js 22 or Python/FastAPI` per architecture/stack docs). Pick one runtime and scaffold consistently.
- Configuration must support local development plus future CI/CD.
- Add a health-check surface for the API to support CI and deployment smoke tests.
- Baseline SQL structure must exist so auth/profile work can land cleanly in the next story.

### Architecture Compliance

- Respect the architecture boundary that the client does not own billing truth, usage counters, or sensitive auth logic.
- Respect the server-authority principle for secrets, auth validation, and future business rules.
- Do not introduce dark mode, landscape-specific UX, web targets, or social-first navigation in the bootstrap.

### Library / Framework Requirements

- Flutter for `apps/mobile`.
- Cloud Run-compatible API service for `apps/api`.
- Environment-variable based config with example files only.
- CI should validate both app surfaces on pull requests.
- No external AI integration is required in this story.

### File Structure Requirements

- Expected files/directories to appear from this story:
  - `apps/mobile/...`
  - `apps/api/...`
  - `.env.example`
  - `.github/workflows/mobile-ci.yml`
  - `.github/workflows/api-ci.yml`
  - `infra/sql/migrations/...`
  - `infra/sql/policies/...`
  - `infra/sql/functions/...`
  - `README.md` updates
- Keep naming consistent with the architecture tree and do not place app code under `_bmad-output`.

### Testing Requirements

- Verify the mobile app starts locally.
- Verify the API starts locally and exposes a health endpoint.
- Verify CI configs parse and are wired to the intended app paths.
- Verify the initial SQL scaffold can be applied or linted without relying on future-story schema objects.
- Prefer smoke tests and validation scripts in this story; detailed feature tests belong to later stories.

### Project Context Reference

- Epic source: [epics.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md)
  - `## Epic 1: Foundation & Authentication`
  - `### Story 1.1: Greenfield Project Bootstrap`
- Architecture source: [architecture.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/architecture.md)
  - `## Core Architectural Decisions`
  - `## Project Structure`
  - `## Implementation Patterns and Boundaries`
- Stack source: [stack_recommendation.md](/Users/yassine/vestiaire2.0/docs/stack_recommendation.md)
  - `## Frontend: Flutter`
  - `## Backend: GCP Hybrid Stack`
  - `## Final Stack Summary`
- PRD source: [prd.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md)
  - `## Project-Type Requirements`
  - `## Tech Stack Reference`

## Dev Agent Record

### Agent Model Used

GPT-5

### Debug Log References

- No prior story file existed for Epic 1.
- No git history was available in the workspace.
- No external web research was performed; this story file relies on repository-local architecture and stack decisions dated 2026-03-09.
- `npm --prefix apps/api test` passed with 2/2 tests green.
- `flutter test` passed for `apps/mobile/test/widget_test.dart`.
- `flutter analyze` passed with no issues in `apps/mobile`.
- API startup smoke test passed via `PORT=4010 node apps/api/src/main.js`.
- Health response smoke test returned `200` with the expected JSON payload from `handleRequest()`.
- `npm --prefix apps/api test` passed with 4/4 tests green after review fixes.
- `flutter test --dart-define=VESTIAIRE_APP_ENV=ci --dart-define=VESTIAIRE_API_BASE_URL=http://127.0.0.1:8080` passed after review fixes.
- `flutter analyze` passed after review fixes.
- API startup smoke test passed after review fixes with `vestiaire-api listening on 0.0.0.0:4010`.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story scope intentionally limited to bootstrap/scaffolding to preserve Story 1.2 auth-data scope.
- Scaffolded a minimal Flutter app shell with strict analyzer settings and a passing widget smoke test.
- Scaffolded a Cloud Run-ready Node.js API baseline with env config, `/healthz`, and a shared not-found middleware path.
- Added baseline SQL migration, policy/function scaffold docs, example environment variables, and CI workflows for mobile and API validation.
- Documented local bootstrap and run commands in the root `README.md`.
- Addressed code-review findings by adding Cloud Run-safe host binding, `.env` file loading, validated port parsing, a mobile config/navigation entrypoint, and concrete SQL bootstrap artifacts.

### File List

- .env.example
- README.md
- .github/workflows/api-ci.yml
- .github/workflows/mobile-ci.yml
- apps/api/package.json
- apps/api/src/config/env.js
- apps/api/src/main.js
- apps/api/src/middleware/notFound.js
- apps/api/test/config.test.js
- apps/api/test/health.test.js
- apps/mobile/analysis_options.yaml
- apps/mobile/lib/main.dart
- apps/mobile/lib/src/app.dart
- apps/mobile/lib/src/config/app_config.dart
- apps/mobile/pubspec.lock
- apps/mobile/pubspec.yaml
- apps/mobile/test/widget_test.dart
- infra/sql/functions/001_set_updated_at.sql
- infra/sql/functions/README.md
- infra/sql/migrations/001_initial_scaffold.sql
- infra/sql/policies/001_bootstrap_state.sql
- infra/sql/policies/README.md

## Change Log

- 2026-03-09: Implemented the greenfield bootstrap scaffold for mobile, API, infra SQL, environment examples, CI workflows, and developer documentation; validated with API tests, Flutter tests, Flutter analyze, and API startup smoke checks.
- 2026-03-10: Code review fixes applied for Cloud Run-safe API startup, validated API config parsing, mobile env/navigation bootstrap wiring, concrete SQL baseline artifacts, and updated CI/bootstrap instructions.

## Senior Developer Review (AI)

### Review Date

2026-03-10

### Reviewer

GPT-5

### Outcome

Approve

### Findings Fixed

- [x] API now binds to `0.0.0.0` and validates `PORT`, matching the Cloud Run-targeted runtime expectation.
- [x] The mobile scaffold now has an explicit config path and placeholder navigation entrypoint instead of a single hardcoded home screen.
- [x] Bootstrap docs now distinguish API `.env` loading from Flutter `--dart-define` usage.
- [x] The SQL scaffold now contains real migration, function, and policy artifacts that can be applied in order.

### Residual Notes

- No git diff audit was possible because the workspace is not a git repository.
