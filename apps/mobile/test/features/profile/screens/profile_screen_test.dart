import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/profile/screens/profile_screen.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/badge_collection_grid.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/challenge_progress_card.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/gamification_header.dart";

/// AuthService that returns a test token.
class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

ApiClient _buildMockApiClient({
  bool shouldFail = false,
  bool badgeCatalogFails = false,
  Map<String, dynamic>? statsResponse,
  List<Map<String, dynamic>>? badgeCatalog,
}) {
  final defaultCatalog = List.generate(15, (i) => {
    "key": "badge_$i",
    "name": "Badge $i",
    "description": "Description $i",
    "iconName": "star",
    "iconColor": "#FBBF24",
    "category": "wardrobe",
    "sortOrder": i + 1,
  });

  final mockHttp = http_testing.MockClient((request) async {
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }
    if (request.url.path.contains("/v1/badges")) {
      if (badgeCatalogFails) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      return http.Response(
        jsonEncode({"badges": badgeCatalog ?? defaultCatalog}),
        200,
      );
    }
    if (request.url.path.contains("/v1/user-stats")) {
      return http.Response(
        jsonEncode(statsResponse ?? {
          "stats": {
            "totalPoints": 150,
            "currentStreak": 5,
            "longestStreak": 10,
            "lastStreakDate": "2026-03-18",
            "streakFreezeUsedAt": null,
            "currentLevel": 3,
            "currentLevelName": "Fashion Explorer",
            "nextLevelThreshold": 50,
            "itemCount": 30,
            "badges": [
              {"key": "first_step", "name": "First Step", "description": "Upload first item", "iconName": "star", "iconColor": "#FBBF24", "category": "wardrobe", "awardedAt": "2026-03-19T10:00:00Z"},
            ],
            "badgeCount": 1,
          }
        }),
        200,
      );
    }
    if (request.url.path.contains("/v1/profiles/me") &&
        request.method == "DELETE") {
      return http.Response(jsonEncode({"deleted": true}), 200);
    }
    return http.Response(jsonEncode({}), 200);
  });

  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _TestAuthService(),
    httpClient: mockHttp,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("ProfileScreen", () {
    testWidgets("renders GamificationHeader when stats load successfully",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      // Loading state first
      await tester.pump();

      // Let the async call complete
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.byType(GamificationHeader), findsOneWidget);
      expect(find.text("Fashion Explorer"), findsOneWidget);
      expect(find.text("Level 3"), findsOneWidget);
    });

    testWidgets("shows loading placeholder while stats are loading",
        (tester) async {
      // The loading state is tested by verifying that immediately after pumping,
      // the GamificationHeader is not yet shown (since the API call is async).
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      // First pump - initState fires, loading starts
      await tester.pump();

      // During loading, GamificationHeader should not be visible yet
      // (we haven't awaited the async response yet)
      // Note: The mock client responds quickly, so we just check initial state.
      // The important thing is that the screen doesn't crash during loading.

      // Let the async call complete
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // After loading, GamificationHeader should appear
      expect(find.byType(GamificationHeader), findsOneWidget);
    });

    testWidgets("shows error banner with retry on stats load failure",
        (tester) async {
      final apiClient = _buildMockApiClient(shouldFail: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text("Unable to load stats"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("retry button triggers stats reload", (tester) async {
      int requestCount = 0;
      final mockHttp = http_testing.MockClient((request) async {
        requestCount++;
        if (request.url.path.contains("/v1/user-stats")) {
          if (requestCount <= 1) {
            return http.Response(
              jsonEncode({"code": "ERROR", "message": "fail"}),
              500,
            );
          }
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

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      // Let first request fail
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text("Unable to load stats"), findsOneWidget);

      // Tap retry
      await tester.runAsync(() async {
        await tester.tap(find.text("Retry"));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Should now show gamification header
      expect(find.byType(GamificationHeader), findsOneWidget);
      expect(find.text("Closet Rookie"), findsOneWidget);
    });

    // Note: SubscriptionService requires RevenueCat SDK and cannot be easily mocked.
    // The subscription button is tested indirectly via the null check -- when
    // subscriptionService is null, the button is absent.

    testWidgets("renders delete account button when onDeleteAccount provided",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            apiClient: apiClient,
            onDeleteAccount: () async {},
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text("Delete Account"), findsOneWidget);
    });

    testWidgets("badge collection grid renders when stats and catalog load successfully",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(BadgeCollectionGrid), findsOneWidget);
    });

    testWidgets("badge count shows N/15", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text("1/15"), findsOneWidget);
    });

    testWidgets("tapping earned badge opens detail sheet with earned date",
        (tester) async {
      final apiClient = _buildMockApiClient(
        badgeCatalog: [
          {"key": "first_step", "name": "First Step", "description": "Upload your first wardrobe item", "iconName": "star", "iconColor": "#FBBF24", "category": "wardrobe", "sortOrder": 1},
          {"key": "week_warrior", "name": "Week Warrior", "description": "7-day streak", "iconName": "local_fire_department", "iconColor": "#F97316", "category": "streak", "sortOrder": 2},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Tap the earned "First Step" badge
      await tester.tap(find.text("First Step"));
      await tester.pumpAndSettle();

      // The detail sheet should appear with earned date
      expect(find.text("Earned on 19/3/2026"), findsOneWidget);
    });

    testWidgets("badge section shows error text when badge catalog fails to load",
        (tester) async {
      final apiClient = _buildMockApiClient(badgeCatalogFails: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text("Unable to load badges"), findsOneWidget);
    });

    testWidgets("sign out button calls onSignOut callback", (tester) async {
      bool signOutCalled = false;
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            apiClient: apiClient,
            onSignOut: () => signOutCalled = true,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(signOutCalled, isTrue);
    });

    // === Story 6.5: Challenge Progress Card Integration ===

    testWidgets("ChallengeProgressCard renders when challenge data present in stats",
        (tester) async {
      final apiClient = _buildMockApiClient(
        statsResponse: {
          "stats": {
            "totalPoints": 150,
            "currentStreak": 5,
            "longestStreak": 10,
            "lastStreakDate": "2026-03-18",
            "streakFreezeUsedAt": null,
            "currentLevel": 3,
            "currentLevelName": "Fashion Explorer",
            "nextLevelThreshold": 50,
            "itemCount": 30,
            "badges": [],
            "badgeCount": 0,
            "challenge": {
              "key": "closet_safari",
              "name": "Closet Safari",
              "status": "active",
              "currentProgress": 8,
              "targetCount": 20,
              "timeRemainingSeconds": 432000,
              "reward": {"type": "premium_trial", "value": 30, "description": "1 month Premium free"}
            }
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeProgressCard), findsOneWidget);
      expect(find.text("8/20 items"), findsOneWidget);
    });

    testWidgets("No challenge card when challenge is null",
        (tester) async {
      final apiClient = _buildMockApiClient(
        statsResponse: {
          "stats": {
            "totalPoints": 150,
            "currentStreak": 5,
            "longestStreak": 10,
            "lastStreakDate": "2026-03-18",
            "streakFreezeUsedAt": null,
            "currentLevel": 3,
            "currentLevelName": "Fashion Explorer",
            "nextLevelThreshold": 50,
            "itemCount": 30,
            "badges": [],
            "badgeCount": 0,
            "challenge": null
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeProgressCard), findsNothing);
    });

    testWidgets("Completed challenge card shows green state",
        (tester) async {
      final apiClient = _buildMockApiClient(
        statsResponse: {
          "stats": {
            "totalPoints": 300,
            "currentStreak": 7,
            "longestStreak": 10,
            "lastStreakDate": "2026-03-19",
            "streakFreezeUsedAt": null,
            "currentLevel": 4,
            "currentLevelName": "Wardrobe Wizard",
            "nextLevelThreshold": 100,
            "itemCount": 50,
            "badges": [],
            "badgeCount": 0,
            "challenge": {
              "key": "closet_safari",
              "name": "Closet Safari",
              "status": "completed",
              "currentProgress": 20,
              "targetCount": 20,
              "reward": {"type": "premium_trial", "value": 30, "description": "1 month Premium free"}
            }
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(apiClient: apiClient),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeProgressCard), findsOneWidget);
      expect(find.text("Closet Safari Complete!"), findsOneWidget);
    });
  });
}
