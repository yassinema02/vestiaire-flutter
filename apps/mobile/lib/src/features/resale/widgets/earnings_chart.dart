/// Custom-painted bar chart for monthly earnings.
///
/// Story 7.4: Resale Status & History Tracking (FR-RSL-08)
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../models/resale_history.dart";

/// A simple bar chart showing monthly earnings using CustomPaint.
///
/// No external charting library is used -- bars are drawn via CustomPainter.
class EarningsChart extends StatelessWidget {
  const EarningsChart({required this.data, super.key});

  final List<MonthlyEarnings> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Semantics(
        label: "Monthly earnings chart",
        child: const SizedBox(
          height: 180,
          child: Center(
            child: Text(
              "No earnings data yet",
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: "Monthly earnings chart",
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          size: const Size(double.infinity, 180),
          painter: _EarningsChartPainter(data: data),
        ),
      ),
    );
  }
}

class _EarningsChartPainter extends CustomPainter {
  _EarningsChartPainter({required this.data});

  final List<MonthlyEarnings> data;

  static const _barColor = Color(0xFF4F46E5);
  static const _labelColor = Color(0xFF6B7280);
  static const _monthLabels = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = data.length;
    if (barCount == 0) return;

    final maxEarnings = data.fold<double>(0, (max, e) => e.earnings > max ? e.earnings : max);
    final effectiveMax = maxEarnings > 0 ? maxEarnings : 1.0;

    final topPadding = 24.0;
    final bottomPadding = 24.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final barWidth = (size.width / barCount) * 0.6;
    final barSpacing = size.width / barCount;

    final barPaint = Paint()..color = _barColor;
    final baselinePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    // Draw baseline
    canvas.drawLine(
      Offset(0, size.height - bottomPadding),
      Offset(size.width, size.height - bottomPadding),
      baselinePaint,
    );

    final currencyFormat = NumberFormat.currency(symbol: "\u00A3", decimalDigits: 0);

    for (int i = 0; i < barCount; i++) {
      final entry = data[i];
      final x = barSpacing * i + (barSpacing - barWidth) / 2;
      final barHeight = (entry.earnings / effectiveMax) * chartHeight;
      final barTop = size.height - bottomPadding - barHeight;

      // Draw bar with rounded top
      if (barHeight > 2) {
        final rrect = RRect.fromLTRBAndCorners(
          x,
          barTop,
          x + barWidth,
          size.height - bottomPadding,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rrect, barPaint);
      } else {
        // Empty month: thin baseline
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - bottomPadding - 2, barWidth, 2),
          Paint()..color = const Color(0xFFE5E7EB),
        );
      }

      // Earnings label above bar
      final earningsText = TextPainter(
        text: TextSpan(
          text: currencyFormat.format(entry.earnings),
          style: const TextStyle(fontSize: 9, color: _labelColor),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      earningsText.paint(
        canvas,
        Offset(x + (barWidth - earningsText.width) / 2, barTop - 16),
      );

      // Month label below bar
      final monthIndex = entry.month.month - 1;
      final monthText = TextPainter(
        text: TextSpan(
          text: _monthLabels[monthIndex],
          style: const TextStyle(fontSize: 10, color: _labelColor),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      monthText.paint(
        canvas,
        Offset(
          x + (barWidth - monthText.width) / 2,
          size.height - bottomPadding + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EarningsChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
