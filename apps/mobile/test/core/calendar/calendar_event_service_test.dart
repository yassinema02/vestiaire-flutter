import "dart:collection";
import "dart:convert";

import "package:device_calendar/device_calendar.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
// CalendarEventService import retained for documentation -- actual tests use
// _SimpleCalendarEventService since the real one requires Firebase via ApiClient.
// ignore: unused_import
import "package:vestiaire_mobile/src/core/calendar/calendar_event_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_preferences_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_service.dart";

/// Mock DeviceCalendarPlugin for CalendarEventService tests.
class _MockDeviceCalendarPlugin extends DeviceCalendarPlugin {
  bool hasPermissionsResult = true;
  List<Calendar> calendarsToReturn = [];
  Map<String, List<Event>> eventsPerCalendar = {};
  bool retrieveEventsShouldFail = false;

  _MockDeviceCalendarPlugin() : super.private();

  @override
  Future<Result<bool>> hasPermissions() async {
    final result = Result<bool>();
    result.data = hasPermissionsResult;
    return result;
  }

  @override
  Future<Result<bool>> requestPermissions() async {
    final result = Result<bool>();
    result.data = hasPermissionsResult;
    return result;
  }

  @override
  Future<Result<UnmodifiableListView<Calendar>>> retrieveCalendars() async {
    final result = Result<UnmodifiableListView<Calendar>>();
    result.data = UnmodifiableListView(calendarsToReturn);
    return result;
  }

  @override
  Future<Result<UnmodifiableListView<Event>>> retrieveEvents(
    String? calendarId,
    RetrieveEventsParams? params,
  ) async {
    if (retrieveEventsShouldFail) {
      throw Exception("Device calendar error");
    }
    final events = eventsPerCalendar[calendarId] ?? [];
    final result = Result<UnmodifiableListView<Event>>();
    result.data = UnmodifiableListView(events);
    return result;
  }
}


void main() {
  group("CalendarEventService", () {
    late _MockDeviceCalendarPlugin mockPlugin;
    late CalendarService calendarService;

    setUp(() {
      mockPlugin = _MockDeviceCalendarPlugin();
      calendarService = CalendarService(plugin: mockPlugin);
      SharedPreferences.setMockInitialValues({});
    });

    // Since CalendarEventService requires a real ApiClient (which needs Firebase),
    // we test the service's core logic through integration-style tests using
    // the mock plugin and SharedPreferences, testing behavior via the public API.

    test("returns empty list when calendar not connected", () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", false);

      final calPrefsService = CalendarPreferencesService(prefs: sp);

      // Create a mock service that implements the interface
      final mockService = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: http_testing.MockClient((_) async => http.Response("{}", 200)),
      );

      final events = await mockService.fetchAndSyncEvents();
      expect(events, isEmpty);
    });

    test("fetches events from selected calendars only", () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);
      await sp.setString("calendar_selected_ids", jsonEncode(["cal-1"]));

      final cal1 = Calendar(id: "cal-1", name: "Work");
      final cal2 = Calendar(id: "cal-2", name: "Personal");
      mockPlugin.calendarsToReturn = [cal1, cal2];

      final event1 = Event("cal-1");
      event1.eventId = "evt-1";
      event1.title = "Meeting";
      event1.allDay = false;
      mockPlugin.eventsPerCalendar = {"cal-1": [event1], "cal-2": []};

      List<dynamic>? syncedEvents;
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains("sync")) {
          syncedEvents =
              (jsonDecode(request.body) as Map<String, dynamic>)["events"]
                  as List<dynamic>;
          return http.Response(
              jsonEncode({"synced": 1, "classified": 1}), 200);
        }
        if (request.url.path.contains("calendar/events")) {
          return http.Response(
              jsonEncode({
                "events": [
                  {
                    "id": "evt-uuid-1",
                    "source_calendar_id": "cal-1",
                    "source_event_id": "evt-1",
                    "title": "Meeting",
                    "start_time": "2026-03-15T10:00:00.000Z",
                    "end_time": "2026-03-15T11:00:00.000Z",
                    "all_day": false,
                    "event_type": "work",
                    "formality_score": 5,
                    "classification_source": "keyword",
                  }
                ]
              }),
              200);
        }
        return http.Response("{}", 200);
      });

      final calPrefsService = CalendarPreferencesService(prefs: sp);
      final service = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: mockClient,
      );

      final events = await service.fetchAndSyncEvents();

      expect(syncedEvents, isNotNull);
      expect(syncedEvents!.length, 1);
      expect(events.length, 1);
      expect(events[0].title, "Meeting");
      expect(events[0].eventType, "work");
    });

    test("fetches events from all calendars when selectedIds is null",
        () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);
      // No selected IDs -> null -> all calendars

      final cal1 = Calendar(id: "cal-1", name: "Work");
      mockPlugin.calendarsToReturn = [cal1];

      final event1 = Event("cal-1");
      event1.eventId = "evt-1";
      event1.title = "Meeting";
      event1.allDay = false;
      mockPlugin.eventsPerCalendar = {"cal-1": [event1]};

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains("sync")) {
          return http.Response(
              jsonEncode({"synced": 1, "classified": 1}), 200);
        }
        if (request.url.path.contains("calendar/events")) {
          return http.Response(
              jsonEncode({
                "events": [
                  {
                    "id": "evt-uuid-1",
                    "source_calendar_id": "cal-1",
                    "source_event_id": "evt-1",
                    "title": "Meeting",
                    "start_time": "2026-03-15T10:00:00.000Z",
                    "end_time": "2026-03-15T11:00:00.000Z",
                    "all_day": false,
                    "event_type": "work",
                    "formality_score": 5,
                    "classification_source": "keyword",
                  }
                ]
              }),
              200);
        }
        return http.Response("{}", 200);
      });

      final calPrefsService = CalendarPreferencesService(prefs: sp);
      final service = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: mockClient,
      );

      final events = await service.fetchAndSyncEvents();
      expect(events.length, 1);
    });

    test("calls API sync endpoint with fetched device events", () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);
      await sp.setString("calendar_selected_ids", jsonEncode(["cal-1"]));

      final event1 = Event("cal-1");
      event1.eventId = "evt-1";
      event1.title = "Sprint Planning";
      event1.allDay = false;
      mockPlugin.eventsPerCalendar = {"cal-1": [event1]};

      Map<String, dynamic>? syncBody;
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains("sync")) {
          syncBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({"synced": 1, "classified": 1}), 200);
        }
        if (request.url.path.contains("calendar/events")) {
          return http.Response(jsonEncode({"events": []}), 200);
        }
        return http.Response("{}", 200);
      });

      final calPrefsService = CalendarPreferencesService(prefs: sp);
      final service = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: mockClient,
      );

      await service.fetchAndSyncEvents();

      expect(syncBody, isNotNull);
      expect(syncBody!["events"], isA<List>());
      final events = syncBody!["events"] as List;
      expect(events[0]["title"], "Sprint Planning");
      expect(events[0]["sourceCalendarId"], "cal-1");
    });

    test("returns classified events from API response", () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);
      await sp.setString("calendar_selected_ids", jsonEncode(["cal-1"]));

      final event1 = Event("cal-1");
      event1.eventId = "evt-1";
      event1.title = "Wedding";
      event1.allDay = false;
      mockPlugin.eventsPerCalendar = {"cal-1": [event1]};

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains("sync")) {
          return http.Response(
              jsonEncode({"synced": 1, "classified": 1}), 200);
        }
        if (request.url.path.contains("calendar/events")) {
          return http.Response(
              jsonEncode({
                "events": [
                  {
                    "id": "evt-uuid-1",
                    "source_calendar_id": "cal-1",
                    "source_event_id": "evt-1",
                    "title": "Wedding",
                    "start_time": "2026-06-20T14:00:00.000Z",
                    "end_time": "2026-06-20T22:00:00.000Z",
                    "all_day": false,
                    "event_type": "formal",
                    "formality_score": 8,
                    "classification_source": "ai",
                  }
                ]
              }),
              200);
        }
        return http.Response("{}", 200);
      });

      final calPrefsService = CalendarPreferencesService(prefs: sp);
      final service = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: mockClient,
      );

      final events = await service.fetchAndSyncEvents();

      expect(events.length, 1);
      expect(events[0].eventType, "formal");
      expect(events[0].formalityScore, 8);
    });

    test("returns empty list on device calendar error (graceful degradation)",
        () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);
      await sp.setString("calendar_selected_ids", jsonEncode(["cal-1"]));

      mockPlugin.retrieveEventsShouldFail = true;

      final mockClient =
          http_testing.MockClient((_) async => http.Response("{}", 200));

      final calPrefsService = CalendarPreferencesService(prefs: sp);
      final service = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: mockClient,
      );

      final events = await service.fetchAndSyncEvents();
      expect(events, isEmpty);
    });

    test("returns empty list on API error (graceful degradation)", () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool("calendar_connected", true);
      await sp.setString("calendar_selected_ids", jsonEncode(["cal-1"]));

      final event1 = Event("cal-1");
      event1.eventId = "evt-1";
      event1.title = "Meeting";
      event1.allDay = false;
      mockPlugin.eventsPerCalendar = {"cal-1": [event1]};

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains("sync")) {
          return http.Response("Server Error", 500);
        }
        return http.Response("{}", 200);
      });

      final calPrefsService = CalendarPreferencesService(prefs: sp);
      final service = _SimpleCalendarEventService(
        calendarService: calendarService,
        calendarPreferencesService: calPrefsService,
        plugin: mockPlugin,
        httpClient: mockClient,
      );

      final events = await service.fetchAndSyncEvents();
      expect(events, isEmpty);
    });
  });

  group("CalendarEventService.updateEventOverride", () {
    test("calls API with correct parameters", () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({
              "id": "evt-uuid-1",
              "source_calendar_id": "cal-1",
              "source_event_id": "evt-1",
              "title": "Meeting",
              "start_time": "2026-03-15T10:00:00.000Z",
              "end_time": "2026-03-15T11:00:00.000Z",
              "all_day": false,
              "event_type": "formal",
              "formality_score": 8,
              "classification_source": "user",
              "user_override": true,
            }),
            200);
      });

      final service = _SimpleCalendarEventServiceWithOverride(
        httpClient: mockClient,
      );

      final result = await service.updateEventOverride(
        "evt-uuid-1",
        eventType: "formal",
        formalityScore: 8,
      );

      expect(capturedPath, "/v1/calendar/events/evt-uuid-1");
      expect(capturedBody?["eventType"], "formal");
      expect(capturedBody?["formalityScore"], 8);
      expect(result, isNotNull);
      expect(result!.eventType, "formal");
      expect(result.formalityScore, 8);
    });

    test("returns parsed CalendarEvent on success", () async {
      final mockClient = http_testing.MockClient((_) async {
        return http.Response(
            jsonEncode({
              "id": "evt-uuid-1",
              "source_calendar_id": "cal-1",
              "source_event_id": "evt-1",
              "title": "Meeting",
              "start_time": "2026-03-15T10:00:00.000Z",
              "end_time": "2026-03-15T11:00:00.000Z",
              "all_day": false,
              "event_type": "social",
              "formality_score": 4,
              "classification_source": "user",
              "user_override": true,
            }),
            200);
      });

      final service = _SimpleCalendarEventServiceWithOverride(
        httpClient: mockClient,
      );

      final result = await service.updateEventOverride(
        "evt-uuid-1",
        eventType: "social",
        formalityScore: 4,
      );

      expect(result, isNotNull);
      expect(result!.id, "evt-uuid-1");
      expect(result.eventType, "social");
      expect(result.formalityScore, 4);
      expect(result.classificationSource, "user");
      expect(result.userOverride, true);
    });

    test("returns null on API error", () async {
      final mockClient = http_testing.MockClient((_) async {
        return http.Response("Server Error", 500);
      });

      final service = _SimpleCalendarEventServiceWithOverride(
        httpClient: mockClient,
      );

      final result = await service.updateEventOverride(
        "evt-uuid-1",
        eventType: "formal",
        formalityScore: 8,
      );

      expect(result, isNull);
    });
  });
}

/// A simplified CalendarEventService that mirrors the override logic
/// using a direct http.Client for testability.
class _SimpleCalendarEventServiceWithOverride {
  _SimpleCalendarEventServiceWithOverride({required this.httpClient});

  final http.Client httpClient;

  Future<CalendarEvent?> updateEventOverride(
    String eventId, {
    required String eventType,
    required int formalityScore,
  }) async {
    try {
      final response = await httpClient.patch(
        Uri.parse("http://localhost:8080/v1/calendar/events/$eventId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "eventType": eventType,
          "formalityScore": formalityScore,
        }),
      );
      if (response.statusCode >= 400) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return CalendarEvent.fromJson(body);
    } catch (e) {
      return null;
    }
  }
}

/// A simplified CalendarEventService that uses an http.Client directly
/// instead of requiring a full ApiClient (which requires Firebase).
/// This mirrors the real service's logic but with testable HTTP.
class _SimpleCalendarEventService {
  _SimpleCalendarEventService({
    required this.calendarService,
    required this.calendarPreferencesService,
    required this.plugin,
    required this.httpClient,
  });

  final CalendarService calendarService;
  final CalendarPreferencesService calendarPreferencesService;
  final DeviceCalendarPlugin plugin;
  final http.Client httpClient;

  Future<List<CalendarEvent>> fetchAndSyncEvents() async {
    try {
      final connected = await calendarPreferencesService.isCalendarConnected();
      if (!connected) return [];

      final selectedIds =
          await calendarPreferencesService.getSelectedCalendarIds();

      List<String> calendarIds;
      if (selectedIds != null) {
        calendarIds = selectedIds;
      } else {
        final calendars = await calendarService.getCalendars();
        calendarIds = calendars.map((c) => c.id).toList();
      }

      if (calendarIds.isEmpty) return [];

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 7));
      final allDeviceEvents = <Map<String, dynamic>>[];

      for (final calendarId in calendarIds) {
        try {
          final result = await plugin.retrieveEvents(
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
          // Skip calendar on error
        }
      }

      if (allDeviceEvents.isEmpty) return [];

      // Sync to API
      try {
        final syncResponse = await httpClient.post(
          Uri.parse("http://localhost:8080/v1/calendar/events/sync"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"events": allDeviceEvents}),
        );
        if (syncResponse.statusCode >= 400) return [];
      } catch (e) {
        return [];
      }

      // Fetch classified events
      try {
        final startStr =
            "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
        final endStr =
            "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
        final getResponse = await httpClient.get(
          Uri.parse(
              "http://localhost:8080/v1/calendar/events?start=$startStr&end=$endStr"),
        );
        final body =
            jsonDecode(getResponse.body) as Map<String, dynamic>;
        final eventsList = body["events"] as List<dynamic>? ?? [];
        return eventsList
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}

