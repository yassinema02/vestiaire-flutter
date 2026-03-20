import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

/// Service for persisting calendar-related user preferences.
///
/// Stores selected calendar IDs, dismissal state, and connection state
/// using SharedPreferences. Accepts optional [SharedPreferences] for
/// test injection.
class CalendarPreferencesService {
  CalendarPreferencesService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const String _keySelectedIds = "calendar_selected_ids";
  static const String _keyDismissed = "calendar_prompt_dismissed";
  static const String _keyConnected = "calendar_connected";

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Stores the selected calendar IDs as a JSON-encoded string list.
  Future<void> saveSelectedCalendarIds(List<String> calendarIds) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keySelectedIds, jsonEncode(calendarIds));
  }

  /// Reads and decodes the stored calendar IDs.
  ///
  /// Returns `null` if no selection has been saved (first-time user).
  /// Story 3.5 should treat null as "all calendars" on first sync.
  Future<List<String>?> getSelectedCalendarIds() async {
    final prefs = await _getPrefs();
    final stored = prefs.getString(_keySelectedIds);
    if (stored == null) return null;
    return List<String>.from(jsonDecode(stored) as List);
  }

  /// Stores whether the user tapped "Not Now" on the calendar prompt.
  Future<void> setCalendarDismissed(bool dismissed) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDismissed, dismissed);
  }

  /// Reads the dismissed flag. Returns `false` if not set.
  Future<bool> isCalendarDismissed() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyDismissed) ?? false;
  }

  /// Stores whether the user has successfully granted calendar permission.
  Future<void> setCalendarConnected(bool connected) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyConnected, connected);
  }

  /// Reads the connected flag. Returns `false` if not set.
  Future<bool> isCalendarConnected() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyConnected) ?? false;
  }

  /// Removes all calendar-related keys.
  ///
  /// Supports account deletion/sign-out cleanup.
  Future<void> clearCalendarPreferences() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keySelectedIds);
    await prefs.remove(_keyDismissed);
    await prefs.remove(_keyConnected);
  }
}
