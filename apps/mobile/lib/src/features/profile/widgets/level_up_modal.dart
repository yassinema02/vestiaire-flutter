import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Level names used for calculating next level name from threshold.
const Map<int, String> _levelNames = {
  1: "Closet Rookie",
  2: "Style Starter",
  3: "Fashion Explorer",
  4: "Wardrobe Pro",
  5: "Style Expert",
  6: "Style Master",
};

/// A celebratory modal dialog displayed when the user levels up.
///
/// Shows the new level name, a congratulatory message, next level info,
/// and a "Continue" button to dismiss.
class LevelUpModal extends StatelessWidget {
  const LevelUpModal({
    required this.newLevel,
    required this.newLevelName,
    this.previousLevelName,
    this.nextLevelThreshold,
    super.key,
  });

  /// The new level number (e.g., 2).
  final int newLevel;

  /// The new level name (e.g., "Style Starter").
  final String newLevelName;

  /// The previous level name (e.g., "Closet Rookie").
  final String? previousLevelName;

  /// The item count threshold for the next level, or null if at max.
  final int? nextLevelThreshold;

  String? get _nextLevelName {
    if (nextLevelThreshold == null) return null;
    // Find the level name that corresponds to the next threshold
    const thresholdToLevel = {10: 2, 25: 3, 50: 4, 100: 5, 200: 6};
    final nextLevel = thresholdToLevel[nextLevelThreshold];
    if (nextLevel == null) return null;
    return _levelNames[nextLevel];
  }

  @override
  Widget build(BuildContext context) {
    final nextName = _nextLevelName;

    return Semantics(
      label: "Congratulations! You've reached level $newLevel, $newLevelName",
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: Color(0xFFFBBF24),
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                newLevelName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You've reached Level $newLevel!",
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4B5563),
              ),
            ),
            if (nextLevelThreshold != null && nextName != null) ...[
              const SizedBox(height: 8),
              Text(
                "Next: $nextName at $nextLevelThreshold items",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
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
}

/// Show a level-up celebration modal with scale-in animation.
///
/// Displays the [LevelUpModal] via [showGeneralDialog] with a
/// [ScaleTransition] animation. Triggers medium haptic feedback.
void showLevelUpModal(
  BuildContext context, {
  required int newLevel,
  required String newLevelName,
  String? previousLevelName,
  int? nextLevelThreshold,
}) {
  HapticFeedback.mediumImpact();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Dismiss level up modal",
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
      return LevelUpModal(
        newLevel: newLevel,
        newLevelName: newLevelName,
        previousLevelName: previousLevelName,
        nextLevelThreshold: nextLevelThreshold,
      );
    },
  );
}
