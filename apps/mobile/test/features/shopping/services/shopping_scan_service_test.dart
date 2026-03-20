import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/shopping/services/shopping_scan_service.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "fake-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("ShoppingScanService.scoreCompatibility", () {
    test("calls POST /v1/shopping/scans/:id/score and returns CompatibilityScoreResult", () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, "POST");
        expect(request.url.path, "/v1/shopping/scans/scan-1/score");

        return http.Response(
          jsonEncode({
            "scan": {
              "id": "scan-1",
              "scanType": "url",
              "productName": "Blue Shirt",
              "brand": "Zara",
              "price": 29.99,
              "currency": "GBP",
              "compatibilityScore": 82,
              "createdAt": "2026-03-19T00:00:00.000Z",
            },
            "score": {
              "total": 82,
              "breakdown": {
                "colorHarmony": 90,
                "styleConsistency": 80,
                "gapFilling": 75,
                "versatility": 70,
                "formalityMatch": 85,
              },
              "tier": "great_choice",
              "tierLabel": "Great Choice",
              "tierColor": "#3B82F6",
              "tierIcon": "thumb_up",
              "reasoning": "Excellent color match.",
            },
            "status": "scored",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );

      final service = ShoppingScanService(apiClient: apiClient);
      final result = await service.scoreCompatibility("scan-1");

      expect(result.total, 82);
      expect(result.scan.id, "scan-1");
      expect(result.breakdown.colorHarmony, 90);
      expect(result.tier.tier, "great_choice");
      expect(result.reasoning, "Excellent color match.");
    });

    test("throws ApiException on 422 WARDROBE_EMPTY", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Wardrobe Empty",
            "code": "WARDROBE_EMPTY",
            "message": "Add items to your wardrobe first.",
          }),
          422,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );

      final service = ShoppingScanService(apiClient: apiClient);

      expect(
        () => service.scoreCompatibility("scan-1"),
        throwsA(isA<ApiException>().having(
          (e) => e.code,
          "code",
          "WARDROBE_EMPTY",
        )),
      );
    });

    test("throws ApiException on 502 SCORING_FAILED", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Bad Gateway",
            "code": "SCORING_FAILED",
            "message": "Unable to calculate compatibility score.",
          }),
          502,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );

      final service = ShoppingScanService(apiClient: apiClient);

      expect(
        () => service.scoreCompatibility("scan-1"),
        throwsA(isA<ApiException>().having(
          (e) => e.code,
          "code",
          "SCORING_FAILED",
        )),
      );
    });
  });
}
