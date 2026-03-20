# Story 3.6: Manual Event Classification Override

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to manually correct the AI's classification or formality score for an event,
so that my outfit suggestions are precisely tailored to what I actually have planned.

## Acceptance Criteria

1. Given an event has been synced and classified (Story 3.5), when I tap on the event in the EventSummaryWidget on the Home screen, then a bottom sheet opens showing the event details (title, time, location) and editable classification fields: an Event Type selector and a Formality Score slider (FR-CTX-12).

2. Given the event detail bottom sheet is open, when I view the Event Type selector, then I see all five classification options (Work, Social, Active, Formal, Casual) displayed as selectable chips with the current classification pre-selected and highlighted with the accent color (#4F46E5) (FR-CTX-12).

3. Given the event detail bottom sheet is open, when I view the Formality Score slider, then I see a continuous slider from 1 (Very Casual) to 10 (Very Formal) with the current formality score pre-selected, labeled endpoints, and the current value displayed prominently (FR-CTX-12).

4. Given I change the Event Type or Formality Score, when I tap "Save", then the override is sent to the API via `PATCH /v1/calendar/events/:id` with the new `event_type`, `formality_score`, `classification_source = "user"`, and `user_override = true`, and the API updates the `calendar_events` row accordingly (FR-CTX-12).

5. Given I have saved an override, when the response is received successfully, then the bottom sheet closes, the EventSummaryWidget updates to reflect the new classification (type icon and label change), and the local `_calendarEvents` list in HomeScreen is updated in place without a full re-fetch (FR-CTX-12).

6. Given I have overridden an event's classification, when the next calendar sync occurs (pull-to-refresh or app relaunch), then the API's upsert logic preserves my override because `user_override = true` prevents the CASE expression from overwriting `event_type`, `formality_score`, and `classification_source` (FR-CTX-12, verified by Story 3.5 Task 2.2).

7. Given the event detail bottom sheet is open, when I tap "Cancel" or swipe down to dismiss, then no changes are saved and the bottom sheet closes (FR-CTX-12).

8. Given events are displayed in the EventSummaryWidget, when I tap on an event that was previously user-overridden, then the bottom sheet shows the user's overridden values (not the original AI/keyword values), and a subtle "User override" indicator is visible to distinguish it from auto-classified events (FR-CTX-12).

9. Given the API call to save the override fails (network error, server error), when the failure is detected, then the user sees a SnackBar error message "Failed to update event classification. Please try again." and the bottom sheet remains open with the user's unsaved changes so they can retry (FR-CTX-12).

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass and new tests cover: event detail bottom sheet rendering, Event Type chip selection, Formality Score slider interaction, PATCH API call, override persistence across syncs, cancel/dismiss behavior, error handling, EventSummaryWidget tap interaction, and API endpoint validation.

## Tasks / Subtasks

- [x] Task 1: API - Add `updateEventOverride` method to calendar event repository (AC: 4, 6)
  - [x] 1.1: Add `updateEventOverride(authContext, eventId, { eventType, formalityScore })` to `apps/api/src/modules/calendar/calendar-event-repository.js`. The method must: (a) set `app.current_user_id` via `set_config`, (b) execute `UPDATE app_public.calendar_events SET event_type = $1, formality_score = $2, classification_source = 'user', user_override = true, updated_at = now() WHERE id = $3 RETURNING *`, (c) verify the returned row exists (throw 404 if not -- RLS ensures the user can only update their own events), (d) wrap in `begin`/`commit`/`rollback` transaction. Follow the exact same pattern as `upsertEvents` and `getEventsForDateRange`.
  - [x] 1.2: Validate inputs: `eventType` must be one of `['work', 'social', 'active', 'formal', 'casual']`, `formalityScore` must be integer between 1 and 10 inclusive. Throw a `{ statusCode: 400, message: '...' }` error if validation fails.

- [x] Task 2: API - Add PATCH endpoint for event override (AC: 4, 9)
  - [x] 2.1: Add route `PATCH /v1/calendar/events/:id` to `apps/api/src/main.js`. Use regex pattern matching: `const eventOverrideMatch = url.pathname.match(/^\/v1\/calendar\/events\/([^/]+)$/)`. Check `req.method === "PATCH" && eventOverrideMatch`. Extract `eventId = eventOverrideMatch[1]`.
  - [x] 2.2: Request body: `{ eventType: string, formalityScore: number }`. Requires auth via `requireAuth`. Call `calendarEventRepo.updateEventOverride(authContext, eventId, body)`. Return `200` with the updated event row.
  - [x] 2.3: Handle errors: 400 for invalid input, 404 for event not found (RLS-enforced), 401 for unauthenticated. Use existing `mapError` pattern.
  - [x] 2.4: Wire `calendarEventRepo` into the `handleRequest` destructuring (it is already available from `resolveContext`).

- [x] Task 3: Mobile - Add `updateEventClassification` method to ApiClient (AC: 4)
  - [x] 3.1: Add `Future<Map<String, dynamic>> updateEventClassification(String eventId, { required String eventType, required int formalityScore })` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `_authenticatedPatch("/v1/calendar/events/$eventId", body: { "eventType": eventType, "formalityScore": formalityScore })`.

- [x] Task 4: Mobile - Add `updateEventOverride` to CalendarEventService (AC: 4, 5)
  - [x] 4.1: Add `Future<CalendarEvent?> updateEventOverride(String eventId, { required String eventType, required int formalityScore })` to `apps/mobile/lib/src/core/calendar/calendar_event_service.dart`. Calls `ApiClient.updateEventClassification(eventId, eventType: eventType, formalityScore: formalityScore)`. Parses the response into a `CalendarEvent` and returns it. Returns `null` on error (does not throw -- caller handles error state).

- [x] Task 5: Mobile - Create EventDetailBottomSheet widget (AC: 1, 2, 3, 7, 8)
  - [x] 5.1: Create `apps/mobile/lib/src/features/home/widgets/event_detail_bottom_sheet.dart` with an `EventDetailBottomSheet` StatefulWidget. Constructor accepts: `CalendarEvent event`, `ValueChanged<CalendarEvent> onSave`, `VoidCallback? onCancel`.
  - [x] 5.2: Display the event header: title (18px, #111827, bold), time range formatted as "HH:mm - HH:mm" or "All day" (14px, #6B7280), location if present (14px, #6B7280, with Icons.location_on prefix). If `event.classificationSource == "user"`, show a subtle "User override" chip (12px, #4F46E5 text, #EEF2FF background, 8px border radius).
  - [x] 5.3: Display "Event Type" section with a horizontal row of 5 `ChoiceChip` widgets for Work, Social, Active, Formal, Casual. Each chip shows the corresponding icon (`Icons.work`, `Icons.people`, `Icons.fitness_center`, `Icons.star`, `Icons.event`) and label text. Selected chip uses #4F46E5 background with white text/icon. Unselected chips use #F3F4F6 background with #4B5563 text. Initialize with `event.eventType`.
  - [x] 5.4: Display "Formality Score" section with a `Slider` widget. Range 1-10, divisions: 9, label showing current integer value. Left endpoint label: "1 - Very Casual" (12px, #6B7280). Right endpoint label: "10 - Very Formal" (12px, #6B7280). Active color: #4F46E5. Initialize with `event.formalityScore.toDouble()`.
  - [x] 5.5: Display action buttons: "Cancel" text button (#6B7280, 14px) and "Save" primary button (#4F46E5 background, white text, 12px border radius, 44px height). Save button calls `onSave` with a new `CalendarEvent` copying the original but with updated `eventType`, `formalityScore`, `classificationSource: "user"`. Cancel button calls `onCancel` or pops.
  - [x] 5.6: Follow Vibrant Soft-UI bottom sheet pattern: drag handle at top (36px wide, 4px tall, #D1D5DB, centered), 24px padding, white background, top border radius 20px. Use `showModalBottomSheet` with `isScrollControlled: true` and `useSafeArea: true`.
  - [x] 5.7: Add `Semantics` labels: "Event type selector" for the chip row, "Formality score: [value]" for the slider, "Save event classification" for Save button.

- [x] Task 6: Mobile - Make EventSummaryWidget tappable (AC: 1, 5, 8)
  - [x] 6.1: Modify `apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart`: add an `onEventTap` callback parameter (`ValueChanged<CalendarEvent>?`). Wrap the next-event row content in a `GestureDetector` (or `InkWell` for ripple) that calls `onEventTap?.call(nextEvent)` on tap. Preserve all existing rendering and semantics. Add Semantics hint: "Double tap to edit classification".

- [x] Task 7: Mobile - Integrate event override into HomeScreen (AC: 1, 4, 5, 9)
  - [x] 7.1: Add `_handleEventTap(CalendarEvent event)` method to `HomeScreenState` in `apps/mobile/lib/src/features/home/screens/home_screen.dart`. This method opens `EventDetailBottomSheet` via `showModalBottomSheet`, passing the tapped event and an `onSave` callback.
  - [x] 7.2: The `onSave` callback: (a) calls `_calendarEventService?.updateEventOverride(event.id, eventType: updatedEvent.eventType, formalityScore: updatedEvent.formalityScore)`, (b) on success, updates `_calendarEvents` in state by replacing the event with the returned updated event (match by `id`), (c) closes the bottom sheet via `Navigator.pop(context)`, (d) on failure, shows a `SnackBar` with "Failed to update event classification. Please try again." and does NOT close the bottom sheet.
  - [x] 7.3: Update `EventSummaryWidget` usage in `build()` to pass `onEventTap: _handleEventTap`.

- [x] Task 8: Mobile - Add `userOverride` field to CalendarEvent model (AC: 8)
  - [x] 8.1: Add `bool userOverride` field to `CalendarEvent` in `apps/mobile/lib/src/core/calendar/calendar_event.dart`. Default to `false`. Add to constructor as optional named parameter with default `false`. Update `fromJson` to parse `json["user_override"] as bool? ?? false`. Update `toJson` to include `"user_override": userOverride`.
  - [x] 8.2: Add `CalendarEvent copyWith({ String? eventType, int? formalityScore, String? classificationSource, bool? userOverride })` method to `CalendarEvent` for creating modified copies when saving overrides.

- [x] Task 9: API - Unit tests for updateEventOverride (AC: 4, 6, 10)
  - [x] 9.1: Add tests to `apps/api/test/modules/calendar/calendar-event-repository.test.js`:
    - `updateEventOverride` updates event_type, formality_score, classification_source, and user_override.
    - `updateEventOverride` returns the updated event row.
    - `updateEventOverride` rejects invalid event_type.
    - `updateEventOverride` rejects formality_score outside 1-10 range.
    - `updateEventOverride` returns 404 for non-existent event ID.
    - `updateEventOverride` enforces RLS (cannot update another user's event).
    - Subsequent `upsertEvents` preserves overridden fields when `user_override = true`.

- [x] Task 10: API - Integration tests for PATCH endpoint (AC: 4, 9, 10)
  - [x] 10.1: Add tests to `apps/api/test/modules/calendar/calendar-sync.test.js`:
    - `PATCH /v1/calendar/events/:id` updates classification and returns 200.
    - `PATCH /v1/calendar/events/:id` requires authentication (401 without token).
    - `PATCH /v1/calendar/events/:id` returns 400 for invalid event_type.
    - `PATCH /v1/calendar/events/:id` returns 400 for invalid formality_score.
    - `PATCH /v1/calendar/events/:id` returns 404 for non-existent event.
    - After PATCH override, `POST /v1/calendar/events/sync` preserves overridden values.

- [x] Task 11: Mobile - Unit tests for CalendarEvent model updates (AC: 8, 10)
  - [x] 11.1: Update `apps/mobile/test/core/calendar/calendar_event_test.dart`:
    - `CalendarEvent.fromJson()` parses `user_override` field.
    - `CalendarEvent.fromJson()` defaults `user_override` to false when missing.
    - `CalendarEvent.toJson()` includes `user_override` field.
    - `CalendarEvent.copyWith()` creates a modified copy with new eventType.
    - `CalendarEvent.copyWith()` creates a modified copy with new formalityScore.
    - `CalendarEvent.copyWith()` preserves unmodified fields.

- [x] Task 12: Mobile - Unit tests for CalendarEventService override (AC: 4, 10)
  - [x] 12.1: Add tests to `apps/mobile/test/core/calendar/calendar_event_service_test.dart`:
    - `updateEventOverride` calls API with correct parameters.
    - `updateEventOverride` returns parsed CalendarEvent on success.
    - `updateEventOverride` returns null on API error.

- [x] Task 13: Mobile - Widget tests for EventDetailBottomSheet (AC: 1, 2, 3, 5, 7, 8, 10)
  - [x] 13.1: Create `apps/mobile/test/features/home/widgets/event_detail_bottom_sheet_test.dart`:
    - Renders event title, time, and location.
    - Shows "User override" chip when classificationSource is "user".
    - Does not show "User override" chip when classificationSource is "keyword" or "ai".
    - Displays all 5 event type chips with correct labels and icons.
    - Pre-selects the current event type chip.
    - Tapping a different event type chip selects it (visual change).
    - Slider displays current formality score.
    - Slider updates when dragged.
    - "Save" button calls onSave with updated CalendarEvent.
    - "Cancel" button calls onCancel.
    - Semantics labels are present for chip row, slider, and save button.

- [x] Task 14: Mobile - Widget tests for EventSummaryWidget tap (AC: 1, 10)
  - [x] 14.1: Update `apps/mobile/test/features/home/widgets/event_summary_widget_test.dart`:
    - Tapping the event summary calls onEventTap with the next event.
    - onEventTap is not called when events list is empty.
    - All existing EventSummaryWidget tests continue to pass.

- [x] Task 15: Mobile - Widget tests for HomeScreen override integration (AC: 1, 5, 9, 10)
  - [x] 15.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - Tapping event in EventSummaryWidget opens EventDetailBottomSheet.
    - Saving override in bottom sheet updates EventSummaryWidget display.
    - Failed override shows SnackBar error message.
    - Cancelling bottom sheet does not change event display.
    - All existing HomeScreen tests continue to pass.

- [x] Task 16: Regression testing (AC: all)
  - [x] 16.1: Run `flutter analyze` -- zero issues.
  - [x] 16.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 16.3: Run `npm --prefix apps/api test` -- all existing + new API tests pass.
  - [x] 16.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, event summary, cache-first loading, pull-to-refresh, staleness indicator.
  - [x] 16.5: Verify the event detail bottom sheet renders correctly and does not interfere with existing layout elements.

## Dev Notes

- This is the SIXTH and FINAL story in Epic 3 (Context Integration -- Weather & Calendar). It builds directly on Story 3.5 which created the `calendar_events` table, event classification (keyword + AI), and the EventSummaryWidget. This story adds the user override capability described in FR-CTX-12.
- The primary FR covered is FR-CTX-12: "Users shall be able to re-classify events if the AI classification is incorrect." This is a P2 requirement per the functional requirements document.
- **Story 3.5 explicitly deferred this work:** "FR-CTX-12 (user re-classification) is OUT OF SCOPE. It is covered in Story 3.6. This story sets up the `user_override` column and preserves overrides during re-sync, but does NOT build the UI for manual override."
- **Story 3.5 already prepared the database layer:** The `calendar_events` table has `user_override BOOLEAN DEFAULT false` and `classification_source TEXT CHECK (classification_source IN ('keyword', 'ai', 'user'))`. The upsert SQL uses `CASE WHEN calendar_events.user_override THEN calendar_events.event_type ELSE EXCLUDED.event_type END` to preserve user overrides. The `markStaleEvents` method has `AND user_override = false` to protect overridden events from deletion.
- **No database migration needed.** All required columns (`user_override`, `classification_source` with 'user' value) were created in Story 3.5's migration `012_calendar_events.sql`.
- **The UX design specification specifies bottom sheets** for "acting on a specific item (editing a piece of clothing, viewing event details)." Quote: "A card that slides up from the bottom, covering 50-90% of the screen, with a visible drag handle at the top. Swipe down to dismiss."
- **This story completes Epic 3.** After this story, all FR-CTX requirements (01 through 13) are implemented. The epic-3 status can be moved to "done" after retrospective.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/home/widgets/event_detail_bottom_sheet.dart` (EventDetailBottomSheet)
  - `apps/mobile/test/features/home/widgets/event_detail_bottom_sheet_test.dart`
- Modified API files:
  - `apps/api/src/modules/calendar/calendar-event-repository.js` (add `updateEventOverride` method)
  - `apps/api/src/main.js` (add `PATCH /v1/calendar/events/:id` route)
  - `apps/api/test/modules/calendar/calendar-event-repository.test.js` (add override tests)
  - `apps/api/test/modules/calendar/calendar-sync.test.js` (add PATCH endpoint tests)
- Modified mobile files:
  - `apps/mobile/lib/src/core/calendar/calendar_event.dart` (add `userOverride` field, `copyWith` method)
  - `apps/mobile/lib/src/core/calendar/calendar_event_service.dart` (add `updateEventOverride` method)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `updateEventClassification` method)
  - `apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart` (add `onEventTap` callback)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add `_handleEventTap`, wire up bottom sheet)
  - `apps/mobile/test/core/calendar/calendar_event_test.dart` (add userOverride, copyWith tests)
  - `apps/mobile/test/core/calendar/calendar_event_service_test.dart` (add override tests)
  - `apps/mobile/test/features/home/widgets/event_summary_widget_test.dart` (add tap tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add override integration tests)

### Technical Requirements

- **New API endpoint:** `PATCH /v1/calendar/events/:id` -- updates the event type, formality score, sets `classification_source = 'user'` and `user_override = true`. Uses existing RLS to scope access. Returns the updated event row.
- **No new database migration.** Reuses `calendar_events` table schema from Story 3.5 migration `012_calendar_events.sql`. The `user_override`, `classification_source`, `event_type`, and `formality_score` columns are all already defined with appropriate CHECK constraints.
- **PATCH semantics:** Only `event_type` and `formality_score` are user-editable. The `classification_source` and `user_override` fields are automatically set to `'user'` and `true` by the API -- the client does not send these values.
- **CalendarEvent model extension:** Add `userOverride` boolean field (default false) and `copyWith` method. The `user_override` field is returned by the API's `RETURNING *` clause and needs to be parsed by the mobile client.
- **Bottom sheet pattern:** Follow `showModalBottomSheet` with `isScrollControlled: true`, top border radius 20px, drag handle, and safe area. This matches the UX specification for "Contextual Deep Dives."
- **Valid event types:** `work`, `social`, `active`, `formal`, `casual` -- same as Story 3.5's CHECK constraint.
- **Valid formality scores:** Integer 1-10 inclusive -- same as Story 3.5's CHECK constraint.

### Architecture Compliance

- **API boundary owns data mutations:** The override is saved via the Cloud Run API, not locally. This follows: "Server authority for sensitive rules" and "Database Boundary: Owns canonical relational state."
- **Mobile boundary owns presentation and user interaction:** The bottom sheet UI, chip selection, and slider interaction are entirely client-side. This follows: "Mobile App Boundary: Owns presentation, gestures."
- **RLS enforces access control:** The `calendar_events` RLS policy ensures users can only update their own events. No additional authorization check is needed in the API route handler.
- **Event override is preserved across syncs:** Story 3.5's upsert SQL with `CASE WHEN calendar_events.user_override` logic ensures that user overrides persist through re-syncs. This story verifies but does not change that behavior.
- **Epic 3 component mapping:** `mobile/features/home`, `api/modules/calendar` -- exactly as specified in the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies. `ChoiceChip` and `Slider` are Material widgets built into Flutter.
- No new API dependencies. The existing `pg` package handles the PATCH query.
- **Flutter Material `ChoiceChip`:** Used for event type selection. `ChoiceChip(label: Text(...), selected: bool, onSelected: (bool) => ...)`. Part of `package:flutter/material.dart`.
- **Flutter Material `Slider`:** Used for formality score. `Slider(value: double, min: 1, max: 10, divisions: 9, label: '...', onChanged: (double) => ...)`. Part of `package:flutter/material.dart`.
- **Flutter `showModalBottomSheet`:** Built-in function for displaying bottom sheets. Parameters: `isScrollControlled: true`, `useSafeArea: true`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))`.

### File Structure Requirements

- New widget in `apps/mobile/lib/src/features/home/widgets/` -- follows existing pattern of home-feature widgets (event_summary_widget, calendar_permission_card, etc.).
- Test files mirror source structure under `apps/api/test/` and `apps/mobile/test/`.
- No new directories needed. All files go into existing directories.

### Testing Requirements

- API unit tests must verify:
  - `updateEventOverride` correctly updates all fields and sets `user_override = true`
  - Input validation rejects invalid event types and out-of-range formality scores
  - RLS prevents cross-user updates (returns 404 for another user's event)
  - User overrides survive subsequent upsert syncs
- API integration tests must verify:
  - PATCH endpoint returns 200 with updated event
  - PATCH endpoint requires authentication
  - PATCH endpoint validates input (400 for bad data)
  - PATCH endpoint returns 404 for non-existent event
  - Override persists through subsequent sync
- Mobile unit tests must verify:
  - CalendarEvent model correctly handles `userOverride` field in serialization
  - `copyWith` creates correct modified copies
  - CalendarEventService `updateEventOverride` calls API and parses response
  - CalendarEventService `updateEventOverride` returns null on failure
- Mobile widget tests must verify:
  - EventDetailBottomSheet renders all UI elements correctly
  - Event type chips are selectable and pre-selected
  - Formality slider is interactive and pre-set
  - Save triggers onSave callback with updated event
  - Cancel triggers onCancel callback
  - "User override" indicator appears for user-classified events
  - EventSummaryWidget tap triggers onEventTap callback
  - HomeScreen integration: tap opens bottom sheet, save updates display, failure shows SnackBar
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new API tests pass)

### Previous Story Intelligence

- **Story 3.5 (direct predecessor)** established: `calendar_events` table with `user_override` column, `upsertEvents` with CASE logic to preserve overrides, `markStaleEvents` with `AND user_override = false`, `CalendarEvent` model, `CalendarEventService`, `EventSummaryWidget`, HomeScreen calendar event integration with `_calendarEvents` state and `_fetchCalendarEvents()`.
- **Story 3.5 explicitly stated:** "FR-CTX-12 (user re-classification) is OUT OF SCOPE. It is covered in Story 3.6. This story sets up the `user_override` column and preserves overrides during re-sync, but does NOT build the UI for manual override."
- **Story 3.5 dev notes on `device_calendar` mocking:** "Fixed mock DeviceCalendarPlugin: `Result.isSuccess` is a computed getter (not settable)." This is relevant if tests need to mock calendar event retrieval.
- **Story 3.4** established: CalendarService DI pattern, CalendarPreferencesService, `_CalendarState` enum in HomeScreen.
- **Story 2.4** established: the PATCH item update pattern in `main.js` using regex matching (`const itemIdMatch = url.pathname.match(/^\/v1\/items\/([^/]+)$/)`). This story's PATCH endpoint follows the identical pattern.
- **HomeScreen constructor parameters (as of Story 3.5):** locationService (required), weatherService (required), sharedPreferences (optional), weatherCacheService (optional), outfitContextService (optional), calendarService (optional), calendarPreferencesService (optional), calendarEventService (optional). No new constructor parameters needed for this story.
- **All 175 API tests and 523 Flutter tests pass** as of Story 3.5 completion. Do not break any of them.
- **ApiClient already has `_authenticatedPatch`** method (added in Story 2.4 for item updates). The new `updateEventClassification` method reuses this existing method.

### Key Anti-Patterns to Avoid

- DO NOT create a new database migration. The `user_override` column and `classification_source` CHECK constraint already exist from Story 3.5's `012_calendar_events.sql`.
- DO NOT modify the existing `upsertEvents` or `markStaleEvents` logic. Story 3.5 already handles override preservation correctly. This story only adds the `updateEventOverride` method.
- DO NOT send `classification_source` or `user_override` from the mobile client. The API sets these automatically when processing the override PATCH.
- DO NOT create a separate screen for event editing. Use a bottom sheet as specified by the UX design ("Contextual Deep Dives -- Bottom Sheets" for acting on specific items).
- DO NOT re-fetch all calendar events after saving an override. Update the local `_calendarEvents` list in place by replacing the overridden event. This is faster and avoids unnecessary API calls.
- DO NOT store event overrides locally (SharedPreferences or similar). Overrides are persisted server-side in the `calendar_events` table. The mobile client is not a local database.
- DO NOT add `userOverride` to `CalendarEventContext` (the lightweight model for OutfitContext). The override flag is not needed for AI outfit generation -- only the `eventType` and `formalityScore` matter.
- DO NOT use a `DropdownButton` for event type selection. Use `ChoiceChip` widgets for a more visual, touch-friendly selection that shows all options at once.
- DO NOT allow editing event title, time, or location. Only the classification (event type and formality score) is editable. The underlying calendar event data comes from the device calendar and is read-only.

### References

- [Source: epics.md - Story 3.6: Manual Event Classification Override]
- [Source: epics.md - Epic 3: Context Integration (Weather & Calendar)]
- [Source: epics.md - FR-CTX-12: Users shall be able to re-classify events if the AI classification is incorrect]
- [Source: functional-requirements.md - FR-CTX-12: Users shall be able to re-classify events if the AI classification is incorrect, Priority P2]
- [Source: ux-design-specification.md - "Contextual Deep Dives (Bottom Sheets): Acting on a specific item, viewing event details. A card that slides up from the bottom, covering 50-90% of the screen, with a visible drag handle at the top."]
- [Source: architecture.md - Database Boundary: Owns canonical relational state and transactional consistency]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures, local caching]
- [Source: architecture.md - Epic 3 Context Integration -> mobile/features/home, api/modules/calendar, api/modules/ai]
- [Source: 3-5-calendar-event-fetching-classification.md - "FR-CTX-12 (user re-classification) is OUT OF SCOPE. It is covered in Story 3.6."]
- [Source: 3-5-calendar-event-fetching-classification.md - calendar_events table with user_override column, upsert CASE logic]
- [Source: 3-5-calendar-event-fetching-classification.md - CalendarEvent model, CalendarEventService, EventSummaryWidget]
- [Source: apps/api/src/modules/calendar/calendar-event-repository.js - upsertEvents with user_override CASE expression]
- [Source: apps/api/src/main.js - PATCH /v1/items/:id pattern for regex route matching]
- [Source: apps/mobile/lib/src/core/calendar/calendar_event.dart - CalendarEvent and CalendarEventContext models]
- [Source: apps/mobile/lib/src/core/networking/api_client.dart - _authenticatedPatch method]
- [Source: apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart - EventSummaryWidget with _iconForType]
- [Source: apps/mobile/lib/src/features/home/screens/home_screen.dart - _calendarEvents state, _fetchCalendarEvents, EventSummaryWidget integration]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Fixed calendar_event_test.dart: new tests were inserted outside the `group("CalendarEvent")` block. Corrected by removing premature closing bracket.
- Fixed calendar_event_service_test.dart: new test group was placed after `main()` closing brace. Moved closing brace after new group.
- Fixed API integration tests (calendar-sync.test.js): mock `authService` needed `authenticate()` method (not `verifyToken()`). Imported `AuthenticationError` and used proper authenticate mock.
- Fixed mock response object in calendar-sync.test.js: `let statusCode` variable scoping issue in Writable class. Used shared state object instead.

### Completion Notes List

- Implemented `updateEventOverride` method in calendar-event-repository.js with input validation, RLS via set_config, begin/commit/rollback transaction pattern, and 404 for missing events.
- Added `PATCH /v1/calendar/events/:id` endpoint in main.js using the existing regex route pattern.
- Added `updateEventClassification` to ApiClient with a public `authenticatedPatch` wrapper.
- Added `updateEventOverride` to CalendarEventService that returns null on error for graceful handling.
- Created EventDetailBottomSheet widget with ChoiceChip event type selection, Slider formality score, User override indicator, drag handle, and proper Semantics.
- Made EventSummaryWidget tappable via GestureDetector wrapping the event row.
- Integrated event override flow into HomeScreen: tap opens bottom sheet, save calls API and updates state in-place, failure shows SnackBar.
- Added `userOverride` field and `copyWith` method to CalendarEvent model.
- All 188 API tests pass (175 existing + 13 new). All 550 Flutter tests pass (523 existing + 27 new). Flutter analyze: zero issues.

### Change Log

- 2026-03-13: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirement FR-CTX-12, UX design specification (bottom sheet pattern), and Stories 3.4-3.5 implementation context.
- 2026-03-13: Story implemented by Dev Agent (Amelia/Claude Opus 4.6). All 16 tasks completed. Added PATCH /v1/calendar/events/:id endpoint, EventDetailBottomSheet widget, CalendarEvent model extensions, and full test coverage (40 new tests total).

### File List

**New files:**
- apps/mobile/lib/src/features/home/widgets/event_detail_bottom_sheet.dart
- apps/mobile/test/features/home/widgets/event_detail_bottom_sheet_test.dart

**Modified files:**
- apps/api/src/modules/calendar/calendar-event-repository.js (added updateEventOverride method)
- apps/api/src/main.js (added PATCH /v1/calendar/events/:id route)
- apps/mobile/lib/src/core/calendar/calendar_event.dart (added userOverride field, copyWith method)
- apps/mobile/lib/src/core/calendar/calendar_event_service.dart (added updateEventOverride method)
- apps/mobile/lib/src/core/networking/api_client.dart (added updateEventClassification, authenticatedPatch)
- apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart (added onEventTap callback, GestureDetector)
- apps/mobile/lib/src/features/home/screens/home_screen.dart (added _handleEventTap, bottom sheet integration)
- apps/api/test/modules/calendar/calendar-event-repository.test.js (added 7 override tests)
- apps/api/test/modules/calendar/calendar-sync.test.js (added 6 PATCH endpoint tests)
- apps/mobile/test/core/calendar/calendar_event_test.dart (added 6 userOverride/copyWith tests)
- apps/mobile/test/core/calendar/calendar_event_service_test.dart (added 3 override tests)
- apps/mobile/test/features/home/widgets/event_summary_widget_test.dart (added 2 tap tests)
- apps/mobile/test/features/home/screens/home_screen_test.dart (added 4 override integration tests)
