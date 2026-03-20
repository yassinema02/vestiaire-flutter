import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/screens/resale_history_screen.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

ApiClient _buildMockApiClient({
  Map<String, dynamic>? historyResponse,
  bool shouldFail = false,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }

    if (request.url.path == "/v1/resale/history") {
      return http.Response(
        jsonEncode(historyResponse ?? {
          "history": [],
          "summary": {"itemsSold": 0, "itemsDonated": 0, "totalEarnings": 0},
          "monthlyEarnings": [],
        }),
        200,
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

  group("ResaleHistoryScreen", () {
    testWidgets("shows loading indicator during fetch", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ResaleHistoryScreen(apiClient: apiClient),
        ),
      );

      // Before pumpAndSettle, should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets("displays summary card with items sold, donated, and earnings",
        (tester) async {
      final apiClient = _buildMockApiClient(
        historyResponse: {
          "history": [
            {
              "id": "h1",
              "itemId": "i1",
              "type": "sold",
              "salePrice": 50.00,
              "saleCurrency": "GBP",
              "saleDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Blue Shirt",
              "itemPhotoUrl": "https://example.com/1.jpg",
            },
          ],
          "summary": {"itemsSold": 3, "itemsDonated": 1, "totalEarnings": 150.00},
          "monthlyEarnings": [
            {"month": "2026-03-01T00:00:00.000Z", "earnings": 150.00},
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResaleHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Summary values
      expect(find.text("3"), findsOneWidget); // items sold
      expect(find.text("1"), findsOneWidget); // items donated
      expect(find.text("Items Sold"), findsOneWidget);
      expect(find.text("Items Donated"), findsOneWidget);
      expect(find.text("Total Earnings"), findsOneWidget);
    });

    testWidgets("displays history entries with item name, status chip, price, and date",
        (tester) async {
      final apiClient = _buildMockApiClient(
        historyResponse: {
          "history": [
            {
              "id": "h1",
              "itemId": "i1",
              "type": "sold",
              "salePrice": 50.00,
              "saleCurrency": "GBP",
              "saleDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Blue Shirt",
              "itemPhotoUrl": "https://example.com/1.jpg",
            },
            {
              "id": "h2",
              "itemId": "i2",
              "type": "donated",
              "salePrice": 0,
              "saleCurrency": "GBP",
              "saleDate": "2026-03-10",
              "createdAt": "2026-03-10T10:00:00.000Z",
              "itemName": "Red Dress",
            },
          ],
          "summary": {"itemsSold": 1, "itemsDonated": 1, "totalEarnings": 50.00},
          "monthlyEarnings": [
            {"month": "2026-03-01T00:00:00.000Z", "earnings": 50.00},
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResaleHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Blue Shirt"), findsOneWidget);
      expect(find.text("Red Dress"), findsOneWidget);
      expect(find.text("Sold"), findsOneWidget);
      expect(find.text("Donated"), findsOneWidget);
      expect(find.text("2026-03-15"), findsOneWidget);
      expect(find.text("2026-03-10"), findsOneWidget);
    });

    testWidgets("displays earnings chart when sold items exist", (tester) async {
      final apiClient = _buildMockApiClient(
        historyResponse: {
          "history": [
            {
              "id": "h1",
              "itemId": "i1",
              "type": "sold",
              "salePrice": 50.00,
              "saleCurrency": "GBP",
              "saleDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Shirt",
            },
          ],
          "summary": {"itemsSold": 1, "itemsDonated": 0, "totalEarnings": 50.00},
          "monthlyEarnings": [
            {"month": "2026-03-01T00:00:00.000Z", "earnings": 50.00},
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResaleHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Chart should be present via CustomPaint
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets("shows empty state when no history exists", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ResaleHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("No resale history yet"), findsOneWidget);
      expect(find.text("List items for sale from their detail screen."), findsOneWidget);
    });

    testWidgets("Semantics labels present on summary and entries", (tester) async {
      final apiClient = _buildMockApiClient(
        historyResponse: {
          "history": [
            {
              "id": "h1",
              "itemId": "i1",
              "type": "sold",
              "salePrice": 50.00,
              "saleCurrency": "GBP",
              "saleDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Blue Shirt",
            },
          ],
          "summary": {"itemsSold": 1, "itemsDonated": 0, "totalEarnings": 50.00},
          "monthlyEarnings": [],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResaleHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Resale history screen semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Resale history",
        ),
        findsOneWidget,
      );

      // Items sold semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains("Items sold") ?? false),
        ),
        findsOneWidget,
      );

      // History entry semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains("Blue Shirt") ?? false),
        ),
        findsOneWidget,
      );
    });
  });
}
