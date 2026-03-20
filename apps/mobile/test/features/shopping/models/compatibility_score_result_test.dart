import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/shopping/models/compatibility_score_result.dart";

void main() {
  group("CompatibilityScoreResult", () {
    test("fromJson parses all fields correctly", () {
      final json = {
        "scan": {
          "id": "scan-1",
          "scanType": "url",
          "productName": "Blue Shirt",
          "brand": "Zara",
          "price": 29.99,
          "currency": "GBP",
          "category": "tops",
          "color": "blue",
          "compatibilityScore": 75,
          "createdAt": "2026-03-19T00:00:00.000Z",
        },
        "score": {
          "total": 75,
          "breakdown": {
            "colorHarmony": 80,
            "styleConsistency": 70,
            "gapFilling": 75,
            "versatility": 65,
            "formalityMatch": 80,
          },
          "tier": "great_choice",
          "tierLabel": "Great Choice",
          "tierColor": "#3B82F6",
          "tierIcon": "thumb_up",
          "reasoning": "Good match with wardrobe."
        },
        "status": "scored",
      };

      final result = CompatibilityScoreResult.fromJson(json);

      expect(result.total, 75);
      expect(result.scan.id, "scan-1");
      expect(result.scan.productName, "Blue Shirt");
      expect(result.breakdown.colorHarmony, 80);
      expect(result.breakdown.styleConsistency, 70);
      expect(result.breakdown.gapFilling, 75);
      expect(result.breakdown.versatility, 65);
      expect(result.breakdown.formalityMatch, 80);
      expect(result.tier.tier, "great_choice");
      expect(result.tier.label, "Great Choice");
      expect(result.reasoning, "Good match with wardrobe.");
    });

    test("fromJson handles missing reasoning", () {
      final json = {
        "scan": {
          "id": "scan-1",
          "scanType": "url",
          "createdAt": "2026-03-19T00:00:00.000Z",
        },
        "score": {
          "total": 50,
          "breakdown": {
            "colorHarmony": 50,
            "styleConsistency": 50,
            "gapFilling": 50,
            "versatility": 50,
            "formalityMatch": 50,
          },
          "tier": "might_work",
          "tierLabel": "Might Work",
          "tierColor": "#F97316",
          "tierIcon": "help_outline",
        },
        "status": "scored",
      };

      final result = CompatibilityScoreResult.fromJson(json);
      expect(result.reasoning, isNull);
    });

    test("fromJson handles score of 0", () {
      final json = {
        "scan": {
          "id": "scan-1",
          "scanType": "url",
          "createdAt": "2026-03-19T00:00:00.000Z",
        },
        "score": {
          "total": 0,
          "breakdown": {
            "colorHarmony": 0,
            "styleConsistency": 0,
            "gapFilling": 0,
            "versatility": 0,
            "formalityMatch": 0,
          },
          "tier": "careful",
          "tierLabel": "Careful",
          "tierColor": "#EF4444",
          "tierIcon": "warning",
        },
        "status": "scored",
      };

      final result = CompatibilityScoreResult.fromJson(json);
      expect(result.total, 0);
      expect(result.tier.tier, "careful");
    });

    test("fromJson handles score of 100", () {
      final json = {
        "scan": {
          "id": "scan-1",
          "scanType": "url",
          "createdAt": "2026-03-19T00:00:00.000Z",
        },
        "score": {
          "total": 100,
          "breakdown": {
            "colorHarmony": 100,
            "styleConsistency": 100,
            "gapFilling": 100,
            "versatility": 100,
            "formalityMatch": 100,
          },
          "tier": "perfect_match",
          "tierLabel": "Perfect Match",
          "tierColor": "#22C55E",
          "tierIcon": "stars",
        },
        "status": "scored",
      };

      final result = CompatibilityScoreResult.fromJson(json);
      expect(result.total, 100);
      expect(result.tier.tier, "perfect_match");
    });
  });

  group("ScoreBreakdown", () {
    test("fromJson parses all 5 factor scores", () {
      final json = {
        "colorHarmony": 80,
        "styleConsistency": 70,
        "gapFilling": 60,
        "versatility": 50,
        "formalityMatch": 40,
      };

      final breakdown = ScoreBreakdown.fromJson(json);
      expect(breakdown.colorHarmony, 80);
      expect(breakdown.styleConsistency, 70);
      expect(breakdown.gapFilling, 60);
      expect(breakdown.versatility, 50);
      expect(breakdown.formalityMatch, 40);
    });
  });

  group("ScoreTier", () {
    test("fromTierString maps perfect_match correctly", () {
      final tier = ScoreTier.fromTierString("perfect_match");
      expect(tier.tier, "perfect_match");
      expect(tier.label, "Perfect Match");
      expect(tier.color, const Color(0xFF22C55E));
      expect(tier.icon, Icons.stars);
    });

    test("fromTierString maps great_choice correctly", () {
      final tier = ScoreTier.fromTierString("great_choice");
      expect(tier.tier, "great_choice");
      expect(tier.label, "Great Choice");
      expect(tier.color, const Color(0xFF3B82F6));
      expect(tier.icon, Icons.thumb_up);
    });

    test("fromTierString maps good_fit correctly", () {
      final tier = ScoreTier.fromTierString("good_fit");
      expect(tier.tier, "good_fit");
      expect(tier.label, "Good Fit");
      expect(tier.color, const Color(0xFFF59E0B));
      expect(tier.icon, Icons.check_circle);
    });

    test("fromTierString maps might_work correctly", () {
      final tier = ScoreTier.fromTierString("might_work");
      expect(tier.tier, "might_work");
      expect(tier.label, "Might Work");
      expect(tier.color, const Color(0xFFF97316));
      expect(tier.icon, Icons.help_outline);
    });

    test("fromTierString maps careful correctly", () {
      final tier = ScoreTier.fromTierString("careful");
      expect(tier.tier, "careful");
      expect(tier.label, "Careful");
      expect(tier.color, const Color(0xFFEF4444));
      expect(tier.icon, Icons.warning);
    });

    test("fromTierString defaults to careful for unknown tier", () {
      final tier = ScoreTier.fromTierString("unknown_tier");
      expect(tier.tier, "careful");
      expect(tier.label, "Careful");
    });
  });
}
