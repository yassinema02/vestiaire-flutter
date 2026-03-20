/// Data models for resale history tracking.
///
/// Story 7.4: Resale Status & History Tracking (FR-RSL-07, FR-RSL-08)

/// A single resale history entry (sold or donated item).
class ResaleHistoryEntry {
  const ResaleHistoryEntry({
    required this.id,
    required this.itemId,
    this.resaleListingId,
    required this.type,
    required this.salePrice,
    required this.saleCurrency,
    required this.saleDate,
    required this.createdAt,
    this.itemName,
    this.itemPhotoUrl,
    this.itemCategory,
    this.itemBrand,
  });

  factory ResaleHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ResaleHistoryEntry(
      id: json["id"] as String? ?? "",
      itemId: json["itemId"] as String? ?? json["item_id"] as String? ?? "",
      resaleListingId: json["resaleListingId"] as String? ??
          json["resale_listing_id"] as String?,
      type: json["type"] as String? ?? "sold",
      salePrice: (json["salePrice"] as num?)?.toDouble() ??
          (json["sale_price"] as num?)?.toDouble() ??
          0.0,
      saleCurrency: json["saleCurrency"] as String? ??
          json["sale_currency"] as String? ??
          "GBP",
      saleDate: DateTime.tryParse(
              json["saleDate"] as String? ?? json["sale_date"] as String? ?? "") ??
          DateTime.now(),
      createdAt: DateTime.tryParse(
              json["createdAt"] as String? ?? json["created_at"] as String? ?? "") ??
          DateTime.now(),
      itemName: json["itemName"] as String? ?? json["item_name"] as String?,
      itemPhotoUrl:
          json["itemPhotoUrl"] as String? ?? json["item_photo_url"] as String?,
      itemCategory:
          json["itemCategory"] as String? ?? json["item_category"] as String?,
      itemBrand: json["itemBrand"] as String? ?? json["item_brand"] as String?,
    );
  }

  final String id;
  final String itemId;
  final String? resaleListingId;
  final String type;
  final double salePrice;
  final String saleCurrency;
  final DateTime saleDate;
  final DateTime createdAt;
  final String? itemName;
  final String? itemPhotoUrl;
  final String? itemCategory;
  final String? itemBrand;

  bool get isSold => type == "sold";
  bool get isDonated => type == "donated";
}

/// Summary of resale earnings.
class ResaleEarningsSummary {
  const ResaleEarningsSummary({
    required this.itemsSold,
    required this.itemsDonated,
    required this.totalEarnings,
  });

  factory ResaleEarningsSummary.fromJson(Map<String, dynamic> json) {
    return ResaleEarningsSummary(
      itemsSold: (json["itemsSold"] as num?)?.toInt() ??
          (json["items_sold"] as num?)?.toInt() ??
          0,
      itemsDonated: (json["itemsDonated"] as num?)?.toInt() ??
          (json["items_donated"] as num?)?.toInt() ??
          0,
      totalEarnings: (json["totalEarnings"] as num?)?.toDouble() ??
          (json["total_earnings"] as num?)?.toDouble() ??
          0.0,
    );
  }

  final int itemsSold;
  final int itemsDonated;
  final double totalEarnings;
}

/// Monthly earnings data point.
class MonthlyEarnings {
  const MonthlyEarnings({
    required this.month,
    required this.earnings,
  });

  factory MonthlyEarnings.fromJson(Map<String, dynamic> json) {
    return MonthlyEarnings(
      month: DateTime.tryParse(json["month"] as String? ?? "") ?? DateTime.now(),
      earnings:
          (json["earnings"] as num?)?.toDouble() ?? 0.0,
    );
  }

  final DateTime month;
  final double earnings;
}
