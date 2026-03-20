import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:geolocator/geolocator.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/config/app_config.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/location/location_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/core/weather/weather_service.dart";
import "package:vestiaire_mobile/src/features/shell/screens/main_shell_screen.dart";

/// AuthService that returns a test token without requiring Firebase sign-in.
class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

/// Mock GeolocatorPlatform that returns denied permission by default.
class _MockGeolocator extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    throw const LocationServiceDisabledException();
  }

  @override
  Future<bool> openLocationSettings() async => true;
}

ApiClient _buildMockApiClient({
  List<Map<String, dynamic>> items = const [],
  bool failList = false,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    if (request.url.path == "/v1/outfits" && request.method == "GET") {
      return http.Response(
        jsonEncode({"outfits": []}),
        200,
      );
    }
    if (request.url.path.contains("/v1/items")) {
      if (failList) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      return http.Response(
        jsonEncode({"items": items}),
        200,
      );
    }
    if (request.url.path.contains("/v1/user-stats")) {
      return http.Response(
        jsonEncode({
          "stats": {
            "totalPoints": 50,
            "currentStreak": 2,
            "longestStreak": 3,
            "lastStreakDate": null,
            "streakFreezeUsedAt": null,
            "currentLevel": 1,
            "currentLevelName": "Closet Rookie",
            "nextLevelThreshold": 10,
            "itemCount": 5,
          }
        }),
        200,
      );
    }
    if (request.url.path.contains("/v1/profiles/me")) {
      return http.Response(
        jsonEncode({
          "profile": {
            "notificationPreferences": {},
            "onboardingCompletedAt": "2024-01-01",
          }
        }),
        200,
      );
    }
    if (request.url.path == "/v1/squads" && request.method == "GET") {
      return http.Response(
        jsonEncode({"squads": []}),
        200,
      );
    }
    return http.Response("{}", 200);
  });

  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _TestAuthService(),
    httpClient: mockHttp,
  );
}

LocationService _buildMockLocationService() {
  return LocationService(geolocator: _MockGeolocator());
}

WeatherService _buildMockWeatherService() {
  final mockClient = http_testing.MockClient((request) async {
    return http.Response(
      jsonEncode({
        "current": {
          "temperature_2m": 18.0,
          "apparent_temperature": 16.0,
          "weather_code": 0,
        },
      }),
      200,
    );
  });
  return WeatherService(client: mockClient);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("MainShellScreen", () {
    const config = AppConfig.fromEnvironment();

    testWidgets("renders 5 bottom navigation destinations with Social tab", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Home"), findsOneWidget);
      expect(find.text("Wardrobe"), findsOneWidget);
      expect(find.text("Social"), findsOneWidget);
      expect(find.text("Outfits"), findsOneWidget);
      expect(find.text("Profile"), findsOneWidget);
      // "Add" tab is no longer present
      expect(find.text("Add"), findsNothing);
    });

    testWidgets("FAB is visible for quick item/outfit creation", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Add item",
        ),
        findsOneWidget,
      );
    });

    testWidgets("FAB tapping pushes AddItemScreen route", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text("Add Item"), findsOneWidget);
      expect(find.text("Take Photo"), findsOneWidget);
      expect(find.text("Choose from Gallery"), findsOneWidget);
    });

    testWidgets("Home tab renders HomeScreen (not placeholder text)",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Old placeholder is gone
      expect(find.text("Home - Coming Soon"), findsNothing);
      // HomeScreen shows location permission card (since permission is denied
      // and not dismissed)
      expect(find.text("Enable Location"), findsWidgets);
    });

    testWidgets("LocationService and WeatherService are passed through",
        (tester) async {
      final locationService = _buildMockLocationService();
      final weatherService = _buildMockWeatherService();

      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: locationService,
            weatherService: weatherService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // HomeScreen is rendered with the services (verified by seeing
      // permission card, which means LocationService was used)
      expect(find.text("Enable Location"), findsWidgets);
    });

    testWidgets("tapping Wardrobe tab shows wardrobe content", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Wardrobe"));
      await tester.pumpAndSettle();

      expect(
        find.text("Your wardrobe is empty.\nTap + to add your first item!"),
        findsOneWidget,
      );
    });

    testWidgets("Social tab navigates to SquadListScreen", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Social"));
      await tester.pumpAndSettle();

      // SquadListScreen shows empty state
      expect(find.text("Your Style Squads"), findsOneWidget);
      expect(find.text("Create Squad"), findsOneWidget);
      expect(find.text("Join Squad"), findsOneWidget);
    });

    testWidgets(
        "tapping Outfits tab displays OutfitHistoryScreen (not placeholder)",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Outfits"));
      await tester.pumpAndSettle();

      // Should NOT show the placeholder
      expect(find.text("Outfits - Coming Soon"), findsNothing);
      // Should show the empty state from OutfitHistoryScreen
      expect(find.text("No outfits saved yet"), findsOneWidget);
    });

    testWidgets(
        "Outfits placeholder is shown when apiClient is null",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: null,
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Outfits tab (index 3)
      await tester.tap(find.text("Outfits"));
      await tester.pumpAndSettle();

      expect(find.text("Outfits - Coming Soon"), findsOneWidget);
    });

    testWidgets("tapping Profile tab shows profile content with sign-out",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            onSignOut: () {},
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Profile"));
      await tester.pump();

      // Let the async getUserStats call complete
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Profile tab now shows ProfileScreen with gamification data
      expect(find.text("Closet Rookie"), findsOneWidget);

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Sign out",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Profile tab has notification settings button",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Profile"));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Notification settings",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Profile tab has Delete Account button", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            onDeleteAccount: () async {},
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Profile"));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text("Delete Account"), findsOneWidget);
    });

    testWidgets("Profile tab displays gamification header with level data",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShellScreen(
            config: config,
            apiClient: _buildMockApiClient(),
            locationService: _buildMockLocationService(),
            weatherService: _buildMockWeatherService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Profile"));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text("Closet Rookie"), findsOneWidget);
      expect(find.text("Level 1"), findsOneWidget);
    });
  });
}
