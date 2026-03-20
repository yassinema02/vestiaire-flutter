import "package:flutter/material.dart";

/// Maps badge icon_name strings from the API to Flutter IconData constants.
const Map<String, IconData> badgeIconMap = {
  "star": Icons.star,
  "checkroom": Icons.checkroom,
  "local_fire_department": Icons.local_fire_department,
  "wb_sunny": Icons.wb_sunny,
  "recycling": Icons.recycling,
  "sell": Icons.sell,
  "volunteer_activism": Icons.volunteer_activism,
  "palette": Icons.palette,
  "verified": Icons.verified,
  "thunderstorm": Icons.thunderstorm,
  "school": Icons.school,
  "eco": Icons.eco,
  "emoji_events": Icons.emoji_events,
};

/// A grid displaying all badges, with earned badges colored and unearned grayed out.
///
/// Shows a 3-column grid of badge cells. Each cell displays the badge icon
/// and name, styled based on whether the user has earned the badge.
class BadgeCollectionGrid extends StatelessWidget {
  const BadgeCollectionGrid({
    required this.allBadges,
    required this.earnedBadges,
    this.onBadgeTap,
    super.key,
  });

  /// The full badge catalog (all 15 definitions).
  final List<Map<String, dynamic>> allBadges;

  /// The user's earned badges.
  final List<Map<String, dynamic>> earnedBadges;

  /// Called when a badge cell is tapped.
  final void Function(Map<String, dynamic> badge, bool isEarned)? onBadgeTap;

  bool _isEarned(String key) {
    return earnedBadges.any((b) => b["key"] == key);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: allBadges.map((badge) {
        final key = badge["key"] as String? ?? "";
        final isEarned = _isEarned(key);
        return _BadgeCell(
          badge: badge,
          isEarned: isEarned,
          onTap: onBadgeTap != null ? () => onBadgeTap!(badge, isEarned) : null,
        );
      }).toList(),
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({
    required this.badge,
    required this.isEarned,
    this.onTap,
  });

  final Map<String, dynamic> badge;
  final bool isEarned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconName = badge["iconName"] as String? ?? "";
    final iconColor = badge["iconColor"] as String? ?? "#D1D5DB";
    final name = badge["name"] as String? ?? "";

    final iconData = badgeIconMap[iconName] ?? Icons.help_outline;
    final color = isEarned ? _parseHexColor(iconColor) : const Color(0xFFD1D5DB);
    final nameColor =
        isEarned ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF);

    return Semantics(
      label: "Badge: $name, ${isEarned ? 'earned' : 'locked'}",
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isEarned
                ? Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  color: nameColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst("#", "");
    if (cleaned.length == 6) {
      return Color(int.parse("FF$cleaned", radix: 16));
    }
    return const Color(0xFFD1D5DB);
  }
}
