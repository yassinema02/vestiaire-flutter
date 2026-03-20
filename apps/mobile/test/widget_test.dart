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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("MainShellScreen displays navigation and profile content",
      (tester) async {
    const config = AppConfig.fromEnvironment();

    final mockHttp = http_testing.MockClient((request) async {
      if (request.url.path.contains("/v1/items")) {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/squads" && request.method == "GET") {
        return http.Response(jsonEncode({"squads": []}), 200);
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
      return http.Response(jsonEncode({}), 200);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _TestAuthService(),
      httpClient: mockHttp,
    );

    final locationService = LocationService(geolocator: _MockGeolocator());
    final weatherService = WeatherService(
      client: http_testing.MockClient((request) async {
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
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScreen(
          config: config,
          apiClient: apiClient,
          locationService: locationService,
          weatherService: weatherService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Home"), findsOneWidget);
    expect(find.text("Wardrobe"), findsOneWidget);
    expect(find.text("Social"), findsOneWidget);
    expect(find.text("Outfits"), findsOneWidget);
    expect(find.text("Profile"), findsOneWidget);

    // Navigate to Profile tab to see profile screen with gamification header
    await tester.tap(find.text("Profile"));
    await tester.pump();

    // Let the async getUserStats call complete
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Profile tab now shows gamification data from ProfileScreen
    expect(find.text("Closet Rookie"), findsOneWidget);
    expect(find.text("Level 1"), findsOneWidget);
  });
}
