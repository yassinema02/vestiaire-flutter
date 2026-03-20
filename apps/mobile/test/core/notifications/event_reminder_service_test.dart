import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/core/notifications/event_reminder_service.dart";

CalendarEvent _makeEvent({
  String title = "Test Event",
  int formalityScore = 7,
  String eventType = "formal",
}) {
  return CalendarEvent(
    id: "event-1",
    sourceCalendarId: "cal-1",
    sourceEventId: "src-1",
    title: title,
    startTime: DateTime(2026, 3, 21, 19, 0),
    endTime: DateTime(2026, 3, 21, 22, 0),
    allDay: false,
    eventType: eventType,
    formalityScore: formalityScore,
    classificationSource: "ai",
  );
}

void main() {
  group("EventReminderService", () {
    test("eventReminderNotificationId is 103", () {
      expect(EventReminderService.eventReminderNotificationId, 103);
    });

    test("notification ID 103 is distinct from morning (100), evening (101), posting (102)", () {
      expect(EventReminderService.eventReminderNotificationId, isNot(100));
      expect(EventReminderService.eventReminderNotificationId, isNot(101));
      expect(EventReminderService.eventReminderNotificationId, isNot(102));
      expect(EventReminderService.eventReminderNotificationId, 103);
    });

    test("can be constructed with default plugin", () {
      final service = EventReminderService();
      expect(service, isNotNull);
    });

    test("buildFallbackTip returns correct text for formality 7-8", () {
      expect(
        EventReminderService.buildFallbackTip(7),
        "Check that your outfit is clean and pressed.",
      );
      expect(
        EventReminderService.buildFallbackTip(8),
        "Check that your outfit is clean and pressed.",
      );
    });

    test("buildFallbackTip returns correct text for formality 9-10", () {
      expect(
        EventReminderService.buildFallbackTip(9),
        "Consider dry cleaning and shoe polishing tonight.",
      );
      expect(
        EventReminderService.buildFallbackTip(10),
        "Consider dry cleaning and shoe polishing tonight.",
      );
    });

    test("filterFormalEvents returns only events with formality >= threshold", () {
      final events = [
        _makeEvent(title: "Casual", formalityScore: 3),
        _makeEvent(title: "Semi-Formal", formalityScore: 6),
        _makeEvent(title: "Formal", formalityScore: 7),
        _makeEvent(title: "Black Tie", formalityScore: 9),
      ];

      final result = EventReminderService.filterFormalEvents(events, 7);
      expect(result.length, 2);
      expect(result[0].title, "Formal");
      expect(result[1].title, "Black Tie");
    });

    test("filterFormalEvents returns empty list when no events meet threshold", () {
      final events = [
        _makeEvent(title: "Casual", formalityScore: 3),
        _makeEvent(title: "Relaxed", formalityScore: 5),
      ];

      final result = EventReminderService.filterFormalEvents(events, 7);
      expect(result, isEmpty);
    });

    test("filterFormalEvents with lower threshold includes more events", () {
      final events = [
        _makeEvent(title: "Semi-Formal", formalityScore: 6),
        _makeEvent(title: "Formal", formalityScore: 7),
        _makeEvent(title: "Black Tie", formalityScore: 9),
      ];

      final result = EventReminderService.filterFormalEvents(events, 6);
      expect(result.length, 3);
    });

    test("filterFormalEvents with exact threshold includes matching events", () {
      final events = [
        _makeEvent(title: "Formal", formalityScore: 7),
      ];

      final result = EventReminderService.filterFormalEvents(events, 7);
      expect(result.length, 1);
    });
  });
}
