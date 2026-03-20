import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/services/resale_prompt_service.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "fake-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("ResalePromptService", () {
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

    test("fetchPendingPrompts calls API and returns parsed prompts", () async {
      final httpClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/resale/prompts");
        expect(request.method, "GET");
        return http.Response(
          jsonEncode({
            "prompts": [
              {
                "id": "prompt-1",
                "itemId": "item-1",
                "estimatedPrice": 48.0,
                "estimatedCurrency": "GBP",
                "action": null,
                "createdAt": "2026-03-19T10:00:00.000Z",
                "itemName": "Blue Shirt",
              }
            ],
          }),
          200,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final prompts = await service.fetchPendingPrompts();

      expect(prompts.length, 1);
      expect(prompts[0].id, "prompt-1");
      expect(prompts[0].itemName, "Blue Shirt");
      expect(prompts[0].estimatedPrice, 48.0);
    });

    test("fetchPendingPrompts returns empty list on error", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Server Error", "code": "INTERNAL_SERVER_ERROR", "message": "fail"}),
          500,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final prompts = await service.fetchPendingPrompts();

      expect(prompts, isEmpty);
    });

    test("triggerEvaluation calls API and returns true when candidates found",
        () async {
      final httpClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/resale/prompts/evaluate");
        expect(request.method, "POST");
        return http.Response(
          jsonEncode({"candidates": 2, "prompted": true}),
          200,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final result = await service.triggerEvaluation();

      expect(result, true);
    });

    test("triggerEvaluation returns false on error", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Server Error", "code": "INTERNAL_SERVER_ERROR", "message": "fail"}),
          500,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final result = await service.triggerEvaluation();

      expect(result, false);
    });

    test("triggerEvaluation returns false when zero candidates", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"candidates": 0, "prompted": false}),
          200,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final result = await service.triggerEvaluation();

      expect(result, false);
    });

    test("acceptPrompt calls PATCH with correct action", () async {
      String? capturedBody;

      final httpClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/resale/prompts/prompt-1");
        expect(request.method, "PATCH");
        capturedBody = request.body;
        return http.Response(
          jsonEncode({"id": "prompt-1", "action": "accepted"}),
          200,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      await service.acceptPrompt("prompt-1");

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["action"], "accepted");
    });

    test("dismissPrompt calls PATCH with correct action", () async {
      String? capturedBody;

      final httpClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/resale/prompts/prompt-1");
        expect(request.method, "PATCH");
        capturedBody = request.body;
        return http.Response(
          jsonEncode({"id": "prompt-1", "action": "dismissed"}),
          200,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      await service.dismissPrompt("prompt-1");

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["action"], "dismissed");
    });

    test("fetchPendingCount returns correct count", () async {
      final httpClient = http_testing.MockClient((request) async {
        expect(request.url.path, "/v1/resale/prompts/count");
        expect(request.method, "GET");
        return http.Response(
          jsonEncode({"count": 3}),
          200,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final count = await service.fetchPendingCount();

      expect(count, 3);
    });

    test("fetchPendingCount returns 0 on error", () async {
      final httpClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Server Error", "code": "INTERNAL_SERVER_ERROR", "message": "fail"}),
          500,
        );
      });

      final service = ResalePromptService(apiClient: buildClient(httpClient));
      final count = await service.fetchPendingCount();

      expect(count, 0);
    });
  });
}
