# Story 12.3: Formal Event Reminders

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to receive an evening reminder before a high-formality event,
so that I have time to prep (iron, dry clean) my outfit the night before.

## Acceptance Criteria

1. Given I have a calendar event classified with formality score >= 7 (formal threshold) scheduled for tomorrow, when the time reaches my configured evening reminder time (default: 20:00 / 8:00 PM), then the system fires a local notification with the title "Formal event tomorrow: {eventTitle}" and a body that includes the scheduled outfit name (if one exists in `calendar_outfits` for that date/event) plus an AI-generated preparation tip (e.g., "Your outfit 'Elegant Evening' is ready. Don't forget to iron your linen shirt and polish your shoes."). If no outfit is scheduled, the body nudges the user to plan one: "You have a formal event tomorrow. Open Vestiaire to plan your outfit." (FR-EVT-07, FR-PSH-05)

2. Given I have a calendar event with formality score < 7 scheduled for tomorrow, when the evening reminder time is reached, then NO formal event reminder notification is fired for that event. Only events meeting the formal threshold trigger reminders. (FR-EVT-07)

3. Given I have multiple formal events (formality >= 7) scheduled for tomorrow, when the evening reminder time is reached, then the system fires ONE consolidated notification listing all formal events: title "Formal events tomorrow" and body listing each event title with its prep tip (up to 3 events; if more, show "and X more"). (FR-EVT-07)

4. Given the AI-generated preparation tip feature, when the reminder is being constructed, then the system calls `POST /v1/outfits/event-prep-tips` with the event details (type, formality, scheduled outfit items if any) to generate a brief preparation tip via Gemini. The tip is concise (max 100 characters) and actionable (e.g., "Iron your cotton blazer and steam the trousers"). If the AI call fails, a generic fallback tip is used based on formality level: formality 7-8: "Check that your outfit is clean and pressed." formality 9-10: "Consider dry cleaning and shoe polishing tonight." (FR-EVT-07)

5. Given I am on the Notification Preferences screen, when I view the notification categories, then I see a new "Event Reminders" toggle (under the existing categories) with: a boolean toggle (default: `true`, preference key in `notification_preferences` JSONB: `event_reminders`), a time picker row below it (same pattern as morning/evening reminders, default 20:00, SharedPreferences key: `event_reminder_time`), and a formality threshold picker (slider or segmented control showing values 6-10, default 7, SharedPreferences key: `event_reminder_formality_threshold`). (FR-EVT-08)

6. Given I change the event reminder settings, when I toggle the preference off, then the scheduled event reminder notifications are cancelled. When I change the time, the notifications are rescheduled. When I change the formality threshold, the threshold is stored locally and applied at next scheduling. (FR-EVT-08)

7. Given the event reminder notification fires and I tap on it, when the app opens, then it navigates to the PlanWeekScreen (from Story 12.2) with tomorrow's date pre-selected, so I can view or assign an outfit for the formal event. (FR-EVT-07)

8. Given I sign out of the app, when the sign-out flow completes, then all event reminder notifications are cancelled (already handled by `MorningNotificationService.cancelAllNotifications()` from Story 4.7, which cancels ALL local notifications). (FR-EVT-08)

9. Given I sign in and the `event_reminders` preference is enabled, when the Home screen loads, then the app checks tomorrow's calendar events, identifies any with formality >= threshold, and schedules (or reschedules) the event reminder for the configured time. This check runs daily on HomeScreen load. (FR-EVT-07, FR-EVT-08)

10. Given the `notification_preferences` JSONB on `profiles` needs to include `event_reminders`, when the API validates notification preferences, then it accepts `event_reminders` as a valid boolean key alongside the existing keys (`outfit_reminders`, `wear_logging`, `analytics`, `social`). New users default to `event_reminders: true`. (FR-PSH-06)

11. Given the prep tip generation requires AI, when the API processes the request, then AI usage is logged to `ai_usage_log` with `feature = "event_prep_tip"` (distinct from "outfit_generation" and "event_outfit_generation"). (NFR-OBS-02)

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1214 API tests, 1634 Flutter tests from Story 12.2) and new tests cover: EventReminderService scheduling/cancellation, prep tip API endpoint (auth, success, AI failure, fallback), NotificationPreferencesScreen event reminder section (toggle, time picker, threshold picker), HomeScreen scheduling trigger, notification tap navigation to PlanWeekScreen, formality threshold filtering, consolidated multi-event notifications, and backward compatibility for `notification_preferences` with new `event_reminders` key.

## Tasks / Subtasks

- [x] Task 1: API - Add `event_reminders` to allowed notification preference keys (AC: 10)
  - [x] 1.1: In `apps/api/src/modules/profiles/service.js`, add `"event_reminders"` to `ALLOWED_NOTIFICATION_KEYS`. It is a boolean key (same as `outfit_reminders`, `wear_logging`, `analytics`).
  - [x] 1.2: Update the column default for `notification_preferences` in a migration to include `event_reminders: true`: Create `infra/sql/migrations/036_event_reminders_preference.sql` that runs `ALTER TABLE app_public.profiles ALTER COLUMN notification_preferences SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all","event_reminders":true}'::jsonb;`. Also backfill existing profiles: `UPDATE app_public.profiles SET notification_preferences = notification_preferences || '{"event_reminders":true}'::jsonb WHERE NOT (notification_preferences ? 'event_reminders');`.
  - [x] 1.3: Update validation tests in `apps/api/test/notification-preferences.test.js` to verify `event_reminders` is accepted as boolean and rejected as non-boolean.

- [x] Task 2: API - Create `POST /v1/outfits/event-prep-tips` endpoint (AC: 4, 11)
  - [x]2.1: In `apps/api/src/modules/outfits/outfit-generation-service.js`, add `async generateEventPrepTip(authContext, { event, outfitItems })` method. This constructs a Gemini prompt asking for a concise (max 100 char) preparation tip for the given event and outfit items. Prompt:
    ```
    You are a personal stylist AI. Generate a brief preparation tip for tomorrow's event.

    EVENT:
    - Title: {event.title}
    - Type: {event.eventType}
    - Formality Score: {event.formalityScore}/10
    - Time: {event.startTime}

    OUTFIT ITEMS (if scheduled):
    {items as JSON array with name, category, material, color}

    Generate ONE concise preparation tip (max 100 characters) that is actionable and specific.
    Focus on: ironing, steaming, dry cleaning, shoe care, accessory prep, or garment inspection.
    If outfit items are provided, reference specific items by name/material.
    If no outfit items, give a general formal event prep tip.

    Return ONLY valid JSON: { "tip": "your tip here" }
    ```
  - [x]2.2: Add route `POST /v1/outfits/event-prep-tips` to `apps/api/src/main.js`. Place it after the existing `POST /v1/outfits/generate-for-event` route. The route: authenticates via `requireAuth`, reads the request body `{ event: { title, eventType, formalityScore, startTime }, outfitItems?: [{ name, category, material, color }] }`, calls `outfitGenerationService.generateEventPrepTip(authContext, body)`, and returns 200 with `{ tip: "..." }`.
  - [x]2.3: Handle errors: 400 for missing event data, 401 for unauthenticated, 503 for AI unavailable, 500 for generation failure. On Gemini failure, return the fallback tip based on formality level: formality 7-8: "Check that your outfit is clean and pressed." formality 9-10: "Consider dry cleaning and shoe polishing tonight."
  - [x]2.4: Log AI usage to `ai_usage_log` with `feature: "event_prep_tip"`.

- [x] Task 3: Mobile - Create EventReminderService (AC: 1, 2, 3, 6, 8, 9)
  - [x]3.1: Create `apps/mobile/lib/src/core/notifications/event_reminder_service.dart` with an `EventReminderService` class. Constructor accepts optional `FlutterLocalNotificationsPlugin` (reuse the same plugin instance as morning/evening/posting services).
  - [x]3.2: Add `Future<void> scheduleEventReminder({ required TimeOfDay time, required List<CalendarEvent> formalEvents, List<CalendarOutfit>? scheduledOutfits, String? prepTip })` method that:
    - (a) Cancels any existing event reminder notification (using fixed notification ID `103` -- distinct from morning `100`, evening `101`, posting `102`).
    - (b) If `formalEvents` is empty, return without scheduling (no formal events tomorrow).
    - (c) Constructs notification content: if 1 event, title = "Formal event tomorrow: {event.title}", body = prepTip or fallback. If 2-3 events, title = "Formal events tomorrow", body = list of event titles + shared prep tip. If >3, title = "Formal events tomorrow", body = first 3 + "and {n} more".
    - (d) Constructs `NotificationDetails` with Android channel ID `"event_reminders"`, channel name `"Formal Event Reminders"`, channel description `"Evening reminders before formal events"`, importance `Importance.high`, priority `Priority.high`. iOS: default presentation options.
    - (e) Calls `flutterLocalNotificationsPlugin.zonedSchedule()` with the specified `time` for TODAY (not daily repeating -- this is a one-shot for tonight). Uses `UILocalNotificationDateInterpretation.absoluteTime` and `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`.
    - (f) Sets the notification payload to `"event_reminder"` so the tap handler can deep-link to PlanWeekScreen.
  - [x]3.3: Add `Future<void> cancelEventReminder()` method that cancels notification ID `103`.
  - [x]3.4: Add static `String buildFallbackTip(int formalityScore)` helper: returns "Check that your outfit is clean and pressed." for 7-8, "Consider dry cleaning and shoe polishing tonight." for 9-10.
  - [x]3.5: Add `List<CalendarEvent> filterFormalEvents(List<CalendarEvent> events, int formalityThreshold)` helper that filters events by `formalityScore >= threshold`.

- [x] Task 4: Mobile - Create EventReminderPreferences helper (AC: 5, 6)
  - [x]4.1: Create `apps/mobile/lib/src/core/notifications/event_reminder_preferences.dart` with an `EventReminderPreferences` class. Constructor accepts optional `SharedPreferences` for DI.
  - [x]4.2: Add `Future<TimeOfDay> getEventReminderTime()` -- reads `event_reminder_time` from SharedPreferences (stored as `"HH:mm"`). Default: `TimeOfDay(hour: 20, minute: 0)`.
  - [x]4.3: Add `Future<void> setEventReminderTime(TimeOfDay time)` -- writes `"HH:mm"` to SharedPreferences.
  - [x]4.4: Add `Future<int> getFormalityThreshold()` -- reads `event_reminder_formality_threshold` from SharedPreferences. Default: `7`.
  - [x]4.5: Add `Future<void> setFormalityThreshold(int threshold)` -- writes to SharedPreferences. Clamp to range 6-10.
  - [x]4.6: Add `Future<bool> isEventRemindersEnabled()` -- reads the locally cached `event_reminders` preference from SharedPreferences key `event_reminders_enabled` (default: `true`). This is a LOCAL cache of the server-side `event_reminders` key in `notification_preferences` JSONB.
  - [x]4.7: Add `Future<void> setEventRemindersEnabled(bool enabled)` -- writes to SharedPreferences.

- [x] Task 5: Mobile - Add prep tip API method to OutfitGenerationService and ApiClient (AC: 4)
  - [x]5.1: Add `Future<Map<String, dynamic>> getEventPrepTip(Map<String, dynamic> event, List<Map<String, dynamic>>? outfitItems)` method to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedPost("/v1/outfits/event-prep-tips", body: { "event": event, "outfitItems": outfitItems })`.
  - [x]5.2: Add `Future<String?> getEventPrepTip(CalendarEvent event, List<Map<String, dynamic>>? outfitItems)` to `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart`. Serializes event, calls `_apiClient.getEventPrepTip(eventJson, outfitItems)`, extracts `tip` from response. Returns `null` on error.

- [x] Task 6: Mobile - Update NotificationPreferencesScreen with event reminders section (AC: 5, 6)
  - [x]6.1: In `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart`, add new constructor parameters: `bool eventRemindersEnabled` (default: `true`), `ValueChanged<bool>? onEventRemindersEnabledChanged`, `TimeOfDay? eventReminderTime` (default: `TimeOfDay(hour: 20, minute: 0)`), `ValueChanged<TimeOfDay>? onEventReminderTimeChanged`, `int formalityThreshold` (default: `7`), `ValueChanged<int>? onFormalityThresholdChanged`.
  - [x]6.2: Below the existing notification categories (after Social Updates section), add an "Event Reminders" section: a `SwitchListTile` with title "Event Reminders", subtitle "Get reminded the evening before formal events", icon `Icons.event_available`.
  - [x]6.3: Below the toggle (visible only when enabled): (a) "Reminder Time" row -- same pattern as morning/evening time pickers (13px label, tappable time value in `#4F46E5`, opens `showTimePicker`). Default "8:00 PM". (b) "Formality Threshold" row -- label "Minimum formality" (13px, #1F2937), a segmented control or `Slider` showing values 6-10 with current value highlighted. Labels: 6="Semi-formal", 7="Formal", 8="Very Formal", 9="Black Tie", 10="Ultra Formal". Default 7.
  - [x]6.4: Add `Semantics` labels: "Event reminders toggle", "Event reminder time picker", "Formality threshold selector".
  - [x]6.5: Styling: 40px left padding for sub-options (matching morning/evening pattern), segmented control uses `#4F46E5` active color.

- [x] Task 7: Mobile - Update MainShellScreen to wire event reminder preferences (AC: 5, 6)
  - [x]7.1: In `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart`, update `_openNotificationPreferences` to: (a) read `event_reminders` from profile's `notificationPreferences`, (b) read event reminder time and formality threshold from `EventReminderPreferences`, (c) pass all event reminder params to `NotificationPreferencesScreen`.
  - [x]7.2: Wire callbacks: `onEventRemindersEnabledChanged` persists to server (via `apiClient.updateNotificationPreferences`) AND local cache (`EventReminderPreferences.setEventRemindersEnabled`). If disabled, cancel via `EventReminderService.cancelEventReminder()`. If enabled, trigger reschedule.
  - [x]7.3: Wire `onEventReminderTimeChanged` to persist via `EventReminderPreferences.setEventReminderTime()` and trigger reschedule.
  - [x]7.4: Wire `onFormalityThresholdChanged` to persist via `EventReminderPreferences.setFormalityThreshold()`.

- [x] Task 8: Mobile - Integrate event reminder scheduling into app lifecycle and HomeScreen (AC: 7, 8, 9)
  - [x]8.1: In `apps/mobile/lib/src/app.dart`, add `EventReminderService` and `EventReminderPreferences` fields (same DI pattern as morning/evening/posting services). Add optional constructor parameters on `VestiaireApp`.
  - [x]8.2: Add `_scheduleEventReminderIfEnabled()` async method that: (a) reads `event_reminders` preference, (b) if enabled, reads reminder time and formality threshold from `EventReminderPreferences`, (c) fetches tomorrow's calendar events via `CalendarEventService` (GET /v1/calendar/events with tomorrow's date range), (d) filters for formality >= threshold, (e) if formal events exist, optionally fetches scheduled outfits for tomorrow via `CalendarOutfitService`, (f) optionally calls `outfitGenerationService.getEventPrepTip()` for the most formal event, (g) schedules the reminder via `EventReminderService.scheduleEventReminder()`.
  - [x]8.3: Call `_scheduleEventReminderIfEnabled()` after profile provisioning, alongside existing morning/evening/posting scheduling. This is fire-and-forget.
  - [x]8.4: Update HomeScreen: add optional `EventReminderService? eventReminderService` and `EventReminderPreferences? eventReminderPreferences` constructor parameters. After calendar events load (in `_fetchCalendarEvents()` or equivalent), call `_updateEventReminder()` which re-evaluates tomorrow's formal events and reschedules the reminder with fresh data.
  - [x]8.5: Handle notification tap for payload `"event_reminder"`: navigate to PlanWeekScreen with tomorrow's date pre-selected. Use the same notification tap dispatch pattern as the evening reminder deep-link. In `app.dart`, when payload is `"event_reminder"`, set a flag that triggers navigation to PlanWeekScreen.

- [x] Task 9: API - Unit tests for event prep tip generation (AC: 4, 11, 12)
  - [x]9.1: Add tests to `apps/api/test/modules/outfits/outfit-generation-service.test.js`:
    - `generateEventPrepTip` calls Gemini with event-specific prompt containing event title, type, formality.
    - `generateEventPrepTip` returns parsed tip string.
    - `generateEventPrepTip` logs AI usage with feature "event_prep_tip".
    - `generateEventPrepTip` returns fallback tip when Gemini fails (formality 7-8 fallback).
    - `generateEventPrepTip` returns fallback tip when Gemini fails (formality 9-10 fallback).
    - `generateEventPrepTip` includes outfit items in prompt when provided.
    - `generateEventPrepTip` works without outfit items.

- [x] Task 10: API - Integration tests for POST /v1/outfits/event-prep-tips (AC: 4, 12)
  - [x]10.1: Add tests in `apps/api/test/modules/outfits/outfit-generation.test.js`:
    - `POST /v1/outfits/event-prep-tips` requires authentication (401).
    - `POST /v1/outfits/event-prep-tips` returns 200 with tip on success.
    - `POST /v1/outfits/event-prep-tips` returns 400 when event data is missing.
    - `POST /v1/outfits/event-prep-tips` returns fallback tip on Gemini failure (not 500).
    - `POST /v1/outfits/event-prep-tips` returns 503 when Gemini is unavailable.

- [x] Task 11: API - Tests for event_reminders preference key (AC: 10, 12)
  - [x]11.1: Update `apps/api/test/notification-preferences.test.js`:
    - PUT /v1/profiles/me with `notification_preferences.event_reminders = true` saves and returns.
    - PUT /v1/profiles/me with `notification_preferences.event_reminders = false` saves and returns.
    - PUT /v1/profiles/me with `notification_preferences.event_reminders = "invalid"` returns 400.

- [x] Task 12: Mobile - Unit tests for EventReminderService (AC: 1, 2, 3, 12)
  - [x]12.1: Create `apps/mobile/test/core/notifications/event_reminder_service_test.dart`:
    - `scheduleEventReminder` uses notification ID 103 (not 100, 101, or 102).
    - `cancelEventReminder` cancels notification with ID 103.
    - `filterFormalEvents` returns only events with formality >= threshold.
    - `filterFormalEvents` returns empty list when no events meet threshold.
    - `buildFallbackTip` returns correct text for formality 7-8.
    - `buildFallbackTip` returns correct text for formality 9-10.
    - Single event notification has event title in notification title.
    - Multiple events notification has consolidated title.
    - `scheduleEventReminder` does not schedule when formalEvents is empty.
    - Construction with default plugin.

- [x] Task 13: Mobile - Unit tests for EventReminderPreferences (AC: 5, 6, 12)
  - [x]13.1: Create `apps/mobile/test/core/notifications/event_reminder_preferences_test.dart`:
    - `getEventReminderTime` returns default 20:00 when no value stored.
    - `getEventReminderTime` returns stored time after `setEventReminderTime`.
    - `setEventReminderTime` persists in "HH:mm" format.
    - `getFormalityThreshold` returns default 7 when no value stored.
    - `getFormalityThreshold` returns stored value after `setFormalityThreshold`.
    - `setFormalityThreshold` clamps to range 6-10.
    - `isEventRemindersEnabled` returns true by default.
    - `isEventRemindersEnabled` returns stored value after set.
    - Round-trip: set then get returns same value.

- [x] Task 14: Mobile - Unit tests for OutfitGenerationService prep tip method (AC: 4, 12)
  - [x]14.1: Add tests to `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart`:
    - `getEventPrepTip` calls API with serialized event and outfit items.
    - `getEventPrepTip` returns parsed tip string on success.
    - `getEventPrepTip` returns null on API error.
    - `getEventPrepTip` returns null on network error.

- [x] Task 15: Mobile - Widget tests for updated NotificationPreferencesScreen (AC: 5, 6, 12)
  - [x]15.1: Update `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart`:
    - Event reminders toggle renders with "Event Reminders" title.
    - Event reminders sub-options (time picker, threshold) visible when toggle is on.
    - Event reminders sub-options hidden when toggle is off.
    - Tapping event reminder time value opens time picker dialog.
    - Selecting new time calls `onEventReminderTimeChanged`.
    - Formality threshold selector renders with current value.
    - Changing formality threshold calls `onFormalityThresholdChanged`.
    - Default event reminder time displays as "8:00 PM".
    - Default formality threshold is 7.
    - Semantics labels present on all event reminder elements.
    - All existing tests (morning, evening, posting, social) continue to pass.

- [x] Task 16: Mobile - Widget/integration tests for HomeScreen event reminder scheduling (AC: 9, 12)
  - [x]16.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When `eventReminderService` is injected and formal events exist tomorrow, reminder is scheduled.
    - When `eventReminderService` is injected but no formal events tomorrow, no reminder scheduled.
    - Event reminder is NOT scheduled if `eventReminderService` is null (default behavior preserved).
    - All existing HomeScreen tests continue to pass.

- [x] Task 17: Regression testing (AC: 12)
  - [x]17.1: Run `flutter analyze` -- zero issues.
  - [x]17.2: Run `flutter test` -- all existing 1634 Flutter tests plus new tests pass.
  - [x]17.3: Run `npm --prefix apps/api test` -- all existing 1214 API tests plus new tests pass.
  - [x]17.4: Verify existing notification preferences screen tests pass (morning, evening, posting, social all unchanged).
  - [x]17.5: Verify existing HomeScreen tests pass with new optional constructor parameters defaulting to null.
  - [x]17.6: Verify existing PlanWeekScreen functionality preserved.
  - [x]17.7: Run migration 036 against test database to verify schema update.

## Dev Notes

- This is the THIRD story in Epic 12 (Calendar Integration & Outfit Planning). It builds on Story 12.1 (event display, event outfit generation, event_type_utils), Story 12.2 (outfit scheduling, calendar_outfits, PlanWeekScreen), and the local notification infrastructure from Stories 4.7 (morning), 5.2 (evening), and 9.6 (posting reminder + FCM notification service).
- The primary FRs covered are FR-EVT-07 (evening reminders before formal events with preparation tips), FR-EVT-08 (configurable reminders: timing, event types, snooze/dismiss), and FR-PSH-05 (event-based outfit reminders fire the evening before formal events).
- **FR-TRV-01 through FR-TRV-05 are OUT OF SCOPE.** They cover travel mode packing in Story 12.4.
- **Snooze/dismiss from FR-EVT-08 is partially covered.** Dismiss is natively handled by the OS notification system. Snooze (rescheduling a notification for later) is deferred to a future enhancement -- V1 provides toggle, time picker, and threshold as the "configurable" aspects.

### Design Decision: Local vs Server-Side Notification

Local notifications are chosen for event reminders, consistent with the pattern established by Stories 4.7, 5.2, and 9.6 for time-based reminders. Rationale:
1. **Timezone awareness:** The device natively knows local time. Server-side would need per-user timezone tracking.
2. **Calendar data is already local:** The mobile app already has tomorrow's events from `CalendarEventService`.
3. **Simplicity:** No Cloud Functions or cron jobs needed.
4. **Offline resilience:** Works without network.

The prep tip generation is the one server-side component -- it requires Gemini AI. The mobile client calls the API to get the tip, then uses it in the local notification body.

### Design Decision: One-Shot vs Daily Repeating

Unlike morning outfit (daily repeating) and evening wear-log (daily repeating), event reminders are ONE-SHOT notifications. They only fire when there are formal events tomorrow. The scheduling logic runs on each HomeScreen load, checks tomorrow's events, and either schedules or skips.

### Design Decision: Notification ID 103

Notification IDs in use: `100` (morning outfit, Story 4.7), `101` (evening wear-log, Story 5.2), `102` (posting reminder, Story 9.6). This story uses `103` for event reminders.

### Design Decision: Formality Threshold Default 7

The formality score range is 1-10 (established in Story 3.5's calendar event classification). A threshold of 7 captures "formal" and above, which aligns with the Gemini prompt rules from Story 12.1: "formal events (formality >= 7): prioritize blazers, dress shirts, tailored trousers, heels, structured bags."

### Design Decision: Prep Tip Generation

The AI-generated prep tip is a lightweight Gemini call (single JSON field output). It is optional -- if the API is unreachable or Gemini fails, a generic fallback tip is used. The prep tip is generated at scheduling time (when HomeScreen loads or when the event reminder is being prepared), not at notification fire time.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/036_event_reminders_preference.sql`
- New mobile files:
  - `apps/mobile/lib/src/core/notifications/event_reminder_service.dart` (scheduling, cancellation, filtering, fallback tips)
  - `apps/mobile/lib/src/core/notifications/event_reminder_preferences.dart` (time, threshold, enabled persistence)
  - `apps/mobile/test/core/notifications/event_reminder_service_test.dart`
  - `apps/mobile/test/core/notifications/event_reminder_preferences_test.dart`
- Modified API files:
  - `apps/api/src/modules/profiles/service.js` (add `event_reminders` to `ALLOWED_NOTIFICATION_KEYS`)
  - `apps/api/src/modules/outfits/outfit-generation-service.js` (add `generateEventPrepTip` method)
  - `apps/api/src/main.js` (add `POST /v1/outfits/event-prep-tips` route)
  - `apps/api/test/modules/outfits/outfit-generation-service.test.js` (add prep tip tests)
  - `apps/api/test/modules/outfits/outfit-generation.test.js` (add prep tip endpoint tests)
  - `apps/api/test/notification-preferences.test.js` (add event_reminders key tests)
- Modified mobile files:
  - `apps/mobile/lib/src/app.dart` (add EventReminderService/Preferences lifecycle, notification tap handler)
  - `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` (pass event reminder params to NotificationPreferencesScreen)
  - `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart` (add event reminders section with toggle, time picker, threshold)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add eventReminderService/Preferences params, schedule on calendar load)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getEventPrepTip` method)
  - `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart` (add `getEventPrepTip` method)
  - `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart` (event reminder section tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (event reminder scheduling tests)
  - `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart` (prep tip tests)

### Technical Requirements

- **New API endpoint:** `POST /v1/outfits/event-prep-tips` -- accepts `{ event: { title, eventType, formalityScore, startTime }, outfitItems?: [...] }`, returns `{ tip: "..." }`. Requires authentication.
- **Gemini 2.0 Flash** for prep tip generation. Same model as outfit generation (`gemini-2.0-flash`), JSON mode (`responseMimeType: "application/json"`).
- **AI usage logging:** Feature name = `"event_prep_tip"`. Log to `ai_usage_log` with same fields.
- **New database migration:** `036_event_reminders_preference.sql` -- updates `notification_preferences` default and backfills existing profiles.
- **Notification ID `103`:** Fixed ID for event reminders. Distinct from IDs 100-102.
- **Android notification channel:** Channel ID `"event_reminders"`, name `"Formal Event Reminders"`. Separate from existing channels.
- **SharedPreferences keys:**
  - `event_reminder_time`: String `"HH:mm"` (default: `"20:00"`)
  - `event_reminder_formality_threshold`: int (default: `7`, range 6-10)
  - `event_reminders_enabled`: Boolean (local cache, default: `true`)
- **`flutter_local_notifications`:** Already a dependency (Story 4.7). No new package needed.
- **No new Flutter dependencies.**

### Architecture Compliance

- **AI calls brokered by Cloud Run:** The mobile client calls the API for prep tips. The API calls Gemini. The mobile client NEVER calls Gemini directly.
- **Server authority for preferences:** The `event_reminders` key is authoritative in the server's `notification_preferences` JSONB. The client caches locally for offline scheduling.
- **Mobile boundary owns local notifications:** Event reminder scheduling is device-side, consistent with architecture.
- **Graceful degradation:** If Gemini fails for prep tips, fallback tips are used. If calendar events fail to load, no reminder is scheduled. If notification permission is denied, scheduling is a no-op.
- **Epic 12 component mapping:** `mobile/features/outfits`, `mobile/features/home`, `api/modules/outfits`, `api/modules/notifications` -- matches architecture.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `flutter_local_notifications`, `timezone`, `shared_preferences`.
- No new API dependencies. Uses existing `@google-cloud/vertexai` via shared `geminiClient`.

### File Structure Requirements

- New notification files in `apps/mobile/lib/src/core/notifications/` alongside existing morning/evening/posting services.
- New API method in existing `outfit-generation-service.js` (no new module directory).
- New migration follows sequential numbering (036 after 035).
- Test files mirror source structure.

### Testing Requirements

- API unit tests must verify:
  - Prep tip Gemini prompt includes event title, type, formality, outfit items
  - Prep tip fallback logic when Gemini fails (formality-dependent)
  - AI usage logged with "event_prep_tip" feature name
  - `event_reminders` accepted as valid notification preference key
- API integration tests must verify:
  - POST /v1/outfits/event-prep-tips requires auth, returns correct structure, handles errors
  - Notification preference with event_reminders key accepted and persisted
- Mobile unit tests must verify:
  - EventReminderService uses notification ID 103
  - Formal event filtering by threshold
  - Fallback tip generation by formality range
  - Consolidated multi-event notification content
  - EventReminderPreferences persists time, threshold, and enabled state
  - OutfitGenerationService.getEventPrepTip calls API correctly
- Mobile widget tests must verify:
  - NotificationPreferencesScreen shows event reminders section with toggle, time picker, threshold
  - Sub-options hidden when toggle off
  - HomeScreen triggers event reminder scheduling when calendar data loads
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 1634+ tests pass)
  - `npm --prefix apps/api test` (all existing 1214+ tests pass)

### Previous Story Intelligence

- **Story 12.2** (previous story in epic, done) ended with 1214 API tests and 1634 Flutter tests. All must continue to pass. Story 12.2 established: `calendar_outfits` table (migration 035), `CalendarOutfitService`, `CalendarOutfit` model, `PlanWeekScreen`, `OutfitAssignmentBottomSheet`, `POST/GET/PUT/DELETE /v1/calendar/outfits` endpoints. The PlanWeekScreen is the deep-link target for event reminder notification taps.
- **Story 12.1** (done) established: `EventsSection` widget, `EventOutfitBottomSheet`, `event_type_utils.dart` (shared utility for event icons/colors), `POST /v1/outfits/generate-for-event` endpoint, `generateOutfitsForEvent` on API. Reuse event display patterns.
- **Story 3.5** established: `calendar_events` table, `CalendarEvent` model with `formalityScore` and `eventType` fields, `CalendarEventService`, `GET /v1/calendar/events` with date range parameters. The `formalityScore` field is the key data point for filtering formal events.
- **Story 4.7** established: `MorningNotificationService` pattern (notification ID 100, `flutter_local_notifications`, `zonedSchedule`, `cancelAllNotifications()` for sign-out). `MorningNotificationPreferences` with SharedPreferences. DI pattern. The `cancelAllNotifications()` on sign-out already covers event reminders (notification ID 103) since it cancels ALL local notifications.
- **Story 5.2** established: `EveningReminderService` (notification ID 101). Confirmed pattern of separate services per notification type.
- **Story 9.6** established: `PostingReminderService` (notification ID 102), centralized `notification-service.js` on API for FCM delivery, `PostingReminderPreferences`. `NotificationPreferencesScreen` now has: morning time picker, evening time picker, social mode selector with posting reminder. Adding event reminders section follows the same pattern.
- **Story 9.6** established: `notification-service.js` in `apps/api/src/modules/notifications/` for server-side push. Event reminders use LOCAL notifications (not server-side push), but the centralized service exists if needed in the future.
- **HomeScreen constructor (as of Story 12.2):** Many DI parameters accumulated. This story adds `eventReminderService` and `eventReminderPreferences` (both optional, null default).
- **VestiaireApp constructor (as of Story 12.2):** This story adds `eventReminderService` and `eventReminderPreferences` (both optional).
- **MainShellScreen** already handles morning, evening, and posting notification params. Adding event reminder params follows the same pattern.
- **Key patterns from prior notification stories:**
  - Separate service per notification type (morning, evening, posting, event)
  - SharedPreferences for device-local time/preference persistence
  - Server-side `notification_preferences` JSONB for preference authority
  - Local cache of server preference for offline scheduling
  - `FlutterLocalNotificationsPlugin` shared instance
  - Fire-and-forget scheduling (try/catch, non-blocking)
  - DI via optional constructor parameters with null defaults

### Key Anti-Patterns to Avoid

- DO NOT implement server-side push for event reminders. Use LOCAL notifications (same as morning/evening/posting reminders). The server-side `notification-service.js` (Story 9.6) is for real-time social push, not scheduled reminders.
- DO NOT use notification IDs 100, 101, or 102. Use 103 for event reminders.
- DO NOT create a daily repeating notification. Event reminders are ONE-SHOT -- scheduled for tonight only if formal events exist tomorrow. Re-evaluated on each HomeScreen load.
- DO NOT store the event reminder time or formality threshold in the database. They are device-local preferences stored in SharedPreferences (same pattern as morning/evening/posting times).
- DO NOT create a new notification category toggle. Add `event_reminders` to the existing `notification_preferences` JSONB as a new boolean key.
- DO NOT block the HomeScreen UI on event reminder scheduling, prep tip fetching, or calendar checks. These are fire-and-forget.
- DO NOT call Gemini from the mobile client for prep tips. Call the API endpoint which brokers the Gemini call.
- DO NOT extend `MorningNotificationService` or `EveningReminderService` with event reminder logic. Create a separate `EventReminderService`.
- DO NOT duplicate the `FlutterLocalNotificationsPlugin` initialization. Reuse the same instance initialized in `app.dart` (Story 4.7).
- DO NOT remove or modify existing notification services. Only ADD the new event reminder service.
- DO NOT change the `calendar_events` or `calendar_outfits` tables. They are read-only for this story.
- DO NOT skip the mounted guard before `setState` in async callbacks.

### Implementation Guidance

- **One-shot scheduling:** Unlike `matchDateTimeComponents: DateTimeComponents.time` (daily repeating used by morning/evening/posting), event reminders should use a one-time `zonedSchedule` call targeting a specific `TZDateTime` for tonight at the configured time. If the configured time has already passed today, skip scheduling (the event is tomorrow and it is too late for a prep reminder).

- **Prep tip caching:** Consider caching the prep tip in memory or SharedPreferences so that if the HomeScreen reloads (screen rotation, tab switch), the prep tip does not trigger another Gemini call. Use a simple cache key like `event_prep_tip_{date}_{eventId}`.

- **Formality threshold UI:** A `Slider` with `divisions: 4` (6 to 10) and labels is simpler to implement than a custom segmented control. Use `Slider(min: 6, max: 10, divisions: 4, value: threshold.toDouble(), label: _labelForThreshold(threshold))`.

- **Calendar events for tomorrow:** When checking tomorrow's events, use the existing `CalendarEventService` methods with date range = tomorrow's date. The `GET /v1/calendar/events` endpoint already supports date range parameters (established in Story 3.5).

- **Notification payload for deep-link:** Set `payload: "event_reminder"` on the scheduled notification. In `app.dart`, the `onDidReceiveNotificationResponse` callback checks the payload and sets a navigation flag for PlanWeekScreen.

### References

- [Source: epics.md - Story 12.3: Formal Event Reminders]
- [Source: epics.md - Epic 12: Calendar Integration & Outfit Planning]
- [Source: epics.md - FR-EVT-07: The system shall send evening reminders before formal events with preparation tips]
- [Source: epics.md - FR-EVT-08: Event reminders shall be configurable: timing, event types, snooze/dismiss]
- [Source: epics.md - FR-PSH-05: Event-based outfit reminders shall fire the evening before formal events]
- [Source: architecture.md - Notifications and Async Work: formal event reminders]
- [Source: architecture.md - Preference enforcement occurs server-side so disabled notifications are never sent]
- [Source: architecture.md - Epic 12 Calendar Planning & Travel -> mobile/features/outfits, api/modules/calendar, api/modules/notifications]
- [Source: 12-1-event-display-suggestions.md - EventsSection, event_type_utils.dart, POST /v1/outfits/generate-for-event, Gemini event prompt pattern]
- [Source: 12-2-outfit-scheduling-plan-week.md - calendar_outfits table, CalendarOutfitService, PlanWeekScreen (deep-link target)]
- [Source: 4-7-morning-outfit-notifications.md - MorningNotificationService pattern, notification ID 100, flutter_local_notifications, zonedSchedule, cancelAllNotifications, DI pattern]
- [Source: 5-2-wear-logging-evening-reminder.md - EveningReminderService pattern, notification ID 101, separate service per notification type]
- [Source: 9-6-social-notification-preferences.md - PostingReminderService, notification ID 102, notification-service.js for FCM, NotificationPreferencesScreen extension pattern]
- [Source: 3-5-calendar-event-fetching-classification.md - CalendarEvent model with formalityScore, eventType, GET /v1/calendar/events with date range]
- [Source: apps/api/src/modules/outfits/outfit-generation-service.js - Gemini prompt pattern, AI usage logging, validateAndEnrichResponse]
- [Source: apps/mobile/lib/src/core/notifications/morning_notification_service.dart - FlutterLocalNotificationsPlugin pattern]
- [Source: apps/mobile/lib/src/core/notifications/evening_reminder_service.dart - Separate service pattern]
- [Source: apps/mobile/lib/src/core/notifications/posting_reminder_service.dart - Notification ID 102 pattern]
- [Source: apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart - Toggle + time picker + sub-option pattern]
- [Source: apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart - _openNotificationPreferences wiring pattern]
- [Source: apps/mobile/lib/src/features/outfits/screens/plan_week_screen.dart - Deep-link target for notification tap]
- [Source: apps/mobile/lib/src/features/outfits/services/calendar_outfit_service.dart - CalendarOutfitService for fetching scheduled outfits]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented `event_reminders` as a new boolean key in `ALLOWED_NOTIFICATION_KEYS` and `BOOLEAN_ONLY_NOTIFICATION_KEYS` in the profiles service.
- Created migration 036 to update notification_preferences default and backfill existing profiles.
- Added `POST /v1/outfits/event-prep-tips` endpoint with Gemini-powered prep tip generation and formality-based fallback tips.
- Created `EventReminderService` (notification ID 103) with one-shot scheduling, formal event filtering, consolidated multi-event notifications, and fallback tips.
- Created `EventReminderPreferences` for persisting event reminder time (default 20:00), formality threshold (default 7, clamped 6-10), and enabled state.
- Added `getEventPrepTip` methods to both `ApiClient` and `OutfitGenerationService` for mobile-side prep tip fetching.
- Extended `NotificationPreferencesScreen` with Event Reminders section: toggle, time picker, and formality threshold slider with labels.
- Wired event reminder preferences through `MainShellScreen` and `VestiaireApp` lifecycle.
- Added event reminder scheduling trigger in `HomeScreen._fetchCalendarEvents()` for daily re-evaluation.
- All 1233 API tests pass (1214 baseline + 19 new). All 1671 Flutter tests pass (1634 baseline + 37 new). Zero analyze errors.

### Change Log

- 2026-03-19: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown (FR-EVT-07, FR-EVT-08, FR-PSH-05), architecture, and Stories 12.1-12.2, 4.7, 5.2, 9.6 implementation context.
- 2026-03-19: Story implemented by Dev Agent (Claude Opus 4.6). All 17 tasks completed. Added event_reminders preference key, POST /v1/outfits/event-prep-tips endpoint, EventReminderService (ID 103), EventReminderPreferences, NotificationPreferencesScreen event reminders section, and HomeScreen scheduling integration. 1233 API tests, 1671 Flutter tests all passing.

### File List

**New files:**
- `infra/sql/migrations/036_event_reminders_preference.sql`
- `apps/mobile/lib/src/core/notifications/event_reminder_service.dart`
- `apps/mobile/lib/src/core/notifications/event_reminder_preferences.dart`
- `apps/mobile/test/core/notifications/event_reminder_service_test.dart`
- `apps/mobile/test/core/notifications/event_reminder_preferences_test.dart`

**Modified API files:**
- `apps/api/src/modules/profiles/service.js` (added `event_reminders` to ALLOWED_NOTIFICATION_KEYS and BOOLEAN_ONLY_NOTIFICATION_KEYS)
- `apps/api/src/modules/outfits/outfit-generation-service.js` (added generateEventPrepTip method, buildEventPrepTipPrompt, getFallbackPrepTip)
- `apps/api/src/main.js` (added POST /v1/outfits/event-prep-tips route)
- `apps/api/test/notification-preferences.test.js` (added 3 event_reminders key tests)
- `apps/api/test/modules/outfits/outfit-generation-service.test.js` (added 9 prep tip unit tests)
- `apps/api/test/modules/outfits/outfit-generation.test.js` (added 5 prep tip endpoint integration tests)

**Modified mobile files:**
- `apps/mobile/lib/src/core/networking/api_client.dart` (added getEventPrepTip method)
- `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart` (added getEventPrepTip method)
- `apps/mobile/lib/src/features/notifications/screens/notification_preferences_screen.dart` (added event reminders section with toggle, time picker, formality slider)
- `apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart` (added event reminder service/preferences params and wiring)
- `apps/mobile/lib/src/app.dart` (added EventReminderService/Preferences lifecycle integration)
- `apps/mobile/lib/src/features/home/screens/home_screen.dart` (added eventReminderService/Preferences params, _updateEventReminder method)
- `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart` (added 4 prep tip tests)
- `apps/mobile/test/features/notifications/screens/notification_preferences_screen_test.dart` (added 11 event reminder section tests, updated existing tests for compatibility)
- `apps/mobile/test/features/home/screens/home_screen_test.dart` (added 3 event reminder integration tests)
