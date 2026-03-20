import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/features/home/widgets/event_summary_widget.dart";

CalendarEvent _makeEvent({
  String id = "evt-1",
  String title = "Sprint Planning",
  String eventType = "work",
  int formalityScore = 5,
  DateTime? startTime,
  DateTime? endTime,
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
    classificationSource: "keyword",
  );
}

void main() {
  group("EventSummaryWidget", () {
    testWidgets("renders next upcoming event title and time", (tester) async {
      final events = [
        _makeEvent(
          title: "Team standup",
          startTime: DateTime(2026, 3, 15, 9, 30),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EventSummaryWidget(events: events)),
        ),
      );

      expect(find.text("Team standup"), findsOneWidget);
      expect(find.text("09:30"), findsOneWidget);
    });

    testWidgets("shows event type icon matching event type", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: [_makeEvent(eventType: "work")],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.work), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: [_makeEvent(eventType: "social")],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.people), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: [_makeEvent(eventType: "active")],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: [_makeEvent(eventType: "formal")],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: [_makeEvent(eventType: "casual")],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.event), findsOneWidget);
    });

    testWidgets("shows '+N more events' when multiple events exist",
        (tester) async {
      final events = [
        _makeEvent(
          id: "evt-1",
          title: "Meeting",
          startTime: DateTime(2026, 3, 15, 10, 0),
        ),
        _makeEvent(
          id: "evt-2",
          title: "Lunch",
          startTime: DateTime(2026, 3, 15, 12, 0),
        ),
        _makeEvent(
          id: "evt-3",
          title: "Gym",
          startTime: DateTime(2026, 3, 15, 18, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EventSummaryWidget(events: events)),
        ),
      );

      expect(find.text("+2 more"), findsOneWidget);
    });

    testWidgets("shows 'No events today' when events list is empty",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(events: const []),
          ),
        ),
      );

      expect(find.text("No events today"), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets("semantics labels are present and correct", (tester) async {
      // With events
      final events = [
        _makeEvent(
          title: "Sprint Planning",
          startTime: DateTime(2026, 3, 15, 10, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EventSummaryWidget(events: events)),
        ),
      );

      final semantics = tester.getSemantics(find.byType(EventSummaryWidget));
      expect(
        semantics.label,
        contains("Upcoming event: Sprint Planning at 10:00"),
      );

      // Empty state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(events: const []),
          ),
        ),
      );

      final emptySemantics =
          tester.getSemantics(find.byType(EventSummaryWidget));
      expect(
        emptySemantics.label,
        contains("No events scheduled for today"),
      );
    });

    testWidgets("shows event type badge label", (tester) async {
      final events = [_makeEvent(eventType: "work")];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EventSummaryWidget(events: events)),
        ),
      );

      expect(find.text("Work"), findsOneWidget);
    });

    testWidgets("tapping the event summary calls onEventTap with the next event",
        (tester) async {
      CalendarEvent? tappedEvent;
      final events = [
        _makeEvent(
          id: "evt-1",
          title: "Meeting",
          startTime: DateTime(2026, 3, 15, 10, 0),
        ),
        _makeEvent(
          id: "evt-2",
          title: "Lunch",
          startTime: DateTime(2026, 3, 15, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: events,
              onEventTap: (event) => tappedEvent = event,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Meeting"));
      await tester.pumpAndSettle();

      expect(tappedEvent, isNotNull);
      expect(tappedEvent!.id, "evt-1");
      expect(tappedEvent!.title, "Meeting");
    });

    testWidgets("onEventTap is not called when events list is empty",
        (tester) async {
      CalendarEvent? tappedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventSummaryWidget(
              events: const [],
              onEventTap: (event) => tappedEvent = event,
            ),
          ),
        ),
      );

      // Tap on the empty state card
      await tester.tap(find.text("No events today"));
      await tester.pumpAndSettle();

      expect(tappedEvent, isNull);
    });

    testWidgets("shows 'All day' for all-day events", (tester) async {
      final events = [
        _makeEvent(
          title: "Vacation",
          allDay: true,
          eventType: "casual",
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EventSummaryWidget(events: events)),
        ),
      );

      expect(find.text("All day"), findsOneWidget);
    });
  });
}
