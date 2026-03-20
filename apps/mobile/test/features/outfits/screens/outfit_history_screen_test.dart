import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/saved_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/screens/outfit_history_screen.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A mock OutfitPersistenceService that allows controlling responses.
class _MockOutfitPersistenceService extends OutfitPersistenceService {
  _MockOutfitPersistenceService({
    this.outfits = const [],
    this.toggleResult,
    this.deleteResult = true,
    this.shouldThrow = false,
  }) : super(
          apiClient: ApiClient(
            baseUrl: "http://localhost:3000",
            authService: _MockAuthService(),
            httpClient: http_testing.MockClient((_) async =>
                http.Response("{}", 200)),
          ),
        );

  final List<SavedOutfit> outfits;
  final SavedOutfit? toggleResult;
  final bool deleteResult;
  final bool shouldThrow;

  int listCallCount = 0;
  String? lastToggleId;
  bool? lastToggleFavorite;
  String? lastDeleteId;

  @override
  Future<List<SavedOutfit>> listOutfits() async {
    listCallCount++;
    if (shouldThrow) throw Exception("Failed to load");
    return List.from(outfits);
  }

  @override
  Future<SavedOutfit?> toggleFavorite(String outfitId, bool isFavorite) async {
    lastToggleId = outfitId;
    lastToggleFavorite = isFavorite;
    return toggleResult;
  }

  @override
  Future<bool> deleteOutfit(String outfitId) async {
    lastDeleteId = outfitId;
    return deleteResult;
  }
}

SavedOutfit _testOutfit({
  String id = "outfit-1",
  String? name = "Spring Casual",
  String source = "ai",
  bool isFavorite = false,
  String? occasion = "everyday",
}) {
  return SavedOutfit(
    id: id,
    name: name,
    explanation: "Perfect for spring",
    occasion: occasion,
    source: source,
    isFavorite: isFavorite,
    createdAt: DateTime.now(),
    items: const [],
  );
}

Widget _buildApp({
  required OutfitPersistenceService service,
  ApiClient? apiClient,
}) {
  return MaterialApp(
    home: OutfitHistoryScreen(
      outfitPersistenceService: service,
      apiClient: apiClient,
    ),
  );
}

void main() {
  group("OutfitHistoryScreen", () {
    testWidgets("renders loading state with CircularProgressIndicator",
        (tester) async {
      // Use a service that takes some time
      final service = _MockOutfitPersistenceService(outfits: []);

      await tester.pumpWidget(_buildApp(service: service));

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("renders outfit list after outfits load", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [
          _testOutfit(id: "1", name: "Outfit One"),
          _testOutfit(id: "2", name: "Outfit Two"),
        ],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text("Outfit One"), findsOneWidget);
      expect(find.text("Outfit Two"), findsOneWidget);
    });

    testWidgets(
        "outfit cards show name, source chip, occasion, date, and favorite icon",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(source: "ai", occasion: "everyday")],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text("Spring Casual"), findsOneWidget);
      expect(find.text("AI"), findsOneWidget);
      expect(find.text("everyday"), findsOneWidget);
      expect(find.text("Today"), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets("empty state is shown when no outfits exist", (tester) async {
      final service = _MockOutfitPersistenceService(outfits: []);

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text("No outfits saved yet"), findsOneWidget);
      expect(
        find.text("Create outfits from the Home screen or build your own"),
        findsOneWidget,
      );
    });

    testWidgets(
        "empty state shows Create Outfit button when apiClient is provided",
        (tester) async {
      final service = _MockOutfitPersistenceService(outfits: []);
      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: http_testing.MockClient((request) async {
          return http.Response(jsonEncode({"items": []}), 200);
        }),
      );

      await tester.pumpWidget(_buildApp(service: service, apiClient: apiClient));
      await tester.pumpAndSettle();

      expect(find.text("Create Outfit"), findsOneWidget);
    });

    testWidgets("tapping favorite icon calls toggleFavorite", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1", isFavorite: false)],
        toggleResult: _testOutfit(id: "outfit-1", isFavorite: true),
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(service.lastToggleId, "outfit-1");
      expect(service.lastToggleFavorite, true);
    });

    testWidgets("favorite icon toggles optimistically on tap", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1", isFavorite: false)],
        toggleResult: _testOutfit(id: "outfit-1", isFavorite: true),
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // Should now show filled heart (optimistic)
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets("favorite toggle reverts on API failure", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1", isFavorite: false)],
        toggleResult: null, // failure
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      // Should revert to outline
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      // Should show error snackbar
      expect(find.text("Failed to update favorite. Please try again."),
          findsOneWidget);
    });

    testWidgets("swiping left on an outfit shows confirmation dialog",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1")],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      // Find the card container (GestureDetector wrapping the card)
      final cardFinder = find.text("Spring Casual");

      // Swipe left
      await tester.fling(cardFinder, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text("Delete this outfit?"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Delete"), findsOneWidget);
    });

    testWidgets("confirming delete calls deleteOutfit and removes the outfit",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1")],
        deleteResult: true,
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      // Swipe left
      await tester.fling(find.text("Spring Casual"), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      // Confirm delete
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      expect(service.lastDeleteId, "outfit-1");
    });

    testWidgets("delete failure shows error snackbar", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1")],
        deleteResult: false,
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      // Swipe left
      await tester.fling(find.text("Spring Casual"), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text("Delete this outfit?"), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      expect(find.text("Failed to delete outfit. Please try again."),
          findsOneWidget);
    });

    testWidgets("renders error state with retry button when loading fails",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [],
        shouldThrow: true,
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text("Failed to load outfits"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("semantics labels are present on outfit cards",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1", name: "My Outfit")],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Outfit: My Outfit"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("semantics labels are present on favorite buttons",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(id: "outfit-1", name: "My Outfit", isFavorite: false)],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Mark My Outfit as favorite"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("semantics labels are present on empty state", (tester) async {
      final service = _MockOutfitPersistenceService(outfits: []);

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("No outfits saved"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("pull to refresh reloads the outfit list", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit()],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      final initialCallCount = service.listCallCount;

      // Pull to refresh
      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(service.listCallCount, greaterThan(initialCallCount));
    });

    testWidgets("manual source shows Manual chip", (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [_testOutfit(source: "manual")],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text("Manual"), findsOneWidget);
    });

    testWidgets("Plan Week button appears in app bar", (tester) async {
      final service = _MockOutfitPersistenceService(outfits: []);
      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: http_testing.MockClient((request) async {
          return http.Response(jsonEncode({"calendarOutfits": [], "events": []}), 200);
        }),
      );

      await tester.pumpWidget(_buildApp(service: service, apiClient: apiClient));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byTooltip("Plan Week"), findsOneWidget);
    });

    testWidgets("tapping Plan Week navigates to PlanWeekScreen",
        (tester) async {
      final service = _MockOutfitPersistenceService(outfits: []);
      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _MockAuthService(),
        httpClient: http_testing.MockClient((request) async {
          return http.Response(
              jsonEncode({"calendarOutfits": [], "events": []}), 200);
        }),
      );

      await tester.pumpWidget(_buildApp(service: service, apiClient: apiClient));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();

      // Should navigate to PlanWeekScreen
      expect(find.text("Plan Your Week"), findsOneWidget);
    });

    testWidgets("existing outfit history functionality unchanged",
        (tester) async {
      final service = _MockOutfitPersistenceService(
        outfits: [
          _testOutfit(id: "1", name: "Outfit One"),
          _testOutfit(id: "2", name: "Outfit Two"),
        ],
      );

      await tester.pumpWidget(_buildApp(service: service));
      await tester.pumpAndSettle();

      // Outfits should still be displayed
      expect(find.text("Outfit One"), findsOneWidget);
      expect(find.text("Outfit Two"), findsOneWidget);
      // AppBar should still have Outfits title
      expect(find.text("Outfits"), findsOneWidget);
    });
  });
}
