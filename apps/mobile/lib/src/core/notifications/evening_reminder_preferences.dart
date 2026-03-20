import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Helper for persisting evening reminder preferences locally.
///
/// Stores the user's preferred evening reminder time and a local cache
/// of the wear_logging enabled state in SharedPreferences.
class EveningReminderPreferences {
  EveningReminderPreferences({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// SharedPreferences key for the evening reminder time ("HH:mm").
  static const String kEveningTimeKey = "evening_reminder_time";

  /// SharedPreferences key for the wear logging enabled state.
  static const String kWearLoggingEnabledKey = "wear_logging_enabled";

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Returns the configured evening reminder time.
  ///
  /// Defaults to 20:00 (8:00 PM) if no custom time has been set.
  Future<TimeOfDay> getEveningTime() async {
    final prefs = await _getPrefs();
    final stored = prefs.getString(kEveningTimeKey);
    if (stored == null || !stored.contains(":")) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
    final parts = stored.split(":");
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  /// Persists the evening reminder time in "HH:mm" format.
  Future<void> setEveningTime(TimeOfDay time) async {
    final prefs = await _getPrefs();
    final formatted =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    await prefs.setString(kEveningTimeKey, formatted);
  }

  /// Returns whether wear logging reminders are enabled locally.
  ///
  /// Defaults to `true` if no value has been stored.
  Future<bool> isWearLoggingEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(kWearLoggingEnabledKey) ?? true;
  }

  /// Persists the wear logging enabled state locally.
  Future<void> setWearLoggingEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(kWearLoggingEnabledKey, enabled);
  }
}
