import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
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

  group("ResaleHistoryService", () {
    test("fetchHistory calls API with correct params and returns parsed data", () async {
      final mockHttp = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/resale/history");
        expect(request.url.queryParameters["limit"], "50");
        expect(request.url.queryParameters["offset"], "0");

        return http.Response(
          jsonEncode({
            "history": [
              {"id": "h1", "type": "sold", "salePrice": 50}
            ],
            "summary": {"itemsSold": 1, "itemsDonated": 0, "totalEarnings": 50},
            "monthlyEarnings": [],
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = ResaleHistoryService(apiClient: apiClient);
      final result = await service.fetchHistory();

      expect(result, isNotNull);
      expect(result!["history"], isA<List>());
      expect((result["history"] as List).length, 1);
      expect(result["summary"], isA<Map>());
    });

    test("fetchHistory returns null on error", () async {
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

      final service = ResaleHistoryService(apiClient: apiClient);
      final result = await service.fetchHistory();

      expect(result, isNull);
    });

    test("updateResaleStatus sends correct body for sold status", () async {
      String? capturedBody;

      final mockHttp = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "item": {"id": "item-1", "resaleStatus": "sold"},
            "historyEntry": {"id": "h1", "type": "sold"},
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = ResaleHistoryService(apiClient: apiClient);
      final result = await service.updateResaleStatus(
        "item-1",
        status: "sold",
        salePrice: 49.99,
        saleCurrency: "GBP",
      );

      expect(result, isNotNull);
      final parsed = jsonDecode(capturedBody!);
      expect(parsed["status"], "sold");
      expect(parsed["salePrice"], 49.99);
      expect(parsed["saleCurrency"], "GBP");
    });

    test("updateResaleStatus sends correct body for donated status", () async {
      String? capturedBody;

      final mockHttp = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "item": {"id": "item-1", "resaleStatus": "donated"},
            "historyEntry": {"id": "h1", "type": "donated"},
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = ResaleHistoryService(apiClient: apiClient);
      final result = await service.updateResaleStatus(
        "item-1",
        status: "donated",
      );

      expect(result, isNotNull);
      final parsed = jsonDecode(capturedBody!);
      expect(parsed["status"], "donated");
      expect(parsed.containsKey("salePrice"), false);
    });

    test("updateResaleStatus throws StatusTransitionException on 409", () async {
      final mockHttp = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "code": "INVALID_TRANSITION",
            "message": "Cannot transition from 'sold' to 'donated'",
          }),
          409,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      final service = ResaleHistoryService(apiClient: apiClient);

      expect(
        () => service.updateResaleStatus("item-1", status: "donated"),
        throwsA(isA<StatusTransitionException>()),
      );
    });
  });
}
