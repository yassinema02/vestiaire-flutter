import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/outfits/models/usage_info.dart";

void main() {
  group("UsageInfo", () {
    test("fromJson correctly parses all fields for free user", () {
      final json = {
        "dailyLimit": 3,
        "used": 1,
        "remaining": 2,
        "resetsAt": "2026-03-16T00:00:00.000Z",
        "isPremium": false,
      };

      final info = UsageInfo.fromJson(json);

      expect(info.dailyLimit, 3);
      expect(info.used, 1);
      expect(info.remaining, 2);
      expect(info.resetsAt, "2026-03-16T00:00:00.000Z");
      expect(info.isPremium, false);
    });

    test("fromJson correctly parses all fields for premium user", () {
      final json = {
        "dailyLimit": null,
        "used": 5,
        "remaining": null,
        "resetsAt": null,
        "isPremium": true,
      };

      final info = UsageInfo.fromJson(json);

      expect(info.dailyLimit, isNull);
      expect(info.used, 5);
      expect(info.remaining, isNull);
      expect(info.resetsAt, isNull);
      expect(info.isPremium, true);
    });

    test("isLimitReached returns true when remaining is 0 and not premium", () {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        resetsAt: "2026-03-16T00:00:00.000Z",
        isPremium: false,
      );

      expect(info.isLimitReached, true);
    });

    test("isLimitReached returns false when remaining > 0", () {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 1,
        remaining: 2,
        resetsAt: "2026-03-16T00:00:00.000Z",
        isPremium: false,
      );

      expect(info.isLimitReached, false);
    });

    test("isLimitReached returns false when user is premium", () {
      const info = UsageInfo(
        dailyLimit: null,
        used: 10,
        remaining: null,
        resetsAt: null,
        isPremium: true,
      );

      expect(info.isLimitReached, false);
    });

    test("remainingText returns correct text for various remaining values", () {
      const info2 = UsageInfo(
        dailyLimit: 3,
        used: 1,
        remaining: 2,
        isPremium: false,
      );
      expect(info2.remainingText, "2 of 3 generations remaining today");

      const info1 = UsageInfo(
        dailyLimit: 3,
        used: 2,
        remaining: 1,
        isPremium: false,
      );
      expect(info1.remainingText, "1 of 3 generations remaining today");
    });

    test("remainingText returns empty string for premium users", () {
      const info = UsageInfo(
        dailyLimit: null,
        used: 5,
        remaining: null,
        isPremium: true,
      );

      expect(info.remainingText, "");
    });

    test("remainingText returns 'Daily limit reached' when remaining is 0", () {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        resetsAt: "2026-03-16T00:00:00.000Z",
        isPremium: false,
      );

      expect(info.remainingText, "Daily limit reached");
    });

    test("toJson serializes all fields correctly", () {
      const info = UsageInfo(
        dailyLimit: 3,
        used: 1,
        remaining: 2,
        resetsAt: "2026-03-16T00:00:00.000Z",
        isPremium: false,
      );

      final json = info.toJson();

      expect(json["dailyLimit"], 3);
      expect(json["used"], 1);
      expect(json["remaining"], 2);
      expect(json["resetsAt"], "2026-03-16T00:00:00.000Z");
      expect(json["isPremium"], false);
    });
  });
}
