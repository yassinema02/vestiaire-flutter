# Story 3.4: Calendar Sync Permission & Selection

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to connect my device calendar to Vestiaire and select which calendars to sync,
so that the app knows what events I have planned and can tailor outfit suggestions accordingly.

## Acceptance Criteria

1. Given I am on the Home screen and have not yet connected my calendar, when the weather section is loaded, then I see a "Connect Calendar" prompt card below the dressing tip (or below the weather section if no dressing tip) that explains why calendar access improves outfit suggestions, with a "Connect Calendar" button and a "Not Now" dismiss option (FR-CTX-07).
2. Given I tap the "Connect Calendar" button, when the native calendar permission dialog appears, then the system requests read-only calendar access using the `device_calendar` plugin and I can grant or deny permission (FR-CTX-07).
3. Given I grant calendar permission, when the permission is confirmed, then the app retrieves the list of all device calendars (work, personal, holidays, etc.) and presents a calendar selection screen listing each calendar with its name, account name, color indicator, and a toggle switch (FR-CTX-08).
4. Given I am on the calendar selection screen, when I view the list, then all calendars are toggled ON by default so that the system syncs broadly unless I explicitly opt out (FR-CTX-08).
5. Given I am on the calendar selection screen, when I toggle individual calendars on/off and tap "Done", then my calendar selection preferences are persisted locally via `shared_preferences` and only selected calendars will be used for event fetching in Story 3.5 (FR-CTX-08).
6. Given I deny calendar permission (or the OS reports "denied forever"), when the permission check completes, then the calendar prompt card updates to show a "Calendar access denied" state with a brief explanation and a "Grant Access" button that opens device settings, similar to the weather denied pattern (FR-CTX-07).
7. Given I tap "Not Now" on the calendar prompt card, when the dismissal is recorded, then the prompt is hidden for the current session and the dismissal is persisted in `shared_preferences` so the card does not re-appear on subsequent app launches until the user navigates to Settings to enable it manually (FR-CTX-07).
8. Given I have previously connected my calendar, when I navigate to Profile > Settings, then I see a "Calendar Sync" section showing connection status (connected/not connected), the number of selected calendars, and a tap action to re-open the calendar selection screen to change my preferences (FR-CTX-07, FR-CTX-08).
9. Given I change my calendar selection in Settings (toggle calendars on/off), when I tap "Done", then the updated preferences are persisted and will be used by Story 3.5 for the next event fetch cycle (FR-CTX-08).
10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass and new tests cover: calendar permission request flow, calendar list retrieval, calendar selection persistence, permission denied state, "Not Now" dismissal persistence, Settings calendar section, and the Home screen calendar prompt card lifecycle.

## Tasks / Subtasks

- [x] Task 1: Mobile - Add `device_calendar` dependency (AC: 2, 3)
  - [x] 1.1: Add `device_calendar: ^4.3.3` to `apps/mobile/pubspec.yaml` under `dependencies`. Run `flutter pub get` to resolve.
  - [x]1.2: Add iOS calendar usage description to `apps/mobile/ios/Runner/Info.plist`: key `NSCalendarsUsageDescription` with value "Vestiaire uses your calendar to suggest outfits that match your upcoming events." Also add `NSCalendarsFullAccessUsageDescription` for iOS 17+ with the same message.
  - [x]1.3: Add Android calendar permission to `apps/mobile/android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.READ_CALENDAR" />`. No WRITE_CALENDAR is needed -- the app only reads events.

- [x]Task 2: Mobile - Create CalendarService (AC: 2, 3, 4, 5, 8, 9)
  - [x]2.1: Create `apps/mobile/lib/src/core/calendar/calendar_service.dart` with a `CalendarService` class. Constructor accepts an optional `DeviceCalendarPlugin` for test injection (following the same DI pattern as `LocationService` and `NotificationService`).
  - [x]2.2: Implement `Future<CalendarPermissionStatus> checkPermission()` that calls `_plugin.hasPermissions()` and returns a simplified enum: `granted`, `denied`, `unknown`. This abstracts the plugin's result type.
  - [x]2.3: Implement `Future<CalendarPermissionStatus> requestPermission()` that calls `_plugin.requestPermissions()` and returns the same simplified enum.
  - [x]2.4: Implement `Future<List<DeviceCalendar>> getCalendars()` that calls `_plugin.retrieveCalendars()` and returns a list of `DeviceCalendar` objects (a simplified model wrapping the plugin's `Calendar` type). Each `DeviceCalendar` contains: `String id`, `String name`, `String? accountName`, `Color? color`, `bool isReadOnly`. Filter out any null-ID calendars.
  - [x]2.5: Define a `CalendarPermissionStatus` enum in the same file: `granted`, `denied`, `unknown`.
  - [x]2.6: Define a `DeviceCalendar` class in the same file with fields: `String id`, `String name`, `String? accountName`, `Color? color`, `bool isReadOnly`. Include a `factory DeviceCalendar.fromPlugin(Calendar calendar)` constructor that maps from the `device_calendar` plugin's `Calendar` type.

- [x]Task 3: Mobile - Create CalendarPreferencesService (AC: 5, 7, 9)
  - [x]3.1: Create `apps/mobile/lib/src/core/calendar/calendar_preferences_service.dart` with a `CalendarPreferencesService` class. Constructor accepts optional `SharedPreferences` for test injection (same DI pattern as HomeScreen's SharedPreferences usage).
  - [x]3.2: Implement `Future<void> saveSelectedCalendarIds(List<String> calendarIds)` that stores the selected calendar IDs as a JSON-encoded string list in SharedPreferences under key `"calendar_selected_ids"`.
  - [x]3.3: Implement `Future<List<String>?> getSelectedCalendarIds()` that reads and decodes the stored calendar IDs. Returns `null` if no selection has been saved (first-time user -- Story 3.5 should treat null as "all calendars" on first sync).
  - [x]3.4: Implement `Future<void> setCalendarDismissed(bool dismissed)` that stores whether the user tapped "Not Now" on the calendar prompt, under key `"calendar_prompt_dismissed"`.
  - [x]3.5: Implement `Future<bool> isCalendarDismissed()` that reads the dismissed flag. Returns `false` if not set.
  - [x]3.6: Implement `Future<void> setCalendarConnected(bool connected)` that stores whether the user has successfully granted calendar permission, under key `"calendar_connected"`.
  - [x]3.7: Implement `Future<bool> isCalendarConnected()` that reads the connected flag. Returns `false` if not set.
  - [x]3.8: Implement `Future<void> clearCalendarPreferences()` that removes all calendar-related keys. This supports account deletion/sign-out cleanup.

- [x]Task 4: Mobile - Create CalendarPermissionCard widget (AC: 1, 6, 7)
  - [x]4.1: Create `apps/mobile/lib/src/features/home/widgets/calendar_permission_card.dart` with a `CalendarPermissionCard` StatelessWidget. It accepts callbacks: `VoidCallback onConnectCalendar`, `VoidCallback onNotNow`.
  - [x]4.2: Display a card matching the Vibrant Soft-UI design system -- **identical card styling to `LocationPermissionCard`**: white background, 16px border radius, `Border.all(color: Color(0xFFD1D5DB))`, subtle shadow (`Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, 2)`), padding `EdgeInsets.all(24)`. Content: a calendar icon (Icons.calendar_month, **48px** matching LocationPermissionCard icon size, color #4F46E5), a title "Plan outfits around your events", a subtitle explaining the benefit ("Connect your calendar so Vestiaire can suggest outfits that match your meetings, dinners, and activities"), a primary "Connect Calendar" button (#4F46E5 background, white text, full-width, **50px height** matching LocationPermissionCard, 12px border radius), and a "Not Now" text button below (#6B7280, 14px, 44px height).
  - [x]4.3: Add `Semantics` label: "Connect calendar to get event-aware outfit suggestions".
  - [x]4.4: Create a `CalendarDeniedCard` StatelessWidget in the same file (or a separate file `calendar_denied_card.dart`). It accepts `VoidCallback onGrantAccess`. Display: calendar icon with a warning overlay, "Calendar access needed" title, explanation text, and a "Grant Access" button that opens device settings. Follow the same pattern as `WeatherDeniedCard`.

- [x]Task 5: Mobile - Create CalendarSelectionScreen (AC: 3, 4, 5, 9)
  - [x]5.1: Create `apps/mobile/lib/src/features/home/screens/calendar_selection_screen.dart` with a `CalendarSelectionScreen` StatefulWidget. Constructor accepts: `List<DeviceCalendar> calendars`, optional `CalendarPreferencesService` for test injection, optional `List<String>? previouslySelectedIds` (for returning users editing their selection).
  - [x]5.2: Initialize state: if `previouslySelectedIds` is provided, use those; otherwise, default all calendars to selected (toggled ON). Store selection as a `Map<String, bool>` mapping calendar ID to selected state.
  - [x]5.3: Build UI: AppBar with title "Select Calendars" and a "Done" action button. Body is a `ListView` of calendar items, each showing: a colored circle indicator (12px, using the calendar's color or a default grey), the calendar name (16px, #111827), the account name below (13px, #6B7280), and a `Switch` widget on the trailing side. Read-only calendars should still appear but can optionally show a subtle "(read-only)" label.
  - [x]5.4: On "Done" tap: collect all selected calendar IDs, call `CalendarPreferencesService.saveSelectedCalendarIds(selectedIds)`, call `CalendarPreferencesService.setCalendarConnected(true)`, and pop the screen returning `true` to indicate selection was saved.
  - [x]5.5: On back navigation without tapping "Done": pop returning `false` (no changes saved). If this is first-time setup and user backs out without confirming, do NOT mark calendar as connected.
  - [x]5.6: Add `Semantics` labels for each calendar toggle: "Toggle sync for [calendar name]".

- [x]Task 6: Mobile - Integrate calendar prompt into HomeScreen (AC: 1, 2, 6, 7)
  - [x]6.1: Add `CalendarService` and `CalendarPreferencesService` as optional constructor parameters to `HomeScreen` (following existing DI pattern with `WeatherCacheService`, `OutfitContextService`).
  - [x]6.2: Add `_CalendarState` enum to track calendar status: `unknown`, `promptVisible`, `denied`, `connected`, `dismissed`. Add `_calendarState` field to `HomeScreenState`, default `unknown`.
  - [x]6.3: Add `_checkCalendarStatus()` method: read `isCalendarConnected()` and `isCalendarDismissed()` from preferences. If connected, set state to `connected`. If dismissed, set state to `dismissed`. Otherwise, check actual permission via `CalendarService.checkPermission()`. If granted (user may have granted outside the app), set connected. If denied-forever, set `denied`. Otherwise set `promptVisible`.
  - [x]6.4: Call `_checkCalendarStatus()` in `_initialize()` after SharedPreferences is loaded, so the calendar state is known before the first build.
  - [x]6.5: Add `_handleConnectCalendar()` method: call `CalendarService.requestPermission()`. If granted, call `CalendarService.getCalendars()` and navigate to `CalendarSelectionScreen`. On return, if selection was saved, update `_calendarState` to `connected`. If permission denied, set state to `denied`.
  - [x]6.6: Add `_handleCalendarNotNow()` method: call `CalendarPreferencesService.setCalendarDismissed(true)`, set `_calendarState` to `dismissed`.
  - [x]6.7: Add `_handleCalendarGrantAccess()` method: open device app settings (use `Geolocator.openAppSettings()` or equivalent -- the `device_calendar` plugin does not have a dedicated settings opener, so use a platform-agnostic approach).
  - [x]6.8: Update `build()`: after the dressing tip widget (or after the weather section if no dressing tip), add the calendar prompt card based on `_calendarState`: if `promptVisible`, show `CalendarPermissionCard`; if `denied`, show `CalendarDeniedCard`; if `connected` or `dismissed`, show nothing.

- [x]Task 7: Mobile - Create Settings calendar section placeholder (AC: 8, 9)
  - [x]7.1: Create `apps/mobile/lib/src/features/settings/widgets/calendar_settings_section.dart` with a `CalendarSettingsSection` StatelessWidget. It accepts: `bool isConnected`, `int selectedCalendarCount`, `VoidCallback onTap`.
  - [x]7.2: Display a list tile with: leading calendar icon, title "Calendar Sync", subtitle showing either "Connected - X calendars synced" or "Not connected", trailing chevron icon. On tap, trigger `onTap` callback (which navigates to CalendarSelectionScreen or initiates permission flow).
  - [x]7.3: This is a self-contained widget. Integration into a full Settings screen is deferred to a future story if no Settings screen exists yet. For now, it is available as a building block. If a Settings screen already exists, integrate it there.

- [x]Task 8: Unit tests for CalendarService (AC: 2, 3, 10)
  - [x]8.1: Create `apps/mobile/test/core/calendar/calendar_service_test.dart`:
    - `checkPermission()` returns `granted` when plugin reports permissions granted.
    - `checkPermission()` returns `denied` when plugin reports permissions denied.
    - `requestPermission()` returns `granted` when plugin grants permissions.
    - `requestPermission()` returns `denied` when plugin denies permissions.
    - `getCalendars()` returns mapped list of DeviceCalendar objects from plugin results.
    - `getCalendars()` filters out calendars with null IDs.
    - `getCalendars()` returns empty list when plugin returns no calendars.
    - `DeviceCalendar.fromPlugin()` correctly maps all fields (id, name, accountName, color, isReadOnly).

- [x]Task 9: Unit tests for CalendarPreferencesService (AC: 5, 7, 9, 10)
  - [x]9.1: Create `apps/mobile/test/core/calendar/calendar_preferences_service_test.dart`:
    - `saveSelectedCalendarIds()` stores IDs in SharedPreferences.
    - `getSelectedCalendarIds()` returns stored IDs.
    - `getSelectedCalendarIds()` returns null when no selection stored.
    - `setCalendarDismissed(true)` persists dismissed flag.
    - `isCalendarDismissed()` returns true after dismissal.
    - `isCalendarDismissed()` returns false when never set.
    - `setCalendarConnected(true)` persists connected flag.
    - `isCalendarConnected()` returns correct value.
    - `clearCalendarPreferences()` removes all calendar keys.
    - Round-trip: save then get returns same IDs.

- [x] Task 10: Widget tests for CalendarPermissionCard and CalendarDeniedCard (AC: 1, 6, 10)
  - [x]10.1: Create `apps/mobile/test/features/home/widgets/calendar_permission_card_test.dart`:
    - Renders calendar icon, title, subtitle, "Connect Calendar" button, and "Not Now" button.
    - "Connect Calendar" button triggers onConnectCalendar callback.
    - "Not Now" button triggers onNotNow callback.
    - Semantics label is present.
    - CalendarDeniedCard renders "Calendar access needed" title and "Grant Access" button.
    - CalendarDeniedCard "Grant Access" button triggers onGrantAccess callback.

- [x] Task 11: Widget tests for CalendarSelectionScreen (AC: 3, 4, 5, 10)
  - [x]11.1: Create `apps/mobile/test/features/home/screens/calendar_selection_screen_test.dart`:
    - Renders list of calendars with names and account names.
    - All calendars are toggled ON by default (first-time user).
    - User can toggle individual calendars off and on.
    - Tapping "Done" saves selected calendar IDs to preferences and pops screen.
    - Previously selected IDs are restored when editing (returning user).
    - Calendar color indicators are displayed.
    - Semantics labels are present for each toggle.
    - Navigating back without "Done" does not save changes.

- [x] Task 12: Widget tests for HomeScreen calendar integration (AC: 1, 2, 6, 7, 10)
  - [x]12.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When weather is loaded and calendar is not connected/dismissed, CalendarPermissionCard appears below dressing tip.
    - When calendar permission is granted and selection saved, CalendarPermissionCard disappears.
    - When "Not Now" is tapped, CalendarPermissionCard disappears and does not re-appear on rebuild.
    - When calendar permission is permanently denied, CalendarDeniedCard shows instead.
    - When calendar is already connected, no calendar prompt card appears.
    - All existing HomeScreen tests continue to pass (location permission flow, weather widget, forecast, dressing tip, cache, staleness, error).

- [x] Task 13: Widget test for CalendarSettingsSection (AC: 8, 10)
  - [x]13.1: Create `apps/mobile/test/features/settings/widgets/calendar_settings_section_test.dart`:
    - Renders "Calendar Sync" title.
    - Shows "Connected - X calendars synced" when connected.
    - Shows "Not connected" when not connected.
    - Tap triggers onTap callback.

- [x] Task 14: Regression testing (AC: all)
  - [x]14.1: Run `flutter analyze` -- zero issues.
  - [x]14.2: Run `flutter test` -- all existing + new tests pass.
  - [x]14.3: Run `npm --prefix apps/api test` -- all existing API tests still pass (no API changes in this story).
  - [x]14.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast widget, dressing tip, cache-first loading, pull-to-refresh, staleness indicator.
  - [x]14.5: Verify the calendar prompt card renders correctly below the weather/dressing tip section and does not interfere with the existing "Daily outfit suggestions coming soon" placeholder.

## Dev Notes

- This is the FOURTH story in Epic 3 (Context Integration -- Weather & Calendar). It builds on Stories 3.1-3.3 which completed the weather integration. This story begins the calendar integration phase.
- The primary FRs covered are FR-CTX-07 (connect device calendar with permission explanation) and FR-CTX-08 (select which calendars to sync).
- **FR-CTX-09 through FR-CTX-13 (event fetching, classification, context compilation) are OUT OF SCOPE.** They are covered in Stories 3.5-3.6. This story ONLY handles permission and calendar selection.
- **No API/backend changes are required.** Calendar permission and selection are entirely on-device operations. The `device_calendar` plugin reads from the OS calendar database directly. No Cloud Run endpoint is involved.
- **No database changes are required.** The `calendar_events` table will be created/populated in Story 3.5. This story only persists calendar preferences locally via `shared_preferences`.
- **The `device_calendar` plugin (^4.3.3)** is the recommended package per the PRD and functional requirements. It supports iOS (EventKit) and Android (CalendarProvider). The plugin requires iOS 13+ and Android API 21+, both well within our iOS 16+ / Android 10+ targets.
- **iOS 17+ dual permission keys:** Starting iOS 17, Apple requires `NSCalendarsFullAccessUsageDescription` in addition to `NSCalendarsUsageDescription`. Both must be present in Info.plist or the permission request will silently fail on iOS 17+.
- **Read-only access:** The app only needs READ access to calendars. We do NOT request WRITE_CALENDAR on Android or write access on iOS. This minimizes the permission footprint and aligns with the "passive context gathering" UX principle.
- **Calendar selection defaults to ALL ON.** The rationale: users who connect their calendar want the app to know about their events. Defaulting to all-on with opt-out toggles is less friction than requiring the user to manually enable each calendar. This matches standard patterns in apps like Google Calendar, Fantastical, etc.
- **"Not Now" dismissal is permanent per-installation** (persisted in SharedPreferences). If the user wants to connect later, they go to Settings. This prevents nagging -- a key UX principle. The alternative (re-prompting after N days) was considered but rejected for MVP to keep it simple.
- **The calendar prompt card appears AFTER weather loads** so it does not compete with the primary weather permission flow. If the user has not yet granted location permission, they see the location permission card first. Calendar prompt only appears once weather is successfully loaded.
- **Story 3.5 will consume the calendar preferences** saved by this story. Specifically, `CalendarPreferencesService.getSelectedCalendarIds()` returns the user's chosen calendars, and `CalendarPreferencesService.isCalendarConnected()` tells Story 3.5 whether to attempt event fetching at all.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/core/calendar/calendar_service.dart` (CalendarService + CalendarPermissionStatus + DeviceCalendar model)
  - `apps/mobile/lib/src/core/calendar/calendar_preferences_service.dart` (CalendarPreferencesService)
  - `apps/mobile/lib/src/features/home/widgets/calendar_permission_card.dart` (CalendarPermissionCard + CalendarDeniedCard)
  - `apps/mobile/lib/src/features/home/screens/calendar_selection_screen.dart` (CalendarSelectionScreen)
  - `apps/mobile/lib/src/features/settings/widgets/calendar_settings_section.dart` (CalendarSettingsSection)
  - `apps/mobile/test/core/calendar/calendar_service_test.dart`
  - `apps/mobile/test/core/calendar/calendar_preferences_service_test.dart`
  - `apps/mobile/test/features/home/widgets/calendar_permission_card_test.dart`
  - `apps/mobile/test/features/home/screens/calendar_selection_screen_test.dart`
  - `apps/mobile/test/features/settings/widgets/calendar_settings_section_test.dart`
- Modified mobile files:
  - `apps/mobile/pubspec.yaml` (add `device_calendar: ^4.3.3`)
  - `apps/mobile/ios/Runner/Info.plist` (add NSCalendarsUsageDescription, NSCalendarsFullAccessUsageDescription)
  - `apps/mobile/android/app/src/main/AndroidManifest.xml` (add READ_CALENDAR permission)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add CalendarService/CalendarPreferencesService DI, calendar state machine, calendar prompt card rendering)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add calendar prompt integration tests)
- Alignment with existing patterns:
  - CalendarService follows the exact same DI pattern as LocationService (accepts optional plugin instance in constructor for test injection).
  - CalendarPreferencesService follows the SharedPreferences pattern already used by HomeScreen for location permission dismissal.
  - CalendarPermissionCard follows the same card design pattern as LocationPermissionCard (icon, title, subtitle, primary button, secondary text button).
  - CalendarDeniedCard follows the same pattern as WeatherDeniedCard.
  - CalendarSelectionScreen is a new screen navigated to via `Navigator.push`, consistent with how other modal flows work in the app.

### Technical Requirements

- **New dependency:** `device_calendar: ^4.3.3` -- cross-platform Flutter plugin for reading device calendar data. Supports iOS EventKit and Android CalendarProvider. Null-safe, actively maintained.
- **Platform configuration required:** iOS Info.plist entries (NSCalendarsUsageDescription, NSCalendarsFullAccessUsageDescription) and Android manifest permission (READ_CALENDAR). Without these, the permission request will fail silently or crash.
- **SharedPreferences keys used:** `"calendar_selected_ids"` (JSON string of List<String>), `"calendar_prompt_dismissed"` (bool), `"calendar_connected"` (bool). These follow the same key naming pattern as `kLocationPermissionDismissedKey`.
- **No network calls in this story.** All operations are local: reading the device calendar list via OS APIs, persisting preferences via SharedPreferences.
- **Flutter SDK constraint:** The project uses SDK `>=3.9.0 <4.0.0`. `device_calendar` ^4.3.3 is compatible with this SDK range.

### Architecture Compliance

- All logic is client-side, per the architecture: "Mobile App Boundary: Owns presentation, gestures, local caching."
- Calendar data stays on-device in this story. Events will be fetched and potentially sent to Cloud Run for AI classification in Story 3.5, which aligns with: "AI calls are brokered only by Cloud Run."
- No database changes. Calendar preferences are local state (SharedPreferences), not server state. The `calendar_events` table in Cloud SQL will be created in Story 3.5.
- The calendar permission flow follows the same progressive disclosure pattern as location permission: explain why, request, handle denial gracefully with settings redirect.

### Library / Framework Requirements

- `device_calendar: ^4.3.3` -- required new dependency. This is the plugin explicitly named in the PRD (FR-CTX-07: "via `device_calendar` plugin") and the functional requirements document.
- No other new dependencies needed. `shared_preferences` is already in pubspec.yaml.

### File Structure Requirements

- New core module: `apps/mobile/lib/src/core/calendar/` -- follows the pattern of `core/weather/`, `core/location/`, `core/auth/`, `core/notifications/`.
- New widgets in `apps/mobile/lib/src/features/home/widgets/` -- follows existing pattern of home-feature widgets (weather_widget, forecast_widget, dressing_tip_widget, location_permission_card, weather_denied_card).
- New screen in `apps/mobile/lib/src/features/home/screens/` -- calendar selection is part of the home feature's onboarding flow, similar to how location permission is handled within home.
- New settings widget in `apps/mobile/lib/src/features/settings/widgets/` -- this creates the settings feature directory. If it does not exist yet, create `features/settings/` and `features/settings/widgets/`.
- Test files mirror the source structure under `apps/mobile/test/`.

### Testing Requirements

- Unit tests must verify:
  - CalendarService permission check/request returns correct enum values
  - CalendarService.getCalendars() correctly maps and filters plugin results
  - DeviceCalendar.fromPlugin() maps all fields
  - CalendarPreferencesService correctly persists and retrieves all preference keys
  - CalendarPreferencesService.clearCalendarPreferences() removes all keys
- Widget tests must verify:
  - CalendarPermissionCard renders all UI elements and triggers callbacks
  - CalendarDeniedCard renders correctly and triggers callback
  - CalendarSelectionScreen displays all calendars with correct default state
  - CalendarSelectionScreen persists selection on "Done"
  - CalendarSelectionScreen does not persist on back navigation
  - HomeScreen shows CalendarPermissionCard when calendar not connected (after weather loads)
  - HomeScreen hides calendar card after connection or dismissal
  - HomeScreen shows CalendarDeniedCard when permission permanently denied
  - CalendarSettingsSection shows correct connection status
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing API tests still pass -- no API changes)
- Target: all existing tests continue to pass plus new tests for calendar feature.

### Previous Story Intelligence

- Story 3.3 (direct predecessor) established: WeatherClothingMapper, OutfitContext model, OutfitContextService, DressingTipWidget, integration into HomeScreen. All weather infrastructure is complete.
- Story 3.3 explicitly stated: "FR-CTX-07 through FR-CTX-12 (calendar sync and event classification) are OUT OF SCOPE for this story. They are covered in Stories 3.4-3.6."
- Story 3.1 established the location permission pattern: LocationService with DI, LocationPermissionCard with "Enable Location"/"Not Now" buttons, WeatherDeniedCard with "Grant Access" button, SharedPreferences for dismissal persistence. This story follows the IDENTICAL pattern for calendar.
- Story 3.1 established: the HomeScreen state machine pattern (_HomeState enum, _buildWeatherSection switch). Calendar adds a parallel state track (_CalendarState) that is independent of the weather state.
- Story 3.2 established: WeatherCacheService with SharedPreferences-based caching. CalendarPreferencesService follows the same SharedPreferences pattern.
- Story 1.6 established: NotificationService with the DI pattern (accepts optional plugin instance). CalendarService follows this same pattern with DeviceCalendarPlugin.
- HomeScreen currently has these constructor parameters: locationService (required), weatherService (required), sharedPreferences (optional), weatherCacheService (optional), outfitContextService (optional). This story adds calendarService (optional) and calendarPreferencesService (optional).
- The HomeScreen build order is: weather section -> forecast widget -> dressing tip -> "coming soon" placeholder. The calendar prompt card goes between the dressing tip and the "coming soon" placeholder.

### Key Anti-Patterns to Avoid

- DO NOT fetch calendar events in this story. Event fetching is Story 3.5. This story ONLY handles permission and calendar selection.
- DO NOT create or modify any database tables. The `calendar_events` table is Story 3.5.
- DO NOT classify events. Event classification (Work, Social, Active, Formal, Casual) is Story 3.5.
- DO NOT add any AI/Gemini calls. Calendar event classification via AI is Story 3.5.
- DO NOT request WRITE access to calendars. The app only reads events. Adding write access would require additional justification in app store review.
- DO NOT store calendar event data in this story. Only calendar IDs (which calendars to sync) and boolean flags (connected, dismissed) are stored.
- DO NOT show the calendar prompt card before weather loads. The location permission flow takes priority. Calendar prompt appears only when weather section is already loaded.
- DO NOT re-prompt users who tapped "Not Now". Once dismissed, the prompt stays hidden until the user goes to Settings.
- DO NOT use `permission_handler` package for calendar permissions. The `device_calendar` plugin has its own permission handling built in (`hasPermissions()`, `requestPermissions()`). Adding `permission_handler` would be redundant.
- DO NOT create a separate API endpoint for calendar operations. Everything in this story is on-device.

### Implementation Guidance

- **CalendarService class:**
  ```dart
  import "package:device_calendar/device_calendar.dart";
  import "package:flutter/material.dart";

  enum CalendarPermissionStatus { granted, denied, unknown }

  class DeviceCalendar {
    const DeviceCalendar({
      required this.id,
      required this.name,
      this.accountName,
      this.color,
      this.isReadOnly = false,
    });

    final String id;
    final String name;
    final String? accountName;
    final Color? color;
    final bool isReadOnly;

    factory DeviceCalendar.fromPlugin(Calendar calendar) {
      return DeviceCalendar(
        id: calendar.id!,
        name: calendar.name ?? "Unnamed Calendar",
        accountName: calendar.accountName,
        color: calendar.color != null ? Color(calendar.color!) : null,
        isReadOnly: calendar.isReadOnly ?? false,
      );
    }
  }

  class CalendarService {
    CalendarService({DeviceCalendarPlugin? plugin})
        : _plugin = plugin ?? DeviceCalendarPlugin();

    final DeviceCalendarPlugin _plugin;

    Future<CalendarPermissionStatus> checkPermission() async {
      final result = await _plugin.hasPermissions();
      if (result.isSuccess && result.data == true) {
        return CalendarPermissionStatus.granted;
      }
      return CalendarPermissionStatus.denied;
    }

    Future<CalendarPermissionStatus> requestPermission() async {
      final result = await _plugin.requestPermissions();
      if (result.isSuccess && result.data == true) {
        return CalendarPermissionStatus.granted;
      }
      return CalendarPermissionStatus.denied;
    }

    Future<List<DeviceCalendar>> getCalendars() async {
      final result = await _plugin.retrieveCalendars();
      if (!result.isSuccess || result.data == null) return [];
      return result.data!
          .where((c) => c.id != null)
          .map((c) => DeviceCalendar.fromPlugin(c))
          .toList();
    }
  }
  ```

- **CalendarPreferencesService class:**
  ```dart
  import "dart:convert";
  import "package:shared_preferences/shared_preferences.dart";

  class CalendarPreferencesService {
    CalendarPreferencesService({SharedPreferences? prefs}) : _prefs = prefs;

    SharedPreferences? _prefs;

    Future<SharedPreferences> _getPrefs() async {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!;
    }

    Future<void> saveSelectedCalendarIds(List<String> calendarIds) async {
      final prefs = await _getPrefs();
      await prefs.setString("calendar_selected_ids", jsonEncode(calendarIds));
    }

    Future<List<String>?> getSelectedCalendarIds() async {
      final prefs = await _getPrefs();
      final stored = prefs.getString("calendar_selected_ids");
      if (stored == null) return null;
      return List<String>.from(jsonDecode(stored));
    }

    Future<void> setCalendarDismissed(bool dismissed) async {
      final prefs = await _getPrefs();
      await prefs.setBool("calendar_prompt_dismissed", dismissed);
    }

    Future<bool> isCalendarDismissed() async {
      final prefs = await _getPrefs();
      return prefs.getBool("calendar_prompt_dismissed") ?? false;
    }

    Future<void> setCalendarConnected(bool connected) async {
      final prefs = await _getPrefs();
      await prefs.setBool("calendar_connected", connected);
    }

    Future<bool> isCalendarConnected() async {
      final prefs = await _getPrefs();
      return prefs.getBool("calendar_connected") ?? false;
    }

    Future<void> clearCalendarPreferences() async {
      final prefs = await _getPrefs();
      await prefs.remove("calendar_selected_ids");
      await prefs.remove("calendar_prompt_dismissed");
      await prefs.remove("calendar_connected");
    }
  }
  ```

- **HomeScreen integration:**
  ```
  Constructor additions:
    this.calendarService,
    this.calendarPreferencesService,

  State additions:
    _CalendarState _calendarState = _CalendarState.unknown;
    late CalendarService _calendarService;
    late CalendarPreferencesService _calendarPreferencesService;

  initState additions:
    _calendarService = widget.calendarService ?? CalendarService();
    _calendarPreferencesService = widget.calendarPreferencesService ?? CalendarPreferencesService();

  _initialize() additions (after SharedPreferences loads):
    await _checkCalendarStatus();

  build() additions (after dressing tip, before "coming soon" placeholder):
    if (_calendarState == _CalendarState.promptVisible) ...[
      const SizedBox(height: 16),
      CalendarPermissionCard(
        onConnectCalendar: _handleConnectCalendar,
        onNotNow: _handleCalendarNotNow,
      ),
    ],
    if (_calendarState == _CalendarState.denied) ...[
      const SizedBox(height: 16),
      CalendarDeniedCard(onGrantAccess: _handleCalendarGrantAccess),
    ],
  ```

### References

- [Source: epics.md - Story 3.4: Calendar Sync Permission & Selection]
- [Source: epics.md - Epic 3: Context Integration (Weather & Calendar)]
- [Source: prd.md - FR-CTX-07: Users shall connect their device Calendar to the app with permission explanation (device_calendar plugin)]
- [Source: prd.md - FR-CTX-08: Users shall select which calendars to sync (work, personal, etc.)]
- [Source: functional-requirements.md - Section 3.5 Context Integration (Weather & Calendar)]
- [Source: functional-requirements.md - Device Calendar: device_calendar Flutter plugin, N/A (on-device)]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures, local caching]
- [Source: architecture.md - Epic 3 Context Integration -> mobile/features/home, api/modules/weather, api/modules/calendar, api/modules/ai]
- [Source: architecture.md - Project Structure: apps/mobile/lib/src/core/, apps/mobile/lib/src/features/]
- [Source: ux-design-specification.md - Passive Context Gathering: Weather and calendar data are pulled automatically]
- [Source: ux-design-specification.md - Context Header showing temperature and primary calendar event]
- [Source: 3-1-location-permission-weather-widget.md - LocationService DI pattern, LocationPermissionCard, WeatherDeniedCard, SharedPreferences dismissal]
- [Source: 3-3-practical-weather-aware-outfit-context.md - "FR-CTX-07 through FR-CTX-12 (calendar sync and event classification) are OUT OF SCOPE for this story. They are covered in Stories 3.4-3.6."]
- [Source: 3-3-practical-weather-aware-outfit-context.md - OutfitContext designed to be extensible for calendar data]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Fixed mock DeviceCalendarPlugin: `Result.isSuccess` is a computed getter (not settable), `retrieveCalendars()` returns `UnmodifiableListView<Calendar>`, constructor requires `DeviceCalendarPlugin.private()` for tests.
- Fixed analyzer error: `jsonDecode()` returns `dynamic`, needs explicit cast to `List` for `List<String>.from()`.
- Fixed HomeScreen calendar integration tests: calendar card rendered below viewport required scrolling before tap interactions.
- Fixed Semantics test approach: `find.bySemanticsLabel` does not match `Semantics` widget labels in tests; used `find.byWidgetPredicate` instead.

### Completion Notes List

- Implemented CalendarService with DI pattern matching LocationService (accepts optional DeviceCalendarPlugin).
- Implemented CalendarPreferencesService with SharedPreferences-based persistence for calendar selection, dismissal, and connection state.
- Created CalendarPermissionCard and CalendarDeniedCard widgets matching Vibrant Soft-UI design system (identical styling to LocationPermissionCard and WeatherDeniedCard).
- Created CalendarSelectionScreen with toggle-based calendar selection, default all-ON, and proper Done/Back navigation handling via PopScope.
- Integrated calendar prompt into HomeScreen with independent _CalendarState state machine. Calendar card appears only after weather loads, between dressing tip and "coming soon" placeholder.
- Created CalendarSettingsSection widget as a self-contained building block for future Settings screen integration.
- Added device_calendar: ^4.3.3 dependency with iOS Info.plist calendar usage descriptions (NSCalendarsUsageDescription + NSCalendarsFullAccessUsageDescription for iOS 17+) and Android READ_CALENDAR permission.
- All 494 Flutter tests pass (0 failures). All 146 API tests pass. Flutter analyze: 0 issues.

### Change Log

- 2026-03-13: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirements (FR-CTX-07, FR-CTX-08), UX design specification, and Stories 3.1-3.3 implementation context.
- 2026-03-13: Story implemented by Dev Agent (Claude Opus 4.6). All 14 tasks completed. Calendar permission flow, calendar selection screen, HomeScreen integration, settings widget, and comprehensive tests added.

### File List

New files:
- apps/mobile/lib/src/core/calendar/calendar_service.dart
- apps/mobile/lib/src/core/calendar/calendar_preferences_service.dart
- apps/mobile/lib/src/features/home/widgets/calendar_permission_card.dart
- apps/mobile/lib/src/features/home/screens/calendar_selection_screen.dart
- apps/mobile/lib/src/features/settings/widgets/calendar_settings_section.dart
- apps/mobile/ios/Runner/Info.plist
- apps/mobile/android/app/src/main/AndroidManifest.xml
- apps/mobile/test/core/calendar/calendar_service_test.dart
- apps/mobile/test/core/calendar/calendar_preferences_service_test.dart
- apps/mobile/test/features/home/widgets/calendar_permission_card_test.dart
- apps/mobile/test/features/home/screens/calendar_selection_screen_test.dart
- apps/mobile/test/features/settings/widgets/calendar_settings_section_test.dart

Modified files:
- apps/mobile/pubspec.yaml (added device_calendar: ^4.3.3)
- apps/mobile/lib/src/features/home/screens/home_screen.dart (added CalendarService/CalendarPreferencesService DI, _CalendarState state machine, calendar prompt rendering)
- apps/mobile/test/features/home/screens/home_screen_test.dart (added calendar integration tests, updated pumpHomeScreen helper with calendar mock support)
