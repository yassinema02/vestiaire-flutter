import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/resale/models/resale_listing.dart";

void main() {
  group("ResaleListing", () {
    test("fromJson() correctly parses all fields", () {
      final json = {
        "id": "listing-1",
        "title": "Beautiful Blue Shirt",
        "description": "A lovely shirt in great condition.",
        "conditionEstimate": "Like New",
        "hashtags": ["fashion", "shirt", "blue"],
        "platform": "general",
        "generatedAt": "2026-03-19T00:00:00.000Z",
      };

      final listing = ResaleListing.fromJson(json);

      expect(listing.id, "listing-1");
      expect(listing.title, "Beautiful Blue Shirt");
      expect(listing.description, "A lovely shirt in great condition.");
      expect(listing.conditionEstimate, "Like New");
      expect(listing.hashtags, ["fashion", "shirt", "blue"]);
      expect(listing.platform, "general");
      expect(listing.generatedAt, "2026-03-19T00:00:00.000Z");
    });

    test("toJson() serializes all fields", () {
      final listing = ResaleListing(
        id: "listing-1",
        title: "Blue Shirt",
        description: "Great shirt.",
        conditionEstimate: "Good",
        hashtags: ["fashion"],
        platform: "general",
        generatedAt: "2026-03-19T00:00:00.000Z",
      );

      final json = listing.toJson();

      expect(json["id"], "listing-1");
      expect(json["title"], "Blue Shirt");
      expect(json["description"], "Great shirt.");
      expect(json["conditionEstimate"], "Good");
      expect(json["hashtags"], ["fashion"]);
      expect(json["platform"], "general");
      expect(json["generatedAt"], "2026-03-19T00:00:00.000Z");
    });

    test("fromJson() handles missing optional fields with defaults", () {
      final json = <String, dynamic>{};

      final listing = ResaleListing.fromJson(json);

      expect(listing.id, "");
      expect(listing.title, "");
      expect(listing.description, "");
      expect(listing.conditionEstimate, "Good");
      expect(listing.hashtags, isEmpty);
      expect(listing.platform, "general");
      expect(listing.generatedAt, "");
    });
  });

  group("ResaleListingResult", () {
    test("fromJson() parses listing and item", () {
      final json = {
        "listing": {
          "id": "listing-1",
          "title": "Blue Shirt",
          "description": "A shirt.",
          "conditionEstimate": "New",
          "hashtags": ["tag1"],
          "platform": "general",
        },
        "item": {
          "id": "item-1",
          "name": "Blue Shirt",
          "category": "tops",
          "brand": "Nike",
          "photoUrl": "https://example.com/photo.jpg",
        },
        "generatedAt": "2026-03-19T12:00:00.000Z",
      };

      final result = ResaleListingResult.fromJson(json);

      expect(result.listing.id, "listing-1");
      expect(result.listing.title, "Blue Shirt");
      expect(result.listing.conditionEstimate, "New");
      expect(result.item.id, "item-1");
      expect(result.item.name, "Blue Shirt");
      expect(result.item.brand, "Nike");
      expect(result.generatedAt, "2026-03-19T12:00:00.000Z");
    });

    test("fromJson() handles empty nested objects", () {
      final json = <String, dynamic>{
        "generatedAt": "2026-03-19T12:00:00.000Z",
      };

      final result = ResaleListingResult.fromJson(json);

      expect(result.listing.id, "");
      expect(result.item.id, "");
      expect(result.generatedAt, "2026-03-19T12:00:00.000Z");
    });
  });

  group("ResaleListingItem", () {
    test("fromJson() handles null brand and photoUrl", () {
      final json = {
        "id": "item-1",
        "name": "Shirt",
        "category": "tops",
      };

      final item = ResaleListingItem.fromJson(json);

      expect(item.id, "item-1");
      expect(item.name, "Shirt");
      expect(item.category, "tops");
      expect(item.brand, isNull);
      expect(item.photoUrl, isNull);
    });

    test("fromJson() parses photoUrl from camelCase key", () {
      final json = {
        "id": "item-1",
        "photoUrl": "https://example.com/photo.jpg",
      };

      final item = ResaleListingItem.fromJson(json);
      expect(item.photoUrl, "https://example.com/photo.jpg");
    });

    test("fromJson() parses photoUrl from snake_case key", () {
      final json = {
        "id": "item-1",
        "photo_url": "https://example.com/photo.jpg",
      };

      final item = ResaleListingItem.fromJson(json);
      expect(item.photoUrl, "https://example.com/photo.jpg");
    });
  });
}
