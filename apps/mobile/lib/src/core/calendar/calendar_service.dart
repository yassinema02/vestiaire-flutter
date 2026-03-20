import "package:device_calendar/device_calendar.dart";
import "package:flutter/material.dart";

/// Simplified permission status for calendar access.
enum CalendarPermissionStatus { granted, denied, unknown }

/// Simplified model wrapping the device_calendar plugin's Calendar type.
class DeviceCalendar {
  const DeviceCalendar({
    required this.id,
    required this.name,
    this.accountName,
    this.color,
    this.isReadOnly = false,
  });

  final String id;
  final String name;
  final String? accountName;
  final Color? color;
  final bool isReadOnly;

  /// Creates a [DeviceCalendar] from the device_calendar plugin's [Calendar].
  factory DeviceCalendar.fromPlugin(Calendar calendar) {
    return DeviceCalendar(
      id: calendar.id!,
      name: calendar.name ?? "Unnamed Calendar",
      accountName: calendar.accountName,
      color: calendar.color != null ? Color(calendar.color!) : null,
      isReadOnly: calendar.isReadOnly ?? false,
    );
  }
}

/// Service for managing device calendar permissions and retrieving calendars.
///
/// Accepts optional [DeviceCalendarPlugin] for dependency injection in tests.
class CalendarService {
  CalendarService({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  /// Checks the current calendar permission status.
  Future<CalendarPermissionStatus> checkPermission() async {
    final result = await _plugin.hasPermissions();
    if (result.isSuccess && result.data == true) {
      return CalendarPermissionStatus.granted;
    }
    return CalendarPermissionStatus.denied;
  }

  /// Requests calendar permission from the user.
  Future<CalendarPermissionStatus> requestPermission() async {
    final result = await _plugin.requestPermissions();
    if (result.isSuccess && result.data == true) {
      return CalendarPermissionStatus.granted;
    }
    return CalendarPermissionStatus.denied;
  }

  /// Retrieves all device calendars, filtering out any with null IDs.
  Future<List<DeviceCalendar>> getCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return [];
    return result.data!
        .where((c) => c.id != null)
        .map((c) => DeviceCalendar.fromPlugin(c))
        .toList();
  }
}
