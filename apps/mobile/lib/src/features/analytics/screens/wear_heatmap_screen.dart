import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/networking/api_client.dart";
import "../models/wear_log.dart";
import "../services/wear_log_service.dart";
import "../widgets/day_detail_bottom_sheet.dart";

/// Heatmap view modes.
enum HeatmapViewMode { month, quarter, year }

/// A full-screen calendar heatmap showing daily wear activity with
/// color intensity proportional to the number of items worn that day.
///
/// Supports Month, Quarter, and Year view modes with navigation.
class WearHeatmapScreen extends StatefulWidget {
  const WearHeatmapScreen({
    required this.apiClient,
    this.wearLogService,
    this.initialDate,
    super.key,
  });

  final ApiClient apiClient;
  final WearLogService? wearLogService;

  /// Optional initial date for testing. Defaults to now.
  final DateTime? initialDate;

  @override
  State<WearHeatmapScreen> createState() => WearHeatmapScreenState();
}

/// Visible for testing.
class WearHeatmapScreenState extends State<WearHeatmapScreen> {
  HeatmapViewMode _viewMode = HeatmapViewMode.month;
  late DateTime _currentDate;
  Map<String, int> _dailyActivity = {};
  Map<String, dynamic> _streakStats = {};
  bool _isLoading = true;
  String? _error;

  // Heatmap color constants
  static const Color _colorNone = Color(0xFFF3F4F6);
  static const Color _colorLight = Color(0xFFBBF7D0);
  static const Color _colorMedium = Color(0xFF4ADE80);
  static const Color _colorDark = Color(0xFF16A34A);

  static Color _intensityColor(int itemsCount) {
    if (itemsCount == 0) return _colorNone;
    if (itemsCount <= 2) return _colorLight;
    if (itemsCount <= 5) return _colorMedium;
    return _colorDark;
  }

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
    _fetchData();
  }

  String _dateRangeStart() {
    switch (_viewMode) {
      case HeatmapViewMode.month:
        return DateFormat("yyyy-MM-dd")
            .format(DateTime(_currentDate.year, _currentDate.month, 1));
      case HeatmapViewMode.quarter:
        final quarterMonth = ((_currentDate.month - 1) ~/ 3) * 3 + 1;
        return DateFormat("yyyy-MM-dd")
            .format(DateTime(_currentDate.year, quarterMonth, 1));
      case HeatmapViewMode.year:
        return "${_currentDate.year}-01-01";
    }
  }

  String _dateRangeEnd() {
    switch (_viewMode) {
      case HeatmapViewMode.month:
        final lastDay =
            DateTime(_currentDate.year, _currentDate.month + 1, 0);
        return DateFormat("yyyy-MM-dd").format(lastDay);
      case HeatmapViewMode.quarter:
        final quarterMonth = ((_currentDate.month - 1) ~/ 3) * 3 + 1;
        final endMonth = quarterMonth + 2;
        final lastDay =
            DateTime(_currentDate.year, endMonth + 1, 0);
        return DateFormat("yyyy-MM-dd").format(lastDay);
      case HeatmapViewMode.year:
        return "${_currentDate.year}-12-31";
    }
  }

  bool _canNavigateForward() {
    final now = DateTime.now();
    switch (_viewMode) {
      case HeatmapViewMode.month:
        return _currentDate.year < now.year ||
            (_currentDate.year == now.year &&
                _currentDate.month < now.month);
      case HeatmapViewMode.quarter:
        final currentQuarter = (_currentDate.month - 1) ~/ 3;
        final nowQuarter = (now.month - 1) ~/ 3;
        return _currentDate.year < now.year ||
            (_currentDate.year == now.year && currentQuarter < nowQuarter);
      case HeatmapViewMode.year:
        return _currentDate.year < now.year;
    }
  }

  void _navigateBack() {
    setState(() {
      switch (_viewMode) {
        case HeatmapViewMode.month:
          _currentDate =
              DateTime(_currentDate.year, _currentDate.month - 1, 1);
          break;
        case HeatmapViewMode.quarter:
          _currentDate =
              DateTime(_currentDate.year, _currentDate.month - 3, 1);
          break;
        case HeatmapViewMode.year:
          _currentDate =
              DateTime(_currentDate.year - 1, _currentDate.month, 1);
          break;
      }
    });
    _fetchData();
  }

  void _navigateForward() {
    if (!_canNavigateForward()) return;
    setState(() {
      switch (_viewMode) {
        case HeatmapViewMode.month:
          _currentDate =
              DateTime(_currentDate.year, _currentDate.month + 1, 1);
          break;
        case HeatmapViewMode.quarter:
          _currentDate =
              DateTime(_currentDate.year, _currentDate.month + 3, 1);
          break;
        case HeatmapViewMode.year:
          _currentDate =
              DateTime(_currentDate.year + 1, _currentDate.month, 1);
          break;
      }
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.apiClient.getHeatmapData(
        startDate: _dateRangeStart(),
        endDate: _dateRangeEnd(),
      );

      if (!mounted) return;

      final activityList =
          (result["dailyActivity"] as List<dynamic>?) ?? [];
      final activityMap = <String, int>{};
      for (final entry in activityList) {
        final map = entry as Map<String, dynamic>;
        activityMap[map["date"] as String] =
            (map["itemsCount"] as num).toInt();
      }

      setState(() {
        _dailyActivity = activityMap;
        _streakStats =
            (result["streakStats"] as Map<String, dynamic>?) ?? {};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onDayTap(DateTime date) async {
    final dateStr = DateFormat("yyyy-MM-dd").format(date);
    final count = _dailyActivity[dateStr] ?? 0;
    if (count == 0) return;

    // Fetch wear logs for this specific day
    List<WearLog> logs = [];
    if (widget.wearLogService != null) {
      try {
        logs = await widget.wearLogService!.getLogsForDateRange(dateStr, dateStr);
      } catch (_) {
        // Best-effort: show empty bottom sheet if fetch fails
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DayDetailBottomSheet(
        date: dateStr,
        wearLogs: logs,
        apiClient: widget.apiClient,
      ),
    );
  }

  void _switchToMonthForDate(DateTime date) {
    setState(() {
      _viewMode = HeatmapViewMode.month;
      _currentDate = DateTime(date.year, date.month, 1);
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Wear Heatmap"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Semantics(
        label: "Wear heatmap, ${_viewMode.name} view",
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32,
                color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchData,
              child: const Text("Retry",
                  style: TextStyle(color: Color(0xFF4F46E5))),
            ),
          ],
        ),
      );
    }

    if (_dailyActivity.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view, size: 32, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            const Text(
              "No wear data yet. Log your outfits to build your heatmap!",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // View mode toggle
          _buildViewModeToggle(),
          const SizedBox(height: 16),

          // Navigation header
          _buildNavigationHeader(),
          const SizedBox(height: 12),

          // Heatmap grid
          _buildHeatmapGrid(),
          const SizedBox(height: 16),

          // Streak statistics
          _buildStreakStats(),
          const SizedBox(height: 12),

          // Color legend
          _buildColorLegend(),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return SegmentedButton<HeatmapViewMode>(
      segments: const [
        ButtonSegment(value: HeatmapViewMode.month, label: Text("Month")),
        ButtonSegment(value: HeatmapViewMode.quarter, label: Text("Quarter")),
        ButtonSegment(value: HeatmapViewMode.year, label: Text("Year")),
      ],
      selected: {_viewMode},
      onSelectionChanged: (selected) {
        setState(() {
          _viewMode = selected.first;
        });
        _fetchData();
      },
      style: SegmentedButton.styleFrom(
        selectedForegroundColor: const Color(0xFF4F46E5),
        selectedBackgroundColor: const Color(0xFFEEF2FF),
      ),
    );
  }

  Widget _buildNavigationHeader() {
    String title;
    switch (_viewMode) {
      case HeatmapViewMode.month:
        title = DateFormat("MMMM yyyy").format(_currentDate);
        break;
      case HeatmapViewMode.quarter:
        final quarter = ((_currentDate.month - 1) ~/ 3) + 1;
        title = "Q$quarter ${_currentDate.year}";
        break;
      case HeatmapViewMode.year:
        title = "${_currentDate.year}";
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _navigateBack,
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: _canNavigateForward()
                ? const Color(0xFF1F2937)
                : const Color(0xFFD1D5DB),
          ),
          onPressed: _canNavigateForward() ? _navigateForward : null,
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid() {
    switch (_viewMode) {
      case HeatmapViewMode.month:
        return _buildMonthGrid(_currentDate);
      case HeatmapViewMode.quarter:
        return _buildQuarterGrid();
      case HeatmapViewMode.year:
        return _buildYearGrid();
    }
  }

  Widget _buildMonthGrid(DateTime month, {double cellSize = 40}) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startDow = firstDay.weekday; // 1=Mon, 7=Sun
    final daysInMonth = lastDay.day;

    // Day-of-week headers
    const dayHeaders = ["M", "T", "W", "T", "F", "S", "S"];

    return Column(
      children: [
        // Day headers row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dayHeaders
              .map((d) => SizedBox(
                    width: cellSize,
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: cellSize,
          ),
          itemCount: ((startDow - 1) + daysInMonth + (7 - ((startDow - 1 + daysInMonth) % 7)) % 7),
          itemBuilder: (context, index) {
            final dayOffset = index - (startDow - 1);
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return const SizedBox.shrink();
            }
            final day = dayOffset + 1;
            final date = DateTime(month.year, month.month, day);
            final dateStr = DateFormat("yyyy-MM-dd").format(date);
            final count = _dailyActivity[dateStr] ?? 0;

            return Semantics(
              label: "Day $dateStr, $count items worn",
              child: GestureDetector(
                onTap: () => _onDayTap(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _intensityColor(count),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      "$day",
                      style: TextStyle(
                        fontSize: cellSize > 30 ? 12 : 8,
                        fontWeight: FontWeight.w500,
                        color: count > 0
                            ? const Color(0xFF1F2937)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuarterGrid() {
    final quarterMonth = ((_currentDate.month - 1) ~/ 3) * 3 + 1;
    return Column(
      children: List.generate(3, (i) {
        final month = DateTime(_currentDate.year, quarterMonth + i, 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                DateFormat("MMMM").format(month),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            _buildMonthGrid(month, cellSize: 28),
            const SizedBox(height: 12),
          ],
        );
      }),
    );
  }

  Widget _buildYearGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = DateTime(_currentDate.year, index + 1, 1);
        final monthAbbr = DateFormat("MMM").format(month);

        return GestureDetector(
          onTap: () => _switchToMonthForDate(month),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                monthAbbr,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(child: _buildTinyMonthGrid(month)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTinyMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startDow = firstDay.weekday;
    final daysInMonth = lastDay.day;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 12,
      ),
      itemCount: (startDow - 1) + daysInMonth,
      itemBuilder: (context, index) {
        final dayOffset = index - (startDow - 1);
        if (dayOffset < 0) return const SizedBox.shrink();
        final day = dayOffset + 1;
        final date = DateTime(month.year, month.month, day);
        final dateStr = DateFormat("yyyy-MM-dd").format(date);
        final count = _dailyActivity[dateStr] ?? 0;

        return Container(
          margin: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            color: _intensityColor(count),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }

  Widget _buildStreakStats() {
    final currentStreak =
        (_streakStats["currentStreak"] as num?)?.toInt() ?? 0;
    final longestStreak =
        (_streakStats["longestStreak"] as num?)?.toInt() ?? 0;
    final totalDaysLogged =
        (_streakStats["totalDaysLogged"] as num?)?.toInt() ?? 0;
    final avgItemsPerDay =
        (_streakStats["avgItemsPerDay"] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.local_fire_department,
          iconColor: const Color(0xFFEF4444),
          value: "$currentStreak",
          label: "Current Streak",
          semanticLabel: "Current streak $currentStreak days",
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          icon: Icons.emoji_events,
          iconColor: const Color(0xFFF59E0B),
          value: "$longestStreak",
          label: "Longest Streak",
          semanticLabel: "Longest streak $longestStreak days",
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          icon: Icons.calendar_today,
          iconColor: const Color(0xFF4F46E5),
          value: "$totalDaysLogged",
          label: "Total Days",
          semanticLabel: "Total days logged $totalDaysLogged",
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          icon: Icons.bar_chart,
          iconColor: const Color(0xFF22C55E),
          value: avgItemsPerDay.toStringAsFixed(1),
          label: "Avg Items/Day",
          semanticLabel:
              "Average items per day ${avgItemsPerDay.toStringAsFixed(1)}",
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String semanticLabel,
  }) {
    return Expanded(
      child: Semantics(
        label: semanticLabel,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(_colorNone, "None"),
        const SizedBox(width: 16),
        _buildLegendItem(_colorLight, "1-2"),
        const SizedBox(width: 16),
        _buildLegendItem(_colorMedium, "3-5"),
        const SizedBox(width: 16),
        _buildLegendItem(_colorDark, "6+"),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
