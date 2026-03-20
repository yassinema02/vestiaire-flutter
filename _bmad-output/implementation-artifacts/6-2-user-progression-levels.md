# Story 6.2: User Progression Levels

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see my "Style Level" increase as my wardrobe grows,
so that I feel a sense of progression from Rookie to Master.

## Acceptance Criteria

1. Given the `user_stats` table exists (from Story 6.1 migration 016), when migration 017 is applied, then two new columns are added: `current_level INTEGER NOT NULL DEFAULT 1` and `current_level_name TEXT NOT NULL DEFAULT 'Closet Rookie'`. These columns are added via `ALTER TABLE app_public.user_stats ADD COLUMN ...` (not a new table). The migration also creates the database RPC function `app_public.recalculate_user_level(p_profile_id UUID)`. (FR-GAM-02, FR-GAM-06)

2. Given a user has fewer than 10 wardrobe items, when their level is calculated, then their level is 1 ("Closet Rookie"). Given a user has 10-24 items, their level is 2 ("Style Starter"). Given 25-49 items, level 3 ("Fashion Explorer"). Given 50-99 items, level 4 ("Wardrobe Pro"). Given 100-199 items, level 5 ("Style Expert"). Given 200+ items, level 6 ("Style Master"). Level thresholds are based on wardrobe item count (`SELECT COUNT(*) FROM app_public.items WHERE profile_id = ...`). (FR-GAM-02)

3. Given a user creates a new wardrobe item via `POST /v1/items`, when the item is successfully created, then the API calls `recalculate_user_level` and includes the level result in the response. If the user's level changed (leveledUp: true), the response includes `levelUp: { newLevel, newLevelName, previousLevel, previousLevelName }`. If the level did not change, `levelUp` is null. The level check is best-effort (wrapped in try/catch) and does not block item creation on failure. (FR-GAM-02)

4. Given a user's level increases after adding an item, when the mobile client receives a response with a non-null `levelUp` object, then a celebratory modal dialog is displayed with: the new level name as the title (e.g., "Style Starter"), a congratulatory message ("You've reached Level 2!"), the next level threshold ("Next: Fashion Explorer at 25 items"), and a "Continue" button to dismiss. The modal uses a scale-in animation. Haptic feedback (medium impact) fires when the modal appears. (FR-GAM-02, FR-GAM-05)

5. Given a user visits the Profile tab, when the profile screen loads, then it displays a gamification header section showing: the user's current level name (e.g., "Style Starter"), a numeric level indicator (e.g., "Level 2"), total style points, current streak (with a flame icon if streak > 0), and an XP progress bar showing progress toward the next level (items owned / next threshold). The progress bar is a `LinearProgressIndicator` with the app's accent color (#2563EB). (FR-GAM-05)

6. Given the `GET /v1/user-stats` endpoint exists (from Story 6.1), when it is called, then the response now also includes `currentLevel`, `currentLevelName`, `nextLevelThreshold`, and `itemCount` alongside the existing fields (totalPoints, currentStreak, longestStreak, lastStreakDate, streakFreezeUsedAt). If no `user_stats` row exists yet, the API returns defaults: `{ currentLevel: 1, currentLevelName: "Closet Rookie", nextLevelThreshold: 10, itemCount: 0, ... }`. (FR-GAM-02, FR-GAM-05)

7. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (474+ API tests, 949+ Flutter tests) and new tests cover: migration 017, recalculate_user_level RPC function, level calculation for all 6 thresholds, level-up detection in POST /v1/items, updated GET /v1/user-stats response, LevelUpModal widget, GamificationHeader widget, Profile screen integration with gamification header, and all level boundary conditions (9->10 items triggers level-up, 10->11 does not).

## Tasks / Subtasks

- [x] Task 1: Database - Create migration 017 for level columns and RPC (AC: 1, 2)
  - [x] 1.1: Create `infra/sql/migrations/017_user_levels.sql`. Add columns to `user_stats`: `ALTER TABLE app_public.user_stats ADD COLUMN current_level INTEGER NOT NULL DEFAULT 1;` and `ALTER TABLE app_public.user_stats ADD COLUMN current_level_name TEXT NOT NULL DEFAULT 'Closet Rookie';`.
  - [x]1.2: Create RPC function `app_public.recalculate_user_level(p_profile_id UUID)` in PL/pgSQL. Steps: (a) count items: `SELECT COUNT(*) FROM app_public.items WHERE profile_id = p_profile_id`, (b) determine level and name from thresholds: 0-9 = Level 1 "Closet Rookie", 10-24 = Level 2 "Style Starter", 25-49 = Level 3 "Fashion Explorer", 50-99 = Level 4 "Wardrobe Pro", 100-199 = Level 5 "Style Expert", 200+ = Level 6 "Style Master", (c) read current level from `user_stats`, (d) upsert `user_stats` row with new level/name: `INSERT INTO app_public.user_stats (profile_id, current_level, current_level_name) VALUES (...) ON CONFLICT (profile_id) DO UPDATE SET current_level = ..., current_level_name = ..., updated_at = now()`, (e) return `TABLE(current_level INTEGER, current_level_name TEXT, previous_level INTEGER, previous_level_name TEXT, leveled_up BOOLEAN, item_count INTEGER, next_level_threshold INTEGER)`. The `next_level_threshold` is the item count needed for the next level (10, 25, 50, 100, 200, NULL for max level).

- [x]Task 2: API - Create level service (AC: 2, 3)
  - [x]2.1: Create `apps/api/src/modules/gamification/level-service.js` with `createLevelService({ pool })`. Follow the factory pattern used by all other services.
  - [x]2.2: Implement `async recalculateLevel(authContext)` method. Look up `profile_id` from `profiles.firebase_uid`, then call `SELECT * FROM app_public.recalculate_user_level($1)` with `[profileId]`. Return `{ currentLevel, currentLevelName, previousLevel, previousLevelName, leveledUp, itemCount, nextLevelThreshold }` mapped to camelCase.

- [x]Task 3: API - Integrate level check into POST /v1/items (AC: 3)
  - [x]3.1: In `apps/api/src/main.js`, import `createLevelService`. In `createRuntime()`, instantiate `levelService = createLevelService({ pool })`. Add to the returned runtime object.
  - [x]3.2: In `handleRequest`, add `levelService` to the destructuring.
  - [x]3.3: In the `POST /v1/items` route, after the existing `stylePointsService.awardItemUploadPoints()` call (from Story 6.1), add: `const levelResult = await levelService.recalculateLevel(authContext)`. Include in the response: `levelUp: levelResult.leveledUp ? { newLevel: levelResult.currentLevel, newLevelName: levelResult.currentLevelName, previousLevel: levelResult.previousLevel, previousLevelName: levelResult.previousLevelName } : null`. Wrap in try/catch so level check failure does NOT fail the item creation -- log the error and return the item without level data.

- [x]Task 4: API - Update GET /v1/user-stats to include level data (AC: 6)
  - [x]4.1: In `apps/api/src/modules/gamification/user-stats-repository.js`, update the `getUserStats` method. Change the SQL query to also fetch `current_level`, `current_level_name` from `user_stats`, and additionally query `SELECT COUNT(*) AS item_count FROM app_public.items WHERE profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1)` to get the live item count. Calculate `nextLevelThreshold` from the current level (level 1 -> 10, level 2 -> 25, level 3 -> 50, level 4 -> 100, level 5 -> 200, level 6 -> null). Add to the return object: `currentLevel`, `currentLevelName`, `itemCount`, `nextLevelThreshold`. Update the defaults for no-row case: `currentLevel: 1, currentLevelName: "Closet Rookie", nextLevelThreshold: 10, itemCount: 0`.

- [x]Task 5: API - Unit tests for level service (AC: 1, 2, 3, 7)
  - [x]5.1: Create `apps/api/test/modules/gamification/level-service.test.js`:
    - `recalculateLevel` returns level 1 "Closet Rookie" for 0 items.
    - `recalculateLevel` returns level 2 "Style Starter" for exactly 10 items.
    - `recalculateLevel` returns level 3 "Fashion Explorer" for 25 items.
    - `recalculateLevel` returns level 4 "Wardrobe Pro" for 50 items.
    - `recalculateLevel` returns level 5 "Style Expert" for 100 items.
    - `recalculateLevel` returns level 6 "Style Master" for 200 items.
    - `recalculateLevel` returns `leveledUp: true` when crossing 10-item threshold.
    - `recalculateLevel` returns `leveledUp: false` when item count stays in same tier (e.g., 11 items, already level 2).
    - `recalculateLevel` returns correct `nextLevelThreshold` for each level.
    - `recalculateLevel` returns `nextLevelThreshold: null` for level 6 (max).
    - Boundary tests: 9 items = level 1, 10 items = level 2, 24 items = level 2, 25 items = level 3.

- [x]Task 6: API - Integration tests for level endpoints (AC: 3, 6, 7)
  - [x]6.1: Create `apps/api/test/modules/gamification/level-endpoints.test.js`:
    - `POST /v1/items` response includes `levelUp: null` when no level change.
    - `POST /v1/items` response includes `levelUp` object when level changes.
    - `GET /v1/user-stats` includes `currentLevel`, `currentLevelName`, `nextLevelThreshold`, `itemCount`.
    - `GET /v1/user-stats` returns defaults for new user (level 1, Closet Rookie, threshold 10).
    - Level-up is correctly detected when adding the 10th item.
    - Level data failure does not break item creation (item still returned).

- [x]Task 7: API - Update existing user-stats tests for new fields (AC: 6, 7)
  - [x]7.1: Update `apps/api/test/modules/gamification/user-stats-repository.test.js`: add assertions for `currentLevel`, `currentLevelName` in `getUserStats` responses, and verify `itemCount` and `nextLevelThreshold` are returned.
  - [x]7.2: Update `apps/api/test/modules/gamification/gamification-endpoints.test.js`: update `GET /v1/user-stats` assertions to include the new level fields.

- [x]Task 8: Mobile - Update ApiClient for level data (AC: 4, 5, 6)
  - [x]8.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, no new methods needed -- `getUserStats()` already fetches `GET /v1/user-stats`. The response now includes additional level fields. Document the new response shape in comments.

- [x]Task 9: Mobile - Create LevelUpModal widget (AC: 4)
  - [x]9.1: Create `apps/mobile/lib/src/features/profile/widgets/level_up_modal.dart` with a `LevelUpModal` StatelessWidget. Constructor accepts: `required int newLevel`, `required String newLevelName`, `String? previousLevelName`, `int? nextLevelThreshold`.
  - [x]9.2: The modal renders as an `AlertDialog` with: title row showing a trophy icon (Icons.emoji_events, #FBBF24 gold) and the new level name (20px, bold, #1F2937), body text "You've reached Level N!" (16px, #4B5563), sub-text showing next level info: "Next: [NextLevelName] at [threshold] items" (14px, #9CA3AF) -- omit this line if at max level, a "Continue" `FilledButton` to dismiss. Scale-in animation via `ScaleTransition` wrapping the dialog. Haptic feedback via `HapticFeedback.mediumImpact()` when shown.
  - [x]9.3: Add `Semantics` label: "Congratulations! You've reached level N, [LevelName]".
  - [x]9.4: Create a top-level function `void showLevelUpModal(BuildContext context, { required int newLevel, required String newLevelName, String? previousLevelName, int? nextLevelThreshold })` that shows the dialog via `showGeneralDialog` with a scale transition animation.

- [x]Task 10: Mobile - Create GamificationHeader widget (AC: 5)
  - [x]10.1: Create `apps/mobile/lib/src/features/profile/widgets/gamification_header.dart` with a `GamificationHeader` StatelessWidget. Constructor accepts: `required int currentLevel`, `required String currentLevelName`, `required int totalPoints`, `required int currentStreak`, `required int itemCount`, `int? nextLevelThreshold`.
  - [x]10.2: The widget renders a `Container` (card style: white background, 12px border radius, subtle shadow) containing:
    - Top row: Level name (18px bold, #1F2937) + "Level N" chip (small rounded container, #4F46E5 background, white text, 12px).
    - Progress bar section: "Progress to [NextLevelName]" label (12px, #6B7280), a `LinearProgressIndicator` (value = itemCount / nextLevelThreshold, color #2563EB, track color #E5E7EB, 8px height, 4px border radius via `ClipRRect`). Below the bar: "[itemCount] / [nextLevelThreshold] items" (12px, #9CA3AF). If at max level (nextLevelThreshold is null), show "Max Level Reached" and a full progress bar.
    - Stats row: Three stat chips in a `Row` with `MainAxisAlignment.spaceEvenly`: (a) total points with sparkle icon (Icons.auto_awesome, #FBBF24), (b) current streak with flame icon (Icons.local_fire_department, streak > 0 ? #F97316 : #D1D5DB), (c) item count with wardrobe icon (Icons.checkroom, #2563EB).
  - [x]10.3: Add `Semantics` labels on all stat elements: "Total points: N", "Current streak: N days", "Wardrobe items: N".

- [x]Task 11: Mobile - Create ProfileScreen and integrate GamificationHeader (AC: 5)
  - [x]11.1: Create `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` with a `ProfileScreen` StatefulWidget. Constructor accepts: `required ApiClient apiClient`, `VoidCallback? onSignOut`, `Future<void> Function()? onDeleteAccount`, `SubscriptionService? subscriptionService`.
  - [x]11.2: In `initState`, call `_loadUserStats()` which calls `apiClient.getUserStats()`. Store the response in state. Handle loading, error, and success states.
  - [x]11.3: The screen layout: `Scaffold` with AppBar (title: "Profile", same actions as current _buildProfileTab: notification settings, sign out). Body is a `SingleChildScrollView` containing: `GamificationHeader` widget at the top (populated from user stats API response), then the existing profile content (subscription button, manage subscription, delete account) below.
  - [x]11.4: Error state: show existing content with a subtle error banner at top ("Unable to load stats") with a retry button. This ensures the profile tab remains functional even if stats fail.
  - [x]11.5: Loading state: show a shimmer/placeholder for the gamification header while loading (a Container with same dimensions as GamificationHeader, filled with #F3F4F6).

- [x]Task 12: Mobile - Replace profile tab placeholder in MainShellScreen (AC: 5)
  - [x]12.1: In `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`, import `ProfileScreen`. Replace the `_buildProfileTab()` method body: instead of the inline Scaffold with "Profile - Coming Soon", instantiate `ProfileScreen(apiClient: widget.apiClient!, onSignOut: widget.onSignOut, onDeleteAccount: widget.onDeleteAccount, subscriptionService: widget.subscriptionService)`. Handle the null apiClient case by keeping the existing fallback UI.
  - [x]12.2: Move the notification preferences navigation logic from `_buildProfileTab` into `ProfileScreen` (or pass callbacks). The notification bell, sign-out button, and delete-account button must remain accessible from the Profile tab with the same behavior.

- [x]Task 13: Mobile - Integrate level-up modal into item upload flow (AC: 4)
  - [x]13.1: In `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`, after the existing points toast (from Story 6.1), check if the response contains `levelUp` and `levelUp` is non-null. If so, call `showLevelUpModal(context, newLevel: levelUp["newLevel"], newLevelName: levelUp["newLevelName"], previousLevelName: levelUp["previousLevelName"], nextLevelThreshold: levelUp["nextLevelThreshold"])`. Show the modal AFTER the points toast (brief delay or sequential). Guard with `mounted` check.

- [x]Task 14: Mobile - Widget tests for LevelUpModal (AC: 4, 7)
  - [x]14.1: Create `apps/mobile/test/features/profile/widgets/level_up_modal_test.dart`:
    - Renders new level name as title.
    - Renders "You've reached Level N!" text.
    - Renders next level info when nextLevelThreshold provided.
    - Does not render next level info when at max level (nextLevelThreshold null).
    - Renders trophy icon.
    - Renders "Continue" button.
    - Tapping "Continue" dismisses the dialog.
    - Semantics label present.

- [x]Task 15: Mobile - Widget tests for GamificationHeader (AC: 5, 7)
  - [x]15.1: Create `apps/mobile/test/features/profile/widgets/gamification_header_test.dart`:
    - Renders current level name and "Level N".
    - Renders progress bar with correct value (e.g., 15/25 = 0.6).
    - Renders "Max Level Reached" when nextLevelThreshold is null.
    - Renders total points with sparkle icon.
    - Renders current streak with flame icon.
    - Renders item count with wardrobe icon.
    - Streak flame icon is colored when streak > 0.
    - Streak flame icon is gray when streak is 0.
    - Semantics labels present on all stat elements.

- [x]Task 16: Mobile - Widget tests for ProfileScreen (AC: 5, 7)
  - [x]16.1: Create `apps/mobile/test/features/profile/screens/profile_screen_test.dart`:
    - Renders GamificationHeader when stats load successfully.
    - Shows loading placeholder while stats are loading.
    - Shows error banner with retry on stats load failure.
    - Retry button triggers stats reload.
    - Renders subscription button when subscriptionService provided.
    - Renders delete account button when onDeleteAccount provided.
    - Sign out button calls onSignOut callback.

- [x]Task 17: Mobile - Integration test for level-up modal in item flow (AC: 4, 7)
  - [x]17.1: In existing `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`, add tests:
    - After successful item creation with levelUp in response, level-up modal is displayed.
    - Level-up modal shows correct new level name.
    - No modal when levelUp is null in response.
    - Both points toast and level-up modal appear when both are present.

- [x]Task 18: Regression testing (AC: all)
  - [x]18.1: Run `flutter analyze` -- zero new issues.
  - [x]18.2: Run `flutter test` -- all existing 949+ Flutter tests plus new tests pass.
  - [x]18.3: Run `npm --prefix apps/api test` -- all existing 474+ API tests plus new tests pass.
  - [x]18.4: Verify existing `POST /v1/items` tests still pass with the added `levelUp` field.
  - [x]18.5: Verify existing `GET /v1/user-stats` tests still pass with added level fields.
  - [x]18.6: Apply migration 017_user_levels.sql and verify schema is correct.

## Dev Notes

- This is the **second story in Epic 6** (Gamification & Engagement). It builds on Story 6.1's `user_stats` table and gamification module to add the user level progression system.
- This story implements **FR-GAM-02**: "The system shall track 6 user levels based on wardrobe item count thresholds: Closet Rookie (0), Style Starter (10), Fashion Explorer (25), Wardrobe Pro (50), Style Expert (100), Style Master (200)."
- This story partially implements **FR-GAM-05**: "The profile screen shall display: current level, XP progress bar, current streak, total points, badge collection grid, and recent activity feed." Specifically, this story adds: current level, XP progress bar, current streak, total points. The badge collection grid is deferred to Story 6.4, and the recent activity feed is out of scope.
- **Levels are based on wardrobe item count, NOT style points.** FR-GAM-02 explicitly says "based on wardrobe item count thresholds." The progress bar shows items owned vs. next threshold, not points. Style points are displayed as a stat but do not determine the level.
- **The `user_stats` table is extended, not replaced.** Migration 017 adds `current_level` and `current_level_name` columns to the existing `user_stats` table (created in migration 016). This avoids creating a separate table and keeps all gamification state co-located.
- **Level recalculation happens on item creation only.** Since levels are based on item count, the only action that can change a level is adding an item. Item deletion could technically lower a level, but for UX simplicity, levels do not decrease -- only recalculate upward. The RPC handles this: if the calculated level is lower than the stored level, it keeps the stored level (no downgrade).
- **The `recalculate_user_level` RPC counts items live.** It queries `SELECT COUNT(*) FROM items WHERE profile_id = ...` each time rather than caching the count. This ensures accuracy. The query is fast (indexed on profile_id) and only runs on item creation.
- **Level-up uses a modal, not a toast.** Story 6.1 explicitly reserved modals for "significant events (level-ups in Story 6.2)." Level-ups are infrequent (only 5 possible transitions) and celebratory, justifying a modal. The modal appears AFTER the points toast, creating a layered reward sequence.
- **The Profile tab gets a real screen.** Currently the Profile tab shows a placeholder "Profile - Coming Soon" with settings links. This story replaces it with a `ProfileScreen` that displays the gamification header and preserves all existing functionality (subscription, delete account, sign out, notification preferences). The notification preferences navigation logic currently in `MainShellScreen` must be migrated to or called from `ProfileScreen`.
- **GET /v1/user-stats is extended, not replaced.** The existing endpoint returns totalPoints, currentStreak, etc. This story adds currentLevel, currentLevelName, nextLevelThreshold, and itemCount. The response shape is backward-compatible: new fields are additive.
- **Best-effort level calculation.** Like points (Story 6.1), level recalculation failure does NOT fail the primary action (item creation). If the level RPC fails, the item is still returned without level data. Log the error.

### Design Decision: Level Thresholds in Database RPC

The level thresholds (0, 10, 25, 50, 100, 200) are hardcoded in the `recalculate_user_level` RPC function rather than in a lookup table. This is appropriate because:
1. There are only 6 fixed levels per FR-GAM-02 -- they will not change frequently.
2. A single RPC call counts items AND determines the level atomically, avoiding race conditions.
3. If thresholds need to change, a new migration updates the function.

### Design Decision: No Level Downgrade

Levels only go up, never down. If a user deletes items and drops below a threshold, they keep their current level. This prevents a frustrating UX where users feel punished for decluttering (which the app actively encourages via resale/donation features).

### Design Decision: Profile Screen Extraction

The Profile tab is extracted from `MainShellScreen._buildProfileTab()` into a dedicated `ProfileScreen` widget in `features/profile/screens/`. This follows the pattern established by other tabs (HomeScreen, WardrobeScreen, OutfitHistoryScreen) and allows the profile to manage its own state (loading stats, error handling).

### Project Structure Notes

- New SQL migration file:
  - `infra/sql/migrations/017_user_levels.sql` (ALTER TABLE for level columns, recalculate_user_level RPC)
- New API files:
  - `apps/api/src/modules/gamification/level-service.js` (level recalculation service)
  - `apps/api/test/modules/gamification/level-service.test.js`
  - `apps/api/test/modules/gamification/level-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (new Profile tab screen)
  - `apps/mobile/lib/src/features/profile/widgets/level_up_modal.dart` (level-up celebration modal)
  - `apps/mobile/lib/src/features/profile/widgets/gamification_header.dart` (profile stats header)
  - `apps/mobile/test/features/profile/screens/profile_screen_test.dart`
  - `apps/mobile/test/features/profile/widgets/level_up_modal_test.dart`
  - `apps/mobile/test/features/profile/widgets/gamification_header_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add levelService to createRuntime, handleRequest; add level check to POST /v1/items)
  - `apps/api/src/modules/gamification/user-stats-repository.js` (update getUserStats to include level and item count)
  - `apps/api/test/modules/gamification/user-stats-repository.test.js` (add level field assertions)
  - `apps/api/test/modules/gamification/gamification-endpoints.test.js` (add level field assertions)
- Modified mobile files:
  - `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` (replace _buildProfileTab with ProfileScreen)
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (add level-up modal after item creation)
  - `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart` (add level-up modal tests)
- New mobile feature directory:
  ```
  apps/mobile/lib/src/features/profile/
  ├── screens/
  │   └── profile_screen.dart (NEW)
  └── widgets/
      ├── gamification_header.dart (NEW)
      └── level_up_modal.dart (NEW)

  apps/mobile/test/features/profile/
  ├── screens/
  │   └── profile_screen_test.dart (NEW)
  └── widgets/
      ├── gamification_header_test.dart (NEW)
      └── level_up_modal_test.dart (NEW)
  ```

### Technical Requirements

- **Database RPC `recalculate_user_level`:** PL/pgSQL function that: (1) counts items for the profile, (2) determines level from thresholds, (3) reads current stored level, (4) only updates if new level >= stored level (no downgrade), (5) returns both old and new level plus leveledUp boolean. Uses `INSERT ... ON CONFLICT DO UPDATE` for upsert semantics (creates user_stats row if not exists).
- **Level thresholds:** Level 1 "Closet Rookie" (0-9), Level 2 "Style Starter" (10-24), Level 3 "Fashion Explorer" (25-49), Level 4 "Wardrobe Pro" (50-99), Level 5 "Style Expert" (100-199), Level 6 "Style Master" (200+).
- **Next level thresholds:** Level 1 -> 10, Level 2 -> 25, Level 3 -> 50, Level 4 -> 100, Level 5 -> 200, Level 6 -> null (max).
- **RLS pattern:** Same as Story 6.1. The recalculate_user_level RPC is called with the profile_id obtained from an authenticated lookup, and the user_stats table has RLS enforced.
- **Service pattern:** Factory function `createLevelService({ pool })` returning an object with `recalculateLevel(authContext)`. Uses `pool.connect()` -> `set_config` -> query -> `client.release()` in try/finally. Maps snake_case to camelCase.
- **API response extension:** `POST /v1/items` gains a `levelUp` field (null or object). `GET /v1/user-stats` gains `currentLevel`, `currentLevelName`, `nextLevelThreshold`, `itemCount`. Both are additive and backward-compatible.
- **Modal widget:** Uses `showGeneralDialog` with `ScaleTransition` for animation. `HapticFeedback.mediumImpact()` on display. Dismiss via "Continue" button calling `Navigator.pop()`.
- **GamificationHeader widget:** Placed in `features/profile/widgets/` since it is specific to the profile feature. Uses `LinearProgressIndicator` for the XP bar.
- **ProfileScreen:** StatefulWidget that loads stats in `initState`. Uses `setState` with `mounted` guard. Error handling with retry. Preserves all existing profile tab functionality.

### Architecture Compliance

- **Server authority for gamification:** Levels are calculated server-side via database RPC. The mobile client does not compute levels.
- **Atomic RPCs:** Level recalculation uses a database function for transactional consistency, consistent with Story 6.1's `award_style_points`.
- **RLS enforces data isolation:** Users can only read/modify their own `user_stats` row via RLS policies (unchanged from Story 6.1).
- **Mobile boundary owns presentation:** The API returns level data. The client handles modal rendering, animation, progress bar display, and haptic feedback.
- **API module placement:** Level service goes in `apps/api/src/modules/gamification/`. Routes stay in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/user-stats` and `POST /v1/items` follow existing API naming conventions.
- **Graceful degradation:** Level calculation failure does not break core actions (item creation).
- **Epic 6 mapping:** Architecture maps Epic 6 to `mobile/features/profile`, `api/modules/analytics`, `api/modules/badges`. This story creates the `mobile/features/profile` directory structure and extends `api/modules/gamification` (established in Story 6.1 as the correct home for gamification logic).

### Library / Framework Requirements

- No new dependencies for mobile or API.
- Mobile uses existing: `flutter/material.dart` (AlertDialog, LinearProgressIndicator, Container, Row, Icon), `flutter/services.dart` (HapticFeedback).
- API uses existing: `pg` (via `pool`).

### File Structure Requirements

- New mobile feature directory: `apps/mobile/lib/src/features/profile/` with `screens/` and `widgets/` subdirectories.
- New mobile test directory: `apps/mobile/test/features/profile/` mirroring source structure.
- API files stay in the existing `apps/api/src/modules/gamification/` directory (created in Story 6.1).
- API test files stay in `apps/api/test/modules/gamification/`.
- Test files mirror source structure.

### Testing Requirements

- **Database migration tests** must verify:
  - `current_level` and `current_level_name` columns added to `user_stats`
  - Default values: level 1, "Closet Rookie"
  - `recalculate_user_level` RPC returns correct level for all 6 threshold boundaries
  - `recalculate_user_level` returns `leveled_up = true` when crossing a threshold
  - `recalculate_user_level` returns `leveled_up = false` when staying in same tier
  - `recalculate_user_level` does not downgrade level (deleting items keeps current level)
  - `recalculate_user_level` upserts (creates user_stats row if not exists)
- **API service tests** must verify:
  - `recalculateLevel` returns correct level for each of the 6 tiers
  - `recalculateLevel` correctly detects level-up transitions
  - Boundary tests: 9 items = level 1, 10 items = level 2
  - Returns correct `nextLevelThreshold` for each level
- **API endpoint tests** must verify:
  - `POST /v1/items` includes `levelUp: null` when no level change
  - `POST /v1/items` includes `levelUp` object when level changes
  - `GET /v1/user-stats` includes level fields
  - Level failure does not break item creation
- **Mobile widget tests** must verify:
  - LevelUpModal renders all elements, dismisses on button tap
  - GamificationHeader renders level, progress bar, stats
  - ProfileScreen loads stats, handles errors, shows gamification header
- **Integration tests** must verify:
  - Level-up modal shown after item creation when levelUp present
  - No modal when levelUp is null
  - Both points toast and level-up modal can appear together
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 949+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 474+ tests plus new tests pass)
  - Existing `POST /v1/items` and `GET /v1/user-stats` tests still pass

### Previous Story Intelligence

- **Story 6.1** (done) established: `user_stats` table with `total_points`, `current_streak`, `longest_streak`, `last_streak_date`, `streak_freeze_used_at`. Migration 016. `api/modules/gamification/` directory with `user-stats-repository.js` and `style-points-service.js`. `GET /v1/user-stats` endpoint returning stats. `StylePointsToast` widget for point feedback. Points integrated into `POST /v1/items` and `POST /v1/wear-logs`. `createRuntime()` returns 18 services (now includes `userStatsRepo` and `stylePointsService`). Test counts: 474 API tests, 949 Flutter tests.
- **Story 6.1 design decisions relevant to 6.2:**
  - "Story 6.2 (Levels) will use a modal for level-up celebrations, which are less frequent and more significant" -- confirmed, must use modal.
  - "DO NOT implement the profile gamification display (XP bar, level, streak flame, badge grid). That is Story 6.2/6.5" -- this story implements the XP bar, level, streak display.
  - `api/modules/gamification/` is the correct directory (not `api/modules/analytics` or `api/modules/badges`).
  - Future `gamification/level-service.js` was anticipated in Story 6.1's design notes.
- **Story 6.1 response shapes to extend:**
  - `POST /v1/items` currently returns: `{ item: result, pointsAwarded: { pointsAwarded: 10, totalPoints: N, action: "item_upload" } }`. This story adds `levelUp` as a sibling field.
  - `GET /v1/user-stats` currently returns: `{ stats: { totalPoints, currentStreak, longestStreak, lastStreakDate, streakFreezeUsedAt } }`. This story adds `currentLevel`, `currentLevelName`, `nextLevelThreshold`, `itemCount` to the `stats` object.
- **Story 2.4** (done) established: `AddItemScreen` for creating wardrobe items. The item creation success handler already shows points toast (from Story 6.1). The level-up modal will be added after the toast.
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern from Story 5.4).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Factory pattern for repositories and services.
  - Database RPC functions for atomic operations.
  - `showGeneralDialog` not yet used -- this is the first modal dialog in gamification. Use `showDialog` with `AlertDialog` as a simpler alternative if `showGeneralDialog` is overly complex.

### Key Anti-Patterns to Avoid

- DO NOT compute levels client-side. All level calculations happen server-side in the database RPC.
- DO NOT make level checks blocking. If level recalculation fails, the primary action (item creation) must still succeed. Wrap in try/catch and log errors.
- DO NOT base levels on style points. FR-GAM-02 explicitly says "based on wardrobe item count thresholds." Points are a display stat, not a level determinant.
- DO NOT allow level downgrades. If a user deletes items and drops below a threshold, keep the current level. Recalculate only upward.
- DO NOT create a separate table for levels. Extend `user_stats` with additional columns via ALTER TABLE.
- DO NOT implement the badge collection grid in this story. Badges are Story 6.4. The gamification header shows level, points, streak, and items -- no badge section.
- DO NOT implement the recent activity feed. That is not required by FR-GAM-02 and can be added later.
- DO NOT cache item counts in `user_stats`. Always query live from the `items` table to ensure accuracy.
- DO NOT use a toast for level-up notifications. Use a modal dialog (as specified in Story 6.1's design decisions).
- DO NOT break existing profile tab functionality. Sign out, delete account, subscription, and notification preferences must all remain accessible.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT modify existing API test expectations to require the new level fields. Existing tests should continue to pass -- the new fields are additive to the response.
- DO NOT create a separate `ProfileScreen` in the settings or shell feature directories. Use `features/profile/screens/`.

### Out of Scope

- **Streak Tracking & Freezes (FR-GAM-03):** Story 6.3 (full streak management, freeze mechanism, streak display enhancements).
- **Badge Achievement System (FR-GAM-04, FR-GAM-06 partial):** Story 6.4 (badges table, user_badges table, badge grid on profile).
- **Challenge Rewards / Closet Safari Premium Trial (FR-ONB-03, FR-ONB-04):** Story 6.5.
- **Recent activity feed on profile (FR-GAM-05 partial):** Deferred. FR-GAM-05 mentions "recent activity feed" but this is not part of the level system.
- **Badge collection grid on profile (FR-GAM-05 partial):** Story 6.4.
- **Rive animations:** UX spec mentions "Flutter + Rive pattern" for gamification animations. For V1, standard Material animations suffice.
- **Level-down on item deletion:** Intentionally excluded for positive UX.
- **Level display on other screens (home, wardrobe):** Only displayed on Profile tab per FR-GAM-05.
- **Dark mode for gamification header:** Follow existing app convention (light mode only for MVP).

### References

- [Source: epics.md - Story 6.2: User Progression Levels]
- [Source: epics.md - FR-GAM-02: The system shall track 6 user levels based on wardrobe item count thresholds: Closet Rookie (0), Style Starter (10), Fashion Explorer (25), Wardrobe Pro (50), Style Expert (100), Style Master (200)]
- [Source: epics.md - FR-GAM-05: The profile screen shall display: current level, XP progress bar, current streak, total points, badge collection grid, and recent activity feed]
- [Source: epics.md - FR-GAM-06: Badges and levels shall be stored server-side with RLS-protected tables]
- [Source: prd.md - Gamification: Style points, levels, streaks, badges, profile stats]
- [Source: architecture.md - Data Architecture: user_stats, badges, user_badges tables]
- [Source: architecture.md - Database rules: atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments]
- [Source: architecture.md - Server authority for sensitive rules: badge grants enforced server-side]
- [Source: architecture.md - Epic 6 Gamification -> mobile/features/profile, api/modules/analytics, api/modules/badges]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Optimistic UI allowed for badge/streak feedback]
- [Source: ux-design-specification.md - Accomplishment: Use gamification (badges, streaks, progress bars) during onboarding and for wear-logging]
- [Source: ux-design-specification.md - Duolingo / Apple Fitness (Gamification): streak and badge elements drive daily habit formation]
- [Source: ux-design-specification.md - The Sustainability / Streak Ring: circular progress indicator similar to Apple Fitness rings]
- [Source: ux-design-specification.md - Positive Reinforcement (The "Streak" Pattern): haptic vibration + floating snackbar overlay]
- [Source: ux-design-specification.md - Accent Color: #2563EB for primary buttons, streak flames, positive feedback]
- [Source: ux-design-specification.md - Core Navigation: 5 tabs: Home, Wardrobe, Add, Outfits, Profile]
- [Source: 6-1-style-points-rewards.md - user_stats table, gamification module, StylePointsToast, points in POST /v1/items, GET /v1/user-stats]
- [Source: 6-1-style-points-rewards.md - "Story 6.2 (Levels) will use a modal for level-up celebrations"]
- [Source: 6-1-style-points-rewards.md - "Future: gamification/level-service.js (Story 6.2)"]
- [Source: 6-1-style-points-rewards.md - 474 API tests, 949 Flutter tests after Story 6.1]
- [Source: infra/sql/migrations/016_user_stats.sql - existing user_stats schema]
- [Source: apps/api/src/modules/gamification/ - existing gamification module structure]
- [Source: apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart - current _buildProfileTab placeholder]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None required.

### Completion Notes List

- Task 1: Created migration 017_user_levels.sql with ALTER TABLE for current_level and current_level_name columns, plus recalculate_user_level RPC function with all 6 level thresholds, no-downgrade logic, and upsert semantics.
- Task 2: Created level-service.js with createLevelService factory and recalculateLevel method following existing service patterns.
- Task 3: Integrated levelService into createRuntime, handleRequest destructuring, and POST /v1/items route with best-effort try/catch wrapping.
- Task 4: Extended getUserStats in user-stats-repository.js to include current_level, current_level_name, live item count, and calculated nextLevelThreshold.
- Task 5: Created level-service.test.js with 17 tests covering all 6 thresholds, level-up detection, boundary conditions, nextLevelThreshold, and error handling.
- Task 6: Created level-endpoints.test.js with 6 integration tests for POST /v1/items levelUp field and GET /v1/user-stats level fields.
- Task 7: Updated user-stats-repository.test.js and gamification-endpoints.test.js to assert new level fields in responses.
- Task 8: Updated getUserStats() JSDoc in api_client.dart to document new response shape.
- Task 9: Created LevelUpModal widget with trophy icon, level name, congratulatory text, next level info, Continue button, Semantics label, scale-in animation via showGeneralDialog, and haptic feedback.
- Task 10: Created GamificationHeader widget with level name, level chip, LinearProgressIndicator progress bar, "Max Level Reached" state, and three stat chips (points, streak, items) with Semantics labels.
- Task 11: Created ProfileScreen StatefulWidget that loads user stats, displays GamificationHeader, handles loading/error/success states with retry, and includes subscription/delete-account/sign-out actions.
- Task 12: Replaced _buildProfileTab in MainShellScreen with ProfileScreen, passing notification settings callback. Removed unused imports.
- Task 13: Integrated showLevelUpModal into AddItemScreen after points toast with 500ms delay and mounted guard.
- Task 14: Created level_up_modal_test.dart with 8 widget tests.
- Task 15: Created gamification_header_test.dart with 9 widget tests.
- Task 16: Created profile_screen_test.dart with 6 widget tests (subscription button test omitted due to RevenueCat SDK coupling).
- Task 17: Added 3 integration tests to add_item_screen_test.dart for level-up modal flow.
- Task 18: flutter analyze shows zero new issues (5 pre-existing in wear_calendar_screen_test.dart). flutter test: 975 tests pass (949 existing + 26 new). npm test: 497 API tests pass (474 existing + 23 new). All existing tests pass.

### Change Log

- 2026-03-19: Implemented Story 6.2 - User Progression Levels. Added migration 017, level-service, level-up modal, gamification header, profile screen. Extended POST /v1/items and GET /v1/user-stats with level data.

### File List

New files:
- infra/sql/migrations/017_user_levels.sql
- apps/api/src/modules/gamification/level-service.js
- apps/api/test/modules/gamification/level-service.test.js
- apps/api/test/modules/gamification/level-endpoints.test.js
- apps/mobile/lib/src/features/profile/screens/profile_screen.dart
- apps/mobile/lib/src/features/profile/widgets/level_up_modal.dart
- apps/mobile/lib/src/features/profile/widgets/gamification_header.dart
- apps/mobile/test/features/profile/screens/profile_screen_test.dart
- apps/mobile/test/features/profile/widgets/level_up_modal_test.dart
- apps/mobile/test/features/profile/widgets/gamification_header_test.dart

Modified files:
- apps/api/src/main.js
- apps/api/src/modules/gamification/user-stats-repository.js
- apps/api/test/modules/gamification/user-stats-repository.test.js
- apps/api/test/modules/gamification/gamification-endpoints.test.js
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart
- apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart
- apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart
- apps/mobile/test/features/shell/screens/main_shell_screen_test.dart
- apps/mobile/test/widget_test.dart
