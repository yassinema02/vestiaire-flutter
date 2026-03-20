import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/notifications/posting_reminder_preferences.dart";

void main() {
  group("PostingReminderPreferences", () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test("getPostingReminderTime returns default 09:00 when no value stored",
        () async {
      final prefs = PostingReminderPreferences();
      final time = await prefs.getPostingReminderTime();

      expect(time.hour, 9);
      expect(time.minute, 0);
    });

    test("getPostingReminderTime returns stored time after set", () async {
      final prefs = PostingReminderPreferences();

      await prefs.setPostingReminderTime(const TimeOfDay(hour: 10, minute: 30));
      final time = await prefs.getPostingReminderTime();

      expect(time.hour, 10);
      expect(time.minute, 30);
    });

    test("setPostingReminderTime persists in HH:mm format", () async {
      final prefs = PostingReminderPreferences();

      await prefs.setPostingReminderTime(const TimeOfDay(hour: 7, minute: 5));

      final sp = await SharedPreferences.getInstance();
      final stored = sp.getString(PostingReminderPreferences.kPostingReminderTimeKey);
      expect(stored, "07:05");
    });

    test("isPostingReminderEnabled returns true by default", () async {
      final prefs = PostingReminderPreferences();
      final enabled = await prefs.isPostingReminderEnabled();

      expect(enabled, isTrue);
    });

    test("isPostingReminderEnabled returns stored value after set", () async {
      final prefs = PostingReminderPreferences();

      await prefs.setPostingReminderEnabled(false);
      final enabled = await prefs.isPostingReminderEnabled();

      expect(enabled, isFalse);
    });

    test("round-trip: set then get returns same value for time", () async {
      final prefs = PostingReminderPreferences();
      const original = TimeOfDay(hour: 14, minute: 45);

      await prefs.setPostingReminderTime(original);
      final retrieved = await prefs.getPostingReminderTime();

      expect(retrieved.hour, original.hour);
      expect(retrieved.minute, original.minute);
    });

    test("round-trip: set then get returns same value for enabled", () async {
      final prefs = PostingReminderPreferences();

      await prefs.setPostingReminderEnabled(true);
      expect(await prefs.isPostingReminderEnabled(), isTrue);

      await prefs.setPostingReminderEnabled(false);
      expect(await prefs.isPostingReminderEnabled(), isFalse);
    });
  });
}
