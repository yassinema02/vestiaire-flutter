import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "badge_collection_grid.dart";

/// A celebratory modal dialog displayed when the user earns a new badge.
///
/// Shows the badge icon, name, description, and a "Continue" button.
class BadgeAwardedModal extends StatelessWidget {
  const BadgeAwardedModal({
    required this.name,
    required this.description,
    required this.iconName,
    required this.iconColor,
    super.key,
  });

  /// The badge name.
  final String name;

  /// The badge description.
  final String description;

  /// The icon name (maps to Flutter IconData via badgeIconMap).
  final String iconName;

  /// The hex color string for the icon.
  final String iconColor;

  @override
  Widget build(BuildContext context) {
    final iconData = badgeIconMap[iconName] ?? Icons.help_outline;
    final color = _parseHexColor(iconColor);

    return Semantics(
      label: "Badge earned: $name",
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: 64,
              color: color,
            ),
            const SizedBox(height: 12),
            const Text(
              "Badge Earned!",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
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
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Continue"),
            ),
          ),
        ],
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

/// Show badge awarded modals sequentially for each badge in the list.
///
/// Displays each badge modal one at a time, waiting for the user to dismiss
/// each before showing the next. Uses scale-in animation and haptic feedback.
Future<void> showBadgeAwardedModals(
  BuildContext context,
  List<Map<String, dynamic>> badges,
) async {
  for (final badge in badges) {
    HapticFeedback.mediumImpact();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss badge modal",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return BadgeAwardedModal(
          name: badge["name"] as String? ?? "",
          description: badge["description"] as String? ?? "",
          iconName: badge["iconName"] as String? ?? "",
          iconColor: badge["iconColor"] as String? ?? "#FBBF24",
        );
      },
    );
  }
}
