import "package:flutter/material.dart";

import "../../../core/weather/weather_data.dart";

/// Displays current weather data in a card format.
///
/// Supports three states: loading (shimmer), success (weather data), and
/// error (message with retry).
class WeatherWidget extends StatelessWidget {
  const WeatherWidget({
    this.weatherData,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.lastUpdatedLabel,
    super.key,
  });

  final WeatherData? weatherData;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// Optional staleness indicator label (e.g., "5 min ago").
  /// Shown when displaying cached data while offline.
  final String? lastUpdatedLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }
    if (weatherData != null) {
      return _buildSuccessState(weatherData!);
    }
    if (errorMessage != null) {
      return _buildErrorState();
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingState() {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: const _ShimmerPlaceholder(),
    );
  }

  Widget _buildSuccessState(WeatherData data) {
    final semanticsLabel = lastUpdatedLabel != null
        ? "Current weather: ${data.temperature.round()} degrees, "
            "${data.weatherDescription}, in ${data.locationName}. "
            "Last updated $lastUpdatedLabel"
        : "Current weather: ${data.temperature.round()} degrees, "
            "${data.weatherDescription}, in ${data.locationName}";

    return Semantics(
      label: semanticsLabel,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  data.weatherIcon,
                  size: 48,
                  color: const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 16),
                Text(
                  "${data.temperature.round()}\u00B0C",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Feels like ${data.feelsLike.round()}\u00B0C",
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.weatherDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  data.locationName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            if (lastUpdatedLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                "Last updated $lastUpdatedLabel",
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Semantics(
      label: "Weather unavailable, tap to retry",
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: onRetry,
                child: const Text(
                  "Retry",
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder();

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(209, 213, 219, _animation.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 80,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(209, 213, 219, _animation.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                color: Color.fromRGBO(209, 213, 219, _animation.value),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: Color.fromRGBO(209, 213, 219, _animation.value),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}
