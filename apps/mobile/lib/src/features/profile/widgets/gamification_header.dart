import "package:flutter/material.dart";

/// Level names used for calculating next level name from threshold.
const Map<int, String> _nextLevelNames = {
  10: "Style Starter",
  25: "Fashion Explorer",
  50: "Wardrobe Pro",
  100: "Style Expert",
  200: "Style Master",
};

/// A profile header widget displaying the user's gamification stats.
///
/// Shows the current level, XP progress bar, total points, current streak,
/// and wardrobe item count. The streak chip includes a freeze indicator
/// (snowflake icon) and is tappable to open streak details.
class GamificationHeader extends StatelessWidget {
  const GamificationHeader({
    required this.currentLevel,
    required this.currentLevelName,
    required this.totalPoints,
    required this.currentStreak,
    required this.itemCount,
    this.nextLevelThreshold,
    this.streakFreezeAvailable = true,
    this.onStreakTap,
    super.key,
  });

  /// The user's current level number (1-6).
  final int currentLevel;

  /// The user's current level name (e.g., "Style Starter").
  final String currentLevelName;

  /// Total style points earned.
  final int totalPoints;

  /// Current daily streak count.
  final int currentStreak;

  /// Total wardrobe item count.
  final int itemCount;

  /// Item count threshold for the next level, or null if at max.
  final int? nextLevelThreshold;

  /// Whether the weekly streak freeze is available.
  final bool streakFreezeAvailable;

  /// Called when the streak area is tapped.
  final VoidCallback? onStreakTap;

  bool get _isMaxLevel => nextLevelThreshold == null;

  double get _progressValue {
    if (_isMaxLevel) return 1.0;
    if (nextLevelThreshold == 0) return 1.0;
    return (itemCount / nextLevelThreshold!).clamp(0.0, 1.0);
  }

  String? get _nextLevelName {
    if (nextLevelThreshold == null) return null;
    return _nextLevelNames[nextLevelThreshold];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: level name + level chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentLevelName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Level $currentLevel",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar section
          if (_isMaxLevel) ...[
            const Text(
              "Max Level Reached",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ] else ...[
            Text(
              "Progress to ${_nextLevelName ?? "next level"}",
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: _progressValue,
                color: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFE5E7EB),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (!_isMaxLevel)
            Text(
              "$itemCount / $nextLevelThreshold items",
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                icon: Icons.auto_awesome,
                iconColor: const Color(0xFFFBBF24),
                value: "$totalPoints",
                semanticsLabel: "Total points: $totalPoints",
              ),
              GestureDetector(
                onTap: onStreakTap,
                child: Semantics(
                  label: "Current streak: $currentStreak days. ${streakFreezeAvailable ? "Streak freeze available" : "Streak freeze used this week"}",
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 20,
                        color: currentStreak > 0
                            ? const Color(0xFFF97316)
                            : const Color(0xFFD1D5DB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$currentStreak",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.ac_unit,
                        size: 12,
                        color: streakFreezeAvailable
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              ),
              _StatChip(
                icon: Icons.checkroom,
                iconColor: const Color(0xFF2563EB),
                value: "$itemCount",
                semanticsLabel: "Wardrobe items: $itemCount",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.semanticsLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}
