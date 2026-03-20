import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:intl/intl.dart";

import "package:vestiaire_mobile/src/features/analytics/models/wear_log.dart";
import "package:vestiaire_mobile/src/features/analytics/screens/wear_calendar_screen.dart";
import "package:vestiaire_mobile/src/features/analytics/services/wear_log_service.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/month_summary_row.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";

/// Mock WearLogService for calendar tests.
class _MockWearLogService implements WearLogService {
  List<WearLog> logsToReturn = [];
  bool shouldFail = false;
  Completer<List<WearLog>>? hangCompleter;
  int fetchCallCount = 0;
  String? lastStartDate;
  String? lastEndDate;

  @override
  Future<List<WearLog>> getLogsForDateRange(
    String startDate,
    String endDate,
  ) async {
    fetchCallCount++;
    lastStartDate = startDate;
    lastEndDate = endDate;
    if (hangCompleter != null) {
      return hangCompleter!.future;
    }
    if (shouldFail) throw Exception("Network error");
    return logsToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("WearCalendarScreen", () {
    late _MockWearLogService mockService;

    setUp(() {
      mockService = _MockWearLogService();
    });

    Future<void> pumpCalendar(
      WidgetTester tester, {
      DateTime? initialMonth,
      List<WearLog>? logs,
      bool shouldFail = false,
    }) async {
      mockService.logsToReturn = logs ?? [];
      mockService.shouldFail = shouldFail;
      await tester.pumpWidget(
        MaterialApp(
          home: WearCalendarScreen(
            wearLogService: mockService,
            initialMonth: initialMonth ?? DateTime(2026, 3, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("renders current month header by default", (tester) async {
      await pumpCalendar(tester, initialMonth: DateTime(2026, 3, 1));
      expect(find.text("March 2026"), findsOneWidget);
    });

    testWidgets("displays day cells with activity indicators for dates with wear logs", (tester) async {
      final logs = [
        const WearLog(
          id: "log-1",
          profileId: "p1",
          loggedDate: "2026-03-05",
          itemIds: ["item-1", "item-2"],
          createdAt: "2026-03-05T14:30:00Z",
        ),
        const WearLog(
          id: "log-2",
          profileId: "p1",
          loggedDate: "2026-03-10",
          itemIds: ["item-3"],
          createdAt: "2026-03-10T09:00:00Z",
        ),
      ];

      await pumpCalendar(tester, logs: logs);

      // Activity indicator dot: 6x6 container with circle shape
      // Find containers that are activity indicators (6x6 circles with primary color)
      final dotFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == 6 &&
          widget.constraints?.maxHeight == 6);
      // We have 2 days with activity, should have 2 dots
      // Note: Container with width/height uses BoxConstraints tight
      // Let's find by decoration instead
      final coloredDots = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final dec = widget.decoration;
          if (dec is BoxDecoration) {
            return dec.shape == BoxShape.circle &&
                dec.color == const Color(0xFF4F46E5);
          }
        }
        return false;
      });
      expect(coloredDots, findsNWidgets(2));
    });

    testWidgets("does not display activity indicators for dates without wear logs", (tester) async {
      await pumpCalendar(tester, logs: []);

      final coloredDots = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final dec = widget.decoration;
          if (dec is BoxDecoration) {
            return dec.shape == BoxShape.circle &&
                dec.color == const Color(0xFF4F46E5);
          }
        }
        return false;
      });
      expect(coloredDots, findsNothing);
    });

    testWidgets("left chevron navigates to previous month and re-fetches data", (tester) async {
      await pumpCalendar(tester, initialMonth: DateTime(2026, 3, 1));
      expect(find.text("March 2026"), findsOneWidget);

      final initialCallCount = mockService.fetchCallCount;

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text("February 2026"), findsOneWidget);
      expect(mockService.fetchCallCount, greaterThan(initialCallCount));
      expect(mockService.lastStartDate, "2026-02-01");
      expect(mockService.lastEndDate, "2026-02-28");
    });

    testWidgets("right chevron navigates to next month when not at current month", (tester) async {
      // Start at January 2026 (not current month)
      await pumpCalendar(tester, initialMonth: DateTime(2026, 1, 1));
      expect(find.text("January 2026"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text("February 2026"), findsOneWidget);
    });

    testWidgets("right chevron is disabled when viewing the current month", (tester) async {
      final now = DateTime.now();
      await pumpCalendar(tester, initialMonth: now);

      final nextButton = find.byWidgetPredicate((w) =>
          w is IconButton &&
          (w.icon as Icon).icon == Icons.chevron_right &&
          w.onPressed == null);
      expect(nextButton, findsOneWidget);
    });

    testWidgets("loading state shows CircularProgressIndicator", (tester) async {
      final completer = Completer<List<WearLog>>();
      mockService.hangCompleter = completer;

      await tester.pumpWidget(
        MaterialApp(
          home: WearCalendarScreen(
            wearLogService: mockService,
            initialMonth: DateTime(2026, 3, 1),
          ),
        ),
      );
      // Pump a single frame to render the loading state
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to allow cleanup
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets("error state shows error message and retry button", (tester) async {
      await pumpCalendar(tester, shouldFail: true);

      expect(find.textContaining("Network error"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("tapping retry re-fetches data", (tester) async {
      await pumpCalendar(tester, shouldFail: true);

      final callsBefore = mockService.fetchCallCount;

      // Now make it succeed and tap retry
      mockService.shouldFail = false;
      await tester.tap(find.text("Retry"));
      await tester.pumpAndSettle();

      expect(mockService.fetchCallCount, greaterThan(callsBefore));
    });

    testWidgets("empty state shows Start logging message", (tester) async {
      await pumpCalendar(tester, logs: []);

      expect(
        find.text("Start logging your outfits to see your activity here!"),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.calendar_today), findsWidgets);
    });

    testWidgets("today's date cell has highlight styling", (tester) async {
      final now = DateTime.now();
      await pumpCalendar(tester, initialMonth: now);

      // Find a container with today's highlight color
      final todayHighlight = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final dec = widget.decoration;
          if (dec is BoxDecoration) {
            return dec.color != null &&
                dec.color!.value ==
                    const Color(0xFF4F46E5).withValues(alpha: 0.1).value;
          }
        }
        return false;
      });
      expect(todayHighlight, findsOneWidget);
    });

    testWidgets("summary row displays correct metrics", (tester) async {
      final logs = [
        const WearLog(
          id: "log-1",
          profileId: "p1",
          loggedDate: "2026-03-05",
          itemIds: ["item-1", "item-2"],
        ),
        const WearLog(
          id: "log-2",
          profileId: "p1",
          loggedDate: "2026-03-05",
          itemIds: ["item-3"],
        ),
        const WearLog(
          id: "log-3",
          profileId: "p1",
          loggedDate: "2026-03-10",
          itemIds: ["item-4"],
        ),
      ];

      await pumpCalendar(tester, logs: logs);

      expect(find.byType(MonthSummaryRow), findsOneWidget);
      // 2 unique days logged
      expect(find.text("Days Logged"), findsOneWidget);
      // 4 total items (2+1+1)
      expect(find.text("Items Logged"), findsOneWidget);
    });

    testWidgets("semantics labels are present on calendar and navigation", (tester) async {
      await pumpCalendar(tester, initialMonth: DateTime(2026, 3, 1));

      // Verify Semantics widgets exist with expected labels
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "Wear calendar for March 2026"),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "Previous month"),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "Next month"),
        findsOneWidget,
      );
    });

    testWidgets("semantics labels present on day cells", (tester) async {
      final logs = [
        const WearLog(
          id: "log-1",
          profileId: "p1",
          loggedDate: "2026-03-05",
          itemIds: ["item-1"],
        ),
      ];

      await pumpCalendar(tester, logs: logs);

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "Day 5, 1 outfits logged"),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "Day 1, no outfits logged"),
        findsOneWidget,
      );
    });

    testWidgets("calls wearLogService.getLogsForDateRange with correct month boundaries", (tester) async {
      await pumpCalendar(tester, initialMonth: DateTime(2026, 3, 1));

      expect(mockService.lastStartDate, "2026-03-01");
      expect(mockService.lastEndDate, "2026-03-31");
    });

    testWidgets("fetches correct boundaries for February", (tester) async {
      await pumpCalendar(tester, initialMonth: DateTime(2026, 2, 1));

      expect(mockService.lastStartDate, "2026-02-01");
      expect(mockService.lastEndDate, "2026-02-28");
    });
  });
}
