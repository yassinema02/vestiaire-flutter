import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:vestiaire_mobile/src/features/analytics/models/wear_log.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/day_detail_bottom_sheet.dart";

void main() {
  group("DayDetailBottomSheet", () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required String date,
      required List<WearLog> wearLogs,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayDetailBottomSheet(
              date: date,
              wearLogs: wearLogs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("renders date header with formatted date", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-1"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
        ],
      );

      expect(find.text("Wednesday, March 18, 2026"), findsOneWidget);
    });

    testWidgets("displays wear log entries with timestamps", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-1"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
        ],
      );

      // Time should be formatted (exact format depends on locale)
      expect(find.textContaining("2:30"), findsOneWidget);
    });

    testWidgets("shows Logged outfit label when outfitId is present", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            outfitId: "outfit-1",
            itemIds: ["item-1"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
        ],
      );

      expect(find.text("Logged outfit"), findsOneWidget);
    });

    testWidgets("does not show Logged outfit when outfitId is null", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-1"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
        ],
      );

      expect(find.text("Logged outfit"), findsNothing);
    });

    testWidgets("displays item IDs as placeholders when no apiClient", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-abc", "item-def"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
        ],
      );

      expect(find.text("item-abc"), findsOneWidget);
      expect(find.text("item-def"), findsOneWidget);
    });

    testWidgets("shows total items logged count", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-1", "item-2"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
          WearLog(
            id: "log-2",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-3"],
            createdAt: "2026-03-18T16:00:00Z",
          ),
        ],
      );

      expect(find.text("3 items logged"), findsOneWidget);
    });

    testWidgets("semantics labels are present", (tester) async {
      await pumpSheet(
        tester,
        date: "2026-03-18",
        wearLogs: const [
          WearLog(
            id: "log-1",
            profileId: "p1",
            loggedDate: "2026-03-18",
            itemIds: ["item-1"],
            createdAt: "2026-03-18T14:30:00Z",
          ),
        ],
      );

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label == "Outfit details for Wednesday, March 18, 2026"),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == "Logged 1 items"),
        findsOneWidget,
      );
    });
  });
}
