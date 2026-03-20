import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/subscription/models/subscription_status.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_sync_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";

/// Minimal mock of AuthService for API client testing.
class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return "fake-firebase-token";
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Create a testable ApiClient with a mock HTTP client.
ApiClient createTestApiClient(http.Client httpClient) {
  return ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _MockAuthService(),
    httpClient: httpClient,
  );
}

void main() {
  group("SubscriptionSyncService", () {
    test("syncSubscription calls POST /v1/subscription/sync with correct body",
        () async {
      String? capturedBody;
      String? capturedPath;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "isPremium": true,
            "premiumSource": "revenuecat",
            "premiumExpiresAt": "2026-04-19T00:00:00Z",
          }),
          200,
          headers: {"content-type": "application/json"},
        );
      });

      final apiClient = createTestApiClient(mockClient);
      final syncService = SubscriptionSyncService(apiClient: apiClient);

      await syncService.syncSubscription("firebase-user-123");

      expect(capturedPath, equals("/v1/subscription/sync"));
      final body = jsonDecode(capturedBody!);
      expect(body["appUserId"], equals("firebase-user-123"));
    });

    test("syncSubscription returns SubscriptionStatus on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "isPremium": true,
            "premiumSource": "revenuecat",
            "premiumExpiresAt": "2026-04-19T00:00:00Z",
          }),
          200,
          headers: {"content-type": "application/json"},
        );
      });

      final apiClient = createTestApiClient(mockClient);
      final syncService = SubscriptionSyncService(apiClient: apiClient);

      final status =
          await syncService.syncSubscription("firebase-user-123");

      expect(status.isPremium, isTrue);
      expect(status.premiumSource, equals("revenuecat"));
      expect(status.premiumExpiresAt, equals("2026-04-19T00:00:00Z"));
    });

    test("syncSubscription handles API error gracefully", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Unauthorized",
            "code": "UNAUTHORIZED",
            "message": "Invalid token",
          }),
          401,
          headers: {"content-type": "application/json"},
        );
      });

      final apiClient = createTestApiClient(mockClient);
      final syncService = SubscriptionSyncService(apiClient: apiClient);

      expect(
        () => syncService.syncSubscription("firebase-user-123"),
        throwsA(anything),
      );
    });
  });

  group("SubscriptionStatus", () {
    test("fromJson parses all fields correctly", () {
      final json = {
        "isPremium": true,
        "premiumSource": "revenuecat",
        "premiumExpiresAt": "2026-04-19T00:00:00Z",
      };

      final status = SubscriptionStatus.fromJson(json);

      expect(status.isPremium, isTrue);
      expect(status.premiumSource, equals("revenuecat"));
      expect(status.premiumExpiresAt, equals("2026-04-19T00:00:00Z"));
    });

    test("fromJson handles null optional fields", () {
      final json = {
        "isPremium": false,
      };

      final status = SubscriptionStatus.fromJson(json);

      expect(status.isPremium, isFalse);
      expect(status.premiumSource, isNull);
      expect(status.premiumExpiresAt, isNull);
    });

    test("fromJson handles missing isPremium (defaults to false)", () {
      final json = <String, dynamic>{};

      final status = SubscriptionStatus.fromJson(json);

      expect(status.isPremium, isFalse);
    });

    test("toJson produces correct output", () {
      const status = SubscriptionStatus(
        isPremium: true,
        premiumSource: "trial",
        premiumExpiresAt: "2026-04-01T00:00:00Z",
      );

      final json = status.toJson();

      expect(json["isPremium"], isTrue);
      expect(json["premiumSource"], equals("trial"));
      expect(json["premiumExpiresAt"], equals("2026-04-01T00:00:00Z"));
    });
  });
}
