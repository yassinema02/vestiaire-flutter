import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/resale/models/donation_log.dart";

void main() {
  group("DonationLogEntry", () {
    test("fromJson() parses all fields correctly", () {
      final json = {
        "id": "d1",
        "itemId": "item-1",
        "charityName": "Red Cross",
        "estimatedValue": 25.50,
        "donationDate": "2026-03-15",
        "createdAt": "2026-03-15T10:00:00.000Z",
        "itemName": "Blue Shirt",
        "itemPhotoUrl": "https://example.com/photo.jpg",
        "itemCategory": "tops",
        "itemBrand": "Nike",
      };

      final entry = DonationLogEntry.fromJson(json);

      expect(entry.id, "d1");
      expect(entry.itemId, "item-1");
      expect(entry.charityName, "Red Cross");
      expect(entry.estimatedValue, 25.50);
      expect(entry.donationDate.year, 2026);
      expect(entry.donationDate.month, 3);
      expect(entry.donationDate.day, 15);
      expect(entry.itemName, "Blue Shirt");
      expect(entry.itemPhotoUrl, "https://example.com/photo.jpg");
      expect(entry.itemCategory, "tops");
      expect(entry.itemBrand, "Nike");
    });

    test("fromJson() handles null charityName and itemBrand", () {
      final json = {
        "id": "d2",
        "itemId": "item-2",
        "estimatedValue": 10,
        "donationDate": "2026-03-10",
        "createdAt": "2026-03-10T10:00:00.000Z",
      };

      final entry = DonationLogEntry.fromJson(json);

      expect(entry.charityName, isNull);
      expect(entry.itemName, isNull);
      expect(entry.itemPhotoUrl, isNull);
      expect(entry.itemCategory, isNull);
      expect(entry.itemBrand, isNull);
      expect(entry.estimatedValue, 10.0);
    });
  });

  group("DonationSummary", () {
    test("fromJson() parses totalDonated and totalValue", () {
      final json = {
        "totalDonated": 5,
        "totalValue": 120.50,
      };

      final summary = DonationSummary.fromJson(json);

      expect(summary.totalDonated, 5);
      expect(summary.totalValue, 120.50);
    });

    test("fromJson() defaults to zero when fields missing", () {
      final summary = DonationSummary.fromJson({});

      expect(summary.totalDonated, 0);
      expect(summary.totalValue, 0.0);
    });
  });
}
