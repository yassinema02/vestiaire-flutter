import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/usage_limit_card.dart";
import "package:vestiaire_mobile/src/features/outfits/models/usage_limit_result.dart";

void main() {
  group("UsageLimitCard", () {
    const limitInfo = UsageLimitReachedResult(
      dailyLimit: 3,
      used: 3,
      remaining: 0,
      resetsAt: "2026-03-16T00:00:00.000Z",
    );

    testWidgets("renders 'Daily Limit Reached' title", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(limitInfo: limitInfo),
          ),
        ),
      );

      expect(find.text("Daily Limit Reached"), findsOneWidget);
    });

    testWidgets("renders subtitle about used suggestions", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(limitInfo: limitInfo),
          ),
        ),
      );

      expect(
        find.text("You've used all 3 outfit suggestions for today"),
        findsOneWidget,
      );
    });

    testWidgets("renders 'Resets at midnight UTC' text", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(limitInfo: limitInfo),
          ),
        ),
      );

      expect(find.text("Resets at midnight UTC"), findsOneWidget);
    });

    testWidgets("renders 'Go Premium' CTA button", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(limitInfo: limitInfo),
          ),
        ),
      );

      expect(
        find.text("Go Premium for Unlimited Suggestions"),
        findsOneWidget,
      );
    });

    testWidgets("CTA button calls onUpgrade callback when tapped",
        (tester) async {
      var upgradeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(
              limitInfo: limitInfo,
              onUpgrade: () => upgradeCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Go Premium for Unlimited Suggestions"));
      await tester.pumpAndSettle();

      expect(upgradeCalled, true);
    });

    testWidgets("CTA button does not crash when onUpgrade is null",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(limitInfo: limitInfo),
          ),
        ),
      );

      // Should not throw
      await tester.tap(find.text("Go Premium for Unlimited Suggestions"));
      await tester.pumpAndSettle();
    });

    testWidgets(
        "CTA button calls onUpgrade callback when subscriptionService is null (backward compat)",
        (tester) async {
      var upgradeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(
              limitInfo: limitInfo,
              onUpgrade: () => upgradeCalled = true,
              subscriptionService: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Go Premium for Unlimited Suggestions"));
      await tester.pumpAndSettle();

      expect(upgradeCalled, true);
    });

    testWidgets("Semantics labels are present", (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageLimitCard(limitInfo: limitInfo),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  "Daily outfit generation limit reached",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  "Upgrade to premium for unlimited suggestions",
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
