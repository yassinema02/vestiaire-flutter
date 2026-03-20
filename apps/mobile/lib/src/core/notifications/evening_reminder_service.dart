import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/timezone.dart" as tz;

import "../../features/analytics/services/wear_log_service.dart";

/// Service for scheduling and managing daily evening wear-log reminder notifications.
///
/// Uses [FlutterLocalNotificationsPlugin] to schedule a repeating daily
/// notification at a user-configurable time. The notification reminds
/// the user to log their outfit and adjusts the body text based on whether
/// they have already logged today.
class EveningReminderService {
  EveningReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    this.wearLogService,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Optional [WearLogService] for checking today's log status.
  final WearLogService? wearLogService;

  /// Fixed notification ID for the evening wear-log reminder.
  static const int eveningNotificationId = 101;

  /// Notification title for the evening reminder.
  static const String notificationTitle = "Did you log today's outfit?";

  /// Schedules a daily repeating evening reminder notification at the given [time].
  ///
  /// Cancels any existing evening reminder before scheduling the new one.
  /// The [hasLoggedToday] flag determines the notification body text.
  /// Sets the notification payload to `"evening_wear_log"` for deep-link handling.
  Future<void> scheduleEveningReminder({
    required TimeOfDay time,
    bool hasLoggedToday = false,
  }) async {
    // Cancel existing notification first
    await cancelEveningReminder();

    const androidDetails = AndroidNotificationDetails(
      "evening_wear_log",
      "Evening Wear Log Reminders",
      channelDescription: "Daily evening reminders to log your outfit",
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
    final body = buildEveningBody(hasLoggedToday: hasLoggedToday);

    await _plugin.zonedSchedule(
      eveningNotificationId,
      notificationTitle,
      body,
      scheduledTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: "evening_wear_log",
    );
  }

  /// Cancels the evening wear-log reminder notification.
  Future<void> cancelEveningReminder() async {
    await _plugin.cancel(eveningNotificationId);
  }

  /// Checks if the user has logged at least one outfit today.
  ///
  /// Returns `true` if wear logs exist for today's date.
  /// Returns `false` on any error (safe default for graceful degradation).
  Future<bool> hasLoggedToday(WearLogService wearLogService) async {
    try {
      final today = DateTime.now();
      final dateStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final logs = await wearLogService.getLogsForDateRange(dateStr, dateStr);
      return logs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Builds the notification body text based on whether the user has already
  /// logged an outfit today.
  ///
  /// Returns a default nudge message or an encouraging message if already logged.
  static String buildEveningBody({bool hasLoggedToday = false}) {
    if (hasLoggedToday) {
      return "Great job logging today! Tap to add more or review your log.";
    }
    return "Tap to log what you wore today and keep your streak going!";
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
