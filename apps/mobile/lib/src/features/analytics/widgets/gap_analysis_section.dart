import "package:flutter/material.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";

/// A section displaying wardrobe gap analysis with severity badges,
/// dimension grouping, dismiss functionality, and AI recommendations.
///
/// Premium-gated: free users see a [PremiumGateCard] instead of the actual
/// gap analysis data.
class GapAnalysisSection extends StatelessWidget {
  const GapAnalysisSection({
    required this.isPremium,
    required this.gaps,
    required this.totalItems,
    required this.onDismissGap,
    required this.dismissedGapIds,
    this.subscriptionService,
    super.key,
  });

  final bool isPremium;
  final List<Map<String, dynamic>> gaps;
  final int totalItems;
  final ValueChanged<String> onDismissGap;
  final Set<String> dismissedGapIds;
  final SubscriptionService? subscriptionService;

  static const _dimensionLabels = <String, String>{
    "category": "Category Balance",
    "weather": "Weather Coverage",
    "formality": "Formality Spectrum",
    "color": "Color Range",
  };

  static const _dimensionOrder = ["category", "weather", "formality", "color"];

  static IconData _dimensionIcon(String dimension) {
    switch (dimension) {
      case "category":
        return Icons.category_outlined;
      case "formality":
        return Icons.business_center_outlined;
      case "color":
        return Icons.palette_outlined;
      case "weather":
        return Icons.wb_sunny_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case "critical":
        return const Color(0xFFEF4444);
      case "important":
        return const Color(0xFFF59E0B);
      case "optional":
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static String _severityLabel(String severity) {
    switch (severity) {
      case "critical":
        return "Critical";
      case "important":
        return "Important";
      case "optional":
        return "Optional";
      default:
        return severity;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isPremium) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: PremiumGateCard(
          title: "Wardrobe Gap Analysis",
          subtitle: "Discover what's missing from your wardrobe",
          icon: Icons.search_outlined,
          subscriptionService: subscriptionService,
        ),
      );
    }

    final visibleGaps = gaps
        .where((g) => !dismissedGapIds.contains(g["id"] as String?))
        .toList();

    return Semantics(
      label: "Wardrobe gap analysis, ${visibleGaps.length} gaps detected",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                const Text(
                  "Wardrobe Gaps",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message:
                      "AI-powered analysis of what's missing from your wardrobe.",
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Empty / insufficient items states
            if (totalItems < 5)
              _buildEmptyState(
                icon: Icons.search_off,
                iconColor: const Color(0xFF9CA3AF),
                message:
                    "Add more items to your wardrobe to see gap analysis! At least 5 items are needed.",
              )
            else if (visibleGaps.isEmpty)
              _buildEmptyState(
                icon: Icons.check_circle_outlined,
                iconColor: const Color(0xFF22C55E),
                message:
                    "Your wardrobe is well-balanced! No gaps detected.",
              )
            else
              _buildGroupedGaps(visibleGaps),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedGaps(List<Map<String, dynamic>> visibleGaps) {
    // Group by dimension
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final gap in visibleGaps) {
      final dim = gap["dimension"] as String? ?? "other";
      grouped.putIfAbsent(dim, () => []).add(gap);
    }

    final children = <Widget>[];
    for (final dim in _dimensionOrder) {
      final dimGaps = grouped[dim];
      if (dimGaps == null || dimGaps.isEmpty) continue;

      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            _dimensionLabels[dim] ?? dim,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
      );

      for (final gap in dimGaps) {
        children.add(_buildGapCard(gap));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildGapCard(Map<String, dynamic> gap) {
    final id = gap["id"] as String? ?? "";
    final dimension = gap["dimension"] as String? ?? "";
    final title = gap["title"] as String? ?? "";
    final description = gap["description"] as String? ?? "";
    final severity = gap["severity"] as String? ?? "optional";
    final recommendation = gap["recommendation"] as String?;

    return Semantics(
      label:
          "Gap: $title, severity $severity, ${recommendation ?? "no recommendation"}",
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _dimensionIcon(dimension),
                        size: 20,
                        color: const Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      // Severity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _severityColor(severity),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _severityLabel(severity),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (recommendation != null)
                    Text(
                      recommendation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4F46E5),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    const Text(
                      "AI recommendation unavailable",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
            // Dismiss button
            Positioned(
              top: -8,
              right: -8,
              child: Semantics(
                label: "Dismiss gap $title",
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => onDismissGap(id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
