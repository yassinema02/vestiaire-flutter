import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/streak_celebration_toast.dart";

void main() {
  group("StreakCelebrationToast", () {
    testWidgets("renders flame icon and 'N Day Streak!' text", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationToast(currentStreak: 5),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text("5 Day Streak!"), findsOneWidget);
    });

    testWidgets('renders milestone label for 7-day streak ("Week Warrior")',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationToast(currentStreak: 7),
          ),
        ),
      );

      expect(find.text("7 Day Streak!"), findsOneWidget);
      expect(find.text("Week Warrior"), findsOneWidget);
    });

    testWidgets('renders milestone label for 30-day streak ("Streak Legend")',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationToast(currentStreak: 30),
          ),
        ),
      );

      expect(find.text("30 Day Streak!"), findsOneWidget);
      expect(find.text("Streak Legend"), findsOneWidget);
    });

    testWidgets("does NOT render milestone label for non-milestone streak",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationToast(currentStreak: 5),
          ),
        ),
      );

      expect(find.text("5 Day Streak!"), findsOneWidget);
      // Should not find any milestone labels
      expect(find.text("Week Warrior"), findsNothing);
      expect(find.text("Two Week Champion"), findsNothing);
      expect(find.text("Streak Legend"), findsNothing);
      expect(find.text("Streak Master"), findsNothing);
      expect(find.text("Streak Centurion"), findsNothing);
    });

    testWidgets("Semantics label present for streak extended", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationToast(currentStreak: 5),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Streak extended to 5 days",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Semantics label present for new streak", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationToast(currentStreak: 1, isNewStreak: true),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "New streak started",
        ),
        findsOneWidget,
      );
    });

    testWidgets("showStreakCelebrationToast shows a SnackBar", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showStreakCelebrationToast(
                  context,
                  currentStreak: 3,
                ),
                child: const Text("Show Toast"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Show Toast"));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text("3 Day Streak!"), findsOneWidget);
    });
  });
}
