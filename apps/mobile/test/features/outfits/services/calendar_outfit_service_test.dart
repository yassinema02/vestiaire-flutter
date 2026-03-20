import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/calendar_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/services/calendar_outfit_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _calendarOutfitJson({String id = "co-1"}) => {
      "id": id,
      "outfitId": "outfit-1",
      "calendarEventId": null,
      "scheduledDate": "2026-03-20",
      "notes": null,
      "outfit": {
        "id": "outfit-1",
        "name": "Test Outfit",
        "occasion": "casual",
        "source": "ai",
        "items": [],
      },
      "createdAt": "2026-03-19T00:00:00Z",
      "updatedAt": "2026-03-19T00:00:00Z",
    };

void main() {
  group("CalendarOutfitService", () {
    test("createCalendarOutfit calls API with correct body and returns parsed result", () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({"calendarOutfit": _calendarOutfitJson()}),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.createCalendarOutfit(
        outfitId: "outfit-1",
        scheduledDate: "2026-03-20",
      );

      expect(result, isNotNull);
      expect(result, isA<CalendarOutfit>());
      expect(result!.id, "co-1");
      expect(result.outfitId, "outfit-1");
      expect(capturedBody!["outfitId"], "outfit-1");
      expect(capturedBody!["scheduledDate"], "2026-03-20");
    });

    test("createCalendarOutfit returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "BAD_REQUEST", "message": "Invalid"}),
          400,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.createCalendarOutfit(
        outfitId: "invalid",
        scheduledDate: "2026-03-20",
      );

      expect(result, isNull);
    });

    test("getCalendarOutfitsForDateRange returns parsed list on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/calendar/outfits");
        expect(request.url.queryParameters["startDate"], "2026-03-19");
        expect(request.url.queryParameters["endDate"], "2026-03-25");
        return http.Response(
          jsonEncode({
            "calendarOutfits": [_calendarOutfitJson()],
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.getCalendarOutfitsForDateRange(
          "2026-03-19", "2026-03-25");

      expect(result, isA<List<CalendarOutfit>>());
      expect(result.length, 1);
      expect(result[0].id, "co-1");
    });

    test("getCalendarOutfitsForDateRange returns empty list on error", () async {
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

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.getCalendarOutfitsForDateRange(
          "2026-03-19", "2026-03-25");

      expect(result, isEmpty);
    });

    test("updateCalendarOutfit calls API and returns parsed result", () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/calendar/outfits/co-1");
        return http.Response(
          jsonEncode({"calendarOutfit": _calendarOutfitJson()}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.updateCalendarOutfit(
        "co-1",
        outfitId: "outfit-2",
      );

      expect(result, isNotNull);
      expect(result!.id, "co-1");
    });

    test("deleteCalendarOutfit returns true on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/calendar/outfits/co-1");
        return http.Response(jsonEncode({}), 204);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.deleteCalendarOutfit("co-1");

      expect(result, true);
    });

    test("deleteCalendarOutfit returns false on error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"code": "NOT_FOUND", "message": "not found"}),
          404,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = CalendarOutfitService(apiClient: apiClient);
      final result = await service.deleteCalendarOutfit("nonexistent");

      expect(result, false);
    });
  });
}
