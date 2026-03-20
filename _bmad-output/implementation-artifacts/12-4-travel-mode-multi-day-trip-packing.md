# Story 12.4: Travel Mode: Multi-Day Trip Packing

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Traveler,
I want the app to detect my upcoming trips and generate a smart packing list,
so that I only pack what I need and avoid overpacking.

## Acceptance Criteria

1. Given my calendar sync has events detected as multi-day (spanning 2+ days OR multiple events in a different location within a 7-day window), when the trip is 3 or fewer days away, then a "Travel Mode" banner appears at the top of the Home screen (below weather, above events section) showing the trip destination, dates, and a "View Packing List" CTA. The banner is dismissible per-trip. (FR-TRV-01, FR-TRV-05)

2. Given the system needs to detect multi-day trips from calendar events, when calendar events are loaded on Home screen, then the API endpoint `POST /v1/calendar/trips/detect` analyzes upcoming events (next 14 days) and identifies trips using the following heuristics: (a) a single event spanning 2+ calendar days (allDay events with duration >= 2 days), (b) a cluster of events in the same non-local location within a 7-day window, (c) events whose title or description contain travel keywords (flight, hotel, airbnb, conference, vacation, trip, travel, check-in, checkout). The response returns detected trips with: estimated destination, startDate, endDate, duration in days, associated event IDs, and destination coordinates (geocoded from event location strings via Open-Meteo geocoding API). (FR-TRV-01)

3. Given a trip is detected and I tap "View Packing List" on the banner (or navigate via the trip detail), when the packing list screen opens, then it calls `POST /v1/calendar/trips/:tripId/packing-list` which generates a smart packing list via Gemini based on: trip duration (number of days), destination weather forecast (fetched server-side via Open-Meteo for destination coordinates), planned events during the trip (types, formality scores), and my wardrobe inventory (categorized items only). The list is grouped by category (Tops, Bottoms, Outerwear, Shoes, Accessories, Essentials) with specific item recommendations from my wardrobe. (FR-TRV-02)

4. Given the packing list is generated, when I view it on the PackingListScreen, then each item shows: item name, thumbnail (from my wardrobe), category, and a checkbox to mark as packed. The packed/unpacked state is persisted locally via SharedPreferences (keyed by trip ID). A progress indicator at the top shows "X of Y items packed". Items are grouped by category with collapsible section headers. (FR-TRV-03)

5. Given I have a packing list displayed, when I tap the "Export" button in the app bar, then the list is formatted as a plain-text checklist and shared via the system share sheet (`share_plus`). The exported text includes: trip name, dates, destination, and all items grouped by category with checkboxes (using Unicode ballot box characters). (FR-TRV-04)

6. Given the packing list generation uses AI, when the API call completes, then the AI usage is logged to `ai_usage_log` with `feature = "packing_list_generation"` (distinct from other AI features). (NFR-OBS-02)

7. Given a trip is detected but the destination weather cannot be fetched (geocoding fails or Open-Meteo is unavailable), when the packing list is generated, then the system generates a weather-agnostic packing list based on trip duration, event formality, and general seasonal context (derived from the current date). The list includes a note: "Weather data unavailable for destination. Pack for variable conditions." (FR-TRV-02)

8. Given I have no calendar connected or no upcoming trips detected, when the Home screen loads, then no Travel Mode banner appears. The Home screen layout is unchanged. (FR-TRV-05)

9. Given a trip has already been detected and I dismissed the banner, when the Home screen reloads, then the banner does not reappear for that trip (dismissed state persisted in SharedPreferences keyed by trip hash of destination+dates). The banner reappears only if trip dates change or a new trip is detected. (FR-TRV-05)

10. Given the trip detection finds a destination location string, when the API processes it, then it geocodes the location using the Open-Meteo geocoding API (`https://geocoding-api.open-meteo.com/v1/search?name={location}&count=1`) to obtain latitude/longitude. If geocoding fails, the trip is still returned but without coordinates (weather will be unavailable). (FR-TRV-01, FR-TRV-02)

11. Given a packing list has been generated for a trip, when I revisit the PackingListScreen for the same trip, then the previously generated list is loaded from local cache (SharedPreferences) without re-calling the API. A "Regenerate" button allows refreshing the list from the API. Regenerating resets all packed checkmarks. (FR-TRV-02, FR-TRV-03)

12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1233 API tests, 1671 Flutter tests from Story 12.3) and new tests cover: trip detection API endpoint (auth, success, no trips, heuristics), packing list generation API endpoint (auth, success, failure, weather fallback), Gemini prompt with trip context, geocoding integration, TravelBanner widget (visible, dismissed, no trips), PackingListScreen (categories, checkboxes, progress, export), trip detection service on mobile, packing list caching, and regression on existing Home screen functionality.

## Tasks / Subtasks

- [x] Task 1: API - Create trip detection service (AC: 2, 10)
  - [x]1.1: Create `apps/api/src/modules/calendar/trip-detection-service.js`. Export `createTripDetectionService({ calendarEventRepo, pool })`. Factory function following the existing service pattern.
  - [x]1.2: Implement `async detectTrips(authContext, { lookaheadDays = 14 })` method that:
    (a) Fetches calendar events for the next `lookaheadDays` via `calendarEventRepo.getEventsForDateRange(authContext, { startDate: today, endDate: today+lookaheadDays })`.
    (b) Applies trip detection heuristics in order:
      - **Multi-day events:** Find events where `endTime - startTime >= 2 days` (or `allDay === true` and spans 2+ calendar dates). These are individual trip candidates.
      - **Location clusters:** Group events by normalized location (lowercase, trimmed). If 2+ events share the same non-empty location within a 7-day window, and that location differs from the user's home location (inferred as the most frequent event location), treat as a trip to that location.
      - **Keyword detection:** Scan event titles and descriptions for travel keywords: `flight`, `hotel`, `airbnb`, `conference`, `vacation`, `trip`, `travel`, `check-in`, `checkout`, `boarding`. Events matching keywords are trip candidates; cluster them by date proximity (within 3 days).
    (c) Merge overlapping trip candidates by date range.
    (d) For each detected trip, return: `{ id: hash(destination+startDate+endDate), destination: string, startDate: string, endDate: string, durationDays: number, eventIds: string[], destinationCoordinates: { latitude, longitude } | null }`.
  - [x]1.3: Implement `async geocodeLocation(locationString)` helper method. Calls `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(locationString)}&count=1&language=en`. Parses the first result's `latitude` and `longitude`. Returns `null` on failure (network error, no results, non-200). Uses native `fetch` (Node 18+). Timeout: 5 seconds.
  - [x]1.4: Implement `async fetchDestinationWeather(latitude, longitude, startDate, endDate)` helper. Calls Open-Meteo forecast API: `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max,temperature_2m_min,weather_code&start_date=${startDate}&end_date=${endDate}&timezone=auto`. Returns array of daily forecasts `[{ date, highTemp, lowTemp, weatherCode }]`. Returns `null` on failure.

- [x] Task 2: API - Create packing list generation service (AC: 3, 6, 7)
  - [x]2.1: In `apps/api/src/modules/outfits/outfit-generation-service.js`, add `async generatePackingList(authContext, { trip, destinationWeather, events, items })` method. Constructs a Gemini prompt:
    ```
    You are a personal stylist AI. Generate a smart packing list for an upcoming trip.

    TRIP:
    - Destination: {trip.destination}
    - Duration: {trip.durationDays} days ({trip.startDate} to {trip.endDate})

    DESTINATION WEATHER (daily forecast):
    {destinationWeather as JSON array, or "Weather data unavailable - pack for variable conditions based on season: {currentSeason}"}

    PLANNED EVENTS DURING TRIP:
    {events as JSON array with title, eventType, formalityScore, date}

    WARDROBE ITEMS (select from these ONLY - use exact item IDs):
    {items as JSON array with id, name, category, subCategory, color, material, brand}

    RULES:
    1. Select items from the wardrobe list above. Use ONLY item IDs that exist in the list.
    2. Pack enough for {trip.durationDays} days. Aim for versatile items that mix and match.
    3. Account for ALL planned events - ensure appropriate formality for each.
    4. Consider weather: if cold, include outerwear and warm layers. If rain expected, include waterproof items.
    5. Minimize quantity: suggest outfit combinations that reuse items across days.
    6. Group items by category: Tops, Bottoms, Outerwear, Shoes, Accessories, Essentials.
    7. For "Essentials" category: suggest general travel essentials (toiletries bag, charger, etc.) as text-only items (no wardrobe ID).
    8. For each wardrobe item, explain briefly why it's included.
    9. Suggest day-by-day outfit combinations using the packed items.

    Return ONLY valid JSON:
    {
      "packingList": {
        "categories": [
          {
            "name": "Tops",
            "items": [
              { "itemId": "uuid-or-null", "name": "Item name", "reason": "Why packed" }
            ]
          }
        ],
        "dailyOutfits": [
          { "day": 1, "date": "YYYY-MM-DD", "outfitItemIds": ["uuid-1", "uuid-2"], "occasion": "description" }
        ],
        "tips": ["General packing tip 1", "Tip 2"]
      }
    }
    ```
  - [x]2.2: Parse and validate the Gemini response: ensure categories exist, validate item IDs against the wardrobe (reuse `validateAndEnrichResponse` pattern for item ID validation), handle missing/invalid fields gracefully. Enrich wardrobe items with thumbnail URLs and full metadata.
  - [x]2.3: Log AI usage to `ai_usage_log` with `feature: "packing_list_generation"`.
  - [x]2.4: On Gemini failure, return a fallback packing list based on trip duration and event types: generic category-based quantities (e.g., "Tops: durationDays + 1", "Bottoms: ceil(durationDays/2)") without specific wardrobe item recommendations. Include a `fallback: true` flag in the response.

- [x] Task 3: API - Add trip detection and packing list endpoints (AC: 2, 3, 10)
  - [x]3.1: In `apps/api/src/main.js`, instantiate `tripDetectionService` from `createTripDetectionService({ calendarEventRepo, pool })`.
  - [x]3.2: Add `POST /v1/calendar/trips/detect` -- requires auth. Reads optional `{ lookaheadDays?: number }` from body (default 14, max 30). Calls `tripDetectionService.detectTrips(authContext, { lookaheadDays })`. Returns 200 with `{ trips: [...] }`. Returns empty array if no trips detected.
  - [x]3.3: Add `POST /v1/calendar/trips/:tripId/packing-list` -- requires auth. Reads `{ trip: { destination, startDate, endDate, durationDays, eventIds, destinationCoordinates }, regenerate?: boolean }` from body. Steps: (a) If `destinationCoordinates` exists, fetch destination weather via `tripDetectionService.fetchDestinationWeather(...)`. (b) Fetch events for trip date range. (c) Fetch user's categorized wardrobe items. (d) Call `outfitGenerationService.generatePackingList(authContext, { trip, destinationWeather, events, items })`. (e) Return 200 with `{ packingList: {...}, generatedAt: "..." }`.
  - [x]3.4: Handle errors: 400 for missing trip data, 401 for unauthenticated, 503 for AI unavailable, 500 for generation failure.

- [x] Task 4: Mobile - Create Trip model and TripDetectionService (AC: 1, 2)
  - [x]4.1: Create `apps/mobile/lib/src/features/outfits/models/trip.dart`. Model `Trip` with fields: `id` (String), `destination` (String), `startDate` (DateTime), `endDate` (DateTime), `durationDays` (int), `eventIds` (List<String>), `destinationLatitude` (double?), `destinationLongitude` (double?). Include `fromJson`/`toJson`.
  - [x]4.2: Create `apps/mobile/lib/src/features/outfits/services/trip_detection_service.dart`. Constructor takes `ApiClient`. Method: `Future<List<Trip>> detectTrips({ int lookaheadDays = 14 })`. Calls `POST /v1/calendar/trips/detect`, parses response into `List<Trip>`. Returns empty list on error.
  - [x]4.3: Add API client method: `Future<Map<String, dynamic>> detectTrips(Map<String, dynamic> body)` calling `authenticatedPost("/v1/calendar/trips/detect", body: body)`.

- [x] Task 5: Mobile - Create PackingList model and PackingListService (AC: 3, 4, 11)
  - [x]5.1: Create `apps/mobile/lib/src/features/outfits/models/packing_list.dart`. Models:
    - `PackingListCategory` with: `name` (String), `items` (List<PackingListItem>).
    - `PackingListItem` with: `itemId` (String?), `name` (String), `reason` (String), `thumbnailUrl` (String?), `category` (String?), `color` (String?), `isPacked` (bool, default false).
    - `DailyOutfit` with: `day` (int), `date` (DateTime), `outfitItemIds` (List<String>), `occasion` (String).
    - `PackingList` with: `categories` (List<PackingListCategory>), `dailyOutfits` (List<DailyOutfit>), `tips` (List<String>), `fallback` (bool), `generatedAt` (DateTime).
    Include `fromJson`/`toJson` for all models.
  - [x]5.2: Create `apps/mobile/lib/src/features/outfits/services/packing_list_service.dart`. Constructor takes `ApiClient`. Methods:
    - `Future<PackingList?> generatePackingList(Trip trip)` -- calls `POST /v1/calendar/trips/:tripId/packing-list` with trip data. Returns parsed `PackingList` or `null` on error.
    - `Future<PackingList?> getCachedPackingList(String tripId)` -- reads from SharedPreferences key `packing_list_{tripId}`.
    - `Future<void> cachePackingList(String tripId, PackingList list)` -- writes to SharedPreferences as JSON.
    - `Future<Map<String, bool>> getPackedStatus(String tripId)` -- reads packed checkmark state from SharedPreferences key `packed_status_{tripId}`.
    - `Future<void> updatePackedStatus(String tripId, String itemId, bool packed)` -- updates packed state in SharedPreferences.
    - `Future<void> clearPackedStatus(String tripId)` -- clears packed state (used on regenerate).
  - [x]5.3: Add API client method: `Future<Map<String, dynamic>> generatePackingList(String tripId, Map<String, dynamic> body)` calling `authenticatedPost("/v1/calendar/trips/$tripId/packing-list", body: body)`.

- [x] Task 6: Mobile - Create TravelBanner widget (AC: 1, 8, 9)
  - [x]6.1: Create `apps/mobile/lib/src/features/home/widgets/travel_banner.dart` with a `TravelBanner` StatelessWidget. Constructor accepts: `Trip trip`, `VoidCallback? onViewPackingList`, `VoidCallback? onDismiss`.
  - [x]6.2: Banner design: gradient background (`#4F46E5` to `#7C3AED`), white text, 16px padding, 12px border radius. Shows:
    - Icon: `Icons.luggage` (24px, white).
    - Title: "Trip to {trip.destination}" (16px, white, bold). If no destination, "Upcoming Trip".
    - Subtitle: "{trip.startDate formatted} - {trip.endDate formatted} ({trip.durationDays} days)" (13px, white70).
    - "View Packing List" button: white text on semi-transparent white background, 12px border radius.
    - Dismiss "X" icon button in top-right corner.
  - [x]6.3: Add `Semantics` labels: "Travel mode banner for trip to {destination}", "View packing list button", "Dismiss travel banner".

- [x] Task 7: Mobile - Create PackingListScreen (AC: 3, 4, 5, 7, 11)
  - [x]7.1: Create `apps/mobile/lib/src/features/outfits/screens/packing_list_screen.dart`. StatefulWidget. Constructor accepts: `Trip trip`, `PackingListService packingListService`.
  - [x]7.2: On `initState`, attempt to load cached packing list via `packingListService.getCachedPackingList(trip.id)`. If cached list exists, display it with saved packed status. If no cache, call `packingListService.generatePackingList(trip)` and cache the result.
  - [x]7.3: Display structure:
    - AppBar: title "Packing List", subtitle "{trip.destination} ({trip.durationDays} days)", actions: Export button (`Icons.share`), Regenerate button (`Icons.refresh`).
    - Below AppBar: progress indicator bar showing packed/total count. Text: "X of Y items packed". Linear progress bar with `#4F46E5` fill.
    - Body: `ListView` with expandable category sections. Each section header shows category name, item count, and expand/collapse chevron. Each item row shows: checkbox (left), item thumbnail (32px circle, `CachedNetworkImage` if wardrobe item, category icon if essential), item name (15px, #111827), reason subtitle (12px, #6B7280). Checked items show strikethrough on name.
    - If `fallback: true` in response, show an info banner at the top: "AI-generated list unavailable. Showing general recommendations based on trip duration." (14px, #92400E on #FEF3C7 background).
    - If weather was unavailable, show a note: "Weather data unavailable for destination. Pack for variable conditions." (13px, #6B7280).
  - [x]7.4: Below the packing checklist, show a "Day-by-Day Outfits" section (collapsible). Each day shows: "Day X - {date}" header, list of item names for that day's suggested outfit, and the occasion tag.
  - [x]7.5: Below daily outfits, show a "Tips" section with bullet-pointed packing tips from the AI response.
  - [x]7.6: Checkbox taps call `packingListService.updatePackedStatus(trip.id, itemId, packed)` and update the progress indicator in real-time.
  - [x]7.7: "Regenerate" button shows a confirmation dialog ("This will regenerate the list and reset all packed items. Continue?"). On confirm, calls `packingListService.clearPackedStatus(trip.id)`, then `packingListService.generatePackingList(trip)`, caches the new result, and refreshes the UI.
  - [x]7.8: "Export" button formats the list as plain text and calls `Share.share(text)` from `share_plus`:
    ```
    Packing List: Trip to {destination}
    {startDate} - {endDate} ({durationDays} days)

    TOPS
    [ ] Item name 1
    [x] Item name 2 (packed)

    BOTTOMS
    [ ] Item name 3
    ...

    DAY-BY-DAY OUTFITS
    Day 1 ({date}): Item 1, Item 2, Item 3 - {occasion}
    ...

    TIPS
    - Tip 1
    - Tip 2

    Generated by Vestiaire
    ```
  - [x]7.9: Loading state: show shimmer placeholders for 4 category sections with 3 items each. Error state: show error message with "Try Again" button.
  - [x]7.10: Add `Semantics` labels: "Packing list for trip to {destination}", "X of Y items packed", "Mark {item name} as packed/unpacked", "Export packing list", "Regenerate packing list".

- [x] Task 8: Mobile - Integrate TravelBanner and trip detection into HomeScreen (AC: 1, 8, 9)
  - [x]8.1: Add optional constructor parameters to HomeScreen: `TripDetectionService? tripDetectionService`, `PackingListService? packingListService`.
  - [x]8.2: In HomeScreen state, add: `Trip? _detectedTrip`, `bool _tripBannerDismissed = false`. After calendar events are loaded (in `_fetchCalendarEvents()` or equivalent), if `tripDetectionService` is not null, call `tripDetectionService.detectTrips()`. If trips returned, set `_detectedTrip` to the first trip approaching within 3 days (or the soonest trip if none within 3 days but within lookahead).
  - [x]8.3: Check SharedPreferences for dismissed state: key `trip_dismissed_{trip.id}`. If dismissed, set `_tripBannerDismissed = true`.
  - [x]8.4: In the `build` method, insert `TravelBanner` in the layout: after weather/forecast/dressing tip section, BEFORE the calendar prompt or events section. Only show if `_detectedTrip != null && !_tripBannerDismissed`.
  - [x]8.5: Wire `onViewPackingList` to navigate to `PackingListScreen` via `Navigator.push`, passing the trip and `packingListService`.
  - [x]8.6: Wire `onDismiss` to persist dismissed state to SharedPreferences and call `setState` to hide the banner.

- [x] Task 9: Mobile - Wire services in app.dart and MainShellScreen (AC: 1)
  - [x]9.1: In `apps/mobile/lib/src/app.dart`, create `TripDetectionService` and `PackingListService` instances (from `apiClient`). Pass to HomeScreen.
  - [x]9.2: No changes to MainShellScreen needed (trip detection is HomeScreen-scoped).

- [x] Task 10: API - Unit tests for trip detection service (AC: 2, 10, 12)
  - [x]10.1: Create `apps/api/test/modules/calendar/trip-detection-service.test.js`:
    - `detectTrips` detects multi-day allDay events as trips.
    - `detectTrips` detects location clusters as trips.
    - `detectTrips` detects keyword-based trips (flight, hotel, conference).
    - `detectTrips` merges overlapping trip candidates.
    - `detectTrips` returns empty array when no trips found.
    - `detectTrips` ignores events in the past.
    - `detectTrips` respects lookaheadDays parameter.
    - `geocodeLocation` returns coordinates for valid location.
    - `geocodeLocation` returns null on API failure.
    - `geocodeLocation` returns null for empty/null location.
    - `fetchDestinationWeather` returns daily forecasts.
    - `fetchDestinationWeather` returns null on API failure.

- [x] Task 11: API - Unit tests for packing list generation (AC: 3, 6, 7, 12)
  - [x]11.1: Add tests to `apps/api/test/modules/outfits/outfit-generation-service.test.js`:
    - `generatePackingList` calls Gemini with trip context, weather, events, and wardrobe items.
    - `generatePackingList` returns validated packing list with enriched item data.
    - `generatePackingList` logs AI usage with feature "packing_list_generation".
    - `generatePackingList` returns fallback list when Gemini fails.
    - `generatePackingList` handles missing destination weather gracefully.
    - `generatePackingList` validates item IDs against wardrobe.
    - `generatePackingList` throws error when no categorized items available.

- [x] Task 12: API - Integration tests for trip endpoints (AC: 2, 3, 12)
  - [x]12.1: Create `apps/api/test/modules/calendar/trip-detection.test.js`:
    - `POST /v1/calendar/trips/detect` requires authentication (401).
    - `POST /v1/calendar/trips/detect` returns 200 with trips on success.
    - `POST /v1/calendar/trips/detect` returns 200 with empty array when no trips.
    - `POST /v1/calendar/trips/detect` respects lookaheadDays parameter.
    - `POST /v1/calendar/trips/:tripId/packing-list` requires authentication (401).
    - `POST /v1/calendar/trips/:tripId/packing-list` returns 200 with packing list on success.
    - `POST /v1/calendar/trips/:tripId/packing-list` returns 400 for missing trip data.
    - `POST /v1/calendar/trips/:tripId/packing-list` returns 503 when Gemini unavailable.
    - `POST /v1/calendar/trips/:tripId/packing-list` returns fallback list on Gemini failure.

- [x] Task 13: Mobile - Unit tests for TripDetectionService (AC: 2, 12)
  - [x]13.1: Create `apps/mobile/test/features/outfits/services/trip_detection_service_test.dart`:
    - `detectTrips` calls API and returns parsed trips on success.
    - `detectTrips` returns empty list on API error.
    - `detectTrips` returns empty list on network error.

- [x] Task 14: Mobile - Unit tests for PackingListService (AC: 3, 4, 11, 12)
  - [x]14.1: Create `apps/mobile/test/features/outfits/services/packing_list_service_test.dart`:
    - `generatePackingList` calls API and returns parsed packing list.
    - `generatePackingList` returns null on API error.
    - `getCachedPackingList` returns cached list from SharedPreferences.
    - `getCachedPackingList` returns null when no cache exists.
    - `cachePackingList` persists to SharedPreferences.
    - `getPackedStatus` returns persisted packed state.
    - `updatePackedStatus` updates packed state for specific item.
    - `clearPackedStatus` removes all packed state for trip.

- [x] Task 15: Mobile - Widget tests for TravelBanner (AC: 1, 8, 9, 12)
  - [x]15.1: Create `apps/mobile/test/features/home/widgets/travel_banner_test.dart`:
    - Renders trip destination and date range.
    - Shows "View Packing List" button.
    - Tapping "View Packing List" calls onViewPackingList callback.
    - Shows dismiss button.
    - Tapping dismiss calls onDismiss callback.
    - Shows "Upcoming Trip" when destination is empty.
    - Semantics labels present.

- [x] Task 16: Mobile - Widget tests for PackingListScreen (AC: 3, 4, 5, 7, 11, 12)
  - [x]16.1: Create `apps/mobile/test/features/outfits/screens/packing_list_screen_test.dart`:
    - Renders trip header with destination and duration.
    - Shows loading shimmer initially.
    - Displays categories with items on success.
    - Checkboxes toggle packed state.
    - Progress indicator updates on check/uncheck.
    - Shows fallback banner when fallback list returned.
    - Shows weather unavailable note when applicable.
    - Export button triggers share_plus Share.share.
    - Regenerate button shows confirmation dialog.
    - Confirming regenerate clears packed state and reloads.
    - Shows error state with retry on generation failure.
    - Loads cached list when available.
    - Semantics labels present.
    - Day-by-day outfits section renders correctly.
    - Tips section renders correctly.

- [x] Task 17: Mobile - Widget tests for HomeScreen travel banner integration (AC: 1, 8, 9, 12)
  - [x]17.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When `tripDetectionService` is injected and trip detected, TravelBanner is displayed.
    - When `tripDetectionService` is injected but no trips, no banner shown.
    - TravelBanner is NOT shown if `tripDetectionService` is null (default behavior preserved).
    - Tapping "View Packing List" on banner navigates to PackingListScreen.
    - Dismissing banner hides it and persists dismissed state.
    - All existing HomeScreen tests continue to pass.

- [x] Task 18: Regression testing (AC: 12)
  - [x]18.1: Run `flutter analyze` -- zero issues.
  - [x]18.2: Run `flutter test` -- all existing 1671 Flutter tests plus new tests pass.
  - [x]18.3: Run `npm --prefix apps/api test` -- all existing 1233 API tests plus new tests pass.
  - [x]18.4: Verify existing Home screen functionality preserved: weather, events section, daily outfit generation, event outfit bottom sheet, event reminders, pull-to-refresh.
  - [x]18.5: Verify existing PlanWeekScreen functionality preserved.
  - [x]18.6: Verify existing Outfits tab functionality preserved.

## Dev Notes

- This is the FOURTH and FINAL story in Epic 12 (Calendar Integration & Outfit Planning). It builds on Story 12.1 (event display, event outfit generation), Story 12.2 (outfit scheduling, calendar_outfits, PlanWeekScreen), Story 12.3 (formal event reminders, notification infrastructure), and the calendar/weather infrastructure from Epic 3 (Stories 3.1-3.6) and outfit generation from Epic 4 (Story 4.1).
- The primary FRs covered are FR-TRV-01 (detect multi-day trips from calendar), FR-TRV-02 (generate packing list based on duration, weather, events), FR-TRV-03 (checklist interface for marking items as packed), FR-TRV-04 (export packing list to notes/reminders), and FR-TRV-05 (travel banner on Home screen).
- **This is the FINAL story in Epic 12.** After completion, all FR-EVT-* and FR-TRV-* requirements are addressed. Epic 12 status should be updated to "done" after this story passes code review.

### Design Decision: Trip Detection Heuristics

Trip detection is a heuristic-based approach, not a machine learning model. The three heuristics (multi-day events, location clusters, keyword detection) cover the most common trip indicators in calendar data. The "home location" inference (most frequent event location) avoids false positives for recurring local events.

### Design Decision: Server-Side Trip Detection and Packing List

Both trip detection and packing list generation happen server-side (API):
1. **Trip detection** requires analyzing multiple calendar events with date/location logic -- server has full event data.
2. **Packing list** requires Gemini AI call + destination weather fetch + wardrobe inventory -- all server-side resources.
3. **Geocoding** is done server-side to avoid exposing API keys to the mobile client.

### Design Decision: Packing List Caching

Packing lists are cached locally (SharedPreferences) because:
1. AI generation is expensive and slow (5-10s Gemini call).
2. The list does not change unless the trip changes or user requests regeneration.
3. Packed checkbox state must persist across app restarts.
Server-side caching is NOT implemented in V1 -- the packing list is regenerated on-demand via the API and cached client-side.

### Design Decision: No New Database Tables

No new database tables are needed for this story:
- Trip detection is computed from existing `calendar_events` data.
- Packing lists are cached client-side in SharedPreferences (not persisted to the database).
- Packed status is client-side only.
This keeps the implementation lightweight and avoids schema changes for what is essentially a computed/ephemeral feature.

### Design Decision: Destination Weather via Open-Meteo

The existing `WeatherService` fetches weather for the user's current location. For trip packing, we need weather at the DESTINATION. The API fetches destination weather directly from Open-Meteo using geocoded coordinates. This is a SERVER-SIDE fetch (not mobile-side) to avoid client-side API calls and to centralize weather data fetching.

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/calendar/trip-detection-service.js` (trip detection + geocoding + destination weather)
  - `apps/api/test/modules/calendar/trip-detection-service.test.js`
  - `apps/api/test/modules/calendar/trip-detection.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/outfits/models/trip.dart` (Trip model)
  - `apps/mobile/lib/src/features/outfits/models/packing_list.dart` (PackingList, PackingListCategory, PackingListItem, DailyOutfit models)
  - `apps/mobile/lib/src/features/outfits/services/trip_detection_service.dart` (TripDetectionService)
  - `apps/mobile/lib/src/features/outfits/services/packing_list_service.dart` (PackingListService with caching)
  - `apps/mobile/lib/src/features/home/widgets/travel_banner.dart` (TravelBanner)
  - `apps/mobile/lib/src/features/outfits/screens/packing_list_screen.dart` (PackingListScreen)
  - `apps/mobile/test/features/outfits/services/trip_detection_service_test.dart`
  - `apps/mobile/test/features/outfits/services/packing_list_service_test.dart`
  - `apps/mobile/test/features/home/widgets/travel_banner_test.dart`
  - `apps/mobile/test/features/outfits/screens/packing_list_screen_test.dart`
- Modified API files:
  - `apps/api/src/modules/outfits/outfit-generation-service.js` (add `generatePackingList` method)
  - `apps/api/src/main.js` (add 2 trip endpoints, instantiate trip detection service)
  - `apps/api/test/modules/outfits/outfit-generation-service.test.js` (add packing list generation tests)
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `detectTrips` and `generatePackingList` methods)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add `tripDetectionService`, `packingListService` params, TravelBanner integration)
  - `apps/mobile/lib/src/app.dart` (create trip/packing services, pass to HomeScreen)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add travel banner integration tests)

### Technical Requirements

- **New API endpoints:**
  - `POST /v1/calendar/trips/detect` -- accepts `{ lookaheadDays?: number }`, returns `{ trips: [...] }`. Requires authentication.
  - `POST /v1/calendar/trips/:tripId/packing-list` -- accepts `{ trip: {...}, regenerate?: boolean }`, returns `{ packingList: {...}, generatedAt: "..." }`. Requires authentication.
- **Gemini 2.0 Flash** for packing list generation. Same model as other AI features (`gemini-2.0-flash`), JSON mode (`responseMimeType: "application/json"`).
- **AI usage logging:** Feature name = `"packing_list_generation"`. Log to `ai_usage_log` with same fields.
- **Open-Meteo Geocoding API:** `https://geocoding-api.open-meteo.com/v1/search?name={location}&count=1`. Free, no API key needed. Used server-side for destination coordinate lookup.
- **Open-Meteo Forecast API (destination):** Same API as existing weather service but called server-side with destination coordinates and specific date range. No API key needed.
- **No new database tables or migrations.** Trip detection uses existing `calendar_events`. Packing lists are ephemeral (cached client-side).
- **SharedPreferences keys:**
  - `packing_list_{tripId}`: JSON string of cached PackingList.
  - `packed_status_{tripId}`: JSON map of `{ itemId: bool }` packed states.
  - `trip_dismissed_{tripId}`: Boolean for banner dismissed state.
- **`share_plus`:** Already a dependency (pubspec.yaml line 32). Used for packing list export.
- **No new Flutter dependencies.**

### Architecture Compliance

- **AI calls brokered by Cloud Run:** The mobile client calls the API for trip detection and packing list generation. The API calls Gemini. The mobile client NEVER calls Gemini directly.
- **Server authority for data:** Trip detection analyzes server-side calendar events. Packing list generation accesses server-side wardrobe inventory and weather data.
- **Mobile boundary owns presentation:** TravelBanner, PackingListScreen, and all UI state (checkboxes, caching) are client-side.
- **Graceful degradation:** If Gemini fails, fallback packing list is returned. If geocoding fails, weather is omitted. If trip detection finds no trips, no banner shown.
- **Epic 12 component mapping:** `mobile/features/outfits`, `mobile/features/home`, `api/modules/calendar`, `api/modules/outfits` -- matches architecture.

### Library / Framework Requirements

- No new Flutter dependencies. Uses existing `share_plus`, `http`, `cached_network_image`, `shared_preferences`, Material widgets.
- No new API dependencies. Uses native `fetch` (Node 18+) for Open-Meteo geocoding and weather APIs. Uses existing `@google-cloud/vertexai` via shared `geminiClient`.

### File Structure Requirements

- New service in `apps/api/src/modules/calendar/` -- follows existing pattern alongside `calendar-event-repository.js` and `calendar-outfit-repository.js`.
- New packing list generation method in existing `modules/outfits/outfit-generation-service.js` -- follows pattern of other generation methods.
- New mobile models in `apps/mobile/lib/src/features/outfits/models/` -- follows existing pattern.
- New mobile services in `apps/mobile/lib/src/features/outfits/services/` -- follows existing pattern.
- New widget in `apps/mobile/lib/src/features/home/widgets/` -- follows existing pattern alongside `travel_banner.dart`.
- New screen in `apps/mobile/lib/src/features/outfits/screens/` -- follows existing pattern alongside `plan_week_screen.dart`.
- Test files mirror source structure.

### Testing Requirements

- API unit tests must verify:
  - Trip detection heuristics (multi-day events, location clusters, keyword detection)
  - Geocoding API integration (success, failure, empty input)
  - Destination weather fetch (success, failure)
  - Packing list Gemini prompt includes trip, weather, events, wardrobe
  - Packing list fallback when Gemini fails
  - AI usage logged with "packing_list_generation" feature name
  - Item ID validation against wardrobe
- API integration tests must verify:
  - Both trip endpoints require auth (401)
  - Trip detection returns trips, handles empty results
  - Packing list generation returns valid structure, handles errors
- Mobile unit tests must verify:
  - TripDetectionService calls API correctly, handles errors
  - PackingListService calls API, caches results, manages packed state
- Mobile widget tests must verify:
  - TravelBanner renders trip info, callbacks work
  - PackingListScreen renders categories, checkboxes, progress, export, regenerate
  - HomeScreen integration: banner appears/hides correctly
- Regression tests:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 1671+ tests pass)
  - `npm --prefix apps/api test` (all existing 1233+ tests pass)

### Previous Story Intelligence

- **Story 12.3** (previous story in epic, done) ended with 1233 API tests and 1671 Flutter tests. All must continue to pass. Story 12.3 established: `EventReminderService` (notification ID 103), `EventReminderPreferences`, `POST /v1/outfits/event-prep-tips` endpoint, `NotificationPreferencesScreen` event reminders section, migration 036. HomeScreen now has optional `eventReminderService` and `eventReminderPreferences` params.
- **Story 12.2** established: `calendar_outfits` table (migration 035), `CalendarOutfitService`, `CalendarOutfit` model, `PlanWeekScreen`, `OutfitAssignmentBottomSheet`, `POST/GET/PUT/DELETE /v1/calendar/outfits` endpoints, `calendar-outfit-repository.js`. PlanWeekScreen is accessible from OutfitHistoryScreen.
- **Story 12.1** established: `EventsSection` widget, `EventOutfitBottomSheet`, `event_type_utils.dart` (shared utility), `POST /v1/outfits/generate-for-event` endpoint, `generateOutfitsForEvent` on API/mobile.
- **Story 3.5** established: `calendar_events` table, `CalendarEvent` model with `location`, `allDay`, `eventType`, `formalityScore` fields. `CalendarEventService` with `getEvents()` and date range support via `GET /v1/calendar/events`. The `location` field is critical for trip detection.
- **Story 3.1** established: Location permission flow, `WeatherService` using Open-Meteo API (latitude, longitude based). The Open-Meteo API pattern is reused server-side for destination weather.
- **Story 3.2** established: `WeatherCacheService` with SharedPreferences caching. Similar caching pattern reused for packing list caching.
- **Story 4.1** established: `outfit-generation-service.js` with Gemini prompt pattern, `validateAndEnrichResponse` for item ID validation, AI usage logging, `itemRepo.listItems()` for fetching wardrobe. All reused for packing list generation.
- **Story 7.3** established: `share_plus` usage for AI resale listing export. The export pattern (formatting text and calling `Share.share()`) is reused for packing list export.
- **HomeScreen constructor (as of Story 12.3):** Many DI parameters accumulated. This story adds `tripDetectionService` and `packingListService` (both optional, null default).
- **VestiaireApp (as of Story 12.3):** This story adds `TripDetectionService` and `PackingListService` creation.
- **Current test counts:** 1233 API tests, 1671 Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT create new database tables for trips or packing lists. Trips are computed from `calendar_events`. Packing lists are cached client-side.
- DO NOT call Gemini from the mobile client. All AI calls go through Cloud Run.
- DO NOT call Open-Meteo geocoding or weather APIs from the mobile client for destination data. These calls happen server-side.
- DO NOT modify the existing `WeatherService` on the mobile side. Destination weather is fetched server-side in the trip detection service.
- DO NOT modify the `calendar_events` table or any existing tables. Trip detection is read-only on existing data.
- DO NOT create daily repeating notifications for travel. The travel banner is shown on Home screen load when a trip is detected.
- DO NOT persist packing lists to the database in V1. SharedPreferences caching is sufficient.
- DO NOT block the HomeScreen UI on trip detection. The detection call is fire-and-forget; the banner appears when data arrives.
- DO NOT duplicate item ID validation logic. Reuse the existing `validateAndEnrichResponse` pattern from `outfit-generation-service.js`.
- DO NOT create a new module directory for trip detection. It belongs in `api/modules/calendar/` alongside the event repository.
- DO NOT use client-side geocoding. The Open-Meteo geocoding API is called server-side only.
- DO NOT remove or modify existing notification services, calendar services, or weather services.
- DO NOT skip the mounted guard before `setState` in async HomeScreen callbacks.

### Implementation Guidance

- **Trip ID generation:** Use a deterministic hash of `destination + startDate + endDate` so the same trip always gets the same ID. This allows consistent caching and dismiss tracking. Use a simple string hash: `"trip_${destination.toLowerCase().replaceAll(/\s+/g, '_')}_${startDate}_${endDate}"`.

- **Home location inference:** The "home location" for filtering out local events can be inferred by finding the most frequent non-null `location` across all calendar events in the lookahead window. Events at the home location are not trip candidates (unless matched by keyword heuristic).

- **Open-Meteo date range weather:** Unlike the current weather fetch (which gets 5-day forecast from today), the destination weather fetch specifies explicit `start_date` and `end_date` parameters. Open-Meteo supports up to 16-day forecasts for free. If the trip is beyond 16 days, weather will not be available.

- **Packing list Gemini response size:** The packing list response is larger than outfit generation (multiple categories, daily outfits, tips). Set a higher `maxOutputTokens` (e.g., 4096) in the Gemini call to ensure the full response is returned.

- **share_plus export:** `Share.share(text)` opens the system share sheet. The user can choose Notes, Reminders, Messages, email, etc. This satisfies FR-TRV-04 without platform-specific Notes/Reminders integration. The existing `share_plus: ^10.1.4` dependency is already in `pubspec.yaml`.

- **Calendar event date range for trip events:** When fetching events for the trip date range (to pass to packing list generation), use `GET /v1/calendar/events?startDate=tripStart&endDate=tripEnd`. The endpoint already supports date range filtering (established in Story 3.5).

- **Gradient banner:** Use `Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)])))` for the travel banner. This makes it visually distinct from other Home screen cards.

### References

- [Source: epics.md - Story 12.4: Travel Mode: Multi-Day Trip Packing]
- [Source: epics.md - Epic 12: Calendar Integration & Outfit Planning]
- [Source: epics.md - FR-TRV-01: The system shall detect multi-day trip events from the calendar]
- [Source: epics.md - FR-TRV-02: The system shall generate packing suggestions based on trip duration, destination weather, and planned events]
- [Source: epics.md - FR-TRV-03: Users shall view a checklist interface to mark items as packed]
- [Source: epics.md - FR-TRV-04: Users shall export the packing list to a notes or reminder app]
- [Source: epics.md - FR-TRV-05: A travel banner shall appear on the Home screen when an upcoming trip is detected]
- [Source: architecture.md - AI Orchestration: Vertex AI / Gemini 2.0 Flash]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Epic 12 Calendar Planning & Travel -> mobile/features/outfits, api/modules/calendar, api/modules/notifications]
- [Source: architecture.md - Data Architecture: calendar_events, calendar_outfits tables]
- [Source: prd.md - Calendar Integration: travel mode packing]
- [Source: 12-1-event-display-suggestions.md - EventsSection, event_type_utils.dart, event outfit generation pattern]
- [Source: 12-2-outfit-scheduling-plan-week.md - calendar_outfits, CalendarOutfitService, PlanWeekScreen]
- [Source: 12-3-formal-event-reminders.md - EventReminderService, HomeScreen DI pattern]
- [Source: 3-5-calendar-event-fetching-classification.md - CalendarEvent model with location, allDay, GET /v1/calendar/events with date range]
- [Source: 3-1-location-permission-weather-widget.md - Open-Meteo API pattern, WeatherService]
- [Source: 3-2-fast-weather-loading-local-caching.md - WeatherCacheService, SharedPreferences caching pattern]
- [Source: 4-1-daily-ai-outfit-generation.md - outfit-generation-service.js, Gemini prompt, validateAndEnrichResponse, AI usage logging]
- [Source: 7-3-ai-resale-listing-generation.md - share_plus export pattern]
- [Source: apps/mobile/pubspec.yaml - share_plus: ^10.1.4 dependency]
- [Source: apps/mobile/lib/src/core/calendar/calendar_event.dart - CalendarEvent model with location field]
- [Source: apps/mobile/lib/src/core/weather/weather_service.dart - Open-Meteo API pattern, fetchWeather method]
- [Source: apps/api/src/modules/calendar/calendar-event-repository.js - event repository factory pattern]
- [Source: apps/api/src/modules/outfits/outfit-generation-service.js - Gemini generation pattern, validateAndEnrichResponse]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None -- clean implementation, all tests pass on first full suite run.

### Completion Notes List

- Implemented full trip detection service with 3 heuristics: multi-day events, location clusters, keyword detection
- Added geocoding via Open-Meteo API and destination weather fetching (both server-side)
- Added generatePackingList to outfit-generation-service using Gemini with fallback support
- Created 2 new API endpoints: POST /v1/calendar/trips/detect and POST /v1/calendar/trips/:tripId/packing-list
- Created Trip and PackingList models on mobile with full JSON serialization
- Created TripDetectionService and PackingListService on mobile with SharedPreferences caching
- Created TravelBanner widget with gradient design, dismiss support, and semantic labels
- Created PackingListScreen with categories, checkboxes, progress indicator, export, regenerate, day-by-day outfits, and tips
- Integrated TravelBanner into HomeScreen (shown after weather/forecast, before calendar events)
- Wired services in MainShellScreen (created from apiClient when available)
- AI usage logged with feature="packing_list_generation" (AC 6)
- Graceful degradation: Gemini failure returns fallback list, geocoding failure omits weather, no trips = no banner
- All 1276 API tests pass (1233 existing + 43 new)
- All 1705 Flutter tests pass (1671 existing + 34 new)
- Flutter analyze: 0 errors (only pre-existing warnings/infos)
- No new database tables, no new Flutter dependencies

### Change Log

- 2026-03-19: Story 12.4 implementation complete -- travel mode with trip detection, packing list generation, TravelBanner, PackingListScreen

### File List

**New API files:**
- apps/api/src/modules/calendar/trip-detection-service.js
- apps/api/test/modules/calendar/trip-detection-service.test.js
- apps/api/test/modules/calendar/trip-detection.test.js

**Modified API files:**
- apps/api/src/modules/outfits/outfit-generation-service.js (added generatePackingList, buildPackingListPrompt, validateAndEnrichPackingList, buildFallbackPackingList, getCurrentSeason)
- apps/api/src/main.js (added tripDetectionService instantiation, itemRepo to return, 2 new endpoints, import)
- apps/api/test/modules/outfits/outfit-generation-service.test.js (added 14 packing list generation tests)

**New mobile files:**
- apps/mobile/lib/src/features/outfits/models/trip.dart
- apps/mobile/lib/src/features/outfits/models/packing_list.dart
- apps/mobile/lib/src/features/outfits/services/trip_detection_service.dart
- apps/mobile/lib/src/features/outfits/services/packing_list_service.dart
- apps/mobile/lib/src/features/home/widgets/travel_banner.dart
- apps/mobile/lib/src/features/outfits/screens/packing_list_screen.dart
- apps/mobile/test/features/outfits/services/trip_detection_service_test.dart
- apps/mobile/test/features/outfits/services/packing_list_service_test.dart
- apps/mobile/test/features/home/widgets/travel_banner_test.dart
- apps/mobile/test/features/outfits/screens/packing_list_screen_test.dart

**Modified mobile files:**
- apps/mobile/lib/src/core/networking/api_client.dart (added detectTrips, generatePackingList methods)
- apps/mobile/lib/src/features/home/screens/home_screen.dart (added tripDetectionService, packingListService params, TravelBanner integration, trip detection logic)
- apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart (imported and created TripDetectionService and PackingListService)
- apps/mobile/test/features/home/screens/home_screen_test.dart (added travel banner integration tests)
