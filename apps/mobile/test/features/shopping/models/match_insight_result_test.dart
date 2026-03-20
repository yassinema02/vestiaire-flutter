import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/shopping/models/match_insight_result.dart";

void main() {
  group("MatchInsightResult", () {
    test("fromJson parses all fields correctly", () {
      final json = {
        "scan": {
          "id": "scan-1",
          "scanType": "url",
          "productName": "Blue Shirt",
          "brand": "Zara",
          "compatibilityScore": 75,
          "createdAt": "2026-03-19T00:00:00.000Z",
        },
        "matches": [
          {
            "itemId": "item-1",
            "itemName": "Navy Blazer",
            "itemImageUrl": "https://example.com/blazer.jpg",
            "category": "outerwear",
            "matchReasons": ["Complementary colors"],
          },
          {
            "itemId": "item-2",
            "itemName": "Black Jeans",
            "itemImageUrl": "https://example.com/jeans.jpg",
            "category": "bottoms",
            "matchReasons": ["Style match"],
          },
        ],
        "insights": [
          {
            "type": "style_feedback",
            "title": "Consistent Style",
            "body": "Fits your wardrobe well.",
          },
          {
            "type": "gap_assessment",
            "title": "Fills a Gap",
            "body": "New color for your collection.",
          },
          {
            "type": "value_proposition",
            "title": "Good Value",
            "body": "Versatile and affordable.",
          },
        ],
      };

      final result = MatchInsightResult.fromJson(json);

      expect(result.scan.id, "scan-1");
      expect(result.scan.productName, "Blue Shirt");
      expect(result.matches.length, 2);
      expect(result.insights.length, 3);
      expect(result.matches[0].itemId, "item-1");
      expect(result.matches[0].itemName, "Navy Blazer");
      expect(result.matches[1].category, "bottoms");
      expect(result.insights[0].type, "style_feedback");
      expect(result.insights[1].type, "gap_assessment");
      expect(result.insights[2].type, "value_proposition");
    });
  });

  group("WardrobeMatch", () {
    test("fromJson parses item fields and match reasons", () {
      final json = {
        "itemId": "item-1",
        "itemName": "Navy Blazer",
        "itemImageUrl": "https://example.com/blazer.jpg",
        "category": "outerwear",
        "matchReasons": ["Color coordination", "Style match"],
      };

      final match = WardrobeMatch.fromJson(json);

      expect(match.itemId, "item-1");
      expect(match.itemName, "Navy Blazer");
      expect(match.itemImageUrl, "https://example.com/blazer.jpg");
      expect(match.category, "outerwear");
      expect(match.matchReasons, ["Color coordination", "Style match"]);
    });

    test("fromJson handles missing matchReasons", () {
      final json = {
        "itemId": "item-2",
        "itemName": "Test",
      };

      final match = WardrobeMatch.fromJson(json);

      expect(match.matchReasons, isEmpty);
    });
  });

  group("ShoppingInsight", () {
    test("fromJson maps style_feedback to Icons.palette", () {
      final json = {
        "type": "style_feedback",
        "title": "Style Title",
        "body": "Style body",
      };

      final insight = ShoppingInsight.fromJson(json);

      expect(insight.type, "style_feedback");
      expect(insight.title, "Style Title");
      expect(insight.body, "Style body");
      expect(insight.icon, Icons.palette);
    });

    test("fromJson maps gap_assessment to Icons.space_dashboard", () {
      final json = {
        "type": "gap_assessment",
        "title": "Gap Title",
        "body": "Gap body",
      };

      final insight = ShoppingInsight.fromJson(json);

      expect(insight.icon, Icons.space_dashboard);
    });

    test("fromJson maps value_proposition to Icons.trending_up", () {
      final json = {
        "type": "value_proposition",
        "title": "Value Title",
        "body": "Value body",
      };

      final insight = ShoppingInsight.fromJson(json);

      expect(insight.icon, Icons.trending_up);
    });

    test("handles edge case: empty matches array", () {
      final json = {
        "scan": {
          "id": "scan-1",
          "scanType": "url",
          "createdAt": "2026-03-19T00:00:00.000Z",
        },
        "matches": <dynamic>[],
        "insights": [
          {"type": "style_feedback", "title": "T", "body": "B"},
          {"type": "gap_assessment", "title": "T", "body": "B"},
          {"type": "value_proposition", "title": "T", "body": "B"},
        ],
      };

      final result = MatchInsightResult.fromJson(json);

      expect(result.matches, isEmpty);
      expect(result.insights.length, 3);
    });

    test("handles edge case: missing insight body defaults to empty string", () {
      final json = {
        "type": "style_feedback",
        "title": "Title Only",
      };

      final insight = ShoppingInsight.fromJson(json);

      expect(insight.body, "");
    });
  });
}
