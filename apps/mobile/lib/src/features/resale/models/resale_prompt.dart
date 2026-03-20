/// Data model for a resale prompt.
///
/// Represents a monthly resale suggestion for a neglected wardrobe item,
/// including estimated sale price and item metadata.
///
/// Story 13.2: Monthly Resale Prompts (FR-RSL-01, FR-RSL-05, FR-RSL-06)
class ResalePrompt {
  const ResalePrompt({
    required this.id,
    required this.itemId,
    required this.estimatedPrice,
    required this.estimatedCurrency,
    this.action,
    this.dismissedUntil,
    required this.createdAt,
    this.itemName,
    this.itemPhotoUrl,
    this.itemCategory,
    this.itemBrand,
    this.itemWearCount = 0,
    this.itemLastWornDate,
    this.itemCreatedAt,
  });

  /// Parse a ResalePrompt from API JSON response.
  factory ResalePrompt.fromJson(Map<String, dynamic> json) {
    return ResalePrompt(
      id: json["id"] as String? ?? "",
      itemId: json["itemId"] as String? ?? json["item_id"] as String? ?? "",
      estimatedPrice: ((json["estimatedPrice"] ?? json["estimated_price"] ?? 10) as num).toDouble(),
      estimatedCurrency: json["estimatedCurrency"] as String? ??
          json["estimated_currency"] as String? ??
          "GBP",
      action: json["action"] as String?,
      dismissedUntil: json["dismissedUntil"] != null
          ? DateTime.tryParse(json["dismissedUntil"].toString())
          : json["dismissed_until"] != null
              ? DateTime.tryParse(json["dismissed_until"].toString())
              : null,
      createdAt: DateTime.tryParse(
              (json["createdAt"] ?? json["created_at"] ?? "").toString()) ??
          DateTime.now(),
      itemName: json["itemName"] as String? ?? json["item_name"] as String?,
      itemPhotoUrl:
          json["itemPhotoUrl"] as String? ?? json["item_photo_url"] as String?,
      itemCategory:
          json["itemCategory"] as String? ?? json["item_category"] as String?,
      itemBrand:
          json["itemBrand"] as String? ?? json["item_brand"] as String?,
      itemWearCount:
          (json["itemWearCount"] ?? json["item_wear_count"] ?? 0) as int,
      itemLastWornDate: json["itemLastWornDate"] != null
          ? DateTime.tryParse(json["itemLastWornDate"].toString())
          : json["item_last_worn_date"] != null
              ? DateTime.tryParse(json["item_last_worn_date"].toString())
              : null,
      itemCreatedAt: json["itemCreatedAt"] != null
          ? DateTime.tryParse(json["itemCreatedAt"].toString())
          : json["item_created_at"] != null
              ? DateTime.tryParse(json["item_created_at"].toString())
              : null,
    );
  }

  final String id;
  final String itemId;
  final double estimatedPrice;
  final String estimatedCurrency;
  final String? action;
  final DateTime? dismissedUntil;
  final DateTime createdAt;
  final String? itemName;
  final String? itemPhotoUrl;
  final String? itemCategory;
  final String? itemBrand;
  final int itemWearCount;
  final DateTime? itemLastWornDate;
  final DateTime? itemCreatedAt;

  /// Number of days since the item was last worn (or created if never worn).
  int get daysSinceLastWorn {
    final reference = itemLastWornDate ?? itemCreatedAt ?? createdAt;
    return DateTime.now().difference(reference).inDays;
  }
}
