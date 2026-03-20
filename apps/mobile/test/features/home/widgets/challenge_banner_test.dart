import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/challenge_banner.dart";

void main() {
  group("ChallengeBanner", () {
    testWidgets("renders challenge name and progress text", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeBanner(
              name: "Closet Safari",
              currentProgress: 8,
              targetCount: 20,
              timeRemainingSeconds: 432000,
            ),
          ),
        ),
      );

      expect(
        find.text("Closet Safari: 8/20 -- 5 days left"),
        findsOneWidget,
      );
    });

    testWidgets("renders compact progress bar", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeBanner(
              name: "Closet Safari",
              currentProgress: 10,
              targetCount: 20,
            ),
          ),
        ),
      );

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, closeTo(0.5, 0.01));
    });

    testWidgets("renders time remaining", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeBanner(
              name: "Closet Safari",
              currentProgress: 5,
              targetCount: 20,
              timeRemainingSeconds: 259200, // 3 days
            ),
          ),
        ),
      );

      expect(
        find.textContaining("3 days left"),
        findsOneWidget,
      );
    });

    testWidgets("tapping fires onTap callback", (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeBanner(
              name: "Closet Safari",
              currentProgress: 5,
              targetCount: 20,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ChallengeBanner));
      expect(tapped, isTrue);
    });

    testWidgets("Semantics label present", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeBanner(
              name: "Closet Safari",
              currentProgress: 8,
              targetCount: 20,
              timeRemainingSeconds: 432000,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Closet Safari challenge") &&
              w.properties.label!.contains("8 of 20"),
        ),
        findsOneWidget,
      );
    });
  });
}
