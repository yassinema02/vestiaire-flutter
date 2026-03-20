import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// A celebratory modal displayed when a challenge is completed.
///
/// Shows a trophy icon, challenge completion title, reward description,
/// and a dismiss button. Uses scale-in animation and haptic feedback.
class ChallengeCompletionModal extends StatelessWidget {
  const ChallengeCompletionModal({
    required this.challengeName,
    required this.rewardDescription,
    this.trialExpiresAt,
    super.key,
  });

  /// The name of the completed challenge.
  final String challengeName;

  /// Description of the reward (e.g., "1 month Premium free").
  final String rewardDescription;

  /// Optional ISO 8601 timestamp for when the trial expires.
  final String? trialExpiresAt;

  @override
  Widget build(BuildContext context) {
    String? formattedExpiry;
    if (trialExpiresAt != null) {
      try {
        final date = DateTime.parse(trialExpiresAt!);
        formattedExpiry =
            "${date.day}/${date.month}/${date.year}";
      } catch (_) {
        // Ignore parse failures
      }
    }

    return Semantics(
      label:
          "Congratulations! Closet Safari complete. Premium unlocked for 30 days.",
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 64,
              color: Color(0xFFFBBF24),
            ),
            const SizedBox(height: 16),
            Text(
              "$challengeName Complete!",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You've unlocked $rewardDescription!",
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4B5563),
              ),
              textAlign: TextAlign.center,
            ),
            if (formattedExpiry != null) ...[
              const SizedBox(height: 8),
              Text(
                "Your Premium trial expires on $formattedExpiry",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                ),
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the challenge completion modal with scale-in animation and haptic feedback.
void showChallengeCompletionModal(
  BuildContext context, {
  required String challengeName,
  required String rewardDescription,
  String? trialExpiresAt,
}) {
  HapticFeedback.heavyImpact();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Dismiss challenge completion",
    pageBuilder: (context, animation, secondaryAnimation) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: ChallengeCompletionModal(
          challengeName: challengeName,
          rewardDescription: rewardDescription,
          trialExpiresAt: trialExpiresAt,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}
