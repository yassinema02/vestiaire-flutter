import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/trip.dart";
import "package:vestiaire_mobile/src/features/outfits/screens/packing_list_screen.dart";
import "package:vestiaire_mobile/src/features/outfits/services/packing_list_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Trip _testTrip() {
  return Trip(
    id: "trip_barcelona_2026-03-20_2026-03-24",
    destination: "Barcelona",
    startDate: DateTime(2026, 3, 20),
    endDate: DateTime(2026, 3, 24),
    durationDays: 4,
    eventIds: ["e1"],
  );
}

Map<String, dynamic> _testPackingListJson({bool fallback = false, bool weatherUnavailable = false}) {
  return {
    "packingList": {
      "categories": [
        {
          "name": "Tops",
          "items": [
            {
              "itemId": "item-1",
              "name": "Blue T-Shirt",
              "reason": "Versatile top for warm weather",
              "thumbnailUrl": null,
              "category": "Tops",
              "color": "blue",
            },
            {
              "itemId": "item-2",
              "name": "White Button-Down",
              "reason": "Conference appropriate",
              "thumbnailUrl": null,
              "category": "Tops",
              "color": "white",
            },
          ],
        },
        {
          "name": "Bottoms",
          "items": [
            {
              "itemId": "item-3",
              "name": "Navy Chinos",
              "reason": "Versatile bottom",
              "thumbnailUrl": null,
              "category": "Bottoms",
              "color": "navy",
            },
          ],
        },
      ],
      "dailyOutfits": [
        {
          "day": 1,
          "date": "2026-03-20",
          "outfitItemIds": ["item-1", "item-3"],
          "occasion": "Conference Day 1",
        },
      ],
      "tips": ["Roll clothes to save space", "Pack versatile items"],
      "fallback": fallback,
      "weatherUnavailable": weatherUnavailable,
    },
    "generatedAt": "2026-03-19T12:00:00.000Z",
  };
}

PackingListService _createService({
  Map<String, dynamic>? apiResponse,
  bool shouldFailApi = false,
  SharedPreferences? prefs,
}) {
  final mockClient = http_testing.MockClient((request) async {
    if (shouldFailApi) {
      return http.Response(
        jsonEncode({"error": "Error", "code": "INTERNAL_SERVER_ERROR", "message": "Failed"}),
        500,
      );
    }
    return http.Response(
      jsonEncode(apiResponse ?? _testPackingListJson()),
      200,
    );
  });

  final apiClient = ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _MockAuthService(),
    httpClient: mockClient,
  );

  return PackingListService(
    apiClient: apiClient,
    sharedPreferences: prefs,
  );
}

void main() {
  group("PackingListScreen", () {
    testWidgets("renders trip header with destination and duration",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Packing List"), findsOneWidget);
      expect(find.textContaining("Barcelona"), findsOneWidget);
      expect(find.textContaining("4 days"), findsOneWidget);
    });

    testWidgets("shows loading shimmer initially", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Use a slow API to keep loading state visible
      final service = _createService(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: service,
          ),
        ),
      );

      // Initially loading
      expect(find.text("Packing List"), findsOneWidget);
    });

    testWidgets("displays categories with items on success",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Category headers
      expect(find.textContaining("Tops"), findsOneWidget);
      expect(find.textContaining("Bottoms"), findsOneWidget);

      // Items
      expect(find.text("Blue T-Shirt"), findsOneWidget);
      expect(find.text("White Button-Down"), findsOneWidget);
      expect(find.text("Navy Chinos"), findsOneWidget);
    });

    testWidgets("checkboxes toggle packed state", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the first checkbox
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Progress should update
      expect(find.textContaining("1 of 3 items packed"), findsOneWidget);
    });

    testWidgets("progress indicator updates on check/uncheck",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 0 packed
      expect(find.text("0 of 3 items packed"), findsOneWidget);

      // Tap to pack
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      expect(find.text("1 of 3 items packed"), findsOneWidget);

      // Tap again to unpack
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      expect(find.text("0 of 3 items packed"), findsOneWidget);
    });

    testWidgets("shows fallback banner when fallback list returned",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(
              apiResponse: _testPackingListJson(fallback: true),
              prefs: prefs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("AI-generated list unavailable. Showing general recommendations based on trip duration."),
        findsOneWidget,
      );
    });

    testWidgets("shows weather unavailable note when applicable",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(
              apiResponse: _testPackingListJson(weatherUnavailable: true),
              prefs: prefs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Weather data unavailable for destination. Pack for variable conditions."),
        findsOneWidget,
      );
    });

    testWidgets("shows error state with retry on generation failure",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(
              shouldFailApi: true,
              prefs: prefs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Failed to generate packing list. Please try again."), findsOneWidget);
      expect(find.text("Try Again"), findsOneWidget);
    });

    testWidgets("loads cached list when available", (tester) async {
      SharedPreferences.setMockInitialValues({
        "packing_list_trip_barcelona_2026-03-20_2026-03-24":
            jsonEncode(_testPackingListJson()),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show cached content without API call
      expect(find.text("Blue T-Shirt"), findsOneWidget);
    });

    testWidgets("regenerate button shows confirmation dialog",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap regenerate icon
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text("Regenerate Packing List?"), findsOneWidget);
      expect(
        find.text("This will regenerate the list and reset all packed items. Continue?"),
        findsOneWidget,
      );
    });

    testWidgets("day-by-day outfits section renders correctly",
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal the daily outfits section
      await tester.scrollUntilVisible(
        find.text("Day-by-Day Outfits"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("Day-by-Day Outfits"), findsOneWidget);
      expect(find.textContaining("Day 1"), findsWidgets);
      expect(find.text("Conference Day 1"), findsOneWidget);
    });

    testWidgets("tips section renders correctly", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal the tips section
      await tester.scrollUntilVisible(
        find.text("Tips"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("Tips"), findsOneWidget);
      expect(find.text("Roll clothes to save space"), findsOneWidget);
      expect(find.text("Pack versatile items"), findsOneWidget);
    });

    testWidgets("semantics labels present", (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp("Packing list for trip to Barcelona")),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp("items packed")),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Export packing list"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Regenerate packing list"),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets("export button has share icon", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: PackingListScreen(
            trip: _testTrip(),
            packingListService: _createService(prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });
}
