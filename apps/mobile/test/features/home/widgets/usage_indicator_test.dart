import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/usage_indicator.dart";
import "package:vestiaire_mobile/src/features/outfits/models/usage_info.dart";

void main() {
  group("UsageIndicator", () {
    testWidgets("renders remaining count text when remaining > 0",
        (tester) async {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 1,
        remaining: 2,
        resetsAt: "2026-03-16T00:00:00.000Z",
        isPremium: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageIndicator(usageInfo: info),
          ),
        ),
      );

      expect(
        find.text("2 of 3 generations remaining today"),
        findsOneWidget,
      );
    });

    testWidgets("renders 'Daily limit reached' text when remaining is 0",
        (tester) async {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        resetsAt: "2026-03-16T00:00:00.000Z",
        isPremium: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageIndicator(usageInfo: info),
          ),
        ),
      );

      expect(find.text("Daily limit reached"), findsOneWidget);
    });

    testWidgets("renders nothing (SizedBox.shrink) when user is premium",
        (tester) async {
      const info = UsageInfo(
        dailyLimit: null,
        used: 5,
        remaining: null,
        resetsAt: null,
        isPremium: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageIndicator(usageInfo: info),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      // Should not find any text
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets("correct icon is shown for remaining > 0 state",
        (tester) async {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 1,
        remaining: 2,
        isPremium: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageIndicator(usageInfo: info),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets("correct icon is shown for limit-reached state",
        (tester) async {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        isPremium: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageIndicator(usageInfo: info),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets("Semantics labels are present", (tester) async {
      final handle = tester.ensureSemantics();

      const info = UsageInfo(
        dailyLimit: 3,
        used: 1,
        remaining: 2,
        isPremium: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageIndicator(usageInfo: info),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "2 of 3 generations remaining today",
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
