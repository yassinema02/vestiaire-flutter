# Story 12.1: Event Display & Suggestions

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to see my upcoming calendar events directly on the Home screen and receive tailored event-specific outfit suggestions,
so that I know what to wear for the specific occasion, not just the weather.

## Acceptance Criteria

1. Given I have a synced calendar with upcoming events, when I view the Home screen, then my upcoming events for the day are displayed in an enhanced "Events" section showing each event's classified type (Work/Social/Active/Formal/Casual), formality score, time, and title -- replacing the simpler single-event EventSummaryWidget from Story 3.5 with a richer multi-event display (FR-EVT-01).

2. Given events are displayed on the Home screen, when I view the events section, then each event shows: a type icon (matching the existing `_iconForType` mapping from EventSummaryWidget), the event title (16px, #111827), time (13px, #6B7280), a formality badge showing the score (e.g., "Formality 8/10"), and the classified type label as a colored chip. Events are ordered chronologically. Maximum 3 events visible, with a "View all" link if more exist (FR-EVT-01).

3. Given events are displayed on the Home screen, when I tap on an event, then a bottom sheet opens showing: event details (title, time, location, type, formality) and an "Event Outfit Suggestions" section that triggers `POST /v1/outfits/generate-for-event` to generate 3 outfit suggestions specifically optimized for that event's formality, type, time of day, and current weather (FR-EVT-02).

4. Given the event outfit generation endpoint is called, when the API processes the request, then it constructs a Gemini prompt that includes: the standard wardrobe inventory and weather context (reusing the pattern from Story 4.1's outfit-generation-service), PLUS the specific event context (title, type, formality score, time of day, location) with explicit instructions to optimize all 3 suggestions for this specific event's formality level and occasion type (FR-EVT-02).

5. Given event-specific outfit suggestions are generated, when the API returns the response, then it returns the same `{ suggestions: [...], generatedAt: "..." }` structure as the daily generation endpoint (reusing `OutfitSuggestion` and `OutfitSuggestionItem` models), so that the mobile client can display them using the existing `OutfitSuggestionCard` widget pattern (FR-EVT-02).

6. Given event outfit suggestions are displayed in the event bottom sheet, when I view them, then I see a vertical scrollable list of up to 3 `OutfitSuggestionCard` widgets, each showing: outfit name, item thumbnails, "Why this outfit?" explanation (which references the specific event), and the occasion tag. A loading shimmer is shown while generation is in progress (FR-EVT-02).

7. Given the daily AI outfit generation already factors in calendar events (established in Story 4.1), when events exist for today, then the Home screen's daily outfit suggestion already considers the most formal event. This story does NOT change the daily generation logic -- it adds the ability to get event-SPECIFIC suggestions by tapping an individual event (FR-EVT-01, FR-EVT-02).

8. Given the event outfit generation API call fails, when the failure is detected, then the bottom sheet shows an inline error message "Unable to generate suggestions for this event. Pull down to retry." with a retry button. The event details remain visible above the error (FR-EVT-02).

9. Given I have no calendar connected (calendar not synced), when the Home screen loads, then the existing behavior from Story 3.4 is preserved -- the CalendarPermissionCard or CalendarDeniedCard is shown, and no events section appears. No changes to the unconnected state (FR-EVT-01).

10. Given I have a connected calendar but no events today, when the Home screen loads, then the EventSummaryWidget's existing "No events today" empty state from Story 3.5 is preserved or enhanced with the new events section showing the empty state (FR-EVT-01).

11. Given the event-specific generation uses AI, when the call completes, then the AI usage is logged to `ai_usage_log` with `feature = "event_outfit_generation"` (distinct from "outfit_generation") so costs can be tracked separately (NFR-OBS-02).

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1175+ API tests, 1585+ Flutter tests) and new tests cover: enhanced events section rendering, event tap opening bottom sheet, event-specific generation API endpoint (auth, success, failure, validation), Gemini prompt with event context, API usage logging, mobile EventOutfitBottomSheet widget (loading, success, error states), HomeScreen integration (events section with multiple events, tap interaction), and regression on existing EventSummaryWidget behavior.

## Tasks / Subtasks

- [x] Task 1: API - Create event-specific outfit generation method (AC: 4, 5, 11)
  - [x] 1.1: In `apps/api/src/modules/outfits/outfit-generation-service.js`, add `async generateOutfitsForEvent(authContext, { outfitContext, event })` method. This follows the IDENTICAL pattern of the existing `generateOutfits` method but with a modified Gemini prompt. Steps: (a) check `geminiClient.isAvailable()`, (b) fetch user items via `itemRepo.listItems(authContext, {})`, (c) filter to `categorizationStatus === "completed"`, (d) check >= 3 items, (e) build event-specific prompt (Task 1.2), (f) call Gemini, (g) parse and validate response (reuse exact validation from `generateOutfits`), (h) log to `ai_usage_log` with `feature: "event_outfit_generation"`.
  - [x] 1.2: Construct the event-specific Gemini prompt. Extend the existing daily prompt template with event-specific instructions:
    ```
    You are a personal stylist AI. Generate 3 outfit suggestions specifically for the following event.

    EVENT:
    - Title: {event.title}
    - Type: {event.eventType} (work/social/active/formal/casual)
    - Formality Score: {event.formalityScore}/10
    - Time: {event.startTime} to {event.endTime}
    - Location: {event.location || "Not specified"}

    TODAY'S CONTEXT:
    - Date: {date} ({dayOfWeek})
    - Season: {season}
    - Weather: {weatherDescription}, {temperature}°C (feels like {feelsLike}°C)
    - Clothing constraints: {JSON.stringify(clothingConstraints)}

    WARDROBE ITEMS (pick from these ONLY — use exact item IDs):
    {items as JSON array}

    RULES:
    1. Each outfit must contain 2-7 items from the wardrobe list above.
    2. Use ONLY item IDs that exist in the wardrobe list. Do NOT invent IDs.
    3. ALL 3 outfits must be appropriate for the event's formality level ({event.formalityScore}/10).
    4. For "formal" events (formality >= 7): prioritize blazers, dress shirts, tailored trousers, heels, structured bags.
    5. For "active" events (formality <= 2): prioritize sportswear, trainers, breathable fabrics.
    6. For "work" events (formality 4-6): smart-casual to business casual depending on score.
    7. Respect the weather constraints: avoid avoidMaterials, prefer preferredMaterials.
    8. Vary the 3 suggestions -- offer different style interpretations of the same formality level.
    9. For each outfit, explain WHY it suits this specific event.

    Return ONLY valid JSON with this exact structure:
    {
      "suggestions": [
        {
          "name": "Short descriptive outfit name",
          "itemIds": ["uuid-1", "uuid-2", "uuid-3"],
          "explanation": "Why this outfit works for [event title]...",
          "occasion": "one of: everyday, work, formal, party, date-night, outdoor, sport, casual"
        }
      ]
    }
    ```
  - [x] 1.3: Reuse the existing `parseAndValidateSuggestions()` logic (extract it to a shared helper if it is currently inline in `generateOutfits`, or call it directly). Do NOT duplicate the validation code.

- [x] Task 2: API - Add `POST /v1/outfits/generate-for-event` endpoint (AC: 3, 4, 5, 8, 11)
  - [x] 2.1: Add route `POST /v1/outfits/generate-for-event` to `apps/api/src/main.js`. Place it after the existing `POST /v1/outfits/generate` route. The route: authenticates via `requireAuth`, reads the request body, calls `outfitGenerationService.generateOutfitsForEvent(authContext, { outfitContext: body.outfitContext, event: body.event })`, and returns 200 with the result.
  - [x] 2.2: Request body shape: `{ outfitContext: { ... }, event: { title: string, eventType: string, formalityScore: number, startTime: string, endTime: string, location: string | null } }`. Validate that `event` is present and has required fields. Return 400 if missing.
  - [x] 2.3: Handle errors using the existing `mapError` pattern. 400 for missing event data, 401 for unauthenticated, 503 for AI unavailable, 500 for generation failure.

- [x] Task 3: Mobile - Create EventsSection widget (AC: 1, 2, 9, 10)
  - [x] 3.1: Create `apps/mobile/lib/src/features/home/widgets/events_section.dart` with an `EventsSection` StatelessWidget. Constructor accepts `List<CalendarEvent> events`, `ValueChanged<CalendarEvent>? onEventTap`.
  - [x] 3.2: Display a section with header "Today's Events" (16px, #111827, bold). Below the header, render up to 3 events as compact event cards within a `Column`. Each event card shows: event type icon (reuse the `_iconForType` mapping from `EventSummaryWidget` -- extract to a shared utility if not already shared), event title (15px, #111827, max 1 line ellipsis), time range (13px, #6B7280), a formality badge (small chip: "Formality X/10", 11px, #4F46E5 text on #EEF2FF background), and event type label chip (12px, matching type color). Each card is wrapped in `GestureDetector` calling `onEventTap?.call(event)`.
  - [x] 3.3: If `events.length > 3`, show a "View all X events" text button below the list (14px, #4F46E5).
  - [x] 3.4: If `events` is empty, show: calendar icon (32px, #9CA3AF) + "No events today" text (14px, #6B7280). This replaces the EventSummaryWidget's empty state.
  - [x] 3.5: Card styling: white background, 12px border radius, `Border.all(color: Color(0xFFE5E7EB))`, 12px padding, 8px spacing between cards. Follow Vibrant Soft-UI system.
  - [x] 3.6: Add `Semantics` labels: "Today's events section", "Event: [title] at [time], [type], formality [score]" for each event card.

- [x] Task 4: Mobile - Create EventOutfitBottomSheet widget (AC: 3, 6, 8)
  - [x] 4.1: Create `apps/mobile/lib/src/features/home/widgets/event_outfit_bottom_sheet.dart` with an `EventOutfitBottomSheet` StatefulWidget. Constructor accepts `CalendarEvent event`, `OutfitGenerationService outfitGenerationService`, `OutfitContext? outfitContext`.
  - [x] 4.2: Display event details at the top: title (18px, #111827, bold), time range (14px, #6B7280), location if present (14px, #6B7280, Icons.location_on prefix), event type chip and formality badge (matching EventsSection styling). If `event.classificationSource == "user"`, show the "User override" indicator from EventDetailBottomSheet (Story 3.6).
  - [x] 4.3: Below event details, show a divider, then "Event Outfit Suggestions" header (16px, #111827, bold).
  - [x] 4.4: On widget init, automatically call `_generateEventOutfits()` which calls `outfitGenerationService.generateOutfitsForEvent(outfitContext, event)`. Show a shimmer loading state (3 card-shaped shimmer placeholders) while loading.
  - [x] 4.5: On success, display up to 3 `OutfitSuggestionCard` widgets in a vertical `ListView`. Reuse the existing `OutfitSuggestionCard` from `apps/mobile/lib/src/features/home/widgets/outfit_suggestion_card.dart` without modification.
  - [x] 4.6: On error, display inline: calendar icon (32px, #EF4444), "Unable to generate suggestions for this event." text (14px, #6B7280), and a "Try Again" button (#4F46E5) that re-triggers generation.
  - [x] 4.7: Bottom sheet pattern: drag handle at top (36px wide, 4px tall, #D1D5DB, centered), 24px horizontal padding, white background, top border radius 20px. Use `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`. Set minimum height to 60% of screen height via `DraggableScrollableSheet` or constrained box.
  - [x] 4.8: Add `Semantics` labels: "Outfit suggestions for [event title]", "Loading event outfit suggestions" during loading.

- [x] Task 5: Mobile - Add `generateOutfitsForEvent` method to OutfitGenerationService and ApiClient (AC: 3, 4)
  - [x] 5.1: Add `Future<Map<String, dynamic>> generateOutfitsForEvent(Map<String, dynamic> outfitContext, Map<String, dynamic> event)` method to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedPost("/v1/outfits/generate-for-event", body: { "outfitContext": outfitContext, "event": event })`.
  - [x] 5.2: Add `Future<OutfitGenerationResult?> generateOutfitsForEvent(OutfitContext context, CalendarEvent event)` to `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart`. Serializes context via `context.toJson()` and event via `{ "title": event.title, "eventType": event.eventType, "formalityScore": event.formalityScore, "startTime": event.startTime.toIso8601String(), "endTime": event.endTime.toIso8601String(), "location": event.location }`. Calls `_apiClient.generateOutfitsForEvent(contextJson, eventJson)`. Parses response into `OutfitGenerationResult`. Returns `null` on error.

- [x] Task 6: Mobile - Integrate EventsSection and EventOutfitBottomSheet into HomeScreen (AC: 1, 3, 7, 9, 10)
  - [x] 6.1: In `apps/mobile/lib/src/features/home/screens/home_screen.dart`, replace the `EventSummaryWidget` usage with the new `EventsSection` widget. The replacement occurs in the `build()` method where EventSummaryWidget is currently rendered (when `_calendarState == _CalendarState.connected`). Pass `onEventTap: _handleEventOutfitTap`.
  - [x] 6.2: Add `_handleEventOutfitTap(CalendarEvent event)` method to `HomeScreenState`. This opens the `EventOutfitBottomSheet` via `showModalBottomSheet`, passing the tapped event, the `_outfitGenerationService`, and the current `outfitContext`.
  - [x] 6.3: Preserve all existing behavior: when calendar is not connected, show CalendarPermissionCard/CalendarDeniedCard. When connected but no events, show EventsSection with empty state. When connected with events, show EventsSection with event cards. The existing `_handleEventTap` method (from Story 3.6, which opens EventDetailBottomSheet for classification override) should still be accessible -- add a small "edit classification" icon button on each event card in EventsSection that opens the existing EventDetailBottomSheet, while the main card tap opens EventOutfitBottomSheet.
  - [x] 6.4: The existing daily outfit generation (OutfitSuggestionCard) remains unchanged. Events section appears ABOVE the daily outfit suggestion, BELOW the dressing tip (or calendar prompt card area). Layout order in build: weather -> forecast -> dressing tip -> [calendar prompt OR events section] -> daily outfit suggestion.

- [x] Task 7: API - Unit tests for event-specific generation (AC: 4, 5, 11, 12)
  - [x] 7.1: Add tests to `apps/api/test/modules/outfits/outfit-generation-service.test.js`:
    - `generateOutfitsForEvent` calls Gemini with event-specific prompt containing event title, type, formality.
    - `generateOutfitsForEvent` returns validated suggestions with enriched item data.
    - `generateOutfitsForEvent` logs usage with feature "event_outfit_generation".
    - `generateOutfitsForEvent` throws error when fewer than 3 categorized items.
    - `generateOutfitsForEvent` throws 503 when Gemini is unavailable.
    - `generateOutfitsForEvent` handles Gemini failure gracefully.
    - `generateOutfitsForEvent` validates event input (requires title, eventType, formalityScore).

- [x] Task 8: API - Integration tests for POST /v1/outfits/generate-for-event (AC: 3, 5, 8, 12)
  - [x] 8.1: Create tests in `apps/api/test/modules/outfits/outfit-generation.test.js` (add to existing file):
    - `POST /v1/outfits/generate-for-event` requires authentication (401 without token).
    - `POST /v1/outfits/generate-for-event` returns 200 with suggestions on success.
    - `POST /v1/outfits/generate-for-event` returns 400 when event data is missing.
    - `POST /v1/outfits/generate-for-event` returns 400 when event fields are incomplete.
    - `POST /v1/outfits/generate-for-event` returns 503 when Gemini is unavailable.
    - `POST /v1/outfits/generate-for-event` returns 500 when Gemini call fails.

- [x] Task 9: Mobile - Unit tests for OutfitGenerationService event method (AC: 3, 4, 12)
  - [x] 9.1: Add tests to `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart`:
    - `generateOutfitsForEvent` calls API with serialized context and event.
    - `generateOutfitsForEvent` returns parsed OutfitGenerationResult on success.
    - `generateOutfitsForEvent` returns null on API error.
    - `generateOutfitsForEvent` returns null on network error.

- [x] Task 10: Mobile - Widget tests for EventsSection (AC: 1, 2, 10, 12)
  - [x] 10.1: Create `apps/mobile/test/features/home/widgets/events_section_test.dart`:
    - Renders "Today's Events" header.
    - Displays up to 3 events with title, time, type icon, formality badge.
    - Shows "View all X events" when more than 3 events.
    - Shows "No events today" empty state when events list is empty.
    - Tapping an event calls onEventTap with correct event.
    - Semantics labels are present.
    - Events are ordered chronologically.

- [x] Task 11: Mobile - Widget tests for EventOutfitBottomSheet (AC: 3, 6, 8, 12)
  - [x] 11.1: Create `apps/mobile/test/features/home/widgets/event_outfit_bottom_sheet_test.dart`:
    - Renders event details (title, time, location, type, formality).
    - Shows loading shimmer initially.
    - Displays OutfitSuggestionCards on successful generation.
    - Shows error state with retry button on generation failure.
    - Retry button re-triggers generation.
    - Shows "User override" indicator for user-classified events.
    - Semantics labels are present.

- [x] Task 12: Mobile - Widget tests for HomeScreen events integration (AC: 1, 3, 7, 9, 12)
  - [x] 12.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When calendar is connected and events exist, EventsSection is displayed (not EventSummaryWidget).
    - When calendar is connected but no events, EventsSection empty state shows.
    - When calendar is not connected, CalendarPermissionCard shows (no EventsSection).
    - Tapping an event in EventsSection opens EventOutfitBottomSheet.
    - EventsSection appears above the daily outfit suggestion card.
    - All existing HomeScreen tests continue to pass.

- [x] Task 13: Regression testing (AC: all)
  - [x] 13.1: Run `flutter analyze` -- zero issues.
  - [x] 13.2: Run `flutter test` -- all existing 1585+ Flutter tests plus new tests pass.
  - [x] 13.3: Run `npm --prefix apps/api test` -- all existing 1175+ API tests plus new tests pass.
  - [x] 13.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast, dressing tip, calendar permission card, daily outfit generation, event override bottom sheet, cache-first loading, pull-to-refresh, staleness indicator.
  - [x] 13.5: Verify the events section renders correctly and does not interfere with existing layout elements.

## Dev Notes

- This is the FIRST story in Epic 12 (Calendar Integration & Outfit Planning). It builds on the calendar infrastructure from Epic 3 (Stories 3.4-3.6) and the outfit generation infrastructure from Epic 4 (Story 4.1).
- The primary FRs covered are FR-EVT-01 (Home screen displays upcoming events with classified type and formality) and FR-EVT-02 (event-specific outfit suggestions considering formality, time of day, and weather).
- **FR-EVT-03 through FR-EVT-08 are OUT OF SCOPE.** They are covered in Stories 12.2-12.3 (outfit scheduling, formal event reminders).
- **FR-TRV-01 through FR-TRV-05 are OUT OF SCOPE.** They are covered in Story 12.4 (travel mode packing).
- **This story does NOT change the daily outfit generation logic from Story 4.1.** The daily generation already considers calendar events via OutfitContext.calendarEvents. This story adds a NEW endpoint for event-SPECIFIC generation when the user taps an individual event.
- **The existing EventSummaryWidget from Story 3.5 is REPLACED** by the richer EventsSection widget. The EventSummaryWidget showed a single upcoming event; EventsSection shows up to 3 events with richer metadata and tappable cards.
- **The existing EventDetailBottomSheet from Story 3.6 is NOT removed.** It still provides the classification override UI. The new EventOutfitBottomSheet is a SEPARATE widget for viewing event-specific outfit suggestions. Both can coexist -- EventsSection event cards open EventOutfitBottomSheet on the main tap area, with a smaller "edit classification" affordance that opens EventDetailBottomSheet.

### Project Structure Notes

- New API files:
  - None (method added to existing `outfit-generation-service.js`)
- New mobile files:
  - `apps/mobile/lib/src/features/home/widgets/events_section.dart` (EventsSection)
  - `apps/mobile/lib/src/features/home/widgets/event_outfit_bottom_sheet.dart` (EventOutfitBottomSheet)
  - `apps/mobile/test/features/home/widgets/events_section_test.dart`
  - `apps/mobile/test/features/home/widgets/event_outfit_bottom_sheet_test.dart`
- Modified API files:
  - `apps/api/src/modules/outfits/outfit-generation-service.js` (add `generateOutfitsForEvent` method, extract shared validation helper)
  - `apps/api/src/main.js` (add `POST /v1/outfits/generate-for-event` route)
  - `apps/api/test/modules/outfits/outfit-generation-service.test.js` (add event-specific tests)
  - `apps/api/test/modules/outfits/outfit-generation.test.js` (add event endpoint integration tests)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `generateOutfitsForEvent` method)
  - `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart` (add `generateOutfitsForEvent` method)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (replace EventSummaryWidget with EventsSection, add `_handleEventOutfitTap`)
  - `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart` (add event generation tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add events section and bottom sheet integration tests)

### Technical Requirements

- **New API endpoint:** `POST /v1/outfits/generate-for-event` -- accepts `{ outfitContext: {...}, event: { title, eventType, formalityScore, startTime, endTime, location } }`, returns `{ suggestions: [...], generatedAt: "..." }`. Requires authentication.
- **Gemini 2.0 Flash** for event-specific generation. Same model as daily generation (`gemini-2.0-flash`), JSON mode (`responseMimeType: "application/json"`).
- **AI usage logging:** Feature name = `"event_outfit_generation"` (distinct from `"outfit_generation"` for daily). Log to `ai_usage_log` with same fields.
- **No new database tables or migrations.** This story reuses `calendar_events` (Story 3.5) and `outfits`/`outfit_items` (Story 4.1). Event-specific suggestions are ephemeral (not persisted) -- same pattern as daily generation in Story 4.1.
- **No usage limit enforcement in this story.** Usage limits for event-specific generation will follow the same gating as daily generation (Story 4.5's enforcement). If limits are already enforced on `generateOutfits`, the same limits should apply to `generateOutfitsForEvent`.

### Architecture Compliance

- **AI calls are brokered only by Cloud Run:** The mobile client sends context + event to the API; the API calls Gemini. The mobile client NEVER calls Gemini directly.
- **Server authority for item data:** The API fetches items from Cloud SQL. The client sends only context + event metadata.
- **Mobile boundary owns presentation:** EventsSection, EventOutfitBottomSheet, and all UI state are client-side.
- **Graceful AI degradation:** If Gemini fails, the bottom sheet shows an error with retry. The app does not crash.
- **Epic 12 component mapping:** `mobile/features/outfits`, `mobile/features/home`, `api/modules/outfits`, `api/modules/calendar` -- matches the architecture's epic-to-component mapping for Epic 12.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `http`, `cached_network_image`, Material widgets (`showModalBottomSheet`, `ChoiceChip`, etc.).
- No new API dependencies. Uses existing `@google-cloud/vertexai` via shared `geminiClient`.

### File Structure Requirements

- New widgets in `apps/mobile/lib/src/features/home/widgets/` -- follows existing pattern.
- No new API module directories. The event generation method lives in the existing `modules/outfits/outfit-generation-service.js`.
- Test files mirror source structure.

### Testing Requirements

- API unit tests must verify:
  - Event-specific Gemini prompt includes event title, type, formality, time
  - Response validation reuses the same logic as daily generation
  - AI usage logged with "event_outfit_generation" feature name
  - Input validation rejects missing event data
- API integration tests must verify:
  - POST /v1/outfits/generate-for-event requires auth, returns correct structure, handles errors
- Mobile unit tests must verify:
  - OutfitGenerationService.generateOutfitsForEvent calls API correctly, handles errors
- Mobile widget tests must verify:
  - EventsSection renders events correctly, handles empty state, triggers callbacks
  - EventOutfitBottomSheet renders event details, shows loading/success/error states
  - HomeScreen integration: EventsSection replaces EventSummaryWidget, tap opens bottom sheet
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 1585+ plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1175+ plus new tests pass)

### Previous Story Intelligence

- **Story 11.4 (last completed story)** ended with 1175 API tests and 1585 Flutter tests. All must continue to pass.
- **Story 3.5** established: `calendar_events` table, CalendarEvent + CalendarEventContext models, CalendarEventService, EventSummaryWidget (being replaced by EventsSection), `POST /v1/calendar/events/sync` and `GET /v1/calendar/events` endpoints. The `_iconForType` helper mapping in EventSummaryWidget maps event types to icons: `work -> Icons.work`, `social -> Icons.people`, `active -> Icons.fitness_center`, `formal -> Icons.star`, `casual -> Icons.event`.
- **Story 3.6** established: EventDetailBottomSheet for classification override, PATCH /v1/calendar/events/:id, CalendarEvent.copyWith, `onEventTap` callback on EventSummaryWidget, `_handleEventTap` in HomeScreen. This override capability must be preserved alongside the new EventOutfitBottomSheet.
- **Story 4.1** established: outfit-generation-service.js with `generateOutfits` (Gemini prompt, response validation, AI usage logging), `POST /v1/outfits/generate` endpoint, OutfitSuggestion/OutfitSuggestionItem/OutfitGenerationResult models, OutfitGenerationService on mobile, OutfitSuggestionCard widget, OutfitMinimumItemsCard widget, HomeScreen integration with `_outfitResult`, `_isGeneratingOutfit`, `_outfitError`, `_wardrobeItems`.
- **Story 4.1 key pattern:** The `parseAndValidateSuggestions` logic validates item IDs against the user's wardrobe, enriches with full item data, and assigns `crypto.randomUUID()`. This MUST be reused for event-specific generation.
- **HomeScreen constructor parameters (as of Story 11.4):** The HomeScreen has accumulated many DI parameters across epics. The existing ones relevant to this story: `calendarService`, `calendarPreferencesService`, `calendarEventService`, `outfitGenerationService`. No new constructor parameters are needed for this story since `outfitGenerationService` is already injected.
- **HomeScreen build order (as of latest):** weather section -> forecast -> dressing tip -> [calendar prompt card OR event summary] -> daily outfit suggestion card (or minimum items card or loading shimmer). This story changes the event summary area to use EventsSection.
- **Key learning from Story 3.6:** When testing bottom sheets in HomeScreen, the `showModalBottomSheet` requires `isScrollControlled: true`. The `Navigator.pop(context)` call closes the sheet. Mock the CalendarEventService and OutfitGenerationService for isolated widget tests.
- **Key learning from Story 4.1:** The Gemini JSON mode (`responseMimeType: "application/json"`) is critical for parseable responses. The `estimateCost` function in categorization-service.js is reused for cost estimation.

### Key Anti-Patterns to Avoid

- DO NOT duplicate the Gemini response validation logic. Extract a shared helper from the existing `generateOutfits` method or call the same internal function.
- DO NOT create a new API module directory for event generation. It belongs in the existing `modules/outfits/outfit-generation-service.js`.
- DO NOT change the daily outfit generation prompt or logic. The daily generation already considers calendar events. This story adds a SEPARATE endpoint for event-specific generation.
- DO NOT remove the EventDetailBottomSheet (Story 3.6's classification override). It must remain accessible.
- DO NOT remove the EventSummaryWidget file. While the HomeScreen no longer uses it directly (replaced by EventsSection), other screens might reference it. If no other references exist, it can be deprecated but should not be deleted in this story.
- DO NOT persist event-specific outfit suggestions to the database. They are ephemeral, same as daily suggestions in Story 4.1.
- DO NOT enforce usage limits in this story. Usage limit enforcement is handled by Story 4.5's infrastructure. If `generateOutfits` already checks limits, `generateOutfitsForEvent` should reuse the same mechanism.
- DO NOT call Gemini from the mobile client. All AI calls go through Cloud Run.
- DO NOT block the bottom sheet UI on generation. Show loading state (shimmer) while generating, display results when ready.
- DO NOT create a separate model for event outfit suggestions. Reuse `OutfitSuggestion`, `OutfitSuggestionItem`, and `OutfitGenerationResult` from Story 4.1.

### Implementation Guidance

- **Extracting shared validation:** In `outfit-generation-service.js`, the `generateOutfits` method currently has inline prompt construction, Gemini call, response parsing, validation, and enrichment. For `generateOutfitsForEvent`, extract the following into shared internal functions: `_buildItemInventory(items)`, `_parseAndValidateResponse(response, validItemIds, itemsMap)`, `_logAiUsage(authContext, { feature, usageMetadata, latencyMs, status, errorMessage })`. Both `generateOutfits` and `generateOutfitsForEvent` call these shared functions with different prompts.

- **EventsSection icon/color mapping:** Extract the event type icon mapping from EventSummaryWidget into a shared utility (e.g., `apps/mobile/lib/src/core/calendar/event_type_utils.dart`) with: `IconData iconForEventType(String type)` and optionally `Color colorForEventType(String type)`. Both EventsSection and EventSummaryWidget can import from this utility.

- **Bottom sheet height:** The EventOutfitBottomSheet should use a `DraggableScrollableSheet` inside `showModalBottomSheet(isScrollControlled: true)` with `initialChildSize: 0.7`, `minChildSize: 0.5`, `maxChildSize: 0.95` so the user can drag it taller when viewing multiple suggestions.

### References

- [Source: epics.md - Story 12.1: Event Display & Suggestions]
- [Source: epics.md - Epic 12: Calendar Integration & Outfit Planning]
- [Source: functional-requirements.md - FR-EVT-01: The Home screen shall display upcoming events with classified type and formality]
- [Source: functional-requirements.md - FR-EVT-02: The system shall generate event-specific outfit suggestions considering formality, time of day, and weather]
- [Source: architecture.md - AI Orchestration: outfit generation, Gemini 2.0 Flash]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Epic 12 Calendar Planning & Travel -> mobile/features/outfits, api/modules/calendar, api/modules/notifications]
- [Source: ux-design-specification.md - Passive Context Gathering: Weather and calendar data are pulled automatically]
- [Source: ux-design-specification.md - Contextual Deep Dives (Bottom Sheets)]
- [Source: prd.md - Calendar access: Optional -- for event-based outfit suggestions]
- [Source: 3-5-calendar-event-fetching-classification.md - CalendarEvent model, EventSummaryWidget, GET /v1/calendar/events endpoint]
- [Source: 3-6-manual-event-classification-override.md - EventDetailBottomSheet, PATCH endpoint, onEventTap, _handleEventTap]
- [Source: 4-1-daily-ai-outfit-generation.md - outfit-generation-service.js, Gemini prompt, OutfitSuggestion model, OutfitSuggestionCard]
- [Source: apps/api/src/modules/outfits/outfit-generation-service.js - generateOutfits pattern, parseAndValidate, estimateCost]
- [Source: apps/mobile/lib/src/features/home/widgets/event_summary_widget.dart - EventSummaryWidget, _iconForType mapping]
- [Source: apps/mobile/lib/src/features/home/widgets/event_detail_bottom_sheet.dart - EventDetailBottomSheet for classification override]
- [Source: apps/mobile/lib/src/features/home/widgets/outfit_suggestion_card.dart - OutfitSuggestionCard widget]
- [Source: apps/mobile/lib/src/features/outfits/models/outfit_suggestion.dart - OutfitSuggestion, OutfitSuggestionItem, OutfitGenerationResult]
- [Source: apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart - OutfitGenerationService]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug issues encountered.

### Completion Notes List

- Task 1: Added `generateOutfitsForEvent` method to outfit-generation-service.js with event-specific Gemini prompt (`buildEventPrompt`), input validation, and AI usage logging with `feature: "event_outfit_generation"`. Reuses existing `validateAndEnrichResponse` for response validation (no duplication).
- Task 2: Added `POST /v1/outfits/generate-for-event` route to main.js with auth, request body validation (event required fields), and error mapping.
- Task 3: Created EventsSection widget replacing EventSummaryWidget on HomeScreen. Displays up to 3 events chronologically with type icons, formality badges, type chips, and edit classification affordance.
- Task 4: Created EventOutfitBottomSheet widget with DraggableScrollableSheet, auto-triggering event outfit generation, loading/success/error states, and reuse of OutfitSuggestionCard.
- Task 5: Added `generateOutfitsForEvent` to both ApiClient (HTTP call) and OutfitGenerationService (serialization + error handling).
- Task 6: Integrated EventsSection into HomeScreen replacing EventSummaryWidget. Added `_handleEventOutfitTap` for opening outfit bottom sheet. Preserved edit classification via `onEditClassification` callback using existing `_handleEventTap`.
- Tasks 7-8: Added 11 API unit tests and 6 API integration tests for event-specific generation.
- Tasks 9-12: Added 4 OutfitGenerationService tests, 7 EventsSection tests, 7 EventOutfitBottomSheet tests, 4 HomeScreen integration tests. Updated 6 existing HomeScreen tests for EventsSection compatibility.
- Task 13: All regression tests pass. 1192 API tests (1175+17), 1607 Flutter tests (1585+22). Flutter analyze: 15 pre-existing warnings, zero errors.

### Change Log

- 2026-03-19: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirements (FR-EVT-01, FR-EVT-02), UX design specification, and Stories 3.4-3.6 + 4.1 implementation context.
- 2026-03-19: Story implemented by Dev Agent (Claude Opus 4.6). Added event-specific outfit generation API endpoint, EventsSection widget, EventOutfitBottomSheet widget, mobile service methods, and comprehensive tests.

### File List

**New files:**
- `apps/mobile/lib/src/features/home/widgets/events_section.dart`
- `apps/mobile/lib/src/features/home/widgets/event_outfit_bottom_sheet.dart`
- `apps/mobile/test/features/home/widgets/events_section_test.dart`
- `apps/mobile/test/features/home/widgets/event_outfit_bottom_sheet_test.dart`

**Modified files:**
- `apps/api/src/modules/outfits/outfit-generation-service.js` (added `generateOutfitsForEvent`, `buildEventPrompt`, exported `buildEventPrompt`)
- `apps/api/src/main.js` (added `POST /v1/outfits/generate-for-event` route)
- `apps/mobile/lib/src/core/networking/api_client.dart` (added `generateOutfitsForEvent` method)
- `apps/mobile/lib/src/features/outfits/services/outfit_generation_service.dart` (added `generateOutfitsForEvent` method, CalendarEvent import)
- `apps/mobile/lib/src/features/home/screens/home_screen.dart` (replaced EventSummaryWidget with EventsSection, added `_handleEventOutfitTap`, added imports)
- `apps/api/test/modules/outfits/outfit-generation-service.test.js` (added 11 event-specific tests)
- `apps/api/test/modules/outfits/outfit-generation.test.js` (added 6 event endpoint integration tests)
- `apps/mobile/test/features/outfits/services/outfit_generation_service_test.dart` (added 4 event generation tests)
- `apps/mobile/test/features/home/screens/home_screen_test.dart` (updated 6 existing tests for EventsSection, added 4 new integration tests)
