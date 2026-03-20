import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/timezone.dart" as tz;

import "../calendar/calendar_event.dart";

/// Service for scheduling and managing one-shot formal event reminder notifications.
///
/// Uses [FlutterLocalNotificationsPlugin] to schedule a one-time notification
/// at the configured evening time reminding the user to prepare for formal events
/// tomorrow. Follows the same pattern as [MorningNotificationService] (ID 100),
/// [EveningReminderService] (ID 101), and [PostingReminderService] (ID 102).
///
/// Story 12.3: Formal Event Reminders (FR-EVT-07, FR-EVT-08, FR-PSH-05)
class EventReminderService {
  EventReminderService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Fixed notification ID for the event reminder notification.
  static const int eventReminderNotificationId = 103;

  /// Schedules a one-shot event reminder notification at the given [time] for today.
  ///
  /// Cancels any existing event reminder before scheduling the new one.
  /// If [formalEvents] is empty, returns without scheduling.
  /// The [prepTip] is used in the notification body. If null, a fallback is used.
  Future<void> scheduleEventReminder({
    required TimeOfDay time,
    required List<CalendarEvent> formalEvents,
    List<dynamic>? scheduledOutfits,
    String? prepTip,
  }) async {
    // Cancel existing notification first
    await cancelEventReminder();

    // No formal events tomorrow -- skip scheduling
    if (formalEvents.isEmpty) return;

    // Build notification content
    final String title;
    final String body;

    if (formalEvents.length == 1) {
      title = "Formal event tomorrow: ${formalEvents.first.title}";
      body = prepTip ??
          buildFallbackTip(formalEvents.first.formalityScore);
    } else if (formalEvents.length <= 3) {
      title = "Formal events tomorrow";
      final eventList =
          formalEvents.map((e) => e.title).join(", ");
      body = prepTip != null
          ? "$eventList. $prepTip"
          : "$eventList. ${buildFallbackTip(formalEvents.first.formalityScore)}";
    } else {
      title = "Formal events tomorrow";
      final first3 =
          formalEvents.take(3).map((e) => e.title).join(", ");
      final remaining = formalEvents.length - 3;
      body = prepTip != null
          ? "$first3, and $remaining more. $prepTip"
          : "$first3, and $remaining more. ${buildFallbackTip(formalEvents.first.formalityScore)}";
    }

    const androidDetails = AndroidNotificationDetails(
      "event_reminders",
      "Formal Event Reminders",
      channelDescription: "Evening reminders before formal events",
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

    final scheduledTime = _nextInstanceOfTimeToday(time);
    // If the configured time has already passed today, skip scheduling
    if (scheduledTime == null) return;

    await _plugin.zonedSchedule(
      eventReminderNotificationId,
      title,
      body,
      scheduledTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: "event_reminder",
    );
  }

  /// Cancels the event reminder notification.
  Future<void> cancelEventReminder() async {
    await _plugin.cancel(eventReminderNotificationId);
  }

  /// Builds a fallback preparation tip based on formality score.
  ///
  /// Returns a tip appropriate for the formality level:
  /// - 7-8: "Check that your outfit is clean and pressed."
  /// - 9-10: "Consider dry cleaning and shoe polishing tonight."
  static String buildFallbackTip(int formalityScore) {
    if (formalityScore >= 9) {
      return "Consider dry cleaning and shoe polishing tonight.";
    }
    return "Check that your outfit is clean and pressed.";
  }

  /// Filters events to only those meeting the formality threshold.
  static List<CalendarEvent> filterFormalEvents(
    List<CalendarEvent> events,
    int formalityThreshold,
  ) {
    return events
        .where((e) => e.formalityScore >= formalityThreshold)
        .toList();
  }

  /// Computes the next occurrence of [time] TODAY in the local timezone.
  /// Returns null if the time has already passed today.
  tz.TZDateTime? _nextInstanceOfTimeToday(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      return null; // Time has already passed today -- skip
    }
    return scheduled;
  }
}
