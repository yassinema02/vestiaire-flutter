import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/notifications/event_reminder_preferences.dart";

void main() {
  group("EventReminderPreferences", () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test("getEventReminderTime returns default 20:00 when no value stored",
        () async {
      final prefs = EventReminderPreferences();
      final time = await prefs.getEventReminderTime();

      expect(time.hour, 20);
      expect(time.minute, 0);
    });

    test("getEventReminderTime returns stored time after setEventReminderTime",
        () async {
      final prefs = EventReminderPreferences();

      await prefs.setEventReminderTime(const TimeOfDay(hour: 19, minute: 30));
      final time = await prefs.getEventReminderTime();

      expect(time.hour, 19);
      expect(time.minute, 30);
    });

    test("setEventReminderTime persists in HH:mm format", () async {
      final prefs = EventReminderPreferences();

      await prefs.setEventReminderTime(const TimeOfDay(hour: 7, minute: 5));

      final sp = await SharedPreferences.getInstance();
      final stored =
          sp.getString(EventReminderPreferences.kEventReminderTimeKey);
      expect(stored, "07:05");
    });

    test("getFormalityThreshold returns default 7 when no value stored",
        () async {
      final prefs = EventReminderPreferences();
      final threshold = await prefs.getFormalityThreshold();

      expect(threshold, 7);
    });

    test("getFormalityThreshold returns stored value after setFormalityThreshold",
        () async {
      final prefs = EventReminderPreferences();

      await prefs.setFormalityThreshold(9);
      final threshold = await prefs.getFormalityThreshold();

      expect(threshold, 9);
    });

    test("setFormalityThreshold clamps to range 6-10", () async {
      final prefs = EventReminderPreferences();

      await prefs.setFormalityThreshold(3);
      expect(await prefs.getFormalityThreshold(), 6);

      await prefs.setFormalityThreshold(15);
      expect(await prefs.getFormalityThreshold(), 10);

      await prefs.setFormalityThreshold(8);
      expect(await prefs.getFormalityThreshold(), 8);
    });

    test("isEventRemindersEnabled returns true by default", () async {
      final prefs = EventReminderPreferences();
      final enabled = await prefs.isEventRemindersEnabled();

      expect(enabled, isTrue);
    });

    test("isEventRemindersEnabled returns stored value after set", () async {
      final prefs = EventReminderPreferences();

      await prefs.setEventRemindersEnabled(false);
      final enabled = await prefs.isEventRemindersEnabled();

      expect(enabled, isFalse);
    });

    test("round-trip: set then get returns same value for time", () async {
      final prefs = EventReminderPreferences();
      const original = TimeOfDay(hour: 21, minute: 45);

      await prefs.setEventReminderTime(original);
      final retrieved = await prefs.getEventReminderTime();

      expect(retrieved.hour, original.hour);
      expect(retrieved.minute, original.minute);
    });

    test("round-trip: set then get returns same value for threshold", () async {
      final prefs = EventReminderPreferences();

      await prefs.setFormalityThreshold(8);
      expect(await prefs.getFormalityThreshold(), 8);

      await prefs.setFormalityThreshold(10);
      expect(await prefs.getFormalityThreshold(), 10);
    });

    test("round-trip: set then get returns same value for enabled", () async {
      final prefs = EventReminderPreferences();

      await prefs.setEventRemindersEnabled(true);
      expect(await prefs.isEventRemindersEnabled(), isTrue);

      await prefs.setEventRemindersEnabled(false);
      expect(await prefs.isEventRemindersEnabled(), isFalse);
    });
  });
}
