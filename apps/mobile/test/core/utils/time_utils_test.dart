import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/utils/time_utils.dart";

void main() {
  final now = DateTime(2026, 3, 19, 12, 0, 0);

  group("formatRelativeTime", () {
    test("returns empty string for null", () {
      expect(formatRelativeTime(null, now: now), equals(""));
    });

    test("returns 'Just now' for < 1 minute ago", () {
      final time = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(time, now: now), equals("Just now"));
    });

    test("returns 'Xm ago' for < 1 hour ago", () {
      final time = now.subtract(const Duration(minutes: 15));
      expect(formatRelativeTime(time, now: now), equals("15m ago"));
    });

    test("returns 'Xh ago' for < 24 hours ago", () {
      final time = now.subtract(const Duration(hours: 5));
      expect(formatRelativeTime(time, now: now), equals("5h ago"));
    });

    test("returns 'Yesterday' for 24-48 hours ago", () {
      final time = now.subtract(const Duration(hours: 30));
      expect(formatRelativeTime(time, now: now), equals("Yesterday"));
    });

    test("returns date string for older", () {
      final time = DateTime(2026, 3, 10);
      expect(formatRelativeTime(time, now: now), equals("Mar 10"));
    });

    test("returns 'Just now' for future dates", () {
      final time = now.add(const Duration(hours: 1));
      expect(formatRelativeTime(time, now: now), equals("Just now"));
    });
  });
}
