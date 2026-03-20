import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/timezone.dart" as tz;

/// Service for scheduling and managing daily posting reminder notifications.
///
/// Uses [FlutterLocalNotificationsPlugin] to schedule a repeating daily
/// notification reminding the user to share their OOTD post. Follows the
/// same pattern as [MorningNotificationService] (ID 100) and
/// [EveningReminderService] (ID 101).
///
/// Story 9.6: Social Notification Preferences (FR-NTF-04, FR-NTF-05)
class PostingReminderService {
  PostingReminderService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Fixed notification ID for the daily posting reminder.
  static const int postingReminderNotificationId = 102;

  /// Schedules a daily repeating posting reminder notification at the given [time].
  ///
  /// Cancels any existing posting reminder before scheduling the new one.
  /// If [hasPostedToday] is true, the reminder is NOT scheduled (silently skipped).
  Future<void> schedulePostingReminder({
    required TimeOfDay time,
    bool hasPostedToday = false,
  }) async {
    // Cancel existing notification first
    await cancelPostingReminder();

    // Skip scheduling if the user has already posted today
    if (hasPostedToday) return;

    const androidDetails = AndroidNotificationDetails(
      "posting_reminder",
      "Daily Posting Reminders",
      channelDescription: "Daily reminders to share your OOTD",
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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
      postingReminderNotificationId,
      "Time to share your OOTD!",
      buildPostingBody(),
      scheduledTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: "posting_reminder",
    );
  }

  /// Cancels the daily posting reminder notification.
  Future<void> cancelPostingReminder() async {
    await _plugin.cancel(postingReminderNotificationId);
  }

  /// Returns the posting reminder body text.
  static String buildPostingBody() {
    return "Post your outfit of the day to your squads.";
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
