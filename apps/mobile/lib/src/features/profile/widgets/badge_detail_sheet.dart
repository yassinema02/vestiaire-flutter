import "package:flutter/material.dart";

import "badge_collection_grid.dart";

/// A modal bottom sheet displaying detailed badge information.
///
/// Shows the badge icon, name, description, and earned status.
/// For earned badges, shows the earned date. For unearned badges,
/// shows encouragement text with the requirement description.
class BadgeDetailSheet extends StatelessWidget {
  const BadgeDetailSheet({
    required this.badge,
    required this.isEarned,
    this.awardedAt,
    super.key,
  });

  /// The badge data map with keys: name, description, iconName, iconColor.
  final Map<String, dynamic> badge;

  /// Whether the user has earned this badge.
  final bool isEarned;

  /// ISO date string when the badge was earned, or null.
  final String? awardedAt;

  @override
  Widget build(BuildContext context) {
    final iconName = badge["iconName"] as String? ?? "";
    final iconColor = badge["iconColor"] as String? ?? "#D1D5DB";
    final name = badge["name"] as String? ?? "";
    final description = badge["description"] as String? ?? "";

    final iconData = badgeIconMap[iconName] ?? Icons.help_outline;
    final color = isEarned ? _parseHexColor(iconColor) : const Color(0xFFD1D5DB);

    return Semantics(
      label: "Badge detail: $name",
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (isEarned && awardedAt != null)
              Semantics(
                label: "Earned on ${_formatDate(awardedAt!)}",
                child: Text(
                  "Earned on ${_formatDate(awardedAt!)}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                  ),
                ),
              )
            else if (!isEarned)
              Semantics(
                label: "Keep going! $description",
                child: Text(
                  "Keep going! $description",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return isoDate;
    }
  }

  Color _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst("#", "");
    if (cleaned.length == 6) {
      return Color(int.parse("FF$cleaned", radix: 16));
    }
    return const Color(0xFFD1D5DB);
  }
}

/// Show a badge detail bottom sheet.
void showBadgeDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> badge,
  required bool isEarned,
  String? awardedAt,
}) {
  showModalBottomSheet(
    context: context,
    builder: (_) => BadgeDetailSheet(
      badge: badge,
      isEarned: isEarned,
      awardedAt: awardedAt,
    ),
  );
}
