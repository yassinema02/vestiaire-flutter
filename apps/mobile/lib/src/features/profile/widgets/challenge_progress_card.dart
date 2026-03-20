import "package:flutter/material.dart";

/// A card showing challenge progress, completion, or expiry state.
///
/// Displays the challenge name, progress bar, time remaining, and reward
/// description. Supports active, completed, expired, and not-accepted states.
class ChallengeProgressCard extends StatelessWidget {
  const ChallengeProgressCard({
    required this.name,
    required this.currentProgress,
    required this.targetCount,
    required this.status,
    this.expiresAt,
    this.timeRemainingSeconds,
    this.rewardDescription,
    this.onAccept,
    super.key,
  });

  /// The challenge name (e.g., "Closet Safari").
  final String name;

  /// Current progress count.
  final int currentProgress;

  /// Target count to complete.
  final int targetCount;

  /// Challenge status: "active", "completed", "expired", or "not_accepted".
  final String status;

  /// ISO 8601 expiry timestamp.
  final String? expiresAt;

  /// Seconds remaining until expiry.
  final int? timeRemainingSeconds;

  /// Reward description (e.g., "Unlock 1 month Premium free").
  final String? rewardDescription;

  /// Called when user taps "Accept Challenge". If null and status is
  /// not "active"/"completed"/"expired", no accept button is shown.
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Challenge: $name, progress $currentProgress of $targetCount items",
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    switch (status) {
      case "completed":
        return _buildCompletedCard();
      case "expired":
        return _buildExpiredCard();
      case "active":
        return _buildActiveCard();
      default:
        if (onAccept != null) {
          return _buildNotAcceptedCard();
        }
        return _buildActiveCard();
    }
  }

  Widget _buildActiveCard() {
    final progress = targetCount > 0 ? currentProgress / targetCount : 0.0;
    final daysLeft = timeRemainingSeconds != null
        ? (timeRemainingSeconds! / 86400).ceil()
        : null;
    final isUrgent = daysLeft != null && daysLeft < 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore, color: Color(0xFF4F46E5), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$currentProgress/$targetCount items",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                ),
              ),
              if (daysLeft != null)
                Text(
                  "$daysLeft days left",
                  style: TextStyle(
                    fontSize: 12,
                    color: isUrgent
                        ? const Color(0xFFF97316)
                        : const Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
          if (rewardDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              rewardDescription!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Closet Safari Complete!",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Premium unlocked for 30 days",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_off, color: Color(0xFF9CA3AF), size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Challenge Expired",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotAcceptedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore, color: Color(0xFF4F46E5), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          if (rewardDescription != null) ...[
            const SizedBox(height: 8),
            Text(
              rewardDescription!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: const Text("Accept Challenge"),
            ),
          ),
        ],
      ),
    );
  }
}
