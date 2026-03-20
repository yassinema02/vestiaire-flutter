import "package:flutter/material.dart";

/// Match quality tier for steal-look results.
///
/// Story 9.5: "Steal This Look" Matcher (FR-SOC-13)
enum MatchTier {
  excellent,
  good,
  partial;

  Color get color {
    switch (this) {
      case MatchTier.excellent:
        return const Color(0xFF22C55E);
      case MatchTier.good:
        return const Color(0xFF3B82F6);
      case MatchTier.partial:
        return const Color(0xFFF59E0B);
    }
  }

  String get label {
    switch (this) {
      case MatchTier.excellent:
        return "Excellent Match";
      case MatchTier.good:
        return "Good Match";
      case MatchTier.partial:
        return "Partial Match";
    }
  }
}

/// A single matched wardrobe item from the steal-look response.
class StealLookMatch {
  const StealLookMatch({
    required this.itemId,
    this.name,
    this.category,
    this.color,
    this.photoUrl,
    required this.matchScore,
    this.matchReason,
  });

  final String itemId;
  final String? name;
  final String? category;
  final String? color;
  final String? photoUrl;
  final int matchScore;
  final String? matchReason;

  MatchTier get tier {
    if (matchScore >= 80) return MatchTier.excellent;
    if (matchScore >= 60) return MatchTier.good;
    return MatchTier.partial;
  }

  factory StealLookMatch.fromJson(Map<String, dynamic> json) {
    return StealLookMatch(
      itemId: json["itemId"] as String,
      name: json["name"] as String?,
      category: json["category"] as String?,
      color: json["color"] as String?,
      photoUrl: json["photoUrl"] as String?,
      matchScore: json["matchScore"] as int? ?? 0,
      matchReason: json["matchReason"] as String?,
    );
  }
}

/// The source item from the friend's post.
class StealLookSourceItem {
  const StealLookSourceItem({
    required this.id,
    this.name,
    this.category,
    this.color,
    this.photoUrl,
  });

  final String id;
  final String? name;
  final String? category;
  final String? color;
  final String? photoUrl;

  factory StealLookSourceItem.fromJson(Map<String, dynamic> json) {
    return StealLookSourceItem(
      id: json["id"] as String,
      name: json["name"] as String?,
      category: json["category"] as String?,
      color: json["color"] as String?,
      photoUrl: json["photoUrl"] as String?,
    );
  }
}

/// A source item paired with its matched wardrobe items.
class StealLookSourceMatch {
  const StealLookSourceMatch({
    required this.sourceItem,
    required this.matches,
  });

  final StealLookSourceItem sourceItem;
  final List<StealLookMatch> matches;

  factory StealLookSourceMatch.fromJson(Map<String, dynamic> json) {
    final matchList = json["matches"] as List<dynamic>? ?? [];
    return StealLookSourceMatch(
      sourceItem: StealLookSourceItem.fromJson(
          json["sourceItem"] as Map<String, dynamic>),
      matches:
          matchList.map((m) => StealLookMatch.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

/// Full steal-look result containing all source matches.
class StealLookResult {
  const StealLookResult({required this.sourceMatches});

  final List<StealLookSourceMatch> sourceMatches;

  factory StealLookResult.fromJson(Map<String, dynamic> json) {
    final list = json["sourceMatches"] as List<dynamic>? ?? [];
    return StealLookResult(
      sourceMatches: list
          .map((m) =>
              StealLookSourceMatch.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
