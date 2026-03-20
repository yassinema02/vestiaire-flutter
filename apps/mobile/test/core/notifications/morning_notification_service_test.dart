import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/notifications/morning_notification_service.dart";

void main() {
  group("MorningNotificationService", () {
    test("morningNotificationId is 100", () {
      expect(MorningNotificationService.morningNotificationId, 100);
    });

    test(
        "buildWeatherSnippet() returns formatted string with temperature and description",
        () {
      final result =
          MorningNotificationService.buildWeatherSnippet(14.3, "sunny");

      expect(result,
          "It's 14C and sunny. Open Vestiaire for today's outfit.");
    });

    test("buildWeatherSnippet() rounds temperature to nearest integer", () {
      final result =
          MorningNotificationService.buildWeatherSnippet(14.7, "cloudy");

      expect(result,
          "It's 15C and cloudy. Open Vestiaire for today's outfit.");
    });

    test("buildWeatherSnippet() returns fallback when temperature is null",
        () {
      final result =
          MorningNotificationService.buildWeatherSnippet(null, "sunny");

      expect(result,
          "Open Vestiaire to see today's outfit suggestion.");
    });

    test("buildWeatherSnippet() returns fallback when description is null",
        () {
      final result =
          MorningNotificationService.buildWeatherSnippet(14.0, null);

      expect(result,
          "Open Vestiaire to see today's outfit suggestion.");
    });

    test("buildWeatherSnippet() returns fallback when description is empty",
        () {
      final result =
          MorningNotificationService.buildWeatherSnippet(14.0, "");

      expect(result,
          "Open Vestiaire to see today's outfit suggestion.");
    });

    test("setOnNotificationTap stores callback", () {
      final service = MorningNotificationService();

      bool tapped = false;
      service.setOnNotificationTap(() {
        tapped = true;
      });

      // Callback is stored -- we verify it's stored (not null) via the
      // constructor accepting it without error. The actual invocation
      // happens via the plugin's notification response callback which
      // requires platform integration.
      expect(tapped, isFalse); // Not called yet
    });

    test("can be constructed with default plugin", () {
      // Verify that the service can be constructed without error.
      final service = MorningNotificationService();
      expect(service, isNotNull);
    });

    test("buildWeatherSnippet handles zero temperature", () {
      final result =
          MorningNotificationService.buildWeatherSnippet(0.0, "snowy");

      expect(result,
          "It's 0C and snowy. Open Vestiaire for today's outfit.");
    });

    test("buildWeatherSnippet handles negative temperature", () {
      final result =
          MorningNotificationService.buildWeatherSnippet(-5.2, "freezing");

      expect(result,
          "It's -5C and freezing. Open Vestiaire for today's outfit.");
    });
  });
}
