import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Milestone names for streak achievements.
const Map<int, String> streakMilestones = {
  7: "Week Warrior",
  14: "Two Week Champion",
  30: "Streak Legend",
  50: "Streak Master",
  100: "Streak Centurion",
};

/// A toast widget that displays streak celebration information.
///
/// Shows a flame icon and "N Day Streak!" text. If the streak count
/// matches a milestone (7, 14, 30, 50, 100), an additional line with
/// the milestone name is shown in gold.
class StreakCelebrationToast extends StatelessWidget {
  const StreakCelebrationToast({
    required this.currentStreak,
    this.isNewStreak = false,
    super.key,
  });

  /// The current streak count.
  final int currentStreak;

  /// Whether this is a brand new streak (first day).
  final bool isNewStreak;

  /// Returns the milestone label if the current streak is a milestone, or null.
  String? get _milestoneLabel => streakMilestones[currentStreak];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isNewStreak
          ? "New streak started"
          : "Streak extended to $currentStreak days",
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
                  Icons.local_fire_department,
                  size: 20,
                  color: Color(0xFFF97316),
                ),
                const SizedBox(width: 8),
                Text(
                  "$currentStreak Day Streak!",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (_milestoneLabel != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  _milestoneLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFBBF24),
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

/// Show a streak celebration toast as a floating SnackBar.
///
/// Triggers light haptic feedback and displays the toast for 2.5 seconds.
void showStreakCelebrationToast(
  BuildContext context, {
  required int currentStreak,
  bool isNewStreak = false,
}) {
  HapticFeedback.lightImpact();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: StreakCelebrationToast(
        currentStreak: currentStreak,
        isNewStreak: isNewStreak,
      ),
      duration: const Duration(milliseconds: 2500),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
