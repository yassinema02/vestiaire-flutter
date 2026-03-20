import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/core/weather/outfit_context.dart";
import "package:vestiaire_mobile/src/core/weather/weather_clothing_mapper.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_generation_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OutfitContext _testOutfitContext() {
  return OutfitContext(
    temperature: 18.5,
    feelsLike: 16.2,
    weatherCode: 0,
    weatherDescription: "Clear sky",
    clothingConstraints: const ClothingConstraints(),
    locationName: "Paris, France",
    date: DateTime(2026, 3, 14),
    dayOfWeek: "Saturday",
    season: "spring",
    temperatureCategory: "mild",
  );
}

void main() {
  group("OutfitGenerationService", () {
    test("generateOutfits calls API with serialized OutfitContext", () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "suggestions": [
              {
                "id": "s1",
                "name": "Test Outfit",
                "items": [
                  {"id": "i1", "name": "Item 1", "category": "tops", "color": "blue", "photoUrl": null}
                ],
                "explanation": "A great outfit.",
                "occasion": "everyday",
              }
            ],
            "generatedAt": "2026-03-14T10:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      await service.generateOutfits(_testOutfitContext());

      expect(capturedPath, "/v1/outfits/generate");
      expect(capturedBody?["outfitContext"], isA<Map>());
      expect(capturedBody?["outfitContext"]["temperature"], 18.5);
      expect(capturedBody?["outfitContext"]["season"], "spring");
    });

    test("generateOutfits returns success response with OutfitGenerationResult",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "suggestions": [
              {
                "id": "s1",
                "name": "Spring Casual",
                "items": [
                  {"id": "i1", "name": "Shirt", "category": "tops", "color": "white", "photoUrl": "url1"},
                  {"id": "i2", "name": "Pants", "category": "bottoms", "color": "navy", "photoUrl": "url2"},
                ],
                "explanation": "Light and comfortable.",
                "occasion": "everyday",
              }
            ],
            "generatedAt": "2026-03-14T10:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final response = await service.generateOutfits(_testOutfitContext());

      expect(response.result, isNotNull);
      expect(response.limitReached, isNull);
      expect(response.isError, false);
      expect(response.result!.suggestions.length, 1);
      expect(response.result!.suggestions[0].name, "Spring Casual");
      expect(response.result!.suggestions[0].items.length, 2);
      expect(response.result!.generatedAt.year, 2026);
    });

    test("generateOutfits returns success response with UsageInfo when API returns 200 with usage metadata",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "suggestions": [
              {
                "id": "s1",
                "name": "Spring Casual",
                "items": [
                  {"id": "i1", "name": "Shirt", "category": "tops", "color": "white", "photoUrl": "url1"},
                ],
                "explanation": "Great outfit.",
                "occasion": "everyday",
              }
            ],
            "generatedAt": "2026-03-14T10:00:00.000Z",
            "usage": {
              "dailyLimit": 3,
              "used": 1,
              "remaining": 2,
              "resetsAt": "2026-03-15T00:00:00.000Z",
              "isPremium": false,
            }
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final response = await service.generateOutfits(_testOutfitContext());

      expect(response.result, isNotNull);
      expect(response.result!.usage, isNotNull);
      expect(response.result!.usage!.dailyLimit, 3);
      expect(response.result!.usage!.used, 1);
      expect(response.result!.usage!.remaining, 2);
      expect(response.result!.usage!.isPremium, false);
    });

    test("generateOutfits returns limit-reached response when API returns 429",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Rate Limit Exceeded",
            "code": "RATE_LIMIT_EXCEEDED",
            "message": "Daily outfit generation limit reached",
            "dailyLimit": 3,
            "used": 3,
            "remaining": 0,
            "resetsAt": "2026-03-16T00:00:00.000Z",
          }),
          429,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final response = await service.generateOutfits(_testOutfitContext());

      expect(response.result, isNull);
      expect(response.limitReached, isNotNull);
      expect(response.isError, false);
      expect(response.limitReached!.dailyLimit, 3);
      expect(response.limitReached!.used, 3);
      expect(response.limitReached!.remaining, 0);
      expect(response.limitReached!.resetsAt, "2026-03-16T00:00:00.000Z");
    });

    test("generateOutfits returns error response on other API failures (500)", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Internal Server Error",
            "code": "GENERATION_FAILED",
            "message": "Outfit generation failed",
          }),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final response = await service.generateOutfits(_testOutfitContext());

      expect(response.result, isNull);
      expect(response.limitReached, isNull);
      expect(response.isError, true);
    });

    test("generateOutfits returns error response on network error", () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final response = await service.generateOutfits(_testOutfitContext());

      expect(response.result, isNull);
      expect(response.limitReached, isNull);
      expect(response.isError, true);
    });
  });

  group("OutfitGenerationService.generateOutfitsForEvent", () {
    test("calls API with serialized context and event", () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "suggestions": [
              {
                "id": "s1",
                "name": "Event Outfit",
                "items": [
                  {"id": "i1", "name": "Item 1", "category": "tops", "color": "blue", "photoUrl": null}
                ],
                "explanation": "Perfect for the event.",
                "occasion": "work",
              }
            ],
            "generatedAt": "2026-03-15T10:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "evt-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        startTime: DateTime(2026, 3, 15, 10, 0),
        endTime: DateTime(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "keyword",
      );

      await service.generateOutfitsForEvent(_testOutfitContext(), event);

      expect(capturedPath, "/v1/outfits/generate-for-event");
      expect(capturedBody?["event"]["title"], "Sprint Planning");
      expect(capturedBody?["event"]["eventType"], "work");
      expect(capturedBody?["event"]["formalityScore"], 5);
      expect(capturedBody?["outfitContext"], isA<Map>());
    });

    test("returns parsed OutfitGenerationResult on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "suggestions": [
              {
                "id": "s1",
                "name": "Event Outfit",
                "items": [
                  {"id": "i1", "name": "Shirt", "category": "tops", "color": "white", "photoUrl": "url1"},
                ],
                "explanation": "Great for the meeting.",
                "occasion": "work",
              }
            ],
            "generatedAt": "2026-03-15T10:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "evt-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        startTime: DateTime(2026, 3, 15, 10, 0),
        endTime: DateTime(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "keyword",
      );

      final result = await service.generateOutfitsForEvent(_testOutfitContext(), event);

      expect(result, isNotNull);
      expect(result!.suggestions.length, 1);
      expect(result.suggestions[0].name, "Event Outfit");
    });

    test("returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Internal Server Error",
            "code": "GENERATION_FAILED",
            "message": "Event outfit generation failed",
          }),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "evt-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        startTime: DateTime(2026, 3, 15, 10, 0),
        endTime: DateTime(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "keyword",
      );

      final result = await service.generateOutfitsForEvent(_testOutfitContext(), event);

      expect(result, isNull);
    });

    test("returns null on network error", () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "evt-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        startTime: DateTime(2026, 3, 15, 10, 0),
        endTime: DateTime(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "keyword",
      );

      final result = await service.generateOutfitsForEvent(_testOutfitContext(), event);

      expect(result, isNull);
    });
  });

  group("OutfitGenerationService.hasEnoughItems", () {
    test("returns true when >= 3 categorized items", () {
      final items = [
        {"id": "1", "categorizationStatus": "completed"},
        {"id": "2", "categorizationStatus": "completed"},
        {"id": "3", "categorizationStatus": "completed"},
      ];

      expect(OutfitGenerationService.hasEnoughItems(items), isTrue);
    });

    test("returns false when < 3 categorized items", () {
      final items = [
        {"id": "1", "categorizationStatus": "completed"},
        {"id": "2", "categorizationStatus": "completed"},
      ];

      expect(OutfitGenerationService.hasEnoughItems(items), isFalse);
    });

    test("excludes items without completed categorization", () {
      final items = [
        {"id": "1", "categorizationStatus": "completed"},
        {"id": "2", "categorizationStatus": "completed"},
        {"id": "3", "categorizationStatus": "pending"},
        {"id": "4", "categorizationStatus": "failed"},
      ];

      expect(OutfitGenerationService.hasEnoughItems(items), isFalse);
    });

    test("returns false for empty list", () {
      expect(OutfitGenerationService.hasEnoughItems([]), isFalse);
    });
  });

  // --- Story 12.3: Event Prep Tip Tests ---
  group("getEventPrepTip", () {
    test("calls API with serialized event and outfit items", () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({"tip": "Iron your blazer"}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "event-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "src-1",
        title: "Gala Dinner",
        startTime: DateTime(2026, 3, 20, 19, 0),
        endTime: DateTime(2026, 3, 20, 22, 0),
        allDay: false,
        eventType: "formal",
        formalityScore: 9,
        classificationSource: "ai",
      );

      await service.getEventPrepTip(event, [
        {"name": "Silk Blazer", "category": "outerwear", "material": "silk", "color": "navy"}
      ]);

      expect(capturedPath, "/v1/outfits/event-prep-tips");
      expect(capturedBody?["event"]["title"], "Gala Dinner");
      expect(capturedBody?["event"]["formalityScore"], 9);
      expect(capturedBody?["outfitItems"], isNotNull);
      expect((capturedBody?["outfitItems"] as List).first["name"], "Silk Blazer");
    });

    test("returns parsed tip string on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"tip": "Steam your trousers tonight"}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "event-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "src-1",
        title: "Conference",
        startTime: DateTime(2026, 3, 20, 9, 0),
        endTime: DateTime(2026, 3, 20, 17, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 7,
        classificationSource: "ai",
      );

      final tip = await service.getEventPrepTip(event, null);
      expect(tip, "Steam your trousers tonight");
    });

    test("returns null on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Server Error", "code": "INTERNAL_SERVER_ERROR", "message": "Failed"}),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "event-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "src-1",
        title: "Meeting",
        startTime: DateTime(2026, 3, 20, 9, 0),
        endTime: DateTime(2026, 3, 20, 10, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 7,
        classificationSource: "ai",
      );

      final tip = await service.getEventPrepTip(event, null);
      expect(tip, isNull);
    });

    test("returns null on network error", () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      final event = CalendarEvent(
        id: "event-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "src-1",
        title: "Meeting",
        startTime: DateTime(2026, 3, 20, 9, 0),
        endTime: DateTime(2026, 3, 20, 10, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 7,
        classificationSource: "ai",
      );

      final tip = await service.getEventPrepTip(event, null);
      expect(tip, isNull);
    });
  });
}
