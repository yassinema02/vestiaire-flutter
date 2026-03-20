import "package:flutter/material.dart";

/// A modal bottom sheet displaying detailed streak information.
///
/// Shows current streak, longest streak, freeze status, and an explanation
/// of how streaks and freezes work.
class StreakDetailSheet extends StatelessWidget {
  const StreakDetailSheet({
    required this.currentStreak,
    required this.longestStreak,
    required this.streakFreezeAvailable,
    this.streakFreezeUsedAt,
    this.lastStreakDate,
    super.key,
  });

  /// Current consecutive day streak count.
  final int currentStreak;

  /// All-time longest streak count.
  final int longestStreak;

  /// Whether the weekly streak freeze is available.
  final bool streakFreezeAvailable;

  /// ISO date string when the freeze was last used, or null.
  final String? streakFreezeUsedAt;

  /// ISO date string of the last streak date, or null.
  final String? lastStreakDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Semantics(
            label: "Streak Details",
            header: true,
            child: const Text(
              "Streak Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Large flame icon with streak count
          Center(
            child: Semantics(
              label: "Current streak: $currentStreak days",
              child: Column(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 48,
                    color: currentStreak > 0
                        ? const Color(0xFFF97316)
                        : const Color(0xFFD1D5DB),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$currentStreak",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats rows
          Semantics(
            label: "Current Streak: $currentStreak days",
            child: _buildStatRow("Current Streak", "$currentStreak days"),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: "Longest Streak: $longestStreak days",
            child: _buildStatRow("Longest Streak", "$longestStreak days"),
          ),

          const Divider(height: 32),

          // Freeze section
          Semantics(
            label: streakFreezeAvailable
                ? "Streak freeze available"
                : "Streak freeze used this week",
            child: Row(
              children: [
                Icon(
                  Icons.ac_unit,
                  size: 20,
                  color: streakFreezeAvailable
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    streakFreezeAvailable
                        ? "You have 1 freeze this week"
                        : streakFreezeUsedAt != null
                            ? "Freeze used on $streakFreezeUsedAt"
                            : "Freeze used",
                    style: TextStyle(
                      fontSize: 14,
                      color: streakFreezeAvailable
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Explanation
          Semantics(
            label: "How streaks work explanation",
            child: const Text(
              "Log an outfit every day to build your streak. If you miss a day, your weekly streak freeze will automatically protect your streak.",
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}
