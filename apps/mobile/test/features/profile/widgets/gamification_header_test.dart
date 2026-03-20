import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/gamification_header.dart";

void main() {
  group("GamificationHeader", () {
    testWidgets('renders current level name and "Level N"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 3,
              currentLevelName: "Fashion Explorer",
              totalPoints: 150,
              currentStreak: 5,
              itemCount: 30,
              nextLevelThreshold: 50,
            ),
          ),
        ),
      );

      expect(find.text("Fashion Explorer"), findsOneWidget);
      expect(find.text("Level 3"), findsOneWidget);
    });

    testWidgets("renders progress bar with correct value", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 2,
              currentLevelName: "Style Starter",
              totalPoints: 50,
              currentStreak: 2,
              itemCount: 15,
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // 15/25 = 0.6
      expect(progressIndicator.value, closeTo(0.6, 0.01));
    });

    testWidgets('renders "Max Level Reached" when nextLevelThreshold is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 6,
              currentLevelName: "Style Master",
              totalPoints: 500,
              currentStreak: 10,
              itemCount: 250,
              nextLevelThreshold: null,
            ),
          ),
        ),
      );

      expect(find.text("Max Level Reached"), findsOneWidget);
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, 1.0);
    });

    testWidgets("renders total points with sparkle icon", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 2,
              currentLevelName: "Style Starter",
              totalPoints: 150,
              currentStreak: 3,
              itemCount: 15,
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.text("150"), findsOneWidget);
    });

    testWidgets("renders current streak with flame icon", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 2,
              currentLevelName: "Style Starter",
              totalPoints: 150,
              currentStreak: 5,
              itemCount: 15,
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text("5"), findsOneWidget);
    });

    testWidgets("renders item count with wardrobe icon", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 2,
              currentLevelName: "Style Starter",
              totalPoints: 150,
              currentStreak: 3,
              itemCount: 15,
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.checkroom), findsOneWidget);
      expect(find.text("15"), findsOneWidget);
    });

    testWidgets("streak flame icon is colored when streak > 0",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 1,
              currentLevelName: "Closet Rookie",
              totalPoints: 10,
              currentStreak: 3,
              itemCount: 5,
              nextLevelThreshold: 10,
            ),
          ),
        ),
      );

      final flameIcon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(flameIcon.color, const Color(0xFFF97316));
    });

    testWidgets("streak flame icon is gray when streak is 0", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 1,
              currentLevelName: "Closet Rookie",
              totalPoints: 10,
              currentStreak: 0,
              itemCount: 5,
              nextLevelThreshold: 10,
            ),
          ),
        ),
      );

      final flameIcon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(flameIcon.color, const Color(0xFFD1D5DB));
    });

    testWidgets("Semantics labels present on all stat elements",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 2,
              currentLevelName: "Style Starter",
              totalPoints: 150,
              currentStreak: 5,
              itemCount: 15,
              nextLevelThreshold: 25,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Total points: 150",
        ),
        findsOneWidget,
      );
      // Streak semantics now includes freeze status
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Current streak: 5 days"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Wardrobe items: 15",
        ),
        findsOneWidget,
      );
    });

    // --- Story 6.3: Streak freeze indicator ---

    testWidgets("streak chip shows blue snowflake when streakFreezeAvailable=true",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 1,
              currentLevelName: "Closet Rookie",
              totalPoints: 10,
              currentStreak: 3,
              itemCount: 5,
              nextLevelThreshold: 10,
              streakFreezeAvailable: true,
            ),
          ),
        ),
      );

      final snowflake = tester.widget<Icon>(find.byIcon(Icons.ac_unit));
      expect(snowflake.color, const Color(0xFF2563EB));
    });

    testWidgets("streak chip shows gray snowflake when streakFreezeAvailable=false",
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 1,
              currentLevelName: "Closet Rookie",
              totalPoints: 10,
              currentStreak: 3,
              itemCount: 5,
              nextLevelThreshold: 10,
              streakFreezeAvailable: false,
            ),
          ),
        ),
      );

      final snowflake = tester.widget<Icon>(find.byIcon(Icons.ac_unit));
      expect(snowflake.color, const Color(0xFFD1D5DB));
    });

    testWidgets("onStreakTap callback fires when streak area tapped",
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 1,
              currentLevelName: "Closet Rookie",
              totalPoints: 10,
              currentStreak: 3,
              itemCount: 5,
              nextLevelThreshold: 10,
              onStreakTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Tap the streak area (contains the flame icon)
      await tester.tap(find.byIcon(Icons.local_fire_department));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets("Semantics label for freeze status present", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationHeader(
              currentLevel: 1,
              currentLevelName: "Closet Rookie",
              totalPoints: 10,
              currentStreak: 3,
              itemCount: 5,
              nextLevelThreshold: 10,
              streakFreezeAvailable: true,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Streak freeze available"),
        ),
        findsOneWidget,
      );
    });
  });
}
