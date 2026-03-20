# Story 12.2: Outfit Scheduling (Plan Week)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Planner User,
I want to schedule my outfits for the upcoming week in a calendar view,
so that my mornings are completely stress-free.

## Acceptance Criteria

1. Given I am on the Outfits tab (OutfitHistoryScreen), when I tap a "Plan Week" button in the app bar, then I navigate to a PlanWeekScreen showing a 7-day horizontal calendar strip starting from today (FR-EVT-03).

2. Given I am on the PlanWeekScreen, when the screen loads, then each of the 7 day cells displays: the day name abbreviation (Mon, Tue, etc.), the date number, a weather preview icon with high/low temperatures (sourced from the existing 5-day `DailyForecast` data via `WeatherService`/`WeatherCacheService`, with days 6-7 showing a "No forecast" placeholder), and a summary of calendar events for that day (event count + most formal event type icon) fetched via `GET /v1/calendar/events` with date range parameters (FR-EVT-04).

3. Given a day cell is displayed with weather and events, when I tap on a day cell, then a day detail panel (expanded below the strip or as a bottom section) shows: full weather details for that day, a list of calendar events for that day (reusing event type icons/formality badges from EventsSection patterns established in Story 12.1), and the currently scheduled outfit (if any) or a prompt to assign one (FR-EVT-03, FR-EVT-04).

4. Given I am viewing a day's detail panel with no scheduled outfit, when I tap "Assign Outfit", then a bottom sheet opens offering two options: (a) "Choose from Saved" which shows a scrollable list of my saved outfits (fetched via `OutfitPersistenceService.listOutfits()`), and (b) "Generate for this Day" which triggers `POST /v1/outfits/generate` with the selected day's weather and event context to create a fresh AI suggestion (FR-EVT-03).

5. Given I select a saved outfit or accept a generated outfit from the assignment bottom sheet, when I confirm the selection, then the outfit is persisted to `calendar_outfits` via `POST /v1/calendar/outfits` with the date, optional event ID, and outfit ID, and the day cell updates to show a thumbnail preview of the assigned outfit's items (FR-EVT-05).

6. Given a day has a scheduled outfit displayed in its detail panel, when I tap "Edit" on the scheduled outfit, then the same assignment bottom sheet from AC#4 opens, allowing me to replace the outfit. The existing `calendar_outfits` record is updated via `PUT /v1/calendar/outfits/:id` (FR-EVT-06).

7. Given a day has a scheduled outfit displayed in its detail panel, when I tap "Remove", then a confirmation dialog appears. On confirm, the `calendar_outfits` record is deleted via `DELETE /v1/calendar/outfits/:id` and the day cell reverts to showing no scheduled outfit (FR-EVT-06).

8. Given the selected day is today, when the scheduled outfit is displayed, then it shows a prominent "Wear This Today" button that logs the outfit as worn via the existing wear-logging infrastructure (POST /v1/wear-logs from Story 5.1) (FR-EVT-03).

9. Given the `calendar_outfits` table does not yet exist, when the migration runs, then it creates `app_public.calendar_outfits` with columns: `id` (UUID PK), `profile_id` (FK to profiles), `outfit_id` (FK to outfits ON DELETE CASCADE), `calendar_event_id` (FK to calendar_events, nullable, ON DELETE SET NULL), `scheduled_date` (DATE NOT NULL), `notes` (TEXT nullable), `created_at`, `updated_at`, with RLS policy matching profiles pattern, a unique constraint on `(profile_id, scheduled_date, calendar_event_id)` to prevent duplicate assignments per day/event, and an index on `(profile_id, scheduled_date)` (FR-EVT-05).

10. Given I have scheduled outfits for the week, when I revisit the PlanWeekScreen, then all previously scheduled outfits are loaded via `GET /v1/calendar/outfits?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD` and displayed on the corresponding day cells (FR-EVT-05).

11. Given any API call for calendar outfits fails, when the error is detected, then appropriate inline error states are shown (error message with retry button) without crashing the app. The weather and events data load independently and show their own error/loading states (FR-EVT-03).

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1192 API tests, 1607 Flutter tests from Story 12.1) and new tests cover: database migration, calendar-outfit-repository CRUD, API endpoints (auth, success, validation, error), PlanWeekScreen rendering (7-day strip, weather, events, outfit assignment), outfit assignment bottom sheet (saved selection, generation), edit/remove flows, and regression on existing Outfits tab and Home screen functionality.

## Tasks / Subtasks

- [x] Task 1: Database - Create `calendar_outfits` migration (AC: 9)
  - [x] 1.1: Create `infra/sql/migrations/035_calendar_outfits.sql`. Create table `app_public.calendar_outfits` with columns: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `outfit_id UUID NOT NULL REFERENCES app_public.outfits(id) ON DELETE CASCADE`, `calendar_event_id UUID REFERENCES app_public.calendar_events(id) ON DELETE SET NULL` (nullable -- day-level scheduling without specific event), `scheduled_date DATE NOT NULL`, `notes TEXT`, `created_at TIMESTAMPTZ DEFAULT now()`, `updated_at TIMESTAMPTZ DEFAULT now()`.
  - [x]1.2: Add RLS policy `calendar_outfits_user_policy` using the same pattern as `outfits_user_policy`: `USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`.
  - [x]1.3: Add unique constraint: `UNIQUE (profile_id, scheduled_date, calendar_event_id)` using `COALESCE(calendar_event_id, '00000000-0000-0000-0000-000000000000')` to handle NULL event IDs in the uniqueness check (one default outfit per day, plus per-event overrides).
  - [x]1.4: Add index: `CREATE INDEX idx_calendar_outfits_profile_date ON app_public.calendar_outfits(profile_id, scheduled_date)`.
  - [x]1.5: Add `set_updated_at` trigger reusing existing `app_private.set_updated_at()` function.

- [x]Task 2: API - Create calendar-outfit-repository (AC: 5, 6, 7, 10)
  - [x]2.1: Create `apps/api/src/modules/calendar/calendar-outfit-repository.js`. Export `createCalendarOutfitRepository({ pool })`. Follow the exact same pattern as `calendar-event-repository.js`: factory function accepting `{ pool }`, returning an object with async methods, each acquiring a client, setting RLS config, executing queries, and releasing.
  - [x]2.2: Implement `async createCalendarOutfit(authContext, { outfitId, calendarEventId, scheduledDate, notes })`. Looks up profile_id from firebase_uid, inserts into `calendar_outfits`, returns the created row with joined outfit data (name, items via subquery joining `outfit_items` and `items`).
  - [x]2.3: Implement `async getCalendarOutfitsForDateRange(authContext, { startDate, endDate })`. Returns all calendar_outfits rows in range with joined outfit data (outfit name, items with thumbnails). Order by `scheduled_date ASC`.
  - [x]2.4: Implement `async updateCalendarOutfit(authContext, calendarOutfitId, { outfitId, calendarEventId, notes })`. Updates the specified record. Returns 404 if not found.
  - [x]2.5: Implement `async deleteCalendarOutfit(authContext, calendarOutfitId)`. Deletes the record. Returns 404 if not found.

- [x]Task 3: API - Add calendar outfit REST endpoints (AC: 5, 6, 7, 10)
  - [x]3.1: In `apps/api/src/main.js`, instantiate `calendarOutfitRepo` from `createCalendarOutfitRepository({ pool })` alongside existing calendar repos.
  - [x]3.2: Add `POST /v1/calendar/outfits` -- requires auth, reads `{ outfitId, calendarEventId?, scheduledDate, notes? }` from body, validates `outfitId` and `scheduledDate` are present, calls `calendarOutfitRepo.createCalendarOutfit(authContext, body)`, returns 201 with created record.
  - [x]3.3: Add `GET /v1/calendar/outfits?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD` -- requires auth, validates date params, calls `calendarOutfitRepo.getCalendarOutfitsForDateRange(authContext, { startDate, endDate })`, returns 200 with `{ calendarOutfits: [...] }`.
  - [x]3.4: Add `PUT /v1/calendar/outfits/:id` -- requires auth, reads `{ outfitId, calendarEventId?, notes? }` from body, calls `calendarOutfitRepo.updateCalendarOutfit(authContext, id, body)`, returns 200 with updated record.
  - [x]3.5: Add `DELETE /v1/calendar/outfits/:id` -- requires auth, calls `calendarOutfitRepo.deleteCalendarOutfit(authContext, id)`, returns 204 on success, 404 if not found.

- [x]Task 4: Mobile - Create CalendarOutfit model and CalendarOutfitService (AC: 5, 10)
  - [x]4.1: Create `apps/mobile/lib/src/features/outfits/models/calendar_outfit.dart`. Model with fields: `id` (String), `outfitId` (String), `calendarEventId` (String?), `scheduledDate` (DateTime), `notes` (String?), `outfit` (SavedOutfit?), `createdAt` (DateTime), `updatedAt` (DateTime?). Include `fromJson`/`toJson` factories.
  - [x]4.2: Create `apps/mobile/lib/src/features/outfits/services/calendar_outfit_service.dart`. Constructor takes `ApiClient`. Methods: `Future<CalendarOutfit?> createCalendarOutfit({ required String outfitId, String? calendarEventId, required String scheduledDate, String? notes })`, `Future<List<CalendarOutfit>> getCalendarOutfitsForDateRange(String startDate, String endDate)`, `Future<CalendarOutfit?> updateCalendarOutfit(String id, { required String outfitId, String? calendarEventId, String? notes })`, `Future<bool> deleteCalendarOutfit(String id)`. Each calls the corresponding API endpoint. Never throws -- returns null/empty/false on error.
  - [x]4.3: Add API client methods in `apps/mobile/lib/src/core/networking/api_client.dart`: `createCalendarOutfit(Map body)`, `getCalendarOutfits(String startDate, String endDate)`, `updateCalendarOutfit(String id, Map body)`, `deleteCalendarOutfit(String id)`.

- [x]Task 5: Mobile - Create PlanWeekScreen (AC: 1, 2, 3, 10, 11)
  - [x]5.1: Create `apps/mobile/lib/src/features/outfits/screens/plan_week_screen.dart`. StatefulWidget. Constructor accepts: `CalendarOutfitService calendarOutfitService`, `OutfitPersistenceService outfitPersistenceService`, `OutfitGenerationService outfitGenerationService`, `CalendarEventService calendarEventService`, `WeatherCacheService? weatherCacheService`. This DI approach matches existing screen patterns (HomeScreen, OutfitHistoryScreen).
  - [x]5.2: Build a 7-day horizontal calendar strip at the top. Each day cell shows: abbreviated day name (from `DailyForecast._dayNames` pattern), date number, weather icon + high/low (from cached `DailyForecast` data for days 1-5, "N/A" for days 6-7), event count badge. The selected day is highlighted with `#4F46E5` accent border. Today's cell has a subtle "Today" label.
  - [x]5.3: On `initState`, fetch: (a) calendar outfits for 7-day range via `calendarOutfitService.getCalendarOutfitsForDateRange(today, today+6)`, (b) calendar events for 7-day range via `calendarEventService` or direct API call, (c) weather forecast from `weatherCacheService`. Show loading shimmer while fetching, error state with retry on failure.
  - [x]5.4: Below the strip, show a detail panel for the selected day: day header (full date, weather summary), events list (reusing event type icon/formality badge patterns from `EventsSection`/`event_type_utils.dart` established in Story 12.1), and scheduled outfit card (or "No outfit scheduled" empty state with "Assign Outfit" button). If multiple outfits exist for the day (day-level + event-specific), show them in a list.
  - [x]5.5: Outfit card shows: outfit name, item thumbnails (horizontal row of `CachedNetworkImage` circles, max 5, "+N" overflow), occasion chip, and action buttons (Edit, Remove). Follow Vibrant Soft-UI: white card, 12px border radius, subtle shadow. If the outfit has a linked event, show the event title as a subtitle.
  - [x]5.6: AppBar title: "Plan Your Week". Back button returns to OutfitHistoryScreen.

- [x]Task 6: Mobile - Create OutfitAssignmentBottomSheet (AC: 4, 5, 6)
  - [x]6.1: Create `apps/mobile/lib/src/features/outfits/widgets/outfit_assignment_bottom_sheet.dart`. StatefulWidget. Constructor accepts: `DateTime selectedDate`, `CalendarEvent? forEvent`, `OutfitPersistenceService outfitPersistenceService`, `OutfitGenerationService outfitGenerationService`, `CalendarOutfitService calendarOutfitService`, `OutfitContext? outfitContext`.
  - [x]6.2: Two-tab layout inside the bottom sheet: Tab 1 "Saved Outfits" shows a scrollable list of saved outfits (via `outfitPersistenceService.listOutfits()`). Each row shows: outfit name, item thumbnails, occasion, created date, and a "Select" button. Tab 2 "Generate New" shows a button to trigger AI outfit generation for the selected day's context (weather + events), displaying results as `OutfitSuggestionCard` widgets with an "Assign This" button on each.
  - [x]6.3: On outfit selection (saved or generated): call `calendarOutfitService.createCalendarOutfit(outfitId: selectedOutfit.id, calendarEventId: forEvent?.id, scheduledDate: selectedDate.toIso8601String().split('T')[0])`. On success, pop the bottom sheet and return the created `CalendarOutfit` to PlanWeekScreen. On failure, show inline error.
  - [x]6.4: For "Generate New" tab: if the selected day is within the 5-day forecast window, build an `OutfitContext` with that day's weather data and events. If outside the forecast window, generate without weather context (events only). Show shimmer loading during generation.
  - [x]6.5: Bottom sheet pattern: `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`, drag handle, 24px padding, white background, top border radius 20px. Use `DraggableScrollableSheet` with `initialChildSize: 0.7`, `minChildSize: 0.4`, `maxChildSize: 0.95`.

- [x]Task 7: Mobile - Integrate PlanWeekScreen into Outfits tab (AC: 1, 8)
  - [x]7.1: In `apps/mobile/lib/src/features/outfits/screens/outfit_history_screen.dart`, add a "Plan Week" icon button (`Icons.calendar_month`) to the AppBar actions. Tapping navigates to `PlanWeekScreen` via `Navigator.push`.
  - [x]7.2: Pass the required services to PlanWeekScreen. The `OutfitPersistenceService` is already available. Create `CalendarOutfitService` from the existing `apiClient`. `OutfitGenerationService` -- instantiate from `apiClient` (same pattern as HomeScreen). `CalendarEventService` -- instantiate from `apiClient`.
  - [x]7.3: For "today" scheduled outfits, add a "Wear This Today" button in PlanWeekScreen's day detail panel. Tapping calls `POST /v1/wear-logs` with the outfit's item IDs (reusing the existing wear-logging pattern from Story 5.1). Show a success snackbar.

- [x]Task 8: API - Unit tests for calendar-outfit-repository (AC: 9, 12)
  - [x]8.1: Create `apps/api/test/modules/calendar/calendar-outfit-repository.test.js`. Tests:
    - `createCalendarOutfit` inserts a record and returns it with outfit data.
    - `createCalendarOutfit` returns error for invalid outfit ID (FK violation).
    - `getCalendarOutfitsForDateRange` returns outfits within range with joined data.
    - `getCalendarOutfitsForDateRange` returns empty array when no outfits scheduled.
    - `updateCalendarOutfit` updates the record and returns it.
    - `updateCalendarOutfit` returns 404 for non-existent ID.
    - `deleteCalendarOutfit` removes the record.
    - `deleteCalendarOutfit` returns 404 for non-existent ID.
    - RLS prevents access to other users' calendar outfits.
    - Unique constraint prevents duplicate scheduling for same date/event.

- [x]Task 9: API - Integration tests for calendar outfit endpoints (AC: 5, 6, 7, 10, 12)
  - [x]9.1: Add tests in `apps/api/test/modules/calendar/calendar-outfit-endpoints.test.js`:
    - `POST /v1/calendar/outfits` requires authentication (401).
    - `POST /v1/calendar/outfits` creates calendar outfit on success (201).
    - `POST /v1/calendar/outfits` returns 400 for missing outfitId or scheduledDate.
    - `GET /v1/calendar/outfits` requires authentication (401).
    - `GET /v1/calendar/outfits` returns outfits for date range (200).
    - `GET /v1/calendar/outfits` returns 400 for missing date parameters.
    - `PUT /v1/calendar/outfits/:id` updates the record (200).
    - `PUT /v1/calendar/outfits/:id` returns 404 for non-existent ID.
    - `DELETE /v1/calendar/outfits/:id` deletes the record (204).
    - `DELETE /v1/calendar/outfits/:id` returns 404 for non-existent ID.

- [x]Task 10: Mobile - Unit tests for CalendarOutfitService (AC: 5, 12)
  - [x]10.1: Create `apps/mobile/test/features/outfits/services/calendar_outfit_service_test.dart`:
    - `createCalendarOutfit` calls API with correct body and returns parsed result.
    - `createCalendarOutfit` returns null on API error.
    - `getCalendarOutfitsForDateRange` returns parsed list on success.
    - `getCalendarOutfitsForDateRange` returns empty list on error.
    - `updateCalendarOutfit` calls API and returns parsed result.
    - `deleteCalendarOutfit` returns true on success, false on error.

- [x]Task 11: Mobile - Widget tests for PlanWeekScreen (AC: 1, 2, 3, 10, 11, 12)
  - [x]11.1: Create `apps/mobile/test/features/outfits/screens/plan_week_screen_test.dart`:
    - Renders 7-day calendar strip with day names and dates.
    - Shows weather icons for available forecast days.
    - Shows event count badges on days with events.
    - Tapping a day selects it and shows detail panel.
    - Shows scheduled outfit card when one exists.
    - Shows empty state with "Assign Outfit" button when no outfit scheduled.
    - Shows loading shimmer while fetching data.
    - Shows error state with retry on fetch failure.
    - Today's cell shows "Today" label.
    - Semantics labels present on key elements.

- [x]Task 12: Mobile - Widget tests for OutfitAssignmentBottomSheet (AC: 4, 5, 6, 12)
  - [x]12.1: Create `apps/mobile/test/features/outfits/widgets/outfit_assignment_bottom_sheet_test.dart`:
    - Renders two tabs: "Saved Outfits" and "Generate New".
    - "Saved Outfits" tab lists saved outfits.
    - Selecting a saved outfit creates calendar outfit via service.
    - "Generate New" tab triggers outfit generation.
    - Selecting a generated outfit creates calendar outfit via service.
    - Shows error state on creation failure.
    - Bottom sheet closes on successful assignment.

- [x]Task 13: Mobile - Integration tests for Outfits tab (AC: 1, 8, 12)
  - [x]13.1: Update `apps/mobile/test/features/outfits/screens/outfit_history_screen_test.dart`:
    - "Plan Week" button appears in app bar.
    - Tapping "Plan Week" navigates to PlanWeekScreen.
    - Existing outfit history functionality unchanged.

- [x]Task 14: Regression testing (AC: 12)
  - [x]14.1: Run `flutter analyze` -- zero issues.
  - [x]14.2: Run `flutter test` -- all existing 1607 Flutter tests plus new tests pass.
  - [x]14.3: Run `npm --prefix apps/api test` -- all existing 1192 API tests plus new tests pass.
  - [x]14.4: Verify existing Outfits tab functionality preserved: outfit history list, swipe-to-delete, favorite toggle, outfit detail navigation.
  - [x]14.5: Verify existing Home screen functionality preserved: weather, events section, daily outfit generation, event outfit bottom sheet.
  - [x]14.6: Run migration 035 against test database to verify schema creation.

## Dev Notes

- This is the SECOND story in Epic 12 (Calendar Integration & Outfit Planning). It builds on Story 12.1 (event display and event-specific outfit suggestions) and introduces the week-ahead planning capability.
- The primary FRs covered are FR-EVT-03 (Plan Week 7-day view), FR-EVT-04 (weather + events per day), FR-EVT-05 (persist to `calendar_outfits`), and FR-EVT-06 (edit/remove scheduled outfits).
- **FR-EVT-07 and FR-EVT-08 are OUT OF SCOPE.** They cover formal event reminders and are addressed in Story 12.3.
- **FR-TRV-01 through FR-TRV-05 are OUT OF SCOPE.** They cover travel mode packing in Story 12.4.
- This story introduces the FIRST new database table since migration 034. The `calendar_outfits` table is referenced in the architecture document's data model and the functional requirements (FR-EVT-05).
- The weather forecast is only available for 5 days (from the existing Open-Meteo integration in `WeatherService`). Days 6-7 of the planning view will show a "No forecast" placeholder. This is acceptable for MVP.
- AI outfit generation for future days reuses the existing `POST /v1/outfits/generate` endpoint. The client builds an `OutfitContext` with the target day's weather (if available) and events. No new AI endpoint is needed.
- The "Wear This Today" shortcut on today's scheduled outfit reuses the existing wear-logging infrastructure from Story 5.1 (`POST /v1/wear-logs`). No modifications to wear logging are needed.

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/calendar/calendar-outfit-repository.js` (CalendarOutfit CRUD)
  - `apps/api/test/modules/calendar/calendar-outfit-repository.test.js`
  - `apps/api/test/modules/calendar/calendar-outfit-endpoints.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/outfits/models/calendar_outfit.dart` (CalendarOutfit model)
  - `apps/mobile/lib/src/features/outfits/services/calendar_outfit_service.dart` (CalendarOutfitService)
  - `apps/mobile/lib/src/features/outfits/screens/plan_week_screen.dart` (PlanWeekScreen)
  - `apps/mobile/lib/src/features/outfits/widgets/outfit_assignment_bottom_sheet.dart` (OutfitAssignmentBottomSheet)
  - `apps/mobile/test/features/outfits/services/calendar_outfit_service_test.dart`
  - `apps/mobile/test/features/outfits/screens/plan_week_screen_test.dart`
  - `apps/mobile/test/features/outfits/widgets/outfit_assignment_bottom_sheet_test.dart`
- New infra files:
  - `infra/sql/migrations/035_calendar_outfits.sql`
- Modified API files:
  - `apps/api/src/main.js` (add calendar outfit endpoints + instantiate repository)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add calendar outfit API methods)
  - `apps/mobile/lib/src/features/outfits/screens/outfit_history_screen.dart` (add "Plan Week" button in app bar)
  - `apps/mobile/test/features/outfits/screens/outfit_history_screen_test.dart` (add Plan Week button tests)

### Technical Requirements

- **New database table:** `app_public.calendar_outfits` with RLS, FK cascades, and unique constraint. Migration file: `035_calendar_outfits.sql`. Next sequential migration number after 034.
- **New API endpoints:**
  - `POST /v1/calendar/outfits` -- creates a scheduled outfit (201)
  - `GET /v1/calendar/outfits?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD` -- lists scheduled outfits in range (200)
  - `PUT /v1/calendar/outfits/:id` -- updates a scheduled outfit (200)
  - `DELETE /v1/calendar/outfits/:id` -- removes a scheduled outfit (204)
- **No new AI endpoints or Gemini prompts.** Outfit generation for future days reuses the existing `POST /v1/outfits/generate` endpoint. The client adjusts the `OutfitContext` with the target day's weather/events.
- **No new Flutter dependencies.** Uses existing packages: `http`, `cached_network_image`, `intl`, and Material widgets.
- **Weather data limitation:** Open-Meteo provides 5-day forecast. Days 6-7 of the planner will show limited weather data. Consider this when building `OutfitContext` for generation -- omit weather data for days beyond the forecast window.

### Architecture Compliance

- **Server authority for data:** `calendar_outfits` CRUD happens on the API. Client sends outfit/event IDs; server validates ownership via RLS and FK constraints.
- **Mobile boundary owns presentation:** PlanWeekScreen, OutfitAssignmentBottomSheet, and all UI state are client-side.
- **Existing repository pattern:** `calendar-outfit-repository.js` follows the identical factory function pattern as `calendar-event-repository.js` and `outfit-repository.js`.
- **RLS on all user-facing tables:** `calendar_outfits` has the same RLS pattern as `outfits`, `calendar_events`, and all other user-scoped tables.
- **Graceful degradation:** If weather data is unavailable or events fail to load, the planner still works with limited context. Each data source loads independently.
- **Epic 12 component mapping:** `mobile/features/outfits`, `api/modules/calendar` -- matches the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies.
- No new API dependencies. Uses existing `pg` pool for database access.

### File Structure Requirements

- New repository in `apps/api/src/modules/calendar/` -- follows existing pattern alongside `calendar-event-repository.js`.
- New mobile model in `apps/mobile/lib/src/features/outfits/models/` -- follows existing pattern alongside `saved_outfit.dart`.
- New mobile service in `apps/mobile/lib/src/features/outfits/services/` -- follows existing pattern alongside `outfit_persistence_service.dart`.
- New screen in `apps/mobile/lib/src/features/outfits/screens/` -- follows existing pattern alongside `outfit_history_screen.dart`.
- New widget in `apps/mobile/lib/src/features/outfits/widgets/` -- new directory for outfits-specific widgets.
- Test files mirror source structure.

### Testing Requirements

- API unit tests must verify:
  - Calendar outfit repository CRUD operations (create, read range, update, delete)
  - RLS enforcement (cannot access other users' data)
  - FK constraint validation (invalid outfit ID rejected)
  - Unique constraint (duplicate date/event prevented)
- API integration tests must verify:
  - All 4 calendar outfit endpoints (POST, GET, PUT, DELETE)
  - Authentication required (401 without token)
  - Input validation (400 for missing fields)
  - 404 for non-existent records
- Mobile unit tests must verify:
  - CalendarOutfitService correctly calls API and parses responses
  - Error handling returns safe defaults (null, empty list, false)
- Mobile widget tests must verify:
  - PlanWeekScreen renders 7-day strip with weather and events
  - Day selection updates detail panel
  - Outfit assignment and removal flows
  - OutfitAssignmentBottomSheet two-tab UI (saved + generate)
  - Integration with OutfitHistoryScreen (Plan Week button navigation)
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 1607+ tests pass)
  - `npm --prefix apps/api test` (all existing 1192+ tests pass)

### Previous Story Intelligence

- **Story 12.1 (previous story in epic)** ended with 1192 API tests and 1607 Flutter tests. All must continue to pass. Story 12.1 established: `EventsSection` widget, `EventOutfitBottomSheet`, `event_type_utils.dart` shared utility for event icons/colors, `generateOutfitsForEvent` on both API and mobile side, and `POST /v1/outfits/generate-for-event` endpoint. Reuse the event display patterns (type icons, formality badges) from EventsSection.
- **Story 3.4** established: `CalendarPreferencesService` for calendar sync permissions, `CalendarPermissionCard`/`CalendarDeniedCard` widgets. Calendar sync must already be enabled for Plan Week to show events data.
- **Story 3.5** established: `calendar_events` table (migration 012), `CalendarEvent`/`CalendarEventContext` models, `CalendarEventService`, `GET /v1/calendar/events` endpoint with date range parameters. This endpoint is reused by PlanWeekScreen to fetch events for the 7-day range.
- **Story 3.6** established: Event classification override (`PATCH /v1/calendar/events/:id`), `EventDetailBottomSheet`. Not directly used here but the event display patterns are shared.
- **Story 4.1** established: `outfit-generation-service.js` with `generateOutfits`, `POST /v1/outfits/generate` endpoint. This endpoint is REUSED for "Generate New" in the assignment bottom sheet.
- **Story 4.2** established: `OutfitSuggestionCard` widget with swipe-to-save pattern. The card is reused in the "Generate New" tab of the assignment bottom sheet.
- **Story 4.3** established: `CreateOutfitScreen` for manual outfit building, `POST /v1/outfits` for saving outfits. Saved outfits are available for selection in the assignment bottom sheet.
- **Story 4.4** established: `OutfitHistoryScreen` with outfit list, swipe-to-delete, favorite toggle. This screen is where the "Plan Week" button is added.
- **Story 5.1** established: Wear logging via `POST /v1/wear-logs`. Reused for the "Wear This Today" button on today's scheduled outfit.
- **Key pattern from Story 12.1:** Bottom sheets use `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with `DraggableScrollableSheet`. The `OutfitSuggestionCard` pattern for displaying generated outfits. Event type icons from `event_type_utils.dart`.
- **HomeScreen constructor parameters:** The existing HomeScreen has many DI parameters. PlanWeekScreen is independent of HomeScreen (accessed from Outfits tab), so it defines its own constructor parameters.
- **Current test counts:** 1192 API tests, 1607 Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT create a new outfit generation endpoint for future days. Reuse `POST /v1/outfits/generate` with adjusted `OutfitContext`.
- DO NOT duplicate weather fetching logic. Use the existing `WeatherCacheService` to access cached forecast data on the mobile side.
- DO NOT duplicate event display patterns. Reuse event type icons/colors from `event_type_utils.dart` (Story 12.1).
- DO NOT modify the `outfits` or `calendar_events` tables. `calendar_outfits` is a NEW join table linking them.
- DO NOT persist generated outfit suggestions directly to `calendar_outfits`. The user must first SAVE the outfit (via existing `POST /v1/outfits`), then assign the saved outfit ID to `calendar_outfits`. This ensures the outfit exists in the `outfits` table before FK linkage.
- DO NOT add new constructor parameters to HomeScreen. PlanWeekScreen is accessed from OutfitHistoryScreen, not HomeScreen.
- DO NOT remove or modify any existing API routes. Only ADD new calendar outfit routes.
- DO NOT change the existing `CalendarEvent` model. It is already complete for this story's needs.
- DO NOT call Gemini from the mobile client. All AI calls go through Cloud Run via existing endpoints.
- DO NOT create a separate `Outfits` tab widget for Plan Week. Keep it as a push navigation from OutfitHistoryScreen.

### Implementation Guidance

- **Unique constraint with nullable FK:** PostgreSQL unique constraints treat NULLs as distinct, so `UNIQUE (profile_id, scheduled_date, calendar_event_id)` allows multiple NULL event entries per day. To enforce one default-per-day, use a partial unique index: `CREATE UNIQUE INDEX idx_calendar_outfits_unique_day ON app_public.calendar_outfits(profile_id, scheduled_date) WHERE calendar_event_id IS NULL;` AND `CREATE UNIQUE INDEX idx_calendar_outfits_unique_event ON app_public.calendar_outfits(profile_id, scheduled_date, calendar_event_id) WHERE calendar_event_id IS NOT NULL;`.

- **Outfit data in GET response:** When returning calendar outfits, JOIN with `outfits` and `outfit_items` + `items` to include the outfit name, occasion, and item thumbnails in a single API call. Avoid N+1 queries. Pattern: LEFT JOIN outfits, then aggregate outfit_items via subquery or lateral join.

- **Weather for future days:** `WeatherCacheService.getCachedWeather()` returns a `CachedWeather` with a `List<DailyForecast> forecast` (5 days). Map each forecast day to the corresponding planner day by matching `DailyForecast.date`. For days beyond the forecast, set weather to null in the UI.

- **Saving generated outfits before assigning:** When the user selects a generated outfit in the "Generate New" tab, first call `POST /v1/outfits` to save it (reusing `OutfitPersistenceService.saveOutfit`), then use the returned outfit ID for `POST /v1/calendar/outfits`. This two-step approach maintains FK integrity.

- **Tab indicator in bottom sheet:** Use `DefaultTabController` + `TabBar` + `TabBarView` for the two-tab layout in `OutfitAssignmentBottomSheet`. Tab styling: `#4F46E5` indicator color, matching app accent.

### References

- [Source: epics.md - Story 12.2: Outfit Scheduling (Plan Week)]
- [Source: epics.md - Epic 12: Calendar Integration & Outfit Planning]
- [Source: functional-requirements.md - FR-EVT-03: Users shall schedule outfits for future days via a "Plan Week" 7-day calendar view]
- [Source: functional-requirements.md - FR-EVT-04: Each day in the planner shall show events and weather preview]
- [Source: functional-requirements.md - FR-EVT-05: Scheduled outfits shall be stored in `calendar_outfits` with event association]
- [Source: functional-requirements.md - FR-EVT-06: Users shall edit or remove scheduled outfits]
- [Source: architecture.md - Data Architecture: `calendar_outfits` table listed in important tables]
- [Source: architecture.md - API Architecture: JSON REST over HTTPS, standard error codes]
- [Source: architecture.md - Epic 12 Calendar Planning & Travel -> mobile/features/outfits, api/modules/calendar]
- [Source: architecture.md - Database rules: RLS, FK cascades, check constraints]
- [Source: 12-1-event-display-suggestions.md - EventsSection widget, event_type_utils.dart, EventOutfitBottomSheet pattern]
- [Source: 3-5-calendar-event-fetching-classification.md - calendar_events table, CalendarEvent model, GET /v1/calendar/events]
- [Source: 4-1-daily-ai-outfit-generation.md - POST /v1/outfits/generate, OutfitContext, outfit-generation-service.js]
- [Source: 4-4-outfit-history-management.md - OutfitHistoryScreen, outfit list/detail patterns]
- [Source: 5-1-log-today-s-outfit-wear-counts.md - POST /v1/wear-logs, wear logging pattern]
- [Source: infra/sql/migrations/012_calendar_events.sql - calendar_events schema pattern]
- [Source: infra/sql/migrations/013_outfits.sql - outfits schema and RLS pattern]
- [Source: apps/api/src/modules/calendar/calendar-event-repository.js - repository factory pattern]
- [Source: apps/mobile/lib/src/features/outfits/models/saved_outfit.dart - SavedOutfit model]
- [Source: apps/mobile/lib/src/features/outfits/services/outfit_persistence_service.dart - OutfitPersistenceService]
- [Source: apps/mobile/lib/src/core/calendar/calendar_event.dart - CalendarEvent model]
- [Source: apps/mobile/lib/src/core/weather/daily_forecast.dart - DailyForecast model, 5-day forecast]
- [Source: apps/mobile/lib/src/core/weather/weather_service.dart - Open-Meteo API, 5-day forecast_days]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented migration 035_calendar_outfits.sql with table, RLS, partial unique indexes, profile_date index, and updated_at trigger.
- Created calendar-outfit-repository.js with full CRUD (create, getForDateRange, update, delete) following existing calendar-event-repository pattern.
- Added 4 REST endpoints: POST/GET/PUT/DELETE /v1/calendar/outfits in main.js with auth, validation, and error handling.
- Created CalendarOutfit model (Dart) with fromJson/toJson supporting SavedOutfit nesting.
- Created CalendarOutfitService (Dart) wrapping all 4 API endpoints with safe error handling (never throws).
- Added 4 API client methods for calendar outfit CRUD.
- Built PlanWeekScreen with 7-day horizontal calendar strip, weather previews, event badges, day detail panel, outfit cards with Edit/Remove, "Wear This Today" for today.
- Built OutfitAssignmentBottomSheet with two-tab layout (Saved Outfits + Generate New), DraggableScrollableSheet, create/update support.
- Added "Plan Week" icon button to OutfitHistoryScreen AppBar with navigation.
- 22 new API tests (10 repository unit + 10 endpoint integration + 2 validation) -- all passing.
- 27 new Flutter tests (7 service + 10 PlanWeekScreen widget + 7 OutfitAssignmentBottomSheet widget + 3 OutfitHistoryScreen integration) -- all passing.
- Total: 1214 API tests, 1634 Flutter tests -- all passing. Zero regressions.

### Change Log

- 2026-03-19: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirements (FR-EVT-03 through FR-EVT-06), and Stories 12.1, 3.4-3.6, 4.1-4.4, 5.1 implementation context.
- 2026-03-19: Story implemented by Dev Agent (Claude Opus 4.6). All 14 tasks complete. Migration 035, repository, 4 endpoints, CalendarOutfit model/service, PlanWeekScreen, OutfitAssignmentBottomSheet, Outfits tab integration. 1214 API tests, 1634 Flutter tests all passing.

### File List

**New files:**
- `infra/sql/migrations/035_calendar_outfits.sql`
- `apps/api/src/modules/calendar/calendar-outfit-repository.js`
- `apps/api/test/modules/calendar/calendar-outfit-repository.test.js`
- `apps/api/test/modules/calendar/calendar-outfit-endpoints.test.js`
- `apps/mobile/lib/src/features/outfits/models/calendar_outfit.dart`
- `apps/mobile/lib/src/features/outfits/services/calendar_outfit_service.dart`
- `apps/mobile/lib/src/features/outfits/screens/plan_week_screen.dart`
- `apps/mobile/lib/src/features/outfits/widgets/outfit_assignment_bottom_sheet.dart`
- `apps/mobile/test/features/outfits/services/calendar_outfit_service_test.dart`
- `apps/mobile/test/features/outfits/screens/plan_week_screen_test.dart`
- `apps/mobile/test/features/outfits/widgets/outfit_assignment_bottom_sheet_test.dart`

**Modified files:**
- `apps/api/src/main.js` (import, instantiation, handleRequest destructuring, 4 new endpoints)
- `apps/mobile/lib/src/core/networking/api_client.dart` (4 new calendar outfit API methods)
- `apps/mobile/lib/src/features/outfits/screens/outfit_history_screen.dart` (Plan Week button + navigation)
- `apps/mobile/test/features/outfits/screens/outfit_history_screen_test.dart` (3 new tests for Plan Week button)
