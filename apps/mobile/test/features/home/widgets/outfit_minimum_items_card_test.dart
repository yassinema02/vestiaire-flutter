import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/outfit_minimum_items_card.dart";

void main() {
  group("OutfitMinimumItemsCard", () {
    testWidgets("renders Build your wardrobe title", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitMinimumItemsCard(onAddItems: () {}),
          ),
        ),
      );

      expect(find.text("Build your wardrobe"), findsOneWidget);
    });

    testWidgets("renders Add at least 3 items subtitle", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitMinimumItemsCard(onAddItems: () {}),
          ),
        ),
      );

      expect(
        find.text("Add at least 3 items to get AI outfit suggestions"),
        findsOneWidget,
      );
    });

    testWidgets("Add Items button calls onAddItems callback", (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitMinimumItemsCard(onAddItems: () => callCount++),
          ),
        ),
      );

      await tester.tap(find.text("Add Items"));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets("semantics label is present", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitMinimumItemsCard(onAddItems: () {}),
          ),
        ),
      );

      final semanticsWidget = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Add more items to receive outfit suggestions",
      );
      expect(semanticsWidget, findsOneWidget);
    });
  });
}
