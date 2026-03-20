import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/dressing_tip_widget.dart";

void main() {
  group("DressingTipWidget", () {
    testWidgets("renders tip icon and tip text when tip is provided",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DressingTipWidget(
              tip: "Grab a waterproof jacket",
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.tips_and_updates), findsOneWidget);
      expect(find.text("Grab a waterproof jacket"), findsOneWidget);
    });

    testWidgets("renders nothing (SizedBox.shrink) when tip is empty string",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DressingTipWidget(tip: ""),
          ),
        ),
      );

      expect(find.byIcon(Icons.tips_and_updates), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets("Semantics label includes 'Dressing tip:' prefix",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DressingTipWidget(
              tip: "Layer up today",
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(DressingTipWidget));
      expect(semantics.label, contains("Dressing tip:"));
      expect(semantics.label, contains("Layer up today"));
    });

    testWidgets("text styling matches spec (13px, italic, #4B5563)",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DressingTipWidget(
              tip: "Light and breezy",
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text("Light and breezy"));
      final style = textWidget.style!;
      expect(style.fontSize, 13);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, const Color(0xFF4B5563));
    });

    testWidgets("icon matches spec (18px, #4F46E5)", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DressingTipWidget(
              tip: "Some tip",
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.tips_and_updates));
      expect(icon.size, 18);
      expect(icon.color, const Color(0xFF4F46E5));
    });
  });
}
