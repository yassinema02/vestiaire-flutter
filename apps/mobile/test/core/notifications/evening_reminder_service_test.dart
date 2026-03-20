import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/notifications/evening_reminder_service.dart";
import "package:vestiaire_mobile/src/features/analytics/models/wear_log.dart";
import "package:vestiaire_mobile/src/features/analytics/services/wear_log_service.dart";

/// A mock WearLogService that can be configured to return specific results.
class _MockWearLogService implements WearLogService {
  List<WearLog> logsToReturn = [];
  bool shouldThrow = false;

  @override
  Future<List<WearLog>> getLogsForDateRange(
      String startDate, String endDate) async {
    if (shouldThrow) throw Exception("API error");
    return logsToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group("EveningReminderService", () {
    test("eveningNotificationId is 101", () {
      expect(EveningReminderService.eveningNotificationId, 101);
    });

    test("can be constructed with default plugin", () {
      final service = EveningReminderService();
      expect(service, isNotNull);
    });

    test(
        "buildEveningBody() returns default body when hasLoggedToday is false",
        () {
      final result = EveningReminderService.buildEveningBody();

      expect(result,
          "Tap to log what you wore today and keep your streak going!");
    });

    test(
        "buildEveningBody() returns encouraging body when hasLoggedToday is true",
        () {
      final result =
          EveningReminderService.buildEveningBody(hasLoggedToday: true);

      expect(result,
          "Great job logging today! Tap to add more or review your log.");
    });

    test(
        "buildEveningBody() returns default body when hasLoggedToday is explicitly false",
        () {
      final result =
          EveningReminderService.buildEveningBody(hasLoggedToday: false);

      expect(result,
          "Tap to log what you wore today and keep your streak going!");
    });

    group("hasLoggedToday()", () {
      late EveningReminderService service;
      late _MockWearLogService mockWearLogService;

      setUp(() {
        service = EveningReminderService();
        mockWearLogService = _MockWearLogService();
      });

      test("returns true when wear logs exist for today", () async {
        mockWearLogService.logsToReturn = [
          WearLog(
            id: "1",
            profileId: "p1",
            loggedDate: DateTime.now().toIso8601String().split("T")[0],
            itemIds: ["item1"],
          ),
        ];

        final result =
            await service.hasLoggedToday(mockWearLogService);

        expect(result, isTrue);
      });

      test("returns false when no wear logs exist for today", () async {
        mockWearLogService.logsToReturn = [];

        final result =
            await service.hasLoggedToday(mockWearLogService);

        expect(result, isFalse);
      });

      test("returns false on API error (graceful degradation)", () async {
        mockWearLogService.shouldThrow = true;

        final result =
            await service.hasLoggedToday(mockWearLogService);

        expect(result, isFalse);
      });
    });
  });
}
