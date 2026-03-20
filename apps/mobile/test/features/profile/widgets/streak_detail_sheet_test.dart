import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/streak_detail_sheet.dart";

void main() {
  group("StreakDetailSheet", () {
    testWidgets("renders current streak count and flame icon", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreakDetailSheet(
                currentStreak: 5,
                longestStreak: 10,
                streakFreezeAvailable: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text("5"), findsOneWidget);
    });

    testWidgets("renders longest streak", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreakDetailSheet(
                currentStreak: 3,
                longestStreak: 15,
                streakFreezeAvailable: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text("15 days"), findsOneWidget);
      expect(find.text("Longest Streak"), findsOneWidget);
    });

    testWidgets(
        'shows "freeze available" with blue snowflake when freeze available',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreakDetailSheet(
                currentStreak: 5,
                longestStreak: 10,
                streakFreezeAvailable: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text("You have 1 freeze this week"), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit), findsOneWidget);

      final snowflake = tester.widget<Icon>(find.byIcon(Icons.ac_unit));
      expect(snowflake.color, const Color(0xFF2563EB));
    });

    testWidgets(
        'shows "Freeze used on [date]" with gray snowflake when freeze consumed',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreakDetailSheet(
                currentStreak: 5,
                longestStreak: 10,
                streakFreezeAvailable: false,
                streakFreezeUsedAt: "2026-03-17",
              ),
            ),
          ),
        ),
      );

      expect(find.text("Freeze used on 2026-03-17"), findsOneWidget);

      final snowflake = tester.widget<Icon>(find.byIcon(Icons.ac_unit));
      expect(snowflake.color, const Color(0xFFD1D5DB));
    });

    testWidgets("renders explanation text", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreakDetailSheet(
                currentStreak: 5,
                longestStreak: 10,
                streakFreezeAvailable: true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(
          "Log an outfit every day to build your streak. If you miss a day, your weekly streak freeze will automatically protect your streak.",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Semantics labels present", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreakDetailSheet(
                currentStreak: 5,
                longestStreak: 10,
                streakFreezeAvailable: true,
              ),
            ),
          ),
        ),
      );

      // Check various Semantics labels
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Streak Details",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Current streak: 5 days",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Streak freeze available",
        ),
        findsOneWidget,
      );
    });
  });
}
