import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/onboarding/screens/first_five_items_screen.dart";

void main() {
  group("FirstFiveItemsScreen", () {
    // ignore: unused_local_variable
    late bool doneCalled;
    late bool skipCalled;
    // ignore: unused_local_variable
    late String? addedItemPath;

    setUp(() {
      doneCalled = false;
      skipCalled = false;
      addedItemPath = null;
    });

    Widget buildSubject({List<OnboardingItem> items = const []}) {
      return MaterialApp(
        home: FirstFiveItemsScreen(
          items: items,
          onDone: () {
            doneCalled = true;
          },
          onSkip: () {
            skipCalled = true;
          },
          onAddItem: (path) {
            addedItemPath = path;
          },
        ),
      );
    }

    testWidgets("progress indicator starts at 0/5", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("0/5 items added"), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets("Add Item button renders", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Add Item"), findsOneWidget);
    });

    testWidgets("Skip and Done buttons render", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Done"), findsOneWidget);
      expect(find.text("Skip for now"), findsOneWidget);
    });

    testWidgets("Done is disabled with 0 items", (tester) async {
      await tester.pumpWidget(buildSubject());

      final doneButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Done"),
      );
      expect(doneButton.onPressed, isNull);
    });

    testWidgets("Done is enabled with items", (tester) async {
      await tester.pumpWidget(buildSubject(
        items: [const OnboardingItem(photoUrl: "https://example.com/photo.jpg")],
      ));

      final doneButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Done"),
      );
      expect(doneButton.onPressed, isNotNull);
    });

    testWidgets("Skip calls skip callback", (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Skip for now"));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets("shows progress with items", (tester) async {
      await tester.pumpWidget(buildSubject(
        items: [
          const OnboardingItem(photoUrl: "https://example.com/1.jpg"),
          const OnboardingItem(photoUrl: "https://example.com/2.jpg"),
          const OnboardingItem(photoUrl: "https://example.com/3.jpg"),
        ],
      ));

      expect(find.text("3/5 items added"), findsOneWidget);
    });

    testWidgets("Semantics labels are present", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Progress 0 of 5 items",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Add Item",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Done",
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
