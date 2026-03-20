/// Model representing a category in a packing list.
class PackingListCategory {
  const PackingListCategory({
    required this.name,
    required this.items,
  });

  final String name;
  final List<PackingListItem> items;

  factory PackingListCategory.fromJson(Map<String, dynamic> json) {
    final itemsList = (json["items"] as List<dynamic>?)
            ?.map((i) => PackingListItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];
    return PackingListCategory(
      name: json["name"] as String? ?? "",
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "items": items.map((i) => i.toJson()).toList(),
      };
}

/// Model representing an item in a packing list.
class PackingListItem {
  PackingListItem({
    this.itemId,
    required this.name,
    required this.reason,
    this.thumbnailUrl,
    this.category,
    this.color,
    this.isPacked = false,
  });

  final String? itemId;
  final String name;
  final String reason;
  final String? thumbnailUrl;
  final String? category;
  final String? color;
  bool isPacked;

  factory PackingListItem.fromJson(Map<String, dynamic> json) {
    return PackingListItem(
      itemId: json["itemId"] as String?,
      name: json["name"] as String? ?? "",
      reason: json["reason"] as String? ?? "",
      thumbnailUrl: json["thumbnailUrl"] as String?,
      category: json["category"] as String?,
      color: json["color"] as String?,
      isPacked: json["isPacked"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        "itemId": itemId,
        "name": name,
        "reason": reason,
        "thumbnailUrl": thumbnailUrl,
        "category": category,
        "color": color,
        "isPacked": isPacked,
      };
}

/// Model representing a daily outfit suggestion.
class DailyOutfit {
  const DailyOutfit({
    required this.day,
    required this.date,
    required this.outfitItemIds,
    required this.occasion,
  });

  final int day;
  final DateTime date;
  final List<String> outfitItemIds;
  final String occasion;

  factory DailyOutfit.fromJson(Map<String, dynamic> json) {
    return DailyOutfit(
      day: (json["day"] as num?)?.toInt() ?? 1,
      date: DateTime.tryParse(json["date"] as String? ?? "") ?? DateTime.now(),
      outfitItemIds: (json["outfitItemIds"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      occasion: json["occasion"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "day": day,
        "date": date.toIso8601String().split("T")[0],
        "outfitItemIds": outfitItemIds,
        "occasion": occasion,
      };
}

/// Model representing a complete packing list.
class PackingList {
  const PackingList({
    required this.categories,
    required this.dailyOutfits,
    required this.tips,
    required this.fallback,
    required this.generatedAt,
    this.weatherUnavailable = false,
  });

  final List<PackingListCategory> categories;
  final List<DailyOutfit> dailyOutfits;
  final List<String> tips;
  final bool fallback;
  final DateTime generatedAt;
  final bool weatherUnavailable;

  /// Total number of packable items across all categories.
  int get totalItems {
    int total = 0;
    for (final category in categories) {
      total += category.items.length;
    }
    return total;
  }

  factory PackingList.fromJson(Map<String, dynamic> json) {
    final packingListData = json["packingList"] as Map<String, dynamic>? ?? json;

    final categories = (packingListData["categories"] as List<dynamic>?)
            ?.map((c) =>
                PackingListCategory.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    final dailyOutfits = (packingListData["dailyOutfits"] as List<dynamic>?)
            ?.map((o) => DailyOutfit.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];
    final tips = (packingListData["tips"] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        [];

    return PackingList(
      categories: categories,
      dailyOutfits: dailyOutfits,
      tips: tips,
      fallback: packingListData["fallback"] as bool? ?? false,
      weatherUnavailable:
          packingListData["weatherUnavailable"] as bool? ?? false,
      generatedAt: DateTime.tryParse(
              json["generatedAt"] as String? ?? "") ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        "packingList": {
          "categories": categories.map((c) => c.toJson()).toList(),
          "dailyOutfits": dailyOutfits.map((o) => o.toJson()).toList(),
          "tips": tips,
          "fallback": fallback,
          "weatherUnavailable": weatherUnavailable,
        },
        "generatedAt": generatedAt.toIso8601String(),
      };
}
