import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_preferences_service.dart";

void main() {
  group("CalendarPreferencesService", () {
    late CalendarPreferencesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<CalendarPreferencesService> buildService() async {
      final prefs = await SharedPreferences.getInstance();
      return CalendarPreferencesService(prefs: prefs);
    }

    group("saveSelectedCalendarIds / getSelectedCalendarIds", () {
      test("stores IDs in SharedPreferences", () async {
        service = await buildService();
        await service.saveSelectedCalendarIds(["cal-1", "cal-2", "cal-3"]);

        final ids = await service.getSelectedCalendarIds();
        expect(ids, ["cal-1", "cal-2", "cal-3"]);
      });

      test("returns stored IDs", () async {
        service = await buildService();
        await service.saveSelectedCalendarIds(["a", "b"]);

        final ids = await service.getSelectedCalendarIds();
        expect(ids, ["a", "b"]);
      });

      test("returns null when no selection stored", () async {
        service = await buildService();

        final ids = await service.getSelectedCalendarIds();
        expect(ids, isNull);
      });

      test("round-trip: save then get returns same IDs", () async {
        service = await buildService();
        final originalIds = ["work-1", "personal-2", "holidays-3"];
        await service.saveSelectedCalendarIds(originalIds);

        final retrieved = await service.getSelectedCalendarIds();
        expect(retrieved, originalIds);
      });
    });

    group("setCalendarDismissed / isCalendarDismissed", () {
      test("persists dismissed flag", () async {
        service = await buildService();
        await service.setCalendarDismissed(true);

        final dismissed = await service.isCalendarDismissed();
        expect(dismissed, true);
      });

      test("returns true after dismissal", () async {
        service = await buildService();
        await service.setCalendarDismissed(true);

        expect(await service.isCalendarDismissed(), true);
      });

      test("returns false when never set", () async {
        service = await buildService();

        expect(await service.isCalendarDismissed(), false);
      });
    });

    group("setCalendarConnected / isCalendarConnected", () {
      test("persists connected flag", () async {
        service = await buildService();
        await service.setCalendarConnected(true);

        expect(await service.isCalendarConnected(), true);
      });

      test("returns correct value", () async {
        service = await buildService();

        expect(await service.isCalendarConnected(), false);
        await service.setCalendarConnected(true);
        expect(await service.isCalendarConnected(), true);
        await service.setCalendarConnected(false);
        expect(await service.isCalendarConnected(), false);
      });
    });

    group("clearCalendarPreferences", () {
      test("removes all calendar keys", () async {
        service = await buildService();

        // Set all preferences
        await service.saveSelectedCalendarIds(["cal-1"]);
        await service.setCalendarDismissed(true);
        await service.setCalendarConnected(true);

        // Verify they are set
        expect(await service.getSelectedCalendarIds(), isNotNull);
        expect(await service.isCalendarDismissed(), true);
        expect(await service.isCalendarConnected(), true);

        // Clear all
        await service.clearCalendarPreferences();

        // Verify all removed
        expect(await service.getSelectedCalendarIds(), isNull);
        expect(await service.isCalendarDismissed(), false);
        expect(await service.isCalendarConnected(), false);
      });
    });
  });
}
