import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// A toast widget that displays style points earned.
///
/// Shows a sparkle icon and "+N Style Points" text with an optional
/// bonus label. Used as the content of a floating SnackBar.
class StylePointsToast extends StatelessWidget {
  const StylePointsToast({
    required this.pointsAwarded,
    this.bonusLabel,
    super.key,
  });

  /// The number of style points awarded.
  final int pointsAwarded;

  /// Optional bonus description (e.g., "Streak Bonus!").
  final String? bonusLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Earned $pointsAwarded style points",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 8),
                Text(
                  "+$pointsAwarded Style Points",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (bonusLabel != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  bonusLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Show a style points toast as a floating SnackBar.
///
/// Triggers light haptic feedback and displays the toast for 2 seconds
/// with a fade-out animation.
void showStylePointsToast(
  BuildContext context, {
  required int pointsAwarded,
  String? bonusLabel,
}) {
  HapticFeedback.lightImpact();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: StylePointsToast(
        pointsAwarded: pointsAwarded,
        bonusLabel: bonusLabel,
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
