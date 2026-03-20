import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/onboarding/screens/onboarding_photo_screen.dart";

void main() {
  group("OnboardingPhotoScreen", () {
    late String? capturedPhotoPath;
    late bool skipCalled;

    setUp(() {
      capturedPhotoPath = null;
      skipCalled = false;
    });

    Widget buildSubject() {
      return MaterialApp(
        home: OnboardingPhotoScreen(
          onContinue: (photoPath) {
            capturedPhotoPath = photoPath;
          },
          onSkip: () {
            skipCalled = true;
          },
        ),
      );
    }

    testWidgets("renders avatar placeholder", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets("renders Choose Photo button", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Choose Photo"), findsOneWidget);
    });

    testWidgets("Skip button calls the skip callback", (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Skip for now"));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets("Continue button is present", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Continue"), findsOneWidget);
    });

    testWidgets("Continue without photo passes null", (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      expect(capturedPhotoPath, isNull);
    });

    testWidgets("Semantics labels are present", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Verify Semantics wrapper widgets exist with the right labels
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Profile photo",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Choose Photo",
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
    });
  });
}
