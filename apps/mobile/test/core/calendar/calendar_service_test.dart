import "dart:collection";

import "package:device_calendar/device_calendar.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_service.dart";

/// Mock DeviceCalendarPlugin for testing.
///
/// Uses DeviceCalendarPlugin.private() to avoid timezone init issues.
class MockDeviceCalendarPlugin extends DeviceCalendarPlugin {
  bool hasPermissionsResult = true;
  bool requestPermissionsResult = true;
  List<Calendar> calendarsToReturn = [];
  bool shouldFail = false;

  MockDeviceCalendarPlugin() : super.private();

  @override
  Future<Result<bool>> hasPermissions() async {
    final result = Result<bool>();
    if (shouldFail) {
      result.errors.add(ResultError(0, "Permission check failed"));
    } else {
      result.data = hasPermissionsResult;
    }
    return result;
  }

  @override
  Future<Result<bool>> requestPermissions() async {
    final result = Result<bool>();
    if (shouldFail) {
      result.errors.add(ResultError(0, "Permission request failed"));
    } else {
      result.data = requestPermissionsResult;
    }
    return result;
  }

  @override
  Future<Result<UnmodifiableListView<Calendar>>> retrieveCalendars() async {
    final result = Result<UnmodifiableListView<Calendar>>();
    if (shouldFail) {
      result.errors.add(ResultError(0, "Retrieve failed"));
    } else {
      result.data = UnmodifiableListView(calendarsToReturn);
    }
    return result;
  }
}

void main() {
  group("CalendarService", () {
    late MockDeviceCalendarPlugin mockPlugin;
    late CalendarService service;

    setUp(() {
      mockPlugin = MockDeviceCalendarPlugin();
      service = CalendarService(plugin: mockPlugin);
    });

    group("checkPermission", () {
      test("returns granted when plugin reports permissions granted", () async {
        mockPlugin.hasPermissionsResult = true;

        final result = await service.checkPermission();
        expect(result, CalendarPermissionStatus.granted);
      });

      test("returns denied when plugin reports permissions denied", () async {
        mockPlugin.hasPermissionsResult = false;

        final result = await service.checkPermission();
        expect(result, CalendarPermissionStatus.denied);
      });

      test("returns denied when plugin call fails", () async {
        mockPlugin.shouldFail = true;

        final result = await service.checkPermission();
        expect(result, CalendarPermissionStatus.denied);
      });
    });

    group("requestPermission", () {
      test("returns granted when plugin grants permissions", () async {
        mockPlugin.requestPermissionsResult = true;

        final result = await service.requestPermission();
        expect(result, CalendarPermissionStatus.granted);
      });

      test("returns denied when plugin denies permissions", () async {
        mockPlugin.requestPermissionsResult = false;

        final result = await service.requestPermission();
        expect(result, CalendarPermissionStatus.denied);
      });
    });

    group("getCalendars", () {
      test("returns mapped list of DeviceCalendar objects from plugin results",
          () async {
        mockPlugin.calendarsToReturn = [
          Calendar(
            id: "cal-1",
            name: "Work",
            accountName: "user@work.com",
            color: 0xFF4285F4,
            isReadOnly: false,
          ),
          Calendar(
            id: "cal-2",
            name: "Personal",
            accountName: "user@gmail.com",
            color: 0xFF0F9D58,
            isReadOnly: true,
          ),
        ];

        final calendars = await service.getCalendars();

        expect(calendars.length, 2);
        expect(calendars[0].id, "cal-1");
        expect(calendars[0].name, "Work");
        expect(calendars[0].accountName, "user@work.com");
        expect(calendars[0].color, const Color(0xFF4285F4));
        expect(calendars[0].isReadOnly, false);
        expect(calendars[1].id, "cal-2");
        expect(calendars[1].name, "Personal");
        expect(calendars[1].isReadOnly, true);
      });

      test("filters out calendars with null IDs", () async {
        mockPlugin.calendarsToReturn = [
          Calendar(id: "cal-1", name: "Valid"),
          Calendar(id: null, name: "No ID"),
        ];

        final calendars = await service.getCalendars();

        expect(calendars.length, 1);
        expect(calendars[0].id, "cal-1");
      });

      test("returns empty list when plugin returns no calendars", () async {
        mockPlugin.calendarsToReturn = [];

        final calendars = await service.getCalendars();

        expect(calendars, isEmpty);
      });

      test("returns empty list when plugin call fails", () async {
        mockPlugin.shouldFail = true;

        final calendars = await service.getCalendars();

        expect(calendars, isEmpty);
      });
    });

    group("DeviceCalendar.fromPlugin", () {
      test("correctly maps all fields", () {
        final pluginCalendar = Calendar(
          id: "test-id",
          name: "Test Calendar",
          accountName: "test@example.com",
          color: 0xFF123456,
          isReadOnly: true,
        );

        final cal = DeviceCalendar.fromPlugin(pluginCalendar);

        expect(cal.id, "test-id");
        expect(cal.name, "Test Calendar");
        expect(cal.accountName, "test@example.com");
        expect(cal.color, const Color(0xFF123456));
        expect(cal.isReadOnly, true);
      });

      test("handles null name with default", () {
        final pluginCalendar = Calendar(id: "test-id", name: null);

        final cal = DeviceCalendar.fromPlugin(pluginCalendar);

        expect(cal.name, "Unnamed Calendar");
      });

      test("handles null color", () {
        final pluginCalendar = Calendar(id: "test-id", name: "Test");

        final cal = DeviceCalendar.fromPlugin(pluginCalendar);

        expect(cal.color, isNull);
      });

      test("handles null isReadOnly with default false", () {
        final pluginCalendar = Calendar(
          id: "test-id",
          name: "Test",
          isReadOnly: null,
        );

        final cal = DeviceCalendar.fromPlugin(pluginCalendar);

        expect(cal.isReadOnly, false);
      });
    });
  });
}
