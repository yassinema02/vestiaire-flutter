import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/location_permission_card.dart";

void main() {
  group("LocationPermissionCard", () {
    testWidgets("renders title, explanation text, Enable Location button, Not Now button",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPermissionCard(
              onEnableLocation: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );

      expect(find.text("Enable Location"), findsWidgets); // title + button
      expect(
        find.text(
          "To show weather and tailor outfit suggestions to your conditions",
        ),
        findsOneWidget,
      );
      expect(find.text("Not Now"), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets("Enable Location button triggers onEnableLocation callback",
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPermissionCard(
              onEnableLocation: () => called = true,
              onNotNow: () {},
            ),
          ),
        ),
      );

      // Tap the ElevatedButton (not the title text)
      await tester.tap(find.byType(ElevatedButton));
      expect(called, true);
    });

    testWidgets("Not Now button triggers onNotNow callback", (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPermissionCard(
              onEnableLocation: () {},
              onNotNow: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Not Now"));
      expect(called, true);
    });

    testWidgets("Semantics labels present on both buttons", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPermissionCard(
              onEnableLocation: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Enable Location",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Not Now",
        ),
        findsOneWidget,
      );
    });
  });
}
