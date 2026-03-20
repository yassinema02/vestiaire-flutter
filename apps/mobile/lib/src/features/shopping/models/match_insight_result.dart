import "package:flutter/material.dart";

import "shopping_scan.dart";

/// Represents a wardrobe item match from the insight analysis.
///
/// Story 8.5: Shopping Match & Insight Display (FR-SHP-08)
class WardrobeMatch {
  const WardrobeMatch({
    required this.itemId,
    this.itemName,
    this.itemImageUrl,
    this.category,
    required this.matchReasons,
  });

  final String itemId;
  final String? itemName;
  final String? itemImageUrl;
  final String? category;
  final List<String> matchReasons;

  factory WardrobeMatch.fromJson(Map<String, dynamic> json) {
    return WardrobeMatch(
      itemId: json["itemId"] as String,
      itemName: json["itemName"] as String?,
      itemImageUrl: json["itemImageUrl"] as String?,
      category: json["category"] as String?,
      matchReasons: json["matchReasons"] != null
          ? (json["matchReasons"] as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : <String>[],
    );
  }
}

/// Represents an AI-generated shopping insight.
///
/// Story 8.5: Shopping Match & Insight Display (FR-SHP-09)
class ShoppingInsight {
  const ShoppingInsight({
    required this.type,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String type;
  final String title;
  final String body;
  final IconData icon;

  factory ShoppingInsight.fromJson(Map<String, dynamic> json) {
    final type = json["type"] as String? ?? "style_feedback";
    return ShoppingInsight(
      type: type,
      title: json["title"] as String? ?? "Analysis",
      body: json["body"] as String? ?? "",
      icon: _iconForType(type),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case "style_feedback":
        return Icons.palette;
      case "gap_assessment":
        return Icons.space_dashboard;
      case "value_proposition":
        return Icons.trending_up;
      default:
        return Icons.palette;
    }
  }
}

/// Combined result from the insights endpoint.
///
/// Story 8.5: Shopping Match & Insight Display (FR-SHP-08, FR-SHP-09)
class MatchInsightResult {
  const MatchInsightResult({
    required this.scan,
    required this.matches,
    required this.insights,
  });

  final ShoppingScan scan;
  final List<WardrobeMatch> matches;
  final List<ShoppingInsight> insights;

  factory MatchInsightResult.fromJson(Map<String, dynamic> json) {
    final scanJson = json["scan"] as Map<String, dynamic>;
    final matchesList = json["matches"] as List<dynamic>? ?? [];
    final insightsList = json["insights"] as List<dynamic>? ?? [];

    return MatchInsightResult(
      scan: ShoppingScan.fromJson(scanJson),
      matches: matchesList
          .map((m) => WardrobeMatch.fromJson(m as Map<String, dynamic>))
          .toList(),
      insights: insightsList
          .map((i) => ShoppingInsight.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
