import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/features/home/widgets/events_section.dart";

CalendarEvent _makeEvent({
  String id = "evt-1",
  String title = "Sprint Planning",
  DateTime? startTime,
  DateTime? endTime,
  String eventType = "work",
  int formalityScore = 5,
  String classificationSource = "keyword",
  bool allDay = false,
}) {
  return CalendarEvent(
    id: id,
    sourceCalendarId: "cal-1",
    sourceEventId: id,
    title: title,
    startTime: startTime ?? DateTime(2026, 3, 15, 10, 0),
    endTime: endTime ?? DateTime(2026, 3, 15, 11, 0),
    allDay: allDay,
    eventType: eventType,
    formalityScore: formalityScore,
    classificationSource: classificationSource,
  );
}

void main() {
  group("EventsSection", () {
    testWidgets("renders 'Today's Events' header", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventsSection(events: [_makeEvent()]),
          ),
        ),
      );

      expect(find.text("Today's Events"), findsOneWidget);
    });

    testWidgets("displays up to 3 events with title, time, type icon, formality badge",
        (tester) async {
      final events = [
        _makeEvent(id: "e1", title: "Morning Standup", startTime: DateTime(2026, 3, 15, 9, 0), endTime: DateTime(2026, 3, 15, 9, 30), eventType: "work", formalityScore: 4),
        _makeEvent(id: "e2", title: "Lunch with Team", startTime: DateTime(2026, 3, 15, 12, 0), endTime: DateTime(2026, 3, 15, 13, 0), eventType: "social", formalityScore: 3),
        _makeEvent(id: "e3", title: "Client Meeting", startTime: DateTime(2026, 3, 15, 15, 0), endTime: DateTime(2026, 3, 15, 16, 0), eventType: "formal", formalityScore: 8),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventsSection(events: events),
            ),
          ),
        ),
      );

      expect(find.text("Morning Standup"), findsOneWidget);
      expect(find.text("Lunch with Team"), findsOneWidget);
      expect(find.text("Client Meeting"), findsOneWidget);
      expect(find.text("Formality 4/10"), findsOneWidget);
      expect(find.text("Formality 3/10"), findsOneWidget);
      expect(find.text("Formality 8/10"), findsOneWidget);
    });

    testWidgets("shows 'View all X events' when more than 3 events",
        (tester) async {
      final events = [
        _makeEvent(id: "e1", title: "Event 1", startTime: DateTime(2026, 3, 15, 8, 0)),
        _makeEvent(id: "e2", title: "Event 2", startTime: DateTime(2026, 3, 15, 10, 0)),
        _makeEvent(id: "e3", title: "Event 3", startTime: DateTime(2026, 3, 15, 12, 0)),
        _makeEvent(id: "e4", title: "Event 4", startTime: DateTime(2026, 3, 15, 14, 0)),
        _makeEvent(id: "e5", title: "Event 5", startTime: DateTime(2026, 3, 15, 16, 0)),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventsSection(events: events),
            ),
          ),
        ),
      );

      expect(find.text("View all 5 events"), findsOneWidget);
      // Only 3 event cards rendered
      expect(find.text("Event 1"), findsOneWidget);
      expect(find.text("Event 2"), findsOneWidget);
      expect(find.text("Event 3"), findsOneWidget);
      expect(find.text("Event 4"), findsNothing);
    });

    testWidgets("shows 'No events today' empty state when events list is empty",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventsSection(events: const []),
          ),
        ),
      );

      expect(find.text("No events today"), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets("tapping an event calls onEventTap with correct event",
        (tester) async {
      CalendarEvent? tappedEvent;
      final event = _makeEvent(title: "Tap Me");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventsSection(
              events: [event],
              onEventTap: (e) => tappedEvent = e,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Tap Me"));
      await tester.pumpAndSettle();

      expect(tappedEvent, isNotNull);
      expect(tappedEvent!.title, "Tap Me");
    });

    testWidgets("semantics labels are present", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventsSection(events: [_makeEvent()]),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r"Today's events section")),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r"Event: Sprint Planning")),
        findsOneWidget,
      );
    });

    testWidgets("events are ordered chronologically", (tester) async {
      final events = [
        _makeEvent(id: "e1", title: "Late Event", startTime: DateTime(2026, 3, 15, 16, 0), endTime: DateTime(2026, 3, 15, 17, 0)),
        _makeEvent(id: "e2", title: "Early Event", startTime: DateTime(2026, 3, 15, 8, 0), endTime: DateTime(2026, 3, 15, 9, 0)),
        _makeEvent(id: "e3", title: "Mid Event", startTime: DateTime(2026, 3, 15, 12, 0), endTime: DateTime(2026, 3, 15, 13, 0)),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventsSection(events: events),
            ),
          ),
        ),
      );

      // All events should be rendered
      expect(find.text("Early Event"), findsOneWidget);
      expect(find.text("Mid Event"), findsOneWidget);
      expect(find.text("Late Event"), findsOneWidget);

      // Check order by finding position of each event
      final earlyPos = tester.getTopLeft(find.text("Early Event"));
      final midPos = tester.getTopLeft(find.text("Mid Event"));
      final latePos = tester.getTopLeft(find.text("Late Event"));
      expect(earlyPos.dy, lessThan(midPos.dy));
      expect(midPos.dy, lessThan(latePos.dy));
    });
  });
}
