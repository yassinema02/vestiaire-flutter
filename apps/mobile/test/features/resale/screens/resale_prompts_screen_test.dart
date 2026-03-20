import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/resale/models/resale_prompt.dart";
import "package:vestiaire_mobile/src/features/resale/screens/resale_prompts_screen.dart";
import "package:vestiaire_mobile/src/features/resale/services/resale_prompt_service.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "fake-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiClient _buildApiClient({
  Map<String, dynamic>? healthResponse,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    if (request.url.path.contains("wardrobe-health")) {
      return http.Response(
        jsonEncode(healthResponse ?? {"score": 72, "recommendation": "Try wearing more items."}),
        200,
      );
    }
    return http.Response(jsonEncode({"error": "Not Found", "code": "NOT_FOUND", "message": "Not found"}), 404);
  });
  return ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _FakeAuthService(),
    httpClient: mockHttp,
  );
}

class _MockResalePromptService extends ResalePromptService {
  _MockResalePromptService({
    this.prompts = const [],
    this.onAccept,
    this.onDismiss,
  }) : super(apiClient: _buildApiClient());

  final List<ResalePrompt> prompts;
  final void Function(String)? onAccept;
  final void Function(String)? onDismiss;
  final List<String> acceptedIds = [];
  final List<String> dismissedIds = [];

  @override
  Future<List<ResalePrompt>> fetchPendingPrompts() async => prompts;

  @override
  Future<void> acceptPrompt(String promptId) async {
    acceptedIds.add(promptId);
    onAccept?.call(promptId);
  }

  @override
  Future<void> dismissPrompt(String promptId) async {
    dismissedIds.add(promptId);
    onDismiss?.call(promptId);
  }

  @override
  Future<int> fetchPendingCount() async => prompts.length;

  @override
  Future<bool> triggerEvaluation() async => false;
}

ResalePrompt _makePrompt({
  String id = "prompt-1",
  String itemName = "Blue Shirt",
  String itemCategory = "Tops",
  String itemBrand = "Nike",
  double estimatedPrice = 48.0,
}) {
  return ResalePrompt(
    id: id,
    itemId: "item-$id",
    estimatedPrice: estimatedPrice,
    estimatedCurrency: "GBP",
    createdAt: DateTime.now(),
    itemName: itemName,
    itemPhotoUrl: null,
    itemCategory: itemCategory,
    itemBrand: itemBrand,
    itemWearCount: 3,
    itemLastWornDate: DateTime.now().subtract(const Duration(days: 200)),
    itemCreatedAt: DateTime.now().subtract(const Duration(days: 365)),
  );
}

Future<void> _pumpAndResolve(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

void main() {
  group("ResalePromptsScreen", () {
    testWidgets("shows loading indicator during fetch", (tester) async {
      final service = _MockResalePromptService(prompts: [_makePrompt()]);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      // First frame should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("displays health score summary card at top", (tester) async {
      final service = _MockResalePromptService(prompts: [_makePrompt()]);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      await _pumpAndResolve(tester);

      expect(find.text("Wardrobe Health Score"), findsOneWidget);
      expect(find.text("72"), findsOneWidget);
      expect(find.text("Improve your score by decluttering!"), findsOneWidget);
    });

    testWidgets("displays prompt item cards with name, category, estimated price",
        (tester) async {
      final service = _MockResalePromptService(prompts: [
        _makePrompt(id: "p1", itemName: "Blue Shirt", itemCategory: "Tops", estimatedPrice: 48),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      await _pumpAndResolve(tester);

      expect(find.text("Blue Shirt"), findsOneWidget);
      expect(find.text("~48 GBP"), findsOneWidget);
      expect(find.text("List for Sale"), findsOneWidget);
      expect(find.text("I'll Keep It"), findsOneWidget);
    });

    testWidgets("'I'll Keep It' button calls dismiss and removes item",
        (tester) async {
      final service = _MockResalePromptService(prompts: [_makePrompt()]);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      await _pumpAndResolve(tester);

      // Tap dismiss
      await tester.tap(find.text("I'll Keep It"));
      await _pumpAndResolve(tester);

      expect(service.dismissedIds, contains("prompt-1"));
      // Item should be removed -- empty state should appear
      expect(find.textContaining("No items to declutter"), findsOneWidget);
    });

    testWidgets("empty state shows when no pending prompts", (tester) async {
      final service = _MockResalePromptService(prompts: []);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      await _pumpAndResolve(tester);

      expect(find.textContaining("No items to declutter"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets("semantics labels present on interactive elements",
        (tester) async {
      final service = _MockResalePromptService(prompts: [_makePrompt()]);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      await _pumpAndResolve(tester);

      // Check semantics labels
      expect(
        find.bySemanticsLabel(RegExp("Resale suggestions")),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp("List item for sale")),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp("Keep this item")),
        findsOneWidget,
      );
    });

    testWidgets("'List for Sale' button calls accept", (tester) async {
      final service = _MockResalePromptService(prompts: [_makePrompt()]);

      await tester.pumpWidget(MaterialApp(
        home: ResalePromptsScreen(
          apiClient: _buildApiClient(),
          resalePromptService: service,
        ),
      ));

      await _pumpAndResolve(tester);

      // Tap accept
      await tester.tap(find.text("List for Sale"));
      await _pumpAndResolve(tester);

      expect(service.acceptedIds, contains("prompt-1"));
    });
  });
}
