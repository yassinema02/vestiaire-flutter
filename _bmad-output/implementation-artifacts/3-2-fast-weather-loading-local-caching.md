# Story 3.2: Fast Weather Loading & Local Caching

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want weather data to load quickly and remain available for a short period without repeated network calls,
so that the home screen feels responsive every time I open it.

## Acceptance Criteria

1. Given I have granted location permission and weather was previously fetched within the last 30 minutes, when the Home screen loads, then the system displays the cached weather data instantly without making a network request (FR-CTX-04).
2. Given I have granted location permission and no cached weather data exists (or it is older than 30 minutes), when the Home screen loads, then the system fetches fresh weather data from the Open-Meteo API and caches it locally (FR-CTX-04).
3. Given weather data is cached, when I check the cache age, then the cache TTL is exactly 30 minutes -- data older than 30 minutes is treated as stale and triggers a fresh fetch (FR-CTX-04).
4. Given the Open-Meteo API request includes forecast parameters, when the response is received, then it contains a 5-day daily forecast with: date, high temperature, low temperature, and weather code for each day (FR-CTX-05).
5. Given the 5-day forecast data has been fetched, when the Home screen renders, then a horizontal scrollable 5-day forecast row is displayed below the current weather widget showing: day name (e.g., "Mon"), weather condition icon, and high/low temperature for each day (FR-CTX-05).
6. Given I pull-to-refresh on the Home screen, when the refresh completes, then the weather cache is invalidated, fresh data is fetched from the API, the cache is updated with the new data, and both current weather and 5-day forecast are re-rendered (FR-CTX-04).
7. Given the app is opened and cached weather data exists but the network is unavailable, when the Home screen loads, then the cached weather data (including forecast) is displayed with a subtle "Last updated X min ago" indicator, and no error state is shown (FR-CTX-04).
8. Given the cache is empty and the network is unavailable, when the Home screen loads, then the weather widget shows the existing error state with a retry button (no regression from Story 3.1) (FR-CTX-04).
9. Given the forecast data includes various weather codes, when the 5-day forecast row renders, then each day's icon correctly maps to the WMO weather code using the existing `weather_codes.dart` mapping (FR-CTX-05).
10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass and new tests cover: weather caching (store, retrieve, TTL expiry, invalidation), 5-day forecast parsing, forecast widget rendering, cache-first loading flow, and pull-to-refresh cache invalidation.

## Tasks / Subtasks

- [x] Task 1: Mobile - Create WeatherCacheService (AC: 1, 2, 3, 6, 7, 8)
  - [x]1.1: Create `apps/mobile/lib/src/core/weather/weather_cache_service.dart` with a `WeatherCacheService` class. Constructor accepts an optional `SharedPreferences` instance for test injection (follows the same pattern as HomeScreen's SharedPreferences injection from Story 3.1).
  - [x]1.2: Define cache key constants: `kWeatherCacheKey = "weather_cache_data"` for the serialized weather JSON and `kWeatherCacheTimestampKey = "weather_cache_timestamp"` for the ISO 8601 timestamp of when data was cached.
  - [x]1.3: Implement `Future<void> cacheWeatherData(WeatherData currentWeather, List<DailyForecast> forecast)` that serializes both the current weather and forecast data to a JSON string and stores it in SharedPreferences along with the current timestamp. The JSON structure should be: `{"current": {...}, "forecast": [...], "cachedAt": "ISO8601"}`.
  - [x]1.4: Implement `Future<CachedWeather?> getCachedWeather()` that reads the cached JSON from SharedPreferences, checks the timestamp against the 30-minute TTL, and returns a `CachedWeather` object (containing `WeatherData`, `List<DailyForecast>`, and `DateTime cachedAt`) if valid, or `null` if expired or missing. The TTL constant should be `static const cacheTtl = Duration(minutes: 30)`.
  - [x]1.5: Implement `Future<void> clearCache()` that removes both the data and timestamp keys from SharedPreferences. This is called on pull-to-refresh.
  - [x]1.6: Implement `bool isCacheValid(DateTime cachedAt)` as a helper that returns `true` if `DateTime.now().difference(cachedAt) < cacheTtl`.

- [x] Task 2: Mobile - Create DailyForecast model (AC: 4, 5, 9)
  - [x]2.1: Create `apps/mobile/lib/src/core/weather/daily_forecast.dart` with a `DailyForecast` class containing fields: `DateTime date`, `double highTemperature`, `double lowTemperature`, `int weatherCode`, `String weatherDescription`, `IconData weatherIcon`. Include `factory DailyForecast.fromOpenMeteoDaily(Map<String, dynamic> daily, int index)` that extracts day `index` from the Open-Meteo daily response arrays.
  - [x]2.2: Implement `Map<String, dynamic> toJson()` and `factory DailyForecast.fromJson(Map<String, dynamic> json)` for cache serialization/deserialization. The `weatherIcon` should be stored as the icon's codePoint (int) and reconstructed via `IconData(codePoint, fontFamily: 'MaterialIcons')`.
  - [x]2.3: Export the model from the weather barrel if one exists, or ensure it is importable from the weather directory.

- [x] Task 3: Mobile - Create CachedWeather model (AC: 1, 7)
  - [x]3.1: Create `apps/mobile/lib/src/core/weather/cached_weather.dart` with a `CachedWeather` class containing fields: `WeatherData currentWeather`, `List<DailyForecast> forecast`, `DateTime cachedAt`. This is the return type of `WeatherCacheService.getCachedWeather()`.
  - [x]3.2: Add a convenience getter `String get lastUpdatedLabel` that returns a human-readable string: "Just now" if < 1 minute, "X min ago" if < 60 minutes, "X hr ago" otherwise. This is used by the UI to show staleness when offline.

- [x] Task 4: Mobile - Extend WeatherData with serialization (AC: 1, 2, 3)
  - [x]4.1: Add `Map<String, dynamic> toJson()` method to the existing `WeatherData` class in `apps/mobile/lib/src/core/weather/weather_data.dart`. Serialize all fields: `temperature`, `feelsLike`, `weatherCode`, `weatherDescription`, `locationName`, `fetchedAt` (as ISO 8601 string). The `weatherIcon` should be stored as `iconCodePoint` (int).
  - [x]4.2: Add `factory WeatherData.fromJson(Map<String, dynamic> json)` constructor that deserializes from the JSON format produced by `toJson()`. Reconstruct `weatherIcon` from `iconCodePoint` via `IconData(codePoint, fontFamily: 'MaterialIcons')`.

- [x] Task 5: Mobile - Extend WeatherService with 5-day forecast (AC: 4, 9)
  - [x]5.1: Update the `fetchCurrentWeather` method in `apps/mobile/lib/src/core/weather/weather_service.dart` to also request daily forecast data. Change the Open-Meteo URL parameters to include `&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=5`. The method signature changes to `Future<WeatherResponse> fetchWeather(double latitude, double longitude, String locationName)` returning a new `WeatherResponse` object.
  - [x]5.2: Create a `WeatherResponse` class (in the same file or a separate file `apps/mobile/lib/src/core/weather/weather_response.dart`) containing `WeatherData current` and `List<DailyForecast> forecast`. The factory constructor parses both `current` and `daily` objects from the Open-Meteo response.
  - [x]5.3: Parse the `daily` object from the Open-Meteo response. The daily object contains arrays: `time` (list of date strings), `temperature_2m_max` (list of doubles), `temperature_2m_min` (list of doubles), `weather_code` (list of ints). Create a `DailyForecast` for each index (0-4).
  - [x]5.4: Maintain backward compatibility: update all existing callers of `fetchCurrentWeather` to use the new `fetchWeather` method and extract `.current` for current weather data.

- [x] Task 6: Mobile - Create ForecastWidget (AC: 5, 9)
  - [x]6.1: Create `apps/mobile/lib/src/features/home/widgets/forecast_widget.dart` with a `ForecastWidget` StatelessWidget. It accepts a `List<DailyForecast>` parameter.
  - [x]6.2: Render a horizontal scrollable row (`SingleChildScrollView` with `scrollDirection: Axis.horizontal`) of 5 forecast day cards. Each card is a `Column` containing: (a) day name abbreviation (e.g., "Mon", "Tue") derived from `DailyForecast.date` using `DateFormat('E')` or manual weekday mapping, (b) weather condition icon (24px, color: #4F46E5) mapped from the weather code, (c) high temperature in bold (14px, #1F2937), (d) low temperature (12px, #6B7280).
  - [x]6.3: Style each day card as a compact column with 12px horizontal padding between items. The entire row sits inside a white card container (16px border radius, subtle shadow) matching the current weather widget style.
  - [x]6.4: Add `Semantics` label on the forecast row: "5-day forecast" and on each day card: "[DayName]: [description], high [X] degrees, low [Y] degrees".
  - [x]6.5: Ensure the forecast row has a minimum touch target of 44px height per WCAG AA.

- [x] Task 7: Mobile - Update HomeScreen with cache-first loading (AC: 1, 2, 3, 5, 6, 7, 8)
  - [x]7.1: Add `WeatherCacheService` as a parameter to `HomeScreen` constructor (optional, defaults to creating a new instance). Follow the existing DI pattern.
  - [x]7.2: Update `_fetchWeather()` to implement a cache-first strategy: (a) First check `weatherCacheService.getCachedWeather()`. If valid cached data exists, set state to `weatherLoaded` immediately with cached data. (b) If cache is empty or expired, fetch fresh data via `weatherService.fetchWeather(lat, lon, locationName)`, cache it via `weatherCacheService.cacheWeatherData(response.current, response.forecast)`, and update state.
  - [x]7.3: Add `List<DailyForecast>? _forecastData` to the HomeScreen state. Update `_buildWeatherSection()` to also render the `ForecastWidget` below the current `WeatherWidget` when forecast data is available.
  - [x]7.4: Update `_handleRefresh()` to call `weatherCacheService.clearCache()` before fetching fresh data, ensuring pull-to-refresh always bypasses the cache.
  - [x]7.5: When displaying cached data while offline, show a "Last updated X min ago" label beneath the weather widget using `CachedWeather.lastUpdatedLabel`. Style: 12px, #9CA3AF, italic.
  - [x]7.6: Handle the edge case where cache exists but fresh fetch fails (network error): keep displaying cached data with the staleness indicator rather than switching to the error state. Only show the error state if both cache is empty AND fetch fails.

- [x] Task 8: Mobile - Update WeatherWidget to support staleness indicator (AC: 7)
  - [x]8.1: Add an optional `String? lastUpdatedLabel` parameter to `WeatherWidget`. When provided and `weatherData` is not null, display the label below the location name row in the success state. Style: 12px, italic, #9CA3AF.
  - [x]8.2: Add Semantics for the staleness indicator: include "Last updated [label]" in the weather widget's Semantics label when the label is present.

- [x] Task 9: Unit tests for WeatherCacheService (AC: 1, 2, 3, 6, 10)
  - [x]9.1: Create `apps/mobile/test/core/weather/weather_cache_service_test.dart`:
    - `cacheWeatherData()` stores data in SharedPreferences.
    - `getCachedWeather()` returns cached data when within TTL.
    - `getCachedWeather()` returns null when cache is expired (> 30 minutes).
    - `getCachedWeather()` returns null when no cache exists.
    - `clearCache()` removes cached data so next `getCachedWeather()` returns null.
    - `isCacheValid()` returns true for recent timestamps, false for old timestamps.
    - Round-trip test: cache data, retrieve it, verify all fields match.

- [x] Task 10: Unit tests for DailyForecast model (AC: 4, 9, 10)
  - [x]10.1: Create `apps/mobile/test/core/weather/daily_forecast_test.dart`:
    - `fromOpenMeteoDaily()` correctly parses temperature_2m_max, temperature_2m_min, weather_code, and time arrays at a given index.
    - `toJson()` and `fromJson()` round-trip correctly (all fields preserved including icon).
    - Weather code is correctly mapped to description and icon via `weather_codes.dart`.
    - Edge case: handles the last index (4) of a 5-day forecast array.

- [x] Task 11: Unit tests for WeatherData serialization (AC: 1, 3, 10)
  - [x]11.1: Add tests to the existing `apps/mobile/test/core/weather/weather_service_test.dart` (or a new `weather_data_test.dart`):
    - `toJson()` produces expected JSON structure with all fields.
    - `fromJson()` reconstructs WeatherData with matching field values.
    - Round-trip: `WeatherData.fromJson(weatherData.toJson())` preserves all fields.
    - `weatherIcon` codePoint serialization and deserialization is correct.

- [x] Task 12: Unit tests for extended WeatherService with forecast (AC: 4, 10)
  - [x]12.1: Update `apps/mobile/test/core/weather/weather_service_test.dart`:
    - `fetchWeather()` parses both current weather and daily forecast from Open-Meteo response.
    - Response includes 5 `DailyForecast` objects with correct high/low temps and weather codes.
    - Existing error-handling tests still pass (network error, non-200, malformed JSON, timeout).
    - Backward compatibility: verify the new method signature works with existing callers.

- [x] Task 13: Widget tests for ForecastWidget (AC: 5, 9, 10)
  - [x]13.1: Create `apps/mobile/test/features/home/widgets/forecast_widget_test.dart`:
    - Renders 5 day cards with correct day names.
    - Each card shows weather icon, high temperature, and low temperature.
    - Weather icons correspond to the correct WMO weather code.
    - Forecast row is horizontally scrollable.
    - Semantics labels are present on the row and each day card.

- [x] Task 14: Widget tests for updated HomeScreen (AC: 1, 2, 5, 6, 7, 8, 10)
  - [x]14.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - When valid cached data exists, WeatherWidget and ForecastWidget render immediately without API call.
    - When cache is expired, fresh data is fetched and cached.
    - Pull-to-refresh clears cache and fetches fresh data.
    - When offline with valid cache, cached data is displayed with "Last updated" label.
    - When offline with no cache, error state is displayed.
    - ForecastWidget appears below WeatherWidget when forecast data is available.
    - Existing tests continue to pass (permission flow, denied state, error state, retry).

- [x] Task 15: Widget tests for WeatherWidget staleness label (AC: 7, 10)
  - [x]15.1: Update `apps/mobile/test/features/home/widgets/weather_widget_test.dart`:
    - When `lastUpdatedLabel` is provided, the label text is displayed below location.
    - When `lastUpdatedLabel` is null, no staleness indicator is shown.
    - Semantics label includes "Last updated" text when the label is present.
    - Existing success/loading/error state tests continue to pass.

- [x] Task 16: Regression testing (AC: all)
  - [x]16.1: Run `flutter analyze` -- zero issues.
  - [x]16.2: Run `flutter test` -- all existing + new tests pass.
  - [x]16.3: Run `npm --prefix apps/api test` -- all existing API tests still pass (no API changes in this story).
  - [x]16.4: Verify existing Home screen functionality is preserved: location permission flow, weather widget states (loading, success, error, denied), pull-to-refresh.
  - [x]16.5: Verify 5-day forecast renders correctly below the current weather widget.
  - [x]16.6: Verify cache behavior: second Home screen load within 30 minutes uses cached data (no shimmer, instant render).

## Dev Notes

- This is the SECOND story in Epic 3 (Context Integration -- Weather & Calendar). It builds directly on Story 3.1 which established the location permission flow, weather fetching from Open-Meteo, and the weather widget on the Home screen. Story 3.1 explicitly deferred caching (FR-CTX-04) and the 5-day forecast (FR-CTX-05) to this story.
- The primary FRs covered are FR-CTX-04 (weather data cached for 30 minutes with local persistence) and FR-CTX-05 (5-day weather forecast).
- **FR-CTX-06 (weather-to-clothing mapping) is OUT OF SCOPE** for this story. It is covered in Story 3.3 (Practical Weather-Aware Outfit Context).
- **No API/backend changes are required.** All caching is client-side using SharedPreferences (already a dependency from Story 3.1). Weather data continues to be fetched directly from the Open-Meteo API.
- **Caching strategy:** SharedPreferences is used for simplicity and because it was already added in Story 3.1. The weather data (current + forecast) is serialized to JSON and stored as a single string. The 30-minute TTL is enforced by storing a timestamp alongside the data. Hive was considered but SharedPreferences is sufficient for this small amount of data (a few KB at most) and avoids adding another dependency.
- **Cache-first loading pattern:** When the Home screen loads, the cache is checked first. If valid cached data exists, it is displayed immediately (no shimmer, no network call). If the cache is empty or expired, a fresh fetch is triggered. This means the Home screen will feel instant on subsequent visits within the 30-minute window.
- **Offline resilience:** If the cache has data but the network is unavailable, the cached data is shown with a "Last updated X min ago" indicator. This is a significant UX improvement: the user sees weather data even when offline, rather than an error state. The error state only appears when both cache is empty AND network is unavailable.
- **Pull-to-refresh always bypasses cache:** When the user explicitly pulls to refresh, the cache is cleared first, then fresh data is fetched. This ensures the user can always force a refresh.
- **Open-Meteo 5-day forecast:** The Open-Meteo API supports daily forecast via the `daily` parameter. Adding `&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=5` to the existing request URL returns daily high/low temps and weather codes for 5 days. The response structure is:
  ```json
  {
    "current": { ... },
    "daily": {
      "time": ["2026-03-12", "2026-03-13", "2026-03-14", "2026-03-15", "2026-03-16"],
      "temperature_2m_max": [15.2, 14.8, 16.1, 13.5, 17.0],
      "temperature_2m_min": [8.1, 7.5, 9.3, 6.8, 10.2],
      "weather_code": [3, 61, 0, 45, 1]
    },
    "daily_units": {
      "temperature_2m_max": "°C",
      "temperature_2m_min": "°C"
    }
  }
  ```
- **WeatherService method rename:** The existing `fetchCurrentWeather` method is renamed to `fetchWeather` and now returns a `WeatherResponse` containing both current weather and forecast data. All callers (HomeScreen) are updated. The old method is removed to avoid maintaining two code paths.
- **Forecast widget design:** The 5-day forecast is displayed as a horizontal scrollable row of compact day cards. Each card shows the day abbreviation, a small weather icon, and high/low temperatures. This follows the common pattern seen in weather apps and fits within the Vibrant Soft-UI design system (white card container, #4F46E5 icons, #1F2937 text).

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/core/weather/weather_cache_service.dart`
  - `apps/mobile/lib/src/core/weather/daily_forecast.dart`
  - `apps/mobile/lib/src/core/weather/cached_weather.dart`
  - `apps/mobile/lib/src/core/weather/weather_response.dart` (optional -- may be in weather_service.dart)
  - `apps/mobile/lib/src/features/home/widgets/forecast_widget.dart`
  - `apps/mobile/test/core/weather/weather_cache_service_test.dart`
  - `apps/mobile/test/core/weather/daily_forecast_test.dart`
  - `apps/mobile/test/features/home/widgets/forecast_widget_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/core/weather/weather_data.dart` (add toJson/fromJson)
  - `apps/mobile/lib/src/core/weather/weather_service.dart` (extend with forecast, rename method)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (cache-first loading, forecast integration)
  - `apps/mobile/lib/src/features/home/widgets/weather_widget.dart` (add lastUpdatedLabel)
  - `apps/mobile/test/core/weather/weather_service_test.dart` (update for new method + forecast tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add cache + forecast tests)
  - `apps/mobile/test/features/home/widgets/weather_widget_test.dart` (add staleness label tests)
- Alignment with existing patterns:
  - WeatherCacheService follows the same SharedPreferences DI pattern as HomeScreen from Story 3.1.
  - JSON serialization follows a simple toJson/fromJson pattern suitable for SharedPreferences string storage.
  - ForecastWidget follows the same card-based, Vibrant Soft-UI styling as WeatherWidget from Story 3.1.

### Technical Requirements

- No new dependencies required. SharedPreferences (^2.3.4) was already added in Story 3.1 for the "Not Now" dismissal persistence and is now also used for weather caching.
- Open-Meteo daily forecast parameters: `daily=temperature_2m_max,temperature_2m_min,weather_code` with `forecast_days=5`. These are added to the existing request URL alongside the `current` parameters.
- The `intl` package is NOT required for day name formatting. Use `DateTime.weekday` (returns 1=Monday to 7=Sunday) and map to abbreviated day names manually (e.g., `["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]`) to avoid adding a heavyweight dependency for a single use case.
- IconData serialization: `IconData` is not directly JSON-serializable. Store the `codePoint` (int) and reconstruct via `IconData(codePoint, fontFamily: 'MaterialIcons')`. This is a well-known Flutter pattern for persisting icon references.
- Cache size is minimal: a single JSON string containing current weather (~200 bytes) + 5 forecast entries (~500 bytes) + metadata. SharedPreferences can handle this easily without performance concerns.

### Architecture Compliance

- Weather data caching is client-side only, per the architecture: "Mobile App Boundary: Owns presentation, gestures, local caching." No server-side caching is added.
- Open-Meteo continues to be called directly from the mobile client (not proxied through Cloud Run), consistent with Story 3.1 and the architecture doc.
- No database changes are needed. All cached data lives in SharedPreferences on the device.
- The cache-first pattern aligns with the architecture principle: "Progressive enhancement: offline browsing, optimistic UI, and cached context improve UX without weakening source-of-truth guarantees."

### Library / Framework Requirements

- No new dependencies. All functionality is built on existing packages:
  - `shared_preferences: ^2.3.4` -- local cache storage (already present)
  - `http: ^1.3.0` -- HTTP client for Open-Meteo (already present)
  - `dart:convert` -- JSON serialization (built-in)

### File Structure Requirements

- Expected new files:
  - `apps/mobile/lib/src/core/weather/weather_cache_service.dart`
  - `apps/mobile/lib/src/core/weather/daily_forecast.dart`
  - `apps/mobile/lib/src/core/weather/cached_weather.dart`
  - `apps/mobile/lib/src/features/home/widgets/forecast_widget.dart`
  - `apps/mobile/test/core/weather/weather_cache_service_test.dart`
  - `apps/mobile/test/core/weather/daily_forecast_test.dart`
  - `apps/mobile/test/features/home/widgets/forecast_widget_test.dart`
- Expected modified files:
  - `apps/mobile/lib/src/core/weather/weather_data.dart` (add toJson/fromJson)
  - `apps/mobile/lib/src/core/weather/weather_service.dart` (extend with forecast, rename method, add WeatherResponse)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (cache-first loading, forecast display, WeatherCacheService DI)
  - `apps/mobile/lib/src/features/home/widgets/weather_widget.dart` (add lastUpdatedLabel param)
  - `apps/mobile/test/core/weather/weather_service_test.dart` (update for forecast tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (add cache + forecast tests)
  - `apps/mobile/test/features/home/widgets/weather_widget_test.dart` (add staleness tests)

### Testing Requirements

- Unit tests must verify:
  - WeatherCacheService stores and retrieves data correctly
  - WeatherCacheService respects 30-minute TTL (returns null for expired cache)
  - WeatherCacheService.clearCache() invalidates the cache
  - DailyForecast parses Open-Meteo daily arrays correctly
  - DailyForecast toJson/fromJson round-trips without data loss
  - WeatherData toJson/fromJson round-trips without data loss
  - WeatherService.fetchWeather() parses both current and daily data
  - WeatherService.fetchWeather() returns 5 DailyForecast objects
  - All existing WeatherService error-handling tests continue to pass
- Widget tests must verify:
  - ForecastWidget renders 5 day cards with correct day names, icons, and temperatures
  - ForecastWidget is horizontally scrollable
  - ForecastWidget has correct Semantics labels
  - HomeScreen uses cached data when available (no API call)
  - HomeScreen fetches fresh data when cache is expired
  - HomeScreen shows forecast below current weather
  - Pull-to-refresh clears cache and fetches fresh data
  - Offline with cache: shows cached data + staleness label
  - Offline without cache: shows error state
  - WeatherWidget shows lastUpdatedLabel when provided
  - All existing HomeScreen tests continue to pass (permission flow, denied, error, retry)
- Regression tests must pass:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing + new tests pass)
  - `npm --prefix apps/api test` (all existing API tests still pass)
- Target: all existing tests continue to pass (348 Flutter tests from Story 3.1, 146 API tests from Story 3.1) plus new tests.

### Previous Story Intelligence

- Story 3.1 (direct predecessor) established: location permission flow, WeatherService fetching from Open-Meteo, WeatherWidget with loading/success/error states, HomeScreen with 6-state state machine, SharedPreferences for "Not Now" persistence. 348 Flutter tests, 146 API tests.
- Story 3.1 explicitly stated: "DO NOT cache weather data in this story. Caching (30-minute TTL with shared_preferences/Hive) is explicitly Story 3.2." and "DO NOT implement the 5-day forecast in this story. That is Story 3.2."
- Story 3.1 added `shared_preferences: ^2.3.4` dependency for the "Not Now" dismissal. This same package is reused here for weather caching.
- Story 3.1's WeatherService currently uses `fetchCurrentWeather()` with only `current` parameters. This story extends the API call to include `daily` parameters.
- Story 3.1's HomeScreen currently fetches fresh weather data every time it loads (no caching). This story introduces cache-first loading.
- Story 3.1's WeatherWidget does not have a staleness indicator. This story adds the `lastUpdatedLabel` parameter.
- Story 2.2 established the shimmer pattern. The forecast widget loading state can reuse it if needed, but since cache-first means data is usually available instantly, a loading state for the forecast is lower priority.
- The MainShellScreen was last modified in Story 3.1 to pass LocationService and WeatherService. No further changes to MainShellScreen are needed in this story.

### Key Anti-Patterns to Avoid

- DO NOT use Hive for caching. SharedPreferences is already a dependency and is sufficient for this small amount of data. Adding Hive would introduce a new dependency, require initialization boilerplate, and add complexity for no benefit.
- DO NOT cache weather data on the server/API side. This is client-side caching per the architecture.
- DO NOT implement weather-to-clothing mapping in this story. That is Story 3.3.
- DO NOT cache location data separately. Location is fetched fresh when needed (it's fast with low accuracy) and the weather cache implicitly includes the location name.
- DO NOT show a loading shimmer when cached data is available. The entire point of caching is to avoid the loading state. Show cached data immediately.
- DO NOT make the cache TTL configurable by the user. 30 minutes is the fixed requirement from FR-CTX-04. User-facing settings add complexity with no clear benefit.
- DO NOT add the `intl` package just for day name formatting. Map weekday numbers to abbreviations manually.
- DO NOT break the existing `fetchCurrentWeather` API in a way that leaves orphaned references. Update all callers when renaming to `fetchWeather`.
- DO NOT show an error state when valid cached data exists but the network is down. Show cached data with a staleness indicator instead. The error state should only appear when there is truly no data to display.
- DO NOT forget to serialize/deserialize `IconData` correctly. Store the codePoint as an integer, reconstruct with `fontFamily: 'MaterialIcons'`.

### Implementation Guidance

- **WeatherCacheService class:**
  ```dart
  import "dart:convert";
  import "package:shared_preferences/shared_preferences.dart";
  import "weather_data.dart";
  import "daily_forecast.dart";
  import "cached_weather.dart";

  class WeatherCacheService {
    WeatherCacheService({SharedPreferences? prefs}) : _prefs = prefs;

    SharedPreferences? _prefs;
    static const cacheTtl = Duration(minutes: 30);
    static const kWeatherCacheKey = "weather_cache_data";
    static const kWeatherCacheTimestampKey = "weather_cache_timestamp";

    Future<SharedPreferences> _getPrefs() async {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!;
    }

    Future<void> cacheWeatherData(
      WeatherData currentWeather,
      List<DailyForecast> forecast,
    ) async {
      final prefs = await _getPrefs();
      final data = jsonEncode({
        "current": currentWeather.toJson(),
        "forecast": forecast.map((f) => f.toJson()).toList(),
      });
      await prefs.setString(kWeatherCacheKey, data);
      await prefs.setString(
        kWeatherCacheTimestampKey,
        DateTime.now().toIso8601String(),
      );
    }

    Future<CachedWeather?> getCachedWeather() async {
      final prefs = await _getPrefs();
      final dataStr = prefs.getString(kWeatherCacheKey);
      final timestampStr = prefs.getString(kWeatherCacheTimestampKey);
      if (dataStr == null || timestampStr == null) return null;

      final cachedAt = DateTime.parse(timestampStr);
      if (!isCacheValid(cachedAt)) return null;

      final json = jsonDecode(dataStr) as Map<String, dynamic>;
      final current = WeatherData.fromJson(
        json["current"] as Map<String, dynamic>,
      );
      final forecast = (json["forecast"] as List)
          .map((f) => DailyForecast.fromJson(f as Map<String, dynamic>))
          .toList();
      return CachedWeather(
        currentWeather: current,
        forecast: forecast,
        cachedAt: cachedAt,
      );
    }

    Future<void> clearCache() async {
      final prefs = await _getPrefs();
      await prefs.remove(kWeatherCacheKey);
      await prefs.remove(kWeatherCacheTimestampKey);
    }

    bool isCacheValid(DateTime cachedAt) =>
        DateTime.now().difference(cachedAt) < cacheTtl;
  }
  ```

- **DailyForecast model:**
  ```dart
  import "package:flutter/material.dart";
  import "weather_codes.dart";

  class DailyForecast {
    const DailyForecast({
      required this.date,
      required this.highTemperature,
      required this.lowTemperature,
      required this.weatherCode,
      required this.weatherDescription,
      required this.weatherIcon,
    });

    final DateTime date;
    final double highTemperature;
    final double lowTemperature;
    final int weatherCode;
    final String weatherDescription;
    final IconData weatherIcon;

    factory DailyForecast.fromOpenMeteoDaily(
      Map<String, dynamic> daily,
      int index,
    ) {
      final code = (daily["weather_code"] as List)[index] as int;
      final condition = mapWeatherCode(code);
      return DailyForecast(
        date: DateTime.parse((daily["time"] as List)[index] as String),
        highTemperature:
            ((daily["temperature_2m_max"] as List)[index] as num).toDouble(),
        lowTemperature:
            ((daily["temperature_2m_min"] as List)[index] as num).toDouble(),
        weatherCode: code,
        weatherDescription: condition.description,
        weatherIcon: condition.icon,
      );
    }

    Map<String, dynamic> toJson() => {
          "date": date.toIso8601String(),
          "highTemperature": highTemperature,
          "lowTemperature": lowTemperature,
          "weatherCode": weatherCode,
          "weatherDescription": weatherDescription,
          "iconCodePoint": weatherIcon.codePoint,
        };

    factory DailyForecast.fromJson(Map<String, dynamic> json) =>
        DailyForecast(
          date: DateTime.parse(json["date"] as String),
          highTemperature: (json["highTemperature"] as num).toDouble(),
          lowTemperature: (json["lowTemperature"] as num).toDouble(),
          weatherCode: json["weatherCode"] as int,
          weatherDescription: json["weatherDescription"] as String,
          weatherIcon: IconData(
            json["iconCodePoint"] as int,
            fontFamily: "MaterialIcons",
          ),
        );
  }
  ```

- **Open-Meteo extended URL:**
  ```
  https://api.open-meteo.com/v1/forecast
    ?latitude=$latitude
    &longitude=$longitude
    &current=temperature_2m,apparent_temperature,weather_code
    &daily=temperature_2m_max,temperature_2m_min,weather_code
    &forecast_days=5
    &timezone=auto
  ```

- **HomeScreen cache-first flow:**
  ```
  _fetchWeather():
    1. Check cache: cachedWeather = await _cacheService.getCachedWeather()
    2. If cachedWeather != null:
       - Set state: weatherLoaded with cachedWeather.currentWeather + cachedWeather.forecast
       - Set _lastUpdatedLabel = cachedWeather.lastUpdatedLabel (only show if cache age > 5 min)
       - Return (no network call)
    3. If cache empty/expired:
       - Get position, get location name
       - Call weatherService.fetchWeather(lat, lon, locationName)
       - Cache the response: cacheService.cacheWeatherData(response.current, response.forecast)
       - Set state: weatherLoaded with fresh data, _lastUpdatedLabel = null
    4. On fetch error:
       - Check if stale cache exists (ignore TTL): if so, show stale data + staleness label
       - If no cache at all, show error state

  _handleRefresh():
    1. Clear cache: cacheService.clearCache()
    2. Call _fetchWeather() (will skip to step 3 since cache is now empty)
  ```

- **Day name mapping (no intl dependency):**
  ```dart
  static const _dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  String dayName(DateTime date) => _dayNames[date.weekday - 1];
  ```

### References

- [Source: epics.md - Story 3.2: Fast Weather Loading & Local Caching]
- [Source: epics.md - Epic 3: Context Integration (Weather & Calendar)]
- [Source: prd.md - FR-CTX-04: Weather data shall be cached for 30 minutes with local persistence (shared_preferences or Hive)]
- [Source: prd.md - FR-CTX-05: The system shall display a 5-day weather forecast]
- [Source: architecture.md - Mobile App Boundary: Owns presentation, gestures, local caching]
- [Source: architecture.md - Progressive enhancement: offline browsing, optimistic UI, and cached context improve UX]
- [Source: functional-requirements.md - Section 3.5 Context Integration (Weather & Calendar)]
- [Source: functional-requirements.md - Open-Meteo API: Weather data (current + forecast), Direct HTTP (free, no key)]
- [Source: 3-1-location-permission-weather-widget.md - Direct predecessor: 348 Flutter tests, 146 API tests, WeatherService, HomeScreen, shared_preferences dependency]
- [Source: 3-1-location-permission-weather-widget.md - "FR-CTX-04 (caching) and FR-CTX-05 (5-day forecast) are OUT OF SCOPE for this story. They are covered in Story 3.2."]

## Dev Agent Record

- **Agent**: Amelia (Claude Opus 4.6)
- **Date**: 2026-03-12
- **Duration**: Single session
- **Test Results**: 392 Flutter tests passing (44 new), 146 API tests passing (unchanged)
- **Analysis**: flutter analyze -- zero issues

## File List

### New Files
- `apps/mobile/lib/src/core/weather/weather_cache_service.dart` -- WeatherCacheService with 30-min TTL caching via SharedPreferences
- `apps/mobile/lib/src/core/weather/daily_forecast.dart` -- DailyForecast model with Open-Meteo parsing and JSON serialization
- `apps/mobile/lib/src/core/weather/cached_weather.dart` -- CachedWeather model with lastUpdatedLabel getter
- `apps/mobile/lib/src/core/weather/weather_response.dart` -- WeatherResponse containing current + forecast data
- `apps/mobile/lib/src/features/home/widgets/forecast_widget.dart` -- Horizontal scrollable 5-day forecast widget
- `apps/mobile/test/core/weather/weather_cache_service_test.dart` -- 10 tests: cache store/retrieve, TTL, clear, round-trip
- `apps/mobile/test/core/weather/daily_forecast_test.dart` -- 8 tests: parsing, serialization, day names
- `apps/mobile/test/core/weather/weather_data_test.dart` -- 4 tests: toJson/fromJson/round-trip/icon serialization

### Modified Files
- `apps/mobile/lib/src/core/weather/weather_data.dart` -- Added toJson() and fromJson() methods
- `apps/mobile/lib/src/core/weather/weather_service.dart` -- Added fetchWeather() with daily forecast params, kept fetchCurrentWeather for compat
- `apps/mobile/lib/src/features/home/screens/home_screen.dart` -- Cache-first loading, forecast display, stale cache fallback, WeatherCacheService DI
- `apps/mobile/lib/src/features/home/widgets/weather_widget.dart` -- Added lastUpdatedLabel parameter with staleness display and Semantics
- `apps/mobile/test/core/weather/weather_service_test.dart` -- Added 7 tests for fetchWeather with forecast parsing
- `apps/mobile/test/features/home/screens/home_screen_test.dart` -- Added 6 tests for cache-first, pull-to-refresh, offline fallback
- `apps/mobile/test/features/home/widgets/weather_widget_test.dart` -- Added 3 tests for lastUpdatedLabel display and Semantics

## Change Log

- 2026-03-12: Story file created by Scrum Master (Bob/Claude Opus 4.6) based on epic breakdown, architecture, PRD requirements (FR-CTX-04, FR-CTX-05), and Story 3.1 implementation context.
- 2026-03-12: Implementation completed by Dev Agent (Amelia/Claude Opus 4.6). All 16 tasks implemented. 392 Flutter tests passing (up from 348), 146 API tests unchanged. Zero analysis issues.
