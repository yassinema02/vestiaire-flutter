import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/services/resale_listing_service.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "fake-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("ResaleListingService", () {
    late _FakeAuthService authService;

    setUp(() {
      authService = _FakeAuthService();
    });

    ApiClient buildClient(http.Client httpClient) {
      return ApiClient(
        baseUrl: "http://localhost:8080",
        authService: authService,
        httpClient: httpClient,
      );
    }

    test("generateListing calls API with correct item ID", () async {
      String? capturedBody;

      final httpClient = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "listing": {
              "id": "listing-1",
              "title": "Blue Shirt",
              "description": "A shirt.",
              "conditionEstimate": "Good",
              "hashtags": ["fashion"],
              "platform": "general",
            },
            "item": {"id": "item-1", "name": "Blue Shirt"},
            "generatedAt": "2026-03-19T00:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = buildClient(httpClient);
      final service = ResaleListingService(apiClient: apiClient);

      await service.generateListing("item-1");

      expect(capturedBody, isNotNull);
      final parsed = jsonDecode(capturedBody!);
      expect(parsed["itemId"], "item-1");
    });

    test("generateListing returns parsed ResaleListingResult on success", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "listing": {
              "id": "listing-1",
              "title": "Blue Shirt",
              "description": "A lovely shirt.",
              "conditionEstimate": "Like New",
              "hashtags": ["fashion", "blue"],
              "platform": "general",
            },
            "item": {
              "id": "item-1",
              "name": "Blue Shirt",
              "category": "tops",
              "brand": "Nike",
              "photoUrl": "https://example.com/photo.jpg",
            },
            "generatedAt": "2026-03-19T00:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = buildClient(httpClient);
      final service = ResaleListingService(apiClient: apiClient);

      final result = await service.generateListing("item-1");

      expect(result, isNotNull);
      expect(result!.listing.id, "listing-1");
      expect(result.listing.title, "Blue Shirt");
      expect(result.listing.conditionEstimate, "Like New");
      expect(result.listing.hashtags, ["fashion", "blue"]);
      expect(result.item.id, "item-1");
      expect(result.item.brand, "Nike");
    });

    test("generateListing returns null on API error (non-429)", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Internal Server Error",
            "code": "INTERNAL_SERVER_ERROR",
            "message": "Something went wrong",
          }),
          500,
        );
      });

      final apiClient = buildClient(httpClient);
      final service = ResaleListingService(apiClient: apiClient);

      final result = await service.generateListing("item-1");

      expect(result, isNull);
    });

    test("generateListing throws UsageLimitException on 429 response", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Rate Limit Exceeded",
            "code": "RATE_LIMIT_EXCEEDED",
            "message": "Free tier limit: 2 resale listings per month",
            "monthlyLimit": 2,
            "used": 2,
            "remaining": 0,
            "resetsAt": "2026-04-01T00:00:00.000Z",
          }),
          429,
        );
      });

      final apiClient = buildClient(httpClient);
      final service = ResaleListingService(apiClient: apiClient);

      expect(
        () => service.generateListing("item-1"),
        throwsA(isA<UsageLimitException>()),
      );
    });
  });
}
