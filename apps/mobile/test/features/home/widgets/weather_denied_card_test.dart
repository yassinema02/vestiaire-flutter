import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/weather_denied_card.dart";

void main() {
  group("WeatherDeniedCard", () {
    testWidgets("renders location-off icon, explanation text, Grant Access button",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherDeniedCard(onGrantAccess: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.location_off), findsOneWidget);
      expect(
        find.text("Location access needed for weather"),
        findsOneWidget,
      );
      expect(
        find.text(
          "Enable location to see local weather and get outfit suggestions tailored to your conditions",
        ),
        findsOneWidget,
      );
      expect(find.text("Grant Access"), findsOneWidget);
    });

    testWidgets("Grant Access button triggers onGrantAccess callback",
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherDeniedCard(onGrantAccess: () => called = true),
          ),
        ),
      );

      await tester.tap(find.text("Grant Access"));
      expect(called, true);
    });

    testWidgets("Semantics labels present", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherDeniedCard(onGrantAccess: () {}),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Grant Access",
        ),
        findsOneWidget,
      );
    });
  });
}
