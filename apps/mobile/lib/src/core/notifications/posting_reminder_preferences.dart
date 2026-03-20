import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Helper for persisting posting reminder preferences locally.
///
/// Stores the user's preferred posting reminder time and enabled state
/// in SharedPreferences. Follows the same pattern as
/// [MorningNotificationPreferences] and [EveningReminderPreferences].
///
/// Story 9.6: Social Notification Preferences (FR-NTF-04)
class PostingReminderPreferences {
  PostingReminderPreferences({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// SharedPreferences key for the posting reminder time ("HH:mm").
  static const String kPostingReminderTimeKey = "posting_reminder_time";

  /// SharedPreferences key for the posting reminder enabled state.
  static const String kPostingReminderEnabledKey = "posting_reminder_enabled";

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Returns the configured posting reminder time.
  ///
  /// Defaults to 09:00 if no custom time has been set.
  Future<TimeOfDay> getPostingReminderTime() async {
    final prefs = await _getPrefs();
    final stored = prefs.getString(kPostingReminderTimeKey);
    if (stored == null || !stored.contains(":")) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final parts = stored.split(":");
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  /// Persists the posting reminder time in "HH:mm" format.
  Future<void> setPostingReminderTime(TimeOfDay time) async {
    final prefs = await _getPrefs();
    final formatted =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    await prefs.setString(kPostingReminderTimeKey, formatted);
  }

  /// Returns whether the posting reminder is enabled locally.
  ///
  /// Defaults to `true` if no value has been stored.
  Future<bool> isPostingReminderEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(kPostingReminderEnabledKey) ?? true;
  }

  /// Persists the posting reminder enabled state locally.
  Future<void> setPostingReminderEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(kPostingReminderEnabledKey, enabled);
  }
}
