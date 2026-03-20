import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/data/latest_all.dart" as tz;
import "package:timezone/timezone.dart" as tz;

/// Service for scheduling and managing daily morning outfit notifications.
///
/// Uses [FlutterLocalNotificationsPlugin] to schedule a repeating daily
/// notification at a user-configurable time. The notification includes a
/// weather snippet when available.
class MorningNotificationService {
  MorningNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Fixed notification ID for the morning outfit notification.
  static const int morningNotificationId = 100;

  /// Callback to invoke when the user taps the notification.
  void Function()? _onNotificationTap;

  /// Initializes the local notification plugin with platform-specific settings.
  ///
  /// Must be called once before scheduling notifications. Does NOT request
  /// permission (Story 1.6 handles that via FCM).
  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _onNotificationTap?.call();
  }

  /// Registers a callback to be invoked when the user taps a notification.
  ///
  /// Typically used by [VestiaireApp] to navigate to the Home tab.
  void setOnNotificationTap(void Function() callback) {
    _onNotificationTap = callback;
  }

  /// Schedules a daily repeating notification at the given [time].
  ///
  /// Cancels any existing morning notification before scheduling the new one.
  /// The [weatherSnippet] is used as the notification body text.
  Future<void> scheduleMorningNotification({
    required TimeOfDay time,
    required String weatherSnippet,
  }) async {
    // Cancel existing notification first
    await cancelMorningNotification();

    const androidDetails = AndroidNotificationDetails(
      "morning_outfit",
      "Morning Outfit Reminders",
      channelDescription: "Daily morning outfit suggestion notifications",
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledTime = _nextInstanceOfTime(time);

    await _plugin.zonedSchedule(
      morningNotificationId,
      "Your outfit is ready!",
      weatherSnippet,
      scheduledTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the morning outfit notification.
  Future<void> cancelMorningNotification() async {
    await _plugin.cancel(morningNotificationId);
  }

  /// Cancels all scheduled local notifications. Used on sign-out.
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// Builds a weather snippet string for the notification body.
  ///
  /// Returns a formatted string like "It's 14C and sunny. Open Vestiaire
  /// for today's outfit." If weather data is unavailable (empty description),
  /// returns a fallback message.
  static String buildWeatherSnippet(
    double? temperature,
    String? weatherDescription,
  ) {
    if (temperature == null ||
        weatherDescription == null ||
        weatherDescription.isEmpty) {
      return "Open Vestiaire to see today's outfit suggestion.";
    }
    return "It's ${temperature.round()}C and $weatherDescription. Open Vestiaire for today's outfit.";
  }

  /// Computes the next occurrence of [time] in the local timezone.
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
