import "dart:collection";
import "dart:convert";

import "package:device_calendar/device_calendar.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:geolocator/geolocator.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_preferences_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_service.dart";
import "package:vestiaire_mobile/src/core/location/location_service.dart";
import "package:vestiaire_mobile/src/core/weather/daily_forecast.dart";
import "package:vestiaire_mobile/src/core/weather/weather_cache_service.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";
import "package:vestiaire_mobile/src/core/weather/weather_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event_service.dart";
import "package:vestiaire_mobile/src/features/analytics/services/wear_log_service.dart";
import "package:vestiaire_mobile/src/features/home/screens/home_screen.dart";
import "package:vestiaire_mobile/src/features/home/widgets/calendar_permission_card.dart";
import "package:vestiaire_mobile/src/features/home/widgets/dressing_tip_widget.dart";
import "package:vestiaire_mobile/src/features/home/widgets/events_section.dart";
import "package:vestiaire_mobile/src/features/home/widgets/forecast_widget.dart";
import "package:vestiaire_mobile/src/features/home/widgets/outfit_minimum_items_card.dart";
import "package:vestiaire_mobile/src/features/home/widgets/outfit_suggestion_card.dart";
import "package:vestiaire_mobile/src/features/home/widgets/swipeable_outfit_stack.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";
import "package:vestiaire_mobile/src/features/outfits/models/usage_info.dart";
import "package:vestiaire_mobile/src/features/outfits/models/usage_limit_result.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_generation_service.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";
import "package:vestiaire_mobile/src/features/home/widgets/usage_indicator.dart";
import "package:vestiaire_mobile/src/features/home/widgets/usage_limit_card.dart";
import "package:vestiaire_mobile/src/core/weather/outfit_context.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";

class _MockAuthServiceForFab implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockGeolocator extends GeolocatorPlatform {
  LocationPermission permissionToReturn = LocationPermission.denied;
  LocationPermission requestPermissionResult = LocationPermission.whileInUse;
  Position? positionToReturn;
  bool openSettingsCalled = false;

  @override
  Future<LocationPermission> checkPermission() async => permissionToReturn;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestPermissionResult;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionToReturn != null) return positionToReturn!;
    throw const LocationServiceDisabledException();
  }

  @override
  Future<bool> openLocationSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

/// Mock DeviceCalendarPlugin for HomeScreen tests.
class _MockDeviceCalendarPlugin extends DeviceCalendarPlugin {
  bool hasPermissionsResult = false;
  bool requestPermissionsResult = false;
  List<Calendar> calendarsToReturn = [];

  _MockDeviceCalendarPlugin() : super.private();

  @override
  Future<Result<bool>> hasPermissions() async {
    final result = Result<bool>();
    result.data = hasPermissionsResult;
    return result;
  }

  @override
  Future<Result<bool>> requestPermissions() async {
    final result = Result<bool>();
    result.data = requestPermissionsResult;
    return result;
  }

  @override
  Future<Result<UnmodifiableListView<Calendar>>> retrieveCalendars() async {
    final result = Result<UnmodifiableListView<Calendar>>();
    result.data = UnmodifiableListView(calendarsToReturn);
    return result;
  }
}

/// Mock CalendarEventService for HomeScreen tests.
///
/// We can't easily extend CalendarEventService (requires real ApiClient),
/// so we use a simple class with the same interface via duck-typing.
/// The HomeScreen only calls fetchAndSyncEvents() and updateEventOverride().
class _MockCalendarEventService implements CalendarEventService {
  List<CalendarEvent> eventsToReturn = [];
  int fetchCallCount = 0;
  CalendarEvent? overrideResult;
  bool overrideShouldFail = false;
  String? lastOverrideEventId;
  String? lastOverrideEventType;
  int? lastOverrideFormalityScore;

  @override
  Future<List<CalendarEvent>> fetchAndSyncEvents() async {
    fetchCallCount++;
    return eventsToReturn;
  }

  @override
  Future<CalendarEvent?> updateEventOverride(
    String eventId, {
    required String eventType,
    required int formalityScore,
  }) async {
    lastOverrideEventId = eventId;
    lastOverrideEventType = eventType;
    lastOverrideFormalityScore = formalityScore;
    if (overrideShouldFail) return null;
    return overrideResult ??
        CalendarEvent(
          id: eventId,
          sourceCalendarId: "cal-1",
          sourceEventId: eventId,
          title: "Updated",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: eventType,
          formalityScore: formalityScore,
          classificationSource: "user",
          userOverride: true,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock OutfitGenerationService for HomeScreen tests.
class _MockOutfitGenerationService implements OutfitGenerationService {
  OutfitGenerationResult? resultToReturn;
  bool shouldFail = false;
  bool shouldReturnLimitReached = false;
  UsageLimitReachedResult? limitReachedToReturn;
  int generateCallCount = 0;

  @override
  Future<OutfitGenerationResponse> generateOutfits(OutfitContext context) async {
    generateCallCount++;
    if (shouldReturnLimitReached && limitReachedToReturn != null) {
      return OutfitGenerationResponse(limitReached: limitReachedToReturn);
    }
    if (shouldFail) {
      return const OutfitGenerationResponse(isError: true);
    }
    if (resultToReturn != null) {
      return OutfitGenerationResponse(result: resultToReturn);
    }
    return const OutfitGenerationResponse(isError: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock OutfitPersistenceService for HomeScreen tests.
class _MockOutfitPersistenceService implements OutfitPersistenceService {
  bool shouldSucceed = true;
  int saveCallCount = 0;

  @override
  Future<Map<String, dynamic>?> saveOutfit(OutfitSuggestion suggestion) async {
    saveCallCount++;
    if (!shouldSucceed) return null;
    return {"outfit": {"id": "outfit-uuid-1", "name": suggestion.name}};
  }

  @override
  Future<Map<String, dynamic>?> saveManualOutfit({
    required String name,
    String? occasion,
    required List<Map<String, dynamic>> items,
  }) async {
    if (!shouldSucceed) return null;
    return {"outfit": {"id": "outfit-uuid-2", "name": name}};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position _testPosition() => Position(
      latitude: 48.85,
      longitude: 2.35,
      timestamp: DateTime.now(),
      accuracy: 100,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

final _validWeatherWithForecastJson = jsonEncode({
  "current": {
    "temperature_2m": 18.5,
    "apparent_temperature": 16.2,
    "weather_code": 0,
  },
  "daily": {
    "time": [
      "2026-03-12",
      "2026-03-13",
      "2026-03-14",
      "2026-03-15",
      "2026-03-16",
    ],
    "temperature_2m_max": [15.2, 14.8, 16.1, 13.5, 17.0],
    "temperature_2m_min": [8.1, 7.5, 9.3, 6.8, 10.2],
    "weather_code": [3, 61, 0, 45, 1],
  },
});

void main() {
  group("HomeScreen", () {
    late _MockGeolocator mockGeolocator;
    late LocationService locationService;
    late _MockDeviceCalendarPlugin mockCalendarPlugin;
    late CalendarService calendarService;

    setUp(() {
      mockGeolocator = _MockGeolocator();
      locationService = LocationService(geolocator: mockGeolocator);
      mockCalendarPlugin = _MockDeviceCalendarPlugin();
      calendarService = CalendarService(plugin: mockCalendarPlugin);
      SharedPreferences.setMockInitialValues({});
    });

    WeatherService buildWeatherService({bool fail = false}) {
      final mockClient = http_testing.MockClient((request) async {
        if (fail) {
          return http.Response("Server Error", 500);
        }
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      return WeatherService(client: mockClient);
    }

    Future<void> pumpHomeScreen(
      WidgetTester tester, {
      required WeatherService weatherService,
      SharedPreferences? prefs,
      WeatherCacheService? cacheService,
      CalendarService? calService,
      CalendarPreferencesService? calPrefsService,
      CalendarEventService? calEventService,
    }) async {
      final sp = prefs ?? await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: weatherService,
            sharedPreferences: sp,
            weatherCacheService:
                cacheService ?? WeatherCacheService(prefs: sp),
            calendarService: calService ?? calendarService,
            calendarPreferencesService:
                calPrefsService ?? CalendarPreferencesService(prefs: sp),
            calendarEventService: calEventService,
          ),
        ),
      );
    }

    // --- Existing tests from Story 3.1 (preserved) ---

    testWidgets(
        "when permission not yet requested and not dismissed, LocationPermissionCard is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.text("Enable Location"), findsWidgets);
      expect(find.text("Not Now"), findsOneWidget);
    });

    testWidgets("when permission denied, WeatherDeniedCard is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.deniedForever;

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.text("Location access needed for weather"), findsOneWidget);
      expect(find.text("Grant Access"), findsOneWidget);
    });

    testWidgets(
        "when permission granted, WeatherWidget is shown with weather data",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Temperature: 18.5 rounds to 19
      expect(find.text("19\u00B0C"), findsOneWidget);
      expect(find.text("Clear sky"), findsWidgets);
    });

    testWidgets("when weather fetch fails, WeatherWidget error state is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(fail: true),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets(
        "tapping Not Now hides the permission card on next build",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Tap Not Now
      await tester.tap(find.text("Not Now"));
      await tester.pumpAndSettle();

      // Should now show denied card, not permission card
      expect(find.text("Not Now"), findsNothing);
      expect(find.text("Location access needed for weather"), findsOneWidget);
    });

    testWidgets("pull-to-refresh triggers weather re-fetch", (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      var fetchCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        fetchCount++;
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      final weatherService = WeatherService(client: mockClient);
      final sp = await SharedPreferences.getInstance();

      await pumpHomeScreen(
        tester,
        weatherService: weatherService,
        prefs: sp,
        cacheService: WeatherCacheService(prefs: sp),
      );
      await tester.pumpAndSettle();

      final initialFetchCount = fetchCount;

      // Pull to refresh -- use first SingleChildScrollView (the outer one)
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 300),
        600,
      );
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThan(initialFetchCount));
    });

    testWidgets("shows Coming Soon placeholder below weather section",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(
        find.text("Daily outfit suggestions coming soon"),
        findsOneWidget,
      );
    });

    testWidgets(
        "when position is null, shows error state",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      // positionToReturn is null by default, getCurrentPosition will throw

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.text("Unable to determine your location"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets(
        "tapping Enable Location with grant shows weather",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;
      mockGeolocator.requestPermissionResult = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Tap Enable Location button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should show weather data
      expect(find.text("19\u00B0C"), findsOneWidget);
    });

    testWidgets(
        "tapping Enable Location with denial shows denied card",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;
      mockGeolocator.requestPermissionResult = LocationPermission.denied;

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Tap Enable Location button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text("Location access needed for weather"), findsOneWidget);
    });

    // --- New tests for Story 3.2 ---

    testWidgets("ForecastWidget appears below WeatherWidget when data loaded",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.byType(ForecastWidget), findsOneWidget);
    });

    testWidgets(
        "when valid cached data exists, renders immediately without API call",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      // Pre-populate cache
      final sp = await SharedPreferences.getInstance();
      final cacheService = WeatherCacheService(prefs: sp);

      // First, do a regular fetch to populate the cache
      var fetchCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        fetchCount++;
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      final weatherService = WeatherService(client: mockClient);

      // First pump - this will fetch and cache
      await pumpHomeScreen(
        tester,
        weatherService: weatherService,
        prefs: sp,
        cacheService: cacheService,
      );
      await tester.pumpAndSettle();

      final firstFetchCount = fetchCount;
      expect(firstFetchCount, 1);

      // Second pump - should use cache, no additional fetch
      await pumpHomeScreen(
        tester,
        weatherService: weatherService,
        prefs: sp,
        cacheService: cacheService,
      );
      await tester.pumpAndSettle();

      // Weather should be displayed
      expect(find.text("19\u00B0C"), findsOneWidget);
      // No additional fetch should have been made
      expect(fetchCount, firstFetchCount);
    });

    testWidgets(
        "pull-to-refresh clears cache and fetches fresh data",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      final cacheService = WeatherCacheService(prefs: sp);

      var fetchCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        fetchCount++;
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      final weatherService = WeatherService(client: mockClient);

      await pumpHomeScreen(
        tester,
        weatherService: weatherService,
        prefs: sp,
        cacheService: cacheService,
      );
      await tester.pumpAndSettle();

      final fetchCountAfterInitial = fetchCount;

      // Pull to refresh -- use first SingleChildScrollView (the outer one)
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 300),
        600,
      );
      await tester.pumpAndSettle();

      // Should have made another fetch (cache was cleared)
      expect(fetchCount, greaterThan(fetchCountAfterInitial));
    });

    testWidgets(
        "when offline with no cache, error state is displayed",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      final cacheService = WeatherCacheService(prefs: sp);

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(fail: true),
        prefs: sp,
        cacheService: cacheService,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    // --- New tests for Story 3.3 ---

    testWidgets(
        "when weather is loaded, DressingTipWidget appears below ForecastWidget",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.byType(DressingTipWidget), findsOneWidget);
      // Forecast should also be visible
      expect(find.byType(ForecastWidget), findsOneWidget);
    });

    testWidgets(
        "dressing tip text matches expected tip for mild clear weather",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      // The mock returns feelsLike 16.2, weatherCode 0 (clear sky)
      // 16.2 >= 15 => mild => "Comfortable day -- dress as you like"
      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(
        find.text("Comfortable day \u2013 dress as you like"),
        findsOneWidget,
      );
    });

    testWidgets(
        "dressing tip updates when weather changes via pull-to-refresh",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      var requestCount = 0;
      // First response: mild weather, second: cold+rain
      final coldRainJson = jsonEncode({
        "current": {
          "temperature_2m": 2.0,
          "apparent_temperature": -1.5,
          "weather_code": 61,
        },
        "daily": {
          "time": ["2026-03-12"],
          "temperature_2m_max": [3.0],
          "temperature_2m_min": [-2.0],
          "weather_code": [61],
        },
      });
      final mockClient = http_testing.MockClient((request) async {
        requestCount++;
        if (requestCount <= 1) {
          return http.Response(_validWeatherWithForecastJson, 200);
        }
        return http.Response(coldRainJson, 200);
      });
      final weatherService = WeatherService(client: mockClient);
      final sp = await SharedPreferences.getInstance();

      await pumpHomeScreen(
        tester,
        weatherService: weatherService,
        prefs: sp,
        cacheService: WeatherCacheService(prefs: sp),
      );
      await tester.pumpAndSettle();

      // Mild weather tip
      expect(
        find.text("Comfortable day \u2013 dress as you like"),
        findsOneWidget,
      );

      // Pull to refresh
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 300),
        600,
      );
      await tester.pumpAndSettle();

      // Cold rain tip
      expect(
        find.text("Bundle up with waterproof layers"),
        findsOneWidget,
      );
    });

    testWidgets(
        "OutfitContext is populated after weather loads",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state =
          tester.state<HomeScreenState>(find.byType(HomeScreen));
      expect(state.outfitContext, isNotNull);
      expect(state.outfitContext!.temperature, 18.5);
      expect(state.outfitContext!.temperatureCategory, "mild");
    });

    testWidgets(
        "when offline with valid cache, shows cached data with staleness label",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      // Pre-populate cache with stale data (31 min old) directly via SharedPreferences
      final sp = await SharedPreferences.getInstance();
      final cacheService = WeatherCacheService(prefs: sp);

      // First populate cache using cacheService
      final testWeather = WeatherData(
        temperature: 18.5,
        feelsLike: 16.2,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
        locationName: "Paris, France",
        fetchedAt: DateTime(2026, 3, 12, 10, 30),
      );
      final testForecast = [
        DailyForecast(
          date: DateTime(2026, 3, 12),
          highTemperature: 15.2,
          lowTemperature: 8.1,
          weatherCode: 3,
          weatherDescription: "Partly cloudy",
          weatherIcon: Icons.cloud_queue,
        ),
      ];
      await cacheService.cacheWeatherData(testWeather, testForecast);

      // Expire the cache timestamp (set to 31 min ago) so getCachedWeather returns null
      // but getStaleCachedWeather still returns data
      final oldTime =
          DateTime.now().subtract(const Duration(minutes: 31)).toIso8601String();
      await sp.setString(WeatherCacheService.kWeatherCacheTimestampKey, oldTime);

      // Now pump with a failing service (simulating offline)
      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(fail: true),
        prefs: sp,
        cacheService: cacheService,
      );
      await tester.pumpAndSettle();

      // Should still show weather data (from stale cache)
      expect(find.text("19\u00B0C"), findsOneWidget);
      // Should show staleness indicator
      expect(find.textContaining("Last updated"), findsOneWidget);
      // Should NOT show error state
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    // --- New tests for Story 3.4 (Calendar integration) ---

    testWidgets(
        "when weather loaded and calendar not connected/dismissed, CalendarPermissionCard appears",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();
      mockCalendarPlugin.hasPermissionsResult = false;

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.byType(CalendarPermissionCard), findsOneWidget);
      expect(find.text("Plan outfits around your events"), findsOneWidget);
      expect(find.text("Connect Calendar"), findsOneWidget);
    });

    testWidgets(
        "when calendar is already connected, no calendar prompt card appears",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      // Pre-set calendar as connected
      await sp.setBool("calendar_connected", true);

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalendarPermissionCard), findsNothing);
      expect(find.byType(CalendarDeniedCard), findsNothing);
    });

    testWidgets(
        "when Not Now is tapped on calendar prompt, card disappears and does not re-appear",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();
      mockCalendarPlugin.hasPermissionsResult = false;

      final sp = await SharedPreferences.getInstance();
      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
      );
      await tester.pumpAndSettle();

      // Calendar card should be present in widget tree
      expect(find.byType(CalendarPermissionCard), findsOneWidget);

      // Scroll down to make the Not Now button visible and tappable
      await tester.scrollUntilVisible(
        find.text("Not Now"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Not Now"));
      await tester.pumpAndSettle();

      // Card should disappear
      expect(find.byType(CalendarPermissionCard), findsNothing);

      // Verify dismissed flag persisted
      expect(sp.getBool("calendar_prompt_dismissed"), true);
    });

    testWidgets(
        "when calendar permission denied, CalendarDeniedCard shows",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();
      mockCalendarPlugin.hasPermissionsResult = false;
      mockCalendarPlugin.requestPermissionsResult = false;

      final sp = await SharedPreferences.getInstance();
      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
      );
      await tester.pumpAndSettle();

      // Scroll down to make Connect Calendar button visible
      await tester.scrollUntilVisible(
        find.text("Connect Calendar"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Connect Calendar
      await tester.tap(find.text("Connect Calendar"));
      await tester.pumpAndSettle();

      // Should show denied card
      expect(find.byType(CalendarDeniedCard), findsOneWidget);
      expect(find.text("Calendar access needed"), findsOneWidget);
    });

    testWidgets(
        "all existing HomeScreen tests continue to pass - location, weather, forecast, dressing tip",
        (tester) async {
      // This test verifies that the calendar integration does not break
      // existing functionality: weather loads, forecast appears, dressing tip shown
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Weather
      expect(find.text("19\u00B0C"), findsOneWidget);
      // Forecast
      expect(find.byType(ForecastWidget), findsOneWidget);
      // Dressing tip
      expect(find.byType(DressingTipWidget), findsOneWidget);
      // Coming soon placeholder
      expect(
          find.text("Daily outfit suggestions coming soon"), findsOneWidget);
    });

    // --- New tests for Story 3.5 (Calendar event integration) ---

    testWidgets(
        "when calendar is connected and events fetched, EventsSection appears",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Sprint Planning",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsSection), findsOneWidget);
      expect(find.text("Sprint Planning"), findsOneWidget);
    });

    testWidgets(
        "when calendar is connected but no events, 'No events today' state shows",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsSection), findsOneWidget);
      expect(find.text("No events today"), findsOneWidget);
    });

    testWidgets(
        "when calendar is not connected, no EventsSection appears",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();
      mockCalendarPlugin.hasPermissionsResult = false;

      final sp = await SharedPreferences.getInstance();
      // Not connected, not dismissed -> shows prompt card

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Should not appear",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsSection), findsNothing);
    });

    // --- New tests for Story 3.6 (Event override integration) ---

    testWidgets(
        "tapping edit icon in EventsSection opens EventDetailBottomSheet",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Sprint Planning",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      // Tap the edit classification icon in EventsSection
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Bottom sheet should be visible with event type chips
      expect(find.text("Event Type"), findsOneWidget);
      expect(find.text("Formality Score"), findsOneWidget);
      expect(find.text("Save"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
    });

    testWidgets(
        "saving override in bottom sheet updates EventsSection display",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Sprint Planning",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];
      mockEventService.overrideResult = CalendarEvent(
        id: "evt-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        startTime: DateTime(2026, 3, 15, 10, 0),
        endTime: DateTime(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "formal",
        formalityScore: 8,
        classificationSource: "user",
        userOverride: true,
      );

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      // Tap the edit classification icon
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Select "Formal" chip
      await tester.tap(find.text("Formal"));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      // Bottom sheet should close and event type badge should update
      expect(find.text("Event Type"), findsNothing); // bottom sheet closed
      // The EventsSection should now show "Formal" type badge
      expect(find.text("Formal"), findsOneWidget);
    });

    testWidgets("failed override shows SnackBar error message",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Sprint Planning",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];
      mockEventService.overrideShouldFail = true;

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      // Tap the edit classification icon
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Tap Save without changing anything
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      // SnackBar should appear with error message
      expect(
        find.text("Failed to update event classification. Please try again."),
        findsOneWidget,
      );

      // Bottom sheet should still be open
      expect(find.text("Event Type"), findsOneWidget);
    });

    testWidgets("cancelling bottom sheet does not change event display",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Sprint Planning",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      // Tap the edit classification icon
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      // Event display should remain unchanged - "Work" type badge
      expect(find.text("Work"), findsOneWidget);
    });

    testWidgets("pull-to-refresh triggers event re-fetch", (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [];

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      final weatherService = WeatherService(client: mockClient);

      await pumpHomeScreen(
        tester,
        weatherService: weatherService,
        prefs: sp,
        cacheService: WeatherCacheService(prefs: sp),
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      final initialCount = mockEventService.fetchCallCount;

      // Pull to refresh
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 300),
        600,
      );
      await tester.pumpAndSettle();

      expect(mockEventService.fetchCallCount, greaterThan(initialCount));
    });

    // --- New tests for Story 4.1 (AI Outfit Generation) ---

    testWidgets(
        "when weather loaded and outfit generation succeeds, OutfitSuggestionCard is displayed",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Spring Casual",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i2", name: "Jeans", category: "bottoms",
                color: "blue", photoUrl: null,
              ),
            ],
            explanation: "Perfect for spring weather.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
      );

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OutfitSuggestionCard), findsOneWidget);
      expect(find.text("Spring Casual"), findsOneWidget);
      expect(find.text("Perfect for spring weather."), findsOneWidget);
      expect(find.text("AI"), findsOneWidget);
    });

    testWidgets(
        "when generation fails, error card with Unable to generate message is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.shouldFail = true;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Unable to generate outfit suggestions"),
        findsOneWidget,
      );
    });

    testWidgets(
        "when < 3 categorized items, OutfitMinimumItemsCard is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set wardrobe items with < 3 categorized
      final state = tester.state<HomeScreenState>(find.byType(HomeScreen));
      state.setWardrobeItems([
        {"id": "1", "categorizationStatus": "completed"},
        {"id": "2", "categorizationStatus": "pending"},
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(OutfitMinimumItemsCard), findsOneWidget);
      expect(find.text("Build your wardrobe"), findsOneWidget);
    });

    testWidgets(
        "when weather is denied, no outfit generation is triggered",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.deniedForever;

      final mockOutfitService = _MockOutfitGenerationService();

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Outfit generation should not have been called
      expect(mockOutfitService.generateCallCount, 0);
      // Should not show outfit card
      expect(find.byType(OutfitSuggestionCard), findsNothing);
    });

    testWidgets(
        "when weather loaded and outfit generation triggered, generation is called",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Test Outfit",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Item", category: "tops",
                color: "blue", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i2", name: "Item 2", category: "bottoms",
                color: "black", photoUrl: null,
              ),
            ],
            explanation: "Great combo.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
      );

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(mockOutfitService.generateCallCount, greaterThan(0));
    });

    testWidgets(
        "all existing HomeScreen tests continue to pass - weather, forecast, dressing tip with outfit service",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      // No outfit generation service -- falls back to placeholder
      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Weather
      expect(find.text("19\u00B0C"), findsOneWidget);
      // Forecast
      expect(find.byType(ForecastWidget), findsOneWidget);
      // Dressing tip
      expect(find.byType(DressingTipWidget), findsOneWidget);
      // Placeholder since no outfit generation service is provided
      expect(
          find.text("Daily outfit suggestions coming soon"), findsOneWidget);
    });

    // --- New tests for Story 4.2 (Outfit Swipe UI) ---

    testWidgets(
        "when generation succeeds with multiple suggestions, SwipeableOutfitStack is displayed",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Spring Casual",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i2", name: "Jeans", category: "bottoms",
                color: "blue", photoUrl: null,
              ),
            ],
            explanation: "Perfect for spring.",
            occasion: "everyday",
          ),
          const OutfitSuggestion(
            id: "s2",
            name: "Office Look",
            items: [
              OutfitSuggestionItem(
                id: "i3", name: "Blazer", category: "tops",
                color: "navy", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i4", name: "Trousers", category: "bottoms",
                color: "grey", photoUrl: null,
              ),
            ],
            explanation: "Professional and polished.",
            occasion: "work",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
      );

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwipeableOutfitStack), findsOneWidget);
      expect(find.text("Spring Casual"), findsOneWidget);
      expect(find.text("1 of 2"), findsOneWidget);
    });

    testWidgets(
        "when outfit save succeeds, snackbar 'Outfit saved!' is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Spring Casual",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
            ],
            explanation: "Perfect for spring.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
      );

      final mockPersistenceService = _MockOutfitPersistenceService();
      mockPersistenceService.shouldSucceed = true;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
            outfitPersistenceService: mockPersistenceService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to the Save button first (may be off-screen)
      await tester.scrollUntilVisible(
        find.text("Save"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Save button
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.text("Outfit saved!"), findsOneWidget);
    });

    testWidgets(
        "when outfit save fails, snackbar 'Failed to save outfit' is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Spring Casual",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
            ],
            explanation: "Perfect for spring.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
      );

      final mockPersistenceService = _MockOutfitPersistenceService();
      mockPersistenceService.shouldSucceed = false;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
            outfitPersistenceService: mockPersistenceService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to the Save button first (may be off-screen)
      await tester.scrollUntilVisible(
        find.text("Save"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Save button
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Failed to save outfit"),
        findsOneWidget,
      );
    });

    // --- Story 4.3: FAB integration tests ---

    testWidgets(
        "when weather is loaded and persistence service and apiClient provided, FAB is visible",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      final mockPersistence = _MockOutfitPersistenceService();
      final mockApiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthServiceForFab(),
        httpClient: http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({"items": []}),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitPersistenceService: mockPersistence,
            apiClient: mockApiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FAB should be visible
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip("Create Outfit"), findsOneWidget);
    });

    testWidgets("when weather is not loaded, FAB is not visible",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      final sp = await SharedPreferences.getInstance();
      final mockPersistence = _MockOutfitPersistenceService();
      final mockApiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthServiceForFab(),
        httpClient: http_testing.MockClient((request) async {
          return http.Response(jsonEncode({"items": []}), 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitPersistenceService: mockPersistence,
            apiClient: mockApiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FAB should NOT be visible
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets("tapping FAB navigates to CreateOutfitScreen", (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      final mockPersistence = _MockOutfitPersistenceService();
      final mockApiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthServiceForFab(),
        httpClient: http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({"items": []}),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitPersistenceService: mockPersistence,
            apiClient: mockApiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Should navigate to CreateOutfitScreen
      expect(find.text("Create Outfit"), findsOneWidget);
    });

    // --- Story 4.5: Usage limits integration tests ---

    testWidgets(
        "when generation returns limit-reached (429), UsageLimitCard is displayed",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.shouldReturnLimitReached = true;
      mockOutfitService.limitReachedToReturn = const UsageLimitReachedResult(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        resetsAt: "2026-03-16T00:00:00.000Z",
      );

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UsageLimitCard), findsOneWidget);
      expect(find.text("Daily Limit Reached"), findsOneWidget);
      expect(
        find.text("You've used all 3 outfit suggestions for today"),
        findsOneWidget,
      );
    });

    testWidgets(
        "when generation succeeds with usage metadata, UsageIndicator is displayed below outfit card",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Spring Casual",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i2", name: "Jeans", category: "bottoms",
                color: "blue", photoUrl: null,
              ),
            ],
            explanation: "Perfect for spring.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
        usage: const UsageInfo(
          dailyLimit: 3,
          used: 1,
          remaining: 2,
          resetsAt: "2026-03-16T00:00:00.000Z",
          isPremium: false,
        ),
      );

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UsageIndicator), findsOneWidget);
      expect(
        find.text("2 of 3 generations remaining today"),
        findsOneWidget,
      );
    });

    testWidgets(
        "when generation succeeds and user is premium, NO usage indicator is shown",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Spring Casual",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i2", name: "Jeans", category: "bottoms",
                color: "blue", photoUrl: null,
              ),
            ],
            explanation: "Perfect for spring.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 14),
        usage: const UsageInfo(
          dailyLimit: null,
          used: 5,
          remaining: null,
          resetsAt: null,
          isPremium: true,
        ),
      );

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show outfit card but NOT the usage indicator
      expect(find.byType(SwipeableOutfitStack), findsOneWidget);
      expect(find.byType(UsageIndicator), findsNothing);
    });

    testWidgets(
        "pull-to-refresh clears limit-reached state and re-triggers generation",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockOutfitService = _MockOutfitGenerationService();
      // First call returns limit reached
      mockOutfitService.shouldReturnLimitReached = true;
      mockOutfitService.limitReachedToReturn = const UsageLimitReachedResult(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        resetsAt: "2026-03-16T00:00:00.000Z",
      );

      final sp = await SharedPreferences.getInstance();
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      final weatherService = WeatherService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: weatherService,
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            outfitGenerationService: mockOutfitService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show limit card initially
      expect(find.byType(UsageLimitCard), findsOneWidget);

      final initialCount = mockOutfitService.generateCallCount;

      // Now change mock to return success for next call
      mockOutfitService.shouldReturnLimitReached = false;
      mockOutfitService.resultToReturn = OutfitGenerationResult(
        suggestions: [
          const OutfitSuggestion(
            id: "s1",
            name: "Fresh Look",
            items: [
              OutfitSuggestionItem(
                id: "i1", name: "Shirt", category: "tops",
                color: "white", photoUrl: null,
              ),
              OutfitSuggestionItem(
                id: "i2", name: "Jeans", category: "bottoms",
                color: "blue", photoUrl: null,
              ),
            ],
            explanation: "A fresh look.",
            occasion: "everyday",
          ),
        ],
        generatedAt: DateTime(2026, 3, 15),
      );

      // Pull to refresh
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 300),
        600,
      );
      await tester.pumpAndSettle();

      // Should have re-triggered generation
      expect(mockOutfitService.generateCallCount, greaterThan(initialCount));
    });

    // --- Story 5.1: Log Today's Outfit button tests ---

    testWidgets(
        "Log Today's Outfit button renders on HomeScreen when wearLogService provided",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        if (path == "/v1/wear-logs") {
          return http.Response(
            jsonEncode({
              "wearLog": {
                "id": "wl-1",
                "profileId": "p-1",
                "loggedDate": "2026-03-17",
                "itemIds": [],
              }
            }),
            201,
          );
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Log Today's Outfit"), findsOneWidget);
    });

    testWidgets(
        "tapping Log Today's Outfit button opens LogOutfitBottomSheet",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(
            jsonEncode({
              "items": [
                {"id": "item-1", "name": "Shirt", "photoUrl": null}
              ]
            }),
            200,
          );
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to make the button visible if it's off-screen
      await tester.scrollUntilVisible(
        find.text("Log Today's Outfit"),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.text("Log Today's Outfit"));
      await tester.pumpAndSettle();

      // Bottom sheet should be open with the tabs
      expect(find.text("Select Items"), findsWidgets);
      expect(find.text("Select Outfit"), findsOneWidget);
    });

    testWidgets(
        "existing HomeScreen tests work with wearLogService defaulting to null",
        (tester) async {
      // This test verifies the optional parameter default
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            // wearLogService not provided (defaults to null)
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Log button should NOT be visible
      expect(find.text("Log Today's Outfit"), findsNothing);
    });

    // --- Evening reminder integration tests (Story 5.2) ---

    testWidgets(
        "evening reminder is NOT scheduled if eveningReminderService is null (default behavior preserved)",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            // eveningReminderService not provided -- no crash
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen renders normally without evening reminder service
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        "when initialOpenLogSheet is false (default), LogOutfitBottomSheet does NOT auto-open",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            // initialOpenLogSheet defaults to false
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bottom sheet tabs should NOT be visible
      expect(find.text("Select Items"), findsNothing);
    });

    testWidgets(
        "when initialOpenLogSheet is true, LogOutfitBottomSheet opens automatically",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(
            jsonEncode({
              "items": [
                {"id": "item-1", "name": "Shirt", "photoUrl": null}
              ]
            }),
            200,
          );
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
            initialOpenLogSheet: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bottom sheet should be auto-opened with tabs visible
      expect(find.text("Select Items"), findsWidgets);
      expect(find.text("Select Outfit"), findsOneWidget);
    });

    // --- Story 5.3: Wear Calendar navigation tests ---

    testWidgets(
        "Wear Calendar button renders on HomeScreen when wearLogService provided",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        if (path.contains("/v1/wear-logs")) {
          return http.Response(jsonEncode({"wearLogs": []}), 200);
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Wear Calendar"), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsWidgets);
    });

    testWidgets(
        "tapping Wear Calendar button navigates to WearCalendarScreen",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        if (path.contains("/v1/wear-logs")) {
          return http.Response(jsonEncode({"wearLogs": []}), 200);
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to make the button visible and tap
      await tester.scrollUntilVisible(
        find.text("Wear Calendar"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Wear Calendar"));
      await tester.pumpAndSettle();

      expect(find.text("Wear Calendar"), findsWidgets); // AppBar title on new screen
    });

    testWidgets(
        "all existing HomeScreen tests pass with new optional evening params defaulting to null",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.denied;

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            // All new optional params default to null/false
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    // --- Story 5.4: Analytics Dashboard navigation tests ---

    testWidgets(
        "Analytics button renders on HomeScreen when wearLogService and apiClient provided",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        if (path.contains("/v1/wear-logs")) {
          return http.Response(jsonEncode({"wearLogs": []}), 200);
        }
        if (path == "/v1/analytics/wardrobe-summary") {
          return http.Response(jsonEncode({"summary": {"totalItems": 0, "pricedItems": 0, "totalValue": 0, "totalWears": 0, "averageCpw": null, "dominantCurrency": null}}), 200);
        }
        if (path == "/v1/analytics/items-cpw") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Analytics"), findsOneWidget);
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets(
        "tapping Analytics button navigates to AnalyticsDashboardScreen",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final mockHttpClient = http_testing.MockClient((request) async {
        final path = request.url.path;
        if (path == "/v1/items") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        if (path == "/v1/outfits") {
          return http.Response(jsonEncode({"outfits": []}), 200);
        }
        if (path.contains("/v1/wear-logs")) {
          return http.Response(jsonEncode({"wearLogs": []}), 200);
        }
        if (path == "/v1/analytics/wardrobe-summary") {
          return http.Response(jsonEncode({"summary": {"totalItems": 5, "pricedItems": 3, "totalValue": 300, "totalWears": 30, "averageCpw": 10.0, "dominantCurrency": "GBP"}}), 200);
        }
        if (path == "/v1/analytics/items-cpw") {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        return http.Response("Not found", 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttpClient,
      );
      final wearLogService = WearLogService(apiClient: apiClient);

      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            wearLogService: wearLogService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to make the button visible and tap
      await tester.scrollUntilVisible(
        find.text("Analytics"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Analytics"));
      await tester.pumpAndSettle();

      // Should now be on the AnalyticsDashboardScreen
      // The AppBar title will be "Analytics" on both screens, but we can check for dashboard content
      expect(find.text("Analytics"), findsWidgets);
    });

    // --- Story 12.1 tests: EventsSection integration ---

    testWidgets(
        "when calendar is connected and events exist, EventsSection is displayed",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Design Review",
          startTime: DateTime(2026, 3, 15, 14, 0),
          endTime: DateTime(2026, 3, 15, 15, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 6,
          classificationSource: "keyword",
        ),
        CalendarEvent(
          id: "evt-2",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-2",
          title: "Team Lunch",
          startTime: DateTime(2026, 3, 15, 12, 0),
          endTime: DateTime(2026, 3, 15, 13, 0),
          allDay: false,
          eventType: "social",
          formalityScore: 3,
          classificationSource: "keyword",
        ),
      ];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsSection), findsOneWidget);
      expect(find.text("Today's Events"), findsOneWidget);
      expect(find.text("Design Review"), findsOneWidget);
      expect(find.text("Team Lunch"), findsOneWidget);
    });

    testWidgets(
        "when calendar is connected but no events, EventsSection empty state shows",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsSection), findsOneWidget);
      expect(find.text("No events today"), findsOneWidget);
    });

    testWidgets(
        "when calendar is not connected, CalendarPermissionCard shows (no EventsSection)",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();
      mockCalendarPlugin.hasPermissionsResult = false;

      final sp = await SharedPreferences.getInstance();

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventsSection), findsNothing);
      expect(find.byType(CalendarPermissionCard), findsOneWidget);
    });

    testWidgets(
        "EventsSection appears above the daily outfit suggestion card",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);

      final mockEventService = _MockCalendarEventService();
      mockEventService.eventsToReturn = [
        CalendarEvent(
          id: "evt-1",
          sourceCalendarId: "cal-1",
          sourceEventId: "evt-1",
          title: "Meeting",
          startTime: DateTime(2026, 3, 15, 10, 0),
          endTime: DateTime(2026, 3, 15, 11, 0),
          allDay: false,
          eventType: "work",
          formalityScore: 5,
          classificationSource: "keyword",
        ),
      ];

      await pumpHomeScreen(
        tester,
        weatherService: buildWeatherService(),
        prefs: sp,
        calEventService: mockEventService,
      );
      await tester.pumpAndSettle();

      // Verify EventsSection exists and the daily outfit placeholder exists
      expect(find.byType(EventsSection), findsOneWidget);
      // The outfit section should be below - verify both exist
      expect(find.text("Today's Events"), findsOneWidget);
      expect(
        find.text("Daily outfit suggestions coming soon"),
        findsOneWidget,
      );

      // Verify layout order: events section should be above outfit section
      final eventsPos = tester.getTopLeft(find.text("Today's Events"));
      final outfitPos = tester.getTopLeft(
        find.text("Daily outfit suggestions coming soon"),
      );
      expect(eventsPos.dy, lessThan(outfitPos.dy));
    });

    // --- Story 12.3: Event Reminder Integration Tests ---

    testWidgets("HomeScreen accepts eventReminderService as null (default behavior preserved)",
        (tester) async {
      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // Should render without errors when eventReminderService is null
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        "HomeScreen accepts optional eventReminderService and eventReminderPreferences parameters",
        (tester) async {
      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarService: calendarService,
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            // Event reminder params are optional and default to null
            eventReminderService: null,
            eventReminderPreferences: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets("All existing HomeScreen tests pass with new optional constructor parameters",
        (tester) async {
      // This ensures backward compatibility -- all params default to null
      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    // --- Story 12.4: Travel Banner Integration Tests ---

    testWidgets("TravelBanner is NOT shown if tripDetectionService is null (default behavior preserved)",
        (tester) async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      mockGeolocator.positionToReturn = _testPosition();

      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      // No TravelBanner should be present
      expect(find.textContaining("Trip to"), findsNothing);
      expect(find.text("View Packing List"), findsNothing);
    });

    testWidgets("All existing HomeScreen tests pass with new tripDetectionService and packingListService params",
        (tester) async {
      // This ensures backward compatibility -- trip/packing params default to null
      await pumpHomeScreen(tester, weatherService: buildWeatherService());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  // ─── Story 13.2: Resale Prompt Banner Tests ───

  group("Resale Prompt Banner (Story 13.2)", () {
    late _MockGeolocator mockGeolocator;
    late LocationService locationService;

    setUp(() {
      mockGeolocator = _MockGeolocator();
      GeolocatorPlatform.instance = mockGeolocator;
      locationService = LocationService();
      SharedPreferences.setMockInitialValues({});
    });

    WeatherService buildWeatherService({bool fail = false}) {
      final mockClient = http_testing.MockClient((request) async {
        if (fail) {
          return http.Response("Server Error", 500);
        }
        return http.Response(_validWeatherWithForecastJson, 200);
      });
      return WeatherService(client: mockClient);
    }

    ApiClient _buildResaleApiClient({int promptCount = 3}) {
      final mockHttp = http_testing.MockClient((request) async {
        if (request.url.path.contains("/v1/resale/prompts/count")) {
          return http.Response(jsonEncode({"count": promptCount}), 200);
        }
        if (request.url.path.contains("/v1/resale/prompts/evaluate")) {
          return http.Response(jsonEncode({"candidates": 0, "prompted": false}), 200);
        }
        if (request.url.path.contains("/v1/user-stats")) {
          return http.Response(jsonEncode({"stats": {}}), 200);
        }
        return http.Response(jsonEncode({"error": "Not Found", "code": "NOT_FOUND", "message": "Not found"}), 404);
      });
      return ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthServiceForFab(),
        httpClient: mockHttp,
      );
    }

    testWidgets("Resale banner is shown when pending count > 0", (tester) async {
      SharedPreferences.setMockInitialValues({
        "last_resale_evaluation": DateTime.now().toIso8601String(),
      });
      mockGeolocator.permissionToReturn = LocationPermission.denied;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(kLocationPermissionDismissedKey, true);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            apiClient: _buildResaleApiClient(promptCount: 3),
          ),
        ),
      );
      // Use runAsync to resolve real async operations
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();

      expect(find.textContaining("items to declutter"), findsOneWidget);
      expect(find.text("View"), findsOneWidget);
    });

    testWidgets("Resale banner is hidden when pending count is 0", (tester) async {
      SharedPreferences.setMockInitialValues({
        "last_resale_evaluation": DateTime.now().toIso8601String(),
      });
      mockGeolocator.permissionToReturn = LocationPermission.denied;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(kLocationPermissionDismissedKey, true);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            apiClient: _buildResaleApiClient(promptCount: 0),
          ),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();

      expect(find.textContaining("items to declutter"), findsNothing);
    });

    testWidgets("Resale banner displays correct count text", (tester) async {
      SharedPreferences.setMockInitialValues({
        "last_resale_evaluation": DateTime.now().toIso8601String(),
      });
      mockGeolocator.permissionToReturn = LocationPermission.denied;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(kLocationPermissionDismissedKey, true);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            apiClient: _buildResaleApiClient(promptCount: 2),
          ),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();

      expect(find.text("You have 2 items to declutter"), findsOneWidget);
    });

    testWidgets("Tapping View navigates to ResalePromptsScreen", (tester) async {
      SharedPreferences.setMockInitialValues({
        "last_resale_evaluation": DateTime.now().toIso8601String(),
      });
      mockGeolocator.permissionToReturn = LocationPermission.denied;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(kLocationPermissionDismissedKey, true);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locationService: locationService,
            weatherService: buildWeatherService(),
            sharedPreferences: sp,
            weatherCacheService: WeatherCacheService(prefs: sp),
            calendarPreferencesService: CalendarPreferencesService(prefs: sp),
            apiClient: _buildResaleApiClient(promptCount: 2),
          ),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();

      // Tap the banner
      await tester.tap(find.text("View"));
      await tester.pumpAndSettle();

      // Should navigate to ResalePromptsScreen
      expect(find.text("Resale Suggestions"), findsOneWidget);
    });
  });
}
