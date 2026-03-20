import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/screens/donation_history_screen.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

ApiClient _buildMockApiClient({
  Map<String, dynamic>? donationResponse,
  bool shouldFail = false,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }

    if (request.url.path == "/v1/donations") {
      return http.Response(
        jsonEncode(donationResponse ?? {
          "donations": [],
          "summary": {"totalDonated": 0, "totalValue": 0},
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

  group("DonationHistoryScreen", () {
    testWidgets("shows loading indicator during fetch", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: DonationHistoryScreen(apiClient: apiClient),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets("displays summary card with total donated and total value",
        (tester) async {
      final apiClient = _buildMockApiClient(
        donationResponse: {
          "donations": [
            {
              "id": "d1",
              "itemId": "item-1",
              "charityName": "Oxfam",
              "estimatedValue": 25,
              "donationDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Blue Shirt",
              "itemPhotoUrl": null,
              "itemCategory": "tops",
              "itemBrand": "Nike",
            },
          ],
          "summary": {"totalDonated": 1, "totalValue": 25},
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DonationHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Summary card
      expect(find.text("1"), findsOneWidget); // Total donated
      expect(find.text("Items Donated"), findsOneWidget);
      expect(find.text("Total Value"), findsOneWidget);
    });

    testWidgets("displays donation entries with item name, charity, date, value",
        (tester) async {
      final apiClient = _buildMockApiClient(
        donationResponse: {
          "donations": [
            {
              "id": "d1",
              "itemId": "item-1",
              "charityName": "Red Cross",
              "estimatedValue": 25,
              "donationDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Blue Shirt",
              "itemPhotoUrl": null,
              "itemCategory": "tops",
              "itemBrand": "Nike",
            },
          ],
          "summary": {"totalDonated": 1, "totalValue": 25},
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DonationHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Blue Shirt"), findsOneWidget);
      expect(find.text("Red Cross"), findsOneWidget);
      expect(find.text("Donated"), findsOneWidget);
    });

    testWidgets("empty state shows when no donations", (tester) async {
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: DonationHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("No donations yet"), findsOneWidget);
      expect(find.byIcon(Icons.volunteer_activism), findsOneWidget);
    });

    testWidgets("semantics labels present", (tester) async {
      final apiClient = _buildMockApiClient(
        donationResponse: {
          "donations": [
            {
              "id": "d1",
              "itemId": "item-1",
              "charityName": "Oxfam",
              "estimatedValue": 25,
              "donationDate": "2026-03-15",
              "createdAt": "2026-03-15T10:00:00.000Z",
              "itemName": "Blue Shirt",
              "itemPhotoUrl": null,
              "itemCategory": "tops",
              "itemBrand": null,
            },
          ],
          "summary": {"totalDonated": 1, "totalValue": 25},
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DonationHistoryScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel("Donation history"), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp("Total items donated")), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp("Total donation value")), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp("Blue Shirt.*donated")), findsAtLeast(1));
    });
  });
}
