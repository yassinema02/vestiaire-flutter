import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/level_up_modal.dart";

void main() {
  group("LevelUpModal", () {
    testWidgets("renders new level name as title", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 2,
              newLevelName: "Style Starter",
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(find.text("Style Starter"), findsOneWidget);
    });

    testWidgets('renders "You\'ve reached Level N!" text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 3,
              newLevelName: "Fashion Explorer",
              nextLevelThreshold: 50,
            ),
          ),
        ),
      );

      expect(find.text("You've reached Level 3!"), findsOneWidget);
    });

    testWidgets("renders next level info when nextLevelThreshold provided",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 2,
              newLevelName: "Style Starter",
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(
        find.text("Next: Fashion Explorer at 25 items"),
        findsOneWidget,
      );
    });

    testWidgets(
        "does not render next level info when at max level (nextLevelThreshold null)",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 6,
              newLevelName: "Style Master",
              nextLevelThreshold: null,
            ),
          ),
        ),
      );

      expect(find.textContaining("Next:"), findsNothing);
    });

    testWidgets("renders trophy icon", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 2,
              newLevelName: "Style Starter",
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('renders "Continue" button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 2,
              newLevelName: "Style Starter",
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(find.text("Continue"), findsOneWidget);
    });

    testWidgets('tapping "Continue" dismisses the dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const LevelUpModal(
                    newLevel: 2,
                    newLevelName: "Style Starter",
                    nextLevelThreshold: 25,
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.text("Style Starter"), findsOneWidget);

      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      expect(find.text("Style Starter"), findsNothing);
    });

    testWidgets("Semantics label present", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpModal(
              newLevel: 2,
              newLevelName: "Style Starter",
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  "Congratulations! You've reached level 2, Style Starter",
        ),
        findsOneWidget,
      );
    });
  });
}
