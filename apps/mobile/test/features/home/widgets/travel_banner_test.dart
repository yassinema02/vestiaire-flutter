import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/travel_banner.dart";
import "package:vestiaire_mobile/src/features/outfits/models/trip.dart";

Trip _testTrip({String destination = "Barcelona"}) {
  return Trip(
    id: "trip_barcelona_2026-03-20_2026-03-24",
    destination: destination,
    startDate: DateTime(2026, 3, 20),
    endDate: DateTime(2026, 3, 24),
    durationDays: 4,
    eventIds: ["e1"],
    destinationLatitude: 41.39,
    destinationLongitude: 2.17,
  );
}

void main() {
  group("TravelBanner", () {
    testWidgets("renders trip destination and date range",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(trip: _testTrip()),
          ),
        ),
      );

      expect(find.text("Trip to Barcelona"), findsOneWidget);
      // Date range should appear
      expect(find.textContaining("4 days"), findsOneWidget);
    });

    testWidgets("shows View Packing List button", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(trip: _testTrip()),
          ),
        ),
      );

      expect(find.text("View Packing List"), findsOneWidget);
    });

    testWidgets("tapping View Packing List calls onViewPackingList callback",
        (tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(
              trip: _testTrip(),
              onViewPackingList: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text("View Packing List"));
      expect(called, true);
    });

    testWidgets("shows dismiss button", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(trip: _testTrip()),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets("tapping dismiss calls onDismiss callback",
        (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(
              trip: _testTrip(),
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, true);
    });

    testWidgets("shows Upcoming Trip when destination is empty",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(trip: _testTrip(destination: "")),
          ),
        ),
      );

      expect(find.text("Upcoming Trip"), findsOneWidget);
    });

    testWidgets("semantics labels present", (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelBanner(trip: _testTrip()),
          ),
        ),
      );

      // Verify Semantics widgets with correct labels exist
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label ?? "").contains("Travel mode banner"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "View packing list button",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Dismiss travel banner",
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
