import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/analytics/services/wear_log_service.dart";

/// Minimal fake AuthService for tests.
class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("WearLogService", () {
    late _FakeAuthService fakeAuth;

    setUp(() {
      fakeAuth = _FakeAuthService();
    });

    ApiClient buildApiClient(http.Client httpClient) {
      return ApiClient(
        baseUrl: "http://localhost:8080",
        authService: fakeAuth,
        httpClient: httpClient,
      );
    }

    test("logItems calls createWearLog with correct item IDs", () async {
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "wearLog": {
              "id": "wl-1",
              "profileId": "p-1",
              "loggedDate": "2026-03-17",
              "itemIds": ["item-1", "item-2"],
            }
          }),
          201,
        );
      });

      final service = WearLogService(apiClient: buildApiClient(mockClient));
      final result = await service.logItems(["item-1", "item-2"]);

      expect(result.wearLog.id, "wl-1");
      expect(result.wearLog.itemIds, ["item-1", "item-2"]);

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["items"], ["item-1", "item-2"]);
      expect(body.containsKey("outfitId"), isFalse);
    });

    test("logOutfit calls createWearLog with outfitId and item IDs", () async {
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "wearLog": {
              "id": "wl-2",
              "profileId": "p-1",
              "loggedDate": "2026-03-17",
              "outfitId": "outfit-1",
              "itemIds": ["item-1"],
            }
          }),
          201,
        );
      });

      final service = WearLogService(apiClient: buildApiClient(mockClient));
      final result = await service.logOutfit("outfit-1", ["item-1"]);

      expect(result.wearLog.id, "wl-2");
      expect(result.wearLog.outfitId, "outfit-1");

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["items"], ["item-1"]);
      expect(body["outfitId"], "outfit-1");
    });

    test("getLogsForDateRange calls listWearLogs with date params", () async {
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "wearLogs": [
              {
                "id": "wl-1",
                "profileId": "p-1",
                "loggedDate": "2026-03-15",
                "itemIds": ["item-1"],
              }
            ]
          }),
          200,
        );
      });

      final service = WearLogService(apiClient: buildApiClient(mockClient));
      final result =
          await service.getLogsForDateRange("2026-03-15", "2026-03-17");

      expect(result.length, 1);
      expect(result[0].id, "wl-1");
      expect(capturedUri?.queryParameters["start"], "2026-03-15");
      expect(capturedUri?.queryParameters["end"], "2026-03-17");
    });

    test("error propagation from ApiClient to service", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Internal Server Error",
            "code": "INTERNAL_SERVER_ERROR",
            "message": "Something went wrong",
          }),
          500,
        );
      });

      final service = WearLogService(apiClient: buildApiClient(mockClient));

      expect(
        () => service.logItems(["item-1"]),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          "statusCode",
          500,
        )),
      );
    });
  });
}
