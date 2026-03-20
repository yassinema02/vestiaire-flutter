import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/calendar_permission_card.dart";

void main() {
  group("CalendarPermissionCard", () {
    testWidgets("renders calendar icon, title, subtitle, buttons",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPermissionCard(
              onConnectCalendar: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(
          find.text("Plan outfits around your events"), findsOneWidget);
      expect(
        find.text(
            "Connect your calendar so Vestiaire can suggest outfits that match your meetings, dinners, and activities"),
        findsOneWidget,
      );
      expect(find.text("Connect Calendar"), findsOneWidget);
      expect(find.text("Not Now"), findsOneWidget);
    });

    testWidgets("Connect Calendar button triggers onConnectCalendar callback",
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPermissionCard(
              onConnectCalendar: () => called = true,
              onNotNow: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text("Connect Calendar"));
      expect(called, true);
    });

    testWidgets("Not Now button triggers onNotNow callback", (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPermissionCard(
              onConnectCalendar: () {},
              onNotNow: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Not Now"));
      expect(called, true);
    });

    testWidgets("Semantics label is present", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPermissionCard(
              onConnectCalendar: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );

      // Verify the Semantics widget with correct label exists
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  "Connect calendar to get event-aware outfit suggestions",
        ),
        findsOneWidget,
      );
    });
  });

  group("CalendarDeniedCard", () {
    testWidgets("renders title and Grant Access button", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarDeniedCard(onGrantAccess: () {}),
          ),
        ),
      );

      expect(find.text("Calendar access needed"), findsOneWidget);
      expect(find.text("Grant Access"), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    });

    testWidgets("Grant Access button triggers onGrantAccess callback",
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarDeniedCard(onGrantAccess: () => called = true),
          ),
        ),
      );

      await tester.tap(find.text("Grant Access"));
      expect(called, true);
    });
  });
}
