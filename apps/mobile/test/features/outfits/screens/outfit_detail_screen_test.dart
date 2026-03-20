import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";
import "package:vestiaire_mobile/src/features/outfits/models/saved_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/screens/outfit_detail_screen.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockOutfitPersistenceService extends OutfitPersistenceService {
  _MockOutfitPersistenceService({
    this.toggleResult,
    this.deleteResult = true,
  }) : super(
          apiClient: ApiClient(
            baseUrl: "http://localhost:3000",
            authService: _MockAuthService(),
            httpClient:
                http_testing.MockClient((_) async => http.Response("{}", 200)),
          ),
        );

  final SavedOutfit? toggleResult;
  final bool deleteResult;
  String? lastToggleId;
  bool? lastToggleFavorite;
  String? lastDeleteId;

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
  bool isFavorite = false,
  String? explanation = "Perfect for spring weather",
  String? occasion = "everyday",
  List<OutfitSuggestionItem>? items,
}) {
  return SavedOutfit(
    id: "outfit-1",
    name: "Spring Casual",
    explanation: explanation,
    occasion: occasion,
    source: "ai",
    isFavorite: isFavorite,
    createdAt: DateTime.now(),
    items: items ??
        const [
          OutfitSuggestionItem(
            id: "item-1",
            name: "White Shirt",
            category: "tops",
            color: "white",
            photoUrl: null,
          ),
          OutfitSuggestionItem(
            id: "item-2",
            name: "Blue Jeans",
            category: "bottoms",
            color: "blue",
            photoUrl: null,
          ),
        ],
  );
}

Widget _buildApp({
  required SavedOutfit outfit,
  required OutfitPersistenceService service,
}) {
  return MaterialApp(
    home: OutfitDetailScreen(
      outfit: outfit,
      outfitPersistenceService: service,
    ),
  );
}

void main() {
  group("OutfitDetailScreen", () {
    testWidgets("renders outfit name, source chip, occasion, and created date",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(
          _buildApp(outfit: _testOutfit(), service: service));
      await tester.pumpAndSettle();

      expect(find.text("Spring Casual"), findsOneWidget);
      expect(find.text("AI"), findsOneWidget);
      expect(find.text("everyday"), findsOneWidget);
      expect(find.text("Created Today"), findsOneWidget);
    });

    testWidgets("renders explanation section when explanation is present",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(_buildApp(
        outfit: _testOutfit(explanation: "Great for warm days"),
        service: service,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Why this outfit?"), findsOneWidget);
      expect(find.text("Great for warm days"), findsOneWidget);
    });

    testWidgets("does not render explanation section when explanation is null",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(_buildApp(
        outfit: _testOutfit(explanation: null),
        service: service,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Why this outfit?"), findsNothing);
    });

    testWidgets("renders item list with name, category, and color",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(
          _buildApp(outfit: _testOutfit(), service: service));
      await tester.pumpAndSettle();

      expect(find.text("Items"), findsOneWidget);
      expect(find.text("White Shirt"), findsOneWidget);
      expect(find.text("tops"), findsOneWidget);
      expect(find.text("white"), findsOneWidget);
      expect(find.text("Blue Jeans"), findsOneWidget);
      expect(find.text("bottoms"), findsOneWidget);
      expect(find.text("blue"), findsOneWidget);
    });

    testWidgets("renders gray placeholder for items with null photoUrl",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(
          _buildApp(outfit: _testOutfit(), service: service));
      await tester.pumpAndSettle();

      // Items with null photoUrl should show gray Container with image icon
      expect(find.byIcon(Icons.image), findsNWidgets(2));
    });

    testWidgets("favorite icon in AppBar toggles on tap", (tester) async {
      final outfit = _testOutfit(isFavorite: false);
      final service = _MockOutfitPersistenceService(
        toggleResult: _testOutfit(isFavorite: true),
      );

      await tester.pumpWidget(_buildApp(outfit: outfit, service: service));
      await tester.pumpAndSettle();

      // Should show outline heart
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Tap favorite
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // Should now show filled heart (optimistic)
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets("favorite toggle reverts on API failure", (tester) async {
      final outfit = _testOutfit(isFavorite: false);
      final service = _MockOutfitPersistenceService(toggleResult: null);

      await tester.pumpWidget(_buildApp(outfit: outfit, service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      // Should revert to outline
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text("Failed to update favorite. Please try again."),
          findsOneWidget);
    });

    testWidgets("tapping Delete Outfit shows confirmation dialog",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(
          _buildApp(outfit: _testOutfit(), service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete Outfit"));
      await tester.pumpAndSettle();

      expect(find.text("Delete this outfit?"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Delete"), findsOneWidget);
    });

    testWidgets("confirming delete calls deleteOutfit and pops screen",
        (tester) async {
      final service = _MockOutfitPersistenceService(deleteResult: true);

      // Use a Navigator to verify pop
      bool popped = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => OutfitDetailScreen(
                    outfit: _testOutfit(),
                    outfitPersistenceService: service,
                  ),
                ),
              );
              popped = result == true;
            },
            child: const Text("Open"),
          ),
        ),
      ));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete Outfit"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      expect(service.lastDeleteId, "outfit-1");
      expect(popped, true);
    });

    testWidgets("delete failure shows error snackbar", (tester) async {
      final service = _MockOutfitPersistenceService(deleteResult: false);

      await tester.pumpWidget(
          _buildApp(outfit: _testOutfit(), service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete Outfit"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      expect(find.text("Failed to delete outfit. Please try again."),
          findsOneWidget);
    });

    testWidgets("semantics labels are present on all elements",
        (tester) async {
      final service = _MockOutfitPersistenceService();

      await tester.pumpWidget(
          _buildApp(outfit: _testOutfit(), service: service));
      await tester.pumpAndSettle();

      // Outfit name semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Outfit name: Spring Casual"),
        ),
        findsOneWidget,
      );

      // Favorite button semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Mark Spring Casual as favorite"),
        ),
        findsOneWidget,
      );

      // Delete button semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Delete this outfit"),
        ),
        findsOneWidget,
      );

      // Item semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Item: tops"),
        ),
        findsOneWidget,
      );
    });
  });
}
