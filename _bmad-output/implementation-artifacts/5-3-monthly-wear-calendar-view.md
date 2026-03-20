# Story 5.3: Monthly Wear Calendar View

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see a calendar view of my logging activity,
so that I can visually track my consistency and history over the month.

## Acceptance Criteria

1. Given I navigate to the Analytics section, when the screen loads, then I see a dedicated "Wear Calendar" screen accessible from the Analytics feature area (e.g., via a tab, button, or navigation route from the Home screen or profile). The calendar defaults to the current month. (FR-LOG-07)

2. Given I am on the Wear Calendar screen, when the current month is displayed, then I see a standard month-view calendar grid with day cells. Days on which I have logged at least one outfit show a visual activity indicator (a colored dot or fill) distinguishing them from days with no activity. Days with no logs appear without an indicator. (FR-LOG-07)

3. Given I am on the Wear Calendar screen, when I tap the left arrow or swipe right, then the calendar navigates to the previous month. When I tap the right arrow or swipe left, the calendar navigates to the next month. Navigation does not allow navigating to future months beyond the current month. (FR-LOG-07)

4. Given I am viewing a month on the Wear Calendar, when the month loads, then the app fetches wear logs for that month's date range via `GET /v1/wear-logs?start=YYYY-MM-01&end=YYYY-MM-DD` (using the first and last day of the month) and maps each log's `loggedDate` to the corresponding calendar cell. (FR-LOG-07)

5. Given I am on the Wear Calendar screen, when I tap on a day that has wear log activity, then a bottom sheet or overlay appears showing the specific items logged on that day. Each item displays its thumbnail image (from `photo_url`), name or category label, and the number of times it appeared in logs that day. If the log was from a saved outfit, the outfit name is shown. (FR-LOG-07)

6. Given I tap on a day with no wear log activity, when the day cell is tapped, then nothing happens (no overlay appears), OR optionally a subtle empty-state message is shown (e.g., "No outfits logged this day").

7. Given I am on the Wear Calendar screen, when the month data is loaded, then a summary row is displayed (above or below the calendar) showing: total days logged this month, total items logged this month, and current logging streak (consecutive days with at least one log ending on today or the most recent logged day).

8. Given the API call to fetch wear logs for a month fails (network error, server error), when the calendar screen attempts to load, then an error state is shown with a "Retry" button. Tapping retry re-fetches the data.

9. Given I have no wear logs at all, when I open the Wear Calendar screen, then the calendar renders with no activity indicators on any day and a friendly empty-state message (e.g., "Start logging your outfits to see your activity here!") is displayed below the calendar.

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (337 API tests, 806 Flutter tests) and new tests cover: WearCalendarScreen widget rendering, month navigation, day-tap detail overlay, activity indicator mapping, summary row computation, error state, empty state, WearLogService integration, and edge cases.

## Tasks / Subtasks

- [ ] Task 1: Mobile - Create WearCalendarScreen widget (AC: 1, 2, 3, 4, 8, 9)
  - [ ] 1.1: Create `apps/mobile/lib/src/features/analytics/screens/wear_calendar_screen.dart` with a `WearCalendarScreen` StatefulWidget. Constructor accepts: `required WearLogService wearLogService`, `ApiClient? apiClient` (for fetching item details on day-tap), optional `DateTime? initialMonth` (for testing).
  - [ ] 1.2: Implement a custom month-view calendar grid using Flutter's built-in widgets (no external package needed -- use a `GridView` with 7 columns for days of the week). Display the month/year header (e.g., "March 2026") with left/right chevron `IconButton` widgets for navigation.
  - [ ] 1.3: Each day cell renders the day number. Days belonging to the displayed month are styled normally; days from adjacent months are dimmed or hidden. Today's date is highlighted with a distinct border or background (primary color #4F46E5 at 10% opacity).
  - [ ] 1.4: Maintain state: `_currentMonth` (DateTime, first day of month), `_wearLogsByDate` (Map<String, List<WearLog>>, keyed by ISO date "YYYY-MM-DD"), `_isLoading` (bool), `_error` (String?).
  - [ ] 1.5: On `initState()` and whenever `_currentMonth` changes, call `_fetchMonthData()` which: sets `_isLoading = true`, calls `wearLogService.getLogsForDateRange(firstDayOfMonth, lastDayOfMonth)`, groups the returned logs by `loggedDate` into `_wearLogsByDate`, sets `_isLoading = false`. On error, sets `_error` with the error message.
  - [ ] 1.6: Render activity indicators: for each day cell, check if `_wearLogsByDate` contains an entry for that date. If yes, render a small colored dot (6px diameter, primary color #4F46E5) centered below the day number. If multiple logs exist, still show a single dot (the count detail is in the day-tap overlay).
  - [ ] 1.7: Month navigation: left chevron calls `setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1); })` and triggers `_fetchMonthData()`. Right chevron does the same for next month but is disabled (greyed out) if `_currentMonth` is the current month (cannot navigate to future months).
  - [ ] 1.8: Loading state: show a `CircularProgressIndicator` centered over the calendar grid while `_isLoading` is true.
  - [ ] 1.9: Error state: show error message with a "Retry" `TextButton`. Tapping retry calls `_fetchMonthData()` again.
  - [ ] 1.10: Empty state: when `_wearLogsByDate` is empty after successful load, show a centered text message below the calendar: "Start logging your outfits to see your activity here!" with a subtle icon (e.g., `Icons.calendar_today`).
  - [ ] 1.11: Add `Semantics` labels: "Wear calendar for [Month Year]", "Previous month", "Next month", "Day [N], [count] outfits logged" (for days with activity), "Day [N], no outfits logged" (for inactive days).

- [ ] Task 2: Mobile - Create DayDetailBottomSheet widget (AC: 5, 6)
  - [ ] 2.1: Create `apps/mobile/lib/src/features/analytics/widgets/day_detail_bottom_sheet.dart` with a `DayDetailBottomSheet` StatelessWidget. Constructor accepts: `required String date` (ISO date string), `required List<WearLog> wearLogs`, `ApiClient? apiClient` (for resolving item thumbnails).
  - [ ] 2.2: The bottom sheet header shows the formatted date (e.g., "Monday, March 18, 2026") and the total number of items logged.
  - [ ] 2.3: Body: a scrollable list of wear log entries for the day. Each entry shows:
    - Log time (from `createdAt`, formatted as "2:30 PM")
    - If `outfitId` is not null: "Logged outfit" label
    - List of item IDs with thumbnails. Since the `WearLog` model only contains `itemIds` (not full item data), load item details from `apiClient.listItems()` (already cached in most cases) OR display item IDs as placeholders with a "Loading..." shimmer. Each item shows a small circular thumbnail (32x32) and the item name/category.
  - [ ] 2.4: If no wear logs exist for the tapped day (empty list), do not show the bottom sheet (handled in Task 1 -- only open bottom sheet for days with activity).
  - [ ] 2.5: Add `Semantics` labels: "Outfit details for [date]", "Logged [count] items".

- [ ] Task 3: Mobile - Integrate day-tap to open DayDetailBottomSheet (AC: 5, 6)
  - [ ] 3.1: In `WearCalendarScreen`, make day cells with activity tappable via `GestureDetector` or `InkWell`. On tap, call `showModalBottomSheet` with `DayDetailBottomSheet(date: tappedDate, wearLogs: _wearLogsByDate[tappedDate]!, apiClient: widget.apiClient)`.
  - [ ] 3.2: Day cells without activity are not tappable (no `GestureDetector`), or tapping shows nothing.
  - [ ] 3.3: Add a subtle ripple effect on tappable day cells to indicate interactivity.

- [ ] Task 4: Mobile - Create MonthSummaryRow widget (AC: 7)
  - [ ] 4.1: Create `apps/mobile/lib/src/features/analytics/widgets/month_summary_row.dart` with a `MonthSummaryRow` StatelessWidget. Constructor accepts: `required Map<String, List<WearLog>> wearLogsByDate`, `required DateTime currentMonth`.
  - [ ] 4.2: Compute and display three metrics in a horizontal row of cards:
    - **Days Logged**: count of unique dates in `wearLogsByDate` that have at least one entry. Display with a calendar icon.
    - **Items Logged**: sum of all `itemIds.length` across all `WearLog` entries for the month. Display with a checkmark icon.
    - **Current Streak**: calculate the longest consecutive-day streak ending on today (or the most recent logged date). Walk backward from today counting consecutive days that appear in `wearLogsByDate`. Display with a flame icon.
  - [ ] 4.3: Each metric card has: icon (24px, primary color), value (20px bold, #1F2937), label (12px, #6B7280). Cards are evenly distributed across the row width.
  - [ ] 4.4: Place the `MonthSummaryRow` above the calendar grid in the `WearCalendarScreen`, below the month/year header.
  - [ ] 4.5: Add `Semantics` labels: "[N] days logged", "[N] items logged", "[N] day streak".

- [ ] Task 5: Mobile - Add navigation route to WearCalendarScreen (AC: 1)
  - [ ] 5.1: Add a "Wear Calendar" entry point. Option A (recommended): Add a "View Calendar" button/link on the HomeScreen below or near the "Log Today's Outfit" button. Tapping it pushes the `WearCalendarScreen` as a full-screen route via `Navigator.of(context).push(MaterialPageRoute(...))`. Option B: Add to the analytics section when it exists.
  - [ ] 5.2: The button should be a `TextButton` or `OutlinedButton` with an icon (`Icons.calendar_month`) and label "Wear Calendar". Styled with primary color text (#4F46E5).
  - [ ] 5.3: Pass the `WearLogService` and `ApiClient` from the HomeScreen to the `WearCalendarScreen`.
  - [ ] 5.4: Add `Semantics` label: "View wear calendar".

- [ ] Task 6: Mobile - Unit tests for WearCalendarScreen (AC: 2, 3, 4, 7, 8, 9, 10)
  - [ ] 6.1: Create `apps/mobile/test/features/analytics/screens/wear_calendar_screen_test.dart`:
    - Renders current month header by default.
    - Displays day cells with activity indicators for dates with wear logs.
    - Does not display activity indicators for dates without wear logs.
    - Left chevron navigates to previous month and re-fetches data.
    - Right chevron navigates to next month (when not at current month).
    - Right chevron is disabled when viewing the current month.
    - Loading state shows CircularProgressIndicator.
    - Error state shows error message and retry button.
    - Tapping retry re-fetches data.
    - Empty state shows "Start logging your outfits" message.
    - Today's date cell has highlight styling.
    - Summary row displays correct days logged, items logged, and streak.
    - Semantics labels are present on calendar, navigation, and day cells.
    - Calls `wearLogService.getLogsForDateRange` with correct month boundaries.

- [ ] Task 7: Mobile - Widget tests for DayDetailBottomSheet (AC: 5, 6, 10)
  - [ ] 7.1: Create `apps/mobile/test/features/analytics/widgets/day_detail_bottom_sheet_test.dart`:
    - Renders date header with formatted date.
    - Displays wear log entries with timestamps.
    - Shows "Logged outfit" label when outfitId is present.
    - Displays item IDs / thumbnails for each log entry.
    - Shows total items logged count.
    - Semantics labels are present.

- [ ] Task 8: Mobile - Widget tests for MonthSummaryRow (AC: 7, 10)
  - [ ] 8.1: Create `apps/mobile/test/features/analytics/widgets/month_summary_row_test.dart`:
    - Displays correct "Days Logged" count.
    - Displays correct "Items Logged" count.
    - Computes correct streak (consecutive days ending on today).
    - Streak is 0 when no logs exist.
    - Streak handles gaps correctly (resets on missed day).
    - Semantics labels are present.

- [ ] Task 9: Mobile - Widget tests for HomeScreen calendar navigation (AC: 1, 10)
  - [ ] 9.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - "Wear Calendar" button renders on HomeScreen.
    - Tapping the button navigates to WearCalendarScreen.
    - All existing HomeScreen tests continue to pass.

- [ ] Task 10: Regression testing (AC: all)
  - [ ] 10.1: Run `flutter analyze` -- zero issues.
  - [ ] 10.2: Run `flutter test` -- all existing 806 + new Flutter tests pass.
  - [ ] 10.3: Run `npm --prefix apps/api test` -- all existing 337 API tests pass (no API changes in this story).
  - [ ] 10.4: Verify existing HomeScreen tests pass with the new "Wear Calendar" button (no regressions on outfit logging, weather, notifications).
  - [ ] 10.5: Verify existing LogOutfitBottomSheet tests still pass.
  - [ ] 10.6: Verify existing WearLogService tests still pass.

## Dev Notes

- This is the **third story in Epic 5** (Wardrobe Analytics & Wear Logging). It builds on Story 5.1 (wear logging infrastructure) and Story 5.2 (evening reminder). It is the last wear-logging FR before the analytics dashboard stories (5.4-5.7).
- This story implements **FR-LOG-07** ("Wear logs shall be viewable in a monthly calendar view with daily activity indicators").
- **No API changes are needed.** The existing `GET /v1/wear-logs?start=&end=` endpoint (from Story 5.1) provides all the data needed. The calendar screen fetches one month at a time.
- **No database migration is needed.** The `wear_logs` and `wear_log_items` tables from Story 5.1 already contain all required data.
- **No new dependencies are needed.** The calendar grid is built with standard Flutter widgets (`GridView`, `Row`, `Column`). Using a third-party calendar package (e.g., `table_calendar`) is NOT recommended -- it adds unnecessary dependency weight for a simple month grid. The `intl` package (already in pubspec.yaml) handles date formatting.

### Design Decision: Custom Calendar Grid vs Third-Party Package

A custom month-view calendar grid is built using Flutter's built-in widgets rather than adding `table_calendar` or similar packages because:
1. **Minimal requirements:** FR-LOG-07 only requires a month view with activity indicators and day-tap detail. No complex features (event markers, range selection, multi-day events) are needed.
2. **Dependency minimization:** The project already has 19 dependencies. Adding a calendar package for a simple grid is unnecessary overhead.
3. **Full control:** Custom styling for activity indicators, today highlight, and empty states is easier without fighting a third-party API.
4. **Future-proofing:** Epic 11 (FR-HMP-01 through FR-HMP-04) will introduce a more advanced calendar heatmap with Month/Quarter/Year views and streak tracking. That story will likely need different visualization than a standard calendar widget. Building a simple custom grid now avoids migration costs later.

### Design Decision: Navigation Entry Point

The Wear Calendar is accessed via a "Wear Calendar" button on the HomeScreen (near the "Log Today's Outfit" button). This is a temporary navigation solution. When the full Analytics dashboard is built (Stories 5.4-5.7), the calendar will likely move to a tab or section within the analytics screen. For now, the HomeScreen entry point keeps the feature discoverable without introducing a new bottom navigation tab.

### Design Decision: No Item Detail Caching in Calendar

The `DayDetailBottomSheet` needs item thumbnails and names, but `WearLog` only contains `itemIds`. Rather than pre-fetching all item data for the entire month, item details are loaded on-demand when the user taps a day. This keeps the initial calendar load fast (only wear log metadata, no item images). The `ApiClient.listItems()` response is typically already cached from the wardrobe screen.

### Design Decision: Streak Calculation is Client-Side

The "current streak" metric in the summary row is calculated on the client by walking backward from today through consecutive dates in `_wearLogsByDate`. This is a simple computation on a small dataset (max 31 days per month). No server-side streak calculation is needed for this story. Epic 6, Story 6.3 (Streak Tracking & Freezes) will introduce server-side streak persistence with freeze logic.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/wear_calendar_screen.dart` (main calendar view)
  - `apps/mobile/lib/src/features/analytics/widgets/day_detail_bottom_sheet.dart` (day-tap detail overlay)
  - `apps/mobile/lib/src/features/analytics/widgets/month_summary_row.dart` (monthly stats row)
  - `apps/mobile/test/features/analytics/screens/wear_calendar_screen_test.dart`
  - `apps/mobile/test/features/analytics/widgets/day_detail_bottom_sheet_test.dart`
  - `apps/mobile/test/features/analytics/widgets/month_summary_row_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add "Wear Calendar" navigation button)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add calendar button tests)
- No API files modified.
- No SQL migration files.
- No new API test files.

### Technical Requirements

- **Calendar grid layout:** 7-column GridView (Sun-Sat or Mon-Sun based on locale). Each cell is minimum 44x44 touch target. The grid has 6 rows maximum (for months that span 6 weeks).
- **Activity indicator:** 6px diameter circle, color #4F46E5, centered below the day number in each cell. Only shown for dates with >= 1 wear log.
- **Today highlight:** Day cell background with #4F46E5 at 10% opacity, or a circular border in #4F46E5.
- **Month header:** "[Month] [Year]" text centered, 18px bold #1F2937. Left/right `IconButton` with `Icons.chevron_left` / `Icons.chevron_right`.
- **Date formatting:** Use `intl` package `DateFormat` for month names, day-of-week headers, and day detail date formatting.
- **API call pattern:** One `GET /v1/wear-logs?start=YYYY-MM-01&end=YYYY-MM-[lastDay]` per month navigation. No debouncing needed since navigation is discrete (button tap, not continuous scroll).

### Architecture Compliance

- **Server authority for wear data:** All wear log data comes from the API. No local database or cache is used for wear logs. The calendar reads from the same `GET /v1/wear-logs` endpoint established in Story 5.1.
- **Mobile boundary owns presentation:** The calendar grid, activity indicators, summary row, and day-detail overlay are all mobile-only concerns. The API returns raw wear log data; the mobile client transforms it into the calendar visualization.
- **No new AI calls:** This story is purely UI + data display. No Gemini involvement.
- **RLS enforces data isolation:** The `GET /v1/wear-logs` endpoint is RLS-scoped to the authenticated user. The calendar screen cannot display another user's data.
- **Optimistic UI is NOT used here:** Unlike wear logging (which is optimistic), the calendar is a read-only view. Data is fetched and displayed without optimistic patterns.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `intl: ^0.19.0` -- date formatting (month names, day-of-week abbreviations, full date format for day detail)
  - `http` via `ApiClient` -- API calls
  - `flutter/material.dart` -- GridView, IconButton, showModalBottomSheet, CircularProgressIndicator
- Existing packages reused:
  - `WearLogService` (from Story 5.1) for data fetching
  - `ApiClient` (for item detail loading in day-tap overlay)
  - `cached_network_image` (for item thumbnails in day detail)

### File Structure Requirements

- New screen goes in `apps/mobile/lib/src/features/analytics/screens/` -- creating the `screens` subdirectory within the existing analytics feature module.
- New widgets go in `apps/mobile/lib/src/features/analytics/widgets/` alongside the existing `log_outfit_bottom_sheet.dart`.
- Test files mirror source structure under `apps/mobile/test/features/analytics/`.
- The analytics feature module directory structure after this story:
  ```
  apps/mobile/lib/src/features/analytics/
  ├── models/
  │   └── wear_log.dart (Story 5.1)
  ├── screens/
  │   └── wear_calendar_screen.dart (NEW)
  ├── services/
  │   └── wear_log_service.dart (Story 5.1)
  └── widgets/
      ├── day_detail_bottom_sheet.dart (NEW)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      └── month_summary_row.dart (NEW)
  ```

### Testing Requirements

- Widget tests must verify:
  - WearCalendarScreen renders month header, day grid, activity indicators correctly
  - Month navigation (previous/next) triggers data re-fetch
  - Right chevron disabled at current month
  - Loading, error, and empty states render correctly
  - Day-tap opens DayDetailBottomSheet with correct data
  - Summary row computes days logged, items logged, and streak correctly
  - Semantics labels present on all interactive elements
- DayDetailBottomSheet tests must verify:
  - Renders formatted date header
  - Lists wear log entries with timestamps
  - Shows outfit label when outfitId is present
  - Displays item count
- MonthSummaryRow tests must verify:
  - Correct metric computations
  - Streak edge cases (gaps, empty data, today not logged)
- HomeScreen integration tests must verify:
  - "Wear Calendar" button renders
  - Navigation to WearCalendarScreen works
- Regression:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 806 + new tests pass)
  - `npm --prefix apps/api test` (all existing 337 API tests pass -- no API changes)

### Previous Story Intelligence

- **Story 5.2** (done) established: 806 Flutter tests, 337 API tests. EveningReminderService, EveningReminderPreferences. HomeScreen now has `eveningReminderService`, `eveningReminderPreferences`, and `initialOpenLogSheet` parameters.
- **Story 5.1** (done) established: `WearLog` model at `apps/mobile/lib/src/features/analytics/models/wear_log.dart` with fields: `id`, `profileId`, `loggedDate` (String, ISO date), `outfitId` (String?), `photoUrl` (String?), `itemIds` (List<String>), `createdAt` (String?).
- **Story 5.1** established: `WearLogService` at `apps/mobile/lib/src/features/analytics/services/wear_log_service.dart` with `getLogsForDateRange(startDate, endDate)` returning `List<WearLog>`. This is the primary data source for the calendar.
- **Story 5.1** established: `GET /v1/wear-logs?start=YYYY-MM-DD&end=YYYY-MM-DD` API endpoint returning `{ wearLogs: [...] }` with each log having `loggedDate`, `itemIds`, `outfitId`, etc.
- **Story 5.1** established: `LogOutfitBottomSheet` at `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart`. The `DayDetailBottomSheet` follows the same modal bottom sheet pattern.
- **Story 5.1** established: `ApiClient.listItems()` for fetching wardrobe items (used by DayDetailBottomSheet for item thumbnails).
- **HomeScreen constructor (as of Story 5.2):** `locationService` (required), `weatherService` (required), `sharedPreferences`, `weatherCacheService`, `outfitContextService`, `calendarService`, `calendarPreferencesService`, `calendarEventService`, `outfitGenerationService`, `outfitPersistenceService`, `onNavigateToAddItem`, `apiClient`, `morningNotificationService`, `morningNotificationPreferences`, `wearLogService`, `eveningReminderService`, `eveningReminderPreferences`, `initialOpenLogSheet`. This story does NOT add new constructor params to HomeScreen -- it only adds a button that navigates using the existing `wearLogService` and `apiClient`.
- **Key pattern from prior stories:** DI via optional constructor parameters with null defaults for test injection. Follow this for WearCalendarScreen.
- **Key pattern:** Bottom sheet modal for detail views (LogOutfitBottomSheet pattern). DayDetailBottomSheet follows this same pattern.
- **Key pattern:** Error states with retry button (used across weather, calendar sync, outfit generation screens).
- **Key pattern:** Semantics labels on all interactive elements (minimum 44x44 touch targets).

### Key Anti-Patterns to Avoid

- DO NOT add `table_calendar` or any other third-party calendar package. Build a simple custom grid with Flutter's built-in widgets. The `intl` package (already installed) handles all date formatting.
- DO NOT fetch all wear logs for the user's entire history on screen load. Fetch one month at a time using `getLogsForDateRange()`.
- DO NOT pre-fetch item details for the entire month. Load item thumbnails on-demand when the user taps a specific day.
- DO NOT cache wear log data across months. Each month navigation triggers a fresh API call. Local caching of wear logs is out of scope for V1.
- DO NOT implement heatmap color intensity (FR-HMP-01) in this story. This story shows a simple binary indicator (dot = logged, no dot = not logged). The heatmap with color intensity is Epic 11, Story 11.4.
- DO NOT implement streak tracking with freezes (FR-GAM-03). The summary row shows a simple consecutive-day count. Streak freezes are Epic 6, Story 6.3.
- DO NOT implement quarter or year views (FR-HMP-02). This story is month view only.
- DO NOT add a new bottom navigation tab for analytics. Use a button/link on the HomeScreen. The analytics tab structure will be defined in Stories 5.4-5.7.
- DO NOT create new API endpoints. The existing `GET /v1/wear-logs` endpoint provides all necessary data.
- DO NOT create a new database migration. All required data structures exist from Story 5.1.
- DO NOT implement the analytics dashboard (FR-ANA-*). Those are Stories 5.4-5.7.
- DO NOT block future months in the calendar from rendering -- but DO disable the "next month" navigation button when viewing the current month.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first. Always guard setState calls with `if (mounted)` after async operations.

### Out of Scope

- **Analytics dashboard (FR-ANA-*):** Stories 5.4-5.7.
- **Calendar heatmap with color intensity (FR-HMP-01):** Epic 11, Story 11.4.
- **Quarter and Year view modes (FR-HMP-02):** Epic 11, Story 11.4.
- **Streak tracking with freezes (FR-GAM-03):** Epic 6, Story 6.3.
- **Gamification / points for logging (FR-GAM-01):** Epic 6, Story 6.1.
- **Wear log deletion/editing:** Not required by any FR.
- **Offline calendar viewing:** Requires local wear log cache. Out of scope for V1.
- **Weekly view or day-view detail screen:** Not required by FR-LOG-07.
- **Wear log photo display:** The schema supports `photo_url` on `wear_logs` but the photo capture UI is not yet implemented. The day detail overlay shows item thumbnails, not wear log photos.

### References

- [Source: epics.md - Story 5.3: Monthly Wear Calendar View]
- [Source: epics.md - FR-LOG-07: Wear logs shall be viewable in a monthly calendar view with daily activity indicators]
- [Source: prd.md - FR-LOG-07: Wear logs shall be viewable in a monthly calendar view with daily activity indicators]
- [Source: architecture.md - Epic 5 Analytics & Wear Logging -> mobile/features/analytics]
- [Source: architecture.md - Optimistic UI is allowed for wear logging, badge/streak feedback, reactions, and save actions]
- [Source: ux-design-specification.md - Analytics/Sustainability Check (Monthly): Accomplishment and Pride]
- [Source: ux-design-specification.md - Anti-Patterns: Overwhelming Data Displays -- data must be visualized simply]
- [Source: ux-design-specification.md - Bottom tab bar for core MVP destinations (Home/Today, Wardrobe, Add, Outfits, Profile)]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - WearLog model, WearLogService, GET /v1/wear-logs endpoint, analytics feature module structure]
- [Source: 5-2-wear-logging-evening-reminder.md - HomeScreen constructor params, 806 Flutter tests, 337 API tests]
- [Source: apps/mobile/lib/src/features/analytics/models/wear_log.dart - WearLog class with loggedDate, itemIds, outfitId]
- [Source: apps/mobile/lib/src/features/analytics/services/wear_log_service.dart - getLogsForDateRange method]
- [Source: apps/mobile/pubspec.yaml - intl: ^0.19.0 already available for date formatting]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
