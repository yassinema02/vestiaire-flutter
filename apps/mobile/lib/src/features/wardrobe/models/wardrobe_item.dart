/// Data model for a wardrobe item.
///
/// Encapsulates the item data returned by the API, including
/// background removal status fields added in Story 2.2,
/// categorization fields added in Story 2.3, and optional
/// metadata fields added in Story 2.4.
class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.profileId,
    required this.photoUrl,
    this.originalPhotoUrl,
    this.name,
    this.bgRemovalStatus,
    this.category,
    this.color,
    this.secondaryColors,
    this.pattern,
    this.material,
    this.style,
    this.season,
    this.occasion,
    this.categorizationStatus,
    this.brand,
    this.purchasePrice,
    this.purchaseDate,
    this.currency,
    this.isFavorite = false,
    this.neglectStatus,
    this.wearCount = 0,
    this.lastWornDate,
    this.resaleStatus,
    this.creationMethod,
    this.extractionJobId,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a WardrobeItem from a JSON map (API response).
  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json["id"] as String? ?? "",
      profileId: json["profileId"] as String? ?? json["profile_id"] as String? ?? "",
      photoUrl: json["photoUrl"] as String? ?? json["photo_url"] as String? ?? "",
      originalPhotoUrl: json["originalPhotoUrl"] as String? ?? json["original_photo_url"] as String?,
      name: json["name"] as String?,
      bgRemovalStatus: json["bgRemovalStatus"] as String? ?? json["bg_removal_status"] as String?,
      category: json["category"] as String?,
      color: json["color"] as String?,
      secondaryColors: (json["secondaryColors"] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          (json["secondary_colors"] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      pattern: json["pattern"] as String?,
      material: json["material"] as String?,
      style: json["style"] as String?,
      season: (json["season"] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      occasion: (json["occasion"] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      categorizationStatus: json["categorizationStatus"] as String? ??
          json["categorization_status"] as String?,
      brand: json["brand"] as String?,
      purchasePrice: (json["purchasePrice"] as num?)?.toDouble() ??
          (json["purchase_price"] as num?)?.toDouble(),
      purchaseDate: json["purchaseDate"] as String? ??
          json["purchase_date"] as String?,
      currency: json["currency"] as String?,
      isFavorite: json["isFavorite"] as bool? ?? json["is_favorite"] as bool? ?? false,
      neglectStatus: json["neglectStatus"] as String? ?? json["neglect_status"] as String?,
      wearCount: (json["wearCount"] as num?)?.toInt() ?? (json["wear_count"] as num?)?.toInt() ?? 0,
      lastWornDate: json["lastWornDate"] as String? ?? json["last_worn_date"] as String?,
      resaleStatus: json["resaleStatus"] as String? ?? json["resale_status"] as String?,
      creationMethod: json["creationMethod"] as String? ?? json["creation_method"] as String?,
      extractionJobId: json["extractionJobId"] as String? ?? json["extraction_job_id"] as String?,
      createdAt: json["createdAt"] as String? ?? json["created_at"] as String?,
      updatedAt: json["updatedAt"] as String? ?? json["updated_at"] as String?,
    );
  }

  final String id;
  final String profileId;
  final String photoUrl;
  final String? originalPhotoUrl;
  final String? name;
  final String? bgRemovalStatus;
  final String? category;
  final String? color;
  final List<String>? secondaryColors;
  final String? pattern;
  final String? material;
  final String? style;
  final List<String>? season;
  final List<String>? occasion;
  final String? categorizationStatus;
  final String? brand;
  final double? purchasePrice;
  final String? purchaseDate;
  final String? currency;
  final bool isFavorite;
  final String? neglectStatus;
  final int wearCount;
  final String? lastWornDate;
  final String? resaleStatus;
  final String? creationMethod;
  final String? extractionJobId;
  final String? createdAt;
  final String? updatedAt;

  /// Whether background removal is currently in progress.
  bool get isProcessing => bgRemovalStatus == "pending";

  /// Whether background removal failed.
  bool get isFailed => bgRemovalStatus == "failed";

  /// Whether background removal completed successfully.
  bool get isCompleted => bgRemovalStatus == "completed";

  /// Whether categorization is currently in progress.
  bool get isCategorizationPending => categorizationStatus == "pending";

  /// Whether categorization failed.
  bool get isCategorizationFailed => categorizationStatus == "failed";

  /// Whether categorization completed successfully.
  bool get isCategorizationCompleted => categorizationStatus == "completed";

  /// Whether this item is neglected (not worn in a long time).
  bool get isNeglected => neglectStatus == "neglected";

  /// Whether this item is listed for resale.
  bool get isListedForResale => resaleStatus == "listed";

  /// Whether this item has been sold.
  bool get isSold => resaleStatus == "sold";

  /// Whether this item has been donated.
  bool get isDonated => resaleStatus == "donated";

  /// Display label: name if available, then category, then 'Item'.
  String get displayLabel => name ?? category ?? "Item";

  /// Cost per wear calculation: purchasePrice / wearCount.
  /// Returns null if no price or zero wears.
  String? get costPerWear {
    if (purchasePrice == null || wearCount == 0) return null;
    return (purchasePrice! / wearCount).toStringAsFixed(2);
  }

  /// Display-friendly cost per wear with currency symbol, or "N/A".
  String get costPerWearDisplay {
    final cpw = costPerWear;
    if (cpw == null) return "N/A";
    final symbol = currency == "EUR" ? "\u20ac" : currency == "USD" ? "\$" : "\u00a3";
    return "$symbol$cpw/wear";
  }

  /// Serialize all editable fields to a JSON map for PATCH /v1/items/:id.
  ///
  /// Only includes fields that have values. Used by the ReviewItemScreen
  /// to send updates to the API.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (category != null) json["category"] = category;
    if (color != null) json["color"] = color;
    if (secondaryColors != null) json["secondaryColors"] = secondaryColors;
    if (pattern != null) json["pattern"] = pattern;
    if (material != null) json["material"] = material;
    if (style != null) json["style"] = style;
    if (season != null) json["season"] = season;
    if (occasion != null) json["occasion"] = occasion;
    if (name != null) json["name"] = name;
    if (brand != null) json["brand"] = brand;
    if (purchasePrice != null) json["purchasePrice"] = purchasePrice;
    if (purchaseDate != null) json["purchaseDate"] = purchaseDate;
    if (currency != null) json["currency"] = currency;
    if (isFavorite) json["isFavorite"] = isFavorite;
    if (resaleStatus != null) json["resaleStatus"] = resaleStatus;
    return json;
  }
}
