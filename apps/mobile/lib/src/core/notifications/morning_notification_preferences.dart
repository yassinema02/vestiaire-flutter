import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Helper for persisting morning notification preferences locally.
///
/// Stores the user's preferred morning notification time and a local cache
/// of the outfit_reminders enabled state in SharedPreferences.
class MorningNotificationPreferences {
  MorningNotificationPreferences({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// SharedPreferences key for the morning notification time ("HH:mm").
  static const String kMorningTimeKey = "morning_notification_time";

  /// SharedPreferences key for the outfit reminders enabled state.
  static const String kOutfitRemindersEnabledKey = "outfit_reminders_enabled";

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Returns the configured morning notification time.
  ///
  /// Defaults to 08:00 if no custom time has been set.
  Future<TimeOfDay> getMorningTime() async {
    final prefs = await _getPrefs();
    final stored = prefs.getString(kMorningTimeKey);
    if (stored == null || !stored.contains(":")) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    final parts = stored.split(":");
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  /// Persists the morning notification time in "HH:mm" format.
  Future<void> setMorningTime(TimeOfDay time) async {
    final prefs = await _getPrefs();
    final formatted =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    await prefs.setString(kMorningTimeKey, formatted);
  }

  /// Returns whether outfit reminders are enabled locally.
  ///
  /// Defaults to `true` if no value has been stored.
  Future<bool> isOutfitRemindersEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(kOutfitRemindersEnabledKey) ?? true;
  }

  /// Persists the outfit reminders enabled state locally.
  Future<void> setOutfitRemindersEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(kOutfitRemindersEnabledKey, enabled);
  }
}
