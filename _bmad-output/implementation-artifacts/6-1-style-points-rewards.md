# Story 6.1: Style Points Rewards

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to earn points for sustainable wardrobe actions (uploading items, logging outfits, maintaining streaks),
so that my progress feels immediate and motivating, encouraging daily engagement with my wardrobe.

## Acceptance Criteria

1. Given a user uploads a new wardrobe item via `POST /v1/items`, when the item is successfully created (201 response), then +10 style points are atomically added to the user's `user_stats.total_points` server-side. The mobile client receives the points awarded in the API response and displays a brief animated toast showing "+10 Style Points". (FR-GAM-01)

2. Given a user logs an outfit via `POST /v1/wear-logs`, when the wear log is successfully created (201 response), then +5 style points are atomically added to the user's `user_stats.total_points` server-side. The mobile client receives the points awarded in the API response and displays a brief animated toast showing "+5 Style Points". (FR-GAM-01)

3. Given a user has an active streak (consecutive days logging outfits), when a wear log is created on a new streak day (the user already logged today but this is a streak continuation from yesterday), then +3 bonus streak points are added in addition to the +5 log points. The toast shows the combined points earned (e.g., "+8 Style Points"). (FR-GAM-01)

4. Given a user creates their first wear log of the day, when the wear log is successfully created, then +2 bonus "first log of day" points are added in addition to the +5 log points. If both first-log-of-day and streak bonuses apply, all bonuses stack (e.g., +5 base + +2 first-log + +3 streak = +10 total). (FR-GAM-01)

5. Given the `user_stats` table does not yet exist, when migration 016 is applied, then the `app_public.user_stats` table is created with columns: `id UUID PK DEFAULT gen_random_uuid()`, `profile_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE`, `total_points INTEGER NOT NULL DEFAULT 0`, `current_streak INTEGER NOT NULL DEFAULT 0`, `longest_streak INTEGER NOT NULL DEFAULT 0`, `last_streak_date DATE`, `streak_freeze_used_at DATE`, `created_at TIMESTAMPTZ DEFAULT now()`, `updated_at TIMESTAMPTZ DEFAULT now()`. RLS is enabled, allowing users to read/update only their own row. An index exists on `profile_id`. (FR-GAM-01, FR-GAM-06)

6. Given a user earns points, when any point-granting action occurs, then the `user_stats` row is created automatically (upsert) if it does not yet exist for this user. The initial `total_points` starts at 0 and the awarded points are added atomically via a database RPC function `award_style_points(p_profile_id UUID, p_points INTEGER)` that uses `INSERT ... ON CONFLICT (profile_id) DO UPDATE SET total_points = user_stats.total_points + p_points, updated_at = now()`. (FR-GAM-01, FR-GAM-06)

7. Given a user wants to see their total points, when a `GET /v1/user-stats` endpoint is called, then the API returns `{ totalPoints, currentStreak, longestStreak, lastStreakDate, streakFreezeUsedAt }`. If no `user_stats` row exists yet, the API returns default values (all zeros/nulls). (FR-GAM-01, FR-GAM-05)

8. Given points are awarded, when the mobile client displays the toast animation, then the toast appears as a floating snackbar at the bottom of the screen with: a sparkle icon (Icons.auto_awesome, #4F46E5), the points text ("+N Style Points", 14px bold, white), on a dark semi-transparent background (#1F2937 at 90% opacity), with 12px border radius. The toast auto-dismisses after 2 seconds with a fade-out animation. Haptic feedback (light impact) fires when points are awarded. (FR-GAM-01, UX-spec: positive reinforcement pattern)

9. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (441+ API tests, 939+ Flutter tests) and new tests cover: user_stats migration, award_style_points RPC function, points awarded on item creation, points awarded on wear log creation, streak bonus calculation, first-log-of-day bonus calculation, GET /v1/user-stats endpoint, mobile StylePointsToast widget, integration of toast into item upload and wear log flows.

## Tasks / Subtasks

- [x] Task 1: Database - Create user_stats table migration (AC: 5, 6)
  - [x] 1.1: Create `infra/sql/migrations/016_user_stats.sql`. Create table `app_public.user_stats` with columns: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `profile_id UUID NOT NULL UNIQUE REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `total_points INTEGER NOT NULL DEFAULT 0`, `current_streak INTEGER NOT NULL DEFAULT 0`, `longest_streak INTEGER NOT NULL DEFAULT 0`, `last_streak_date DATE`, `streak_freeze_used_at DATE`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`. Add index: `CREATE INDEX idx_user_stats_profile ON app_public.user_stats(profile_id)`.
  - [x] 1.2: Enable RLS: `ALTER TABLE app_public.user_stats ENABLE ROW LEVEL SECURITY`. Create policy: `CREATE POLICY user_stats_isolation ON app_public.user_stats USING (profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id')))`. This follows the identical RLS pattern used on `items`, `wear_logs`, `outfits`.
  - [x] 1.3: Create RPC function `app_public.award_style_points(p_profile_id UUID, p_points INTEGER)` that performs an atomic upsert: `INSERT INTO app_public.user_stats (profile_id, total_points) VALUES (p_profile_id, p_points) ON CONFLICT (profile_id) DO UPDATE SET total_points = app_public.user_stats.total_points + EXCLUDED.total_points, updated_at = now() RETURNING total_points`. This ensures atomic point addition even under concurrent requests.
  - [x] 1.4: Create RPC function `app_public.award_points_with_streak(p_profile_id UUID, p_base_points INTEGER, p_is_first_log_today BOOLEAN, p_is_streak_day BOOLEAN)` that: (a) calculates total points = p_base_points + (2 if p_is_first_log_today) + (3 if p_is_streak_day), (b) upserts `user_stats` with total points, (c) if p_is_streak_day, updates `current_streak = current_streak + 1`, `longest_streak = GREATEST(longest_streak, current_streak + 1)`, `last_streak_date = CURRENT_DATE`, (d) returns `{ total_points, points_awarded, current_streak }`.

- [x] Task 2: API - Create user-stats repository (AC: 5, 6, 7)
  - [x] 2.1: Create `apps/api/src/modules/gamification/user-stats-repository.js` with `createUserStatsRepository({ pool })`. Follow the factory pattern used by all other repositories.
  - [x] 2.2: Implement `async getUserStats(authContext)` method. Query: `SELECT total_points, current_streak, longest_streak, last_streak_date, streak_freeze_used_at FROM app_public.user_stats WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)`. If no row found, return defaults: `{ totalPoints: 0, currentStreak: 0, longestStreak: 0, lastStreakDate: null, streakFreezeUsedAt: null }`. Map snake_case to camelCase.
  - [x] 2.3: Implement `async awardPoints(authContext, { points })` method. Look up `profile_id` from `profiles.firebase_uid`, then call `SELECT * FROM app_public.award_style_points($1, $2)` with `[profileId, points]`. Return `{ totalPoints: result.total_points, pointsAwarded: points }`.
  - [x] 2.4: Implement `async awardPointsWithStreak(authContext, { basePoints, isFirstLogToday, isStreakDay })` method. Look up `profile_id`, then call `SELECT * FROM app_public.award_points_with_streak($1, $2, $3, $4)` with `[profileId, basePoints, isFirstLogToday, isStreakDay]`. Return `{ totalPoints, pointsAwarded, currentStreak }`.
  - [x] 2.5: Implement `async checkFirstLogToday(authContext)` method. Query: `SELECT COUNT(*) AS log_count FROM app_public.wear_logs WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1) AND logged_date = CURRENT_DATE`. Return `logCount === 0` (true means this would be the first log today).
  - [x] 2.6: Implement `async checkStreakDay(authContext)` method. Query the user's `last_streak_date` from `user_stats`. If `last_streak_date = yesterday`, return `true` (streak continues). If `last_streak_date = today`, return `false` (already counted today). If `last_streak_date` is null or older than yesterday, return `false` (streak broken). Use `CURRENT_DATE - INTERVAL '1 day'` for yesterday comparison.

- [x] Task 3: API - Create style points service (AC: 1, 2, 3, 4, 6)
  - [x] 3.1: Create `apps/api/src/modules/gamification/style-points-service.js` with `createStylePointsService({ userStatsRepo })`. Follow the factory pattern.
  - [x] 3.2: Implement `async awardItemUploadPoints(authContext)` method. Calls `userStatsRepo.awardPoints(authContext, { points: 10 })`. Returns `{ pointsAwarded: 10, totalPoints, action: "item_upload" }`.
  - [x] 3.3: Implement `async awardWearLogPoints(authContext)` method. Steps: (a) call `userStatsRepo.checkFirstLogToday(authContext)` to determine if this is the first log today, (b) call `userStatsRepo.checkStreakDay(authContext)` to determine if this continues a streak, (c) call `userStatsRepo.awardPointsWithStreak(authContext, { basePoints: 5, isFirstLogToday, isStreakDay })`, (d) return `{ pointsAwarded, totalPoints, currentStreak, bonuses: { firstLogOfDay: isFirstLogToday ? 2 : 0, streakDay: isStreakDay ? 3 : 0 }, action: "wear_log" }`.

- [x] Task 4: API - Integrate points into existing endpoints (AC: 1, 2, 3, 4)
  - [x] 4.1: In `apps/api/src/main.js`, import `createUserStatsRepository` and `createStylePointsService`. In `createRuntime()`, instantiate `userStatsRepo = createUserStatsRepository({ pool })` and `stylePointsService = createStylePointsService({ userStatsRepo })`. Add both to the returned runtime object.
  - [x] 4.2: In `handleRequest`, add `userStatsRepo` and `stylePointsService` to the destructuring.
  - [x] 4.3: Modify the `POST /v1/items` route: after the successful `itemService.createItemForUser()` call and before `sendJson(res, 201, ...)`, call `const pointsResult = await stylePointsService.awardItemUploadPoints(authContext)`. Include `pointsResult` in the 201 response: `sendJson(res, 201, { item: result, pointsAwarded: pointsResult })`. Wrap in try/catch so points failure does NOT fail the item creation -- log the error and return the item without points data.
  - [x] 4.4: Modify the `POST /v1/wear-logs` route: after the successful `wearLogRepository.createWearLog()` call and before `sendJson(res, 201, ...)`, call `const pointsResult = await stylePointsService.awardWearLogPoints(authContext)`. Include `pointsResult` in the 201 response: `sendJson(res, 201, { wearLog: result, pointsAwarded: pointsResult })`. Wrap in try/catch so points failure does NOT fail the wear log creation.

- [x] Task 5: API - Add GET /v1/user-stats endpoint (AC: 7)
  - [x] 5.1: In `apps/api/src/main.js`, add route `GET /v1/user-stats`. Requires authentication (401 if unauthenticated). Calls `userStatsRepo.getUserStats(authContext)`. Returns 200 with `{ stats: { totalPoints, currentStreak, longestStreak, lastStreakDate, streakFreezeUsedAt } }`. Place after analytics routes and before `notFound`.

- [x] Task 6: API - Unit tests for user-stats repository (AC: 5, 6, 7, 9)
  - [x] 6.1: Create `apps/api/test/modules/gamification/user-stats-repository.test.js`:
    - `getUserStats` returns defaults when no user_stats row exists.
    - `getUserStats` returns correct stats when row exists.
    - `awardPoints` creates user_stats row if none exists (upsert).
    - `awardPoints` increments existing total_points atomically.
    - `awardPoints` returns updated totalPoints and pointsAwarded.
    - `awardPointsWithStreak` adds base + first-log + streak bonuses correctly.
    - `awardPointsWithStreak` updates current_streak and longest_streak.
    - `awardPointsWithStreak` sets last_streak_date to today.
    - `checkFirstLogToday` returns true when no wear logs exist for today.
    - `checkFirstLogToday` returns false when wear logs exist for today.
    - `checkStreakDay` returns true when last_streak_date is yesterday.
    - `checkStreakDay` returns false when last_streak_date is today (already counted).
    - `checkStreakDay` returns false when last_streak_date is older than yesterday (broken).
    - `checkStreakDay` returns false when no user_stats row exists.
    - RLS isolation: user A cannot read/modify user B's stats.

- [x] Task 7: API - Unit tests for style points service (AC: 1, 2, 3, 4, 9)
  - [x] 7.1: Create `apps/api/test/modules/gamification/style-points-service.test.js`:
    - `awardItemUploadPoints` calls awardPoints with 10 points.
    - `awardItemUploadPoints` returns pointsAwarded: 10 and action: "item_upload".
    - `awardWearLogPoints` awards 5 base points when no bonuses apply.
    - `awardWearLogPoints` awards 7 points when first-log-of-day bonus applies (+5 +2).
    - `awardWearLogPoints` awards 8 points when streak bonus applies (+5 +3).
    - `awardWearLogPoints` awards 10 points when both bonuses apply (+5 +2 +3).
    - `awardWearLogPoints` returns correct bonuses breakdown.
    - `awardWearLogPoints` returns currentStreak from repository.

- [x] Task 8: API - Integration tests for points and user-stats endpoints (AC: 1, 2, 3, 4, 7, 9)
  - [x] 8.1: Create `apps/api/test/modules/gamification/gamification-endpoints.test.js`:
    - `GET /v1/user-stats` returns 200 with default stats for new user.
    - `GET /v1/user-stats` returns 401 if unauthenticated.
    - `GET /v1/user-stats` returns correct stats after points have been awarded.
    - `POST /v1/items` response includes `pointsAwarded` with 10 points.
    - `POST /v1/wear-logs` response includes `pointsAwarded` with base + applicable bonuses.
    - Points are persisted: `GET /v1/user-stats` reflects cumulative points after multiple actions.
    - Points failure does not break item creation (item still returned).
    - Points failure does not break wear log creation (wear log still returned).

- [x] Task 9: Mobile - Add API methods to ApiClient (AC: 7, 8)
  - [x] 9.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getUserStats()` method. Calls `GET /v1/user-stats` using `_authenticatedGet`. Returns response JSON map.

- [x] Task 10: Mobile - Create StylePointsToast widget (AC: 8)
  - [x] 10.1: Create `apps/mobile/lib/src/core/widgets/style_points_toast.dart` with a `StylePointsToast` StatelessWidget. Constructor accepts: `required int pointsAwarded`, `String? bonusLabel` (e.g., "Streak Bonus!").
  - [x] 10.2: The toast renders as a `Container` with: dark background (#1F2937 at 90% opacity), 12px border radius, horizontal padding 16px, vertical padding 10px. Content is a `Row` with: `Icons.auto_awesome` icon (20px, #FBBF24 gold/amber), 8px gap, "+N Style Points" text (14px, FontWeight.bold, Colors.white). If `bonusLabel` is non-null, a secondary line shows the bonus text (12px, #9CA3AF).
  - [x] 10.3: Add `Semantics` label: "Earned N style points".

- [x] Task 11: Mobile - Create showStylePointsToast utility function (AC: 8)
  - [x] 11.1: In the same file `style_points_toast.dart`, add a top-level function `void showStylePointsToast(BuildContext context, { required int pointsAwarded, String? bonusLabel })`. This function: (a) triggers light haptic feedback via `HapticFeedback.lightImpact()`, (b) shows a `SnackBar` with the `StylePointsToast` widget as content, duration 2 seconds, behavior `SnackBarBehavior.floating`, background `Colors.transparent`, elevation 0, no margin (widget handles its own styling).

- [x] Task 12: Mobile - Integrate toast into item upload flow (AC: 1, 8)
  - [x] 12.1: In `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`, after a successful item creation API call, check if the response contains `pointsAwarded`. If `pointsAwarded` is present and `pointsAwarded["pointsAwarded"] > 0`, call `showStylePointsToast(context, pointsAwarded: pointsResult["pointsAwarded"])`. Guard with `mounted` check.

- [x] Task 13: Mobile - Integrate toast into wear log flow (AC: 2, 3, 4, 8)
  - [x] 13.1: In `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart` (or the screen that calls `POST /v1/wear-logs`), after a successful wear log API call, check the response for `pointsAwarded`. Extract `pointsAwarded` (the total), and build a `bonusLabel` string from the bonuses (e.g., "includes streak bonus!" if streak > 0). Call `showStylePointsToast(context, pointsAwarded: total, bonusLabel: bonusLabel)`. Guard with `mounted` check.

- [x] Task 14: Mobile - Widget tests for StylePointsToast (AC: 8, 9)
  - [x] 14.1: Create `apps/mobile/test/core/widgets/style_points_toast_test.dart`:
    - Renders "+10 Style Points" text with correct styling.
    - Renders sparkle icon (Icons.auto_awesome).
    - Renders bonus label when provided.
    - Does not render bonus label when null.
    - Semantics label present: "Earned N style points".
    - showStylePointsToast shows a SnackBar.

- [x] Task 15: Mobile - Integration tests for points display (AC: 1, 2, 8, 9)
  - [x] 15.1: In existing `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`, add tests:
    - After successful item creation, points toast is displayed when pointsAwarded in response.
    - No toast displayed when pointsAwarded is absent from response (backward compatibility).
  - [x] 15.2: In existing wear log test files, add tests:
    - After successful wear log, points toast is displayed with correct total.
    - Bonus label shows when streak or first-log bonuses apply.

- [x] Task 16: Regression testing (AC: all)
  - [x] 16.1: Run `flutter analyze` -- zero new issues.
  - [x] 16.2: Run `flutter test` -- all existing 939+ Flutter tests plus new tests pass.
  - [x] 16.3: Run `npm --prefix apps/api test` -- all existing 441+ API tests plus new tests pass.
  - [x] 16.4: Verify existing `POST /v1/items` tests still pass with the added pointsAwarded field.
  - [x] 16.5: Verify existing `POST /v1/wear-logs` tests still pass with the added pointsAwarded field.
  - [x] 16.6: Apply migration 016_user_stats.sql and verify schema is correct.

## Dev Notes

- This is the **first story in Epic 6** (Gamification & Engagement). It establishes the foundational `user_stats` table and style points system that all subsequent Epic 6 stories build upon (6.2 Levels, 6.3 Streaks, 6.4 Badges, 6.5 Challenge Rewards).
- This story implements **FR-GAM-01**: "Users shall earn style points for actions: upload item (+10), log outfit (+5), streak day (+3), first log of day (+2)."
- This story also partially implements **FR-GAM-06**: "Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`)" -- specifically the `user_stats` table. The `badges` and `user_badges` tables are deferred to Story 6.4.
- **No `user_stats` or gamification infrastructure exists yet.** This is a fully greenfield feature. The architecture maps Epic 6 to `mobile/features/profile`, `api/modules/analytics`, `api/modules/badges`. However, given that gamification is a distinct domain, this story creates a new `api/modules/gamification/` directory for clean separation.
- **The `user_stats` table stores aggregated gamification state.** It is a single row per user (1:1 with profiles) that tracks total points, streak data, and will be extended in later stories for level and badge tracking. The UNIQUE constraint on `profile_id` ensures one row per user.
- **Points are awarded atomically via database RPC functions.** This follows the architecture principle: "atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments." The `award_style_points` function uses `INSERT ... ON CONFLICT DO UPDATE` for safe concurrent upserts.
- **Points are best-effort, non-blocking.** If the points system fails (e.g., database error), the primary action (item creation or wear log) still succeeds. Points failure is logged but does not propagate to the user. This ensures gamification never degrades core functionality.
- **Streak detection is based on `last_streak_date` in `user_stats`.** If the last streak date is yesterday, today's log continues the streak (+3 bonus). If it is today, the streak was already counted. If it is older or null, the streak is broken. Story 6.3 will add the streak freeze mechanism and full streak management; this story only awards the +3 streak bonus when applicable.
- **First-log-of-day detection** queries `wear_logs` for today's date before the current log is inserted. This check happens at the service level, before the wear log is created.
- **The API response shape changes for `POST /v1/items` and `POST /v1/wear-logs`.** Both endpoints now include an optional `pointsAwarded` object alongside the existing `item` or `wearLog` object. This is backward-compatible: existing clients that do not parse `pointsAwarded` continue to work normally.

### Design Decision: New `api/modules/gamification/` Directory

The architecture maps Epic 6 to `api/modules/analytics` and `api/modules/badges`. However, gamification (points, stats, streaks) is a distinct domain from analytics (dashboards, charts, summaries) and badges (achievement definitions). Creating `api/modules/gamification/` provides clear separation:
- `gamification/user-stats-repository.js` -- data access for user_stats
- `gamification/style-points-service.js` -- business logic for point awarding
- Future: `gamification/streak-service.js` (Story 6.3), `gamification/level-service.js` (Story 6.2)

The `badges/` module (Story 6.4) will remain separate as it manages badge definitions and grants.

### Design Decision: Database RPC for Atomic Point Award

Using a PostgreSQL function (`award_style_points`) instead of application-level read-then-write ensures:
1. Atomic increment even under concurrent requests (two simultaneous wear logs).
2. Upsert semantics -- the row is created on first point award without a separate initialization step.
3. Consistent with the existing pattern: `increment_wear_counts` RPC (Story 5.1).

### Design Decision: Toast Instead of Modal for Points

Points are a frequent, low-ceremony reward (+5 for every wear log). A floating snackbar toast is appropriate because:
1. It does not interrupt the user's flow (unlike a modal dialog).
2. It provides immediate positive feedback consistent with the UX spec's "positive reinforcement" pattern.
3. It auto-dismisses after 2 seconds, requiring no user interaction.
4. Story 6.2 (Levels) will use a modal for level-up celebrations, which are less frequent and more significant.

### Design Decision: Streak Logic in This Story vs Story 6.3

This story implements streak *detection* (checking if last_streak_date is yesterday) and the +3 streak bonus point. Story 6.3 will implement full streak *management*: streak freeze mechanism, streak reset on missed days, streak display on profile, and the full streak tracking UX. The `current_streak` and `longest_streak` columns are created in this story's migration to avoid a future schema change, and the `award_points_with_streak` RPC updates them when streak bonuses are awarded.

### Project Structure Notes

- New SQL migration file:
  - `infra/sql/migrations/016_user_stats.sql` (user_stats table, RLS policy, RPC functions)
- New API files:
  - `apps/api/src/modules/gamification/user-stats-repository.js` (data access)
  - `apps/api/src/modules/gamification/style-points-service.js` (business logic)
  - `apps/api/test/modules/gamification/user-stats-repository.test.js`
  - `apps/api/test/modules/gamification/style-points-service.test.js`
  - `apps/api/test/modules/gamification/gamification-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/core/widgets/style_points_toast.dart` (toast widget + utility function)
  - `apps/mobile/test/core/widgets/style_points_toast_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add userStatsRepo, stylePointsService to createRuntime; add GET /v1/user-stats route; modify POST /v1/items and POST /v1/wear-logs responses to include pointsAwarded)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add getUserStats method)
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (add points toast after item creation)
  - `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart` (add points toast after wear log)
- Gamification module directory structure after this story:
  ```
  apps/api/src/modules/gamification/
  ├── user-stats-repository.js (NEW)
  └── style-points-service.js (NEW)

  apps/api/test/modules/gamification/
  ├── user-stats-repository.test.js (NEW)
  ├── style-points-service.test.js (NEW)
  └── gamification-endpoints.test.js (NEW)
  ```

### Technical Requirements

- **Database RPC `award_style_points`:** `CREATE OR REPLACE FUNCTION app_public.award_style_points(p_profile_id UUID, p_points INTEGER) RETURNS TABLE(total_points INTEGER) AS $$ INSERT INTO app_public.user_stats (profile_id, total_points) VALUES (p_profile_id, p_points) ON CONFLICT (profile_id) DO UPDATE SET total_points = app_public.user_stats.total_points + EXCLUDED.total_points, updated_at = now() RETURNING total_points; $$ LANGUAGE sql;`
- **Database RPC `award_points_with_streak`:** More complex PL/pgSQL function that calculates bonuses, upserts user_stats, and returns the result. Must handle the case where `current_streak` needs incrementing only when `last_streak_date` is yesterday.
- **RLS pattern:** Identical to `items`, `outfits`, `wear_logs`. Uses `current_setting('app.current_user_id')` to look up `profile_id` from `profiles.firebase_uid`.
- **Repository pattern:** Factory function returning an object with async methods. Uses `pool.connect()` -> `set_config` -> query -> `client.release()` in try/finally. Maps snake_case to camelCase.
- **Service pattern:** Factory function accepting repository dependencies. Contains business logic (bonus calculation, streak detection). Does not access `pool` directly.
- **API response extension:** Both `POST /v1/items` and `POST /v1/wear-logs` responses gain a `pointsAwarded` field. The field is `null` or absent if points fail to be awarded. This is backward-compatible.
- **Toast widget:** The `StylePointsToast` is placed in `core/widgets/` (not in a feature directory) because it is used across multiple features (wardrobe and analytics). This follows the core/widgets pattern established in the project.
- **Haptic feedback:** Use `HapticFeedback.lightImpact()` from `package:flutter/services.dart`. This is the same import used for other haptic feedback in the app.

### Architecture Compliance

- **Server authority for gamification:** Points are calculated and stored server-side. The mobile client does not compute points or modify `user_stats` directly.
- **Atomic RPCs:** Point awards use database functions for transactional consistency, following the architecture principle for "atomic RPCs for wear counts, badge grants."
- **RLS enforces data isolation:** Users can only read/modify their own `user_stats` row.
- **Mobile boundary owns presentation:** The API returns point values. The client handles toast rendering, animation, and haptic feedback.
- **API module placement:** Gamification services go in `apps/api/src/modules/gamification/`. Routes go in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/user-stats` follows existing API naming conventions.
- **Graceful degradation:** Points failure does not break core actions (item upload, wear logging).

### Library / Framework Requirements

- No new dependencies for mobile or API.
- Mobile uses existing: `flutter/material.dart` (SnackBar, Container, Row, Icon), `flutter/services.dart` (HapticFeedback).
- API uses existing: `pg` (via `pool`).

### File Structure Requirements

- New API module directory: `apps/api/src/modules/gamification/` (new directory for Epic 6).
- New API test directory: `apps/api/test/modules/gamification/`.
- New mobile widget in `apps/mobile/lib/src/core/widgets/` (shared across features).
- Test files mirror source structure.

### Testing Requirements

- **Database migration tests** must verify:
  - `user_stats` table created with correct columns and constraints
  - RLS policy prevents cross-user access
  - `award_style_points` RPC creates row on first call (upsert)
  - `award_style_points` RPC increments existing points
  - `award_points_with_streak` RPC calculates bonuses correctly
  - `award_points_with_streak` RPC updates streak fields
- **API repository tests** must verify:
  - `getUserStats` returns defaults for new user
  - `getUserStats` returns correct data for existing user
  - `awardPoints` upserts correctly
  - `awardPointsWithStreak` handles all bonus combinations
  - `checkFirstLogToday` correctly detects first/subsequent logs
  - `checkStreakDay` correctly detects streak continuation/break
  - RLS isolation between users
- **API service tests** must verify:
  - `awardItemUploadPoints` awards 10 points
  - `awardWearLogPoints` awards correct totals for all bonus combinations (5, 7, 8, 10)
  - Correct bonus breakdown in response
- **API endpoint tests** must verify:
  - `GET /v1/user-stats` returns 200 with stats
  - `GET /v1/user-stats` returns 401 if unauthenticated
  - `POST /v1/items` response includes pointsAwarded
  - `POST /v1/wear-logs` response includes pointsAwarded with bonuses
  - Points failure does not break item/wear-log creation
- **Mobile widget tests** must verify:
  - StylePointsToast renders points text and icon
  - StylePointsToast renders bonus label when provided
  - Semantics labels present
  - showStylePointsToast displays SnackBar
- **Integration tests** must verify:
  - Toast shown after item upload with points
  - Toast shown after wear log with points and bonuses
  - No toast when pointsAwarded absent (backward compatibility)
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 939+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 441+ tests plus new tests pass)
  - Existing `POST /v1/items` and `POST /v1/wear-logs` tests still pass

### Previous Story Intelligence

- **Story 5.7** (done, final in Epic 5) established: 441 API tests, 939 Flutter tests. `createRuntime()` returns: `config, pool, authService, profileService, itemService, uploadService, backgroundRemovalService, categorizationService, calendarEventRepo, classificationService, calendarService, outfitGenerationService, outfitRepository, usageLimitService, wearLogRepository, analyticsRepository, analyticsSummaryService`. `handleRequest` destructures all of these. This story adds `userStatsRepo` and `stylePointsService`.
- **Story 5.1** (done) established: `wear_logs` table with `profile_id`, `logged_date`, `outfit_id`, `photo_url`, `created_at`. `wear_log_items` table. `increment_wear_counts` RPC for atomic wear count increments. `createWearLogRepository` with `createWearLog()` and `listWearLogs()` methods. `POST /v1/wear-logs` endpoint. `LogOutfitBottomSheet` widget for logging outfits.
- **Story 5.2** (done) established: Evening reminder notification for wear logging. The wear log flow triggers from `LogOutfitBottomSheet`.
- **Story 2.4** (done) established: `AddItemScreen` for creating wardrobe items. `POST /v1/items` calls `itemService.createItemForUser()`.
- **Story 4.5** (done) established: `profiles.is_premium` column (migration 014), `createUsageLimitService`, premium gating pattern.
- **Key `POST /v1/items` response shape:** Currently returns `sendJson(res, 201, { item: result })`. This story extends it to `{ item: result, pointsAwarded: { pointsAwarded: 10, totalPoints: N, action: "item_upload" } }`.
- **Key `POST /v1/wear-logs` response shape:** Currently returns `sendJson(res, 201, { wearLog: result })`. This story extends it to `{ wearLog: result, pointsAwarded: { pointsAwarded: N, totalPoints: M, currentStreak: S, bonuses: {...}, action: "wear_log" } }`.
- **Existing migrations (001-015):** 016 is the next available migration number.
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Factory pattern for repositories and services.
  - Database RPC functions for atomic operations (e.g., `increment_wear_counts`).
  - SnackBar for transient feedback messages.

### Key Anti-Patterns to Avoid

- DO NOT compute points client-side. All point calculations happen server-side in the API/database.
- DO NOT make points blocking. If the points system fails, the primary action (item creation, wear logging) must still succeed. Wrap points calls in try/catch and log errors.
- DO NOT create a separate "initialize user stats" endpoint. The `award_style_points` RPC handles upsert automatically.
- DO NOT store point history as individual rows (e.g., a `point_transactions` table). The `user_stats` table stores only the aggregate. If point history is needed later, it can be added in a future story.
- DO NOT implement the level system in this story. Levels are Story 6.2. Only store `total_points` -- the level calculation will be added later.
- DO NOT implement the badge system in this story. Badges are Story 6.4. Do NOT create `badges` or `user_badges` tables.
- DO NOT implement the full streak management (freeze, reset, display) in this story. Streaks are Story 6.3. Only implement streak detection for the +3 bonus and basic `current_streak` tracking.
- DO NOT implement the profile gamification display (XP bar, level, streak flame, badge grid). That is Story 6.2/6.5 (FR-GAM-05). This story only adds the floating toast notification.
- DO NOT use a modal dialog for point awards. Use a floating snackbar toast. Modals are reserved for significant events (level-ups in Story 6.2).
- DO NOT modify the `profiles` table schema. Use the separate `user_stats` table.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT modify existing API test expectations to require `pointsAwarded`. Existing tests should continue to pass -- the `pointsAwarded` field is additive to the response.
- DO NOT create mobile-side point calculation or caching. The client displays what the API returns, nothing more.

### Out of Scope

- **User Progression Levels (FR-GAM-02, FR-GAM-05 partial):** Story 6.2.
- **Streak Tracking & Freezes (FR-GAM-03):** Story 6.3 (full streak management, freeze mechanism, profile display).
- **Badge Achievement System (FR-GAM-04, FR-GAM-06 partial):** Story 6.4.
- **Challenge Rewards / Closet Safari Premium Trial (FR-ONB-03, FR-ONB-04):** Story 6.5.
- **Profile gamification display (XP bar, level, streak, badge grid):** Story 6.2 / 6.5 (FR-GAM-05).
- **Rive animations for points:** The UX spec mentions "Flutter + Rive pattern" for point animations. For V1, a simple Material snackbar toast suffices. Rive animations can be added as a polish enhancement.
- **Point history / transaction log:** Not required by FR-GAM-01. Can be added if needed.
- **Leaderboards or social point comparison:** Not specified in any FR.
- **Points for other actions beyond upload and wear log:** FR-GAM-01 specifies only 4 point types. Additional point sources can be added in future stories.

### References

- [Source: epics.md - Story 6.1: Style Points Rewards]
- [Source: epics.md - FR-GAM-01: Users shall earn style points for actions: upload item (+10), log outfit (+5), streak day (+3), first log of day (+2)]
- [Source: epics.md - FR-GAM-06: Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`)]
- [Source: prd.md - Gamification: Style points, levels, streaks, badges, profile stats]
- [Source: architecture.md - Data Architecture: user_stats, badges, user_badges tables]
- [Source: architecture.md - Database rules: atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments]
- [Source: architecture.md - Server authority for sensitive rules: badge grants enforced server-side]
- [Source: architecture.md - Epic 6 Gamification -> mobile/features/profile, api/modules/analytics, api/modules/badges]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: ux-design-specification.md - Positive Reinforcement (The "Streak" Pattern): haptic vibration + floating snackbar overlay]
- [Source: ux-design-specification.md - Reward every action that builds the user's wardrobe database]
- [Source: ux-design-specification.md - Use gamification (badges, streaks, progress bars) during onboarding and for wear-logging]
- [Source: ux-design-specification.md - Haptic feedback on successful actions (saving an outfit, reaching a streak)]
- [Source: 5-7-ai-generated-analytics-summary.md - createRuntime with 16 services, handleRequest destructuring, 441 API tests, 939 Flutter tests]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - wear_logs table, createWearLogRepository, POST /v1/wear-logs, LogOutfitBottomSheet, increment_wear_counts RPC]
- [Source: 2-4-manual-metadata-editing-creation.md - AddItemScreen, POST /v1/items, itemService.createItemForUser]
- [Source: infra/sql/migrations/ - 001-015 existing, 016 is next available]
- [Source: apps/api/src/modules/wear-logs/wear-log-repository.js - createWearLog pattern, pool.connect/RLS/transaction]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None.

### Completion Notes List

- Implemented complete gamification style points system (FR-GAM-01, FR-GAM-06 partial).
- Created `user_stats` table via migration 016 with RLS, indexes, and two RPC functions (`award_style_points`, `award_points_with_streak`).
- Created `user-stats-repository.js` with 6 methods: `getUserStats`, `awardPoints`, `awardPointsWithStreak`, `checkFirstLogToday`, `checkStreakDay`.
- Created `style-points-service.js` with `awardItemUploadPoints` (+10) and `awardWearLogPoints` (+5 base, +2 first-log, +3 streak).
- Integrated points into `POST /v1/items` and `POST /v1/wear-logs` (best-effort, non-blocking via try/catch).
- Added `GET /v1/user-stats` endpoint for retrieving user gamification stats.
- Created `StylePointsToast` widget and `showStylePointsToast` utility with haptic feedback.
- Integrated toast into `AddItemScreen` (item upload) and `LogOutfitBottomSheet` (wear log) flows.
- Modified `WearLogService` to return `WearLogResult` (includes `pointsAwarded` from API).
- Added `getUserStats()` method to mobile `ApiClient`.
- 33 new API tests (474 total, all passing). 10 new Flutter tests (949 total, all passing).
- `flutter analyze`: zero new issues (5 pre-existing warnings in `wear_calendar_screen_test.dart`).
- All existing tests pass with no regressions -- `pointsAwarded` field is additive and backward-compatible.

### Change Log

- 2026-03-19: Story 6.1 implemented -- style points rewards system with gamification module, migration, API endpoints, mobile toast integration.

### File List

New files:
- `infra/sql/migrations/016_user_stats.sql`
- `apps/api/src/modules/gamification/user-stats-repository.js`
- `apps/api/src/modules/gamification/style-points-service.js`
- `apps/api/test/modules/gamification/user-stats-repository.test.js`
- `apps/api/test/modules/gamification/style-points-service.test.js`
- `apps/api/test/modules/gamification/gamification-endpoints.test.js`
- `apps/mobile/lib/src/core/widgets/style_points_toast.dart`
- `apps/mobile/test/core/widgets/style_points_toast_test.dart`

Modified files:
- `apps/api/src/main.js` (added gamification imports, createRuntime wiring, handleRequest destructuring, points in POST /v1/items and POST /v1/wear-logs, GET /v1/user-stats route)
- `apps/mobile/lib/src/core/networking/api_client.dart` (added getUserStats method)
- `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (added points toast after item creation)
- `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart` (added points toast after wear log, _showPointsToast helper)
- `apps/mobile/lib/src/features/analytics/services/wear_log_service.dart` (added WearLogResult class, logItems/logOutfit return WearLogResult with pointsAwarded)
- `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart` (added points toast integration tests)
- `apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart` (added points data integration tests)
- `apps/mobile/test/features/analytics/services/wear_log_service_test.dart` (updated to use result.wearLog for WearLogResult)
