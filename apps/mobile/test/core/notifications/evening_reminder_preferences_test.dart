import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/notifications/evening_reminder_preferences.dart";

void main() {
  group("EveningReminderPreferences", () {
    late EveningReminderPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      prefs = EveningReminderPreferences(prefs: sp);
    });

    test("getEveningTime() returns default 20:00 when no value stored",
        () async {
      final time = await prefs.getEveningTime();

      expect(time.hour, 20);
      expect(time.minute, 0);
    });

    test("getEveningTime() returns stored time after setEveningTime()",
        () async {
      await prefs.setEveningTime(const TimeOfDay(hour: 19, minute: 30));

      final time = await prefs.getEveningTime();

      expect(time.hour, 19);
      expect(time.minute, 30);
    });

    test("setEveningTime() persists in HH:mm format", () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final testPrefs = EveningReminderPreferences(prefs: sp);

      await testPrefs.setEveningTime(const TimeOfDay(hour: 21, minute: 5));

      final stored =
          sp.getString(EveningReminderPreferences.kEveningTimeKey);
      expect(stored, "21:05");
    });

    test("isWearLoggingEnabled() returns true by default", () async {
      final enabled = await prefs.isWearLoggingEnabled();

      expect(enabled, isTrue);
    });

    test(
        "isWearLoggingEnabled() returns stored value after setWearLoggingEnabled()",
        () async {
      await prefs.setWearLoggingEnabled(false);

      final enabled = await prefs.isWearLoggingEnabled();

      expect(enabled, isFalse);
    });

    test("round-trip: set then get returns same value", () async {
      await prefs.setEveningTime(const TimeOfDay(hour: 22, minute: 45));
      final time = await prefs.getEveningTime();
      expect(time.hour, 22);
      expect(time.minute, 45);

      await prefs.setWearLoggingEnabled(false);
      final enabled = await prefs.isWearLoggingEnabled();
      expect(enabled, isFalse);

      await prefs.setWearLoggingEnabled(true);
      final enabled2 = await prefs.isWearLoggingEnabled();
      expect(enabled2, isTrue);
    });
  });
}
