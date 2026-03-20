import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/networking/api_client.dart";
import "../models/wear_log.dart";
import "../services/wear_log_service.dart";
import "../widgets/day_detail_bottom_sheet.dart";
import "../widgets/month_summary_row.dart";

/// A monthly calendar view showing wear-log activity indicators.
///
/// Displays a standard month grid where days with logged outfits show a
/// coloured dot. Tapping an active day opens [DayDetailBottomSheet].
class WearCalendarScreen extends StatefulWidget {
  const WearCalendarScreen({
    required this.wearLogService,
    this.apiClient,
    this.initialMonth,
    super.key,
  });

  final WearLogService wearLogService;
  final ApiClient? apiClient;

  /// Optional initial month for testing. Defaults to the current month.
  final DateTime? initialMonth;

  @override
  State<WearCalendarScreen> createState() => WearCalendarScreenState();
}

/// Visible for testing.
class WearCalendarScreenState extends State<WearCalendarScreen> {
  late DateTime _currentMonth;
  Map<String, List<WearLog>> _wearLogsByDate = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final init = widget.initialMonth ?? DateTime.now();
    _currentMonth = DateTime(init.year, init.month, 1);
    _fetchMonthData();
  }

  Future<void> _fetchMonthData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firstDay = _currentMonth;
      final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);

      final startDate = DateFormat("yyyy-MM-dd").format(firstDay);
      final endDate = DateFormat("yyyy-MM-dd").format(lastDay);

      final logs = await widget.wearLogService.getLogsForDateRange(
        startDate,
        endDate,
      );

      final grouped = <String, List<WearLog>>{};
      for (final log in logs) {
        grouped.putIfAbsent(log.loggedDate, () => []).add(log);
      }

      if (!mounted) return;
      setState(() {
        _wearLogsByDate = grouped;
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

  void _navigatePrevious() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _fetchMonthData();
  }

  void _navigateNext() {
    if (_isCurrentMonth) return;
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _fetchMonthData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentMonth.year == now.year && _currentMonth.month == now.month;
  }

  void _onDayTap(String dateKey, List<WearLog> logs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DayDetailBottomSheet(
        date: dateKey,
        wearLogs: logs,
        apiClient: widget.apiClient,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat("MMMM yyyy").format(_currentMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Wear Calendar"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Semantics(
        label: "Wear calendar for $monthLabel",
        child: Column(
          children: [
            _buildMonthHeader(monthLabel),
            if (!_isLoading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonthSummaryRow(
                  wearLogsByDate: _wearLogsByDate,
                  currentMonth: _currentMonth,
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(String monthLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: "Previous month",
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _navigatePrevious,
            ),
          ),
          Text(
            monthLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          Semantics(
            label: "Next month",
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _isCurrentMonth ? null : _navigateNext,
              color: _isCurrentMonth ? Colors.grey : null,
            ),
          ),
        ],
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
            const Icon(Icons.error_outline, size: 32, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchMonthData,
              child: const Text(
                "Retry",
                style: TextStyle(color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildDayOfWeekHeaders(),
        Expanded(child: _buildCalendarGrid()),
        if (_wearLogsByDate.isEmpty) ...[
          const SizedBox(height: 16),
          _buildEmptyState(),
        ],
      ],
    );
  }

  Widget _buildDayOfWeekHeaders() {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = _currentMonth;
    final daysInMonth = DateTime(firstDayOfMonth.year, firstDayOfMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final cells = <Widget>[];

    // Empty cells for days before the 1st
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    final now = DateTime.now();
    final todayKey = DateFormat("yyyy-MM-dd").format(now);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, day);
      final dateKey = DateFormat("yyyy-MM-dd").format(date);
      final logs = _wearLogsByDate[dateKey];
      final hasActivity = logs != null && logs.isNotEmpty;
      final isToday = dateKey == todayKey;

      cells.add(_buildDayCell(day, dateKey, hasActivity, isToday, logs));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(
    int day,
    String dateKey,
    bool hasActivity,
    bool isToday,
    List<WearLog>? logs,
  ) {
    final logCount = logs?.length ?? 0;
    final semanticLabel = hasActivity
        ? "Day $day, $logCount outfits logged"
        : "Day $day, no outfits logged";

    final cell = Semantics(
      label: semanticLabel,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "$day",
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF1F2937),
              ),
            ),
            if (hasActivity)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );

    if (hasActivity) {
      return InkWell(
        onTap: () => _onDayTap(dateKey, logs!),
        borderRadius: BorderRadius.circular(8),
        child: cell,
      );
    }

    return cell;
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            "Start logging your outfits to see your activity here!",
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
