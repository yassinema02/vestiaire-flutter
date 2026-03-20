import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/packing_list.dart";
import "package:vestiaire_mobile/src/features/outfits/models/trip.dart";
import "package:vestiaire_mobile/src/features/outfits/services/packing_list_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Trip _testTrip() {
  return Trip(
    id: "trip_barcelona_2026-03-20_2026-03-24",
    destination: "Barcelona",
    startDate: DateTime(2026, 3, 20),
    endDate: DateTime(2026, 3, 24),
    durationDays: 4,
    eventIds: ["e1"],
  );
}

Map<String, dynamic> _testPackingListJson() {
  return {
    "packingList": {
      "categories": [
        {
          "name": "Tops",
          "items": [
            {
              "itemId": "item-1",
              "name": "Blue T-Shirt",
              "reason": "Versatile top",
              "thumbnailUrl": "https://example.com/1.jpg",
              "category": "Tops",
              "color": "blue",
            }
          ]
        }
      ],
      "dailyOutfits": [
        {
          "day": 1,
          "date": "2026-03-20",
          "outfitItemIds": ["item-1"],
          "occasion": "Conference Day 1",
        }
      ],
      "tips": ["Pack light"],
      "fallback": false,
      "weatherUnavailable": false,
    },
    "generatedAt": "2026-03-19T12:00:00.000Z",
  };
}

void main() {
  group("PackingListService", () {
    test("generatePackingList calls API and returns parsed packing list",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(jsonEncode(_testPackingListJson()), 200);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = PackingListService(apiClient: apiClient);
      final result = await service.generatePackingList(_testTrip());

      expect(result, isNotNull);
      expect(result!.categories, hasLength(1));
      expect(result.categories[0].name, "Tops");
      expect(result.categories[0].items[0].name, "Blue T-Shirt");
      expect(result.dailyOutfits, hasLength(1));
      expect(result.tips, ["Pack light"]);
      expect(result.fallback, false);
    });

    test("generatePackingList returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Error", "code": "INTERNAL_SERVER_ERROR", "message": "Failed"}),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = PackingListService(apiClient: apiClient);
      final result = await service.generatePackingList(_testTrip());

      expect(result, isNull);
    });

    test("getCachedPackingList returns cached list from SharedPreferences",
        () async {
      SharedPreferences.setMockInitialValues({
        "packing_list_trip_barcelona_2026-03-20_2026-03-24":
            jsonEncode(_testPackingListJson()),
      });
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
      );

      final service =
          PackingListService(apiClient: apiClient, sharedPreferences: prefs);
      final result = await service.getCachedPackingList(
          "trip_barcelona_2026-03-20_2026-03-24");

      expect(result, isNotNull);
      expect(result!.categories, hasLength(1));
      expect(result.categories[0].name, "Tops");
    });

    test("getCachedPackingList returns null when no cache exists", () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
      );

      final service =
          PackingListService(apiClient: apiClient, sharedPreferences: prefs);
      final result = await service.getCachedPackingList("nonexistent-trip");

      expect(result, isNull);
    });

    test("cachePackingList persists to SharedPreferences", () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
      );

      final service =
          PackingListService(apiClient: apiClient, sharedPreferences: prefs);

      final list = PackingList(
        categories: [
          PackingListCategory(
              name: "Tops",
              items: [
                PackingListItem(name: "Shirt", reason: "Versatile"),
              ]),
        ],
        dailyOutfits: [],
        tips: [],
        fallback: false,
        generatedAt: DateTime(2026, 3, 19),
      );

      await service.cachePackingList("test-trip", list);

      final cached = prefs.getString("packing_list_test-trip");
      expect(cached, isNotNull);
      expect(cached, contains("Tops"));
    });

    test("getPackedStatus returns persisted packed state", () async {
      SharedPreferences.setMockInitialValues({
        "packed_status_test-trip":
            jsonEncode({"item-1": true, "item-2": false}),
      });
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
      );

      final service =
          PackingListService(apiClient: apiClient, sharedPreferences: prefs);
      final status = await service.getPackedStatus("test-trip");

      expect(status["item-1"], true);
      expect(status["item-2"], false);
    });

    test("updatePackedStatus updates packed state for specific item",
        () async {
      SharedPreferences.setMockInitialValues({
        "packed_status_test-trip": jsonEncode({"item-1": false}),
      });
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
      );

      final service =
          PackingListService(apiClient: apiClient, sharedPreferences: prefs);
      await service.updatePackedStatus("test-trip", "item-1", true);

      final status = await service.getPackedStatus("test-trip");
      expect(status["item-1"], true);
    });

    test("clearPackedStatus removes all packed state for trip", () async {
      SharedPreferences.setMockInitialValues({
        "packed_status_test-trip":
            jsonEncode({"item-1": true, "item-2": true}),
      });
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
      );

      final service =
          PackingListService(apiClient: apiClient, sharedPreferences: prefs);
      await service.clearPackedStatus("test-trip");

      final status = await service.getPackedStatus("test-trip");
      expect(status, isEmpty);
    });
  });
}
