import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";

void main() {
  group("CalendarEvent", () {
    final sampleJson = {
      "id": "evt-uuid-1",
      "source_calendar_id": "cal-1",
      "source_event_id": "evt-1",
      "title": "Sprint Planning",
      "description": "Weekly sprint planning session",
      "location": "Office",
      "start_time": "2026-03-15T10:00:00.000Z",
      "end_time": "2026-03-15T11:00:00.000Z",
      "all_day": false,
      "event_type": "work",
      "formality_score": 5,
      "classification_source": "keyword",
    };

    test("fromJson correctly parses all fields", () {
      final event = CalendarEvent.fromJson(sampleJson);

      expect(event.id, "evt-uuid-1");
      expect(event.sourceCalendarId, "cal-1");
      expect(event.sourceEventId, "evt-1");
      expect(event.title, "Sprint Planning");
      expect(event.description, "Weekly sprint planning session");
      expect(event.location, "Office");
      expect(event.startTime, DateTime.utc(2026, 3, 15, 10, 0));
      expect(event.endTime, DateTime.utc(2026, 3, 15, 11, 0));
      expect(event.allDay, false);
      expect(event.eventType, "work");
      expect(event.formalityScore, 5);
      expect(event.classificationSource, "keyword");
    });

    test("toJson serializes all fields", () {
      final event = CalendarEvent(
        id: "evt-uuid-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        description: "Weekly",
        location: "Office",
        startTime: DateTime.utc(2026, 3, 15, 10, 0),
        endTime: DateTime.utc(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "keyword",
      );

      final json = event.toJson();

      expect(json["id"], "evt-uuid-1");
      expect(json["source_calendar_id"], "cal-1");
      expect(json["source_event_id"], "evt-1");
      expect(json["title"], "Sprint Planning");
      expect(json["event_type"], "work");
      expect(json["formality_score"], 5);
      expect(json["classification_source"], "keyword");
      expect(json["all_day"], false);
    });

    test("round-trip: toJson then fromJson returns equivalent object", () {
      final original = CalendarEvent(
        id: "evt-uuid-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Birthday dinner",
        description: "At the Italian place",
        location: "Restaurant",
        startTime: DateTime.utc(2026, 3, 15, 19, 0),
        endTime: DateTime.utc(2026, 3, 15, 21, 0),
        allDay: false,
        eventType: "social",
        formalityScore: 3,
        classificationSource: "ai",
      );

      final restored = CalendarEvent.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.sourceCalendarId, original.sourceCalendarId);
      expect(restored.sourceEventId, original.sourceEventId);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.location, original.location);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.allDay, original.allDay);
      expect(restored.eventType, original.eventType);
      expect(restored.formalityScore, original.formalityScore);
      expect(restored.classificationSource, original.classificationSource);
    });

    test("fromJson parses user_override field", () {
      final json = {
        ...sampleJson,
        "user_override": true,
      };
      final event = CalendarEvent.fromJson(json);
      expect(event.userOverride, true);
    });

    test("fromJson defaults user_override to false when missing", () {
      final event = CalendarEvent.fromJson(sampleJson);
      expect(event.userOverride, false);
    });

    test("toJson includes user_override field", () {
      final event = CalendarEvent(
        id: "evt-uuid-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        startTime: DateTime.utc(2026, 3, 15, 10, 0),
        endTime: DateTime.utc(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "user",
        userOverride: true,
      );

      final json = event.toJson();
      expect(json["user_override"], true);
    });

    test("copyWith creates a modified copy with new eventType", () {
      final event = CalendarEvent.fromJson(sampleJson);
      final modified = event.copyWith(eventType: "formal");

      expect(modified.eventType, "formal");
      expect(modified.id, event.id);
      expect(modified.title, event.title);
      expect(modified.formalityScore, event.formalityScore);
    });

    test("copyWith creates a modified copy with new formalityScore", () {
      final event = CalendarEvent.fromJson(sampleJson);
      final modified = event.copyWith(formalityScore: 9);

      expect(modified.formalityScore, 9);
      expect(modified.eventType, event.eventType);
    });

    test("copyWith preserves unmodified fields", () {
      final event = CalendarEvent(
        id: "evt-uuid-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Sprint Planning",
        description: "Weekly",
        location: "Office",
        startTime: DateTime.utc(2026, 3, 15, 10, 0),
        endTime: DateTime.utc(2026, 3, 15, 11, 0),
        allDay: false,
        eventType: "work",
        formalityScore: 5,
        classificationSource: "keyword",
        userOverride: false,
      );

      final modified = event.copyWith(
        eventType: "formal",
        formalityScore: 8,
        classificationSource: "user",
        userOverride: true,
      );

      expect(modified.id, event.id);
      expect(modified.sourceCalendarId, event.sourceCalendarId);
      expect(modified.sourceEventId, event.sourceEventId);
      expect(modified.title, event.title);
      expect(modified.description, event.description);
      expect(modified.location, event.location);
      expect(modified.startTime, event.startTime);
      expect(modified.endTime, event.endTime);
      expect(modified.allDay, event.allDay);
      expect(modified.eventType, "formal");
      expect(modified.formalityScore, 8);
      expect(modified.classificationSource, "user");
      expect(modified.userOverride, true);
    });
  });

  group("CalendarEventContext", () {
    test("fromCalendarEvent maps correctly", () {
      final event = CalendarEvent(
        id: "evt-uuid-1",
        sourceCalendarId: "cal-1",
        sourceEventId: "evt-1",
        title: "Yoga class",
        description: "Morning yoga",
        location: "Studio",
        startTime: DateTime.utc(2026, 3, 15, 7, 0),
        endTime: DateTime.utc(2026, 3, 15, 8, 0),
        allDay: false,
        eventType: "active",
        formalityScore: 1,
        classificationSource: "keyword",
      );

      final context = CalendarEventContext.fromCalendarEvent(event);

      expect(context.title, "Yoga class");
      expect(context.eventType, "active");
      expect(context.formalityScore, 1);
      expect(context.startTime, DateTime.utc(2026, 3, 15, 7, 0));
      expect(context.endTime, DateTime.utc(2026, 3, 15, 8, 0));
      expect(context.allDay, false);
    });

    test("toJson serializes correctly", () {
      final context = CalendarEventContext(
        title: "Wedding",
        eventType: "formal",
        formalityScore: 8,
        startTime: DateTime.utc(2026, 6, 20, 14, 0),
        endTime: DateTime.utc(2026, 6, 20, 22, 0),
        allDay: false,
      );

      final json = context.toJson();

      expect(json["title"], "Wedding");
      expect(json["eventType"], "formal");
      expect(json["formalityScore"], 8);
      expect(json["allDay"], false);
      expect(json["startTime"], contains("2026-06-20"));
    });

    test("fromJson round-trip", () {
      final original = CalendarEventContext(
        title: "Team lunch",
        eventType: "social",
        formalityScore: 3,
        startTime: DateTime.utc(2026, 3, 15, 12, 0),
        endTime: DateTime.utc(2026, 3, 15, 13, 0),
        allDay: false,
      );

      final restored = CalendarEventContext.fromJson(original.toJson());

      expect(restored.title, original.title);
      expect(restored.eventType, original.eventType);
      expect(restored.formalityScore, original.formalityScore);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.allDay, original.allDay);
    });
  });
}
