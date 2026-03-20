import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";
import "package:vestiaire_mobile/src/features/outfits/models/saved_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OutfitSuggestion _testSuggestion() {
  return const OutfitSuggestion(
    id: "s1",
    name: "Spring Casual",
    items: [
      OutfitSuggestionItem(
        id: "item-1",
        name: "Shirt",
        category: "tops",
        color: "white",
        photoUrl: null,
      ),
      OutfitSuggestionItem(
        id: "item-2",
        name: "Jeans",
        category: "bottoms",
        color: "blue",
        photoUrl: null,
      ),
      OutfitSuggestionItem(
        id: "item-3",
        name: "Sneakers",
        category: "shoes",
        color: "white",
        photoUrl: null,
      ),
    ],
    explanation: "Perfect for spring weather.",
    occasion: "everyday",
  );
}

void main() {
  group("OutfitPersistenceService", () {
    test("saveOutfit calls API with correct request body", () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "outfit": {
              "id": "outfit-uuid-1",
              "name": "Spring Casual",
            }
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.saveOutfit(_testSuggestion());

      expect(capturedBody, isNotNull);
      expect(capturedBody!["name"], "Spring Casual");
      expect(capturedBody!["explanation"], "Perfect for spring weather.");
      expect(capturedBody!["occasion"], "everyday");
      expect(capturedBody!["source"], "ai");
      expect(capturedBody!["items"], isA<List>());
      expect(capturedBody!["items"].length, 3);
    });

    test("saveOutfit maps item positions correctly (0-indexed)", () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({"outfit": {"id": "outfit-uuid-1"}}),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.saveOutfit(_testSuggestion());

      final items = capturedBody!["items"] as List;
      expect(items[0]["itemId"], "item-1");
      expect(items[0]["position"], 0);
      expect(items[1]["itemId"], "item-2");
      expect(items[1]["position"], 1);
      expect(items[2]["itemId"], "item-3");
      expect(items[2]["position"], 2);
    });

    test("saveOutfit returns parsed response map on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "outfit": {
              "id": "outfit-uuid-1",
              "name": "Spring Casual",
              "source": "ai",
            }
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.saveOutfit(_testSuggestion());

      expect(result, isNotNull);
      expect(result!["outfit"]["id"], "outfit-uuid-1");
      expect(result["outfit"]["name"], "Spring Casual");
    });

    test("saveOutfit returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Bad Request",
            "code": "INVALID_ITEM",
            "message": "One or more items not found",
          }),
          400,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.saveOutfit(_testSuggestion());

      expect(result, isNull);
    });

    test("saveOutfit returns null on network error", () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.saveOutfit(_testSuggestion());

      expect(result, isNull);
    });
  });

  group("OutfitPersistenceService.saveManualOutfit", () {
    test("calls API with correct request body", () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "outfit": {"id": "outfit-uuid-2", "name": "Weekend Look"}
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.saveManualOutfit(
        name: "Weekend Look",
        occasion: "casual",
        items: [
          {"itemId": "item-a", "position": 0},
          {"itemId": "item-b", "position": 1},
        ],
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!["name"], "Weekend Look");
      expect(capturedBody!["source"], "manual");
      expect(capturedBody!["occasion"], "casual");
      expect(capturedBody!["items"], isA<List>());
      expect(capturedBody!["items"].length, 2);
      expect(capturedBody!["items"][0]["itemId"], "item-a");
      expect(capturedBody!["items"][0]["position"], 0);
      expect(capturedBody!["items"][1]["itemId"], "item-b");
      expect(capturedBody!["items"][1]["position"], 1);
    });

    test("sends source as manual (not ai)", () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({"outfit": {"id": "outfit-uuid-2"}}),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.saveManualOutfit(
        name: "Test",
        items: [{"itemId": "item-a", "position": 0}],
      );

      expect(capturedBody!["source"], "manual");
    });

    test("returns parsed response map on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "outfit": {
              "id": "outfit-uuid-2",
              "name": "Weekend Look",
              "source": "manual",
            }
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.saveManualOutfit(
        name: "Weekend Look",
        items: [{"itemId": "item-a", "position": 0}],
      );

      expect(result, isNotNull);
      expect(result!["outfit"]["id"], "outfit-uuid-2");
      expect(result["outfit"]["name"], "Weekend Look");
    });

    test("returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Bad Request",
            "code": "INVALID_ITEM",
            "message": "One or more items not found",
          }),
          400,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.saveManualOutfit(
        name: "Test",
        items: [{"itemId": "item-a", "position": 0}],
      );

      expect(result, isNull);
    });

    test("returns null on network error", () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.saveManualOutfit(
        name: "Test",
        items: [{"itemId": "item-a", "position": 0}],
      );

      expect(result, isNull);
    });

    test("sends null occasion when not provided (manual)", () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({"outfit": {"id": "outfit-uuid-2"}}),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.saveManualOutfit(
        name: "No Occasion",
        items: [{"itemId": "item-a", "position": 0}],
      );

      expect(capturedBody!["occasion"], isNull);
    });
  });

  group("OutfitPersistenceService.listOutfits", () {
    test("calls API and returns parsed list of SavedOutfit", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "outfits": [
              {
                "id": "outfit-1",
                "name": "Spring Casual",
                "source": "ai",
                "isFavorite": false,
                "createdAt": "2026-03-15T10:00:00Z",
                "items": [
                  {"id": "item-1", "name": "Shirt", "category": "tops", "color": "blue", "photoUrl": null}
                ]
              }
            ]
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.listOutfits();

      expect(result, isA<List<SavedOutfit>>());
      expect(result.length, 1);
      expect(result[0].id, "outfit-1");
      expect(result[0].name, "Spring Casual");
      expect(result[0].items.length, 1);
    });

    test("returns empty list on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.listOutfits();

      expect(result, isEmpty);
    });

    test("returns empty list when response has no outfits", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"outfits": []}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.listOutfits();

      expect(result, isEmpty);
    });
  });

  group("OutfitPersistenceService.toggleFavorite", () {
    test("calls API with correct outfitId and isFavorite value", () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "outfit": {
              "id": "outfit-1",
              "name": "Test",
              "isFavorite": true,
              "source": "ai",
              "createdAt": "2026-03-15T10:00:00Z",
              "items": []
            }
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.toggleFavorite("outfit-1", true);

      expect(capturedPath, "/v1/outfits/outfit-1");
      expect(capturedBody!["isFavorite"], true);
    });

    test("returns parsed SavedOutfit on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "outfit": {
              "id": "outfit-1",
              "name": "Test",
              "isFavorite": true,
              "source": "ai",
              "createdAt": "2026-03-15T10:00:00Z",
              "items": []
            }
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.toggleFavorite("outfit-1", true);

      expect(result, isNotNull);
      expect(result!.id, "outfit-1");
      expect(result.isFavorite, true);
    });

    test("returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "NOT_FOUND", "message": "Outfit not found"}),
          404,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.toggleFavorite("nonexistent", true);

      expect(result, isNull);
    });
  });

  group("OutfitPersistenceService.deleteOutfit", () {
    test("calls API with correct outfitId", () async {
      String? capturedPath;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        return http.Response(
          jsonEncode({"deleted": true, "id": "outfit-1"}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      await service.deleteOutfit("outfit-1");

      expect(capturedPath, "/v1/outfits/outfit-1");
    });

    test("returns true on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"deleted": true, "id": "outfit-1"}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.deleteOutfit("outfit-1");

      expect(result, true);
    });

    test("returns false on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "NOT_FOUND", "message": "Outfit not found"}),
          404,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = OutfitPersistenceService(apiClient: apiClient);
      final result = await service.deleteOutfit("nonexistent");

      expect(result, false);
    });
  });
}
