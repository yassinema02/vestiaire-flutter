import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/analytics/services/wear_log_service.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/log_outfit_bottom_sheet.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Build a mock ApiClient whose underlying HTTP mock serves items and outfits.
ApiClient _buildMockApiClient({
  List<Map<String, dynamic>>? items,
  List<Map<String, dynamic>>? outfits,
  Map<String, dynamic>? pointsAwarded,
  Map<String, dynamic>? streakUpdate,
  List<Map<String, dynamic>>? badgesAwarded,
}) {
  final mockClient = http_testing.MockClient((request) async {
    final path = request.url.path;

    if (path == "/v1/items") {
      return http.Response(
        jsonEncode({"items": items ?? []}),
        200,
      );
    }

    if (path == "/v1/outfits") {
      return http.Response(
        jsonEncode({"outfits": outfits ?? []}),
        200,
      );
    }

    if (path == "/v1/wear-logs" && request.method == "POST") {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final responseBody = <String, dynamic>{
        "wearLog": {
          "id": "wl-1",
          "profileId": "p-1",
          "loggedDate": "2026-03-17",
          "outfitId": body["outfitId"],
          "itemIds": body["items"],
        },
      };
      if (pointsAwarded != null) {
        responseBody["pointsAwarded"] = pointsAwarded;
      }
      if (streakUpdate != null) {
        responseBody["streakUpdate"] = streakUpdate;
      }
      if (badgesAwarded != null) {
        responseBody["badgesAwarded"] = badgesAwarded;
      }
      return http.Response(
        jsonEncode(responseBody),
        201,
      );
    }

    return http.Response("Not found", 404);
  });

  return ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _FakeAuthService(),
    httpClient: mockClient,
  );
}

void main() {
  group("LogOutfitBottomSheet", () {
    testWidgets("renders Select Items tab by default", (tester) async {
      final apiClient = _buildMockApiClient();
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.text("Select Items"), findsOneWidget);
      expect(find.text("Select Outfit"), findsOneWidget);
    });

    testWidgets("displays wardrobe items in grid with selectable checkboxes",
        (tester) async {
      final apiClient = _buildMockApiClient(items: [
        {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        {"id": "item-2", "name": "Red Pants", "photoUrl": null},
      ]);
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.text("Blue Shirt"), findsOneWidget);
      expect(find.text("Red Pants"), findsOneWidget);
    });

    testWidgets("selecting items updates the Log X Items button count",
        (tester) async {
      final apiClient = _buildMockApiClient(items: [
        {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        {"id": "item-2", "name": "Red Pants", "photoUrl": null},
      ]);
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Initially shows "Select Items" button
      expect(find.text("Select Items"), findsWidgets);

      // Tap on first item
      await tester.tap(find.text("Blue Shirt"));
      await tester.pump();

      expect(find.text("Log 1 Items"), findsOneWidget);

      // Tap on second item
      await tester.tap(find.text("Red Pants"));
      await tester.pump();

      expect(find.text("Log 2 Items"), findsOneWidget);
    });

    testWidgets("switching to Select Outfit tab shows saved outfits",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [],
        outfits: [
          {
            "id": "outfit-1",
            "name": "Work Outfit",
            "occasion": "work",
            "items": [
              {"id": "item-1"}
            ]
          },
        ],
      );
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Switch to outfits tab
      await tester.tap(find.text("Select Outfit"));
      await tester.pumpAndSettle();

      expect(find.text("Work Outfit"), findsOneWidget);
      expect(find.text("1 items \u00b7 work"), findsOneWidget);
    });

    testWidgets("tapping an outfit enables the Log Outfit button",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [],
        outfits: [
          {
            "id": "outfit-1",
            "name": "Work Outfit",
            "occasion": "work",
            "items": [
              {"id": "item-1"}
            ]
          },
        ],
      );
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Select Outfit"));
      await tester.pumpAndSettle();

      // Tap the outfit
      await tester.tap(find.text("Work Outfit"));
      await tester.pump();

      // Check icon appears
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets("onLogged callback fires after successful log",
        (tester) async {
      bool loggedCalled = false;
      final apiClient = _buildMockApiClient(items: [
        {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
      ]);
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                      onLogged: () {
                        loggedCalled = true;
                      },
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Select an item
      await tester.tap(find.text("Blue Shirt"));
      await tester.pump();

      // Confirm
      await tester.tap(find.text("Log 1 Items"));
      await tester.pumpAndSettle();

      expect(loggedCalled, isTrue);
    });

    testWidgets("semantics labels present", (tester) async {
      final apiClient = _buildMockApiClient(items: [
        {"id": "item-1", "name": "Shirt", "photoUrl": null},
      ]);
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Verify Semantics widgets exist by finding the wrapping Semantics
      // The bottom sheet title is present
      expect(find.text("Log Today's Outfit"), findsOneWidget);
      // Tab labels are present
      expect(find.text("Select Items"), findsWidgets);
      expect(find.text("Select Outfit"), findsOneWidget);
      // Items grid has Semantics wrapping
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets("empty wardrobe shows Add items message", (tester) async {
      final apiClient = _buildMockApiClient(items: []);
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(
          find.text("Add items to your wardrobe first"), findsOneWidget);
    });

    testWidgets("empty outfits list shows No saved outfits message",
        (tester) async {
      final apiClient = _buildMockApiClient(outfits: []);
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Switch to outfits tab
      await tester.tap(find.text("Select Outfit"));
      await tester.pumpAndSettle();

      expect(find.text("No saved outfits yet"), findsOneWidget);
    });

    // === Story 6.1: Style Points Integration ===

    testWidgets(
        "WearLogService returns pointsAwarded from API response",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
        pointsAwarded: {
          "pointsAwarded": 7,
          "totalPoints": 25,
          "currentStreak": 0,
          "bonuses": {"firstLogOfDay": 2, "streakDay": 0},
          "action": "wear_log",
        },
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.wearLog.id, "wl-1");
      expect(result.pointsAwarded, isNotNull);
      expect(result.pointsAwarded!["pointsAwarded"], 7);
      expect(result.pointsAwarded!["bonuses"]["firstLogOfDay"], 2);
    });

    testWidgets(
        "WearLogService returns pointsAwarded with streak bonus from API response",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
        pointsAwarded: {
          "pointsAwarded": 10,
          "totalPoints": 50,
          "currentStreak": 3,
          "bonuses": {"firstLogOfDay": 2, "streakDay": 3},
          "action": "wear_log",
        },
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.pointsAwarded, isNotNull);
      expect(result.pointsAwarded!["pointsAwarded"], 10);
      expect(result.pointsAwarded!["bonuses"]["streakDay"], 3);
      expect(result.pointsAwarded!["bonuses"]["firstLogOfDay"], 2);
    });

    // === Story 6.3: Streak Toast Integration ===

    testWidgets(
        "WearLogService returns streakUpdate from API response",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
        streakUpdate: {
          "currentStreak": 5,
          "longestStreak": 10,
          "isNewStreak": false,
          "streakExtended": true,
          "streakFreezeAvailable": true,
        },
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.streakUpdate, isNotNull);
      expect(result.streakUpdate!["currentStreak"], 5);
      expect(result.streakUpdate!["streakExtended"], true);
    });

    testWidgets(
        "WearLogService returns null streakUpdate when not in API response",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.streakUpdate, isNull);
    });

    testWidgets(
        "WearLogService correctly parses streakUpdate with streakExtended=true",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
        pointsAwarded: {
          "pointsAwarded": 8,
          "totalPoints": 50,
          "currentStreak": 5,
          "bonuses": {"firstLogOfDay": 0, "streakDay": 3},
          "action": "wear_log",
        },
        streakUpdate: {
          "currentStreak": 5,
          "longestStreak": 10,
          "isNewStreak": false,
          "streakExtended": true,
          "streakFreezeAvailable": true,
        },
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.streakUpdate, isNotNull);
      expect(result.streakUpdate!["streakExtended"], true);
      expect(result.streakUpdate!["currentStreak"], 5);
      expect(result.streakUpdate!["isNewStreak"], false);
      // Verify both points and streak data are returned together
      expect(result.pointsAwarded, isNotNull);
      expect(result.pointsAwarded!["bonuses"]["streakDay"], 3);
    });

    testWidgets(
        "No streak toast when streakUpdate is null",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
        pointsAwarded: {
          "pointsAwarded": 5,
          "totalPoints": 25,
          "currentStreak": 0,
          "bonuses": {"firstLogOfDay": 0, "streakDay": 0},
          "action": "wear_log",
        },
      );
      final service = WearLogService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LogOutfitBottomSheet(
                      wearLogService: service,
                      apiClient: apiClient,
                    ),
                  );
                },
                child: const Text("Open"),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Select an item
      await tester.tap(find.text("Blue Shirt"));
      await tester.pump();

      // Confirm
      await tester.tap(find.text("Log 1 Items"));
      await tester.pumpAndSettle();

      // Wait for any potential streak toast
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // No streak toast should appear
      expect(find.textContaining("Day Streak!"), findsNothing);
    });

    // === Story 6.4: Badge Modal Integration ===

    testWidgets(
        "WearLogService returns badgesAwarded from API response",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
        badgesAwarded: [
          {"key": "first_step", "name": "First Step", "description": "Upload first item", "iconName": "star", "iconColor": "#FBBF24"},
        ],
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.badgesAwarded, isNotNull);
      expect(result.badgesAwarded!.length, 1);
      expect(result.badgesAwarded![0]["key"], "first_step");
    });

    testWidgets(
        "WearLogService returns null badgesAwarded when not in API response",
        (tester) async {
      final apiClient = _buildMockApiClient(
        items: [
          {"id": "item-1", "name": "Blue Shirt", "photoUrl": null},
        ],
      );
      final service = WearLogService(apiClient: apiClient);

      late WearLogResult result;
      await tester.runAsync(() async {
        result = await service.logItems(["item-1"]);
      });

      expect(result.badgesAwarded, isNull);
    });
  });
}

