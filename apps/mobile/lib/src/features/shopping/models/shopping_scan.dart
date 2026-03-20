/// Model representing a shopping scan result from the API.
///
/// Contains extracted product metadata from URL scraping and AI analysis.
/// Story 8.1: Product URL Scraping (FR-SHP-04, FR-SHP-11)
class ShoppingScan {
  const ShoppingScan({
    required this.id,
    this.url,
    required this.scanType,
    this.productName,
    this.brand,
    this.price,
    this.currency,
    this.imageUrl,
    this.category,
    this.color,
    this.secondaryColors,
    this.pattern,
    this.material,
    this.style,
    this.season,
    this.occasion,
    this.formalityScore,
    this.extractionMethod,
    this.compatibilityScore,
    this.insights,
    this.wishlisted = false,
    required this.createdAt,
  });

  final String id;
  final String? url;
  final String scanType;
  final String? productName;
  final String? brand;
  final double? price;
  final String? currency;
  final String? imageUrl;
  final String? category;
  final String? color;
  final List<String>? secondaryColors;
  final String? pattern;
  final String? material;
  final String? style;
  final List<String>? season;
  final List<String>? occasion;
  final int? formalityScore;
  final String? extractionMethod;
  final int? compatibilityScore;
  final Map<String, dynamic>? insights;
  final bool wishlisted;
  final DateTime createdAt;

  /// Parse a ShoppingScan from a JSON map.
  factory ShoppingScan.fromJson(Map<String, dynamic> json) {
    return ShoppingScan(
      id: json["id"] as String,
      url: json["url"] as String?,
      scanType: (json["scanType"] as String?) ?? "url",
      productName: json["productName"] as String?,
      brand: json["brand"] as String?,
      price: json["price"] != null ? (json["price"] as num).toDouble() : null,
      currency: json["currency"] as String?,
      imageUrl: json["imageUrl"] as String?,
      category: json["category"] as String?,
      color: json["color"] as String?,
      secondaryColors: json["secondaryColors"] != null
          ? (json["secondaryColors"] as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : null,
      pattern: json["pattern"] as String?,
      material: json["material"] as String?,
      style: json["style"] as String?,
      season: json["season"] != null
          ? (json["season"] as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : null,
      occasion: json["occasion"] != null
          ? (json["occasion"] as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : null,
      formalityScore: json["formalityScore"] != null
          ? (json["formalityScore"] as num).toInt()
          : null,
      extractionMethod: json["extractionMethod"] as String?,
      compatibilityScore: json["compatibilityScore"] != null
          ? (json["compatibilityScore"] as num).toInt()
          : null,
      insights: json["insights"] != null
          ? Map<String, dynamic>.from(json["insights"] as Map)
          : null,
      wishlisted: (json["wishlisted"] as bool?) ?? false,
      createdAt: DateTime.parse(json["createdAt"] as String),
    );
  }

  /// Create a copy with selectively updated fields.
  ShoppingScan copyWith({
    String? id,
    String? url,
    String? scanType,
    String? productName,
    String? brand,
    double? price,
    String? currency,
    String? imageUrl,
    String? category,
    String? color,
    List<String>? secondaryColors,
    String? pattern,
    String? material,
    String? style,
    List<String>? season,
    List<String>? occasion,
    int? formalityScore,
    String? extractionMethod,
    int? compatibilityScore,
    Map<String, dynamic>? insights,
    bool? wishlisted,
    DateTime? createdAt,
  }) {
    return ShoppingScan(
      id: id ?? this.id,
      url: url ?? this.url,
      scanType: scanType ?? this.scanType,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      color: color ?? this.color,
      secondaryColors: secondaryColors ?? this.secondaryColors,
      pattern: pattern ?? this.pattern,
      material: material ?? this.material,
      style: style ?? this.style,
      season: season ?? this.season,
      occasion: occasion ?? this.occasion,
      formalityScore: formalityScore ?? this.formalityScore,
      extractionMethod: extractionMethod ?? this.extractionMethod,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
      insights: insights ?? this.insights,
      wishlisted: wishlisted ?? this.wishlisted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serialize all editable fields to a JSON map.
  /// Only includes fields that have values (skips nulls).
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (productName != null) json["productName"] = productName;
    if (brand != null) json["brand"] = brand;
    if (price != null) json["price"] = price;
    if (currency != null) json["currency"] = currency;
    if (category != null) json["category"] = category;
    if (color != null) json["color"] = color;
    if (secondaryColors != null) json["secondaryColors"] = secondaryColors;
    if (pattern != null) json["pattern"] = pattern;
    if (material != null) json["material"] = material;
    if (style != null) json["style"] = style;
    if (season != null) json["season"] = season;
    if (occasion != null) json["occasion"] = occasion;
    if (formalityScore != null) json["formalityScore"] = formalityScore;
    return json;
  }

  /// Display name: product name or fallback.
  String get displayName => productName ?? "Unknown Product";

  /// Formatted price string with currency.
  String get displayPrice =>
      price != null ? "${currency ?? "GBP"} ${price!.toStringAsFixed(2)}" : "";

  /// Whether the scan has an image.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
