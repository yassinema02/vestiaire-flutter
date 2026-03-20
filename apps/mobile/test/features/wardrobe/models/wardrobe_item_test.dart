import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/wardrobe_item.dart";

void main() {
  group("WardrobeItem", () {
    test("fromJson parses all fields correctly", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "originalPhotoUrl": "https://example.com/original.jpg",
        "name": "Blue Shirt",
        "bgRemovalStatus": "completed",
        "createdAt": "2026-03-10T12:00:00.000Z",
        "updatedAt": "2026-03-10T12:00:00.000Z",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.id, "item-1");
      expect(item.profileId, "profile-1");
      expect(item.photoUrl, "https://example.com/photo.jpg");
      expect(item.originalPhotoUrl, "https://example.com/original.jpg");
      expect(item.name, "Blue Shirt");
      expect(item.bgRemovalStatus, "completed");
      expect(item.createdAt, "2026-03-10T12:00:00.000Z");
      expect(item.updatedAt, "2026-03-10T12:00:00.000Z");
    });

    test("fromJson parses snake_case keys", () {
      final json = {
        "id": "item-1",
        "profile_id": "profile-1",
        "photo_url": "https://example.com/photo.jpg",
        "original_photo_url": "https://example.com/original.jpg",
        "name": null,
        "bg_removal_status": "pending",
        "created_at": "2026-03-10T12:00:00.000Z",
        "updated_at": "2026-03-10T12:00:00.000Z",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.profileId, "profile-1");
      expect(item.photoUrl, "https://example.com/photo.jpg");
      expect(item.originalPhotoUrl, "https://example.com/original.jpg");
      expect(item.bgRemovalStatus, "pending");
      expect(item.name, isNull);
    });

    test("fromJson handles missing optional fields", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.originalPhotoUrl, isNull);
      expect(item.name, isNull);
      expect(item.bgRemovalStatus, isNull);
      expect(item.createdAt, isNull);
      expect(item.updatedAt, isNull);
      expect(item.category, isNull);
      expect(item.color, isNull);
      expect(item.secondaryColors, isNull);
      expect(item.pattern, isNull);
      expect(item.material, isNull);
      expect(item.style, isNull);
      expect(item.season, isNull);
      expect(item.occasion, isNull);
      expect(item.categorizationStatus, isNull);
    });

    group("isProcessing", () {
      test("returns true when bgRemovalStatus is pending", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "pending",
        });
        expect(item.isProcessing, isTrue);
      });

      test("returns false when bgRemovalStatus is completed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "completed",
        });
        expect(item.isProcessing, isFalse);
      });

      test("returns false when bgRemovalStatus is failed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "failed",
        });
        expect(item.isProcessing, isFalse);
      });

      test("returns false when bgRemovalStatus is null", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
        });
        expect(item.isProcessing, isFalse);
      });
    });

    group("isFailed", () {
      test("returns true when bgRemovalStatus is failed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "failed",
        });
        expect(item.isFailed, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "completed",
        });
        expect(item.isFailed, isFalse);
      });
    });

    group("isCompleted", () {
      test("returns true when bgRemovalStatus is completed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "completed",
        });
        expect(item.isCompleted, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "bgRemovalStatus": "pending",
        });
        expect(item.isCompleted, isFalse);
      });
    });

    // === Story 2.3: Categorization fields ===

    test("fromJson parses all categorization fields", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "category": "tops",
        "color": "blue",
        "secondaryColors": ["white", "red"],
        "pattern": "striped",
        "material": "cotton",
        "style": "casual",
        "season": ["spring", "summer"],
        "occasion": ["everyday", "work"],
        "categorizationStatus": "completed",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.category, "tops");
      expect(item.color, "blue");
      expect(item.secondaryColors, ["white", "red"]);
      expect(item.pattern, "striped");
      expect(item.material, "cotton");
      expect(item.style, "casual");
      expect(item.season, ["spring", "summer"]);
      expect(item.occasion, ["everyday", "work"]);
      expect(item.categorizationStatus, "completed");
    });

    test("fromJson parses snake_case categorization keys", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "secondary_colors": ["black"],
        "categorization_status": "pending",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.secondaryColors, ["black"]);
      expect(item.categorizationStatus, "pending");
    });

    test("secondaryColors parses as List<String>", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "url",
        "secondaryColors": ["red", "blue", "green"],
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.secondaryColors, isA<List<String>>());
      expect(item.secondaryColors!.length, 3);
      expect(item.secondaryColors, ["red", "blue", "green"]);
    });

    test("season parses as List<String>", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "url",
        "season": ["spring", "fall"],
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.season, isA<List<String>>());
      expect(item.season!.length, 2);
      expect(item.season, ["spring", "fall"]);
    });

    test("occasion parses as List<String>", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "url",
        "occasion": ["everyday", "work", "party"],
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.occasion, isA<List<String>>());
      expect(item.occasion!.length, 3);
      expect(item.occasion, ["everyday", "work", "party"]);
    });

    group("isCategorizationPending", () {
      test("returns true when categorizationStatus is pending", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "categorizationStatus": "pending",
        });
        expect(item.isCategorizationPending, isTrue);
      });

      test("returns false when categorizationStatus is completed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "categorizationStatus": "completed",
        });
        expect(item.isCategorizationPending, isFalse);
      });

      test("returns false when categorizationStatus is null", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
        });
        expect(item.isCategorizationPending, isFalse);
      });
    });

    group("isCategorizationFailed", () {
      test("returns true when categorizationStatus is failed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "categorizationStatus": "failed",
        });
        expect(item.isCategorizationFailed, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "categorizationStatus": "completed",
        });
        expect(item.isCategorizationFailed, isFalse);
      });
    });

    group("isCategorizationCompleted", () {
      test("returns true when categorizationStatus is completed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "categorizationStatus": "completed",
        });
        expect(item.isCategorizationCompleted, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "categorizationStatus": "pending",
        });
        expect(item.isCategorizationCompleted, isFalse);
      });
    });

    // === Story 2.4: Optional metadata fields ===

    test("fromJson parses brand, purchasePrice, purchaseDate, currency", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "brand": "Nike",
        "purchasePrice": 49.99,
        "purchaseDate": "2025-06-15",
        "currency": "USD",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.brand, "Nike");
      expect(item.purchasePrice, 49.99);
      expect(item.purchaseDate, "2025-06-15");
      expect(item.currency, "USD");
    });

    test("fromJson parses snake_case optional metadata keys", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "purchase_price": 29.99,
        "purchase_date": "2025-01-10",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.purchasePrice, 29.99);
      expect(item.purchaseDate, "2025-01-10");
    });

    test("fromJson handles null optional metadata fields", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
      };

      final item = WardrobeItem.fromJson(json);

      expect(item.brand, isNull);
      expect(item.purchasePrice, isNull);
      expect(item.purchaseDate, isNull);
      expect(item.currency, isNull);
    });

    test("toJson serializes all editable fields", () {
      final item = WardrobeItem.fromJson({
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "category": "tops",
        "color": "blue",
        "secondaryColors": ["red"],
        "pattern": "solid",
        "material": "cotton",
        "style": "casual",
        "season": ["spring"],
        "occasion": ["everyday"],
        "name": "My Shirt",
        "brand": "Nike",
        "purchasePrice": 49.99,
        "purchaseDate": "2025-06-15",
        "currency": "USD",
      });

      final json = item.toJson();

      expect(json["category"], "tops");
      expect(json["color"], "blue");
      expect(json["secondaryColors"], ["red"]);
      expect(json["pattern"], "solid");
      expect(json["material"], "cotton");
      expect(json["style"], "casual");
      expect(json["season"], ["spring"]);
      expect(json["occasion"], ["everyday"]);
      expect(json["name"], "My Shirt");
      expect(json["brand"], "Nike");
      expect(json["purchasePrice"], 49.99);
      expect(json["purchaseDate"], "2025-06-15");
      expect(json["currency"], "USD");
    });

    // === Story 7.3: resaleStatus field ===

    test("fromJson parses resaleStatus field (camelCase)", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "resaleStatus": "listed",
      };

      final item = WardrobeItem.fromJson(json);
      expect(item.resaleStatus, "listed");
    });

    test("fromJson parses resaleStatus from snake_case key", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "resale_status": "sold",
      };

      final item = WardrobeItem.fromJson(json);
      expect(item.resaleStatus, "sold");
    });

    test("resaleStatus is null when not provided", () {
      final json = {
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
      };

      final item = WardrobeItem.fromJson(json);
      expect(item.resaleStatus, isNull);
    });

    group("isListedForResale", () {
      test("returns true when resaleStatus is listed", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "resaleStatus": "listed",
        });
        expect(item.isListedForResale, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "resaleStatus": "sold",
        });
        expect(item.isListedForResale, isFalse);
      });

      test("returns false when null", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
        });
        expect(item.isListedForResale, isFalse);
      });
    });

    group("isSold", () {
      test("returns true when resaleStatus is sold", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "resaleStatus": "sold",
        });
        expect(item.isSold, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "resaleStatus": "listed",
        });
        expect(item.isSold, isFalse);
      });
    });

    group("isDonated", () {
      test("returns true when resaleStatus is donated", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "resaleStatus": "donated",
        });
        expect(item.isDonated, isTrue);
      });

      test("returns false for other statuses", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "resaleStatus": "listed",
        });
        expect(item.isDonated, isFalse);
      });
    });

    test("toJson includes resaleStatus when set", () {
      final item = WardrobeItem.fromJson({
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "resaleStatus": "listed",
      });

      final json = item.toJson();
      expect(json["resaleStatus"], "listed");
    });

    test("toJson omits resaleStatus when null", () {
      final item = WardrobeItem.fromJson({
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
      });

      final json = item.toJson();
      expect(json.containsKey("resaleStatus"), isFalse);
    });

    test("toJson omits null fields", () {
      final item = WardrobeItem.fromJson({
        "id": "item-1",
        "profileId": "profile-1",
        "photoUrl": "https://example.com/photo.jpg",
        "category": "tops",
      });

      final json = item.toJson();

      expect(json.containsKey("category"), isTrue);
      expect(json.containsKey("brand"), isFalse);
      expect(json.containsKey("purchasePrice"), isFalse);
      expect(json.containsKey("purchaseDate"), isFalse);
    });

    group("displayLabel", () {
      test("returns name when available", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "name": "My Blue Shirt",
          "category": "tops",
        });
        expect(item.displayLabel, "My Blue Shirt");
      });

      test("returns category when name is null", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
          "category": "tops",
        });
        expect(item.displayLabel, "tops");
      });

      test("returns 'Item' when both name and category are null", () {
        final item = WardrobeItem.fromJson({
          "id": "1",
          "profileId": "p1",
          "photoUrl": "url",
        });
        expect(item.displayLabel, "Item");
      });
    });
  });
}
