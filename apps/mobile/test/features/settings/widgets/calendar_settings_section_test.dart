import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/settings/widgets/calendar_settings_section.dart";

void main() {
  group("CalendarSettingsSection", () {
    testWidgets("renders Calendar Sync title", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarSettingsSection(
              isConnected: false,
              selectedCalendarCount: 0,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text("Calendar Sync"), findsOneWidget);
    });

    testWidgets("shows Connected - X calendars synced when connected",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarSettingsSection(
              isConnected: true,
              selectedCalendarCount: 3,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text("Connected - 3 calendars synced"), findsOneWidget);
    });

    testWidgets("shows Not connected when not connected", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarSettingsSection(
              isConnected: false,
              selectedCalendarCount: 0,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text("Not connected"), findsOneWidget);
    });

    testWidgets("tap triggers onTap callback", (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarSettingsSection(
              isConnected: true,
              selectedCalendarCount: 2,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      expect(tapped, true);
    });
  });
}
