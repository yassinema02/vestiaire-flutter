import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:intl/intl.dart";

import "package:vestiaire_mobile/src/features/analytics/models/wear_log.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/month_summary_row.dart";

void main() {
  group("MonthSummaryRow", () {
    Future<void> pumpRow(
      WidgetTester tester, {
      required Map<String, List<WearLog>> wearLogsByDate,
      DateTime? currentMonth,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthSummaryRow(
              wearLogsByDate: wearLogsByDate,
              currentMonth: currentMonth ?? DateTime(2026, 3, 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("displays correct Days Logged count", (tester) async {
      final logs = <String, List<WearLog>>{
        "2026-03-05": [
          const WearLog(id: "1", profileId: "p1", loggedDate: "2026-03-05", itemIds: ["a"]),
        ],
        "2026-03-10": [
          const WearLog(id: "2", profileId: "p1", loggedDate: "2026-03-10", itemIds: ["b"]),
        ],
      };
      await pumpRow(tester, wearLogsByDate: logs);

      // 2 days logged
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "2 days logged"),
        findsOneWidget,
      );
      expect(find.text("Days Logged"), findsOneWidget);
    });

    testWidgets("displays correct Items Logged count", (tester) async {
      final logs = <String, List<WearLog>>{
        "2026-03-05": [
          const WearLog(id: "1", profileId: "p1", loggedDate: "2026-03-05", itemIds: ["a", "b"]),
          const WearLog(id: "2", profileId: "p1", loggedDate: "2026-03-05", itemIds: ["c"]),
        ],
      };
      await pumpRow(tester, wearLogsByDate: logs);

      // 3 items logged
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "3 items logged"),
        findsOneWidget,
      );
      expect(find.text("Items Logged"), findsOneWidget);
    });

    testWidgets("computes correct streak ending on today", (tester) async {
      final now = DateTime.now();
      final fmt = DateFormat("yyyy-MM-dd");
      final today = fmt.format(now);
      final yesterday = fmt.format(now.subtract(const Duration(days: 1)));
      final twoDaysAgo = fmt.format(now.subtract(const Duration(days: 2)));

      final logs = <String, List<WearLog>>{
        today: [
          WearLog(id: "1", profileId: "p1", loggedDate: today, itemIds: const ["a"]),
        ],
        yesterday: [
          WearLog(id: "2", profileId: "p1", loggedDate: yesterday, itemIds: const ["b"]),
        ],
        twoDaysAgo: [
          WearLog(id: "3", profileId: "p1", loggedDate: twoDaysAgo, itemIds: const ["c"]),
        ],
      };
      await pumpRow(tester, wearLogsByDate: logs, currentMonth: now);

      // Streak should be 3
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "3 day streak"),
        findsOneWidget,
      );
      expect(find.text("Day Streak"), findsOneWidget);
    });

    testWidgets("streak is 0 when no logs exist", (tester) async {
      await pumpRow(tester, wearLogsByDate: {});

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "0 day streak"),
        findsOneWidget,
      );
    });

    testWidgets("streak handles gaps correctly", (tester) async {
      final now = DateTime.now();
      final fmt = DateFormat("yyyy-MM-dd");
      final today = fmt.format(now);
      // Skip yesterday, log 2 days ago
      final twoDaysAgo = fmt.format(now.subtract(const Duration(days: 2)));

      final logs = <String, List<WearLog>>{
        today: [
          WearLog(id: "1", profileId: "p1", loggedDate: today, itemIds: const ["a"]),
        ],
        twoDaysAgo: [
          WearLog(id: "2", profileId: "p1", loggedDate: twoDaysAgo, itemIds: const ["b"]),
        ],
      };
      await pumpRow(tester, wearLogsByDate: logs, currentMonth: now);

      // Streak is only 1 (today), because yesterday has a gap
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "1 day streak"),
        findsOneWidget,
      );
    });

    testWidgets("semantics labels are present", (tester) async {
      final logs = <String, List<WearLog>>{
        "2026-03-05": [
          const WearLog(id: "1", profileId: "p1", loggedDate: "2026-03-05", itemIds: ["a", "b"]),
        ],
      };
      await pumpRow(tester, wearLogsByDate: logs);

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "1 days logged"),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "2 items logged"),
        findsOneWidget,
      );
      expect(find.text("Day Streak"), findsOneWidget);
    });
  });
}
