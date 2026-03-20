import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/squads/models/steal_look_result.dart";

void main() {
  group("StealLookResult.fromJson", () {
    test("parses all fields correctly", () {
      final json = {
        "sourceMatches": [
          {
            "sourceItem": {
              "id": "item-a",
              "name": "Blue Top",
              "category": "tops",
              "color": "blue",
              "photoUrl": "https://example.com/blue.jpg",
            },
            "matches": [
              {
                "itemId": "w1",
                "name": "Navy Blouse",
                "category": "tops",
                "color": "navy",
                "photoUrl": "https://example.com/navy.jpg",
                "matchScore": 85,
                "matchReason": "Similar navy top",
              }
            ],
          }
        ],
      };

      final result = StealLookResult.fromJson(json);

      expect(result.sourceMatches.length, 1);
      expect(result.sourceMatches[0].sourceItem.id, "item-a");
      expect(result.sourceMatches[0].sourceItem.name, "Blue Top");
      expect(result.sourceMatches[0].matches.length, 1);
      expect(result.sourceMatches[0].matches[0].itemId, "w1");
      expect(result.sourceMatches[0].matches[0].matchScore, 85);
      expect(result.sourceMatches[0].matches[0].matchReason, "Similar navy top");
    });
  });

  group("StealLookMatch.fromJson", () {
    test("parses matchScore, matchReason, and item fields", () {
      final json = {
        "itemId": "w1",
        "name": "Navy Blouse",
        "category": "tops",
        "color": "navy",
        "photoUrl": "https://example.com/navy.jpg",
        "matchScore": 72,
        "matchReason": "Good match for casual style",
      };

      final match = StealLookMatch.fromJson(json);

      expect(match.itemId, "w1");
      expect(match.name, "Navy Blouse");
      expect(match.category, "tops");
      expect(match.color, "navy");
      expect(match.photoUrl, "https://example.com/navy.jpg");
      expect(match.matchScore, 72);
      expect(match.matchReason, "Good match for casual style");
    });
  });

  group("StealLookMatch.tier", () {
    test("returns Excellent for score 85", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 85);
      expect(match.tier, MatchTier.excellent);
    });

    test("returns Good for score 65", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 65);
      expect(match.tier, MatchTier.good);
    });

    test("returns Partial for score 40", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 40);
      expect(match.tier, MatchTier.partial);
    });

    test("returns Excellent for score 80 (boundary)", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 80);
      expect(match.tier, MatchTier.excellent);
    });

    test("returns Good for score 60 (boundary)", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 60);
      expect(match.tier, MatchTier.good);
    });

    test("returns Partial for score 30 (boundary)", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 30);
      expect(match.tier, MatchTier.partial);
    });

    test("returns Excellent for score 100", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 100);
      expect(match.tier, MatchTier.excellent);
    });

    test("returns Partial for score 0", () {
      final match = StealLookMatch(itemId: "w1", matchScore: 0);
      expect(match.tier, MatchTier.partial);
    });
  });

  group("MatchTier", () {
    test("excellent has correct color (#22C55E) and label", () {
      expect(MatchTier.excellent.color, const Color(0xFF22C55E));
      expect(MatchTier.excellent.label, "Excellent Match");
    });

    test("good has correct color (#3B82F6) and label", () {
      expect(MatchTier.good.color, const Color(0xFF3B82F6));
      expect(MatchTier.good.label, "Good Match");
    });

    test("partial has correct color (#F59E0B) and label", () {
      expect(MatchTier.partial.color, const Color(0xFFF59E0B));
      expect(MatchTier.partial.label, "Partial Match");
    });
  });

  group("StealLookSourceMatch.fromJson", () {
    test("handles empty matches array", () {
      final json = {
        "sourceItem": {
          "id": "item-a",
          "name": "Blue Top",
        },
        "matches": [],
      };

      final sourceMatch = StealLookSourceMatch.fromJson(json);
      expect(sourceMatch.matches.isEmpty, true);
      expect(sourceMatch.sourceItem.id, "item-a");
    });

    test("handles missing matches key", () {
      final json = {
        "sourceItem": {
          "id": "item-a",
        },
      };

      final sourceMatch = StealLookSourceMatch.fromJson(json);
      expect(sourceMatch.matches.isEmpty, true);
    });
  });

  group("Edge cases", () {
    test("handles null matchReason", () {
      final match = StealLookMatch.fromJson({
        "itemId": "w1",
        "matchScore": 50,
      });

      expect(match.matchReason, isNull);
    });

    test("handles null name and photoUrl", () {
      final match = StealLookMatch.fromJson({
        "itemId": "w1",
        "matchScore": 70,
      });

      expect(match.name, isNull);
      expect(match.photoUrl, isNull);
    });

    test("handles matchScore of 0", () {
      final match = StealLookMatch.fromJson({
        "itemId": "w1",
        "matchScore": 0,
      });

      expect(match.matchScore, 0);
      expect(match.tier, MatchTier.partial);
    });

    test("handles missing matchScore (defaults to 0)", () {
      final match = StealLookMatch.fromJson({
        "itemId": "w1",
      });

      expect(match.matchScore, 0);
    });

    test("StealLookSourceItem.fromJson handles null fields", () {
      final item = StealLookSourceItem.fromJson({
        "id": "x",
      });

      expect(item.id, "x");
      expect(item.name, isNull);
      expect(item.category, isNull);
      expect(item.color, isNull);
      expect(item.photoUrl, isNull);
    });
  });
}
