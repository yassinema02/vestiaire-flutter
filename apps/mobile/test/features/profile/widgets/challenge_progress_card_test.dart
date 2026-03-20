import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/challenge_progress_card.dart";

void main() {
  group("ChallengeProgressCard", () {
    testWidgets("renders challenge name and progress text", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 8,
              targetCount: 20,
              status: "active",
              timeRemainingSeconds: 432000,
            ),
          ),
        ),
      );

      expect(find.text("Closet Safari"), findsOneWidget);
      expect(find.text("8/20 items"), findsOneWidget);
    });

    testWidgets("renders progress bar with correct value", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 10,
              targetCount: 20,
              status: "active",
            ),
          ),
        ),
      );

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, closeTo(0.5, 0.01));
    });

    testWidgets("renders time remaining text", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 5,
              targetCount: 20,
              status: "active",
              timeRemainingSeconds: 432000, // 5 days
            ),
          ),
        ),
      );

      expect(find.text("5 days left"), findsOneWidget);
    });

    testWidgets("shows Accept Challenge button when onAccept provided and status is not active",
        (tester) async {
      bool accepted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 0,
              targetCount: 20,
              status: "not_accepted",
              onAccept: () => accepted = true,
            ),
          ),
        ),
      );

      expect(find.text("Accept Challenge"), findsOneWidget);

      await tester.tap(find.text("Accept Challenge"));
      expect(accepted, isTrue);
    });

    testWidgets("shows completed state with green styling", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 20,
              targetCount: 20,
              status: "completed",
            ),
          ),
        ),
      );

      expect(find.text("Closet Safari Complete!"), findsOneWidget);
      expect(find.text("Premium unlocked for 30 days"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets("shows expired state with gray styling", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 12,
              targetCount: 20,
              status: "expired",
            ),
          ),
        ),
      );

      expect(find.text("Challenge Expired"), findsOneWidget);
      expect(find.byIcon(Icons.timer_off), findsOneWidget);
    });

    testWidgets("renders reward description", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 5,
              targetCount: 20,
              status: "active",
              rewardDescription: "Unlock 1 month Premium free",
            ),
          ),
        ),
      );

      expect(find.text("Unlock 1 month Premium free"), findsOneWidget);
    });

    testWidgets("Semantics label present", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChallengeProgressCard(
              name: "Closet Safari",
              currentProgress: 8,
              targetCount: 20,
              status: "active",
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  "Challenge: Closet Safari, progress 8 of 20 items",
        ),
        findsOneWidget,
      );
    });
  });
}
