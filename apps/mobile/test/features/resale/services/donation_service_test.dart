import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/services/donation_service.dart";
import "package:vestiaire_mobile/src/features/resale/services/resale_history_service.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("DonationService", () {
    test("createDonation calls API with correct body", () async {
      String? capturedBody;

      final mockHttp = http_testing.MockClient((request) async {
        capturedBody = request.body;
        expect(request.url.path, "/v1/donations");
        expect(request.method, "POST");
        return http.Response(
          jsonEncode({
            "donation": {"id": "d1", "itemId": "item-1", "charityName": "Oxfam", "estimatedValue": 15},
            "item": {"id": "item-1", "resaleStatus": "donated"},
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = DonationService(apiClient: apiClient);
      final result = await service.createDonation(
        itemId: "item-1",
        charityName: "Oxfam",
        estimatedValue: 15,
      );

      expect(result, isNotNull);
      final parsed = jsonDecode(capturedBody!);
      expect(parsed["itemId"], "item-1");
      expect(parsed["charityName"], "Oxfam");
      expect(parsed["estimatedValue"], 15);
    });

    test("createDonation returns parsed response on success", () async {
      final mockHttp = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "donation": {"id": "d1", "itemId": "item-1"},
            "item": {"id": "item-1", "resaleStatus": "donated"},
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = DonationService(apiClient: apiClient);
      final result = await service.createDonation(itemId: "item-1");

      expect(result, isNotNull);
      expect(result!["donation"], isA<Map>());
      expect(result["item"], isA<Map>());
    });

    test("createDonation returns null on non-409 error", () async {
      final mockHttp = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = DonationService(apiClient: apiClient);
      final result = await service.createDonation(itemId: "item-1");

      expect(result, isNull);
    });

    test("createDonation throws StatusTransitionException on 409", () async {
      final mockHttp = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "code": "INVALID_TRANSITION",
            "message": "Cannot donate item with resale_status 'sold'",
          }),
          409,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = DonationService(apiClient: apiClient);

      expect(
        () => service.createDonation(itemId: "item-1"),
        throwsA(isA<StatusTransitionException>()),
      );
    });

    test("fetchDonations calls API with correct params", () async {
      final mockHttp = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/donations");
        expect(request.url.queryParameters["limit"], "10");
        expect(request.url.queryParameters["offset"], "5");

        return http.Response(
          jsonEncode({
            "donations": [],
            "summary": {"totalDonated": 0, "totalValue": 0},
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = DonationService(apiClient: apiClient);
      final result = await service.fetchDonations(limit: 10, offset: 5);

      expect(result, isNotNull);
      expect(result!["donations"], isA<List>());
      expect(result["summary"], isA<Map>());
    });

    test("fetchDonations returns null on error", () async {
      final mockHttp = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = DonationService(apiClient: apiClient);
      final result = await service.fetchDonations();

      expect(result, isNull);
    });
  });
}
