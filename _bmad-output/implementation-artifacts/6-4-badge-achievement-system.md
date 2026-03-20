# Story 6.4: Badge Achievement System

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to earn specific badges for reaching milestones (streaks, sustainability, resale, donations, wardrobe diversity),
so that I can showcase my sustainable fashion journey in a badge collection on my profile.

## Acceptance Criteria

1. Given the `badges` and `user_badges` tables do not yet exist, when migration 019 is applied, then the `app_public.badges` table is created with columns: `id UUID PK DEFAULT gen_random_uuid()`, `key TEXT NOT NULL UNIQUE` (machine name e.g., "streak_legend"), `name TEXT NOT NULL` (display name e.g., "Streak Legend"), `description TEXT NOT NULL` (e.g., "Maintain a 30-day outfit logging streak"), `icon_name TEXT NOT NULL` (Flutter Icons constant name e.g., "emoji_events"), `icon_color TEXT NOT NULL` (hex color e.g., "#FBBF24"), `category TEXT NOT NULL CHECK (category IN ('streak', 'wardrobe', 'sustainability', 'social', 'special'))`, `sort_order INTEGER NOT NULL DEFAULT 0`, `created_at TIMESTAMPTZ DEFAULT now()`. The `app_public.user_badges` table is created with columns: `id UUID PK DEFAULT gen_random_uuid()`, `profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE`, `badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE`, `awarded_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `UNIQUE(profile_id, badge_id)`. RLS is enabled on `user_badges`, allowing users to read only their own rows. The `badges` table is readable by all authenticated users (public catalog). An index exists on `user_badges(profile_id)`. (FR-GAM-04, FR-GAM-06)

2. Given migration 019 is applied, when seed data is inserted, then the following 15 badge definitions exist in the `badges` table: **First Step** (key: "first_step", upload first item, category: wardrobe, icon: star, #FBBF24), **Closet Complete** (key: "closet_complete", reach 50 items, category: wardrobe, icon: checkroom, #2563EB), **Week Warrior** (key: "week_warrior", 7-day streak, category: streak, icon: local_fire_department, #F97316), **Streak Legend** (key: "streak_legend", 30-day streak, category: streak, icon: local_fire_department, #EF4444), **Early Bird** (key: "early_bird", log outfit before 8 AM, category: special, icon: wb_sunny, #FBBF24), **Rewear Champion** (key: "rewear_champion", 50 total re-wears across all items, category: sustainability, icon: recycling, #10B981), **Circular Seller** (key: "circular_seller", list 1+ item for resale, category: sustainability, icon: sell, #8B5CF6), **Circular Champion** (key: "circular_champion", sell 10+ items, category: sustainability, icon: sell, #8B5CF6), **Generous Giver** (key: "generous_giver", donate 20+ items, category: sustainability, icon: volunteer_activism, #EC4899), **Monochrome Master** (key: "monochrome_master", log 5 single-color outfits, category: special, icon: palette, #6B7280), **Rainbow Warrior** (key: "rainbow_warrior", own items in 7+ colors, category: wardrobe, icon: palette, #EF4444), **OG Member** (key: "og_member", account age >= 365 days, category: special, icon: verified, #2563EB), **Weather Warrior** (key: "weather_warrior", log outfits in all 4 season types, category: special, icon: thunderstorm, #0EA5E9), **Style Guru** (key: "style_guru", reach level 5 "Style Expert", category: wardrobe, icon: school, #8B5CF6), **Eco Warrior** (key: "eco_warrior", sustainability score >= 80, category: sustainability, icon: eco, #10B981). (FR-GAM-04, FR-SUS-05)

3. Given a user performs an action that satisfies a badge criterion, when the system evaluates badge eligibility (via atomic RPC `app_public.evaluate_badges(p_profile_id UUID)`), then any newly earned badges are inserted into `user_badges`. The RPC checks ALL badge criteria in a single call, only inserts badges the user does not already have, and returns the list of newly awarded badge keys. Badge evaluation is idempotent -- calling it multiple times with the same state produces no duplicates due to the UNIQUE(profile_id, badge_id) constraint. (FR-GAM-04, FR-GAM-06)

4. Given badge evaluation is triggered, when the user earns one or more new badges, then the API response includes a `badgesAwarded` array of objects: `[{ key, name, description, iconName, iconColor }]`. If no new badges were earned, `badgesAwarded` is an empty array. Badge evaluation failures are best-effort (wrapped in try/catch) and do NOT fail the primary action. (FR-GAM-04)

5. Given badge evaluation needs to run, when any of the following API endpoints complete successfully, then `evaluate_badges` is called: `POST /v1/items` (checks: first_step, closet_complete, rainbow_warrior, style_guru), `POST /v1/wear-logs` (checks: week_warrior, streak_legend, early_bird, rewear_champion, monochrome_master, weather_warrior), `GET /v1/user-stats` (checks: og_member, eco_warrior -- lazy evaluation on profile load). Resale and donation badges (circular_seller, circular_champion, generous_giver) will be evaluated when those features are implemented in Epic 7/13; for now the badge definitions exist but are not evaluable. (FR-GAM-04)

6. Given a user visits the Profile tab, when the profile screen loads, then the `GamificationHeader` (or a new section below it) displays a "Badge Collection" grid showing ALL 15 badges. Earned badges are fully colored/illuminated with their `icon_color`. Unearned badges are grayed out (icon in #D1D5DB, name in #9CA3AF). Each badge shows: the icon, the badge name below, and a subtle glow/border on earned badges. Tapping an earned badge opens a `BadgeDetailSheet` bottom sheet showing: badge name, description, earned date ("Earned on [date]"), and the badge icon prominently. Tapping an unearned badge shows the description and requirement ("Log outfits for 30 consecutive days to earn this badge"). The grid uses 3 columns with consistent spacing. (FR-GAM-04, FR-GAM-05)

7. Given a user earns a new badge during an action (item upload or wear log), when the mobile client receives a non-empty `badgesAwarded` array, then a celebratory badge modal is displayed showing: the badge icon (large, colored), the badge name, the badge description, and a "Continue" button. If multiple badges are earned simultaneously, they are shown one at a time (dismiss first to see next). The modal uses a scale-in animation and haptic feedback (medium impact). The badge modal appears AFTER the points toast and streak toast (with a 1000ms delay from the last toast). (FR-GAM-04, FR-GAM-05)

8. Given the `GET /v1/user-stats` endpoint exists, when it is called, then the response now also includes a `badges` array: `[{ key, name, description, iconName, iconColor, category, awardedAt }]` containing all earned badges for the user, plus a `badgeCount` integer (total earned). Additionally, a new endpoint `GET /v1/badges` returns the full badge catalog: `[{ key, name, description, iconName, iconColor, category, sortOrder }]` (all 15 badge definitions, no auth required beyond basic authentication). (FR-GAM-04, FR-GAM-05, FR-GAM-06)

9. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (528+ API tests, 996+ Flutter tests) and new tests cover: migration 019 (badges + user_badges tables, seed data, RLS), evaluate_badges RPC for each of the 10 evaluable badge criteria, badge-service unit tests, badge endpoints (GET /v1/badges, GET /v1/user-stats badges field, badgesAwarded in POST responses), BadgeCollectionGrid widget, BadgeDetailSheet widget, BadgeAwardedModal widget, ProfileScreen badge integration, and badge modal in item upload and wear log flows.

## Tasks / Subtasks

- [x] Task 1: Database -- Create migration 019 for badges and user_badges tables (AC: 1, 2)
  - [x] 1.1: Create `infra/sql/migrations/019_badges.sql`. Create table `app_public.badges` with columns as specified in AC1. Create table `app_public.user_badges` with columns, UNIQUE constraint, and foreign keys as specified in AC1. Enable RLS on `user_badges`: policy allows users to SELECT their own rows (`profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id'))`). The `badges` table uses a simpler RLS policy: all authenticated users can SELECT (public catalog). Create index: `CREATE INDEX idx_user_badges_profile ON app_public.user_badges(profile_id)`.
  - [x] 1.2: Insert the 15 badge seed records into `app_public.badges` as specified in AC2. Use a single INSERT statement with all 15 rows. Set `sort_order` to preserve display order: First Step=1, Closet Complete=2, Week Warrior=3, Streak Legend=4, Early Bird=5, Rewear Champion=6, Circular Seller=7, Circular Champion=8, Generous Giver=9, Monochrome Master=10, Rainbow Warrior=11, OG Member=12, Weather Warrior=13, Style Guru=14, Eco Warrior=15.
  - [x] 1.3: Create the `app_public.evaluate_badges(p_profile_id UUID)` RPC function in PL/pgSQL. The function: (a) checks each badge criterion against current user data, (b) for each satisfied criterion where the user does NOT already have the badge, inserts into `user_badges`, (c) returns `TABLE(badge_key TEXT, badge_name TEXT, badge_description TEXT, badge_icon_name TEXT, badge_icon_color TEXT)` containing only NEWLY awarded badges. Badge criteria implementations:
    - **first_step**: `SELECT COUNT(*) >= 1 FROM app_public.items WHERE profile_id = p_profile_id`
    - **closet_complete**: `SELECT COUNT(*) >= 50 FROM app_public.items WHERE profile_id = p_profile_id`
    - **week_warrior**: `SELECT current_streak >= 7 OR longest_streak >= 7 FROM app_public.user_stats WHERE profile_id = p_profile_id`
    - **streak_legend**: `SELECT current_streak >= 30 OR longest_streak >= 30 FROM app_public.user_stats WHERE profile_id = p_profile_id`
    - **early_bird**: `SELECT COUNT(*) >= 1 FROM app_public.wear_logs WHERE profile_id = p_profile_id AND EXTRACT(HOUR FROM created_at) < 8`
    - **rewear_champion**: `SELECT COALESCE(SUM(wear_count), 0) >= 50 FROM app_public.items WHERE profile_id = p_profile_id AND wear_count > 1` (sum of wear_count for items worn more than once)
    - **monochrome_master**: `SELECT COUNT(*) >= 5 FROM app_public.outfits o WHERE o.profile_id = p_profile_id AND (SELECT COUNT(DISTINCT i.color) FROM app_public.outfit_items oi JOIN app_public.items i ON i.id = oi.item_id WHERE oi.outfit_id = o.id) = 1`
    - **rainbow_warrior**: `SELECT COUNT(DISTINCT color) >= 7 FROM app_public.items WHERE profile_id = p_profile_id`
    - **og_member**: `SELECT created_at <= NOW() - INTERVAL '365 days' FROM app_public.profiles WHERE id = p_profile_id`
    - **style_guru**: `SELECT current_level >= 5 FROM app_public.user_stats WHERE profile_id = p_profile_id`
    The remaining 5 badges (circular_seller, circular_champion, generous_giver, weather_warrior, eco_warrior) have placeholder checks that always return FALSE -- they depend on tables/data from future epics (resale_listings, donation_log, sustainability scores). Include a SQL comment: `-- TODO: Enable when Epic 7/11/13 tables exist`.

- [x] Task 2: API -- Create badge repository (AC: 3, 4, 8)
  - [x] 2.1: Create `apps/api/src/modules/badges/badge-repository.js` with `createBadgeRepository({ pool })`. Follow the factory pattern used by all other repositories. **Note:** This goes in `api/modules/badges/` per the architecture mapping, separate from `api/modules/gamification/`.
  - [x] 2.2: Implement `async getAllBadges()` method. Query: `SELECT key, name, description, icon_name, icon_color, category, sort_order FROM app_public.badges ORDER BY sort_order`. Map snake_case to camelCase. Returns the full badge catalog array.
  - [x] 2.3: Implement `async getUserBadges(authContext)` method. Query: `SELECT b.key, b.name, b.description, b.icon_name, b.icon_color, b.category, ub.awarded_at FROM app_public.user_badges ub JOIN app_public.badges b ON b.id = ub.badge_id WHERE ub.profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = $1) ORDER BY ub.awarded_at DESC`. Map to camelCase. Returns the user's earned badges array.
  - [x] 2.4: Implement `async evaluateBadges(authContext)` method. Look up `profile_id` from `profiles.firebase_uid`, then call `SELECT * FROM app_public.evaluate_badges($1)` with `[profileId]`. Return array of `{ key, name, description, iconName, iconColor }` for newly awarded badges.

- [x] Task 3: API -- Create badge service (AC: 3, 4, 5)
  - [x] 3.1: Create `apps/api/src/modules/badges/badge-service.js` with `createBadgeService({ badgeRepo })`. Follow the factory pattern.
  - [x] 3.2: Implement `async evaluateAndAward(authContext)` method. Calls `badgeRepo.evaluateBadges(authContext)`. Returns `{ badgesAwarded: [...] }`. If the array is empty, returns `{ badgesAwarded: [] }`.
  - [x] 3.3: Implement `async getBadgeCatalog()` method. Calls `badgeRepo.getAllBadges()`. Returns the full badge catalog.
  - [x] 3.4: Implement `async getUserBadgeCollection(authContext)` method. Calls `badgeRepo.getUserBadges(authContext)`. Returns `{ badges: [...], badgeCount: N }`.

- [x] Task 4: API -- Add badge endpoints and integrate into existing routes (AC: 4, 5, 8)
  - [x] 4.1: In `apps/api/src/main.js`, import `createBadgeRepository` and `createBadgeService`. In `createRuntime()`, instantiate `badgeRepo = createBadgeRepository({ pool })` and `badgeService = createBadgeService({ badgeRepo })`. Add both to the returned runtime object.
  - [x] 4.2: In `handleRequest`, add `badgeRepo` and `badgeService` to the destructuring.
  - [x] 4.3: Add route `GET /v1/badges`. Requires authentication (401 if unauthenticated). Calls `badgeService.getBadgeCatalog()`. Returns 200 with `{ badges: [...] }`. Place after `GET /v1/user-stats`.
  - [x] 4.4: Update `GET /v1/user-stats` route: after the existing stats fetch, call `badgeService.getUserBadgeCollection(authContext)`. Merge into the response: `{ stats: { ...existingStats, badges: [...], badgeCount: N } }`. Wrap in try/catch so badge failure does not break stats.
  - [x] 4.5: In the `POST /v1/items` route, after the existing points and level calls, add: `const badgeResult = await badgeService.evaluateAndAward(authContext)`. Include in the response: `badgesAwarded: badgeResult.badgesAwarded`. Wrap in try/catch (best-effort).
  - [x] 4.6: In the `POST /v1/wear-logs` route, after the existing points and streak calls, add: `const badgeResult = await badgeService.evaluateAndAward(authContext)`. Include in the response: `badgesAwarded: badgeResult.badgesAwarded`. Wrap in try/catch (best-effort).

- [x] Task 5: API -- Unit tests for badge repository (AC: 1, 2, 3, 8, 9)
  - [x] 5.1: Create `apps/api/test/modules/badges/badge-repository.test.js`:
    - `getAllBadges` returns all 15 badge definitions in sort order.
    - `getAllBadges` maps snake_case to camelCase.
    - `getUserBadges` returns empty array for user with no badges.
    - `getUserBadges` returns correct badges for user with earned badges.
    - `getUserBadges` returns badges ordered by awarded_at DESC.
    - `evaluateBadges` returns empty array when no new badges earned.
    - `evaluateBadges` returns newly awarded badge when criterion met (e.g., first_step after first item).
    - `evaluateBadges` is idempotent (calling twice returns empty on second call).
    - `evaluateBadges` awards multiple badges simultaneously when multiple criteria met.
    - RLS isolation: user A cannot read user B's badges.
    - `badges` table is readable by all authenticated users.

- [x] Task 6: API -- Unit tests for badge service (AC: 3, 4, 9)
  - [x] 6.1: Create `apps/api/test/modules/badges/badge-service.test.js`:
    - `evaluateAndAward` returns `{ badgesAwarded: [] }` when no badges earned.
    - `evaluateAndAward` returns `{ badgesAwarded: [{ key, name, ... }] }` when badge earned.
    - `getBadgeCatalog` returns all 15 badges.
    - `getUserBadgeCollection` returns correct badges and badgeCount.

- [x] Task 7: API -- Integration tests for badge endpoints (AC: 4, 5, 8, 9)
  - [x] 7.1: Create `apps/api/test/modules/badges/badge-endpoints.test.js`:
    - `GET /v1/badges` returns 200 with all 15 badge definitions.
    - `GET /v1/badges` returns 401 if unauthenticated.
    - `GET /v1/user-stats` includes `badges` array and `badgeCount`.
    - `GET /v1/user-stats` returns empty badges for new user.
    - `POST /v1/items` response includes `badgesAwarded` (e.g., first_step badge on first item).
    - `POST /v1/wear-logs` response includes `badgesAwarded`.
    - Badge evaluation failure does not break item creation.
    - Badge evaluation failure does not break wear log creation.
    - `evaluate_badges` RPC awards first_step badge correctly.
    - `evaluate_badges` RPC awards week_warrior when longest_streak >= 7.
    - `evaluate_badges` RPC does not re-award already earned badges.

- [x] Task 8: API -- Update existing gamification tests (AC: 9)
  - [x] 8.1: Update `apps/api/test/modules/gamification/gamification-endpoints.test.js`: add `badgeService` mock to the route handler setup. Verify `GET /v1/user-stats` response includes `badges` and `badgeCount` fields.
  - [x] 8.2: Verify existing `POST /v1/items` and `POST /v1/wear-logs` tests still pass with the added `badgesAwarded` field (additive, backward-compatible).

- [x] Task 9: Mobile -- Update ApiClient for badge data (AC: 6, 7, 8)
  - [x] 9.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<List<Map<String, dynamic>>> getBadgeCatalog()` method. Calls `GET /v1/badges` using `_authenticatedGet`. Returns the `badges` array from the response.
  - [x] 9.2: The existing `getUserStats()` method already returns the full response map -- the new `badges` and `badgeCount` fields will be available automatically. Add JSDoc documenting the new fields.

- [x] Task 10: Mobile -- Create BadgeCollectionGrid widget (AC: 6)
  - [x] 10.1: Create `apps/mobile/lib/src/features/profile/widgets/badge_collection_grid.dart` with a `BadgeCollectionGrid` StatelessWidget. Constructor accepts: `required List<Map<String, dynamic>> allBadges` (full catalog of 15), `required List<Map<String, dynamic>> earnedBadges` (user's earned badges), `void Function(Map<String, dynamic> badge, bool isEarned)? onBadgeTap`.
  - [x] 10.2: The widget renders a `GridView.count` with `crossAxisCount: 3`, `crossAxisSpacing: 12`, `mainAxisSpacing: 12`, `childAspectRatio: 0.8`. Each cell is a `BadgeCell` containing: the badge icon (`Icon` using `iconName` mapped to Flutter `IconData`, size 32px), colored with `iconColor` if earned or #D1D5DB if unearned, badge name below (12px, #1F2937 if earned, #9CA3AF if unearned), a subtle glow border on earned badges (1px solid `iconColor` at 30% opacity, 8px border radius). Tapping a cell calls `onBadgeTap`.
  - [x] 10.3: Map `iconName` strings to Flutter `IconData`: create a utility map `badgeIconMap` in the file: `{ "star": Icons.star, "checkroom": Icons.checkroom, "local_fire_department": Icons.local_fire_department, "wb_sunny": Icons.wb_sunny, "recycling": Icons.recycling, "sell": Icons.sell, "volunteer_activism": Icons.volunteer_activism, "palette": Icons.palette, "verified": Icons.verified, "thunderstorm": Icons.thunderstorm, "school": Icons.school, "eco": Icons.eco, "emoji_events": Icons.emoji_events }`. Use `Icons.help_outline` as fallback for unknown icon names.
  - [x] 10.4: Add `Semantics` label on each badge cell: "Badge: [name], [earned/locked]".

- [x] Task 11: Mobile -- Create BadgeDetailSheet widget (AC: 6)
  - [x] 11.1: Create `apps/mobile/lib/src/features/profile/widgets/badge_detail_sheet.dart` with a `BadgeDetailSheet` StatelessWidget. Constructor accepts: `required Map<String, dynamic> badge`, `required bool isEarned`, `String? awardedAt`.
  - [x] 11.2: The sheet renders as a modal bottom sheet containing: the badge icon (48px, colored if earned, gray if not), badge name (20px, bold, #1F2937), badge description (14px, #4B5563), and if earned: "Earned on [formatted date]" (12px, #10B981 green), if not earned: "Keep going! [description of requirement]" (12px, #9CA3AF).
  - [x] 11.3: Add `Semantics` labels. Add a top-level function `void showBadgeDetailSheet(BuildContext context, { required Map<String, dynamic> badge, required bool isEarned, String? awardedAt })` that shows the modal bottom sheet.

- [x] Task 12: Mobile -- Create BadgeAwardedModal widget (AC: 7)
  - [x] 12.1: Create `apps/mobile/lib/src/features/profile/widgets/badge_awarded_modal.dart` with a `BadgeAwardedModal` StatelessWidget. Constructor accepts: `required String name`, `required String description`, `required String iconName`, `required String iconColor`.
  - [x] 12.2: The modal renders as an `AlertDialog` with: the badge icon (64px, colored), "Badge Earned!" subtitle (14px, #6B7280), badge name as title (20px, bold, #1F2937), badge description (14px, #4B5563), and a "Continue" `FilledButton` to dismiss. Scale-in animation via `showGeneralDialog` with `ScaleTransition`. Haptic feedback via `HapticFeedback.mediumImpact()` when shown.
  - [x] 12.3: Add `Semantics` label: "Badge earned: [name]".
  - [x] 12.4: Create a top-level function `Future<void> showBadgeAwardedModals(BuildContext context, List<Map<String, dynamic>> badges)` that shows each badge modal sequentially -- await the first dialog to close before showing the next. Use `showGeneralDialog` for each.

- [x] Task 13: Mobile -- Integrate BadgeCollectionGrid into ProfileScreen (AC: 6)
  - [x] 13.1: In `apps/mobile/lib/src/features/profile/screens/profile_screen.dart`, add state for `_allBadges` (List) and `_earnedBadges` (List). In `_loadUserStats()`, also call `apiClient.getBadgeCatalog()` to fetch the badge catalog. Parse `badges` and `badgeCount` from the user stats response for earned badges. Store both in state.
  - [x] 13.2: In the profile screen body, add a "Badges" section header (16px, bold, #1F2937) with badge count ("N/15") below the GamificationHeader. Then render `BadgeCollectionGrid(allBadges: _allBadges, earnedBadges: _earnedBadges, onBadgeTap: _onBadgeTap)`.
  - [x] 13.3: Implement `_onBadgeTap(badge, isEarned)`: find the matching earned badge to get `awardedAt`, then call `showBadgeDetailSheet(context, badge: badge, isEarned: isEarned, awardedAt: awardedAt)`.
  - [x] 13.4: Handle loading and error states for badge data independently from stats -- if badges fail to load, show the gamification header without the badge grid and a "Unable to load badges" text with retry.

- [x] Task 14: Mobile -- Integrate badge modal into item upload flow (AC: 7)
  - [x] 14.1: In `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart`, after the existing points toast and level-up modal handling, check if the response contains `badgesAwarded` and the array is non-empty. If so, call `showBadgeAwardedModals(context, badgesAwarded)` with a 1000ms delay after the level-up modal (or after the points toast if no level-up). Guard with `mounted` check.

- [x] Task 15: Mobile -- Integrate badge modal into wear log flow (AC: 7)
  - [x] 15.1: In `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart` (or the wear log handling code), after the existing points toast and streak toast handling, check if the response contains `badgesAwarded` and the array is non-empty. If so, call `showBadgeAwardedModals(context, badgesAwarded)` with a 1000ms delay after the streak toast. Guard with `mounted` check.
  - [x] 15.2: Update `WearLogResult` in `wear_log_service.dart` to include `badgesAwarded` field. Parse from API response.

- [x] Task 16: Mobile -- Widget tests for BadgeCollectionGrid (AC: 6, 9)
  - [x] 16.1: Create `apps/mobile/test/features/profile/widgets/badge_collection_grid_test.dart`:
    - Renders 15 badge cells in a 3-column grid.
    - Earned badges show colored icon.
    - Unearned badges show gray icon (#D1D5DB).
    - Earned badges show glow border.
    - Badge name renders below icon.
    - Tapping a badge fires onBadgeTap callback with correct badge data and earned status.
    - Semantics labels present on each cell.
    - Unknown icon name falls back to help_outline.

- [x] Task 17: Mobile -- Widget tests for BadgeDetailSheet (AC: 6, 9)
  - [x] 17.1: Create `apps/mobile/test/features/profile/widgets/badge_detail_sheet_test.dart`:
    - Renders badge icon, name, description for earned badge.
    - Renders "Earned on [date]" for earned badge.
    - Renders "Keep going!" message for unearned badge.
    - Icon is colored for earned badge, gray for unearned.
    - Semantics labels present.

- [x] Task 18: Mobile -- Widget tests for BadgeAwardedModal (AC: 7, 9)
  - [x] 18.1: Create `apps/mobile/test/features/profile/widgets/badge_awarded_modal_test.dart`:
    - Renders badge icon, "Badge Earned!" text, name, description.
    - Renders "Continue" button.
    - Tapping "Continue" dismisses dialog.
    - Semantics label present.
    - showBadgeAwardedModals shows modals sequentially for multiple badges.

- [x] Task 19: Mobile -- Integration tests for badge display on profile (AC: 6, 9)
  - [x] 19.1: Update `apps/mobile/test/features/profile/screens/profile_screen_test.dart`:
    - Badge collection grid renders when stats and catalog load successfully.
    - Badge count shows "N/15".
    - Tapping earned badge opens detail sheet with earned date.
    - Tapping unearned badge opens detail sheet with requirement text.
    - Badge section shows error text when badge catalog fails to load.

- [x] Task 20: Mobile -- Integration tests for badge modals in action flows (AC: 7, 9)
  - [x] 20.1: Update `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart`:
    - After item creation with badgesAwarded in response, badge modal is displayed.
    - No modal when badgesAwarded is empty.
    - Badge modal appears after level-up modal.
  - [x] 20.2: Update `apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart`:
    - After wear log with badgesAwarded in response, badge modal is displayed.
    - No modal when badgesAwarded is empty.

- [x] Task 21: Regression testing (AC: all)
  - [x] 21.1: Run `flutter analyze` -- zero new issues.
  - [x] 21.2: Run `flutter test` -- all existing 996+ Flutter tests plus new tests pass.
  - [x] 21.3: Run `npm --prefix apps/api test` -- all existing 528+ API tests plus new tests pass.
  - [x] 21.4: Verify existing `POST /v1/items` tests still pass with the added `badgesAwarded` field.
  - [x] 21.5: Verify existing `POST /v1/wear-logs` tests still pass with the added `badgesAwarded` field.
  - [x] 21.6: Verify existing `GET /v1/user-stats` tests still pass with added `badges` and `badgeCount` fields.
  - [x] 21.7: Apply migration 019_badges.sql and verify tables, seed data, and RPC function work correctly.

## Dev Notes

- This is the **fourth story in Epic 6** (Gamification & Engagement). It builds on Story 6.1's `user_stats` table, Story 6.2's profile screen and gamification header, and Story 6.3's streak service to add the badge achievement system.
- This story implements **FR-GAM-04**: "The system shall award badges for achievements, including: First Step, Closet Complete, Week Warrior, Streak Legend (30 days), Early Bird, Rewear Champion (50 re-wears), Circular Seller (1+ listing), Circular Champion (10+ sold), Generous Giver (20+ donated), Monochrome Master, Rainbow Warrior, OG Member, Weather Warrior, Style Guru, Eco Warrior."
- This story implements **FR-GAM-06** (partial): "Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`)." The `badges` and `user_badges` tables are created here. The `user_stats` table was created in Story 6.1.
- This story implements **FR-SUS-05**: "An 'Eco Warrior' badge shall unlock at sustainability score >= 80." The badge definition is created but the evaluation is a placeholder (depends on sustainability scoring from Epic 11).
- This story implements **FR-RSL-09** and **FR-DON-04** badge definitions: "Circular Champion" (10+ sold) and "Generous Giver" (20+ donated). Badge definitions are created but evaluations are placeholders (depend on resale/donation features from Epic 7/13).
- This story partially implements **FR-GAM-05**: "The profile screen shall display: ... badge collection grid." The badge collection grid is added to the profile screen below the gamification header.
- **Of the 15 badges, 10 are evaluable in this story.** The remaining 5 (circular_seller, circular_champion, generous_giver, weather_warrior, eco_warrior) depend on features from future epics. Their badge definitions exist in the catalog (users can see them as locked), but the `evaluate_badges` RPC has placeholder FALSE checks for them. When those epics are implemented, the corresponding migration will update the RPC to add real checks.
- **Weather Warrior badge** requires logging outfits in all 4 season types. This requires season data on wear logs or outfits, which may not be available yet. If the `outfits` or `wear_logs` table does not have a season field, this badge evaluation should be a placeholder. Check the schema before implementing.
- **`evaluate_badges` is a single comprehensive RPC.** All badge checks happen in one database function call. This is efficient (single round-trip) and atomic. The function is idempotent -- the UNIQUE constraint on `(profile_id, badge_id)` prevents duplicates, and the function only returns newly inserted badges.
- **Badge repository goes in `api/modules/badges/`, not `api/modules/gamification/`.** The architecture maps Epic 6 to `api/modules/badges` alongside `api/modules/gamification`. Badges are a distinct domain from points/streaks/levels. Story 6.1 explicitly noted: "The `badges/` module (Story 6.4) will remain separate."
- **The `POST /v1/items` and `POST /v1/wear-logs` responses grow again.** After this story: `POST /v1/items` returns `{ item, pointsAwarded, levelUp, badgesAwarded }`. `POST /v1/wear-logs` returns `{ wearLog, pointsAwarded, streakUpdate, badgesAwarded }`. All new fields are additive and nullable/empty -- backward-compatible.

### Design Decision: Single evaluate_badges RPC

All badge criteria are checked in a single PL/pgSQL function rather than individual functions per badge. This is efficient (one DB call evaluates all badges) and maintainable (adding a new badge means adding one more check block). The function uses `INSERT INTO user_badges ... ON CONFLICT DO NOTHING` with a `RETURNING` clause to atomically grant and report new badges.

### Design Decision: Badge Catalog as Database Table

Badge definitions live in the `badges` table (not hardcoded in the API or mobile client). This allows:
1. Adding new badges via migration without API/mobile code changes.
2. The mobile client fetches the catalog dynamically, so new badges appear automatically.
3. Badge metadata (icon, color, description) can be updated via migration.

### Design Decision: Badge Module Separation

The badge module (`api/modules/badges/`) is separate from the gamification module (`api/modules/gamification/`). This follows the architecture mapping and provides clean separation: gamification handles points/streaks/levels (all in `user_stats`), badges handles badge definitions and grants (in `badges`/`user_badges`). The badge service depends on gamification data (checking `user_stats` for streak/level badges) but at the database level, not the API service level.

### Design Decision: Placeholder Badge Evaluations

Five badges depend on features from future epics (resale, donations, weather seasons, sustainability scores). Rather than omitting them, we create the badge definitions now so users can see the full collection (locked badges). The `evaluate_badges` RPC has FALSE placeholders for these, clearly commented. When Epic 7/11/13 are implemented, a migration updates the RPC.

### Project Structure Notes

- New SQL migration file:
  - `infra/sql/migrations/019_badges.sql` (badges table, user_badges table, seed data, evaluate_badges RPC, RLS policies)
- New API files:
  - `apps/api/src/modules/badges/badge-repository.js` (data access for badges and user_badges)
  - `apps/api/src/modules/badges/badge-service.js` (badge evaluation and catalog business logic)
  - `apps/api/test/modules/badges/badge-repository.test.js`
  - `apps/api/test/modules/badges/badge-service.test.js`
  - `apps/api/test/modules/badges/badge-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/profile/widgets/badge_collection_grid.dart` (badge grid + cell + icon mapping)
  - `apps/mobile/lib/src/features/profile/widgets/badge_detail_sheet.dart` (badge detail bottom sheet)
  - `apps/mobile/lib/src/features/profile/widgets/badge_awarded_modal.dart` (badge celebration modal)
  - `apps/mobile/test/features/profile/widgets/badge_collection_grid_test.dart`
  - `apps/mobile/test/features/profile/widgets/badge_detail_sheet_test.dart`
  - `apps/mobile/test/features/profile/widgets/badge_awarded_modal_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add badgeRepo, badgeService to createRuntime, handleRequest; add GET /v1/badges route; integrate badge evaluation into POST /v1/items, POST /v1/wear-logs; add badges to GET /v1/user-stats)
  - `apps/api/test/modules/gamification/gamification-endpoints.test.js` (add badgeService mock, verify badges in user-stats)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add getBadgeCatalog method)
  - `apps/mobile/lib/src/features/profile/screens/profile_screen.dart` (add badge collection grid, badge state, badge tap handling)
  - `apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart` (add badge modal after item creation)
  - `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart` (add badge modal after wear log)
  - `apps/mobile/lib/src/features/analytics/services/wear_log_service.dart` (extend WearLogResult with badgesAwarded)
  - `apps/mobile/test/features/profile/screens/profile_screen_test.dart` (add badge grid tests)
  - `apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart` (add badge modal tests)
  - `apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart` (add badge modal tests)
- Directory structure after this story:
  ```
  apps/api/src/modules/badges/
  ├── badge-repository.js (NEW)
  └── badge-service.js (NEW)

  apps/api/test/modules/badges/
  ├── badge-repository.test.js (NEW)
  ├── badge-service.test.js (NEW)
  └── badge-endpoints.test.js (NEW)

  apps/api/src/modules/gamification/
  ├── user-stats-repository.js (unchanged)
  ├── style-points-service.js (unchanged)
  ├── level-service.js (unchanged)
  └── streak-service.js (unchanged)

  apps/mobile/lib/src/features/profile/widgets/
  ├── gamification_header.dart (unchanged)
  ├── level_up_modal.dart (unchanged)
  ├── streak_celebration_toast.dart (unchanged)
  ├── streak_detail_sheet.dart (unchanged)
  ├── badge_collection_grid.dart (NEW)
  ├── badge_detail_sheet.dart (NEW)
  └── badge_awarded_modal.dart (NEW)
  ```

### Technical Requirements

- **Database table `badges`:** Public catalog of badge definitions. RLS allows all authenticated users to SELECT. No INSERT/UPDATE/DELETE for regular users. 15 seed records inserted in migration.
- **Database table `user_badges`:** Junction table linking users to earned badges. RLS allows users to SELECT only their own rows. UNIQUE(profile_id, badge_id) prevents duplicate grants. Foreign key cascade on profile deletion.
- **Database RPC `evaluate_badges`:** PL/pgSQL function that checks all 10 evaluable badge criteria, uses `INSERT INTO user_badges ... ON CONFLICT (profile_id, badge_id) DO NOTHING RETURNING ...` to atomically grant new badges. Returns only newly awarded badges. Must be idempotent and safe under concurrent calls.
- **RLS pattern:** Identical to existing tables. `user_badges` uses `profile_id = (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id'))`. `badges` allows all authenticated SELECT.
- **Repository pattern:** Factory function `createBadgeRepository({ pool })` returning an object with async methods. Uses `pool.connect()` -> `set_config` -> query -> `client.release()` in try/finally. Maps snake_case to camelCase.
- **Service pattern:** Factory function `createBadgeService({ badgeRepo })` accepting repository dependency. Contains business logic. Does not access `pool` directly.
- **API response extensions:** `POST /v1/items` gains `badgesAwarded` array. `POST /v1/wear-logs` gains `badgesAwarded` array. `GET /v1/user-stats` gains `badges` array and `badgeCount`. `GET /v1/badges` is a new endpoint. All additive and backward-compatible.
- **Icon mapping:** Mobile client maps `icon_name` strings from the API to Flutter `IconData` constants. A static map in `badge_collection_grid.dart` handles this. Unknown icons fall back to `Icons.help_outline`.
- **Badge modal sequencing:** Badges appear AFTER points toast, level-up modal, and streak toast. Use a 1000ms delay from the last preceding notification. Multiple badges are shown sequentially using `await` between `showGeneralDialog` calls.

### Architecture Compliance

- **Server authority for gamification:** Badge evaluation and grants happen server-side via database RPC. The mobile client does not determine badge eligibility.
- **Atomic RPCs:** Badge grants use `INSERT ... ON CONFLICT DO NOTHING` inside the RPC for transactional consistency. Follows the architecture principle: "atomic RPCs for wear counts, badge grants."
- **RLS enforces data isolation:** Users can only read their own `user_badges` rows. Badge definitions are a public catalog.
- **Mobile boundary owns presentation:** The API returns badge data. The client handles grid rendering, detail sheets, modals, animation, and haptic feedback.
- **Optimistic UI allowed for badge feedback:** Architecture states "Optimistic UI is allowed for... badge/streak feedback."
- **API module placement:** Badge services go in `apps/api/src/modules/badges/` per the architecture mapping: "Epic 6 Gamification -> api/modules/badges."
- **JSON REST over HTTPS:** `GET /v1/badges` and extended endpoints follow existing API naming conventions.
- **Graceful degradation:** Badge evaluation failure does not break core actions (item creation, wear logging, stats fetching).

### Library / Framework Requirements

- No new dependencies for mobile or API.
- Mobile uses existing: `flutter/material.dart` (GridView, AlertDialog, BottomSheet, Icon, Container), `flutter/services.dart` (HapticFeedback).
- API uses existing: `pg` (via `pool`).

### File Structure Requirements

- New API module directory: `apps/api/src/modules/badges/` (per architecture mapping, separate from gamification).
- New API test directory: `apps/api/test/modules/badges/`.
- New mobile widgets in `apps/mobile/lib/src/features/profile/widgets/` (created in Story 6.2).
- New mobile tests in `apps/mobile/test/features/profile/widgets/`.
- Test files mirror source structure.

### Testing Requirements

- **Database migration tests** must verify:
  - `badges` table created with 15 seed records
  - `user_badges` table created with correct constraints (UNIQUE, FK cascade)
  - RLS on `user_badges` prevents cross-user access
  - RLS on `badges` allows all authenticated users to read
  - `evaluate_badges` RPC: first_step badge awarded after first item
  - `evaluate_badges` RPC: closet_complete badge awarded at 50 items
  - `evaluate_badges` RPC: week_warrior badge awarded at 7-day streak
  - `evaluate_badges` RPC: streak_legend badge awarded at 30-day streak
  - `evaluate_badges` RPC: style_guru badge awarded at level 5
  - `evaluate_badges` RPC: rainbow_warrior badge awarded with 7+ colors
  - `evaluate_badges` RPC: idempotent (no duplicates on repeated calls)
  - `evaluate_badges` RPC: returns empty when no new badges
  - `evaluate_badges` RPC: awards multiple badges in single call
  - Placeholder badges (circular_seller, etc.) are never awarded
- **API repository tests** must verify:
  - `getAllBadges` returns full catalog in order
  - `getUserBadges` returns correct earned badges
  - `evaluateBadges` grants and returns new badges
  - RLS isolation between users
- **API service tests** must verify:
  - `evaluateAndAward` returns correct structure
  - `getBadgeCatalog` returns all badges
  - `getUserBadgeCollection` returns badges with count
- **API endpoint tests** must verify:
  - `GET /v1/badges` returns catalog
  - `GET /v1/user-stats` includes badge data
  - `POST /v1/items` includes `badgesAwarded`
  - `POST /v1/wear-logs` includes `badgesAwarded`
  - Badge failure does not break primary actions
- **Mobile widget tests** must verify:
  - BadgeCollectionGrid renders 15 cells, earned colored, unearned gray
  - BadgeDetailSheet renders correct info for earned/unearned
  - BadgeAwardedModal renders icon, name, description, dismiss button
  - ProfileScreen shows badge grid with catalog and earned badges
  - Badge modals appear in item upload and wear log flows when badgesAwarded non-empty
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 996+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 528+ tests plus new tests pass)
  - Existing endpoint tests still pass with new additive fields

### Previous Story Intelligence

- **Story 6.3** (done) established: Migration 018 (evaluate_streak RPC), `streak-service.js`, `StreakCelebrationToast`, `StreakDetailSheet`, updated `GamificationHeader` with freeze indicator. `createRuntime()` returns 22 services (includes `userStatsRepo`, `stylePointsService`, `levelService`, `streakService`). Test counts: 528 API tests, 996 Flutter tests. `POST /v1/wear-logs` returns `{ wearLog, pointsAwarded, streakUpdate }`. `GET /v1/user-stats` returns `{ stats: { totalPoints, currentStreak, longestStreak, lastStreakDate, streakFreezeUsedAt, streakFreezeAvailable, currentLevel, currentLevelName, nextLevelThreshold, itemCount } }`.
- **Story 6.2** (done) established: Migration 017 (level columns + recalculate_user_level RPC), `level-service.js`, `ProfileScreen` (StatefulWidget loading stats, error/loading/success states), `GamificationHeader`, `LevelUpModal`. `POST /v1/items` returns `{ item, pointsAwarded, levelUp }`.
- **Story 6.1** (done) established: Migration 016 (`user_stats` table), `user-stats-repository.js`, `style-points-service.js`, `StylePointsToast`, `GET /v1/user-stats`, `api/modules/gamification/` directory. Explicitly stated: "The `badges/` module (Story 6.4) will remain separate as it manages badge definitions and grants." and "DO NOT create `badges` or `user_badges` tables."
- **Story 6.1 design decisions relevant to 6.4:**
  - "This story also partially implements FR-GAM-06 -- specifically the user_stats table. The badges and user_badges tables are deferred to Story 6.4."
  - "Badge Achievement System (FR-GAM-04, FR-GAM-06 partial): Story 6.4."
  - The `api/modules/badges/` directory was anticipated but not created. This story creates it.
- **Story 6.3 completion notes:** 528 API tests, 996 Flutter tests. `evaluate_streak` refactored points to use pre-computed `isStreakDay`. Toast sequencing: points toast -> streak toast (500ms delay).
- **Existing database schema relevant to badge evaluation:**
  - `items` table: `profile_id`, `wear_count`, `color`, `category` (used for first_step, closet_complete, rewear_champion, rainbow_warrior)
  - `user_stats` table: `current_streak`, `longest_streak`, `current_level` (used for week_warrior, streak_legend, style_guru)
  - `wear_logs` table: `profile_id`, `created_at`, `logged_date` (used for early_bird)
  - `outfits` + `outfit_items` tables: `outfit_id`, `item_id` (used for monochrome_master)
  - `profiles` table: `id`, `created_at` (used for og_member)
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Factory pattern for repositories and services.
  - Database RPC functions for atomic operations.
  - Toast/modal sequencing with delays (points -> streak 500ms, points -> level-up 500ms).
  - Best-effort gamification (try/catch, does not break primary action).

### Key Anti-Patterns to Avoid

- DO NOT compute badge eligibility client-side. All badge evaluation happens server-side in the `evaluate_badges` RPC.
- DO NOT make badge evaluation blocking. If badge evaluation fails, the primary action (item creation, wear logging, stats fetching) must still succeed. Wrap in try/catch and log errors.
- DO NOT put badge repository/service in `api/modules/gamification/`. Use `api/modules/badges/` per architecture mapping and Story 6.1's design note.
- DO NOT hardcode badge definitions in the API or mobile client. Badge definitions live in the `badges` database table and are fetched dynamically.
- DO NOT evaluate resale, donation, weather_warrior, or eco_warrior badges -- these depend on features from future epics. Use placeholder FALSE checks in the RPC.
- DO NOT create individual RPC functions per badge. Use a single `evaluate_badges` function that checks all criteria.
- DO NOT allow `user_badges` to have duplicate (profile_id, badge_id) pairs. The UNIQUE constraint and `ON CONFLICT DO NOTHING` prevent this.
- DO NOT remove or modify any existing gamification code (points, levels, streaks). Badge evaluation is additive -- it reads from `user_stats`, `items`, `wear_logs`, `outfits` but does not modify them.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT modify existing API test expectations to require the new fields (`badgesAwarded`, `badges`, `badgeCount`). Existing tests should continue to pass -- new fields are additive.
- DO NOT create a separate "grant badge" API endpoint. Badge grants happen automatically via `evaluate_badges` called from existing endpoints. There is no user-initiated badge granting.
- DO NOT show badge modals for empty `badgesAwarded` arrays. Only show when the array has elements.
- DO NOT implement the Eco Warrior sustainability score calculation. The badge definition exists but evaluation is a placeholder. Sustainability scoring is Epic 11.

### Out of Scope

- **Circular Seller, Circular Champion badge evaluation:** Depends on `resale_listings` table (Epic 7). Badge definitions exist, evaluation is placeholder.
- **Generous Giver badge evaluation:** Depends on `donation_log` table (Epic 13). Badge definition exists, evaluation is placeholder.
- **Weather Warrior badge evaluation:** Depends on season tracking per outfit/wear log. Badge definition exists, evaluation is placeholder.
- **Eco Warrior badge evaluation:** Depends on sustainability score calculation (Epic 11). Badge definition exists, evaluation is placeholder.
- **Challenge Rewards / Closet Safari Premium Trial (FR-ONB-03, FR-ONB-04):** Story 6.5.
- **Push notifications for badge awards:** In-app modals only. Push notifications for badges are not in FR-GAM-04.
- **Badge sharing or social display:** Not specified in any FR.
- **Badge animation (Rive):** UX spec mentions "Flutter + Rive pattern." For V1, standard Material scale-in animation suffices.
- **Badge leaderboard or comparison:** Not specified in any FR.
- **Dark mode for badge widgets:** Follow existing app convention (light mode only for MVP).

### References

- [Source: epics.md - Story 6.4: Badge Achievement System]
- [Source: epics.md - FR-GAM-04: The system shall award badges for achievements, including: First Step, Closet Complete, Week Warrior, Streak Legend, Early Bird, Rewear Champion, Circular Seller, Circular Champion, Generous Giver, Monochrome Master, Rainbow Warrior, OG Member, Weather Warrior, Style Guru, Eco Warrior]
- [Source: epics.md - FR-GAM-05: The profile screen shall display: current level, XP progress bar, current streak, total points, badge collection grid, and recent activity feed]
- [Source: epics.md - FR-GAM-06: Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`)]
- [Source: epics.md - FR-SUS-05: An "Eco Warrior" badge shall unlock at sustainability score >= 80]
- [Source: epics.md - FR-RSL-09: Selling 10+ items shall unlock the "Circular Champion" badge]
- [Source: epics.md - FR-DON-04: Donating 20+ items shall unlock the "Generous Giver" badge]
- [Source: prd.md - Gamification: Style points, levels, streaks, badges, profile stats]
- [Source: architecture.md - Data Architecture: user_stats, badges, user_badges tables]
- [Source: architecture.md - Database rules: atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments]
- [Source: architecture.md - Server authority for sensitive rules: badge grants enforced server-side]
- [Source: architecture.md - Epic 6 Gamification -> mobile/features/profile, api/modules/analytics, api/modules/badges]
- [Source: architecture.md - Optimistic UI allowed for badge/streak feedback]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: ux-design-specification.md - Accomplishment: Use gamification (badges, streaks, progress bars) during onboarding and for wear-logging]
- [Source: ux-design-specification.md - Duolingo / Apple Fitness (Gamification): streak and badge elements drive daily habit formation]
- [Source: 6-1-style-points-rewards.md - "The badges/ module (Story 6.4) will remain separate as it manages badge definitions and grants"]
- [Source: 6-1-style-points-rewards.md - "Badge Achievement System (FR-GAM-04, FR-GAM-06 partial): Story 6.4"]
- [Source: 6-2-user-progression-levels.md - ProfileScreen, GamificationHeader, profile feature directory structure]
- [Source: 6-3-streak-tracking-freezes.md - 528 API tests, 996 Flutter tests, evaluate_streak RPC, streakService]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented migration 019_badges.sql with badges table, user_badges table, 15 seed badges, evaluate_badges RPC with 10 evaluable criteria and 5 placeholders
- Created badge-repository.js with getAllBadges, getUserBadges, evaluateBadges methods following existing factory pattern
- Created badge-service.js with evaluateAndAward, getBadgeCatalog, getUserBadgeCollection methods
- Integrated badge service into main.js: createRuntime, handleRequest destructuring, GET /v1/badges route, badge evaluation in POST /v1/items and POST /v1/wear-logs, badge data in GET /v1/user-stats
- All badge operations are best-effort (try/catch) and do not break primary actions
- Updated existing gamification-endpoints.test.js with badgeService mock to maintain backward compatibility
- Created BadgeCollectionGrid with 3-column grid, earned/unearned styling, icon mapping, and Semantics labels
- Created BadgeDetailSheet with earned date display and "Keep going!" encouragement for unearned badges
- Created BadgeAwardedModal with scale-in animation and haptic feedback, sequential display for multiple badges
- Integrated badge grid into ProfileScreen with independent error handling for badge catalog loading
- Integrated badge modals into AddItemScreen (after level-up modal, 1000ms delay) and LogOutfitBottomSheet (after streak toast, 1000ms delay)
- Extended WearLogResult with badgesAwarded field
- All 554 API tests pass (528 baseline + 26 new badge tests)
- All 1022 Flutter tests pass (996 baseline + 26 new badge tests)
- flutter analyze: zero new issues (5 pre-existing warnings from unrelated files)

### Change Log

- 2026-03-19: Story 6.4 Badge Achievement System implemented. Added badges + user_badges tables (migration 019), badge repository/service, badge endpoints, BadgeCollectionGrid, BadgeDetailSheet, BadgeAwardedModal, and full test coverage.

### File List

New files:
- infra/sql/migrations/019_badges.sql
- apps/api/src/modules/badges/badge-repository.js
- apps/api/src/modules/badges/badge-service.js
- apps/api/test/modules/badges/badge-repository.test.js
- apps/api/test/modules/badges/badge-service.test.js
- apps/api/test/modules/badges/badge-endpoints.test.js
- apps/mobile/lib/src/features/profile/widgets/badge_collection_grid.dart
- apps/mobile/lib/src/features/profile/widgets/badge_detail_sheet.dart
- apps/mobile/lib/src/features/profile/widgets/badge_awarded_modal.dart
- apps/mobile/test/features/profile/widgets/badge_collection_grid_test.dart
- apps/mobile/test/features/profile/widgets/badge_detail_sheet_test.dart
- apps/mobile/test/features/profile/widgets/badge_awarded_modal_test.dart

Modified files:
- apps/api/src/main.js
- apps/api/test/modules/gamification/gamification-endpoints.test.js
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/profile/screens/profile_screen.dart
- apps/mobile/lib/src/features/wardrobe/screens/add_item_screen.dart
- apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart
- apps/mobile/lib/src/features/analytics/services/wear_log_service.dart
- apps/mobile/test/features/profile/screens/profile_screen_test.dart
- apps/mobile/test/features/wardrobe/screens/add_item_screen_test.dart
- apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart
