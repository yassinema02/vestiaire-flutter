import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../models/wear_log.dart";

/// A horizontal row of summary metric cards displayed above the calendar.
///
/// Shows three metrics: Days Logged, Items Logged, and Current Streak.
class MonthSummaryRow extends StatelessWidget {
  const MonthSummaryRow({
    required this.wearLogsByDate,
    required this.currentMonth,
    super.key,
  });

  final Map<String, List<WearLog>> wearLogsByDate;
  final DateTime currentMonth;

  int get daysLogged => wearLogsByDate.keys
      .where((k) => wearLogsByDate[k]!.isNotEmpty)
      .length;

  int get itemsLogged {
    int total = 0;
    for (final logs in wearLogsByDate.values) {
      for (final log in logs) {
        total += log.itemIds.length;
      }
    }
    return total;
  }

  /// Calculate the longest consecutive-day streak ending on today
  /// (or the most recent logged date). Walk backward from today
  /// counting consecutive days that appear in [wearLogsByDate].
  int get currentStreak {
    if (wearLogsByDate.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fmt = DateFormat("yyyy-MM-dd");

    // Start from today and walk backward
    int streak = 0;
    DateTime checkDate = today;

    // If today has no log, check if the most recent date is yesterday
    // (in which case we start from yesterday)
    final todayKey = fmt.format(today);
    if (!wearLogsByDate.containsKey(todayKey)) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = fmt.format(yesterday);
      if (!wearLogsByDate.containsKey(yesterdayKey)) {
        return 0;
      }
      checkDate = yesterday;
    }

    while (true) {
      final key = fmt.format(checkDate);
      if (wearLogsByDate.containsKey(key) &&
          wearLogsByDate[key]!.isNotEmpty) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.calendar_today,
            value: daysLogged,
            label: "Days Logged",
            semanticLabel: "$daysLogged days logged",
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.check_circle_outline,
            value: itemsLogged,
            label: "Items Logged",
            semanticLabel: "$itemsLogged items logged",
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.local_fire_department,
            value: currentStreak,
            label: "Day Streak",
            semanticLabel: "$currentStreak day streak",
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.semanticLabel,
  });

  final IconData icon;
  final int value;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF4F46E5)),
            const SizedBox(height: 4),
            Text(
              "$value",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
