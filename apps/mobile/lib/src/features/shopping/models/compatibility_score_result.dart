import "package:flutter/material.dart";

import "shopping_scan.dart";

/// Breakdown of the 5 compatibility scoring factors.
///
/// Story 8.4: Purchase Compatibility Scoring (FR-SHP-06)
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.colorHarmony,
    required this.styleConsistency,
    required this.gapFilling,
    required this.versatility,
    required this.formalityMatch,
  });

  final int colorHarmony;
  final int styleConsistency;
  final int gapFilling;
  final int versatility;
  final int formalityMatch;

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      colorHarmony: (json["colorHarmony"] as num).toInt(),
      styleConsistency: (json["styleConsistency"] as num).toInt(),
      gapFilling: (json["gapFilling"] as num).toInt(),
      versatility: (json["versatility"] as num).toInt(),
      formalityMatch: (json["formalityMatch"] as num).toInt(),
    );
  }
}

/// Tier information for a compatibility score.
///
/// Story 8.4: Purchase Compatibility Scoring (FR-SHP-07)
class ScoreTier {
  const ScoreTier({
    required this.tier,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String tier;
  final String label;
  final Color color;
  final IconData icon;

  /// Map a tier string to the full ScoreTier with color and icon.
  factory ScoreTier.fromTierString(String tier) {
    switch (tier) {
      case "perfect_match":
        return const ScoreTier(
          tier: "perfect_match",
          label: "Perfect Match",
          color: Color(0xFF22C55E),
          icon: Icons.stars,
        );
      case "great_choice":
        return const ScoreTier(
          tier: "great_choice",
          label: "Great Choice",
          color: Color(0xFF3B82F6),
          icon: Icons.thumb_up,
        );
      case "good_fit":
        return const ScoreTier(
          tier: "good_fit",
          label: "Good Fit",
          color: Color(0xFFF59E0B),
          icon: Icons.check_circle,
        );
      case "might_work":
        return const ScoreTier(
          tier: "might_work",
          label: "Might Work",
          color: Color(0xFFF97316),
          icon: Icons.help_outline,
        );
      case "careful":
      default:
        return const ScoreTier(
          tier: "careful",
          label: "Careful",
          color: Color(0xFFEF4444),
          icon: Icons.warning,
        );
    }
  }

  /// Build a ScoreTier from server JSON (tier, tierLabel, tierColor, tierIcon).
  factory ScoreTier.fromJson(Map<String, dynamic> json) {
    return ScoreTier.fromTierString(json["tier"] as String);
  }
}

/// Full compatibility score result from the API.
///
/// Story 8.4: Purchase Compatibility Scoring (FR-SHP-06, FR-SHP-07)
class CompatibilityScoreResult {
  const CompatibilityScoreResult({
    required this.scan,
    required this.total,
    required this.breakdown,
    required this.tier,
    this.reasoning,
  });

  final ShoppingScan scan;
  final int total;
  final ScoreBreakdown breakdown;
  final ScoreTier tier;
  final String? reasoning;

  factory CompatibilityScoreResult.fromJson(Map<String, dynamic> json) {
    final scoreJson = json["score"] as Map<String, dynamic>;
    final scanJson = json["scan"] as Map<String, dynamic>;

    return CompatibilityScoreResult(
      scan: ShoppingScan.fromJson(scanJson),
      total: (scoreJson["total"] as num).toInt(),
      breakdown: ScoreBreakdown.fromJson(
        scoreJson["breakdown"] as Map<String, dynamic>,
      ),
      tier: ScoreTier.fromTierString(scoreJson["tier"] as String),
      reasoning: scoreJson["reasoning"] as String?,
    );
  }
}
