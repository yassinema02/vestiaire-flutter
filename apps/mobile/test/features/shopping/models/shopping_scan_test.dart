import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/shopping/models/shopping_scan.dart";

void main() {
  group("ShoppingScan", () {
    test("fromJson parses all fields correctly", () {
      final json = {
        "id": "scan-1",
        "url": "https://www.zara.com/shirt",
        "scanType": "url",
        "productName": "Blue Cotton Shirt",
        "brand": "Zara",
        "price": 29.99,
        "currency": "GBP",
        "imageUrl": "https://example.com/shirt.jpg",
        "category": "tops",
        "color": "blue",
        "secondaryColors": ["white", "navy"],
        "pattern": "solid",
        "material": "cotton",
        "style": "casual",
        "season": ["spring", "summer"],
        "occasion": ["everyday", "work"],
        "formalityScore": 3,
        "extractionMethod": "og_tags+json_ld",
        "compatibilityScore": 85,
        "wishlisted": true,
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final scan = ShoppingScan.fromJson(json);

      expect(scan.id, "scan-1");
      expect(scan.url, "https://www.zara.com/shirt");
      expect(scan.scanType, "url");
      expect(scan.productName, "Blue Cotton Shirt");
      expect(scan.brand, "Zara");
      expect(scan.price, 29.99);
      expect(scan.currency, "GBP");
      expect(scan.imageUrl, "https://example.com/shirt.jpg");
      expect(scan.category, "tops");
      expect(scan.color, "blue");
      expect(scan.secondaryColors, ["white", "navy"]);
      expect(scan.pattern, "solid");
      expect(scan.material, "cotton");
      expect(scan.style, "casual");
      expect(scan.season, ["spring", "summer"]);
      expect(scan.occasion, ["everyday", "work"]);
      expect(scan.formalityScore, 3);
      expect(scan.extractionMethod, "og_tags+json_ld");
      expect(scan.compatibilityScore, 85);
      expect(scan.wishlisted, true);
      expect(scan.createdAt, DateTime.parse("2026-03-19T10:00:00.000Z"));
    });

    test("fromJson handles null optional fields", () {
      final json = {
        "id": "scan-2",
        "scanType": "url",
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final scan = ShoppingScan.fromJson(json);

      expect(scan.id, "scan-2");
      expect(scan.url, isNull);
      expect(scan.productName, isNull);
      expect(scan.brand, isNull);
      expect(scan.price, isNull);
      expect(scan.currency, isNull);
      expect(scan.imageUrl, isNull);
      expect(scan.category, isNull);
      expect(scan.color, isNull);
      expect(scan.secondaryColors, isNull);
      expect(scan.pattern, isNull);
      expect(scan.material, isNull);
      expect(scan.style, isNull);
      expect(scan.season, isNull);
      expect(scan.occasion, isNull);
      expect(scan.formalityScore, isNull);
      expect(scan.extractionMethod, isNull);
      expect(scan.compatibilityScore, isNull);
      expect(scan.wishlisted, false);
    });

    test("fromJson parses list fields (secondaryColors, season, occasion)", () {
      final json = {
        "id": "scan-3",
        "scanType": "url",
        "secondaryColors": ["red", "green"],
        "season": ["fall", "winter"],
        "occasion": ["formal", "party"],
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final scan = ShoppingScan.fromJson(json);

      expect(scan.secondaryColors, isA<List<String>>());
      expect(scan.secondaryColors, ["red", "green"]);
      expect(scan.season, isA<List<String>>());
      expect(scan.season, ["fall", "winter"]);
      expect(scan.occasion, isA<List<String>>());
      expect(scan.occasion, ["formal", "party"]);
    });

    test("displayName returns productName when available", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-4",
        "scanType": "url",
        "productName": "Cool Jacket",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.displayName, "Cool Jacket");
    });

    test("displayName returns 'Unknown Product' when productName is null", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-5",
        "scanType": "url",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.displayName, "Unknown Product");
    });

    test("displayPrice formats price with currency", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-6",
        "scanType": "url",
        "price": 49.99,
        "currency": "EUR",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.displayPrice, "EUR 49.99");
    });

    test("displayPrice returns empty string when price is null", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-7",
        "scanType": "url",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.displayPrice, "");
    });

    test("displayPrice uses GBP default when currency is null", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-8",
        "scanType": "url",
        "price": 30.00,
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.displayPrice, "GBP 30.00");
    });

    test("hasImage returns true when imageUrl is present", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-9",
        "scanType": "url",
        "imageUrl": "https://example.com/img.jpg",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.hasImage, true);
    });

    test("hasImage returns false when imageUrl is null", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-10",
        "scanType": "url",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.hasImage, false);
    });

    test("hasImage returns false when imageUrl is empty", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-11",
        "scanType": "url",
        "imageUrl": "",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      expect(scan.hasImage, false);
    });

    // === Story 8.3: toJson and copyWith tests ===

    test("toJson serializes all editable fields correctly", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-12",
        "scanType": "url",
        "productName": "Test Product",
        "brand": "Test Brand",
        "price": 49.99,
        "currency": "EUR",
        "category": "tops",
        "color": "blue",
        "secondaryColors": ["white"],
        "pattern": "solid",
        "material": "cotton",
        "style": "casual",
        "season": ["spring"],
        "occasion": ["everyday"],
        "formalityScore": 5,
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      final json = scan.toJson();

      expect(json["productName"], "Test Product");
      expect(json["brand"], "Test Brand");
      expect(json["price"], 49.99);
      expect(json["currency"], "EUR");
      expect(json["category"], "tops");
      expect(json["color"], "blue");
      expect(json["secondaryColors"], ["white"]);
      expect(json["pattern"], "solid");
      expect(json["material"], "cotton");
      expect(json["style"], "casual");
      expect(json["season"], ["spring"]);
      expect(json["occasion"], ["everyday"]);
      expect(json["formalityScore"], 5);
    });

    test("toJson skips null fields", () {
      final scan = ShoppingScan.fromJson({
        "id": "scan-13",
        "scanType": "url",
        "productName": "Only Name",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      final json = scan.toJson();

      expect(json["productName"], "Only Name");
      expect(json.containsKey("brand"), false);
      expect(json.containsKey("price"), false);
      expect(json.containsKey("category"), false);
      expect(json.containsKey("color"), false);
      expect(json.containsKey("secondaryColors"), false);
    });

    test("copyWith creates a new instance with updated fields", () {
      final original = ShoppingScan.fromJson({
        "id": "scan-14",
        "scanType": "url",
        "productName": "Original",
        "brand": "OG Brand",
        "category": "tops",
        "color": "blue",
        "formalityScore": 3,
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      final updated = original.copyWith(
        category: "shoes",
        color: "red",
        formalityScore: 8,
      );

      expect(updated.category, "shoes");
      expect(updated.color, "red");
      expect(updated.formalityScore, 8);
      // Should be a new instance
      expect(identical(original, updated), false);
    });

    // === Story 8.5: insights field tests ===

    test("fromJson parses insights field as Map<String, dynamic>?", () {
      final json = {
        "id": "scan-insights-1",
        "scanType": "url",
        "insights": {
          "matches": [
            {"itemId": "item-1", "matchReasons": ["Good match"]}
          ],
          "insights": [
            {"type": "style_feedback", "title": "T", "body": "B"}
          ]
        },
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final scan = ShoppingScan.fromJson(json);

      expect(scan.insights, isNotNull);
      expect(scan.insights, isA<Map<String, dynamic>>());
      expect((scan.insights!["matches"] as List).length, 1);
    });

    test("fromJson returns null insights when not present", () {
      final json = {
        "id": "scan-insights-2",
        "scanType": "url",
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final scan = ShoppingScan.fromJson(json);

      expect(scan.insights, isNull);
    });

    test("copyWith updates insights field", () {
      final original = ShoppingScan.fromJson({
        "id": "scan-insights-3",
        "scanType": "url",
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      final newInsights = {"matches": <dynamic>[], "insights": <dynamic>[]};
      final updated = original.copyWith(insights: newInsights);

      expect(updated.insights, isNotNull);
      expect(updated.insights, newInsights);
      expect(original.insights, isNull);
    });

    test("copyWith preserves unchanged fields", () {
      final original = ShoppingScan.fromJson({
        "id": "scan-15",
        "scanType": "url",
        "productName": "Test Shirt",
        "brand": "Brand X",
        "price": 29.99,
        "currency": "GBP",
        "category": "tops",
        "color": "blue",
        "formalityScore": 5,
        "createdAt": "2026-03-19T10:00:00.000Z",
      });

      final updated = original.copyWith(category: "bottoms");

      expect(updated.id, "scan-15");
      expect(updated.scanType, "url");
      expect(updated.productName, "Test Shirt");
      expect(updated.brand, "Brand X");
      expect(updated.price, 29.99);
      expect(updated.currency, "GBP");
      expect(updated.color, "blue");
      expect(updated.formalityScore, 5);
      expect(updated.category, "bottoms"); // Only this changed
    });
  });
}
