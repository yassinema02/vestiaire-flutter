import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/subscription/premium_state.dart";

void main() {
  group("PremiumState", () {
    test("stores and exposes isPremium field", () {
      const state = PremiumState(isPremium: true);
      expect(state.isPremium, isTrue);
    });

    test("stores and exposes premiumSource field", () {
      const state = PremiumState(
        isPremium: true,
        premiumSource: "revenuecat",
      );
      expect(state.premiumSource, equals("revenuecat"));
    });

    test("stores and exposes premiumExpiresAt field", () {
      final expiresAt = DateTime(2026, 12, 31);
      final state = PremiumState(
        isPremium: true,
        premiumExpiresAt: expiresAt,
      );
      expect(state.premiumExpiresAt, equals(expiresAt));
    });

    test("premiumSource defaults to null", () {
      const state = PremiumState(isPremium: false);
      expect(state.premiumSource, isNull);
    });

    test("premiumExpiresAt defaults to null", () {
      const state = PremiumState(isPremium: false);
      expect(state.premiumExpiresAt, isNull);
    });

    test("stores all fields together", () {
      final expiresAt = DateTime(2026, 6, 15);
      final state = PremiumState(
        isPremium: true,
        premiumSource: "trial",
        premiumExpiresAt: expiresAt,
      );
      expect(state.isPremium, isTrue);
      expect(state.premiumSource, equals("trial"));
      expect(state.premiumExpiresAt, equals(expiresAt));
    });
  });
}
