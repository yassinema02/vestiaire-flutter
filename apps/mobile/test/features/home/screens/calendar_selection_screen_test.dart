import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_preferences_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_service.dart";
import "package:vestiaire_mobile/src/features/home/screens/calendar_selection_screen.dart";

void main() {
  group("CalendarSelectionScreen", () {
    final testCalendars = [
      const DeviceCalendar(
        id: "cal-1",
        name: "Work",
        accountName: "user@work.com",
        color: Color(0xFF4285F4),
        isReadOnly: false,
      ),
      const DeviceCalendar(
        id: "cal-2",
        name: "Personal",
        accountName: "user@gmail.com",
        color: Color(0xFF0F9D58),
        isReadOnly: true,
      ),
      const DeviceCalendar(
        id: "cal-3",
        name: "Holidays",
        accountName: "user@gmail.com",
        color: Color(0xFFDB4437),
      ),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<CalendarPreferencesService> buildPrefsService() async {
      final prefs = await SharedPreferences.getInstance();
      return CalendarPreferencesService(prefs: prefs);
    }

    testWidgets("renders list of calendars with names and account names",
        (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
          ),
        ),
      );

      expect(find.text("Work"), findsOneWidget);
      expect(find.text("user@work.com"), findsOneWidget);
      expect(find.text("Personal"), findsOneWidget);
      expect(find.text("user@gmail.com"), findsWidgets);
      expect(find.text("Holidays"), findsOneWidget);
    });

    testWidgets("all calendars are toggled ON by default (first-time user)",
        (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
          ),
        ),
      );

      // All switches should be on
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      for (final s in switches) {
        expect(s.value, true);
      }
    });

    testWidgets("user can toggle individual calendars off and on",
        (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
          ),
        ),
      );

      // Toggle first calendar off
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      // First should be off, rest still on
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, false);
      expect(switches[1].value, true);
      expect(switches[2].value, true);

      // Toggle it back on
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      final switchesAfter =
          tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switchesAfter[0].value, true);
    });

    testWidgets("tapping Done saves selected calendar IDs to preferences",
        (tester) async {
      final prefsService = await buildPrefsService();
      bool? popResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarSelectionScreen(
                      calendars: testCalendars,
                      calendarPreferencesService: prefsService,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Toggle off "Holidays" (3rd calendar)
      final switches = find.byType(Switch);
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.text("Done"));
      await tester.pumpAndSettle();

      // Verify preferences saved
      final savedIds = await prefsService.getSelectedCalendarIds();
      expect(savedIds, ["cal-1", "cal-2"]);
      expect(await prefsService.isCalendarConnected(), true);
      expect(popResult, true);
    });

    testWidgets("previously selected IDs are restored when editing",
        (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
            previouslySelectedIds: ["cal-1", "cal-3"],
          ),
        ),
      );

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, true); // cal-1 selected
      expect(switches[1].value, false); // cal-2 not selected
      expect(switches[2].value, true); // cal-3 selected
    });

    testWidgets("calendar color indicators are displayed", (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
          ),
        ),
      );

      // Find colored circle containers
      final colorContainers = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(colorContainers, findsNWidgets(3));
    });

    testWidgets("semantics labels are present for each toggle", (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
          ),
        ),
      );

      // Verify Semantics widgets with correct labels exist
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Toggle sync for Work",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Toggle sync for Personal",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Toggle sync for Holidays",
        ),
        findsOneWidget,
      );
    });

    testWidgets("navigating back without Done does not save changes",
        (tester) async {
      final prefsService = await buildPrefsService();
      bool? popResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarSelectionScreen(
                      calendars: testCalendars,
                      calendarPreferencesService: prefsService,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Navigate back without tapping Done
      final backButton = find.byTooltip("Back");
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Preferences should not be saved
      expect(await prefsService.getSelectedCalendarIds(), isNull);
      expect(await prefsService.isCalendarConnected(), false);
      expect(popResult, false);
    });

    testWidgets("renders Select Calendars title in AppBar", (tester) async {
      final prefsService = await buildPrefsService();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSelectionScreen(
            calendars: testCalendars,
            calendarPreferencesService: prefsService,
          ),
        ),
      );

      expect(find.text("Select Calendars"), findsOneWidget);
    });
  });
}
