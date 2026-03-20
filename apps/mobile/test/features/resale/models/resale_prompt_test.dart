import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/resale/models/resale_prompt.dart";

void main() {
  group("ResalePrompt.fromJson", () {
    test("parses all fields correctly (camelCase)", () {
      final json = {
        "id": "prompt-1",
        "itemId": "item-1",
        "estimatedPrice": 48.0,
        "estimatedCurrency": "GBP",
        "action": null,
        "dismissedUntil": null,
        "createdAt": "2026-03-19T10:00:00.000Z",
        "itemName": "Blue Shirt",
        "itemPhotoUrl": "http://img.com/1.jpg",
        "itemCategory": "Tops",
        "itemBrand": "Nike",
        "itemWearCount": 3,
        "itemLastWornDate": "2025-08-01T10:00:00.000Z",
        "itemCreatedAt": "2025-01-01T10:00:00.000Z",
      };

      final prompt = ResalePrompt.fromJson(json);

      expect(prompt.id, "prompt-1");
      expect(prompt.itemId, "item-1");
      expect(prompt.estimatedPrice, 48.0);
      expect(prompt.estimatedCurrency, "GBP");
      expect(prompt.action, isNull);
      expect(prompt.dismissedUntil, isNull);
      expect(prompt.itemName, "Blue Shirt");
      expect(prompt.itemPhotoUrl, "http://img.com/1.jpg");
      expect(prompt.itemCategory, "Tops");
      expect(prompt.itemBrand, "Nike");
      expect(prompt.itemWearCount, 3);
      expect(prompt.itemLastWornDate, isNotNull);
      expect(prompt.itemCreatedAt, isNotNull);
    });

    test("parses all fields correctly (snake_case)", () {
      final json = {
        "id": "prompt-2",
        "item_id": "item-2",
        "estimated_price": 30,
        "estimated_currency": "EUR",
        "action": "dismissed",
        "dismissed_until": "2026-06-17",
        "created_at": "2026-03-19T10:00:00.000Z",
        "item_name": "Red Dress",
        "item_photo_url": "http://img.com/2.jpg",
        "item_category": "Dresses",
        "item_brand": "Zara",
        "item_wear_count": 0,
        "item_last_worn_date": null,
        "item_created_at": "2025-05-01T10:00:00.000Z",
      };

      final prompt = ResalePrompt.fromJson(json);

      expect(prompt.id, "prompt-2");
      expect(prompt.itemId, "item-2");
      expect(prompt.estimatedPrice, 30.0);
      expect(prompt.estimatedCurrency, "EUR");
      expect(prompt.action, "dismissed");
      expect(prompt.dismissedUntil, isNotNull);
      expect(prompt.itemName, "Red Dress");
      expect(prompt.itemBrand, "Zara");
      expect(prompt.itemWearCount, 0);
    });

    test("handles null optional fields", () {
      final json = {
        "id": "prompt-3",
        "itemId": "item-3",
        "estimatedPrice": 10,
        "estimatedCurrency": "GBP",
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final prompt = ResalePrompt.fromJson(json);

      expect(prompt.id, "prompt-3");
      expect(prompt.action, isNull);
      expect(prompt.dismissedUntil, isNull);
      expect(prompt.itemName, isNull);
      expect(prompt.itemPhotoUrl, isNull);
      expect(prompt.itemCategory, isNull);
      expect(prompt.itemBrand, isNull);
      expect(prompt.itemWearCount, 0);
      expect(prompt.itemLastWornDate, isNull);
      expect(prompt.itemCreatedAt, isNull);
    });

    test("defaults estimatedCurrency to GBP when missing", () {
      final json = {
        "id": "prompt-4",
        "itemId": "item-4",
        "estimatedPrice": 10,
        "createdAt": "2026-03-19T10:00:00.000Z",
      };

      final prompt = ResalePrompt.fromJson(json);
      expect(prompt.estimatedCurrency, "GBP");
    });
  });

  group("daysSinceLastWorn", () {
    test("computes correctly from itemLastWornDate", () {
      final lastWorn = DateTime.now().subtract(const Duration(days: 200));
      final prompt = ResalePrompt(
        id: "p1",
        itemId: "i1",
        estimatedPrice: 10,
        estimatedCurrency: "GBP",
        createdAt: DateTime.now(),
        itemLastWornDate: lastWorn,
        itemCreatedAt: DateTime.now().subtract(const Duration(days: 365)),
      );

      // Should be close to 200 (within 1 day tolerance)
      expect(prompt.daysSinceLastWorn, closeTo(200, 1));
    });

    test("falls back to itemCreatedAt when itemLastWornDate is null", () {
      final created = DateTime.now().subtract(const Duration(days: 300));
      final prompt = ResalePrompt(
        id: "p2",
        itemId: "i2",
        estimatedPrice: 10,
        estimatedCurrency: "GBP",
        createdAt: DateTime.now(),
        itemLastWornDate: null,
        itemCreatedAt: created,
      );

      expect(prompt.daysSinceLastWorn, closeTo(300, 1));
    });

    test("falls back to createdAt when both dates are null", () {
      final created = DateTime.now().subtract(const Duration(days: 30));
      final prompt = ResalePrompt(
        id: "p3",
        itemId: "i3",
        estimatedPrice: 10,
        estimatedCurrency: "GBP",
        createdAt: created,
        itemLastWornDate: null,
        itemCreatedAt: null,
      );

      expect(prompt.daysSinceLastWorn, closeTo(30, 1));
    });
  });
}
