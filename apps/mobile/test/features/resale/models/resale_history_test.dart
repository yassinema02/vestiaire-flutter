import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/resale/models/resale_history.dart";

void main() {
  group("ResaleHistoryEntry", () {
    test("fromJson() parses all fields correctly", () {
      final json = {
        "id": "h1",
        "itemId": "item-1",
        "resaleListingId": "listing-1",
        "type": "sold",
        "salePrice": 49.99,
        "saleCurrency": "GBP",
        "saleDate": "2026-03-15",
        "createdAt": "2026-03-15T10:00:00.000Z",
        "itemName": "Blue Shirt",
        "itemPhotoUrl": "https://example.com/photo.jpg",
        "itemCategory": "tops",
        "itemBrand": "Nike",
      };

      final entry = ResaleHistoryEntry.fromJson(json);

      expect(entry.id, "h1");
      expect(entry.itemId, "item-1");
      expect(entry.resaleListingId, "listing-1");
      expect(entry.type, "sold");
      expect(entry.salePrice, 49.99);
      expect(entry.saleCurrency, "GBP");
      expect(entry.saleDate.year, 2026);
      expect(entry.saleDate.month, 3);
      expect(entry.saleDate.day, 15);
      expect(entry.itemName, "Blue Shirt");
      expect(entry.itemPhotoUrl, "https://example.com/photo.jpg");
      expect(entry.itemCategory, "tops");
      expect(entry.itemBrand, "Nike");
      expect(entry.isSold, true);
      expect(entry.isDonated, false);
    });

    test("fromJson() handles null optional fields", () {
      final json = {
        "id": "h2",
        "itemId": "item-2",
        "type": "donated",
        "salePrice": 0,
        "saleCurrency": "GBP",
        "saleDate": "2026-03-10",
        "createdAt": "2026-03-10T10:00:00.000Z",
      };

      final entry = ResaleHistoryEntry.fromJson(json);

      expect(entry.resaleListingId, isNull);
      expect(entry.itemName, isNull);
      expect(entry.itemPhotoUrl, isNull);
      expect(entry.itemCategory, isNull);
      expect(entry.itemBrand, isNull);
      expect(entry.isDonated, true);
      expect(entry.isSold, false);
    });
  });

  group("ResaleEarningsSummary", () {
    test("fromJson() parses counts and earnings", () {
      final json = {
        "itemsSold": 5,
        "itemsDonated": 3,
        "totalEarnings": 250.50,
      };

      final summary = ResaleEarningsSummary.fromJson(json);

      expect(summary.itemsSold, 5);
      expect(summary.itemsDonated, 3);
      expect(summary.totalEarnings, 250.50);
    });

    test("fromJson() defaults to zero when fields missing", () {
      final summary = ResaleEarningsSummary.fromJson({});

      expect(summary.itemsSold, 0);
      expect(summary.itemsDonated, 0);
      expect(summary.totalEarnings, 0.0);
    });
  });

  group("MonthlyEarnings", () {
    test("fromJson() parses month and earnings", () {
      final json = {
        "month": "2026-01-01T00:00:00.000Z",
        "earnings": 150.00,
      };

      final data = MonthlyEarnings.fromJson(json);

      expect(data.month.year, 2026);
      expect(data.month.month, 1);
      expect(data.earnings, 150.00);
    });

    test("fromJson() defaults earnings to 0 when missing", () {
      final data = MonthlyEarnings.fromJson({"month": "2026-02-01"});

      expect(data.earnings, 0.0);
    });
  });
}
