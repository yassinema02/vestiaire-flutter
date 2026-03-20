import "package:flutter/material.dart";

import "../../../core/weather/daily_forecast.dart";

/// Displays a horizontal scrollable 5-day weather forecast row.
///
/// Each day card shows: day name abbreviation, weather icon, and high/low
/// temperatures. Styled to match the Vibrant Soft-UI design system.
class ForecastWidget extends StatelessWidget {
  const ForecastWidget({
    required this.forecast,
    super.key,
  });

  final List<DailyForecast> forecast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "5-day forecast",
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: forecast
                  .map((day) => _buildDayCard(day))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(DailyForecast day) {
    return Semantics(
      label:
          "${day.dayName}: ${day.weatherDescription}, high ${day.highTemperature.round()} degrees, low ${day.lowTemperature.round()} degrees",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day.dayName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              day.weatherIcon,
              size: 24,
              color: const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 6),
            Text(
              "${day.highTemperature.round()}\u00B0",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "${day.lowTemperature.round()}\u00B0",
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
