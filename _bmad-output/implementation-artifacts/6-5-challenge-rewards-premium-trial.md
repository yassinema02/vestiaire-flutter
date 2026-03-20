# Story 6.5: Challenge Rewards (Premium Trial)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a New User,
I want to unlock a free month of Premium by completing the Closet Safari challenge (upload 20 items within 7 days of signup),
so that I am incentivized to digitize my first 20 items quickly and experience the full Premium feature set.

## Acceptance Criteria

1. Given the `challenges` and `user_challenges` tables do not yet exist, when migration 020 is applied, then the `app_public.challenges` table is created with columns: `id UUID PK DEFAULT gen_random_uuid()`, `key TEXT NOT NULL UNIQUE` (e.g., "closet_safari"), `name TEXT NOT NULL` (e.g., "Closet Safari"), `description TEXT NOT NULL` (e.g., "Upload 20 items in 7 days to unlock 1 month Premium free"), `target_count INTEGER NOT NULL` (e.g., 20), `time_limit_days INTEGER NOT NULL` (e.g., 7), `reward_type TEXT NOT NULL CHECK (reward_type IN ('premium_trial'))`, `reward_value INTEGER NOT NULL` (e.g., 30 -- days of premium), `icon_name TEXT NOT NULL` (e.g., "explore"), `created_at TIMESTAMPTZ DEFAULT now()`. The `app_public.user_challenges` table is created with columns: `id UUID PK DEFAULT gen_random_uuid()`, `profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE`, `challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE`, `status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'expired', 'skipped'))`, `accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `completed_at TIMESTAMPTZ`, `expires_at TIMESTAMPTZ NOT NULL`, `current_progress INTEGER NOT NULL DEFAULT 0`, `UNIQUE(profile_id, challenge_id)`. RLS is enabled on `user_challenges`, allowing users to read/update only their own rows. The `challenges` table is readable by all authenticated users (public catalog). An index exists on `user_challenges(profile_id)`. One seed record is inserted: the "Closet Safari" challenge (key: "closet_safari", name: "Closet Safari", description: "Upload 20 items in 7 days to unlock 1 month Premium free", target_count: 20, time_limit_days: 7, reward_type: "premium_trial", reward_value: 30, icon_name: "explore"). (FR-ONB-03, FR-ONB-04)

2. Given the `profiles` table has an `is_premium` column (from migration 014) but no `premium_trial_expires_at` column, when migration 020 is applied, then a new column `premium_trial_expires_at TIMESTAMPTZ` is added to `app_public.profiles` (nullable, NULL means no active trial). A database RPC function `app_public.grant_premium_trial(p_profile_id UUID, p_days INTEGER)` is created that sets `is_premium = true` and `premium_trial_expires_at = NOW() + (p_days || ' days')::INTERVAL` on the profile row. The function returns `TABLE(is_premium BOOLEAN, premium_trial_expires_at TIMESTAMPTZ)`. A second RPC function `app_public.check_trial_expiry(p_profile_id UUID)` is created that checks if `premium_trial_expires_at` is non-null and in the past -- if so, it sets `is_premium = false` and `premium_trial_expires_at = NULL`, returning the updated values. This expiry check is lazy (called on relevant API endpoints). (FR-ONB-04)

3. Given a new user has completed the onboarding flow, when the Closet Safari challenge screen is presented (after onboarding or from the profile/home screen), then the user sees a challenge card showing: the challenge name ("Closet Safari"), description, a progress indicator (X/20 items), time remaining (e.g., "5 days left"), reward description ("Unlock 1 month Premium free"), and an "Accept Challenge" button (if not yet accepted) or the progress view (if already accepted). If the challenge has expired, a "Challenge Expired" state is shown. If completed, a "Completed" state with the reward is shown. (FR-ONB-03)

4. Given a user taps "Accept Challenge" on the Closet Safari card, when the API processes the acceptance via `POST /v1/challenges/closet_safari/accept`, then a `user_challenges` row is created with `status = 'active'`, `accepted_at = now()`, `expires_at = now() + 7 days`, `current_progress` set to the user's current item count at the time of acceptance. The API returns `{ challenge: { key, name, status, acceptedAt, expiresAt, currentProgress, targetCount, timeRemainingSeconds } }`. If the user already has a row for this challenge (idempotent), return the existing challenge state. (FR-ONB-03)

5. Given a user has an active Closet Safari challenge, when the user uploads a new item via `POST /v1/items`, then the API checks if the user has an active "closet_safari" challenge. If yes, `current_progress` is incremented by 1 (via an atomic RPC `app_public.increment_challenge_progress(p_profile_id UUID, p_challenge_key TEXT)` that also checks whether the challenge is now complete). The API response for `POST /v1/items` includes a `challengeUpdate` object: `{ key: "closet_safari", currentProgress, targetCount, completed: boolean, timeRemainingSeconds }` when the user has an active challenge, or `null` when they do not. Challenge progress update is best-effort (wrapped in try/catch) and does NOT fail item creation. (FR-ONB-03)

6. Given a user's Closet Safari `current_progress` reaches the `target_count` (20), when the `increment_challenge_progress` RPC detects completion, then it atomically: (a) sets `user_challenges.status = 'completed'` and `user_challenges.completed_at = now()`, (b) calls `grant_premium_trial(p_profile_id, 30)` to set `profiles.is_premium = true` and `profiles.premium_trial_expires_at = now() + 30 days`, (c) returns `{ completed: true, rewardGranted: true }`. The API response for `POST /v1/items` includes `challengeUpdate.completed = true` and `challengeUpdate.rewardGranted = true`. (FR-ONB-03, FR-ONB-04)

7. Given the user completes the Closet Safari challenge, when the mobile client receives a response where `challengeUpdate.completed = true`, then a celebratory modal is displayed showing: a confetti/trophy icon, "Closet Safari Complete!" title, "You've unlocked 1 month of Premium!" description, "Your Premium trial expires on [date]" subtitle, and a "Continue" button to dismiss. Haptic feedback (heavy impact) fires when the modal appears. (FR-ONB-03, FR-ONB-04)

8. Given a user has an active Closet Safari challenge, when `GET /v1/user-stats` is called, then the response includes a `challenge` object: `{ key, name, status, currentProgress, targetCount, expiresAt, timeRemainingSeconds, reward: { type, value, description } }`. If the user has no active/completed challenge, `challenge` is null. If the challenge has expired (current time > expires_at and status is still "active"), the system lazily sets `status = 'expired'` and returns the expired state. (FR-ONB-03)

9. Given a user has an active premium trial (is_premium = true, premium_trial_expires_at is set), when any premium-gated API endpoint is called (outfit generation, analytics summary, etc.), then the `check_trial_expiry` RPC is called lazily to verify the trial has not expired. If expired, `is_premium` is set to `false` before the premium check, ensuring the user is properly downgraded. This integrates with the existing `usageLimitService` and `analyticsSummaryService` premium checks without modifying their logic -- only the `is_premium` value is kept accurate. (FR-ONB-04)

10. Given a user visits the Profile tab, when the profile screen loads, then if the user has an active challenge, a `ChallengeProgressCard` widget is displayed between the `GamificationHeader` and the badge collection grid. The card shows: challenge name, progress bar (X/20), time remaining, and the reward description. If the challenge is completed, the card shows a green "Completed" state with the reward. If expired, the card shows a gray "Expired" state. If no challenge exists, no card is shown. (FR-ONB-03, FR-GAM-05)

11. Given a user has an active challenge, when the Home screen loads, then a compact challenge banner is shown at the top of the home screen (below the weather widget) with: "Closet Safari: X/20 items -- Y days left" and a progress bar. Tapping the banner navigates to the full challenge detail screen or scrolls to the profile tab. (FR-ONB-03)

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (554+ API tests, 1022+ Flutter tests) and new tests cover: migration 020 (challenges + user_challenges tables, seed data, grant_premium_trial RPC, increment_challenge_progress RPC, check_trial_expiry RPC), challenge-service unit tests, challenge endpoints (POST /v1/challenges/closet_safari/accept, GET /v1/user-stats with challenge data, challengeUpdate in POST /v1/items), ChallengeProgressCard widget, ChallengeCompletionModal widget, ChallengeBanner widget, ProfileScreen challenge integration, and challenge modal in item upload flow.

## Tasks / Subtasks

- [x] Task 1: Database -- Create migration 020 for challenges, user_challenges, and premium trial (AC: 1, 2)
  - [x] 1.1: Create `infra/sql/migrations/020_challenges.sql`. Create table `app_public.challenges` with columns as specified in AC1. Create table `app_public.user_challenges` with columns, UNIQUE constraint, status CHECK constraint, and foreign keys as specified in AC1. Enable RLS on `user_challenges`: policy allows users to SELECT and UPDATE their own rows (`profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id'))`). The `challenges` table uses a simpler RLS policy: all authenticated users can SELECT (public catalog). Create index: `CREATE INDEX idx_user_challenges_profile ON app_public.user_challenges(profile_id)`. Insert Closet Safari seed record: `INSERT INTO app_public.challenges (key, name, description, target_count, time_limit_days, reward_type, reward_value, icon_name) VALUES ('closet_safari', 'Closet Safari', 'Upload 20 items in 7 days to unlock 1 month Premium free', 20, 7, 'premium_trial', 30, 'explore')`.
  - [x] 1.2: Add column to profiles: `ALTER TABLE app_public.profiles ADD COLUMN premium_trial_expires_at TIMESTAMPTZ`. This is nullable -- NULL means no active trial.
  - [x] 1.3: Create RPC `app_public.grant_premium_trial(p_profile_id UUID, p_days INTEGER)` in PL/pgSQL. Updates the profile: `UPDATE app_public.profiles SET is_premium = true, premium_trial_expires_at = NOW() + (p_days || ' days')::INTERVAL WHERE id = p_profile_id RETURNING is_premium, premium_trial_expires_at`.
  - [x] 1.4: Create RPC `app_public.check_trial_expiry(p_profile_id UUID)` in PL/pgSQL. Checks if `premium_trial_expires_at IS NOT NULL AND premium_trial_expires_at < NOW()`. If so: `UPDATE app_public.profiles SET is_premium = false, premium_trial_expires_at = NULL WHERE id = p_profile_id`. Returns `TABLE(is_premium BOOLEAN, premium_trial_expires_at TIMESTAMPTZ, trial_expired BOOLEAN)`.
  - [x] 1.5: Create RPC `app_public.increment_challenge_progress(p_profile_id UUID, p_challenge_key TEXT)` in PL/pgSQL. Steps: (a) look up the challenge by key, (b) look up user_challenges for this profile+challenge where status = 'active', (c) if no active challenge found, return NULL, (d) if `expires_at < NOW()`, set status = 'expired' and return expired state, (e) increment `current_progress` by 1, (f) if `current_progress >= target_count`, set `status = 'completed'`, `completed_at = now()`, and call `app_public.grant_premium_trial(p_profile_id, reward_value)`, (g) return `TABLE(challenge_key TEXT, current_progress INTEGER, target_count INTEGER, completed BOOLEAN, reward_granted BOOLEAN, time_remaining_seconds INTEGER)`. The `time_remaining_seconds` is `EXTRACT(EPOCH FROM (expires_at - NOW()))::INTEGER`.

- [x] Task 2: API -- Create challenge repository (AC: 1, 4, 5, 8)
  - [x] 2.1: Create `apps/api/src/modules/gamification/challenge-repository.js` with `createChallengeRepository({ pool })`. Follow the factory pattern used by all other repositories.
  - [x] 2.2: Implement `async getChallenge(challengeKey)` method. Query: `SELECT key, name, description, target_count, time_limit_days, reward_type, reward_value, icon_name FROM app_public.challenges WHERE key = $1`. Map snake_case to camelCase.
  - [x] 2.3: Implement `async getUserChallenge(authContext, challengeKey)` method. Query: `SELECT uc.status, uc.accepted_at, uc.completed_at, uc.expires_at, uc.current_progress, c.target_count, c.name, c.key, c.reward_type, c.reward_value, EXTRACT(EPOCH FROM (uc.expires_at - NOW()))::INTEGER AS time_remaining_seconds FROM app_public.user_challenges uc JOIN app_public.challenges c ON c.id = uc.challenge_id WHERE uc.profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1) AND c.key = $2`. Map to camelCase. Return null if no row found.
  - [x] 2.4: Implement `async acceptChallenge(authContext, challengeKey)` method. Look up `profile_id` from `profiles.firebase_uid`, look up `challenge_id` from `challenges.key`, count current items for this profile (`SELECT COUNT(*) FROM app_public.items WHERE profile_id = ...`), insert into `user_challenges`: `INSERT INTO app_public.user_challenges (profile_id, challenge_id, status, expires_at, current_progress) VALUES ($1, $2, 'active', NOW() + (SELECT time_limit_days || ' days' FROM app_public.challenges WHERE id = $2)::INTERVAL, $3) ON CONFLICT (profile_id, challenge_id) DO NOTHING RETURNING *`. If ON CONFLICT (already exists), select and return the existing row. Return full challenge state.
  - [x] 2.5: Implement `async incrementProgress(authContext, challengeKey)` method. Look up `profile_id`, call `SELECT * FROM app_public.increment_challenge_progress($1, $2)` with `[profileId, challengeKey]`. Map to camelCase. Return `{ challengeKey, currentProgress, targetCount, completed, rewardGranted, timeRemainingSeconds }` or null if no active challenge.
  - [x] 2.6: Implement `async expireChallengeIfNeeded(authContext, challengeKey)` method. Check user_challenges for active challenge where `expires_at < NOW()`. If found, update status to 'expired'. Return updated state or null.

- [x] Task 3: API -- Create challenge service (AC: 4, 5, 6, 8, 9)
  - [x] 3.1: Create `apps/api/src/modules/gamification/challenge-service.js` with `createChallengeService({ challengeRepo, pool })`. Follow the factory pattern.
  - [x] 3.2: Implement `async acceptChallenge(authContext, challengeKey)` method. Validates challengeKey is "closet_safari" (only supported challenge for now). Calls `challengeRepo.acceptChallenge(authContext, challengeKey)`. Returns `{ challenge: { key, name, status, acceptedAt, expiresAt, currentProgress, targetCount, timeRemainingSeconds } }`.
  - [x] 3.3: Implement `async updateProgressOnItemCreate(authContext)` method. Calls `challengeRepo.incrementProgress(authContext, "closet_safari")`. Returns `{ challengeUpdate: { key, currentProgress, targetCount, completed, rewardGranted, timeRemainingSeconds } }` or `{ challengeUpdate: null }` if no active challenge.
  - [x] 3.4: Implement `async getChallengeStatus(authContext)` method. Calls `challengeRepo.getUserChallenge(authContext, "closet_safari")`. If active and expired, calls `challengeRepo.expireChallengeIfNeeded(authContext, "closet_safari")`. Returns the challenge state or null.
  - [x] 3.5: Implement `async checkTrialExpiry(authContext)` method. Look up `profile_id`, call `SELECT * FROM app_public.check_trial_expiry($1)`. This ensures `is_premium` is accurate before any premium-gated operation.

- [x] Task 4: API -- Add challenge endpoints and integrate into existing routes (AC: 4, 5, 6, 8, 9)
  - [x] 4.1: In `apps/api/src/main.js`, import `createChallengeRepository` and `createChallengeService`. In `createRuntime()`, instantiate `challengeRepo = createChallengeRepository({ pool })` and `challengeService = createChallengeService({ challengeRepo, pool })`. Add both to the returned runtime object.
  - [x] 4.2: In `handleRequest`, add `challengeRepo` and `challengeService` to the destructuring.
  - [x] 4.3: Add route `POST /v1/challenges/:challengeKey/accept`. Requires authentication. Extracts `challengeKey` from the URL path. Calls `challengeService.acceptChallenge(authContext, challengeKey)`. Returns 200 with challenge state. Returns 404 if challenge key is unknown. Place after `GET /v1/badges` and before `notFound`.
  - [x] 4.4: In the `POST /v1/items` route, after the existing points, level, and badge calls, add: `const challengeResult = await challengeService.updateProgressOnItemCreate(authContext)`. Include in the response: `challengeUpdate: challengeResult.challengeUpdate`. Wrap in try/catch (best-effort).
  - [x] 4.5: Update `GET /v1/user-stats` route: after the existing stats and badge fetch, call `challengeService.getChallengeStatus(authContext)`. Merge into the response: `{ stats: { ...existingStats, challenge: challengeState } }`. Wrap in try/catch so challenge failure does not break stats.
  - [x] 4.6: Add trial expiry check to premium-gated endpoints. In the `POST /v1/outfits/generate` route (where `usageLimitService.checkAndLog` is called), add a `challengeService.checkTrialExpiry(authContext)` call BEFORE the premium check. Similarly add to `GET /v1/analytics/summary` route before the premium check. This keeps `is_premium` accurate. Wrap in try/catch -- if trial check fails, proceed with current `is_premium` value.

- [x] Task 5: API -- Unit tests for challenge repository (AC: 1, 4, 5, 6, 12)
  - [x] 5.1: Create `apps/api/test/modules/gamification/challenge-repository.test.js`:
    - `getChallenge` returns closet_safari challenge definition.
    - `getChallenge` returns null for unknown challenge key.
    - `getUserChallenge` returns null when user has not accepted.
    - `getUserChallenge` returns challenge state when accepted.
    - `acceptChallenge` creates user_challenges row with correct fields.
    - `acceptChallenge` is idempotent (second call returns existing row).
    - `acceptChallenge` sets current_progress to user's current item count.
    - `acceptChallenge` sets expires_at to 7 days from now.
    - `incrementProgress` increments current_progress by 1.
    - `incrementProgress` returns null when no active challenge.
    - `incrementProgress` sets status to "expired" when time has passed.
    - `incrementProgress` completes challenge when reaching target_count.
    - `incrementProgress` grants premium trial on completion.
    - `incrementProgress` is idempotent for already-completed challenges.
    - RLS isolation: user A cannot read/modify user B's challenges.

- [x] Task 6: API -- Unit tests for challenge service (AC: 4, 5, 6, 8, 9, 12)
  - [x] 6.1: Create `apps/api/test/modules/gamification/challenge-service.test.js`:
    - `acceptChallenge` returns challenge state for valid key.
    - `acceptChallenge` throws 404 for invalid challenge key.
    - `updateProgressOnItemCreate` returns challengeUpdate when active challenge exists.
    - `updateProgressOnItemCreate` returns null challengeUpdate when no active challenge.
    - `updateProgressOnItemCreate` returns completed=true when target reached.
    - `getChallengeStatus` returns challenge state.
    - `getChallengeStatus` expires stale challenges.
    - `getChallengeStatus` returns null when no challenge.
    - `checkTrialExpiry` calls check_trial_expiry RPC.
    - `checkTrialExpiry` downgrades expired premium trials.

- [x] Task 7: API -- Integration tests for challenge endpoints (AC: 4, 5, 6, 8, 9, 12)
  - [x] 7.1: Create `apps/api/test/modules/gamification/challenge-endpoints.test.js`:
    - `POST /v1/challenges/closet_safari/accept` returns 200 with challenge state.
    - `POST /v1/challenges/closet_safari/accept` returns 401 if unauthenticated.
    - `POST /v1/challenges/unknown_key/accept` returns 404.
    - `POST /v1/challenges/closet_safari/accept` is idempotent.
    - `POST /v1/items` response includes `challengeUpdate` when active challenge exists.
    - `POST /v1/items` response has `challengeUpdate: null` when no active challenge.
    - `GET /v1/user-stats` includes `challenge` object when challenge accepted.
    - `GET /v1/user-stats` returns `challenge: null` when no challenge.
    - Challenge progress increments correctly across multiple item uploads.
    - Challenge completion triggers premium trial grant (is_premium = true).
    - Premium trial expiry correctly downgrades is_premium to false.
    - Challenge update failure does not break item creation.

- [x] Task 8: API -- Update existing gamification tests (AC: 12)
  - [x] 8.1: Update `apps/api/test/modules/gamification/gamification-endpoints.test.js`: add `challengeService` mock to the route handler setup. Verify `GET /v1/user-stats` response can include `challenge` field (additive, backward-compatible).
  - [x] 8.2: Verify existing `POST /v1/items` tests still pass with the added `challengeUpdate` field.

- [x] Task 9: Mobile -- Update ApiClient for challenge data (AC: 3, 4, 7, 10, 11)
  - [x] 9.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> acceptChallenge(String challengeKey)` method. Calls `POST /v1/challenges/$challengeKey/accept` using `_authenticatedPost`. Returns the response JSON map.
  - [x] 9.2: The existing `getUserStats()` method already returns the full response map -- the new `challenge` field will be available automatically. Add JSDoc documenting the new field.

- [x] Task 10: Mobile -- Create ChallengeProgressCard widget (AC: 3, 10)
  - [x] 10.1: Create `apps/mobile/lib/src/features/profile/widgets/challenge_progress_card.dart` with a `ChallengeProgressCard` StatelessWidget. Constructor accepts: `required String name`, `required int currentProgress`, `required int targetCount`, `required String status` (active/completed/expired), `String? expiresAt`, `int? timeRemainingSeconds`, `String? rewardDescription`, `VoidCallback? onAccept`.
  - [x] 10.2: The widget renders a `Container` (card style: white background, 12px border radius, subtle shadow, 16px padding) containing:
    - **Active state:** Challenge icon (Icons.explore, #4F46E5), challenge name (16px bold, #1F2937), progress bar (`LinearProgressIndicator`, value = currentProgress/targetCount, color #4F46E5, track #E5E7EB, 8px height, 4px border radius via `ClipRRect`), progress text ("X/20 items", 14px, #4B5563), time remaining ("Y days left", 12px, #F97316 if < 2 days, #6B7280 otherwise), reward text ("Unlock 1 month Premium free", 12px, #10B981).
    - **Completed state:** Green background (#F0FDF4), checkmark icon (Icons.check_circle, #10B981), "Closet Safari Complete!" title, "Premium unlocked for 30 days" subtitle.
    - **Expired state:** Gray background (#F9FAFB), clock icon (Icons.timer_off, #9CA3AF), "Challenge Expired" title, gray text.
    - **Not accepted state (if onAccept provided):** Show description and "Accept Challenge" `FilledButton` (#4F46E5).
  - [x] 10.3: Add `Semantics` label: "Challenge: [name], progress [X] of [Y] items".

- [x] Task 11: Mobile -- Create ChallengeCompletionModal widget (AC: 7)
  - [x] 11.1: Create `apps/mobile/lib/src/features/profile/widgets/challenge_completion_modal.dart` with a `ChallengeCompletionModal` StatelessWidget. Constructor accepts: `required String challengeName`, `required String rewardDescription`, `String? trialExpiresAt`.
  - [x] 11.2: The modal renders as an `AlertDialog` with: a trophy/confetti icon (Icons.emoji_events, 64px, #FBBF24 gold), "Closet Safari Complete!" title (20px, bold, #1F2937), "You've unlocked 1 month of Premium!" body (16px, #4B5563), "Your Premium trial expires on [formatted date]" subtitle (14px, #9CA3AF), and a "Continue" `FilledButton` to dismiss. Scale-in animation via `showGeneralDialog` with `ScaleTransition`. Haptic feedback via `HapticFeedback.heavyImpact()` when shown.
  - [x] 11.3: Add `Semantics` label: "Congratulations! Closet Safari complete. Premium unlocked for 30 days."
  - [x] 11.4: Create a top-level function `void showChallengeCompletionModal(BuildContext context, { required String challengeName, required String rewardDescription, String? trialExpiresAt })` that shows the dialog via `showGeneralDialog`.

- [x] Task 12: Mobile -- Create ChallengeBanner widget for Home screen (AC: 11)
  - [x] 12.1: Create `apps/mobile/lib/src/features/home/widgets/challenge_banner.dart` with a `ChallengeBanner` StatelessWidget. Constructor accepts: `required String name`, `required int currentProgress`, `required int targetCount`, `int? timeRemainingSeconds`, `VoidCallback? onTap`.
  - [x] 12.2: The banner renders as a compact `GestureDetector` with `Container` (gradient background #4F46E5 to #6366F1, 8px border radius, 12px horizontal padding, 8px vertical padding) containing a `Row`: challenge icon (Icons.explore, 16px, white), "Closet Safari: X/20 -- Y days left" text (13px, white), a small `LinearProgressIndicator` (value = currentProgress/targetCount, color white, track white30, 4px height). The banner is tappable (calls `onTap`).
  - [x] 12.3: Add `Semantics` label: "Closet Safari challenge: [X] of [Y] items, [Z] days remaining".

- [x] Task 13: Mobile -- Integrate ChallengeProgressCard into ProfileScreen (AC: 10)
  - [x] 13.1: In `apps/mobile/lib/src/features/profile/screens/profile_screen.dart`, add state for `_challengeData` (Map or null). In `_loadUserStats()`, extract the `challenge` field from the user stats response and store in `_challengeData`.
  - [x] 13.2: In the profile screen body, between the `GamificationHeader` and the badge collection grid, conditionally render `ChallengeProgressCard` when `_challengeData` is non-null. Pass the challenge data and an `onAccept` callback (if status indicates not-yet-accepted, but typically challenge is accepted from onboarding). If `_challengeData` is null, show nothing (no card).
  - [x] 13.3: Handle the "Accept Challenge" action by calling `apiClient.acceptChallenge("closet_safari")`, then reload stats.

- [x] Task 14: Mobile -- Integrate ChallengeBanner into HomeScreen (AC: 11)
  - [x] 14.1: In the Home screen widget (`apps/mobile/lib/src/features/home/screens/home_screen.dart`), load user stats on init (or receive challenge data from parent). If `challenge` is non-null and status is "active", render `ChallengeBanner` below the weather widget. Pass `onTap` to navigate to the Profile tab (or scroll to challenge section).
  - [x] 14.2: If the challenge is completed or expired, do not show the banner on the Home screen.

- [x] Task 15: Mobile -- Integrate challenge completion modal into item upload flow (AC: 7)
  - [x] 15.1: In `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`, after the existing points toast, level-up modal, and badge modal handling, check if the response contains `challengeUpdate` and `challengeUpdate.completed == true`. If so, call `showChallengeCompletionModal(context, challengeName: "Closet Safari", rewardDescription: "1 month Premium free", trialExpiresAt: ...)` with a 1000ms delay after the badge modal (or after the level-up modal if no badges). Guard with `mounted` check.

- [x] Task 16: Mobile -- Integrate challenge acceptance into onboarding (AC: 3)
  - [x] 16.1: In the onboarding flow (`apps/mobile/lib/src/features/onboarding/onboarding_flow.dart`), after the "First 5 Items" challenge screen completes, add a step or a prompt that presents the Closet Safari challenge: "Keep going! Upload 15 more items in 7 days to unlock Premium free." Call `apiClient.acceptChallenge("closet_safari")` if the user accepts. If the user skips, do not create the challenge row. This is a lightweight addition to the existing onboarding flow, not a full new screen.
  - [x] 16.2: Alternative: Auto-accept the Closet Safari challenge when onboarding completes (since the user has already shown intent by adding 5 items). The acceptance call fires in the background. This is the recommended approach for maximizing challenge participation.

- [x] Task 17: Mobile -- Widget tests for ChallengeProgressCard (AC: 3, 10, 12)
  - [x] 17.1: Create `apps/mobile/test/features/profile/widgets/challenge_progress_card_test.dart`:
    - Renders challenge name and progress text.
    - Renders progress bar with correct value.
    - Renders time remaining text.
    - Shows "Accept Challenge" button when onAccept provided and status is not accepted.
    - Shows completed state with green styling.
    - Shows expired state with gray styling.
    - Renders reward description.
    - Semantics label present.

- [x] Task 18: Mobile -- Widget tests for ChallengeCompletionModal (AC: 7, 12)
  - [x] 18.1: Create `apps/mobile/test/features/profile/widgets/challenge_completion_modal_test.dart`:
    - Renders trophy icon, title, reward description.
    - Renders trial expiry date when provided.
    - Renders "Continue" button.
    - Tapping "Continue" dismisses dialog.
    - Semantics label present.

- [x] Task 19: Mobile -- Widget tests for ChallengeBanner (AC: 11, 12)
  - [x] 19.1: Create `apps/mobile/test/features/home/widgets/challenge_banner_test.dart`:
    - Renders challenge name and progress text.
    - Renders compact progress bar.
    - Renders time remaining.
    - Tapping fires onTap callback.
    - Semantics label present.

- [x] Task 20: Mobile -- Integration tests for challenge in ProfileScreen (AC: 10, 12)
  - [x] 20.1: Update `apps/mobile/test/features/profile/screens/profile_screen_test.dart`:
    - ChallengeProgressCard renders when challenge data present in stats.
    - No challenge card when challenge is null.
    - Completed challenge card shows green state.

- [x] Task 21: Mobile -- Integration tests for challenge modal in item flow (AC: 7, 12)
  - [x] 21.1: Update `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`:
    - After item creation with challengeUpdate.completed=true, completion modal is displayed.
    - No modal when challengeUpdate is null.
    - No modal when challengeUpdate.completed is false.

- [x] Task 22: Regression testing (AC: all)
  - [x] 22.1: Run `flutter analyze` -- zero new issues.
  - [x] 22.2: Run `flutter test` -- all existing 1022+ Flutter tests plus new tests pass.
  - [x] 22.3: Run `npm --prefix apps/api test` -- all existing 554+ API tests plus new tests pass.
  - [x] 22.4: Verify existing `POST /v1/items` tests still pass with the added `challengeUpdate` field.
  - [x] 22.5: Verify existing `GET /v1/user-stats` tests still pass with added `challenge` field.
  - [x] 22.6: Verify existing premium-gated endpoint tests still pass with trial expiry check added.
  - [x] 22.7: Apply migration 020_challenges.sql and verify tables, seed data, and RPC functions work correctly.

## Dev Notes

- This is the **fifth and final story in Epic 6** (Gamification & Engagement). It builds on all previous Epic 6 stories (6.1 points, 6.2 levels, 6.3 streaks, 6.4 badges) to add the Closet Safari challenge and premium trial reward system.
- This story implements **FR-ONB-03**: "The system shall present a 'Closet Safari' 7-day challenge: upload 20 items to unlock 1 month Premium free."
- This story implements **FR-ONB-04**: "Completing the Closet Safari challenge shall automatically grant a 30-day Premium trial."
- **The premium trial is granted via server-side atomic RPC.** The architecture mandates "atomic RPCs for... premium trial grants" and "server authority for sensitive rules: subscription gating... enforced server-side." The `grant_premium_trial` RPC sets both `is_premium = true` and `premium_trial_expires_at` atomically.
- **Trial expiry is lazy, not cron-based.** There is no background job to expire trials. Instead, `check_trial_expiry` is called lazily on premium-gated API endpoints. This is consistent with the architecture principle of keeping the system simple (no cron jobs or background workers in MVP).
- **Challenge progress piggybacks on `POST /v1/items`.** No separate "increment progress" endpoint is needed. The item creation endpoint already triggers points (Story 6.1), levels (Story 6.2), and badges (Story 6.4). Adding challenge progress follows the same best-effort pattern.
- **The `challenges` table is designed for future extensibility.** Only the Closet Safari challenge exists now, but the table structure supports adding new challenges via migration. The `reward_type` and `reward_value` columns generalize the reward system.
- **The `user_challenges` table uses UNIQUE(profile_id, challenge_id).** A user can only have one entry per challenge. The `acceptChallenge` endpoint is idempotent due to `ON CONFLICT DO NOTHING`.
- **Challenge acceptance sets `current_progress` to the user's current item count.** If a user already has 5 items from onboarding when they accept the challenge, `current_progress` starts at 5 (they need 15 more). This is fair and prevents gaming the system by delaying acceptance.
- **The `POST /v1/items` response grows again.** After this story: `POST /v1/items` returns `{ item, pointsAwarded, levelUp, badgesAwarded, challengeUpdate }`. All new fields are additive and nullable -- backward-compatible.
- **The `premium_trial_expires_at` column on `profiles` is separate from RevenueCat.** RevenueCat integration (Story 7.1) manages paid subscriptions. The trial is an in-app reward that sets `is_premium = true` directly in the database. When RevenueCat is integrated in Story 7.1, it will reconcile: if a user has both a trial AND a paid subscription, RevenueCat takes precedence. For now, the trial mechanism is self-contained.
- **The existing `is_premium` column (migration 014) is reused.** No new premium columns are needed beyond `premium_trial_expires_at`. The `is_premium` boolean remains the single source of truth for premium status. Trial expiry simply flips it to `false`.

### Design Decision: Challenge Repository in gamification/ Module

The challenge repository and service go in `apps/api/src/modules/gamification/`, not a new `challenges/` module. Challenges are part of the gamification system (points, levels, streaks, badges, challenges). The architecture maps Epic 6 to `api/modules/gamification` and `api/modules/badges`. Challenges are closer to gamification (progression mechanics) than to badges (achievement recognition).

### Design Decision: Lazy Trial Expiry

Trial expiry is checked lazily (on API call) rather than via a scheduled job because:
1. No cron/scheduler infrastructure exists in the MVP architecture.
2. Lazy checking is sufficient -- a user whose trial expired but hasn't called a premium endpoint yet gets downgraded on their next premium request.
3. The `check_trial_expiry` RPC is cheap (single row update with index lookup).
4. Story 7.1 (RevenueCat) will introduce proper subscription lifecycle management. The trial expiry mechanism bridges until then.

### Design Decision: Auto-Accept Closet Safari on Onboarding Completion

Rather than requiring explicit "Accept Challenge" interaction, the recommended implementation is to auto-accept the Closet Safari challenge when onboarding completes. The user has already demonstrated intent by completing the "First 5 Items" flow. Auto-accepting maximizes participation. The user can see their progress on the Profile screen and Home banner.

### Design Decision: Challenge Completion Celebration Ordering

Challenge completion is the most significant reward event in the app (free Premium). The modal appears LAST in the celebration sequence: points toast -> streak toast (500ms) -> level-up modal (500ms) -> badge modals (1000ms) -> challenge completion modal (1000ms). This builds anticipation and ensures the user sees all rewards.

### Project Structure Notes

- New SQL migration file:
  - `infra/sql/migrations/020_challenges.sql` (challenges table, user_challenges table, seed data, grant_premium_trial RPC, check_trial_expiry RPC, increment_challenge_progress RPC, profiles.premium_trial_expires_at column)
- New API files:
  - `apps/api/src/modules/gamification/challenge-repository.js` (data access for challenges and user_challenges)
  - `apps/api/src/modules/gamification/challenge-service.js` (challenge logic, trial management)
  - `apps/api/test/modules/gamification/challenge-repository.test.js`
  - `apps/api/test/modules/gamification/challenge-service.test.js`
  - `apps/api/test/modules/gamification/challenge-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/profile/widgets/challenge_progress_card.dart` (challenge progress card for profile)
  - `apps/mobile/lib/src/features/profile/widgets/challenge_completion_modal.dart` (celebration modal)
  - `apps/mobile/lib/src/features/home/widgets/challenge_banner.dart` (compact home banner)
  - `apps/mobile/test/features/profile/widgets/challenge_progress_card_test.dart`
  - `apps/mobile/test/features/profile/widgets/challenge_completion_modal_test.dart`
  - `apps/mobile/test/features/home/widgets/challenge_banner_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add challengeRepo, challengeService to createRuntime, handleRequest; add POST /v1/challenges/:key/accept route; integrate challenge progress into POST /v1/items; add challenge to GET /v1/user-stats; add trial expiry check to premium-gated routes)
  - `apps/api/test/modules/gamification/gamification-endpoints.test.js` (add challengeService mock, verify challenge field in user-stats)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add acceptChallenge method)
  - `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (add ChallengeProgressCard, challenge state)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add ChallengeBanner for active challenges)
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (add challenge completion modal)
  - `apps/mobile/lib/src/features/onboarding/onboarding_flow.dart` (auto-accept Closet Safari on completion)
  - `apps/mobile/test/features/profile/screens/profile_screen_test.dart` (add challenge card tests)
  - `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart` (add challenge modal tests)
- Directory structure after this story:
  ```
  apps/api/src/modules/gamification/
  ├── user-stats-repository.js (unchanged)
  ├── style-points-service.js (unchanged)
  ├── level-service.js (unchanged)
  ├── streak-service.js (unchanged)
  ├── challenge-repository.js (NEW)
  └── challenge-service.js (NEW)

  apps/api/test/modules/gamification/
  ├── user-stats-repository.test.js (unchanged)
  ├── style-points-service.test.js (unchanged)
  ├── level-service.test.js (unchanged)
  ├── level-endpoints.test.js (unchanged)
  ├── streak-service.test.js (unchanged)
  ├── streak-endpoints.test.js (unchanged)
  ├── gamification-endpoints.test.js (MODIFIED)
  ├── challenge-repository.test.js (NEW)
  ├── challenge-service.test.js (NEW)
  └── challenge-endpoints.test.js (NEW)

  apps/mobile/lib/src/features/profile/widgets/
  ├── gamification_header.dart (unchanged)
  ├── level_up_modal.dart (unchanged)
  ├── streak_celebration_toast.dart (unchanged)
  ├── streak_detail_sheet.dart (unchanged)
  ├── badge_collection_grid.dart (unchanged)
  ├── badge_detail_sheet.dart (unchanged)
  ├── badge_awarded_modal.dart (unchanged)
  ├── challenge_progress_card.dart (NEW)
  └── challenge_completion_modal.dart (NEW)

  apps/mobile/lib/src/features/home/widgets/
  └── challenge_banner.dart (NEW)
  ```

### Technical Requirements

- **Database table `challenges`:** Public catalog of challenge definitions. RLS allows all authenticated users to SELECT. 1 seed record (Closet Safari). Extensible for future challenges.
- **Database table `user_challenges`:** Tracks per-user challenge state. RLS allows users to SELECT/UPDATE their own rows. UNIQUE(profile_id, challenge_id) prevents duplicate entries. Status CHECK constraint enforces valid states.
- **Database column `profiles.premium_trial_expires_at`:** Nullable TIMESTAMPTZ. NULL = no active trial. Non-null + future = active trial. Non-null + past = expired (cleaned up lazily).
- **Database RPC `grant_premium_trial`:** Atomically sets `is_premium = true` and `premium_trial_expires_at`. Follows architecture principle: "atomic RPCs for... premium trial grants."
- **Database RPC `check_trial_expiry`:** Lazily downgrades expired trials. Called before premium-gated operations.
- **Database RPC `increment_challenge_progress`:** Atomically increments progress, checks completion, grants reward if complete. Single database call for the entire flow.
- **RLS pattern:** Identical to existing tables. `user_challenges` uses `profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id'))`. `challenges` allows all authenticated SELECT.
- **Repository pattern:** Factory function `createChallengeRepository({ pool })` returning an object with async methods. Uses `pool.connect()` -> `set_config` -> query -> `client.release()` in try/finally. Maps snake_case to camelCase.
- **Service pattern:** Factory function `createChallengeService({ challengeRepo, pool })` accepting repository and pool dependencies. Contains business logic. Uses pool directly only for the trial expiry RPC.
- **API response extensions:** `POST /v1/items` gains `challengeUpdate` object. `GET /v1/user-stats` gains `challenge` object. `POST /v1/challenges/:key/accept` is a new endpoint. All additive and backward-compatible.
- **URL path parsing:** `POST /v1/challenges/:key/accept` requires extracting `challengeKey` from the URL path. Use the same pattern as other parameterized routes in main.js (regex or string split on pathname).
- **Modal celebration:** Challenge completion is the most significant gamification event. Uses `showGeneralDialog` with `ScaleTransition` and `HapticFeedback.heavyImpact()` (heavier than level-up's medium impact). Appears last in the celebration sequence.

### Architecture Compliance

- **Server authority for gamification:** Challenge progress, completion, and premium trial grants happen server-side via database RPCs. The mobile client does not compute challenge progress or grant premium status.
- **Atomic RPCs:** Challenge completion + premium grant uses a database function for transactional consistency. Follows: "atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments."
- **RLS enforces data isolation:** Users can only read/modify their own `user_challenges` rows. Challenge definitions are a public catalog.
- **Premium gating server-side:** The `is_premium` flag is set server-side by the RPC. The mobile client does not flip `is_premium`. This follows: "Server authority for sensitive rules: subscription gating... enforced server-side."
- **Mobile boundary owns presentation:** The API returns challenge state. The client handles progress cards, banners, modals, animation, and haptic feedback.
- **API module placement:** Challenge services go in `apps/api/src/modules/gamification/` alongside existing gamification services.
- **JSON REST over HTTPS:** New endpoint follows existing API naming conventions.
- **Graceful degradation:** Challenge progress failure does not break core actions (item creation, stats fetching).
- **RevenueCat compatibility:** The trial mechanism is independent of RevenueCat. Story 7.1 will reconcile trial state with RevenueCat subscription state. No conflicts.

### Library / Framework Requirements

- No new dependencies for mobile or API.
- Mobile uses existing: `flutter/material.dart` (AlertDialog, LinearProgressIndicator, Container, Row, Icon, GestureDetector), `flutter/services.dart` (HapticFeedback).
- API uses existing: `pg` (via `pool`).

### File Structure Requirements

- New API files in existing `apps/api/src/modules/gamification/` directory (created in Story 6.1).
- New API test files in existing `apps/api/test/modules/gamification/` directory.
- New mobile widgets in existing `apps/mobile/lib/src/features/profile/widgets/` (created in Story 6.2).
- New mobile widget in `apps/mobile/lib/src/features/home/widgets/` (may need to create `widgets/` subdirectory if it doesn't exist).
- Test files mirror source structure.

### Testing Requirements

- **Database migration tests** must verify:
  - `challenges` table created with Closet Safari seed record
  - `user_challenges` table created with correct constraints (UNIQUE, FK cascade, status CHECK)
  - RLS on `user_challenges` prevents cross-user access
  - RLS on `challenges` allows all authenticated users to read
  - `profiles.premium_trial_expires_at` column added
  - `grant_premium_trial` RPC sets is_premium and premium_trial_expires_at correctly
  - `check_trial_expiry` RPC downgrades expired trial
  - `check_trial_expiry` RPC is no-op for non-trial premium users
  - `increment_challenge_progress` RPC increments progress
  - `increment_challenge_progress` RPC completes challenge at target
  - `increment_challenge_progress` RPC grants premium on completion
  - `increment_challenge_progress` RPC expires stale challenges
  - `increment_challenge_progress` RPC returns null for no active challenge
- **API repository tests** must verify:
  - `getChallenge` returns closet_safari definition
  - `getUserChallenge` returns correct state
  - `acceptChallenge` creates row with correct fields (including current item count)
  - `acceptChallenge` is idempotent
  - `incrementProgress` increments and detects completion
  - RLS isolation between users
- **API service tests** must verify:
  - `acceptChallenge` returns challenge state
  - `updateProgressOnItemCreate` returns correct update
  - `getChallengeStatus` expires stale challenges
  - `checkTrialExpiry` calls RPC correctly
- **API endpoint tests** must verify:
  - `POST /v1/challenges/closet_safari/accept` returns challenge state
  - `POST /v1/items` includes `challengeUpdate` when active challenge
  - `GET /v1/user-stats` includes `challenge` object
  - Challenge completion grants premium
  - Trial expiry downgrades premium
  - Challenge failure does not break primary actions
- **Mobile widget tests** must verify:
  - ChallengeProgressCard renders all states (active, completed, expired, not-accepted)
  - ChallengeCompletionModal renders icon, title, reward, dismiss button
  - ChallengeBanner renders compact progress view
  - ProfileScreen shows challenge card when data present
  - Challenge modal appears in item upload flow when challenge completes
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1022+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 554+ tests plus new tests pass)
  - Existing endpoint tests still pass with new additive fields

### Previous Story Intelligence

- **Story 6.4** (done) established: Migration 019 (badges table, user_badges table, evaluate_badges RPC), `badge-repository.js` in `api/modules/badges/`, `badge-service.js`, BadgeCollectionGrid, BadgeDetailSheet, BadgeAwardedModal. `createRuntime()` returns 24 services (includes `userStatsRepo`, `stylePointsService`, `levelService`, `streakService`, `badgeRepo`, `badgeService`). Test counts: 554 API tests, 1022 Flutter tests. `POST /v1/items` returns `{ item, pointsAwarded, levelUp, badgesAwarded }`. `POST /v1/wear-logs` returns `{ wearLog, pointsAwarded, streakUpdate, badgesAwarded }`. `GET /v1/user-stats` returns `{ stats: { totalPoints, currentStreak, longestStreak, lastStreakDate, streakFreezeUsedAt, streakFreezeAvailable, currentLevel, currentLevelName, nextLevelThreshold, itemCount, badges: [...], badgeCount } }`.
- **Story 6.3** (done) established: Migration 018 (evaluate_streak RPC), `streak-service.js`, `StreakCelebrationToast`, `StreakDetailSheet`. Toast sequencing pattern: points toast -> streak toast (500ms delay).
- **Story 6.2** (done) established: Migration 017 (level columns + recalculate_user_level RPC), `level-service.js`, `ProfileScreen`, `GamificationHeader`, `LevelUpModal`. Modal sequencing: points toast -> level-up modal (500ms delay).
- **Story 6.1** (done) established: Migration 016 (`user_stats` table), `user-stats-repository.js`, `style-points-service.js`, `StylePointsToast`, `GET /v1/user-stats`, `api/modules/gamification/` directory. Explicitly stated "Challenge Rewards / Closet Safari Premium Trial (FR-ONB-03, FR-ONB-04): Story 6.5."
- **Story 4.5** (done) established: `profiles.is_premium` column (migration 014), `createUsageLimitService`, premium gating pattern. The `usageLimitService.checkAndLog()` reads `is_premium` from the profiles table. This story's trial expiry check must update `is_premium` BEFORE `checkAndLog` runs.
- **Story 1.5** (done) established: Onboarding flow (`onboarding_flow.dart`), "First 5 Items" challenge screen, `onboarding_completed_at` profile column, `OnboardingProfileScreen`, `OnboardingPhotoScreen`, `FirstFiveItemsScreen`. The onboarding flow completes at step 3 (first-5-items). The Closet Safari challenge auto-acceptance should fire when onboarding completes. FR-ONB-03/FR-ONB-04 were explicitly noted as out of scope: "FR-ONB-03 (Closet Safari 7-day challenge) and FR-ONB-04 (Premium trial grant) are NOT in scope for this story. They belong to Epic 6."
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Factory pattern for repositories and services.
  - Database RPC functions for atomic operations.
  - Toast/modal sequencing with delays: points -> streak (500ms) -> level-up (500ms) -> badges (1000ms) -> challenge completion (1000ms).
  - Best-effort gamification (try/catch, does not break primary action).
  - `POST /v1/items` response pattern: `{ item, pointsAwarded, levelUp, badgesAwarded }` -- this story adds `challengeUpdate`.

### Key Anti-Patterns to Avoid

- DO NOT compute challenge progress client-side. All progress tracking and completion detection happen server-side in the `increment_challenge_progress` RPC.
- DO NOT make challenge progress blocking. If challenge progress fails, the primary action (item creation) must still succeed. Wrap in try/catch and log errors.
- DO NOT grant premium trial client-side. The `grant_premium_trial` RPC is the only mechanism for setting `is_premium = true` for trial rewards. The mobile client NEVER sets `is_premium`.
- DO NOT use a cron job for trial expiry. Use lazy checking via `check_trial_expiry` on premium-gated endpoints.
- DO NOT create a separate `challenges/` API module. Challenge code goes in `api/modules/gamification/`.
- DO NOT hardcode challenge definitions in the API or mobile client. Challenge definitions live in the `challenges` database table.
- DO NOT allow `user_challenges` to have duplicate (profile_id, challenge_id) pairs. The UNIQUE constraint and `ON CONFLICT DO NOTHING` prevent this.
- DO NOT modify the existing `usageLimitService` or `analyticsSummaryService` premium check logic. Only ensure `is_premium` is accurate by calling `check_trial_expiry` BEFORE those services run.
- DO NOT remove or modify any existing gamification code (points, levels, streaks, badges). Challenge progress is additive.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT modify existing API test expectations to require the new fields (`challengeUpdate`, `challenge`). Existing tests should continue to pass -- new fields are additive.
- DO NOT create an endpoint to manually grant premium. Premium is only granted as a challenge reward via the atomic RPC.
- DO NOT show the challenge completion modal for non-completed challenges. Only show when `challengeUpdate.completed = true`.
- DO NOT conflict with RevenueCat. The trial uses `profiles.is_premium` directly. Story 7.1 will reconcile RevenueCat subscription state with this column. No RevenueCat SDK calls are made in this story.

### Out of Scope

- **RevenueCat integration for trial management:** Story 7.1 will handle RevenueCat webhooks and reconcile subscription state with `is_premium`. This story uses the database column directly.
- **Multiple challenges:** Only the Closet Safari challenge is implemented. The `challenges` table supports future challenges but no UI for browsing multiple challenges is built.
- **Challenge push notifications:** FR-ONB-03 does not specify push notifications for challenge progress. The in-app banner and profile card provide visibility.
- **Challenge expiry push notification:** No notification when the challenge expires. The user sees the expired state in-app.
- **Extending onboarding with a full Closet Safari screen:** The onboarding flow gets a lightweight auto-accept addition, not a new full screen. Users see challenge progress on the Profile tab and Home banner.
- **Trial period warnings:** No "3 days left" warning for the premium trial. This could be added as a future enhancement.
- **Retroactive challenge progress for existing users:** Users who already have 20+ items do not automatically complete the challenge. They must accept it first, and progress starts from their current item count at acceptance time.
- **Dark mode for challenge widgets:** Follow existing app convention (light mode only for MVP).
- **Rive animations for challenge completion:** Standard Material scale-in animation suffices for V1.

### References

- [Source: epics.md - Story 6.5: Challenge Rewards (Premium Trial)]
- [Source: epics.md - FR-ONB-03: The system shall present a "Closet Safari" 7-day challenge: upload 20 items to unlock 1 month Premium free]
- [Source: epics.md - FR-ONB-04: Completing the Closet Safari challenge shall automatically grant a 30-day Premium trial]
- [Source: prd.md - Closet Safari challenge completion: >= 20% of new users complete the 20-items-in-7-days challenge]
- [Source: prd.md - Trial: 30-day free Premium via "Closet Safari" challenge completion]
- [Source: prd.md - Billing provider: RevenueCat (manages App Store + Play Store subscriptions)]
- [Source: prd.md - Marcus persona: Day 6 hits 23 items, app celebrates with confetti, unlocks Premium for 30 days]
- [Source: architecture.md - Database rules: atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments]
- [Source: architecture.md - Server authority for sensitive rules: subscription gating enforced server-side]
- [Source: architecture.md - Subscription and Premium Gating: RevenueCat acts as subscription state source; Cloud Run persists an internal entitlement view]
- [Source: architecture.md - Gated features include outfit generation quotas, shopping scans, resale listing generation, advanced analytics, and premium trial unlocks]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Epic 6 Gamification -> mobile/features/profile, api/modules/gamification]
- [Source: ux-design-specification.md - Positive Reinforcement (The "Streak" Pattern): haptic vibration + floating snackbar overlay]
- [Source: ux-design-specification.md - Accomplishment: Use gamification during onboarding and for wear-logging]
- [Source: 6-4-badge-achievement-system.md - 554 API tests, 1022 Flutter tests, POST /v1/items returns { item, pointsAwarded, levelUp, badgesAwarded }]
- [Source: 6-1-style-points-rewards.md - "Challenge Rewards / Closet Safari Premium Trial (FR-ONB-03, FR-ONB-04): Story 6.5"]
- [Source: 4-5-ai-usage-limits-enforcement.md - profiles.is_premium column (migration 014), usageLimitService premium checks]
- [Source: 1-5-onboarding-profile-setup-first-5-items.md - Onboarding flow, First 5 Items challenge, "FR-ONB-03/FR-ONB-04 belong to Epic 6"]
- [Source: infra/sql/migrations/014_profiles_is_premium.sql - is_premium column, existing premium infrastructure]
- [Source: infra/sql/migrations/019_badges.sql - last migration number, 020 is next available]
- [Source: apps/api/src/main.js - createRuntime with 24 services, handleRequest destructuring pattern]
- [Source: apps/mobile/lib/src/core/subscription/subscription_service.dart - SubscriptionService wraps RevenueCat SDK, proEntitlementId]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None.

### Completion Notes List

- Implemented migration 020_challenges.sql with challenges table, user_challenges table, Closet Safari seed data, profiles.premium_trial_expires_at column, and 3 RPC functions (grant_premium_trial, check_trial_expiry, increment_challenge_progress).
- Created challenge-repository.js with 5 methods: getChallenge, getUserChallenge, acceptChallenge, incrementProgress, expireChallengeIfNeeded.
- Created challenge-service.js with 4 methods: acceptChallenge, updateProgressOnItemCreate, getChallengeStatus, checkTrialExpiry.
- Integrated challenge system into main.js: new POST /v1/challenges/:key/accept endpoint, challengeUpdate in POST /v1/items, challenge in GET /v1/user-stats, trial expiry checks in POST /v1/outfits/generate and GET /v1/analytics/ai-summary.
- Created ChallengeProgressCard widget with active/completed/expired/not-accepted states.
- Created ChallengeCompletionModal widget with scale-in animation and haptic feedback.
- Created ChallengeBanner widget for Home screen with gradient styling.
- Integrated challenge card into ProfileScreen between GamificationHeader and badge grid.
- Integrated challenge banner into HomeScreen below weather widget (active challenges only).
- Integrated challenge completion modal into AddItemScreen item upload flow.
- Added onChallengeAutoAccept callback to OnboardingFlow for auto-accepting Closet Safari on onboarding completion.
- All challenge operations are best-effort (wrapped in try/catch) -- never break primary actions.
- All 594 API tests pass (554 existing + 40 new). All 1046 Flutter tests pass (1022 existing + 24 new).
- flutter analyze: 0 new issues (5 pre-existing warnings in unrelated files).

### Change Log

- 2026-03-19: Implemented Story 6.5 - Challenge Rewards (Premium Trial). Added challenges table, user_challenges table, Closet Safari challenge, premium trial system, 3 database RPCs, challenge repository/service, new API endpoint, mobile widgets (ChallengeProgressCard, ChallengeCompletionModal, ChallengeBanner), and integrated into ProfileScreen, HomeScreen, AddItemScreen, and OnboardingFlow. 40 new API tests, 24 new Flutter tests.

### File List

New files:
- infra/sql/migrations/020_challenges.sql
- apps/api/src/modules/gamification/challenge-repository.js
- apps/api/src/modules/gamification/challenge-service.js
- apps/api/test/modules/gamification/challenge-repository.test.js
- apps/api/test/modules/gamification/challenge-service.test.js
- apps/api/test/modules/gamification/challenge-endpoints.test.js
- apps/mobile/lib/src/features/profile/widgets/challenge_progress_card.dart
- apps/mobile/lib/src/features/profile/widgets/challenge_completion_modal.dart
- apps/mobile/lib/src/features/home/widgets/challenge_banner.dart
- apps/mobile/test/features/profile/widgets/challenge_progress_card_test.dart
- apps/mobile/test/features/profile/widgets/challenge_completion_modal_test.dart
- apps/mobile/test/features/home/widgets/challenge_banner_test.dart

Modified files:
- apps/api/src/main.js
- apps/api/test/modules/gamification/gamification-endpoints.test.js
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/profile/screens/profile_screen.dart
- apps/mobile/lib/src/features/home/screens/home_screen.dart
- apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart
- apps/mobile/lib/src/features/onboarding/onboarding_flow.dart
- apps/mobile/test/features/profile/screens/profile_screen_test.dart
- apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart
