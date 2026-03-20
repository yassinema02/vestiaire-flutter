import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/outfit_suggestion_card.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";

OutfitSuggestion _testSuggestion({
  bool includeNullPhotoUrl = false,
}) {
  return OutfitSuggestion(
    id: "suggestion-1",
    name: "Casual Blue Look",
    items: [
      const OutfitSuggestionItem(
        id: "item-1",
        name: "Blue T-Shirt",
        category: "tops",
        color: "blue",
        photoUrl: "https://example.com/photo1.jpg",
      ),
      OutfitSuggestionItem(
        id: "item-2",
        name: "Dark Jeans",
        category: "bottoms",
        color: "navy",
        photoUrl: includeNullPhotoUrl ? null : "https://example.com/photo2.jpg",
      ),
    ],
    explanation: "A comfortable outfit for a mild spring day.",
    occasion: "everyday",
  );
}

void main() {
  group("OutfitSuggestionCard", () {
    testWidgets("renders outfit name", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      expect(find.text("Casual Blue Look"), findsOneWidget);
    });

    testWidgets("renders AI badge/chip", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      expect(find.text("AI"), findsOneWidget);
    });

    testWidgets("renders item thumbnails in a horizontal scrollable row",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      // Should find horizontal SingleChildScrollView for items
      final scrollViews = find.byType(SingleChildScrollView);
      expect(scrollViews, findsOneWidget);
    });

    testWidgets("shows category label below each item thumbnail",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      expect(find.text("tops"), findsOneWidget);
      expect(find.text("bottoms"), findsOneWidget);
    });

    testWidgets("renders Why this outfit? label and explanation text",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      expect(find.text("Why this outfit?"), findsOneWidget);
      expect(
        find.text("A comfortable outfit for a mild spring day."),
        findsOneWidget,
      );
    });

    testWidgets("renders gray placeholder for items with null photoUrl",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(
              suggestion: _testSuggestion(includeNullPhotoUrl: true),
            ),
          ),
        ),
      );

      // Should find the placeholder icon for the null photoUrl item
      expect(find.byIcon(Icons.checkroom), findsOneWidget);
    });

    testWidgets("semantics labels are present for card, items, and explanation",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      // Find Semantics widgets with correct labels
      final cardSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Outfit suggestion: Casual Blue Look",
      );
      expect(cardSemantics, findsOneWidget);

      final itemSemantics1 = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Outfit item: tops",
      );
      expect(itemSemantics1, findsOneWidget);

      final itemSemantics2 = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Outfit item: bottoms",
      );
      expect(itemSemantics2, findsOneWidget);

      final explanationSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Outfit explanation: A comfortable outfit for a mild spring day.",
      );
      expect(explanationSemantics, findsOneWidget);
    });

    testWidgets("item thumbnails are NOT tappable (no gesture handler)",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSuggestionCard(suggestion: _testSuggestion()),
          ),
        ),
      );

      // There should be no GestureDetector or InkWell wrapping the item thumbnails
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
