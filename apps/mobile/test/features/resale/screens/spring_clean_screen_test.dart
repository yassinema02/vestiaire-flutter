import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/screens/spring_clean_screen.dart";
import "package:vestiaire_mobile/src/features/resale/services/donation_service.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

final _sampleItems = [
  {
    "id": "item-1",
    "name": "Old Shirt",
    "category": "tops",
    "brand": "Nike",
    "photoUrl": "",
    "daysUnworn": 200,
    "estimatedValue": 15,
    "wearCount": 3,
    "resaleStatus": null,
    "neglectStatus": "neglected",
  },
  {
    "id": "item-2",
    "name": "Vintage Jacket",
    "category": "outerwear",
    "brand": "Zara",
    "photoUrl": "",
    "daysUnworn": 250,
    "estimatedValue": 30,
    "wearCount": 1,
    "resaleStatus": null,
    "neglectStatus": "neglected",
  },
];

ApiClient _buildMockApiClient({
  List<Map<String, dynamic>>? items,
  bool shouldFail = false,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }

    if (request.url.path == "/v1/spring-clean/items") {
      return http.Response(
        jsonEncode({"items": items ?? _sampleItems}),
        200,
      );
    }

    if (request.url.path == "/v1/donations" && request.method == "POST") {
      return http.Response(
        jsonEncode({
          "donation": {"id": "d1", "itemId": "item-1"},
          "item": {"id": "item-1", "resaleStatus": "donated"},
        }),
        201,
      );
    }

    return http.Response(jsonEncode({"code": "NOT_FOUND"}), 404);
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

  group("SpringCleanScreen", () {
    testWidgets("shows loading indicator during fetch", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets("displays item card with name, category, days unworn, estimated value",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Old Shirt"), findsOneWidget);
      expect(find.textContaining("Not worn in 200 days"), findsOneWidget);
      expect(find.textContaining("15 GBP"), findsOneWidget);
    });

    testWidgets("progress indicator shows Reviewing X of Y items",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Reviewing 1 of 2 items"), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets("Keep button advances to next item", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Old Shirt"), findsOneWidget);

      await tester.tap(find.text("Keep"));
      await tester.pumpAndSettle();

      expect(find.text("Vintage Jacket"), findsOneWidget);
      expect(find.textContaining("Reviewing 2 of 2 items"), findsOneWidget);
    });

    testWidgets("Sell button adds item to sell queue and advances",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Sell"));
      await tester.pumpAndSettle();

      expect(find.text("Vintage Jacket"), findsOneWidget);
    });

    testWidgets("Donate button shows bottom sheet with charity field",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Donate"));
      await tester.pumpAndSettle();

      expect(find.text("Donate Old Shirt"), findsOneWidget);
      expect(find.text("Charity or organization (optional)"), findsOneWidget);
      expect(find.text("Confirm Donation"), findsOneWidget);
    });

    testWidgets("Donation confirmation calls API", (tester) async {
      bool donationCalled = false;
      final mockHttp = http_testing.MockClient((request) async {
        if (request.url.path == "/v1/spring-clean/items") {
          return http.Response(
            jsonEncode({"items": _sampleItems}),
            200,
          );
        }
        if (request.url.path == "/v1/donations" && request.method == "POST") {
          donationCalled = true;
          return http.Response(
            jsonEncode({
              "donation": {"id": "d1", "itemId": "item-1"},
              "item": {"id": "item-1", "resaleStatus": "donated"},
            }),
            201,
          );
        }
        return http.Response(jsonEncode({"code": "NOT_FOUND"}), 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Donate"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Confirm Donation"));
      await tester.pumpAndSettle();

      expect(donationCalled, isTrue);
    });

    testWidgets("Session summary shows correct counts", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Keep first item
      await tester.tap(find.text("Keep"));
      await tester.pumpAndSettle();

      // Sell second item -> should show summary
      await tester.tap(find.text("Sell"));
      await tester.pumpAndSettle();

      // Should now show session summary
      expect(find.text("Spring Clean Complete!"), findsOneWidget);
      expect(find.text("2"), findsOneWidget); // Reviewed count
      expect(find.text("1"), findsAtLeast(1)); // Kept or Sell count
    });

    testWidgets("Finish button ends session early and shows summary",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Finish"));
      await tester.pumpAndSettle();

      expect(find.text("Spring Clean Complete!"), findsOneWidget);
    });

    testWidgets("Empty state shows when no neglected items found",
        (tester) async {
      final apiClient = _buildMockApiClient(items: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("No neglected items to review"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text("Back to Wardrobe"), findsOneWidget);
    });

    testWidgets("Semantics labels present on all interactive elements",
        (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SpringCleanScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Check semantics labels exist
      expect(
        find.bySemanticsLabel(RegExp("Spring Clean review")),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp("Item Old Shirt")),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel("Keep this item"), findsOneWidget);
      expect(find.bySemanticsLabel("Sell this item"), findsOneWidget);
      expect(find.bySemanticsLabel("Donate this item"), findsOneWidget);
    });
  });
}
