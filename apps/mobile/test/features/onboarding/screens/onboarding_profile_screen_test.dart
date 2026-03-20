import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/onboarding/screens/onboarding_profile_screen.dart";

void main() {
  group("OnboardingProfileScreen", () {
    late String? capturedName;
    late List<String>? capturedStyles;
    late bool skipCalled;

    setUp(() {
      capturedName = null;
      capturedStyles = null;
      skipCalled = false;
    });

    Widget buildSubject() {
      return MaterialApp(
        home: OnboardingProfileScreen(
          onContinue: (name, styles) {
            capturedName = name;
            capturedStyles = styles;
          },
          onSkip: () {
            skipCalled = true;
          },
        ),
      );
    }

    testWidgets("renders display name field", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("Enter your display name"), findsOneWidget);
    });

    testWidgets("renders all 8 style preference chips", (tester) async {
      await tester.pumpWidget(buildSubject());

      for (final style in kStylePreferences) {
        final capitalized = style[0].toUpperCase() + style.substring(1);
        expect(find.text(capitalized), findsOneWidget);
      }
      expect(find.byType(FilterChip), findsNWidgets(8));
    });

    testWidgets("tapping chips toggles selection", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Tap "Casual" chip
      await tester.tap(find.text("Casual"));
      await tester.pumpAndSettle();

      // Tap "Sporty" chip
      await tester.tap(find.text("Sporty"));
      await tester.pumpAndSettle();

      // Now enter a name and continue
      await tester.enterText(find.byType(TextField), "Alice");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      expect(capturedName, "Alice");
      expect(capturedStyles, isNotNull);
      expect(capturedStyles!, contains("casual"));
      expect(capturedStyles!, contains("sporty"));
    });

    testWidgets("Continue requires non-empty display name", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Continue button should be disabled initially
      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Continue"),
      );
      expect(continueButton.onPressed, isNull);

      // Enter a name
      await tester.enterText(find.byType(TextField), "Alice");
      await tester.pumpAndSettle();

      // Now it should be enabled
      final enabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Continue"),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets("Skip button calls the skip callback", (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Skip for now"));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets("Semantics labels are present", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Verify Semantics widgets exist with the right labels
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Display name",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Continue",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Skip",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "casual style preference",
        ),
        findsOneWidget,
      );
    });
  });
}
