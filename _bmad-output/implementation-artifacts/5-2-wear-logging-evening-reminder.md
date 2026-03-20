# Story 5.2: Wear Logging Evening Reminder

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to be reminded in the evening to log my outfit,
so that I don't forget to maintain my wear streak and keep my wardrobe analytics accurate.

## Acceptance Criteria

1. Given I have the `wear_logging` notification preference enabled (which defaults to `true` in the `notification_preferences` JSONB on `profiles`), when my configured evening notification time is reached, then the system fires a local notification with the title "Did you log today's outfit?" and a body that includes a contextual nudge (e.g., "Tap to log what you wore today and keep your streak going!"). (FR-LOG-06, FR-PSH-03)

2. Given I have disabled the `wear_logging` notification preference, when the evening notification time is reached, then NO notification is fired. The preference check is performed locally before scheduling so that disabled categories never produce a notification.

3. Given I have not granted OS-level push notification permission, when the app attempts to schedule the evening reminder, then no notification is scheduled and no error is thrown. The scheduling logic gracefully handles the lack of permission.

4. Given I am on the Notification Preferences screen, when I view the "Wear Logging" category, then I see the existing toggle plus a new time-picker row below it that displays the currently configured evening reminder time (default: 20:00 / 8:00 PM). Tapping the time-picker row opens a platform time picker dialog.

5. Given I change the evening reminder time via the time picker, when I confirm the new time, then the selected time is persisted locally via SharedPreferences (key: `evening_reminder_time`), the previously scheduled evening notification is cancelled, and a new daily repeating notification is scheduled at the new time.

6. Given the evening reminder notification fires and I tap on it, when the app opens, then it navigates to the Home screen and automatically opens the "Log Today's Outfit" bottom sheet (from Story 5.1) so I can immediately log my outfit. If the app is already running, tapping the notification brings it to the foreground and opens the log bottom sheet.

7. Given I have already logged an outfit today (at least one `wear_log` exists for today's date), when the evening reminder notification would normally fire, then the notification body changes to an encouraging message (e.g., "Great job logging today! Tap to add more or review your log.") rather than being suppressed. The notification still fires to reinforce the habit.

8. Given I sign out of the app, when the sign-out flow completes, then the evening reminder notification is cancelled along with all other scheduled notifications (already handled by `MorningNotificationService.cancelAllNotifications()` from Story 4.7).

9. Given I sign in and the `wear_logging` preference is enabled, when the Home screen loads for the first time after sign-in, then the app schedules (or re-schedules) the evening reminder using the locally stored time (or the default 20:00 if no custom time is stored).

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (337 API tests, 775 Flutter tests) and new tests cover: EveningReminderService scheduling/cancellation, NotificationPreferencesScreen wear-logging time-picker integration, HomeScreen scheduling trigger, notification tap deep-link to log bottom sheet, and edge cases (permission denied, preference disabled, already-logged-today body variation).

## Tasks / Subtasks

- [x] Task 1: Mobile - Create EveningReminderService (AC: 1, 2, 3, 5, 7, 8, 9)
  - [x] 1.1: Create `apps/mobile/lib/src/core/notifications/evening_reminder_service.dart` with an `EveningReminderService` class. Constructor accepts optional `FlutterLocalNotificationsPlugin` (reuse the same plugin instance as `MorningNotificationService`) and optional `WearLogService` for checking today's log status.
  - [x] 1.2: Add `Future<void> scheduleEveningReminder({ required TimeOfDay time, bool hasLoggedToday = false })` method that:
    - (a) Cancels any existing evening reminder notification (using a fixed notification ID `101` -- distinct from morning notification ID `100`).
    - (b) Constructs `NotificationDetails` with: Android channel ID `"evening_wear_log"`, channel name `"Evening Wear Log Reminders"`, channel description `"Daily evening reminders to log your outfit"`, importance `Importance.high`, priority `Priority.high`. iOS: default presentation options.
    - (c) Calls `flutterLocalNotificationsPlugin.zonedSchedule()` with `matchDateTimeComponents: DateTimeComponents.time` for daily repeating at the specified `time` in the local timezone.
    - (d) Title: `"Did you log today's outfit?"`. Body: `"Tap to log what you wore today and keep your streak going!"` (default) or `"Great job logging today! Tap to add more or review your log."` (if `hasLoggedToday` is true).
    - (e) Uses `UILocalNotificationDateInterpretation.absoluteTime` and `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`.
    - (f) Sets the notification payload to `"evening_wear_log"` so the tap handler can identify it and deep-link to the log flow.
  - [x] 1.3: Add `Future<void> cancelEveningReminder()` method that cancels the notification with the fixed ID (`101`).
  - [x] 1.4: Add `Future<bool> hasLoggedToday(WearLogService wearLogService)` helper that calls `wearLogService.getLogsForDateRange(today, today)` and returns `true` if the list is non-empty. Wrap in try/catch: on failure, return `false` (safe default).
  - [x] 1.5: Add a static `String buildEveningBody({ bool hasLoggedToday = false })` helper that returns the appropriate body text based on whether the user has already logged today.

- [x] Task 2: Mobile - Create EveningReminderPreferences helper (AC: 4, 5, 9)
  - [x] 2.1: Create `apps/mobile/lib/src/core/notifications/evening_reminder_preferences.dart` with an `EveningReminderPreferences` class. Constructor accepts optional `SharedPreferences` for DI.
  - [x] 2.2: Add `Future<TimeOfDay> getEveningTime()` that reads `evening_reminder_time` from SharedPreferences. Stored as `"HH:mm"` string. Returns `TimeOfDay(hour: 20, minute: 0)` as default if not set.
  - [x] 2.3: Add `Future<void> setEveningTime(TimeOfDay time)` that writes the time as `"HH:mm"` string to SharedPreferences key `evening_reminder_time`.
  - [x] 2.4: Add `Future<bool> isWearLoggingEnabled()` that reads the locally cached `wear_logging` preference from SharedPreferences key `wear_logging_enabled` (default: `true`). This is a LOCAL cache of the server-side `wear_logging` key in `notification_preferences` JSONB.
  - [x] 2.5: Add `Future<void> setWearLoggingEnabled(bool enabled)` that writes the value to SharedPreferences.

- [x] Task 3: Mobile - Update NotificationPreferencesScreen with wear-logging time picker (AC: 4, 5)
  - [x] 3.1: Update `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`: add new constructor parameters `TimeOfDay? eveningReminderTime` (default: `TimeOfDay(hour: 20, minute: 0)`) and `ValueChanged<TimeOfDay>? onEveningTimeChanged` callback.
  - [x] 3.2: Below the "Wear Logging" toggle (`wear_logging` category), add a conditional row (visible only when `wear_logging` is enabled) showing:
    - Label: "Reminder Time" (13px, #1F2937)
    - Current time value formatted as "8:00 PM" (13px, #4F46E5, tappable)
    - Tapping opens `showTimePicker(context: context, initialTime: _eveningTime)`
    - When a new time is selected, call `onEveningTimeChanged` and update the displayed time.
  - [x] 3.3: Add `Semantics` label: "Evening reminder time picker" on the time row.
  - [x] 3.4: The time picker row has 16px horizontal padding and is visually indented below the Wear Logging toggle (40px left padding, matching the morning time picker pattern from Story 4.7).

- [x] Task 4: Mobile - Update NotificationPreferencesScreen integration in MainShellScreen (AC: 4, 5)
  - [x] 4.1: Update `_openNotificationPreferences` in `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`: pass the `eveningReminderTime` and `onEveningTimeChanged` parameters to the `NotificationPreferencesScreen`.
  - [x] 4.2: When `onEveningTimeChanged` is called: persist the new time via `EveningReminderPreferences.setEveningTime(time)`, then reschedule the evening reminder via `EveningReminderService.scheduleEveningReminder(time: time)`.
  - [x] 4.3: When the `wear_logging` toggle changes: update the local `EveningReminderPreferences.setWearLoggingEnabled(value)`. If disabled, cancel the evening reminder via `EveningReminderService.cancelEveningReminder()`. If enabled, schedule it.

- [x] Task 5: Mobile - Integrate evening reminder scheduling into app lifecycle (AC: 6, 8, 9)
  - [x] 5.1: Update `apps/mobile/lib/src/app.dart` (`_VestiaireAppState`):
    - Add `late final EveningReminderService _eveningReminderService` field.
    - Initialize it in `initState()` using the same `FlutterLocalNotificationsPlugin` instance as the morning notification service.
  - [x] 5.2: Add `EveningReminderService` and `EveningReminderPreferences` as optional constructor parameters on `VestiaireApp` for test injection.
  - [x] 5.3: Update `_scheduleMorningNotificationIfEnabled()` (or create a parallel `_scheduleEveningReminderIfEnabled()` method) that:
    - (a) Reads the `wear_logging` preference from `EveningReminderPreferences`.
    - (b) If enabled, reads the evening time from `EveningReminderPreferences`.
    - (c) Optionally checks if user has logged today via `EveningReminderService.hasLoggedToday()` (for body variation).
    - (d) Schedules the reminder via `EveningReminderService.scheduleEveningReminder(time: eveningTime, hasLoggedToday: ...)`.
  - [x] 5.4: Call `_scheduleEveningReminderIfEnabled()` after successful profile provisioning (inside `_provisionProfile()` after the onboarding check), alongside the existing `_scheduleMorningNotificationIfEnabled()` call.
  - [x] 5.5: Update the notification tap handler in `_morningNotificationService.setOnNotificationTap()` (or register a new handler): when the notification payload is `"evening_wear_log"`, set a flag `_pendingWearLogNavigation = true` that the HomeScreen can read to automatically open the LogOutfitBottomSheet.

- [x] Task 6: Mobile - Handle notification tap deep-link to Log Outfit flow (AC: 6)
  - [x] 6.1: Update `apps/mobile/lib/src/features/home/screens/home_screen.dart`: add optional `bool initialOpenLogSheet` constructor parameter (default: `false`).
  - [x] 6.2: In `HomeScreen.initState()` or after the first build, if `initialOpenLogSheet` is `true`, call `showModalBottomSheet` to open the `LogOutfitBottomSheet` automatically.
  - [x] 6.3: In `apps/mobile/lib/src/app.dart`, when the evening notification tap is detected (payload `"evening_wear_log"`), pass `initialOpenLogSheet: true` to the HomeScreen. This can be achieved via a ValueNotifier or a state flag on `_VestiaireAppState` that is read by `MainShellScreen` / `HomeScreen`.
  - [x] 6.4: If the app is already open and the user taps the notification, use the `onDidReceiveNotificationResponse` callback to trigger the log sheet. This may require a GlobalKey on the HomeScreen or a stream/notifier that the HomeScreen listens to.

- [x] Task 7: Mobile - Integrate evening reminder update in HomeScreen (AC: 7, 9)
  - [x] 7.1: Update `HomeScreen` constructor: add optional `EveningReminderService? eveningReminderService` and `EveningReminderPreferences? eveningReminderPreferences` parameters.
  - [x] 7.2: After the HomeScreen loads (in `initState` or after weather fetch), call `_updateEveningReminder()` which:
    - (a) Checks if `eveningReminderService` is injected.
    - (b) Checks if wear logging reminders are enabled via `eveningReminderPreferences`.
    - (c) Checks if user has logged today via `eveningReminderService.hasLoggedToday()`.
    - (d) Reschedules the evening reminder with the updated `hasLoggedToday` flag so the notification body is contextually appropriate.
  - [x] 7.3: This is a non-blocking fire-and-forget call. Wrap in try/catch so failures do not affect the HomeScreen.

- [x] Task 8: Unit tests for EveningReminderService (AC: 1, 2, 3, 5, 7, 10)
  - [x] 8.1: Create `apps/mobile/test/core/notifications/evening_reminder_service_test.dart`:
    - `scheduleEveningReminder()` uses notification ID 101 (not 100).
    - `cancelEveningReminder()` cancels notification with ID 101.
    - `buildEveningBody()` returns default body when `hasLoggedToday` is false.
    - `buildEveningBody()` returns encouraging body when `hasLoggedToday` is true.
    - `hasLoggedToday()` returns true when wear logs exist for today.
    - `hasLoggedToday()` returns false when no wear logs exist for today.
    - `hasLoggedToday()` returns false on API error (graceful degradation).
    - Construction with default plugin.

- [x] Task 9: Unit tests for EveningReminderPreferences (AC: 4, 5, 10)
  - [x] 9.1: Create `apps/mobile/test/core/notifications/evening_reminder_preferences_test.dart`:
    - `getEveningTime()` returns default 20:00 when no value stored.
    - `getEveningTime()` returns stored time after `setEveningTime()`.
    - `setEveningTime()` persists in "HH:mm" format.
    - `isWearLoggingEnabled()` returns true by default.
    - `isWearLoggingEnabled()` returns stored value after `setWearLoggingEnabled()`.
    - Round-trip: set then get returns same value.

- [x] Task 10: Widget tests for updated NotificationPreferencesScreen (AC: 4, 5, 10)
  - [x] 10.1: Update `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart`:
    - Evening time picker row renders below Wear Logging toggle when toggle is on.
    - Evening time picker row is hidden when Wear Logging toggle is off.
    - Tapping the evening time value opens the time picker dialog.
    - Selecting a new evening time calls `onEveningTimeChanged` callback.
    - Default evening time displays as "8:00 PM".
    - Semantics label "Evening reminder time picker" is present.
    - All existing tests (including morning time picker tests from Story 4.7) continue to pass.

- [x] Task 11: Widget/integration tests for HomeScreen evening reminder integration (AC: 6, 7, 10)
  - [x] 11.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When `eveningReminderService` is injected, `_updateEveningReminder()` is called after load.
    - Evening reminder is NOT scheduled if `eveningReminderService` is null (default behavior preserved).
    - When `initialOpenLogSheet` is true, the LogOutfitBottomSheet opens automatically.
    - When `initialOpenLogSheet` is false (default), the LogOutfitBottomSheet does NOT auto-open.
    - All existing HomeScreen tests continue to pass.

- [x] Task 12: Unit tests for app lifecycle evening reminder integration (AC: 8, 9, 10)
  - [x] 12.1: Update `apps/mobile/test/app_test.dart` (or create `apps/mobile/test/app_evening_reminder_lifecycle_test.dart`):
    - After sign-in and profile provisioning, evening reminder is scheduled if `wear_logging` is enabled.
    - Evening reminder is NOT scheduled if `wear_logging` is disabled.
    - Sign-out cancels all notifications (evening reminder included via existing `cancelAllNotifications()`).
    - Account deletion cancels all notifications (evening reminder included).

- [x] Task 13: Regression testing (AC: all)
  - [x] 13.1: Run `flutter analyze` -- zero issues.
  - [x] 13.2: Run `flutter test` -- all existing 775 + new Flutter tests pass.
  - [x] 13.3: Run `npm --prefix apps/api test` -- all existing 337 API tests pass (no API changes in this story).
  - [x] 13.4: Verify existing morning notification tests pass unchanged.
  - [x] 13.5: Verify existing notification preferences screen tests pass (new evening time picker tests extend them).
  - [x] 13.6: Verify existing HomeScreen tests pass with the new optional constructor parameters defaulting to null.
  - [x] 13.7: Verify existing app.dart tests pass with the new optional EveningReminderService parameter defaulting to null.

## Dev Notes

- This is the **second story in Epic 5** (Wardrobe Analytics & Wear Logging). It builds directly on Story 5.1 (wear logging infrastructure) and reuses the local notification infrastructure established in Story 4.7 (morning outfit notifications).
- This story implements **FR-LOG-06** ("evening reminder notification, default 8 PM, user-configurable") and **FR-PSH-03** ("Evening wear-log reminders shall be sent at user-configurable time, default 8 PM").
- **This story uses LOCAL notifications** (via `flutter_local_notifications`), exactly like Story 4.7's morning notifications. The rationale is identical: an evening reminder is a time-based local concern -- the device knows the user's timezone and can schedule a repeating alarm without server involvement.
- **No API changes are needed.** The notification is entirely client-side. The `notification_preferences` JSONB column (from Story 1.6) already contains the `wear_logging` key, which controls whether the evening reminder is shown. The time preference is stored locally in SharedPreferences.
- **No database migration is needed.** All new data is stored in SharedPreferences on the device.
- **The `wear_logging` preference key already exists** in the `notification_preferences` JSONB on `profiles`. Story 1.6 established four categories: `outfit_reminders`, `wear_logging`, `analytics`, `social`. This story hooks into the `wear_logging` key to control the evening reminder.

### Design Decision: Separate Service vs Extending MorningNotificationService

A separate `EveningReminderService` is created rather than extending `MorningNotificationService` because:
1. **Single Responsibility:** Each service handles one notification type with its own scheduling logic, notification ID, channel, and preferences.
2. **Independent lifecycle:** The morning notification can be enabled/disabled independently of the evening reminder. They use different preference keys (`outfit_reminders` vs `wear_logging`).
3. **Different notification IDs:** Morning uses ID `100`, evening uses ID `101`. Keeping them in separate services prevents accidental cross-cancellation.
4. **Shared plugin instance:** Both services share the same `FlutterLocalNotificationsPlugin` instance (initialized once in `app.dart`), so there is no overhead from having two services.

### Design Decision: Notification ID 101

The morning notification uses ID `100` (established in Story 4.7). The evening reminder uses ID `101` to avoid conflicts. Both are cancelled together during sign-out via `cancelAllNotifications()`.

### Design Decision: Contextual Notification Body

Rather than suppressing the notification when the user has already logged today, the notification still fires but with an encouraging message. This reinforces the habit loop without being annoying (the user already did the right thing). The body variation is determined at scheduling time based on the `hasLoggedToday` check. Since the notification is scheduled as a daily repeating notification, the body may be slightly stale (e.g., the user logs after the last schedule). This is acceptable -- the purpose is nudging, not precision.

### Design Decision: Deep-Link to Log Bottom Sheet

Tapping the evening notification opens the app AND automatically opens the LogOutfitBottomSheet (from Story 5.1). This reduces friction to zero -- one tap from notification to logging. The deep-link is achieved by setting the notification payload to `"evening_wear_log"` and having the notification tap handler set a flag that HomeScreen reads to auto-open the sheet.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/core/notifications/evening_reminder_service.dart` (scheduling, cancellation, body builder)
  - `apps/mobile/lib/src/core/notifications/evening_reminder_preferences.dart` (time and preference persistence)
  - `apps/mobile/test/core/notifications/evening_reminder_service_test.dart`
  - `apps/mobile/test/core/notifications/evening_reminder_preferences_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/app.dart` (integrate EveningReminderService lifecycle, notification tap handler for deep-link)
  - `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` (pass evening time picker params to notification preferences screen)
  - `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart` (add evening time picker row below Wear Logging toggle)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add eveningReminderService/preferences params, initialOpenLogSheet param, auto-open log sheet on notification tap, update evening reminder with hasLoggedToday)
  - `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart` (evening time picker tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (evening reminder scheduling tests, auto-open log sheet tests)
- No API files modified.
- No SQL migration files.
- No new API test files.

### Technical Requirements

- **Notification ID `101`:** Fixed ID for the evening wear-log reminder. Distinct from morning notification ID `100`.
- **Android notification channel:** Channel ID `"evening_wear_log"`, name `"Evening Wear Log Reminders"`. Separate from the morning channel (`"morning_outfit"`).
- **SharedPreferences keys:**
  - `evening_reminder_time`: String in `"HH:mm"` format (default: `"20:00"`)
  - `wear_logging_enabled`: Boolean (local cache of server-side `wear_logging` preference, default: `true`)
- **Notification payload:** `"evening_wear_log"` string. Used by the tap handler to identify the notification type and deep-link to the log flow.
- **`flutter_local_notifications`:** Already a dependency (added in Story 4.7). No new package installation needed.
- **`timezone`:** Already a dependency (added in Story 4.7). No new package installation needed.

### Architecture Compliance

- **Mobile boundary owns local notifications:** Evening reminder scheduling is a device-specific concern, identical pattern to Story 4.7 morning notifications. No API or database involvement.
- **Server authority for preferences:** The `wear_logging` preference is authoritative in the server's `notification_preferences` JSONB. The client caches it locally in SharedPreferences for offline scheduling decisions. When the user toggles the preference on the NotificationPreferencesScreen, the server is updated (via `PUT /v1/profiles/me`) AND the local cache is updated.
- **No new API endpoints.** Reuses existing `PUT /v1/profiles/me` for preference persistence. The evening time is device-local only.
- **Graceful degradation:** If notification permission is denied, scheduling is a no-op. If `WearLogService` fails when checking today's logs, the notification uses the default body. The feature degrades gracefully at every point.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `flutter_local_notifications: ^18.x` (added in Story 4.7) -- local notification scheduling
  - `timezone: ^0.9.x` (added in Story 4.7) -- timezone data for `zonedSchedule`
  - `shared_preferences` -- already in pubspec.yaml, used for time and preference persistence
  - `flutter/material.dart` -- `TimeOfDay`, `showTimePicker`

### File Structure Requirements

- New files go in `apps/mobile/lib/src/core/notifications/` alongside `morning_notification_service.dart` and `morning_notification_preferences.dart`.
- Test files mirror source structure under `apps/mobile/test/core/notifications/`.
- Modified files are all in the mobile app -- no API or infrastructure changes.

### Testing Requirements

- Unit tests must verify:
  - EveningReminderService uses notification ID 101 (not 100)
  - EveningReminderService.scheduleEveningReminder() creates a daily repeating notification
  - EveningReminderService.cancelEveningReminder() cancels with the correct ID
  - EveningReminderService.buildEveningBody() returns correct text for both logged/not-logged states
  - EveningReminderService.hasLoggedToday() delegates to WearLogService correctly
  - EveningReminderPreferences persists and retrieves time and enabled state
- Widget tests must verify:
  - NotificationPreferencesScreen shows evening time picker row when wear_logging is enabled
  - NotificationPreferencesScreen hides evening time picker row when wear_logging is disabled
  - Time picker opens on tap and calls onEveningTimeChanged
  - HomeScreen triggers evening reminder update after load
  - HomeScreen auto-opens LogOutfitBottomSheet when initialOpenLogSheet is true
- Lifecycle tests must verify:
  - Sign-out cancels all scheduled notifications (evening included)
  - Account deletion cancels all scheduled notifications
  - App launch schedules evening reminder if wear_logging is enabled
  - App launch does NOT schedule evening reminder if wear_logging is disabled
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 775 + new tests pass)
  - `npm --prefix apps/api test` (all existing 337 API tests pass -- no API changes)

### Previous Story Intelligence

- **Story 5.1** (done) established: Wear logging infrastructure -- `wear_logs` and `wear_log_items` tables, `POST /v1/wear-logs` and `GET /v1/wear-logs` API endpoints, `WearLog` model, `WearLogService` with `logItems()`, `logOutfit()`, `getLogsForDateRange()`, `LogOutfitBottomSheet` widget, HomeScreen "Log Today's Outfit" button. 337 API tests, 775 Flutter tests.
- **Story 5.1** established: `WearLogService` at `apps/mobile/lib/src/features/analytics/services/wear_log_service.dart`. The `getLogsForDateRange(startDate, endDate)` method is used by this story to check if the user has logged today.
- **Story 5.1** established: `LogOutfitBottomSheet` at `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart`. This is the widget that the deep-link from the evening notification should open.
- **Story 5.1** established: HomeScreen now has `wearLogService` optional parameter. This story adds `eveningReminderService` and `eveningReminderPreferences` optional parameters.
- **Story 4.7** (done) established: `MorningNotificationService` at `apps/mobile/lib/src/core/notifications/morning_notification_service.dart` with notification ID `100`, `scheduleMorningNotification()`, `cancelMorningNotification()`, `cancelAllNotifications()`, `buildWeatherSnippet()`, `setOnNotificationTap()`. `MorningNotificationPreferences` at `apps/mobile/lib/src/core/notifications/morning_notification_preferences.dart` with `getMorningTime()`, `setMorningTime()`, `isOutfitRemindersEnabled()`, `setOutfitRemindersEnabled()`.
- **Story 4.7** established: `flutter_local_notifications: ^18.0.1` and `timezone: ^0.9.4` in `pubspec.yaml`. Android permissions for `RECEIVE_BOOT_COMPLETED` and `SCHEDULE_EXACT_ALARM` already added to `AndroidManifest.xml`.
- **Story 4.7** established: `_VestiaireAppState` in `app.dart` has `_morningNotificationService` field, `_scheduleMorningNotificationIfEnabled()` method, sign-out/delete `cancelAllNotifications()` call. The evening reminder service should follow the same pattern.
- **Story 4.7** established: NotificationPreferencesScreen has `morningTime`/`onMorningTimeChanged` params and a time picker row below the "Outfit Reminders" toggle. This story adds the same pattern for the "Wear Logging" toggle.
- **Story 4.7** established: `MainShellScreen` at `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` handles `_openNotificationPreferences()` with morning notification params. This story extends it with evening reminder params.
- **Story 1.6** established: `notification_preferences` JSONB on `profiles` with keys: `outfit_reminders`, `wear_logging`, `analytics`, `social` (all default `true`). The `wear_logging` key is the preference that controls the evening reminder.
- **Story 1.6** established: NotificationPreferencesScreen with four toggle switches. The "Wear Logging" toggle already exists -- this story adds a time picker row below it, matching the pattern Story 4.7 added for "Outfit Reminders".
- **HomeScreen constructor (as of Story 5.1):** `locationService` (required), `weatherService` (required), `sharedPreferences`, `weatherCacheService`, `outfitContextService`, `calendarService`, `calendarPreferencesService`, `calendarEventService`, `outfitGenerationService`, `outfitPersistenceService`, `onNavigateToAddItem`, `apiClient`, `morningNotificationService`, `morningNotificationPreferences`, `wearLogService`. This story adds `eveningReminderService`, `eveningReminderPreferences`, and `initialOpenLogSheet`.
- **VestiaireApp constructor (as of Story 5.1):** `config` (required), `authService`, `sessionManager`, `apiClient`, `notificationService`, `locationService`, `weatherService`, `subscriptionService`, `morningNotificationService`, `morningNotificationPreferences`. This story adds `eveningReminderService` and `eveningReminderPreferences`.
- **Key pattern:** DI via optional constructor parameters with null defaults for test injection. Follow this for all new parameters.
- **Key pattern:** Non-blocking fire-and-forget for notification scheduling (try/catch, no awaiting on the HomeScreen build path).

### Key Anti-Patterns to Avoid

- DO NOT implement server-side push notification delivery. This story uses LOCAL notifications only (same as Story 4.7).
- DO NOT store the evening reminder time in the database. It is a device-local preference stored in SharedPreferences.
- DO NOT create a new notification category or toggle. The existing `wear_logging` toggle from Story 1.6 controls this feature. Only ADD the time picker sub-option.
- DO NOT reuse notification ID `100` (that is the morning notification). Use ID `101` for the evening reminder.
- DO NOT suppress the notification when the user has already logged today. Instead, change the notification body to an encouraging message. The notification reinforces the habit loop.
- DO NOT extend `MorningNotificationService` with evening logic. Create a separate `EveningReminderService` for single responsibility.
- DO NOT block the HomeScreen UI on notification scheduling or `hasLoggedToday` checks. These are fire-and-forget.
- DO NOT request notification permission again. Story 1.6 already handles permission via `firebase_messaging`. The `flutter_local_notifications` plugin respects the same OS permission grant.
- DO NOT trigger a live API call from the notification itself. The `hasLoggedToday` check happens at scheduling time (when the HomeScreen loads), not at notification fire time.
- DO NOT create new API endpoints or database migrations. This story is entirely client-side.
- DO NOT implement analytics features. Those are Stories 5.4-5.7.
- DO NOT implement the monthly calendar view (FR-LOG-07). That is Story 5.3.

### Out of Scope

- **Monthly calendar view (FR-LOG-07):** Story 5.3.
- **Analytics dashboard (FR-ANA-*):** Stories 5.4-5.7.
- **Gamification / streak tracking:** Epic 6.
- **Event-based outfit reminders (FR-PSH-05):** Epic 12.
- **Rich notification content (images, action buttons):** V1 uses simple text notifications.
- **Background wear-log check:** Checking if the user has logged today happens at scheduling time, not at notification fire time. A background task that dynamically changes the notification body at fire time is out of scope for V1.
- **Custom notification sounds:** Uses system default.
- **Quiet hours / Do Not Disturb integration:** Out of scope for V1.

### References

- [Source: epics.md - Story 5.2: Wear Logging Evening Reminder]
- [Source: epics.md - FR-LOG-06: Evening reminder notification, default 8 PM, user-configurable]
- [Source: epics.md - FR-PSH-03: Evening wear-log reminders shall be sent at user-configurable time (default 8 PM)]
- [Source: architecture.md - Notifications and Async Work: wear-log reminders]
- [Source: architecture.md - Preference enforcement occurs server-side so disabled notifications are never sent]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - WearLogService, LogOutfitBottomSheet, HomeScreen integration]
- [Source: 4-7-morning-outfit-notifications.md - MorningNotificationService, MorningNotificationPreferences, flutter_local_notifications pattern, notification ID 100]
- [Source: 1-6-push-notification-permissions-preferences.md - notification_preferences JSONB with wear_logging key, NotificationPreferencesScreen toggles]
- [Source: apps/mobile/lib/src/core/notifications/morning_notification_service.dart - pattern for local notification scheduling]
- [Source: apps/mobile/lib/src/core/notifications/morning_notification_preferences.dart - pattern for time/preference persistence]
- [Source: apps/mobile/lib/src/features/analytics/services/wear_log_service.dart - getLogsForDateRange for hasLoggedToday check]
- [Source: apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart - deep-link target for notification tap]
- [Source: apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart - existing toggles and morning time picker]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented EveningReminderService with notification ID 101, scheduling via zonedSchedule, contextual body text (hasLoggedToday variation), and graceful degradation on errors.
- Implemented EveningReminderPreferences with SharedPreferences persistence for evening_reminder_time (HH:mm) and wear_logging_enabled (bool).
- Updated NotificationPreferencesScreen with evening time picker row below Wear Logging toggle (conditional on toggle state), matching morning time picker pattern.
- Updated MainShellScreen to pass evening reminder params, handle time changes (persist + reschedule), and handle wear_logging toggle (enable/disable scheduling).
- Updated VestiaireApp (app.dart) with _scheduleEveningReminderIfEnabled() method called after profile provisioning, alongside existing morning notification scheduling.
- Added initialOpenLogSheet parameter to HomeScreen with post-frame callback to auto-open LogOutfitBottomSheet on notification tap deep-link.
- Added _updateEveningReminder() fire-and-forget method to HomeScreen that reschedules the evening reminder with hasLoggedToday context.
- All 806 Flutter tests pass (775 original + 31 new). All 337 API tests pass. flutter analyze reports zero issues.

### Change Log

- 2026-03-18: Implemented Story 5.2 - Wear Logging Evening Reminder. Added EveningReminderService, EveningReminderPreferences, evening time picker on NotificationPreferencesScreen, app lifecycle integration, HomeScreen deep-link and reminder update. 31 new tests added.

### File List

New files:
- apps/mobile/lib/src/core/notifications/evening_reminder_service.dart
- apps/mobile/lib/src/core/notifications/evening_reminder_preferences.dart
- apps/mobile/test/core/notifications/evening_reminder_service_test.dart
- apps/mobile/test/core/notifications/evening_reminder_preferences_test.dart
- apps/mobile/test/app_evening_reminder_lifecycle_test.dart

Modified files:
- apps/mobile/lib/src/app.dart
- apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart
- apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart
- apps/mobile/lib/src/features/home/screens/home_screen.dart
- apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart
- apps/mobile/test/features/home/screens/home_screen_test.dart
