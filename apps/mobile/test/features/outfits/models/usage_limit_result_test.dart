import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/outfits/models/usage_limit_result.dart";

void main() {
  group("UsageLimitReachedResult", () {
    test("fromJson correctly parses all fields", () {
      final json = {
        "dailyLimit": 3,
        "used": 3,
        "remaining": 0,
        "resetsAt": "2026-03-16T00:00:00.000Z",
      };

      final result = UsageLimitReachedResult.fromJson(json);

      expect(result.dailyLimit, 3);
      expect(result.used, 3);
      expect(result.remaining, 0);
      expect(result.resetsAt, "2026-03-16T00:00:00.000Z");
    });

    test("round-trip serialization", () {
      const original = UsageLimitReachedResult(
        dailyLimit: 3,
        used: 3,
        remaining: 0,
        resetsAt: "2026-03-16T00:00:00.000Z",
      );

      final json = original.toJson();
      final restored = UsageLimitReachedResult.fromJson(json);

      expect(restored.dailyLimit, original.dailyLimit);
      expect(restored.used, original.used);
      expect(restored.remaining, original.remaining);
      expect(restored.resetsAt, original.resetsAt);
    });
  });
}
