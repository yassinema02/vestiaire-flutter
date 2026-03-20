import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/notifications/morning_notification_preferences.dart";

void main() {
  group("MorningNotificationPreferences", () {
    late MorningNotificationPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      prefs = MorningNotificationPreferences(prefs: sp);
    });

    test("getMorningTime() returns default 08:00 when no value stored",
        () async {
      final time = await prefs.getMorningTime();

      expect(time.hour, 8);
      expect(time.minute, 0);
    });

    test("getMorningTime() returns stored time after setMorningTime()",
        () async {
      await prefs.setMorningTime(const TimeOfDay(hour: 7, minute: 15));

      final time = await prefs.getMorningTime();

      expect(time.hour, 7);
      expect(time.minute, 15);
    });

    test("setMorningTime() persists in HH:mm format", () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final testPrefs = MorningNotificationPreferences(prefs: sp);

      await testPrefs.setMorningTime(const TimeOfDay(hour: 6, minute: 5));

      final stored = sp.getString(MorningNotificationPreferences.kMorningTimeKey);
      expect(stored, "06:05");
    });

    test("isOutfitRemindersEnabled() returns true by default", () async {
      final enabled = await prefs.isOutfitRemindersEnabled();

      expect(enabled, isTrue);
    });

    test(
        "isOutfitRemindersEnabled() returns stored value after setOutfitRemindersEnabled()",
        () async {
      await prefs.setOutfitRemindersEnabled(false);

      final enabled = await prefs.isOutfitRemindersEnabled();

      expect(enabled, isFalse);
    });

    test("round-trip: set then get returns same value", () async {
      await prefs.setMorningTime(const TimeOfDay(hour: 22, minute: 45));
      final time = await prefs.getMorningTime();
      expect(time.hour, 22);
      expect(time.minute, 45);

      await prefs.setOutfitRemindersEnabled(false);
      final enabled = await prefs.isOutfitRemindersEnabled();
      expect(enabled, isFalse);

      await prefs.setOutfitRemindersEnabled(true);
      final enabled2 = await prefs.isOutfitRemindersEnabled();
      expect(enabled2, isTrue);
    });
  });
}
