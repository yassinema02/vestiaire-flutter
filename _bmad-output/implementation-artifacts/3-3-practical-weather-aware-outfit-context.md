# Story 3.3: Practical Weather-Aware Outfit Context

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the app to translate weather conditions into practical clothing constraints and compile a context object for AI outfit generation,
so that outfit suggestions are usable in real life and not just visually coordinated.

## Acceptance Criteria

1. Given a specific weather condition is detected (e.g., Rain, Snow, Hot, Cold, Fog), when the system compiles the context for outfit generation, then it includes specific clothing requirement flags (e.g., "requires: waterproof_outerwear", "avoid: suede", "prefer: warm_layers") derived from the current weather code and temperature (FR-CTX-06).
2. Given the current temperature is above 28C (feels-like), when the system maps weather to clothing constraints, then it produces a "hot weather" constraint set that includes: prefer lightweight/breathable materials (cotton, linen, mesh), avoid heavy materials (wool, fleece, leather), suggest season-appropriate items (summer, all), and prefer light colors (FR-CTX-06).
3. Given the current temperature is below 5C (feels-like), when the system maps weather to clothing constraints, then it produces a "cold weather" constraint set that includes: require outerwear category, prefer warm materials (wool, cashmere, fleece), suggest season-appropriate items (winter, all), and include layering recommendation (FR-CTX-06).
4. Given the current temperature is between 5C and 15C (feels-like), when the system maps weather to clothing constraints, then it produces a "cool weather" constraint set that includes: suggest layerable items, prefer mid-weight materials, suggest season-appropriate items (fall, spring, all) (FR-CTX-06).
5. Given the current temperature is between 15C and 28C (feels-like), when the system maps weather to clothing constraints, then it produces a "mild weather" constraint set that includes: no heavy outerwear required, allow all materials except extreme cold-weather fabrics, suggest season-appropriate items (spring, summer, fall, all) (FR-CTX-06).
6. Given the weather code indicates Rain (codes 51-67, 80-82), when the system maps weather to clothing constraints, then the constraint set includes: require waterproof/water-resistant outerwear, avoid materials damaged by water (suede, leather, silk), and add a "bring umbrella" advisory note (FR-CTX-06).
7. Given the weather code indicates Snow (codes 71-77, 85-86), when the system maps weather to clothing constraints, then the constraint set includes: require warm waterproof outerwear, require closed-toe shoes, prefer warm materials, and avoid delicate materials (suede, silk, chiffon) (FR-CTX-06).
8. Given the weather code indicates Thunderstorm (codes 95-99), when the system maps weather to clothing constraints, then the constraint set includes all rain constraints plus: prefer dark colors (hides water stains), avoid light-colored items, and add advisory note about severe weather (FR-CTX-06).
9. Given weather data (current + forecast) and a date/day-of-week are available, when the system compiles the full outfit context object, then the context includes: current temperature, feels-like temperature, weather description, weather code, clothing constraints (from the mapping), location name, date, day-of-week name, and season derived from the date -- structured as a serializable object ready for Gemini prompt injection (FR-CTX-13).
10. Given the outfit context object is compiled, when it is serialized to a Map/JSON structure, then it contains all fields needed by the AI outfit generation prompt in Story 4.1: `temperature`, `feelsLike`, `weatherCode`, `weatherDescription`, `clothingConstraints` (requires, avoids, prefers, advisories), `locationName`, `date`, `dayOfWeek`, `season`, and `temperatureCategory` (hot/mild/cool/cold) (FR-CTX-13).
11. Given the weather widget is displayed on the Home screen, when weather-to-clothing constraints are computed, then a compact "Dressing tip" line is shown below the forecast widget displaying one practical recommendation (e.g., "Layer up today" or "Light and breezy -- perfect for cotton" or "Grab a waterproof jacket") derived from the top-priority clothing constraint (FR-CTX-06).
12. Given all changes are made, when I run the full test suite, then all existing tests continue to pass and new tests cover: weather-to-clothing mapping for all temperature ranges and weather condition types, outfit context compilation, context serialization, dressing tip generation, and the dressing tip widget display.

## Tasks / Subtasks

- [x] Task 1: Mobile - Create WeatherClothingMapper service (AC: 1, 2, 3, 4, 5, 6, 7, 8)
  - [x] 1.1: Create `apps/mobile/lib/src/core/weather/weather_clothing_mapper.dart` with a `WeatherClothingMapper` class containing a static method `ClothingConstraints mapWeatherToClothing(int weatherCode, double feelsLikeTemperature)`. This is a pure function with no dependencies -- it takes weather data in and produces clothing constraints out.
  - [x] 1.2: Define a `ClothingConstraints` class in the same file with fields: `List<String> requiredCategories` (e.g., ["outerwear"]), `List<String> preferredMaterials` (e.g., ["cotton", "linen"]), `List<String> avoidMaterials` (e.g., ["suede", "leather"]), `List<String> preferredSeasons` (e.g., ["summer", "all"]), `List<String> preferredColors` (optional color hints), `String temperatureCategory` (one of: "hot", "mild", "cool", "cold"), `List<String> advisories` (human-readable notes like "Bring an umbrella"), `bool requiresWaterproof`, `bool requiresLayering`. All list fields use values from the existing taxonomy in `apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart` (validCategories, validMaterials, validSeasons, etc.).
  - [x] 1.3: Implement temperature-based mapping: Hot (>28C feels-like): preferredMaterials = ["cotton", "linen", "mesh", "chiffon"], avoidMaterials = ["wool", "fleece", "leather", "cashmere", "velvet", "corduroy"], preferredSeasons = ["summer", "all"], temperatureCategory = "hot", requiresLayering = false. Mild (15-28C): preferredMaterials = [] (no restriction), avoidMaterials = [] (none), preferredSeasons = ["spring", "summer", "fall", "all"], temperatureCategory = "mild". Cool (5-15C): preferredMaterials = ["wool", "knit", "fleece", "denim", "corduroy"], avoidMaterials = [] (none), preferredSeasons = ["fall", "spring", "all"], temperatureCategory = "cool", requiresLayering = true. Cold (<5C): requiredCategories = ["outerwear"], preferredMaterials = ["wool", "cashmere", "fleece", "knit"], avoidMaterials = ["mesh", "chiffon", "linen"], preferredSeasons = ["winter", "all"], temperatureCategory = "cold", requiresLayering = true.
  - [x] 1.4: Implement precipitation-based overlays that augment the temperature-based constraints: Rain (codes 51-67, 80-82): set requiresWaterproof = true, add "suede" and "silk" to avoidMaterials (if not already present), add "Bring an umbrella" to advisories. Snow (codes 71-77, 85-86): set requiresWaterproof = true, add "suede", "silk", "chiffon" to avoidMaterials, add "outerwear" to requiredCategories if not present, add "shoes" to requiredCategories (closed-toe), add "Wear warm waterproof layers" to advisories. Thunderstorm (codes 95-99): apply all rain constraints plus add "Prefer dark colors" to advisories, add "Severe weather -- dress practically" to advisories. Freezing precipitation (codes 56-57, 66-67): apply rain constraints plus add cold-weather material preferences.
  - [x] 1.5: Implement fog overlay (codes 45, 48): add advisory "Low visibility -- wear bright or reflective colors if walking/cycling" to advisories. No material or category changes.
  - [x] 1.6: Add a `String get primaryTip` getter on `ClothingConstraints` that returns the single most relevant dressing tip for the UI. Priority order: (1) thunderstorm advisory, (2) rain/snow waterproof tip, (3) cold layering tip, (4) hot weather tip, (5) mild weather tip. Examples: "Grab a waterproof jacket -- rain expected", "Layer up with warm fabrics today", "Light and breezy -- perfect for cotton and linen", "Comfortable day -- dress as you like".
  - [x] 1.7: Add `Map<String, dynamic> toJson()` method on `ClothingConstraints` that serializes all fields for inclusion in the outfit context object. This enables the constraints to be embedded in the AI prompt payload.

- [x] Task 2: Mobile - Create OutfitContext model (AC: 9, 10)
  - [x] 2.1: Create `apps/mobile/lib/src/core/weather/outfit_context.dart` with an `OutfitContext` class. Fields: `double temperature`, `double feelsLike`, `int weatherCode`, `String weatherDescription`, `ClothingConstraints clothingConstraints`, `String locationName`, `DateTime date`, `String dayOfWeek`, `String season`, `String temperatureCategory`. The `season` is derived from the date (March-May = spring, June-August = summer, September-November = fall, December-February = winter) and `dayOfWeek` is the full day name (e.g., "Monday").
  - [x] 2.2: Implement `factory OutfitContext.fromWeatherData(WeatherData weatherData, {DateTime? overrideDate})` that creates an OutfitContext from the existing `WeatherData` object. It calls `WeatherClothingMapper.mapWeatherToClothing()` to generate clothing constraints. The `overrideDate` parameter allows tests to inject a fixed date. Default uses `DateTime.now()`.
  - [x] 2.3: Implement `Map<String, dynamic> toJson()` that serializes the full context for use in AI prompt construction (Story 4.1). Structure: `{ "temperature": 22.5, "feelsLike": 21.0, "weatherCode": 3, "weatherDescription": "Partly cloudy", "clothingConstraints": { ... }, "locationName": "Paris, France", "date": "2026-03-12", "dayOfWeek": "Thursday", "season": "spring", "temperatureCategory": "mild" }`.
  - [x] 2.4: Implement `factory OutfitContext.fromJson(Map<String, dynamic> json)` for potential cache deserialization or test construction.
  - [x] 2.5: Add a static helper `String deriveSeason(DateTime date)` that maps month to season: 3-5 = "spring", 6-8 = "summer", 9-11 = "fall", 12/1/2 = "winter". This uses meteorological seasons (northern hemisphere default) which is the simplest model and correct for the majority of users.
  - [x] 2.6: Add a static helper `String deriveDayOfWeek(DateTime date)` that maps `DateTime.weekday` to full day name using a static list: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].

- [x] Task 3: Mobile - Create OutfitContextService (AC: 9, 10)
  - [x] 3.1: Create `apps/mobile/lib/src/core/weather/outfit_context_service.dart` with an `OutfitContextService` class. Constructor accepts optional `WeatherCacheService` for test injection.
  - [x] 3.2: Implement `Future<OutfitContext?> getCurrentContext()` that reads the latest cached weather data from `WeatherCacheService`, and if available, constructs an `OutfitContext` from it. Returns null if no weather data is cached (location denied or fresh app install).
  - [x] 3.3: Implement `OutfitContext? buildContextFromWeather(WeatherData weatherData)` as a synchronous method that creates an `OutfitContext` from a given `WeatherData` object. This is used by `HomeScreen` when fresh weather data is just fetched (before caching).
  - [x] 3.4: This service acts as the bridge between the weather layer (Epic 3) and the AI outfit generation layer (Epic 4, Story 4.1). The `OutfitContext.toJson()` output will be injected into the Gemini prompt by the outfit generation service in Story 4.1.

- [x] Task 4: Mobile - Create DressingTipWidget (AC: 11)
  - [x] 4.1: Create `apps/mobile/lib/src/features/home/widgets/dressing_tip_widget.dart` with a `DressingTipWidget` StatelessWidget. It accepts a `String tip` parameter.
  - [x] 4.2: Display a compact row containing: (a) a small tip/lightbulb icon (Icons.tips_and_updates, 18px, color #4F46E5), (b) the tip text (13px, #4B5563, italic). The row has 12px vertical padding and matches the card styling context (no separate card -- it sits below the forecast widget within the weather section area).
  - [x] 4.3: Add `Semantics` label: "Dressing tip: [tip text]".
  - [x] 4.4: If the tip text is empty or null, render `SizedBox.shrink()` (nothing).

- [x] Task 5: Mobile - Integrate dressing tip into HomeScreen (AC: 1, 9, 11)
  - [x] 5.1: Add `OutfitContextService` as an optional constructor parameter to `HomeScreen` (follows existing DI pattern). Default creates a new instance.
  - [x] 5.2: Add `OutfitContext? _outfitContext` and `String? _dressingTip` to `HomeScreenState`.
  - [x] 5.3: Update `_fetchWeather()`: after weather data is loaded (both from cache and from fresh fetch), build the outfit context via `outfitContextService.buildContextFromWeather(weatherData)` and extract `_dressingTip = outfitContext.clothingConstraints.primaryTip`. Store `_outfitContext` in state for future use by Story 4.1.
  - [x] 5.4: Update `build()`: render `DressingTipWidget(tip: _dressingTip ?? "")` below the `ForecastWidget` (after the forecast row, before the "coming soon" placeholder). Only show when `_state == _HomeState.weatherLoaded` and `_dressingTip` is not null/empty.
  - [x] 5.5: Ensure the dressing tip updates when weather is refreshed via pull-to-refresh.

- [x] Task 6: Unit tests for WeatherClothingMapper (AC: 1, 2, 3, 4, 5, 6, 7, 8, 12)
  - [x] 6.1: Create `apps/mobile/test/core/weather/weather_clothing_mapper_test.dart`:
    - Hot weather (>28C, clear sky): temperatureCategory = "hot", avoidMaterials includes wool/fleece/leather, preferredMaterials includes cotton/linen, requiresLayering = false.
    - Cold weather (<5C, clear sky): temperatureCategory = "cold", requiredCategories includes "outerwear", preferredMaterials includes wool/cashmere/fleece, requiresLayering = true.
    - Cool weather (10C, clear sky): temperatureCategory = "cool", requiresLayering = true, preferredSeasons includes fall/spring.
    - Mild weather (22C, clear sky): temperatureCategory = "mild", no avoidMaterials, preferredSeasons includes spring/summer/fall.
    - Rain overlay (15C, code 61): requiresWaterproof = true, avoidMaterials includes suede/silk, advisories includes umbrella tip.
    - Snow overlay (−2C, code 71): requiresWaterproof = true, requiredCategories includes outerwear + shoes, avoidMaterials includes suede/silk/chiffon.
    - Thunderstorm overlay (20C, code 95): requiresWaterproof = true, advisories includes severe weather note + dark colors tip.
    - Fog overlay (12C, code 45): advisories includes visibility note, no material changes.
    - Freezing drizzle overlay (−1C, code 56): combines rain + cold constraints.
    - Edge case: exactly 28C boundary is "mild" not "hot", exactly 5C is "cool" not "cold", exactly 15C is "mild" not "cool".
    - primaryTip returns appropriate tip string for each weather scenario.
    - toJson() serialization contains all expected fields.

- [x] Task 7: Unit tests for OutfitContext (AC: 9, 10, 12)
  - [x] 7.1: Create `apps/mobile/test/core/weather/outfit_context_test.dart`:
    - fromWeatherData creates correct context with temperature, weatherCode, location, constraints.
    - deriveSeason returns "spring" for March, "summer" for July, "fall" for October, "winter" for January.
    - deriveDayOfWeek returns "Monday" for weekday 1, "Sunday" for weekday 7.
    - toJson produces expected structure with all fields.
    - fromJson round-trips correctly.
    - Season derivation handles edge months: March = spring, June = summer, September = fall, December = winter.
    - dayOfWeek is correctly populated from the date.

- [x] Task 8: Unit tests for OutfitContextService (AC: 9, 10, 12)
  - [x] 8.1: Create `apps/mobile/test/core/weather/outfit_context_service_test.dart`:
    - getCurrentContext() returns OutfitContext when cached weather exists.
    - getCurrentContext() returns null when no cached weather exists.
    - buildContextFromWeather() produces correct OutfitContext from WeatherData.
    - Clothing constraints in returned context match expected values for the weather data.

- [x] Task 9: Widget tests for DressingTipWidget (AC: 11, 12)
  - [x] 9.1: Create `apps/mobile/test/features/home/widgets/dressing_tip_widget_test.dart`:
    - Renders tip icon and tip text when tip is provided.
    - Renders nothing (SizedBox.shrink) when tip is empty string.
    - Semantics label includes "Dressing tip:" prefix.
    - Text styling matches spec (13px, italic, #4B5563).

- [x] Task 10: Widget tests for HomeScreen integration (AC: 1, 9, 11, 12)
  - [x] 10.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When weather is loaded, DressingTipWidget appears below ForecastWidget.
    - Dressing tip text matches expected tip for the mock weather conditions.
    - When weather data changes via pull-to-refresh, dressing tip updates accordingly.
    - OutfitContext is populated in state after weather loads (can test via exposed state if needed).
    - All existing HomeScreen tests continue to pass (permission flow, cache, forecast, staleness, error).

- [x] Task 11: Regression testing (AC: all)
  - [x] 11.1: Run `flutter analyze` -- zero issues.
  - [x] 11.2: Run `flutter test` -- all existing + new tests pass.
  - [x] 11.3: Run `npm --prefix apps/api test` -- all existing API tests still pass (no API changes in this story).
  - [x] 11.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget, forecast widget, cache-first loading, pull-to-refresh, staleness indicator.
  - [x] 11.5: Verify dressing tip renders correctly below the forecast for various weather conditions.

## Dev Notes

- This is the THIRD story in Epic 3 (Context Integration -- Weather & Calendar). It builds directly on Stories 3.1 (location permission, weather widget) and 3.2 (weather caching, 5-day forecast). Stories 3.1 and 3.2 explicitly deferred FR-CTX-06 (weather-to-clothing mapping) to this story.
- The primary FRs covered are FR-CTX-06 (map weather conditions to clothing recommendations) and FR-CTX-13 (compile a context object for AI outfit generation, partially -- weather + date portion only; calendar events will be added in Stories 3.4-3.6).
- **FR-CTX-07 through FR-CTX-12 (calendar sync and event classification) are OUT OF SCOPE** for this story. They are covered in Stories 3.4-3.6.
- **The full FR-CTX-13 context object requires both weather AND calendar data.** This story implements the weather portion of the context object. Story 3.5 (calendar event fetching) and Story 3.6 (event classification) will add calendar event data to the context object. Story 4.1 (daily AI outfit generation) will be the consumer of the complete context object.
- **No API/backend changes are required.** The weather-to-clothing mapping is a pure client-side logic layer. The outfit context object is constructed on the mobile client and will be serialized into the Gemini prompt payload in Story 4.1 (which DOES involve the API). This story only creates the data structures and mapping logic.
- **Taxonomy alignment:** The clothing constraints use values from the existing `taxonomy.dart` constants (`validCategories`, `validMaterials`, `validSeasons`). This ensures the constraints can be directly matched against wardrobe item attributes when the AI generates outfit suggestions. For example, if the constraint says "avoid: suede", the AI can filter items where `material == "suede"` from the suggestion pool.
- **Temperature thresholds rationale:** The temperature bands (hot >28C, mild 15-28C, cool 5-15C, cold <5C) use "feels like" temperature rather than actual temperature. "Feels like" accounts for wind chill and humidity, making it a better predictor of what the user should actually wear. The bands are based on common clothing comfort guidelines and are NOT user-configurable in this story. Future stories could add preference tuning.
- **Precipitation overlay pattern:** The mapping uses a layered approach: first compute temperature-based constraints, then overlay precipitation-based constraints on top. This means a rainy 30C day gets hot-weather material preferences PLUS waterproof requirements and suede/silk avoidance. The overlays are additive (they add to avoidMaterials, they add to advisories) rather than replacing the temperature-based constraints.
- **The dressing tip is deliberately simple.** It shows one human-readable line of advice, not a complex constraint set. The full constraint set exists in the `OutfitContext` for the AI to consume programmatically, but the user sees only a friendly tip. This matches the UX principle of "Relief & Clarity" from the UX design spec.
- **Northern hemisphere season derivation:** The `deriveSeason()` helper uses meteorological seasons (March-May = spring, etc.) based on Northern Hemisphere conventions. This is a simplification; a future story could use the user's hemisphere based on their latitude. For MVP, this covers the majority use case.
- **OutfitContext is the contract for Story 4.1.** The `OutfitContext.toJson()` output is designed to be directly injectable into the Gemini prompt. Story 4.1 will import and use `OutfitContextService.getCurrentContext()` to get the weather-aware context, then add calendar data (from Stories 3.5-3.6), wardrobe items, and wear history before sending to Gemini.

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/core/weather/weather_clothing_mapper.dart`
  - `apps/mobile/lib/src/core/weather/outfit_context.dart`
  - `apps/mobile/lib/src/core/weather/outfit_context_service.dart`
  - `apps/mobile/lib/src/features/home/widgets/dressing_tip_widget.dart`
  - `apps/mobile/test/core/weather/weather_clothing_mapper_test.dart`
  - `apps/mobile/test/core/weather/outfit_context_test.dart`
  - `apps/mobile/test/core/weather/outfit_context_service_test.dart`
  - `apps/mobile/test/features/home/widgets/dressing_tip_widget_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add OutfitContextService DI, compute context + dressing tip on weather load, render DressingTipWidget)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add dressing tip + outfit context integration tests)
- Alignment with existing patterns:
  - WeatherClothingMapper is a pure static utility class, similar to `weather_codes.dart` (no state, no dependencies, purely functional mapping).
  - OutfitContext follows the same model pattern as WeatherData and DailyForecast (immutable class with toJson/fromJson).
  - OutfitContextService follows the same DI pattern as WeatherCacheService (accepts optional dependencies in constructor).
  - DressingTipWidget follows the same StatelessWidget pattern and Vibrant Soft-UI styling as WeatherWidget and ForecastWidget.

### Technical Requirements

- No new dependencies required. All functionality is built on existing packages and pure Dart logic.
- The `ClothingConstraints` class references taxonomy values from `apps/mobile/lib/src/features/wardrobe/models/taxonomy.dart`. This creates a cross-feature import (weather -> wardrobe). This is acceptable because the taxonomy is a shared vocabulary across the app. If this becomes a concern, the taxonomy constants could be moved to `core/` in a future refactoring story.
- Temperature thresholds use `feelsLike` from `WeatherData` (available since Story 3.1). No additional API parameters are needed.
- The WMO weather code ranges used for precipitation detection are the same codes already mapped in `weather_codes.dart` (Story 3.1). This story does NOT modify `weather_codes.dart` -- it reads the same code values and adds clothing-specific interpretation.

### Architecture Compliance

- All logic is client-side, per the architecture: "Mobile App Boundary: Owns presentation, gestures, local caching."
- The outfit context object is prepared on the client but will be sent to Cloud Run as part of the AI outfit generation request in Story 4.1. This aligns with the architecture principle: "AI calls are brokered only by Cloud Run."
- No database changes are needed. The outfit context is an ephemeral runtime object constructed from cached weather data and current date.
- The clothing constraints are structured data that will be consumed by the Gemini prompt in Story 4.1. This aligns with the architecture principle of "taxonomy validation on structured outputs" -- the constraints use the same taxonomy vocabulary that Gemini will output against.

### Library / Framework Requirements

- No new dependencies required. This story is purely additive logic on top of existing weather infrastructure.

### File Structure Requirements

- Expected new files:
  - `apps/mobile/lib/src/core/weather/weather_clothing_mapper.dart`
  - `apps/mobile/lib/src/core/weather/outfit_context.dart`
  - `apps/mobile/lib/src/core/weather/outfit_context_service.dart`
  - `apps/mobile/lib/src/features/home/widgets/dressing_tip_widget.dart`
  - `apps/mobile/test/core/weather/weather_clothing_mapper_test.dart`
  - `apps/mobile/test/core/weather/outfit_context_test.dart`
  - `apps/mobile/test/core/weather/outfit_context_service_test.dart`
  - `apps/mobile/test/features/home/widgets/dressing_tip_widget_test.dart`
- Expected modified files:
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add OutfitContextService, compute context on weather load, render dressing tip)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add dressing tip integration tests)

### Testing Requirements

- Unit tests must verify:
  - WeatherClothingMapper produces correct constraints for all 4 temperature bands (hot, mild, cool, cold)
  - WeatherClothingMapper produces correct precipitation overlays for rain, snow, thunderstorm, fog, freezing precipitation
  - WeatherClothingMapper correctly combines temperature + precipitation constraints (additive overlay)
  - WeatherClothingMapper handles boundary temperatures correctly (28C = mild, 5C = cool, 15C = mild)
  - ClothingConstraints.primaryTip returns the highest-priority tip for each weather scenario
  - ClothingConstraints.toJson() produces expected serialized structure
  - OutfitContext.fromWeatherData() produces correct context with all fields
  - OutfitContext.deriveSeason() returns correct season for all months
  - OutfitContext.deriveDayOfWeek() returns correct day name for all weekdays
  - OutfitContext.toJson() and fromJson() round-trip correctly
  - OutfitContextService.getCurrentContext() returns context when cache has data, null when no cache
  - OutfitContextService.buildContextFromWeather() produces correct context from WeatherData
- Widget tests must verify:
  - DressingTipWidget renders icon and text when tip is provided
  - DressingTipWidget renders nothing when tip is empty
  - DressingTipWidget has correct Semantics label
  - HomeScreen shows DressingTipWidget below ForecastWidget when weather is loaded
  - Dressing tip updates on pull-to-refresh
  - All existing HomeScreen tests continue to pass
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing API tests still pass)
- Target: all existing tests continue to pass (392 Flutter tests from Story 3.2, 146 API tests from Story 3.2) plus new tests.

### Previous Story Intelligence

- Story 3.2 (direct predecessor) established: WeatherCacheService with 30-min TTL, DailyForecast model, ForecastWidget, cache-first loading in HomeScreen, staleness indicator. 392 Flutter tests, 146 API tests.
- Story 3.2 explicitly stated: "DO NOT implement weather-to-clothing mapping in this story. That is Story 3.3."
- Story 3.1 explicitly stated: "FR-CTX-06 (weather-to-clothing mapping) is OUT OF SCOPE for this story. It is covered in Story 3.3 (Practical Weather-Aware Outfit Context)."
- Story 3.1 established: WeatherData model with `temperature`, `feelsLike`, `weatherCode`, `weatherDescription`, `weatherIcon`, `locationName`, `fetchedAt`. This is the input for the clothing mapper.
- Story 3.1 established: `weather_codes.dart` with WMO code to description/icon mapping. This story adds a parallel mapping layer: WMO code to clothing constraints.
- Story 3.2 established: `WeatherCacheService.getCachedWeather()` returns `CachedWeather` with `currentWeather` and `forecast`. The `OutfitContextService` uses this to build context from cached data.
- Story 2.3 established: Item taxonomy in `taxonomy.dart` with validCategories, validColors, validPatterns, validMaterials, validStyles, validSeasons, validOccasions. The clothing constraints reference these same values.
- The MainShellScreen was last modified in Story 3.1 to pass LocationService and WeatherService. No further changes to MainShellScreen are needed in this story.
- HomeScreen currently has a "Daily outfit suggestions coming soon" placeholder card (line 264-285 in home_screen.dart). This placeholder remains unchanged in this story. Story 4.1 will replace it.

### Key Anti-Patterns to Avoid

- DO NOT call the Open-Meteo API again. All weather data is already available from Story 3.2's cache. This story ONLY adds interpretation logic on top of existing weather data.
- DO NOT add AI calls (Gemini) in this story. The clothing mapping is deterministic rule-based logic, not AI inference. AI outfit generation is Story 4.1.
- DO NOT add calendar event data to the context object yet. Calendar sync is Stories 3.4-3.6. This story creates the weather portion of the context and designs the object to be extensible for calendar data.
- DO NOT make the temperature thresholds user-configurable. Fixed thresholds are simpler and sufficient for MVP.
- DO NOT modify the existing `weather_codes.dart` mapping. The clothing mapper reads weather codes independently and adds clothing-specific interpretation alongside the existing description/icon mapping.
- DO NOT create a separate API endpoint for weather-to-clothing mapping. This is purely client-side logic.
- DO NOT show the full constraint set to the user. The user sees only the `primaryTip` string. The detailed constraints are for the AI's consumption in Story 4.1.
- DO NOT import from `features/wardrobe/models/taxonomy.dart` using string literal values. Import the constants and reference them by name to ensure compile-time safety if taxonomy values change.
- DO NOT add any backend changes. The context object preparation is entirely a mobile concern. Story 4.1 will send the context to Cloud Run for AI processing.

### Implementation Guidance

- **WeatherClothingMapper class:**
  ```dart
  import "../../features/wardrobe/models/taxonomy.dart";

  class ClothingConstraints {
    const ClothingConstraints({
      this.requiredCategories = const [],
      this.preferredMaterials = const [],
      this.avoidMaterials = const [],
      this.preferredSeasons = const [],
      this.preferredColors = const [],
      this.temperatureCategory = "mild",
      this.advisories = const [],
      this.requiresWaterproof = false,
      this.requiresLayering = false,
    });

    final List<String> requiredCategories;
    final List<String> preferredMaterials;
    final List<String> avoidMaterials;
    final List<String> preferredSeasons;
    final List<String> preferredColors;
    final String temperatureCategory;
    final List<String> advisories;
    final bool requiresWaterproof;
    final bool requiresLayering;

    String get primaryTip {
      // Priority: thunderstorm > rain/snow > cold > cool > hot > mild
      if (advisories.any((a) => a.contains("Severe weather"))) {
        return "Severe weather expected -- dress practically";
      }
      if (requiresWaterproof && temperatureCategory == "cold") {
        return "Bundle up with waterproof layers";
      }
      if (requiresWaterproof) {
        return "Grab a waterproof jacket -- rain expected";
      }
      if (temperatureCategory == "cold") {
        return "Layer up with warm fabrics today";
      }
      if (temperatureCategory == "cool") {
        return "A light jacket or layers will keep you comfortable";
      }
      if (temperatureCategory == "hot") {
        return "Light and breezy -- perfect for cotton and linen";
      }
      return "Comfortable day -- dress as you like";
    }

    Map<String, dynamic> toJson() => {
      "requiredCategories": requiredCategories,
      "preferredMaterials": preferredMaterials,
      "avoidMaterials": avoidMaterials,
      "preferredSeasons": preferredSeasons,
      "preferredColors": preferredColors,
      "temperatureCategory": temperatureCategory,
      "advisories": advisories,
      "requiresWaterproof": requiresWaterproof,
      "requiresLayering": requiresLayering,
    };
  }
  ```

- **OutfitContext model:**
  ```dart
  class OutfitContext {
    const OutfitContext({
      required this.temperature,
      required this.feelsLike,
      required this.weatherCode,
      required this.weatherDescription,
      required this.clothingConstraints,
      required this.locationName,
      required this.date,
      required this.dayOfWeek,
      required this.season,
      required this.temperatureCategory,
    });

    final double temperature;
    final double feelsLike;
    final int weatherCode;
    final String weatherDescription;
    final ClothingConstraints clothingConstraints;
    final String locationName;
    final DateTime date;
    final String dayOfWeek;
    final String season;
    final String temperatureCategory;

    static const _dayNames = [
      "Monday", "Tuesday", "Wednesday", "Thursday",
      "Friday", "Saturday", "Sunday",
    ];

    static String deriveSeason(DateTime date) {
      final month = date.month;
      if (month >= 3 && month <= 5) return "spring";
      if (month >= 6 && month <= 8) return "summer";
      if (month >= 9 && month <= 11) return "fall";
      return "winter";
    }

    static String deriveDayOfWeek(DateTime date) =>
        _dayNames[date.weekday - 1];

    factory OutfitContext.fromWeatherData(
      WeatherData weatherData, {
      DateTime? overrideDate,
    }) {
      final date = overrideDate ?? DateTime.now();
      final constraints = WeatherClothingMapper.mapWeatherToClothing(
        weatherData.weatherCode,
        weatherData.feelsLike,
      );
      return OutfitContext(
        temperature: weatherData.temperature,
        feelsLike: weatherData.feelsLike,
        weatherCode: weatherData.weatherCode,
        weatherDescription: weatherData.weatherDescription,
        clothingConstraints: constraints,
        locationName: weatherData.locationName,
        date: date,
        dayOfWeek: deriveDayOfWeek(date),
        season: deriveSeason(date),
        temperatureCategory: constraints.temperatureCategory,
      );
    }

    Map<String, dynamic> toJson() => {
      "temperature": temperature,
      "feelsLike": feelsLike,
      "weatherCode": weatherCode,
      "weatherDescription": weatherDescription,
      "clothingConstraints": clothingConstraints.toJson(),
      "locationName": locationName,
      "date": "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      "dayOfWeek": dayOfWeek,
      "season": season,
      "temperatureCategory": temperatureCategory,
    };
  }
  ```

- **HomeScreen integration:**
  ```
  _fetchWeather() additions:
    After setState with weatherLoaded:
      final context = _outfitContextService.buildContextFromWeather(_weatherData!);
      _outfitContext = context;
      _dressingTip = context?.clothingConstraints.primaryTip;

  build() additions:
    After ForecastWidget, before "Coming soon" placeholder:
      if (_dressingTip != null && _dressingTip!.isNotEmpty &&
          _state == _HomeState.weatherLoaded) ...[
        const SizedBox(height: 8),
        DressingTipWidget(tip: _dressingTip!),
      ],
  ```

### References

- [Source: epics.md - Story 3.3: Practical Weather-Aware Outfit Context]
- [Source: epics.md - Epic 3: Context Integration (Weather & Calendar)]
- [Source: prd.md - FR-CTX-06: The system shall map weather conditions to clothing recommendations (e.g., rain -> waterproof outerwear)]
- [Source: prd.md - FR-CTX-13: The system shall compile a context object (weather + events + date + day-of-week) for AI outfit generation]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures, local caching]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - taxonomy validation on structured outputs]
- [Source: functional-requirements.md - Section 3.5 Context Integration (Weather & Calendar)]
- [Source: ux-design-specification.md - Relief & Clarity: removing cognitive load of getting dressed]
- [Source: ux-design-specification.md - Confidence: feeling put-together and knowing the outfit is appropriate for the weather]
- [Source: 3-1-location-permission-weather-widget.md - WeatherData model, weather_codes.dart, WeatherService]
- [Source: 3-1-location-permission-weather-widget.md - "FR-CTX-06 (weather-to-clothing mapping) is OUT OF SCOPE for this story. It is covered in Story 3.3."]
- [Source: 3-2-fast-weather-loading-local-caching.md - WeatherCacheService, DailyForecast, ForecastWidget, cache-first loading, 392 Flutter tests]
- [Source: 3-2-fast-weather-loading-local-caching.md - "DO NOT implement weather-to-clothing mapping in this story. That is Story 3.3."]
- [Source: taxonomy.dart - validCategories, validMaterials, validSeasons, validOccasions, validColors]

## Change Log

- 2026-03-12: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirements (FR-CTX-06, FR-CTX-13), taxonomy.dart, and Stories 3.1-3.2 implementation context.
