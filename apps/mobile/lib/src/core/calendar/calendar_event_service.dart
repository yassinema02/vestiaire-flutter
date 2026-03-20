import "package:device_calendar/device_calendar.dart";

import "../networking/api_client.dart";
import "calendar_event.dart";
import "calendar_preferences_service.dart";
import "calendar_service.dart";

/// Service for fetching device calendar events, syncing them to the API,
/// and returning classified events.
///
/// Does NOT store events locally -- the API is the source of truth.
class CalendarEventService {
  CalendarEventService({
    required CalendarService calendarService,
    required CalendarPreferencesService calendarPreferencesService,
    required ApiClient apiClient,
    DeviceCalendarPlugin? plugin,
  })  : _calendarService = calendarService,
        _calendarPreferencesService = calendarPreferencesService,
        _apiClient = apiClient,
        _plugin = plugin ?? DeviceCalendarPlugin();

  final CalendarService _calendarService;
  final CalendarPreferencesService _calendarPreferencesService;
  final ApiClient _apiClient;
  final DeviceCalendarPlugin _plugin;

  /// Update an event's classification via user override.
  ///
  /// Returns the updated [CalendarEvent] on success, or `null` on error.
  Future<CalendarEvent?> updateEventOverride(
    String eventId, {
    required String eventType,
    required int formalityScore,
  }) async {
    try {
      final response = await _apiClient.updateEventClassification(
        eventId,
        eventType: eventType,
        formalityScore: formalityScore,
      );
      return CalendarEvent.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Fetch events from device calendars, sync to API, and return classified events.
  ///
  /// Returns empty list if calendar is not connected or on error.
  Future<List<CalendarEvent>> fetchAndSyncEvents() async {
    try {
      // Check if calendar is connected
      final connected =
          await _calendarPreferencesService.isCalendarConnected();
      if (!connected) return [];

      // Get selected calendar IDs (null = all calendars)
      final selectedIds =
          await _calendarPreferencesService.getSelectedCalendarIds();

      // Determine which calendars to fetch from
      List<String> calendarIds;
      if (selectedIds != null) {
        calendarIds = selectedIds;
      } else {
        // Fetch all calendars
        final calendars = await _calendarService.getCalendars();
        calendarIds = calendars.map((c) => c.id).toList();
      }

      if (calendarIds.isEmpty) return [];

      // Fetch events from each calendar
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 7));
      final allDeviceEvents = <Map<String, dynamic>>[];

      for (final calendarId in calendarIds) {
        try {
          final result = await _plugin.retrieveEvents(
            calendarId,
            RetrieveEventsParams(startDate: startDate, endDate: endDate),
          );
          if (result.isSuccess && result.data != null) {
            for (final event in result.data!) {
              if (event.eventId == null) continue;
              allDeviceEvents.add({
                "sourceCalendarId": calendarId,
                "sourceEventId": event.eventId!,
                "title": event.title ?? "Untitled",
                "description": event.description,
                "location": event.location,
                "startTime": event.start?.toIso8601String() ??
                    startDate.toIso8601String(),
                "endTime": event.end?.toIso8601String() ??
                    endDate.toIso8601String(),
                "allDay": event.allDay ?? false,
              });
            }
          }
        } catch (e) {
          // Skip calendar on error, continue with others
        }
      }

      if (allDeviceEvents.isEmpty) return [];

      // Sync to API
      try {
        await _apiClient.syncCalendarEvents(allDeviceEvents);
      } catch (e) {
        // API sync failed -- return empty list (graceful degradation)
        return [];
      }

      // Fetch classified events back from API
      try {
        final startStr =
            "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
        final endStr =
            "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
        final response = await _apiClient.getCalendarEvents(
          startDate: startStr,
          endDate: endStr,
        );
        final eventsList = response["events"] as List<dynamic>? ?? [];
        return eventsList
            .map((e) =>
                CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return [];
      }
    } catch (e) {
      // Graceful degradation: return empty list on any error
      return [];
    }
  }
}
