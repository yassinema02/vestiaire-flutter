# Story 3.5: Calendar Event Fetching & Classification

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want my upcoming events fetched and classified automatically,
so that outfit suggestions reflect what I actually have planned.

## Acceptance Criteria

1. Given the user has synced their calendar (Story 3.4: `CalendarPreferencesService.isCalendarConnected()` returns true), when the Home screen loads or the user pulls to refresh, then events for today and the next 7 days are fetched from the device calendar using the `device_calendar` plugin's `retrieveEvents()` method, filtered to only the user's selected calendars (`CalendarPreferencesService.getSelectedCalendarIds()`), and sent to the Cloud Run API for persistence in the `calendar_events` table (FR-CTX-09).

2. Given events have been fetched, when they are sent to the API endpoint `POST /v1/calendar/events/sync`, then the API persists each event in the `calendar_events` table with: `profile_id`, `source_calendar_id`, `source_event_id`, `title`, `description`, `location`, `start_time`, `end_time`, `all_day` flag, `event_type` (classified), `formality_score`, `classification_source`, and `created_at`/`updated_at` timestamps (FR-CTX-09).

3. Given events are being classified, when the API processes each event, then it first attempts keyword-based classification using title/description keywords (e.g., "meeting"/"standup" -> Work, "dinner"/"birthday" -> Social, "gym"/"yoga" -> Active, "wedding"/"gala" -> Formal, fallback -> Casual), and only falls back to Gemini 2.0 Flash AI classification if keyword matching is inconclusive (FR-CTX-10).

4. Given an event has been classified, when the classification is stored, then the event receives a computed formality score from 1 (very casual) to 10 (very formal) based on the event type and contextual signals from the title/description, where Work defaults to 5, Social to 3, Active to 1, Formal to 8, Casual to 2, with AI refinement when available (FR-CTX-11).

5. Given the API receives a sync request with events the user has previously synced, when processing the batch, then existing events (matched by `source_event_id` + `source_calendar_id`) are updated (title, time, description may have changed on device) and events no longer present on the device calendar for the date range are soft-deleted or marked stale, preserving any user overrides from Story 3.6 (FR-CTX-09).

6. Given the user has events fetched and classified, when the OutfitContext is built on the Home screen, then the `OutfitContext` model is extended to include a `List<CalendarEventContext>` field containing today's classified events with their type and formality score, so that Story 4.1 can include them in the Gemini outfit generation prompt (FR-CTX-13).

7. Given the calendar sync completes (success or failure), when the Home screen displays events, then a compact event summary section appears below the dressing tip (or below the calendar prompt card area) showing the next upcoming event with its classified type icon and time, or "No events today" if empty, following the Vibrant Soft-UI design system.

8. Given the user has no calendar connected, when the Home screen loads, then no event fetching is attempted and no event summary is displayed -- the existing calendar prompt card from Story 3.4 handles this state.

9. Given the Gemini AI classification call fails (network error, quota, etc.), when the API processes an event, then the keyword-based classification result is used as the final classification with `classification_source = "keyword"` (graceful degradation), and the failure is logged to `ai_usage_log` (FR-CTX-10).

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass and new tests cover: event fetching from device calendar, event sync API endpoint, keyword classification logic, AI classification with Gemini, formality score computation, OutfitContext extension, Home screen event summary widget, calendar event repository CRUD, and graceful degradation scenarios.

## Tasks / Subtasks

- [x] Task 1: API - Create `calendar_events` database migration (AC: 2)
  - [x] 1.1: Create `infra/sql/migrations/012_calendar_events.sql` with the `calendar_events` table in `app_public` schema. Columns: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `source_calendar_id TEXT NOT NULL`, `source_event_id TEXT NOT NULL`, `title TEXT NOT NULL`, `description TEXT`, `location TEXT`, `start_time TIMESTAMPTZ NOT NULL`, `end_time TIMESTAMPTZ NOT NULL`, `all_day BOOLEAN DEFAULT false`, `event_type TEXT NOT NULL DEFAULT 'casual' CHECK (event_type IN ('work', 'social', 'active', 'formal', 'casual'))`, `formality_score INTEGER NOT NULL DEFAULT 2 CHECK (formality_score BETWEEN 1 AND 10)`, `classification_source TEXT NOT NULL DEFAULT 'keyword' CHECK (classification_source IN ('keyword', 'ai', 'user'))`, `user_override BOOLEAN DEFAULT false`, `created_at TIMESTAMPTZ DEFAULT now()`, `updated_at TIMESTAMPTZ DEFAULT now()`. Add UNIQUE constraint on `(profile_id, source_calendar_id, source_event_id)` for upsert support.
  - [x] 1.2: Add RLS policy: `CREATE POLICY calendar_events_user_policy ON app_public.calendar_events FOR ALL USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`. Follow the exact same RLS pattern used in `002_profiles.sql` and `004_items_baseline.sql`.
  - [x] 1.3: Add index: `CREATE INDEX idx_calendar_events_profile_start ON app_public.calendar_events(profile_id, start_time)` for efficient date-range queries.
  - [x] 1.4: Add updated_at trigger: reuse the existing `set_updated_at()` trigger function from prior migrations.

- [x] Task 2: API - Create calendar event repository (AC: 2, 5)
  - [x] 2.1: Create `apps/api/src/modules/calendar/calendar-event-repository.js` with `createCalendarEventRepository({ pool })`. Follow the exact pattern of `createItemRepository` and `createAiUsageLogRepository`.
  - [x] 2.2: Implement `upsertEvents(authContext, events)` that performs a batch upsert using `INSERT ... ON CONFLICT (profile_id, source_calendar_id, source_event_id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description, location = EXCLUDED.location, start_time = EXCLUDED.start_time, end_time = EXCLUDED.end_time, all_day = EXCLUDED.all_day, event_type = CASE WHEN calendar_events.user_override THEN calendar_events.event_type ELSE EXCLUDED.event_type END, formality_score = CASE WHEN calendar_events.user_override THEN calendar_events.formality_score ELSE EXCLUDED.formality_score END, classification_source = CASE WHEN calendar_events.user_override THEN calendar_events.classification_source ELSE EXCLUDED.classification_source END, updated_at = now()`. This preserves user overrides from Story 3.6.
  - [x] 2.3: Implement `getEventsForDateRange(authContext, { startDate, endDate })` that returns events within the date range, ordered by `start_time ASC`.
  - [x] 2.4: Implement `markStaleEvents(authContext, { sourceCalendarId, sourceEventIds, startDate, endDate })` that deletes events in the date range for the given calendar that are NOT in the provided `sourceEventIds` list AND do NOT have `user_override = true`.
  - [x] 2.5: All queries must set `app.current_user_id` via `set_config` before executing, wrapped in a transaction with `begin`/`commit`/`rollback`. Follow the exact pattern in `ai-usage-log-repository.js`.

- [x] Task 3: API - Create event classification service (AC: 3, 4, 9)
  - [x] 3.1: Create `apps/api/src/modules/calendar/event-classification-service.js` with `createEventClassificationService({ geminiClient, aiUsageLogRepo })`.
  - [x] 3.2: Implement keyword-based classifier function `classifyByKeywords(title, description)` that returns `{ eventType, formalityScore, confidence }`. Keyword map: Work keywords ("meeting", "standup", "review", "sprint", "presentation", "interview", "conference", "workshop", "training", "office", "call", "sync", "1:1", "demo", "deadline", "client") -> `{ eventType: "work", formalityScore: 5 }`. Social keywords ("dinner", "lunch", "birthday", "party", "drinks", "brunch", "bbq", "hangout", "catch up", "reunion", "anniversary", "shower", "celebration") -> `{ eventType: "social", formalityScore: 3 }`. Active keywords ("gym", "yoga", "run", "hike", "swim", "tennis", "football", "cycling", "pilates", "crossfit", "workout", "class", "match", "game", "practice") -> `{ eventType: "active", formalityScore: 1 }`. Formal keywords ("wedding", "gala", "ceremony", "award", "fundraiser", "opera", "ballet", "black tie", "reception", "inauguration", "graduation", "funeral") -> `{ eventType: "formal", formalityScore: 8 }`. If no keywords match, return `{ eventType: "casual", formalityScore: 2, confidence: "low" }`.
  - [x] 3.3: Implement `classifyWithAI(authContext, { title, description, location, startTime })` that calls Gemini 2.0 Flash with a structured JSON prompt: "Classify this calendar event. Return JSON: { eventType: 'work'|'social'|'active'|'formal'|'casual', formalityScore: 1-10 }. Event: title='...', description='...', location='...', time='...'". Use `generationConfig: { responseMimeType: "application/json" }` matching the categorization-service pattern. Validate the response against the valid event types and score range. Log usage to `ai_usage_log` with feature = "event_classification".
  - [x] 3.4: Implement `classifyEvent(authContext, { title, description, location, startTime })` orchestrator: first try keyword classification. If confidence is "low" AND Gemini is available, try AI classification. If AI fails, fall back to keyword result. Return `{ eventType, formalityScore, classificationSource }`.

- [x] Task 4: API - Create calendar sync endpoint (AC: 2, 5, 9)
  - [x] 4.1: Create `apps/api/src/modules/calendar/calendar-service.js` with `createCalendarService({ calendarEventRepo, classificationService })`.
  - [x] 4.2: Implement `syncEvents(authContext, { events })` that: (a) classifies each event via `classificationService.classifyEvent()`, (b) calls `calendarEventRepo.upsertEvents()` with classified events, (c) for each unique `sourceCalendarId` in the batch, calls `calendarEventRepo.markStaleEvents()` to clean up events no longer on the device. Returns `{ synced: count, classified: count }`.
  - [x] 4.3: Add route `POST /v1/calendar/events/sync` to `apps/api/src/main.js`. Request body: `{ events: [{ sourceCalendarId, sourceEventId, title, description, location, startTime, endTime, allDay }] }`. Requires auth. Returns `{ synced: N, classified: N }`.
  - [x] 4.4: Add route `GET /v1/calendar/events?start=YYYY-MM-DD&end=YYYY-MM-DD` to `apps/api/src/main.js`. Returns `{ events: [...] }` for the date range. Requires auth.
  - [x] 4.5: Wire up the calendar service in `createRuntime()`: instantiate `calendarEventRepo`, `classificationService`, and `calendarService`. Add them to the runtime object.

- [x] Task 5: Mobile - Create CalendarEventModel and CalendarEventContext (AC: 6)
  - [x] 5.1: Create `apps/mobile/lib/src/core/calendar/calendar_event.dart` with a `CalendarEvent` model class. Fields: `String id`, `String sourceCalendarId`, `String sourceEventId`, `String title`, `String? description`, `String? location`, `DateTime startTime`, `DateTime endTime`, `bool allDay`, `String eventType` (work/social/active/formal/casual), `int formalityScore` (1-10), `String classificationSource` (keyword/ai/user). Include `factory CalendarEvent.fromJson(Map<String, dynamic> json)` and `Map<String, dynamic> toJson()`.
  - [x] 5.2: Create `CalendarEventContext` class in the same file -- a lightweight version for inclusion in OutfitContext. Fields: `String title`, `String eventType`, `int formalityScore`, `DateTime startTime`, `DateTime endTime`, `bool allDay`. Include `factory CalendarEventContext.fromCalendarEvent(CalendarEvent event)` and `Map<String, dynamic> toJson()`.

- [x] Task 6: Mobile - Create CalendarEventService for event fetching (AC: 1, 8)
  - [x] 6.1: Create `apps/mobile/lib/src/core/calendar/calendar_event_service.dart` with a `CalendarEventService` class. Constructor accepts `CalendarService` (from Story 3.4), `CalendarPreferencesService` (from Story 3.4), `ApiClient`, and optional `DeviceCalendarPlugin` for direct event retrieval.
  - [x] 6.2: Implement `Future<List<CalendarEvent>> fetchAndSyncEvents()` that: (a) checks `isCalendarConnected()` -- returns empty list if false, (b) gets selected calendar IDs via `getSelectedCalendarIds()` (null = all), (c) for each selected calendar, calls `_plugin.retrieveEvents(calendarId, RetrieveEventsParams(startDate: today, endDate: today + 7 days))` to get device events, (d) maps events to sync payload, (e) calls `ApiClient.authenticatedPost("/v1/calendar/events/sync", body: { events: [...] })`, (f) calls `ApiClient._authenticatedGet("/v1/calendar/events?start=...&end=...")` to get classified events back, (g) returns `List<CalendarEvent>` parsed from the API response.
  - [x] 6.3: Handle errors gracefully: if device calendar read fails, log and return empty list. If API sync fails, attempt to return locally cached events if available or return empty list. Do not crash the app.

- [x] Task 7: Mobile - Extend OutfitContext with calendar events (AC: 6)
  - [x] 7.1: Add `List<CalendarEventContext> calendarEvents` field to `OutfitContext` in `apps/mobile/lib/src/core/weather/outfit_context.dart`. Default to empty list. Make it an optional named parameter in the constructor with default `const []`.
  - [x] 7.2: Update `OutfitContext.fromWeatherData()` to accept optional `List<CalendarEventContext>? calendarEvents` parameter and pass it through.
  - [x] 7.3: Update `OutfitContext.toJson()` to include `"calendarEvents": calendarEvents.map((e) => e.toJson()).toList()`.
  - [x] 7.4: Update `OutfitContext.fromJson()` to parse the `calendarEvents` field (treat missing field as empty list for backward compatibility with cached data from Story 3.3).
  - [x] 7.5: Update `OutfitContextService.getCurrentContext()` and `buildContextFromWeather()` to accept and pass through calendar events.

- [x] Task 8: Mobile - Create EventSummaryWidget (AC: 7, 8)
  - [x] 8.1: Create `apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart` with an `EventSummaryWidget` StatelessWidget. Accepts `List<CalendarEvent> events`.
  - [x] 8.2: Display a compact card following the Vibrant Soft-UI design system (same card styling as CalendarPermissionCard: white background, 16px border radius, `Border.all(color: Color(0xFFD1D5DB))`, shadow). Content: if events exist, show the next upcoming event with an event type icon (Icons.work for work, Icons.people for social, Icons.fitness_center for active, Icons.star for formal, Icons.event for casual), event title (16px, #111827, max 1 line ellipsis), event time (13px, #6B7280), and a small badge showing the event type label. If multiple events today, show count: "+N more events". If no events, show "No events today" with a subtle calendar icon.
  - [x] 8.3: Add `Semantics` label: "Upcoming event: [event title] at [time]" or "No events scheduled for today".

- [x] Task 9: Mobile - Integrate event fetching into HomeScreen (AC: 1, 7, 8)
  - [x] 9.1: Add `CalendarEventService` as an optional constructor parameter to `HomeScreen` (following existing DI pattern).
  - [x] 9.2: Add `List<CalendarEvent> _calendarEvents = []` state field to `HomeScreenState`.
  - [x] 9.3: Add `_fetchCalendarEvents()` async method that calls `CalendarEventService.fetchAndSyncEvents()`, updates state with the result, and passes events to OutfitContextService when building context. Call this in `_initialize()` AFTER calendar status check confirms connected, and on pull-to-refresh.
  - [x] 9.4: Update `build()`: after the calendar prompt card area (between dressing tip and "coming soon" placeholder), add `EventSummaryWidget` when `_calendarState == _CalendarState.connected` and `_calendarEvents` is not empty. If connected but no events, still show EventSummaryWidget with empty state.

- [x] Task 10: Mobile - Add calendar sync methods to ApiClient (AC: 1, 2)
  - [x] 10.1: Add `Future<Map<String, dynamic>> syncCalendarEvents(List<Map<String, dynamic>> events)` to `ApiClient` that calls `authenticatedPost("/v1/calendar/events/sync", body: { "events": events })`.
  - [x] 10.2: Add `Future<Map<String, dynamic>> getCalendarEvents({ required String startDate, required String endDate })` to `ApiClient` that calls `_authenticatedGet("/v1/calendar/events?start=$startDate&end=$endDate")`.

- [x] Task 11: API - Unit tests for event classification service (AC: 3, 4, 9, 10)
  - [x] 11.1: Create `apps/api/test/modules/calendar/event-classification-service.test.js`:
    - `classifyByKeywords` returns "work" for "Sprint Planning" title.
    - `classifyByKeywords` returns "social" for "Birthday dinner with friends" title.
    - `classifyByKeywords` returns "active" for "Yoga class" title.
    - `classifyByKeywords` returns "formal" for "Wedding reception" title.
    - `classifyByKeywords` returns "casual" with low confidence for "Doctor appointment" title.
    - `classifyByKeywords` checks description when title has no keywords.
    - `classifyWithAI` calls Gemini and returns valid classification.
    - `classifyWithAI` logs usage to ai_usage_log.
    - `classifyWithAI` returns keyword fallback when Gemini fails.
    - `classifyEvent` uses keyword result when confidence is high.
    - `classifyEvent` calls AI when keyword confidence is low.
    - `classifyEvent` returns keyword result when AI is unavailable.
    - Formality score ranges: work=5, social=3, active=1, formal=8, casual=2.

- [x] Task 12: API - Unit tests for calendar event repository (AC: 2, 5, 10)
  - [x] 12.1: Create `apps/api/test/modules/calendar/calendar-event-repository.test.js`:
    - `upsertEvents` inserts new events correctly.
    - `upsertEvents` updates existing events (matched by source IDs).
    - `upsertEvents` preserves user_override events during update.
    - `getEventsForDateRange` returns events within range.
    - `getEventsForDateRange` excludes events outside range.
    - `markStaleEvents` removes events not in provided ID list.
    - `markStaleEvents` preserves events with user_override = true.
    - RLS enforces profile-scoped access.

- [x] Task 13: API - Integration tests for calendar sync endpoint (AC: 2, 4, 5, 10)
  - [x] 13.1: Create `apps/api/test/modules/calendar/calendar-sync.test.js`:
    - `POST /v1/calendar/events/sync` with valid events returns synced count.
    - `POST /v1/calendar/events/sync` classifies events by type.
    - `POST /v1/calendar/events/sync` requires authentication (401 without token).
    - `GET /v1/calendar/events` returns events for date range.
    - `GET /v1/calendar/events` requires authentication.
    - Re-sync updates changed events and removes deleted events.

- [x] Task 14: Mobile - Unit tests for CalendarEvent model (AC: 6, 10)
  - [x] 14.1: Create `apps/mobile/test/core/calendar/calendar_event_test.dart`:
    - `CalendarEvent.fromJson()` correctly parses all fields.
    - `CalendarEvent.toJson()` serializes all fields.
    - `CalendarEventContext.fromCalendarEvent()` maps correctly.
    - `CalendarEventContext.toJson()` serializes correctly.
    - Round-trip: toJson then fromJson returns equivalent object.

- [x] Task 15: Mobile - Unit tests for CalendarEventService (AC: 1, 8, 10)
  - [x] 15.1: Create `apps/mobile/test/core/calendar/calendar_event_service_test.dart`:
    - Returns empty list when calendar not connected.
    - Fetches events from selected calendars only.
    - Fetches events from all calendars when selectedIds is null.
    - Calls API sync endpoint with fetched device events.
    - Returns classified events from API response.
    - Returns empty list on device calendar error (graceful degradation).
    - Returns empty list on API error (graceful degradation).

- [x] Task 16: Mobile - Unit tests for OutfitContext extension (AC: 6, 10)
  - [x] 16.1: Update `apps/mobile/test/core/weather/outfit_context_test.dart`:
    - OutfitContext with calendarEvents serializes events in toJson.
    - OutfitContext.fromJson with calendarEvents field parses correctly.
    - OutfitContext.fromJson without calendarEvents field defaults to empty list (backward compat).
    - OutfitContext.fromWeatherData with calendarEvents passes them through.

- [x] Task 17: Mobile - Widget tests for EventSummaryWidget (AC: 7, 10)
  - [x] 17.1: Create `apps/mobile/test/features/home/widgets/event_summary_widget_test.dart`:
    - Renders next upcoming event title and time.
    - Shows event type icon matching event type.
    - Shows "+N more events" when multiple events exist.
    - Shows "No events today" when events list is empty.
    - Semantics labels are present and correct.

- [x] Task 18: Mobile - Widget tests for HomeScreen calendar event integration (AC: 1, 7, 8, 10)
  - [x] 18.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When calendar is connected and events fetched, EventSummaryWidget appears.
    - When calendar is connected but no events, "No events today" state shows.
    - When calendar is not connected, no EventSummaryWidget appears.
    - Pull-to-refresh triggers event re-fetch.
    - All existing HomeScreen tests continue to pass.

- [x] Task 19: Regression testing (AC: all)
  - [x] 19.1: Run `flutter analyze` -- zero issues.
  - [x] 19.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 19.3: Run `npm --prefix apps/api test` -- all existing + new API tests pass.
  - [x] 19.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, cache-first loading, pull-to-refresh, staleness indicator.
  - [x] 19.5: Verify the event summary widget renders correctly and does not interfere with existing layout elements.

## Dev Notes

- This is the FIFTH story in Epic 3 (Context Integration -- Weather & Calendar). It builds on Story 3.4 which established calendar permission and selection. This story adds the actual event fetching, server-side persistence, AI/keyword classification, and Home screen event display.
- The primary FRs covered are FR-CTX-09 (fetch and store events for today + 7 days), FR-CTX-10 (classify events by type using keyword detection and AI fallback), FR-CTX-11 (formality score 1-10), and partially FR-CTX-13 (extending OutfitContext with calendar events).
- **FR-CTX-12 (user re-classification) is OUT OF SCOPE.** It is covered in Story 3.6. This story sets up the `user_override` column and preserves overrides during re-sync, but does NOT build the UI for manual override.
- **This is the FIRST story in Epic 3 that requires API/backend changes.** Stories 3.1-3.4 were entirely client-side. This story creates a new database migration, a new API module (`calendar`), and new API endpoints.
- **The `device_calendar` plugin's `retrieveEvents()` method** is used to fetch events. It returns `Event` objects with: `eventId`, `calendarId`, `title`, `description`, `start`, `end`, `allDay`, `location`. These are mapped to the sync payload sent to the API.
- **Keyword-first classification strategy:** The architecture specifies "keyword detection and AI fallback" (FR-CTX-10). Keywords are cheap and fast. AI (Gemini) is called ONLY when keyword confidence is low. This minimizes AI costs and latency. The keyword map should be comprehensive enough that ~70-80% of events are classified without AI.
- **Event sync is a full-range upsert:** The mobile client sends ALL events for the next 7 days. The API upserts them (insert or update) and marks stale events not in the batch. This handles event modifications and deletions on the device calendar.
- **The `user_override` column** is critical for Story 3.6 compatibility. When a user manually reclassifies an event in Story 3.6, `user_override` is set to `true`. Subsequent syncs must NOT overwrite user-classified events. The upsert SQL uses a CASE expression to preserve overridden fields.
- **OutfitContext extension is backward-compatible.** The `calendarEvents` field defaults to an empty list. Existing cached OutfitContext data from Story 3.3 (which lacks this field) will deserialize correctly because `fromJson` treats a missing field as empty list.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/012_calendar_events.sql` (database migration)
  - `apps/api/src/modules/calendar/calendar-event-repository.js` (repository)
  - `apps/api/src/modules/calendar/event-classification-service.js` (keyword + AI classifier)
  - `apps/api/src/modules/calendar/calendar-service.js` (sync orchestration)
  - `apps/api/test/modules/calendar/event-classification-service.test.js`
  - `apps/api/test/modules/calendar/calendar-event-repository.test.js`
  - `apps/api/test/modules/calendar/calendar-sync.test.js`
- New mobile files:
  - `apps/mobile/lib/src/core/calendar/calendar_event.dart` (CalendarEvent + CalendarEventContext models)
  - `apps/mobile/lib/src/core/calendar/calendar_event_service.dart` (CalendarEventService)
  - `apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart` (EventSummaryWidget)
  - `apps/mobile/test/core/calendar/calendar_event_test.dart`
  - `apps/mobile/test/core/calendar/calendar_event_service_test.dart`
  - `apps/mobile/test/features/home/widgets/event_summary_widget_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add calendar sync and events GET routes, wire up calendar services in createRuntime)
- Modified mobile files:
  - `apps/mobile/lib/src/core/weather/outfit_context.dart` (add calendarEvents field)
  - `apps/mobile/lib/src/core/weather/outfit_context_service.dart` (pass through calendarEvents)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add syncCalendarEvents and getCalendarEvents methods)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add CalendarEventService DI, event fetching, EventSummaryWidget rendering)
  - `apps/mobile/test/core/weather/outfit_context_test.dart` (add calendarEvents tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add event integration tests)

### Technical Requirements

- **New database table:** `calendar_events` in `app_public` schema with RLS, UUID PK, foreign key to `profiles`, unique constraint for upsert support, CHECK constraints for `event_type` and `formality_score`.
- **New API module:** `apps/api/src/modules/calendar/` with repository, classification service, and calendar service. Follow the same functional composition pattern as `modules/ai/` and `modules/items/`.
- **Gemini 2.0 Flash** for AI event classification. Use the existing `geminiClient` from `createRuntime()`. Model: `gemini-2.0-flash`. Response format: JSON mode (`responseMimeType: "application/json"`). Follow the exact pattern in `categorization-service.js`.
- **AI usage logging:** All Gemini calls for event classification must be logged to `ai_usage_log` with `feature = "event_classification"`. Follow the pattern in `categorization-service.js`.
- **device_calendar plugin event retrieval:** Use `_plugin.retrieveEvents(calendarId, RetrieveEventsParams(startDate: start, endDate: end))`. The plugin returns `Result<List<Event>>`. Map each `Event` to the sync payload: `{ sourceCalendarId: event.calendarId, sourceEventId: event.eventId, title: event.title, description: event.description, location: event.location, startTime: event.start.toIso8601String(), endTime: event.end.toIso8601String(), allDay: event.allDay }`.
- **No write access to device calendar.** This story only reads events. The `device_calendar` plugin's `createOrUpdateEvent` and `deleteEvent` methods must NOT be used.
- **SharedPreferences keys consumed from Story 3.4:** `"calendar_selected_ids"` and `"calendar_connected"`. Read via `CalendarPreferencesService`.

### Architecture Compliance

- **API boundary owns classification and persistence:** The mobile client fetches raw events from the device and sends them to Cloud Run. Classification (keyword + AI) happens server-side. This follows: "AI calls are brokered only by Cloud Run" and "Server authority for sensitive rules."
- **Database boundary owns canonical state:** Events are stored in Cloud SQL `calendar_events` table with RLS. The mobile client does not persist events locally -- it reads from the API. This follows: "Database Boundary: Owns canonical relational state and transactional consistency."
- **Mobile boundary owns device access and presentation:** The mobile client reads from the device calendar and renders the event summary. This follows: "Mobile App Boundary: Owns presentation, gestures, local caching."
- **Graceful AI degradation:** If Gemini fails, keyword classification is used as fallback. This follows: "Guardrails: safe defaults when AI confidence is low" and "graceful fallbacks for AI failures."
- **Epic 3 component mapping:** `mobile/features/home`, `api/modules/calendar`, `api/modules/ai` -- exactly as specified in the architecture's epic-to-component mapping.

### Library / Framework Requirements

- No new Flutter dependencies. `device_calendar: ^4.3.3` was added in Story 3.4. `http` and `shared_preferences` are already in pubspec.yaml.
- No new API dependencies. The existing `@google-cloud/vertexai` and `pg` packages are sufficient.
- **device_calendar Event retrieval API:** `retrieveEvents(String calendarId, RetrieveEventsParams params)` returns `Result<UnmodifiableListView<Event>>`. The `Event` class fields: `String? eventId`, `String? calendarId`, `String? title`, `String? description`, `TZDateTime? start`, `TZDateTime? end`, `bool? allDay`, `String? location`.

### File Structure Requirements

- New API module: `apps/api/src/modules/calendar/` -- follows the pattern of `modules/ai/`, `modules/items/`, `modules/profiles/`.
- New migration: `infra/sql/migrations/012_calendar_events.sql` -- follows sequential numbering after `011_items_favorite.sql`.
- New model in `apps/mobile/lib/src/core/calendar/` -- extends the existing calendar core module created in Story 3.4.
- New widget in `apps/mobile/lib/src/features/home/widgets/` -- follows existing pattern of home-feature widgets.
- Test files mirror source structure under `apps/api/test/` and `apps/mobile/test/`.

### Testing Requirements

- API unit tests must verify:
  - Keyword classification returns correct event types and formality scores for known keywords
  - AI classification calls Gemini with correct prompt and parses response
  - AI classification falls back to keywords on Gemini failure
  - AI usage is logged for classification calls
  - Calendar event repository upserts, queries by date range, and marks stale events
  - User overrides are preserved during upsert
  - RLS enforces profile-scoped access
- API integration tests must verify:
  - POST /v1/calendar/events/sync accepts events and returns sync count
  - GET /v1/calendar/events returns events for date range
  - Both endpoints require authentication
  - Re-sync handles updates and deletions correctly
- Mobile unit tests must verify:
  - CalendarEvent model serialization round-trip
  - CalendarEventService returns empty list when not connected
  - CalendarEventService fetches from selected calendars only
  - CalendarEventService handles errors gracefully
  - OutfitContext backward compatibility with missing calendarEvents field
- Mobile widget tests must verify:
  - EventSummaryWidget displays event information correctly
  - EventSummaryWidget shows empty state
  - HomeScreen integration: events appear when connected, absent when not
  - All existing HomeScreen tests continue to pass
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing + new API tests pass)

### Previous Story Intelligence

- **Story 3.4 (direct predecessor)** established: CalendarService with DI pattern, CalendarPreferencesService with SharedPreferences, CalendarPermissionCard/CalendarDeniedCard widgets, CalendarSelectionScreen, HomeScreen calendar state machine (`_CalendarState` enum). This story extends CalendarService with event retrieval and adds CalendarEventService as a new service.
- **Story 3.4 explicitly stated:** "Story 3.5 will consume the calendar preferences saved by this story. Specifically, `CalendarPreferencesService.getSelectedCalendarIds()` returns the user's chosen calendars, and `CalendarPreferencesService.isCalendarConnected()` tells Story 3.5 whether to attempt event fetching at all."
- **Story 3.4 dev notes:** Fixed mock DeviceCalendarPlugin issues -- `Result.isSuccess` is a computed getter (not settable), `retrieveCalendars()` returns `UnmodifiableListView<Calendar>`. The same patterns apply to `retrieveEvents()` which returns `Result<UnmodifiableListView<Event>>`.
- **Story 3.3** established: OutfitContext model with `toJson()`/`fromJson()`, OutfitContextService, DressingTipWidget. OutfitContext was explicitly designed to be "extensible for calendar data" per Story 3.3's references.
- **Story 3.1** established: the HomeScreen state machine pattern, DI pattern for services, SharedPreferences integration, and the overall Home screen layout flow.
- **Story 2.3** established: the AI categorization pattern (categorization-service.js) -- Gemini 2.0 Flash call with JSON mode, taxonomy validation, safe defaults, AI usage logging. This story's event classification follows the IDENTICAL pattern.
- **HomeScreen constructor parameters (as of Story 3.4):** locationService (required), weatherService (required), sharedPreferences (optional), weatherCacheService (optional), outfitContextService (optional), calendarService (optional), calendarPreferencesService (optional). This story adds calendarEventService (optional).
- **All 494 Flutter tests and 146 API tests pass** as of Story 3.4 completion. Do not break any of them.

### Key Anti-Patterns to Avoid

- DO NOT implement user re-classification UI. That is Story 3.6. This story only provides the `user_override` column and preserves overrides during re-sync.
- DO NOT write to the device calendar. Only READ events. The app is a passive consumer of calendar data.
- DO NOT store events locally on the mobile client. Events are persisted server-side in Cloud SQL and fetched via the API. The mobile client is not a local database.
- DO NOT call Gemini for every event. Use keyword classification first. Only fall back to AI when keywords are inconclusive. This is both a cost and latency optimization.
- DO NOT skip AI usage logging. Every Gemini call for event classification MUST be logged to `ai_usage_log`.
- DO NOT create a separate migration file for the RLS policy. Include the RLS policy in the same migration file as the table creation (`012_calendar_events.sql`), following the pattern of `004_items_baseline.sql`.
- DO NOT break backward compatibility of OutfitContext. The `calendarEvents` field must default to empty list so existing cached data still works.
- DO NOT make calendar event fetching block the Home screen load. Fetch events asynchronously after weather data loads. Show the event summary widget when data arrives.
- DO NOT duplicate the Gemini client initialization. Reuse the existing `geminiClient` from `createRuntime()`.
- DO NOT use `permission_handler` for calendar. The `device_calendar` plugin has built-in permission handling (already configured in Story 3.4).

### References

- [Source: epics.md - Story 3.5: Calendar Event Fetching & Classification]
- [Source: epics.md - Epic 3: Context Integration (Weather & Calendar)]
- [Source: prd.md - FR-CTX-09: The system shall fetch and store events for today and the next 7 days in `calendar_events`]
- [Source: prd.md - FR-CTX-10: The system shall classify calendar events by type using keyword detection and AI fallback: Work, Social, Active, Formal, Casual]
- [Source: prd.md - FR-CTX-11: Each classified event shall receive a formality score (1-10)]
- [Source: prd.md - FR-CTX-13: The system shall compile a context object (weather + events + date + day-of-week) for AI outfit generation]
- [Source: functional-requirements.md - Section 3.5 Context Integration (Weather & Calendar)]
- [Source: functional-requirements.md - Table 7.1: calendar_events -- Synced and classified calendar events, belongs to profile]
- [Source: architecture.md - AI Orchestration: calendar event classification, Gemini 2.0 Flash]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Data Architecture: calendar_events table, RLS, UUID PKs, JSONB]
- [Source: architecture.md - Epic 3 Context Integration -> mobile/features/home, api/modules/calendar, api/modules/ai]
- [Source: architecture.md - Project Structure: apps/api/src/modules/]
- [Source: 3-4-calendar-sync-permission-selection.md - CalendarService, CalendarPreferencesService, device_calendar ^4.3.3]
- [Source: 3-4-calendar-sync-permission-selection.md - "Story 3.5 will consume the calendar preferences"]
- [Source: 3-3-practical-weather-aware-outfit-context.md - OutfitContext designed to be extensible for calendar data]
- [Source: apps/api/src/modules/ai/categorization-service.js - Gemini classification pattern with JSON mode]
- [Source: apps/api/src/modules/ai/ai-usage-log-repository.js - AI usage logging pattern]
- [Source: apps/mobile/lib/src/core/calendar/calendar_service.dart - CalendarService with DI]
- [Source: apps/mobile/lib/src/core/calendar/calendar_preferences_service.dart - SharedPreferences-based calendar preferences]
- [Source: apps/mobile/lib/src/core/weather/outfit_context.dart - OutfitContext model with toJson/fromJson]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

### Completion Notes List

- Implemented calendar_events database migration with RLS, indexes, and triggers (Task 1)
- Created calendar event repository with upsert, date-range query, and stale cleanup (Task 2)
- Built keyword-first event classification with Gemini AI fallback and usage logging (Task 3)
- Created calendar sync service and wired POST/GET endpoints into main.js (Task 4)
- Created CalendarEvent and CalendarEventContext models with JSON serialization (Task 5)
- Built CalendarEventService for device event fetching and API sync (Task 6)
- Extended OutfitContext with backward-compatible calendarEvents field (Task 7)
- Created EventSummaryWidget with Vibrant Soft-UI design and accessibility (Task 8)
- Integrated event fetching into HomeScreen with DI and pull-to-refresh support (Task 9)
- Added syncCalendarEvents and getCalendarEvents methods to ApiClient (Task 10)
- All 175 API tests pass (29 new calendar tests). All 523 Flutter tests pass (29 new tests). flutter analyze: zero issues.

### Change Log

- 2026-03-13: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirements (FR-CTX-09, FR-CTX-10, FR-CTX-11, FR-CTX-13), UX design specification, and Stories 3.1-3.4 implementation context.
- 2026-03-13: Story implementation completed by Dev Agent (Claude Opus 4.6). All 19 tasks implemented and tested. 175 API tests, 523 Flutter tests passing.

### File List

New files:
- infra/sql/migrations/012_calendar_events.sql
- apps/api/src/modules/calendar/calendar-event-repository.js
- apps/api/src/modules/calendar/event-classification-service.js
- apps/api/src/modules/calendar/calendar-service.js
- apps/api/test/modules/calendar/event-classification-service.test.js
- apps/api/test/modules/calendar/calendar-event-repository.test.js
- apps/api/test/modules/calendar/calendar-sync.test.js
- apps/mobile/lib/src/core/calendar/calendar_event.dart
- apps/mobile/lib/src/core/calendar/calendar_event_service.dart
- apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart
- apps/mobile/test/core/calendar/calendar_event_test.dart
- apps/mobile/test/core/calendar/calendar_event_service_test.dart
- apps/mobile/test/features/home/widgets/event_summary_widget_test.dart

Modified files:
- apps/api/src/main.js
- apps/mobile/lib/src/core/weather/outfit_context.dart
- apps/mobile/lib/src/core/weather/outfit_context_service.dart
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/home/screens/home_screen.dart
- apps/mobile/test/core/weather/outfit_context_test.dart
- apps/mobile/test/features/home/screens/home_screen_test.dart
