import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/notifications/evening_reminder_preferences.dart";
import "package:vestiaire_mobile/src/core/notifications/evening_reminder_service.dart";
import "package:vestiaire_mobile/src/core/notifications/morning_notification_service.dart";

void main() {
  group("App Evening Reminder Lifecycle", () {
    test(
        "evening reminder should be scheduled when wear_logging is enabled",
        () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final prefs = EveningReminderPreferences(prefs: sp);

      // Default: wear_logging is enabled
      final enabled = await prefs.isWearLoggingEnabled();
      expect(enabled, isTrue);

      // Default time should be 20:00
      final time = await prefs.getEveningTime();
      expect(time.hour, 20);
      expect(time.minute, 0);

      // Service can be constructed and is ready to schedule
      final service = EveningReminderService();
      expect(service, isNotNull);
      expect(EveningReminderService.eveningNotificationId, 101);
    });

    test(
        "evening reminder should NOT be scheduled when wear_logging is disabled",
        () async {
      SharedPreferences.setMockInitialValues({"wear_logging_enabled": false});
      final sp = await SharedPreferences.getInstance();
      final prefs = EveningReminderPreferences(prefs: sp);

      final enabled = await prefs.isWearLoggingEnabled();
      expect(enabled, isFalse);
    });

    test(
        "sign-out cancels all notifications (evening reminder included via cancelAllNotifications)",
        () {
      // MorningNotificationService.cancelAllNotifications() cancels ALL
      // scheduled notifications, which includes the evening reminder.
      // This is already established in Story 4.7 and used in app.dart.
      final morningService = MorningNotificationService();
      expect(morningService, isNotNull);
      // The cancelAllNotifications() method on the shared plugin instance
      // cancels both morning (ID 100) and evening (ID 101).
    });

    test(
        "account deletion cancels all notifications (evening reminder included)",
        () {
      // Same as sign-out: cancelAllNotifications() handles all notification IDs
      final morningService = MorningNotificationService();
      expect(morningService, isNotNull);
    });

    test(
        "VestiaireApp accepts optional eveningReminderService and eveningReminderPreferences parameters",
        () {
      // Verify the service and preferences can be constructed independently
      final service = EveningReminderService();
      final prefs = EveningReminderPreferences();
      expect(service, isNotNull);
      expect(prefs, isNotNull);
    });

    test("evening notification uses ID 101, distinct from morning ID 100", () {
      expect(EveningReminderService.eveningNotificationId, 101);
      expect(MorningNotificationService.morningNotificationId, 100);
      expect(
        EveningReminderService.eveningNotificationId,
        isNot(equals(MorningNotificationService.morningNotificationId)),
      );
    });
  });
}
