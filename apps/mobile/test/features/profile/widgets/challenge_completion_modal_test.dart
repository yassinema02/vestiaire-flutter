import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/challenge_completion_modal.dart";

void main() {
  group("ChallengeCompletionModal", () {
    testWidgets("renders trophy icon, title, reward description", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeCompletionModal(
              challengeName: "Closet Safari",
              rewardDescription: "1 month Premium free",
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.text("Closet Safari Complete!"), findsOneWidget);
      expect(find.text("You've unlocked 1 month Premium free!"), findsOneWidget);
    });

    testWidgets("renders trial expiry date when provided", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeCompletionModal(
              challengeName: "Closet Safari",
              rewardDescription: "1 month Premium free",
              trialExpiresAt: "2026-04-19T10:00:00Z",
            ),
          ),
        ),
      );

      expect(
        find.text("Your Premium trial expires on 19/4/2026"),
        findsOneWidget,
      );
    });

    testWidgets("renders Continue button", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeCompletionModal(
              challengeName: "Closet Safari",
              rewardDescription: "1 month Premium free",
            ),
          ),
        ),
      );

      expect(find.text("Continue"), findsOneWidget);
    });

    testWidgets("tapping Continue dismisses dialog", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const ChallengeCompletionModal(
                    challengeName: "Closet Safari",
                    rewardDescription: "1 month Premium free",
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

      expect(find.text("Closet Safari Complete!"), findsOneWidget);

      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      expect(find.text("Closet Safari Complete!"), findsNothing);
    });

    testWidgets("Semantics label present", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeCompletionModal(
              challengeName: "Closet Safari",
              rewardDescription: "1 month Premium free",
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  "Congratulations! Closet Safari complete. Premium unlocked for 30 days.",
        ),
        findsOneWidget,
      );
    });
  });
}
