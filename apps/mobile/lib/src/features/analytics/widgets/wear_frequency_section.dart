import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

/// Displays a bar chart of wear frequency by day of the week.
class WearFrequencySection extends StatelessWidget {
  const WearFrequencySection({
    required this.days,
    super.key,
  });

  final List<Map<String, dynamic>> days;

  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _secondaryColor = Color(0xFFC7D2FE);
  static const List<String> _dayLabels = [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ];

  bool get _allZero {
    if (days.isEmpty) return true;
    return days.every(
        (d) => ((d["logCount"] as num?)?.toInt() ?? 0) == 0);
  }

  @override
  Widget build(BuildContext context) {
    // Determine the current day index (Mon=0, ..., Sun=6)
    final todayIndex = DateTime.now().weekday - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Wear Frequency",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          if (_allZero)
            _buildEmptyState()
          else
            Semantics(
              label: "Wear frequency chart, weekly distribution",
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: BarChart(
                  BarChartData(
                    barGroups: _buildBarGroups(todayIndex),
                    titlesData: _buildTitlesData(),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barTouchData: BarTouchData(
                      enabled: false,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 4,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            rod.toY.toInt().toString(),
                            const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(int todayIndex) {
    return List.generate(7, (index) {
      final logCount = (index < days.length)
          ? ((days[index]["logCount"] as num?)?.toDouble() ?? 0)
          : 0.0;
      final isToday = index == todayIndex;

      return BarChartGroupData(
        x: index,
        showingTooltipIndicators: [0],
        barRods: [
          BarChartRodData(
            toY: logCount,
            color: isToday ? _primaryColor : _secondaryColor,
            width: 28,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= _dayLabels.length) {
              return const SizedBox.shrink();
            }
            final dayName = _dayLabels[index];
            final count = (index < days.length)
                ? ((days[index]["logCount"] as num?)?.toInt() ?? 0)
                : 0;
            return Semantics(
              label: "$dayName, $count outfits logged",
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  dayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            "Start logging outfits to see your weekly patterns!",
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
