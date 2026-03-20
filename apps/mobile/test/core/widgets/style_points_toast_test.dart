import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/widgets/style_points_toast.dart";

void main() {
  group("StylePointsToast", () {
    testWidgets("renders +N Style Points text with correct styling",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StylePointsToast(pointsAwarded: 10),
          ),
        ),
      );

      expect(find.text("+10 Style Points"), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text("+10 Style Points"));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.fontSize, 14);
      expect(textWidget.style?.color, Colors.white);
    });

    testWidgets("renders sparkle icon (Icons.auto_awesome)", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StylePointsToast(pointsAwarded: 5),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
      expect(icon.size, 20);
      expect(icon.color, const Color(0xFFFBBF24));
    });

    testWidgets("renders bonus label when provided", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StylePointsToast(
              pointsAwarded: 8,
              bonusLabel: "Streak Bonus!",
            ),
          ),
        ),
      );

      expect(find.text("Streak Bonus!"), findsOneWidget);

      final bonusText = tester.widget<Text>(find.text("Streak Bonus!"));
      expect(bonusText.style?.fontSize, 12);
      expect(bonusText.style?.color, const Color(0xFF9CA3AF));
    });

    testWidgets("does not render bonus label when null", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StylePointsToast(pointsAwarded: 5),
          ),
        ),
      );

      // Only the main text should be present, no bonus label
      expect(find.text("+5 Style Points"), findsOneWidget);
      // Verify no secondary text beyond the main one
      final allTexts = find.byType(Text);
      expect(allTexts, findsOneWidget);
    });

    testWidgets("Semantics label present: Earned N style points",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StylePointsToast(pointsAwarded: 10),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Earned 10 style points",
        ),
        findsOneWidget,
      );
    });
  });

  group("showStylePointsToast", () {
    testWidgets("shows a SnackBar", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showStylePointsToast(context, pointsAwarded: 10);
                },
                child: const Text("Show Toast"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Show Toast"));
      await tester.pump();

      // SnackBar should be visible
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text("+10 Style Points"), findsOneWidget);
    });
  });
}
