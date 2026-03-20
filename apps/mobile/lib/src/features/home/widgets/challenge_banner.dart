import "package:flutter/material.dart";

/// A compact banner showing active challenge progress on the Home screen.
///
/// Displays challenge name, progress (X/Y), time remaining, and a progress bar.
/// Tappable to navigate to the full challenge view.
class ChallengeBanner extends StatelessWidget {
  const ChallengeBanner({
    required this.name,
    required this.currentProgress,
    required this.targetCount,
    this.timeRemainingSeconds,
    this.onTap,
    super.key,
  });

  /// The challenge name (e.g., "Closet Safari").
  final String name;

  /// Current progress count.
  final int currentProgress;

  /// Target count to complete.
  final int targetCount;

  /// Seconds remaining until expiry.
  final int? timeRemainingSeconds;

  /// Called when the banner is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final daysLeft = timeRemainingSeconds != null
        ? (timeRemainingSeconds! / 86400).ceil()
        : null;
    final progress = targetCount > 0 ? currentProgress / targetCount : 0.0;

    return Semantics(
      label:
          "Closet Safari challenge: $currentProgress of $targetCount items${daysLeft != null ? ', $daysLeft days remaining' : ''}",
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.explore, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "$name: $currentProgress/$targetCount${daysLeft != null ? ' -- $daysLeft days left' : ''}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
