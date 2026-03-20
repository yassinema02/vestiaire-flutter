import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Helper for persisting event reminder preferences locally.
///
/// Stores the user's preferred event reminder time, formality threshold,
/// and enabled state in SharedPreferences. Follows the same pattern as
/// [MorningNotificationPreferences] and [PostingReminderPreferences].
///
/// Story 12.3: Formal Event Reminders (FR-EVT-08)
class EventReminderPreferences {
  EventReminderPreferences({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// SharedPreferences key for the event reminder time ("HH:mm").
  static const String kEventReminderTimeKey = "event_reminder_time";

  /// SharedPreferences key for the formality threshold (int 6-10).
  static const String kFormalityThresholdKey =
      "event_reminder_formality_threshold";

  /// SharedPreferences key for the event reminders enabled state.
  static const String kEventRemindersEnabledKey = "event_reminders_enabled";

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Returns the configured event reminder time.
  ///
  /// Defaults to 20:00 (8:00 PM) if no custom time has been set.
  Future<TimeOfDay> getEventReminderTime() async {
    final prefs = await _getPrefs();
    final stored = prefs.getString(kEventReminderTimeKey);
    if (stored == null || !stored.contains(":")) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
    final parts = stored.split(":");
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  /// Persists the event reminder time in "HH:mm" format.
  Future<void> setEventReminderTime(TimeOfDay time) async {
    final prefs = await _getPrefs();
    final formatted =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    await prefs.setString(kEventReminderTimeKey, formatted);
  }

  /// Returns the configured formality threshold.
  ///
  /// Defaults to 7 if no value has been stored.
  Future<int> getFormalityThreshold() async {
    final prefs = await _getPrefs();
    return prefs.getInt(kFormalityThresholdKey) ?? 7;
  }

  /// Persists the formality threshold. Clamps to range 6-10.
  Future<void> setFormalityThreshold(int threshold) async {
    final prefs = await _getPrefs();
    final clamped = threshold.clamp(6, 10);
    await prefs.setInt(kFormalityThresholdKey, clamped);
  }

  /// Returns whether event reminders are enabled locally.
  ///
  /// Defaults to `true` if no value has been stored.
  Future<bool> isEventRemindersEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(kEventRemindersEnabledKey) ?? true;
  }

  /// Persists the event reminders enabled state locally.
  Future<void> setEventRemindersEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(kEventRemindersEnabledKey, enabled);
  }
}
