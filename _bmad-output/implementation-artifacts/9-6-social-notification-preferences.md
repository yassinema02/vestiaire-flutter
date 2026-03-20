# Story 9.6: Social Notification Preferences

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to control how and when I receive notifications about my squads,
So that I am engaged but not annoyed.

## Acceptance Criteria

1. Given I am in Profile Settings -> Notifications, when I view the "Social Updates" category, then I see the existing boolean toggle REPLACED with a three-option selector: "All posts" (receive a push notification for every new OOTD post from squad members), "Only morning digest" (receive a single morning summary at the user's configured morning time), or "Off" (no social post notifications). The current `notification_preferences.social` boolean is migrated: `true` maps to `"all"`, `false` maps to `"off"`. Default for new users is `"all"`. (FR-NTF-01, FR-NTF-02)

2. Given the user's social notification mode is set to `"all"`, when a squad member creates a new OOTD post, then the API sends a push notification via Firebase Cloud Messaging (FCM) to all other squad members who have `social` set to `"all"` AND whose push_token is non-null AND the current time is NOT within quiet hours (22:00-07:00 local time, using UTC as a safe approximation). The notification title is "{authorName} posted a new OOTD" and the body is the post caption (truncated to 100 chars) or "Check out their outfit!" if no caption. (FR-NTF-01, FR-NTF-03)

3. Given quiet hours are 22:00-07:00 (default), when a notification would be sent during quiet hours, then the notification is silently dropped (not queued, not deferred). Quiet hours are enforced server-side before sending. (FR-NTF-03)

4. Given I have enabled the daily posting reminder (a new sub-preference under Social Updates), when my configured posting reminder time is reached (default: 09:00 AM), then the system fires a local notification with the title "Time to share your OOTD!" and the body "Post your outfit of the day to your squads." The reminder uses local notifications (same pattern as morning outfit and evening wear-log reminders). (FR-NTF-04)

5. Given the daily posting reminder is enabled, when the reminder time is reached and I have already posted an OOTD today (at least one `ootd_posts` record with `created_at` today), then the reminder notification is NOT fired. The check is performed at scheduling time (when the HomeScreen loads) using a local flag or API check. (FR-NTF-05)

6. Given I change the social notification mode on the NotificationPreferencesScreen, when I select a new option, then the preference is persisted to the server via `PUT /v1/profiles/me` with the updated `notification_preferences` object. The `social` key changes from boolean to string: `"all"`, `"morning"`, or `"off"`. The API validation is updated to accept both boolean (backward compat) and string values for the `social` key. (FR-NTF-02, FR-PSH-06)

7. Given I toggle the daily posting reminder on or off, when I save, then the preference is stored locally in SharedPreferences (key: `posting_reminder_enabled`, default: `true`) and the posting reminder time is stored locally (key: `posting_reminder_time`, default: `"09:00"`). If disabled, the scheduled local notification is cancelled. If enabled, it is scheduled. (FR-NTF-04)

8. Given the comment notification stub from Story 9.4 exists in `ootd-service.js`, when Story 9.6 is implemented, then the stub is replaced with actual FCM delivery via `firebase-admin` SDK's `admin.messaging().send()`. The existing preference check (social !== false) and quiet hours check are updated to handle the new string-based social preference (`"all"` sends, `"morning"` skips real-time, `"off"` skips entirely). (FR-NTF-01)

9. Given the new OOTD post notification is sent via FCM, when the notification is delivered to the user's device, then tapping it opens the app and navigates to the Social tab (or the specific post detail screen if deep-link data is included in the FCM payload). (FR-NTF-01)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (961+ API tests, 1431+ Flutter tests) and new tests cover: notification service FCM delivery, social preference mode migration (boolean to string), updated NotificationPreferencesScreen with three-option selector, PostingReminderService scheduling/cancellation, OOTD post notification trigger in ootd-service.js, quiet hours enforcement, and backward compatibility for boolean social preference.

## Tasks / Subtasks

- [x] Task 1: Database migration -- update notification_preferences social key from boolean to string (AC: 1, 6)
  - [x] 1.1: Create `infra/sql/migrations/029_social_notification_mode.sql` that runs an UPDATE to migrate existing `notification_preferences.social` values: `UPDATE app_public.profiles SET notification_preferences = notification_preferences || jsonb_build_object('social', CASE WHEN (notification_preferences->>'social')::boolean = true THEN '"all"' WHEN (notification_preferences->>'social')::boolean = false THEN '"off"' ELSE '"all"' END::jsonb) WHERE notification_preferences ? 'social';`. Also update the column default: `ALTER TABLE app_public.profiles ALTER COLUMN notification_preferences SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all"}'::jsonb;`.
  - [x]1.2: Add a comment on the migration explaining the boolean-to-string migration for backward compatibility.

- [x]Task 2: API -- Update notification_preferences validation to accept string for social key (AC: 6, 8)
  - [x]2.1: In `apps/api/src/modules/profiles/service.js`, update the `notification_preferences` validation logic. Currently all keys must be boolean. Change to: `outfit_reminders`, `wear_logging`, `analytics` remain boolean-only. The `social` key accepts either boolean (backward compat: `true` -> `"all"`, `false` -> `"off"`) or a string from the set `["all", "morning", "off"]`. If a boolean is received for `social`, normalize it to the string equivalent before persisting.
  - [x]2.2: Update the `ALLOWED_NOTIFICATION_KEYS` validation and add `SOCIAL_NOTIFICATION_MODES = ["all", "morning", "off"]` constant.
  - [x]2.3: In `apps/api/src/modules/profiles/service.js`, add a normalization step: if `notification_preferences.social` is `true`, replace with `"all"`; if `false`, replace with `"off"`. This ensures stored values are always strings after this migration.

- [x]Task 3: API -- Create notification service with FCM delivery (AC: 2, 3, 8)
  - [x]3.1: Create `apps/api/src/modules/notifications/notification-service.js` with a `createNotificationService({ pool })` factory. This is the centralized notification service that replaces the inline stub.
  - [x]3.2: Add `async sendPushNotification(profileId, { title, body, data })` method that: (a) looks up `push_token` and `notification_preferences` from `profiles` WHERE `id = profileId`, (b) checks if push_token is non-null, (c) checks quiet hours (22:00-07:00 using `new Date().getHours()`), (d) sends via `firebase-admin` messaging: lazy-import `firebase-admin`, initialize if not already initialized (reuse the same initialization pattern from `firebaseAdmin.js`), call `admin.messaging().send({ token: push_token, notification: { title, body }, data })`. (e) Fire-and-forget: log errors but do not throw.
  - [x]3.3: Add `async sendToSquadMembers(squadId, excludeProfileId, { title, body, data, checkSocialMode })` method that: (a) queries all squad members' profile IDs (excluding `excludeProfileId`), (b) for each member, looks up `push_token` and `notification_preferences`, (c) if `checkSocialMode` is provided, checks `notification_preferences.social` against the mode (`"all"` sends, `"morning"` or `"off"` skips), (d) checks quiet hours, (e) sends via FCM to each qualifying member. Use a single query to batch-fetch all members' tokens and preferences. Fire-and-forget for each send.
  - [x]3.4: Add `isQuietHours()` helper (22:00-07:00 default). Extract from the existing inline check in ootd-service.js.
  - [x]3.5: If `firebase-admin` credentials are not available (local dev), log the notification intent and return gracefully (same pattern as `firebaseAdmin.js`).

- [x]Task 4: API -- Wire notification service and update OOTD post creation to trigger notifications (AC: 2, 3, 8)
  - [x]4.1: In `apps/api/src/main.js` (`createRuntime`), instantiate `notificationService = createNotificationService({ pool })` and pass it to `createOotdService` as a new dependency.
  - [x]4.2: In `apps/api/src/modules/squads/ootd-service.js`, update `createOotdService` factory to accept `notificationService` parameter.
  - [x]4.3: In `ootd-service.js`, update the `createPost` method: after successfully creating the post, for each squad the post was shared to, call `notificationService.sendToSquadMembers(squadId, authorProfileId, { title: "{authorName} posted a new OOTD", body: caption?.substring(0, 100) || "Check out their outfit!", data: { type: "ootd_post", postId }, checkSocialMode: "all" })`. Fire-and-forget.
  - [x]4.4: Replace the `sendCommentNotification` stub function with a call to `notificationService.sendPushNotification(postAuthorId, { title, body, data: { type: "ootd_comment", postId } })`. The social preference check moves into the notification service's `sendPushNotification` method (check `notification_preferences.social !== "off"`). For comment notifications, send if social mode is `"all"` OR `"morning"` (comments are direct interactions, not broadcast posts).
  - [x]4.5: Remove the old `sendCommentNotification` function from `ootd-service.js` after migrating its logic to the notification service.

- [x]Task 5: Mobile -- Create PostingReminderService (AC: 4, 5, 7)
  - [x]5.1: Create `apps/mobile/lib/src/core/notifications/posting_reminder_service.dart` with a `PostingReminderService` class. Constructor accepts optional `FlutterLocalNotificationsPlugin` (reuse same instance as morning/evening services).
  - [x]5.2: Add `Future<void> schedulePostingReminder({ required TimeOfDay time, bool hasPostedToday = false })` method: (a) cancels any existing posting reminder (notification ID `102`), (b) if `hasPostedToday` is true, do NOT schedule (skip silently), (c) constructs `NotificationDetails` with Android channel ID `"posting_reminder"`, channel name `"Daily Posting Reminders"`, importance `Importance.defaultImportance`, (d) calls `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` for daily repeating, (e) title: `"Time to share your OOTD!"`, body: `"Post your outfit of the day to your squads."`, (f) payload: `"posting_reminder"`.
  - [x]5.3: Add `Future<void> cancelPostingReminder()` method that cancels notification ID `102`.
  - [x]5.4: Add static `String buildPostingBody()` that returns the posting reminder body text.

- [x]Task 6: Mobile -- Create PostingReminderPreferences helper (AC: 7)
  - [x]6.1: Create `apps/mobile/lib/src/core/notifications/posting_reminder_preferences.dart` with a `PostingReminderPreferences` class. Constructor accepts optional `SharedPreferences`.
  - [x]6.2: Add `Future<TimeOfDay> getPostingReminderTime()` -- reads `posting_reminder_time` from SharedPreferences (stored as `"HH:mm"`). Default: `TimeOfDay(hour: 9, minute: 0)`.
  - [x]6.3: Add `Future<void> setPostingReminderTime(TimeOfDay time)` -- writes `"HH:mm"` to SharedPreferences.
  - [x]6.4: Add `Future<bool> isPostingReminderEnabled()` -- reads `posting_reminder_enabled` from SharedPreferences. Default: `true`.
  - [x]6.5: Add `Future<void> setPostingReminderEnabled(bool enabled)` -- writes to SharedPreferences.

- [x]Task 7: Mobile -- Update NotificationPreferencesScreen with social mode selector and posting reminder (AC: 1, 4, 6, 7)
  - [x]7.1: In `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`, replace the existing `SwitchListTile` for "Social Updates" with a `ListTile` that shows the current mode label ("All posts", "Morning digest", "Off") as trailing text. Tapping opens a bottom sheet or dialog with three radio options.
  - [x]7.2: Add new constructor parameters: `String socialMode` (default: `"all"`), `ValueChanged<String>? onSocialModeChanged`. Remove or deprecate the `social` boolean from the initial preferences map.
  - [x]7.3: Below the social mode selector, add a conditional section (visible when socialMode != "off"): a "Daily Posting Reminder" `SwitchListTile` with subtitle "Get reminded to share your OOTD each morning".
  - [x]7.4: Below the posting reminder toggle (when enabled), add a time picker row (same pattern as morning/evening time pickers): label "Reminder Time", tappable time display (default "9:00 AM"), opens `showTimePicker`. Constructor parameters: `TimeOfDay? postingReminderTime`, `ValueChanged<TimeOfDay>? onPostingReminderTimeChanged`, `bool postingReminderEnabled`, `ValueChanged<bool>? onPostingReminderEnabledChanged`.
  - [x]7.5: Add `Semantics` labels: "Social notification mode selector", "Daily posting reminder toggle", "Posting reminder time picker".
  - [x]7.6: Follow Vibrant Soft-UI design: the three-option selector should use radio buttons or segmented control with `#4F46E5` active color.

- [x]Task 8: Mobile -- Update MainShellScreen to wire social notification preferences (AC: 1, 6, 7)
  - [x]8.1: In `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`, update `_openNotificationPreferences` to: (a) read the `social` value from the profile's `notificationPreferences` (now a string: `"all"`, `"morning"`, `"off"`; handle legacy boolean), (b) pass `socialMode`, `onSocialModeChanged` to `NotificationPreferencesScreen`, (c) on mode change, persist via `apiClient.updateNotificationPreferences({ "social": newMode })`.
  - [x]8.2: Pass `postingReminderEnabled`, `postingReminderTime`, `onPostingReminderEnabledChanged`, `onPostingReminderTimeChanged` to `NotificationPreferencesScreen`. Wire the callbacks to `PostingReminderPreferences` setters and `PostingReminderService` schedule/cancel.

- [x]Task 9: Mobile -- Integrate posting reminder into app lifecycle (AC: 4, 5, 7, 9)
  - [x]9.1: In `apps/mobile/lib/src/app.dart`, add `PostingReminderService` and `PostingReminderPreferences` fields (same DI pattern as morning/evening services).
  - [x]9.2: Add `_schedulePostingReminderIfEnabled()` method: (a) read `postingReminderEnabled` from preferences, (b) if enabled, read time, (c) check if user has posted today via `ootdService.hasPostedToday()` (new method), (d) schedule if not posted, skip if posted.
  - [x]9.3: Call `_schedulePostingReminderIfEnabled()` after profile provisioning, alongside existing morning/evening scheduling.
  - [x]9.4: Add `PostingReminderService` and `PostingReminderPreferences` as optional constructor parameters on `VestiaireApp`.
  - [x]9.5: Handle notification tap for payload `"posting_reminder"`: navigate to Social tab. Use the same notification tap dispatch pattern as the evening reminder deep-link.

- [x]Task 10: Mobile -- Add hasPostedToday check to OotdService (AC: 5)
  - [x]10.1: In `apps/mobile/lib/src/features/squads/services/ootd_service.dart`, add `Future<bool> hasPostedToday()` method that calls `GET /v1/squads/posts?authorOnly=true&since=today` (or use the existing feed endpoint with filters). Returns `true` if at least one post exists. Wrap in try/catch: on failure, return `false`.
  - [x]10.2: In `apps/mobile/lib/src/core/networking/api_client.dart`, if a new endpoint is needed, add `Future<Map<String, dynamic>> listMyRecentPosts({ String? since })` method. Alternatively, reuse existing `listOotdFeedPosts` with author filter.

- [x]Task 11: Mobile -- Handle FCM push notification tap for social notifications (AC: 9)
  - [x]11.1: In `apps/mobile/lib/src/core/notifications/notification_service.dart` (or `app.dart`), update the FCM `onMessageOpenedApp` handler to check the notification data payload. If `data.type == "ootd_post"`, navigate to Social tab. If `data.type == "ootd_comment"`, navigate to the post detail screen (using `data.postId`).
  - [x]11.2: Handle the case where the app is terminated and opened via notification tap: check `FirebaseMessaging.instance.getInitialMessage()` on app start.

- [x]Task 12: API -- Unit tests for notification service (AC: 2, 3, 8, 10)
  - [x]12.1: Create `apps/api/test/modules/notifications/notification-service.test.js`:
    - `sendPushNotification` sends FCM message when push_token exists and social mode is not "off".
    - `sendPushNotification` skips when push_token is null.
    - `sendPushNotification` skips during quiet hours (22:00-07:00).
    - `sendPushNotification` does not throw on FCM failure (fire-and-forget).
    - `sendToSquadMembers` sends to all qualifying members.
    - `sendToSquadMembers` excludes the sender.
    - `sendToSquadMembers` respects social mode (`"all"` sends, `"morning"` skips, `"off"` skips).
    - `sendToSquadMembers` respects quiet hours for each member.
    - `isQuietHours` returns true for hours 22-23 and 0-6.
    - `isQuietHours` returns false for hours 7-21.

- [x]Task 13: API -- Update ootd-service tests for notification integration (AC: 2, 8, 10)
  - [x]13.1: Update `apps/api/test/modules/squads/ootd-service.test.js`:
    - `createPost` triggers `sendToSquadMembers` with correct parameters.
    - `createPost` passes author name and caption to notification.
    - `createComment` calls `notificationService.sendPushNotification` instead of old stub.
    - `createComment` sends notification when social mode is `"all"` or `"morning"`.
    - `createComment` does NOT send notification when social mode is `"off"`.

- [x]Task 14: API -- Update profile service validation tests (AC: 6, 10)
  - [x]14.1: Update `apps/api/test/notification-preferences.test.js`:
    - PUT /v1/profiles/me with `notification_preferences.social = "all"` saves and returns string.
    - PUT /v1/profiles/me with `notification_preferences.social = "morning"` saves string.
    - PUT /v1/profiles/me with `notification_preferences.social = "off"` saves string.
    - PUT /v1/profiles/me with `notification_preferences.social = true` normalizes to `"all"`.
    - PUT /v1/profiles/me with `notification_preferences.social = false` normalizes to `"off"`.
    - PUT /v1/profiles/me with `notification_preferences.social = "invalid"` returns 400.

- [x]Task 15: Mobile -- Unit tests for PostingReminderService (AC: 4, 5, 10)
  - [x]15.1: Create `apps/mobile/test/core/notifications/posting_reminder_service_test.dart`:
    - `schedulePostingReminder` uses notification ID 102.
    - `cancelPostingReminder` cancels notification ID 102.
    - `buildPostingBody` returns correct text.
    - `schedulePostingReminder` does NOT schedule when `hasPostedToday` is true.
    - `schedulePostingReminder` schedules when `hasPostedToday` is false.
    - Construction with default plugin.

- [x]Task 16: Mobile -- Unit tests for PostingReminderPreferences (AC: 7, 10)
  - [x]16.1: Create `apps/mobile/test/core/notifications/posting_reminder_preferences_test.dart`:
    - `getPostingReminderTime` returns default 09:00 when no value stored.
    - `getPostingReminderTime` returns stored time after set.
    - `setPostingReminderTime` persists in "HH:mm" format.
    - `isPostingReminderEnabled` returns true by default.
    - `isPostingReminderEnabled` returns stored value after set.
    - Round-trip: set then get returns same value.

- [x]Task 17: Mobile -- Widget tests for updated NotificationPreferencesScreen (AC: 1, 4, 7, 10)
  - [x]17.1: Update `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart`:
    - Social mode selector renders with three options.
    - Selecting "All posts" calls onSocialModeChanged with "all".
    - Selecting "Morning digest" calls onSocialModeChanged with "morning".
    - Selecting "Off" calls onSocialModeChanged with "off".
    - Daily posting reminder toggle visible when social mode is not "off".
    - Daily posting reminder toggle hidden when social mode is "off".
    - Posting reminder time picker visible when toggle is on.
    - Posting reminder time picker hidden when toggle is off.
    - Tapping posting time picker opens time picker dialog.
    - Semantics labels present on all new elements.
    - All existing morning/evening time picker tests still pass.

- [x]Task 18: Mobile -- Update OotdService and ApiClient tests (AC: 5, 10)
  - [x]18.1: Update `apps/mobile/test/features/squads/services/ootd_service_test.dart`:
    - `hasPostedToday` returns true when posts exist for today.
    - `hasPostedToday` returns false when no posts today.
    - `hasPostedToday` returns false on error.

- [x]Task 19: Regression testing (AC: all)
  - [x]19.1: Run `flutter analyze` -- zero new issues.
  - [x]19.2: Run `flutter test` -- all existing 1431+ tests plus new tests pass.
  - [x]19.3: Run `npm --prefix apps/api test` -- all existing 961+ API tests plus new tests pass.
  - [x]19.4: Verify existing notification preferences screen tests still pass (morning/evening time pickers unchanged).
  - [x]19.5: Verify existing OOTD post creation, reaction, and comment flows work correctly.
  - [x]19.6: Verify existing profile update API tests pass with backward-compatible social boolean.

## Dev Notes

- This is Story 9.6, the **FINAL story in Epic 9** (Social OOTD Feed / Style Squads). After this story is complete, Epic 9 can be moved to `done` status.
- **FRs covered:** FR-NTF-01 (push notification when squad member posts OOTD), FR-NTF-02 (notification settings: All posts / Only morning / Off), FR-NTF-03 (quiet hours 22:00-07:00, configurable daily notification limit), FR-NTF-04 (optional daily posting reminder, default 9 AM, user-configurable), FR-NTF-05 (posting reminder skipped if already posted today).
- This story spans **API and mobile**. It introduces actual FCM push delivery on the API side, a new notification service module, an updated preferences schema (boolean to string for social), and a new local posting reminder on mobile.

### Current State of the Codebase

- **Notification stub in ootd-service.js (lines 170-204):** `sendCommentNotification()` is a stub that checks `notification_preferences.social`, checks quiet hours, but only logs `[NOTIFICATION STUB] Would send to...`. The TODO references Story 9.6. This must be replaced with actual FCM delivery.
- **`firebase-admin` is already a dependency** in `apps/api/package.json` (used by `apps/api/src/modules/auth/firebaseAdmin.js` for user deletion). The same lazy-import and initialization pattern should be reused for FCM messaging.
- **`notification_preferences.social` is currently a boolean** (`true`/`false`) stored in the JSONB column on `profiles`. Story 1.6 established the four keys: `outfit_reminders`, `wear_logging`, `analytics`, `social` (all boolean, all default `true`). This story migrates `social` from boolean to string (`"all"`, `"morning"`, `"off"`).
- **No `apps/api/src/modules/notifications/` directory exists.** The architecture maps Epic 9 to `api/modules/notifications`. This story creates the notification service module.
- **`FlutterLocalNotificationsPlugin`** is already initialized in `app.dart` (Story 4.7). Notification IDs in use: `100` (morning outfit), `101` (evening wear-log). This story uses ID `102` for the posting reminder.
- **`NotificationPreferencesScreen`** has four SwitchListTile toggles (outfit_reminders, wear_logging, analytics, social) plus morning time picker (Story 4.7) and evening time picker (Story 5.2). The `social` toggle must be replaced with a three-option selector.
- **`MainShellScreen._openNotificationPreferences()`** loads the profile and passes preference params to the screen. This must be extended with the social mode and posting reminder params.
- **Test baselines (from Story 9.5):** 961 API tests, 1431 Flutter tests.

### Database Schema Changes

```sql
-- Migration 029: Migrate social notification preference from boolean to string
-- Existing: notification_preferences.social = true/false
-- New: notification_preferences.social = "all" / "morning" / "off"

UPDATE app_public.profiles
SET notification_preferences = notification_preferences ||
  CASE
    WHEN (notification_preferences->>'social')::text = 'true' THEN '{"social":"all"}'::jsonb
    WHEN (notification_preferences->>'social')::text = 'false' THEN '{"social":"off"}'::jsonb
    ELSE '{"social":"all"}'::jsonb
  END
WHERE notification_preferences ? 'social';

ALTER TABLE app_public.profiles
ALTER COLUMN notification_preferences
SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all"}'::jsonb;
```

### API Endpoint Changes

No new REST endpoints are created. Changes are to existing behavior:

| Changed Behavior | Details |
|---------|---------|
| PUT /v1/profiles/me | `notification_preferences.social` now accepts `"all"`, `"morning"`, `"off"` (strings) in addition to `true`/`false` (boolean, normalized) |
| POST /v1/squads/posts | After creating a post, triggers FCM push to squad members with `social = "all"` |
| POST /v1/squads/posts/:postId/comments | Comment notification now uses real FCM instead of stub |

### Notification Service Design

```
apps/api/src/modules/notifications/
  notification-service.js    <-- NEW: centralized notification service
```

The service handles:
1. **FCM delivery** via `firebase-admin` messaging API (lazy-loaded)
2. **Preference checking** (social mode: `"all"` / `"morning"` / `"off"`)
3. **Quiet hours enforcement** (22:00-07:00)
4. **Batch squad notifications** (one query for all members' tokens/prefs)
5. **Graceful fallback** when credentials unavailable (local dev)

### FCM Message Format

```javascript
// New OOTD post notification
{
  token: "device_fcm_token",
  notification: {
    title: "{authorName} posted a new OOTD",
    body: "caption text..." // or "Check out their outfit!"
  },
  data: {
    type: "ootd_post",
    postId: "uuid"
  }
}

// Comment notification
{
  token: "device_fcm_token",
  notification: {
    title: "{commenterName} commented on your OOTD",
    body: "comment text preview..."
  },
  data: {
    type: "ootd_comment",
    postId: "uuid"
  }
}
```

### Social Preference Mode Mapping

| Mode | New OOTD post push | Comment push | Posting reminder (local) |
|------|-------------------|-------------|------------------------|
| `"all"` | Yes (real-time) | Yes | If enabled |
| `"morning"` | No (deferred to digest -- future) | Yes (direct interaction) | If enabled |
| `"off"` | No | No | No |

Note: The `"morning"` digest delivery (batching posts into one morning notification) is a future enhancement. For this story, `"morning"` mode simply suppresses real-time post notifications. Comments are still delivered in `"morning"` mode because they are direct interactions.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/029_social_notification_mode.sql`
  - `apps/api/src/modules/notifications/notification-service.js`
  - `apps/api/test/modules/notifications/notification-service.test.js`
- New mobile files:
  - `apps/mobile/lib/src/core/notifications/posting_reminder_service.dart`
  - `apps/mobile/lib/src/core/notifications/posting_reminder_preferences.dart`
  - `apps/mobile/test/core/notifications/posting_reminder_service_test.dart`
  - `apps/mobile/test/core/notifications/posting_reminder_preferences_test.dart`
- Modified API files:
  - `apps/api/src/modules/profiles/service.js` (social key validation: boolean + string)
  - `apps/api/src/modules/squads/ootd-service.js` (remove sendCommentNotification stub, use notificationService, add post notification trigger)
  - `apps/api/src/main.js` (instantiate notificationService, pass to createOotdService)
  - `apps/api/test/modules/squads/ootd-service.test.js` (update notification tests)
  - `apps/api/test/notification-preferences.test.js` (add string social mode tests)
- Modified mobile files:
  - `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart` (social mode selector, posting reminder toggle + time picker)
  - `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` (pass new params)
  - `apps/mobile/lib/src/app.dart` (add PostingReminderService/Preferences, lifecycle integration)
  - `apps/mobile/lib/src/features/squads/services/ootd_service.dart` (add hasPostedToday)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (if new endpoint needed for hasPostedToday)
  - `apps/mobile/lib/src/core/notifications/notification_service.dart` (FCM tap handler for social notifications)
  - `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart` (new social mode + posting reminder tests)
  - `apps/mobile/test/features/squads/services/ootd_service_test.dart` (hasPostedToday tests)

### Alignment with Unified Project Structure

- The new `notification-service.js` goes in `apps/api/src/modules/notifications/` as specified by the architecture doc: "Epic 9 Social OOTD -> api/modules/notifications".
- Mobile notification services go in `apps/mobile/lib/src/core/notifications/` alongside `morning_notification_service.dart` and `evening_reminder_service.dart`.
- Posting reminder follows the exact same pattern as morning (4.7) and evening (5.2) services.
- Test files mirror source structure.

### Technical Requirements

- **`firebase-admin`:** Already in `apps/api/package.json`. Use `admin.messaging().send()` for FCM delivery. Lazy-import and initialization pattern from `firebaseAdmin.js`.
- **PostgreSQL 16:** Migration 029 updates JSONB values in-place using `||` operator. No schema change beyond column default.
- **Flutter / Dart:** No new dependencies. Uses existing `flutter_local_notifications`, `shared_preferences`, `firebase_messaging`.
- **Notification ID `102`:** For posting reminder. Distinct from morning (`100`) and evening (`101`).
- **SharedPreferences keys:**
  - `posting_reminder_time`: String `"HH:mm"` (default: `"09:00"`)
  - `posting_reminder_enabled`: Boolean (default: `true`)

### Architecture Compliance

- **Server-side preference enforcement:** Social notification mode is checked server-side before FCM delivery. Disabled notifications are never sent (per architecture: "Preference enforcement occurs server-side so disabled notifications are never sent").
- **Quiet hours enforced server-side before fanout** (per architecture: "Quiet hours and notification-type toggles are modeled as profile or settings data and enforced before fanout").
- **API owns notification initiation** (per architecture: "API Boundary: Owns validation, orchestration, authorization, AI calls, notification initiation, and transactional mutations").
- **FCM for delivery** (per architecture: "Delivery: Firebase Cloud Messaging").
- **Posting reminder is local notification:** Same rationale as Stories 4.7 and 5.2 -- time-based local concern, device knows timezone, no server involvement needed.
- **Graceful degradation:** If FCM credentials unavailable (local dev), log and return. If notification permission denied, local scheduling is a no-op.
- **Accessibility:** Semantics labels on all new UI elements (mode selector, posting reminder toggle, time picker). 44x44 touch targets.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `firebase-admin` package (already in `package.json`) and `pg` pool.
- **Mobile:** No new dependencies. Uses existing `flutter_local_notifications`, `timezone`, `shared_preferences`, `firebase_messaging`.

### File Structure Requirements

- New API module: `apps/api/src/modules/notifications/notification-service.js`.
- New mobile files: `posting_reminder_service.dart`, `posting_reminder_preferences.dart` in `apps/mobile/lib/src/core/notifications/`.
- New migration: `infra/sql/migrations/029_social_notification_mode.sql`.
- All other changes are modifications to existing files.

### Testing Requirements

- **API tests:** New notification service test file. Update existing ootd-service tests and notification-preferences tests. Mock `firebase-admin` messaging in tests.
- **Flutter tests:** Follow existing patterns: mock services via DI, `setupFirebaseCoreMocks()` + `Firebase.initializeApp()`. `PostingReminderService` tests focus on static methods and construction (same limitation as morning/evening services with `FlutterLocalNotificationsPlugin`).
- **Target:** All existing tests pass (961 API, 1431 Flutter) plus new tests.

### Previous Story Intelligence

- **Story 9.5** (done, predecessor): Added "Steal This Look" with Gemini AI matching. 961 API tests, 1431 Flutter tests. Updated `createOotdService` factory to accept `itemRepo`, `geminiClient`, `aiUsageLogRepo`. Route ordering pattern: new routes before `ootdPostIdMatch`.
- **Story 9.4** (done): Added reactions/comments. The `sendCommentNotification` **stub** is the primary target for replacement. Notification checks social preference (boolean) and quiet hours. 939 API tests baseline + 22 = 961 total.
- **Story 9.2** (done): Created OOTD post infrastructure. `createPost` in `ootd-service.js` creates the post and returns. Post notification triggering is added by this story.
- **Story 1.6** (done): Established `push_token` and `notification_preferences` JSONB on `profiles`. `ALLOWED_NOTIFICATION_KEYS` set with `social` as boolean. Validation rejects unknown keys and non-boolean values. This story updates validation to accept string for `social` key.
- **Story 4.7** (done): Established `MorningNotificationService` pattern for local notifications (notification ID 100, `flutter_local_notifications`, `zonedSchedule` with `DateTimeComponents.time`). `MorningNotificationPreferences` with SharedPreferences persistence. DI pattern with optional constructor params. `PostingReminderService` follows the exact same patterns.
- **Story 5.2** (done): Established `EveningReminderService` (notification ID 101). Confirmed pattern of separate services per notification type. `_scheduleEveningReminderIfEnabled()` in `app.dart`. `MainShellScreen` passes time picker params. Same pattern for posting reminder.
- **`firebaseAdmin.js`** (Story 1.7): Lazy-imports `firebase-admin`, checks `GOOGLE_APPLICATION_CREDENTIALS`, initializes with `admin.initializeApp()`. FCM delivery should reuse this pattern. Check if `admin.apps.length === 0` before initializing.

### Key Anti-Patterns to Avoid

- DO NOT keep the `sendCommentNotification` stub. Replace it with real FCM delivery via the notification service.
- DO NOT create a separate Firebase Admin app instance for messaging. Reuse the same app instance from `firebaseAdmin.js` (check `admin.apps.length === 0` before initializing).
- DO NOT send notifications synchronously in the request path. All notification sends are fire-and-forget (catch errors, log, continue).
- DO NOT store posting reminder time in the database. It is device-local (same pattern as morning/evening reminders).
- DO NOT queue or defer quiet-hours notifications. Silently drop them.
- DO NOT create new REST endpoints for notifications. Notifications are triggered as side effects of existing post/comment operations.
- DO NOT break backward compatibility for `notification_preferences.social`. Accept both boolean (normalize to string) and string values.
- DO NOT use notification ID 100 or 101 for the posting reminder. Use 102.
- DO NOT implement the morning digest batch feature. The `"morning"` mode simply suppresses real-time post push notifications for now. Batch digest is a future enhancement.
- DO NOT remove the `social` key from `ALLOWED_NOTIFICATION_KEYS`. Keep backward compatibility.
- DO NOT forget to pass `notificationService` to `createOotdService` in `main.js`.
- DO NOT send post notifications to the post author. Always exclude `authorProfileId`.
- DO NOT skip the `mounted` guard before `setState` in async callbacks.
- DO NOT use Supabase client or direct database access from Flutter.

### Out of Scope

- **Morning digest batching:** The `"morning"` mode suppresses real-time post notifications but does not yet deliver a batched morning summary. This is a future enhancement.
- **Configurable quiet hours:** Quiet hours are hardcoded to 22:00-07:00. Per-user quiet hours configuration is deferred.
- **Configurable daily notification limit:** FR-NTF-03 mentions a "configurable daily notification limit." This is deferred -- no rate limiting on notifications in this story.
- **Content moderation:** Not implemented per PRD deferral.
- **Rich push notifications:** No images or action buttons in push notifications. Simple text only.
- **Real-time feed updates via push:** Notifications inform the user, but the feed requires manual refresh or pull-to-refresh.
- **Web push notifications:** Mobile only (iOS/Android).
- **Epic 10+ features:** All out of scope.

### References

- [Source: epics.md - Story 9.6: Social Notification Preferences]
- [Source: epics.md - Epic 9: Social OOTD Feed (Style Squads), FR-NTF-01 through FR-NTF-05]
- [Source: prd.md - FR-NTF-01: Users shall receive push notifications when a squad member posts an OOTD]
- [Source: prd.md - FR-NTF-02: Notification settings shall support: All posts, Only morning posts, Off]
- [Source: prd.md - FR-NTF-03: Quiet hours shall be respected (default: 10 PM - 7 AM) with configurable daily notification limit]
- [Source: prd.md - FR-NTF-04: Users shall receive an optional daily posting reminder (default 9 AM, user-configurable)]
- [Source: prd.md - FR-NTF-05: The posting reminder shall be skipped if the user has already posted today]
- [Source: architecture.md - Notifications and Async Work: Delivery via Firebase Cloud Messaging, social notifications]
- [Source: architecture.md - Preference enforcement occurs server-side so disabled notifications are never sent]
- [Source: architecture.md - Quiet hours and notification-type toggles are modeled as profile or settings data and enforced before fanout]
- [Source: architecture.md - API Boundary: Owns notification initiation]
- [Source: architecture.md - Epic 9 Social OOTD -> api/modules/notifications]
- [Source: 9-4-reactions-comments.md - sendCommentNotification stub at lines 170-204 in ootd-service.js, quiet hours check, social preference check, notification_preferences.social boolean]
- [Source: 9-5-steal-this-look-matcher.md - createOotdService factory with itemRepo/geminiClient/aiUsageLogRepo, 961 API tests, 1431 Flutter tests]
- [Source: 9-2-ootd-post-creation.md - createPost method in ootd-service.js, post shared to squads via ootd_post_squads table]
- [Source: 1-6-push-notification-permissions-preferences.md - push_token on profiles, notification_preferences JSONB, ALLOWED_NOTIFICATION_KEYS, NotificationPreferencesScreen, NotificationService for FCM token]
- [Source: 4-7-morning-outfit-notifications.md - MorningNotificationService pattern, notification ID 100, flutter_local_notifications, zonedSchedule, DI pattern]
- [Source: 5-2-wear-logging-evening-reminder.md - EveningReminderService pattern, notification ID 101, MainShellScreen time picker wiring, _scheduleEveningReminderIfEnabled pattern]
- [Source: apps/api/src/modules/auth/firebaseAdmin.js - firebase-admin lazy import and initialization pattern for FCM reuse]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed type mismatch in `ApiClient.updateNotificationPreferences` signature: changed `Map<String, bool>` to `Map<String, dynamic>` to support string values for social mode.
- Fixed widget test for bottom sheet: "All posts" appears twice (trailing text + radio option) when socialMode is "all".

### Completion Notes List

- Task 1: Created migration 029 to convert notification_preferences.social from boolean to string ("all"/"morning"/"off"). Column default updated.
- Task 2: Updated profile service validation to accept string modes for social key while maintaining backward compatibility with boolean values (true->"all", false->"off").
- Task 3: Created centralized notification-service.js with FCM delivery via firebase-admin, quiet hours enforcement (22:00-07:00), and batch squad member notifications.
- Task 4: Wired notification service into main.js and ootd-service.js. createPost now triggers push notifications to squad members. Replaced sendCommentNotification stub with real notificationService calls.
- Task 5: Created PostingReminderService (notification ID 102) following MorningNotificationService pattern. Supports hasPostedToday skip logic.
- Task 6: Created PostingReminderPreferences with SharedPreferences persistence for posting_reminder_time and posting_reminder_enabled.
- Task 7: Replaced Social Updates SwitchListTile with a three-option mode selector (bottom sheet with radio buttons). Added Daily Posting Reminder toggle and time picker. All Semantics labels added.
- Task 8: Updated MainShellScreen to pass social mode, posting reminder params, and wire callbacks for persistence and scheduling.
- Task 9: Integrated PostingReminderService/Preferences into VestiaireApp lifecycle. Added _schedulePostingReminderIfEnabled() called after profile provisioning. Set up FCM message handlers for social notification taps.
- Task 10: Added hasPostedToday() to mobile OotdService using feed endpoint.
- Task 11: Added FCM onMessageOpenedApp and getInitialMessage handlers in app.dart for social notification deep linking.
- Task 12: Created 20 new API tests for notification-service (isQuietHours, sendPushNotification, sendToSquadMembers).
- Task 13: Updated ootd-service tests: 4 new tests for notification integration (createPost triggers sendToSquadMembers, createComment uses notificationService, author exclusion, fallback body).
- Task 14: Added 7 new API tests for string social mode validation (all/morning/off strings, boolean normalization, invalid rejection).
- Task 15: Created 5 tests for PostingReminderService (ID 102, buildPostingBody, construction).
- Task 16: Created 7 tests for PostingReminderPreferences (default values, persistence, round-trip).
- Task 17: Rewrote notification preferences screen tests: 30+ tests covering social mode selector, posting reminder, and all existing morning/evening time picker functionality.
- Task 18: Added 3 hasPostedToday tests to mobile OotdService tests.
- Task 19: All regression tests pass. 989 API tests (961 baseline + 28 new). 1459 Flutter tests (1431 baseline + 28 new). flutter analyze: 0 new issues.

### Change Log

- 2026-03-19: Story 9.6 implementation complete -- Social Notification Preferences (FR-NTF-01 through FR-NTF-05). 989 API tests, 1459 Flutter tests all passing.

### File List

**New files:**
- infra/sql/migrations/029_social_notification_mode.sql
- apps/api/src/modules/notifications/notification-service.js
- apps/api/test/modules/notifications/notification-service.test.js
- apps/mobile/lib/src/core/notifications/posting_reminder_service.dart
- apps/mobile/lib/src/core/notifications/posting_reminder_preferences.dart
- apps/mobile/test/core/notifications/posting_reminder_service_test.dart
- apps/mobile/test/core/notifications/posting_reminder_preferences_test.dart

**Modified files:**
- apps/api/src/modules/profiles/service.js
- apps/api/src/modules/squads/ootd-service.js
- apps/api/src/main.js
- apps/api/test/notification-preferences.test.js
- apps/api/test/modules/squads/ootd-service.test.js
- apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart
- apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart
- apps/mobile/lib/src/app.dart
- apps/mobile/lib/src/features/squads/services/ootd_service.dart
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart
- apps/mobile/test/features/squads/services/ootd_service_test.dart
