import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/features/home/widgets/event_detail_bottom_sheet.dart";

CalendarEvent _makeEvent({
  String id = "evt-1",
  String title = "Sprint Planning",
  String eventType = "work",
  int formalityScore = 5,
  String classificationSource = "keyword",
  String? location,
  DateTime? startTime,
  DateTime? endTime,
  bool allDay = false,
}) {
  return CalendarEvent(
    id: id,
    sourceCalendarId: "cal-1",
    sourceEventId: id,
    title: title,
    location: location,
    startTime: startTime ?? DateTime(2026, 3, 15, 10, 0),
    endTime: endTime ?? DateTime(2026, 3, 15, 11, 0),
    allDay: allDay,
    eventType: eventType,
    formalityScore: formalityScore,
    classificationSource: classificationSource,
  );
}

void main() {
  group("EventDetailBottomSheet", () {
    testWidgets("renders event title, time, and location", (tester) async {
      final event = _makeEvent(
        title: "Team standup",
        location: "Office",
        startTime: DateTime(2026, 3, 15, 9, 30),
        endTime: DateTime(2026, 3, 15, 10, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDetailBottomSheet(
              event: event,
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("Team standup"), findsOneWidget);
      expect(find.text("09:30 - 10:00"), findsOneWidget);
      expect(find.text("Office"), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets("shows 'User override' chip when classificationSource is 'user'",
        (tester) async {
      final event = _makeEvent(classificationSource: "user");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDetailBottomSheet(
              event: event,
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("User override"), findsOneWidget);
    });

    testWidgets(
        "does not show 'User override' chip when classificationSource is 'keyword'",
        (tester) async {
      final event = _makeEvent(classificationSource: "keyword");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDetailBottomSheet(
              event: event,
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("User override"), findsNothing);
    });

    testWidgets(
        "does not show 'User override' chip when classificationSource is 'ai'",
        (tester) async {
      final event = _makeEvent(classificationSource: "ai");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDetailBottomSheet(
              event: event,
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("User override"), findsNothing);
    });

    testWidgets("displays all 5 event type chips with correct labels and icons",
        (tester) async {
      final event = _makeEvent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text("Work"), findsOneWidget);
      expect(find.text("Social"), findsOneWidget);
      expect(find.text("Active"), findsOneWidget);
      expect(find.text("Formal"), findsOneWidget);
      expect(find.text("Casual"), findsOneWidget);

      expect(find.byIcon(Icons.work), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
    });

    testWidgets("pre-selects the current event type chip", (tester) async {
      final event = _makeEvent(eventType: "social");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      // Find all ChoiceChips and check the "Social" one is selected
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final socialChip = chips.firstWhere(
        (chip) => (chip.label as Text).data == "Social",
      );
      expect(socialChip.selected, true);
    });

    testWidgets("tapping a different event type chip selects it",
        (tester) async {
      final event = _makeEvent(eventType: "work");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap "Social" chip
      await tester.tap(find.text("Social"));
      await tester.pumpAndSettle();

      // Social should now be selected
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final socialChip = chips.firstWhere(
        (chip) => (chip.label as Text).data == "Social",
      );
      expect(socialChip.selected, true);

      // Work should be deselected
      final workChip = chips.firstWhere(
        (chip) => (chip.label as Text).data == "Work",
      );
      expect(workChip.selected, false);
    });

    testWidgets("slider displays current formality score", (tester) async {
      final event = _makeEvent(formalityScore: 7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 7.0);
    });

    testWidgets("slider updates when dragged", (tester) async {
      final event = _makeEvent(formalityScore: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      // Drag slider to the right
      final sliderFinder = find.byType(Slider);
      final sliderRect = tester.getRect(sliderFinder);
      await tester.drag(sliderFinder, Offset(sliderRect.width / 4, 0));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Value should have changed from 5
      expect(slider.value, isNot(5.0));
    });

    testWidgets("'Save' button calls onSave with updated CalendarEvent",
        (tester) async {
      CalendarEvent? savedEvent;
      final event = _makeEvent(eventType: "work", formalityScore: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (e) => savedEvent = e,
              ),
            ),
          ),
        ),
      );

      // Change event type to "formal"
      await tester.tap(find.text("Formal"));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(savedEvent, isNotNull);
      expect(savedEvent!.eventType, "formal");
      expect(savedEvent!.classificationSource, "user");
      // Original fields preserved
      expect(savedEvent!.id, event.id);
      expect(savedEvent!.title, event.title);
    });

    testWidgets("'Cancel' button calls onCancel", (tester) async {
      var cancelCalled = false;
      final event = _makeEvent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
                onCancel: () => cancelCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(cancelCalled, true);
    });

    testWidgets("semantics labels are present for chip row, slider, and save button",
        (tester) async {
      final event = _makeEvent(formalityScore: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventDetailBottomSheet(
                event: event,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      // Check Semantics labels
      expect(
        find.bySemanticsLabel("Event type selector"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Formality score: 5"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Save event classification"),
        findsOneWidget,
      );
    });
  });
}
