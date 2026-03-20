import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/onboarding/onboarding_flow.dart";
import "package:vestiaire_mobile/src/features/onboarding/screens/first_five_items_screen.dart";

void main() {
  group("OnboardingFlow", () {
    // ignore: unused_local_variable
    late bool completeCalled;
    late bool skipCalled;
    late String? profileName;
    // ignore: unused_local_variable
    late List<String>? profileStyles;
    // ignore: unused_local_variable
    late bool enableNotificationsCalled;

    setUp(() {
      completeCalled = false;
      skipCalled = false;
      profileName = null;
      profileStyles = null;
      enableNotificationsCalled = false;
    });

    Widget buildSubject({List<OnboardingItem> items = const []}) {
      return MaterialApp(
        home: Scaffold(
          body: OnboardingFlow(
            items: items,
            onComplete: () {
              completeCalled = true;
            },
            onSkip: () {
              skipCalled = true;
            },
            onProfileSubmit: (name, styles) {
              profileName = name;
              profileStyles = styles;
            },
            onPhotoSubmit: (_) {},
            onAddItem: (_) {},
            onEnableNotifications: () {
              enableNotificationsCalled = true;
            },
          ),
        ),
      );
    }

    testWidgets("flow starts at profile step", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Should see profile screen content
      expect(find.text("What should we call you?"), findsOneWidget);
      expect(find.text("Enter your display name"), findsOneWidget);
    });

    testWidgets("step indicator renders 4 segments", (tester) async {
      await tester.pumpWidget(buildSubject());

      // The step indicator has 4 containers (one per step)
      expect(
        find.bySemanticsLabel("Onboarding step 1 of 4"),
        findsOneWidget,
      );
    });

    testWidgets("navigation from profile to photo step", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Fill in display name
      await tester.enterText(find.byType(TextField), "Alice");
      await tester.pumpAndSettle();

      // Tap Continue
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Should now be on photo step
      expect(find.text("Add a Profile Photo"), findsOneWidget);
      expect(profileName, "Alice");
    });

    testWidgets("navigation from photo to notifications step",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Go through profile step
      await tester.enterText(find.byType(TextField), "Alice");
      await tester.pumpAndSettle();
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Now on photo step, tap Continue
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Should now be on notification permission step
      expect(find.text("Stay in the Loop"), findsOneWidget);
      expect(find.text("Enable Notifications"), findsOneWidget);
    });

    testWidgets("notification step exists between photo and first-5-items",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Go through profile step
      await tester.enterText(find.byType(TextField), "Alice");
      await tester.pumpAndSettle();
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Go through photo step
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Should be on notifications step
      expect(find.text("Stay in the Loop"), findsOneWidget);

      // Skip notifications to get to first-5-items (scroll into view first)
      await tester.ensureVisible(find.text("Not Now"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Not Now"));
      await tester.pumpAndSettle();

      // Should now be on first-5-items step
      expect(find.text("First 5 Items Challenge"), findsOneWidget);
      expect(find.text("0/5 items added"), findsOneWidget);
    });

    testWidgets("skip on notification step advances to first-5-items",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Navigate to notifications step
      await tester.enterText(find.byType(TextField), "Alice");
      await tester.pumpAndSettle();
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Now on notifications step, scroll and tap Not Now
      await tester.ensureVisible(find.text("Not Now"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Not Now"));
      await tester.pumpAndSettle();

      // Should be on first-5-items
      expect(find.text("First 5 Items Challenge"), findsOneWidget);
    });

    testWidgets("skip on profile step calls skip callback", (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Skip for now"));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });
  });
}
