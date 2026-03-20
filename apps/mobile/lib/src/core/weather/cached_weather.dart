import "daily_forecast.dart";
import "weather_data.dart";

/// Holds cached weather data along with the timestamp of when it was cached.
///
/// Returned by [WeatherCacheService.getCachedWeather] when valid cached data
/// exists within the TTL window.
class CachedWeather {
  const CachedWeather({
    required this.currentWeather,
    required this.forecast,
    required this.cachedAt,
  });

  final WeatherData currentWeather;
  final List<DailyForecast> forecast;
  final DateTime cachedAt;

  /// Returns a human-readable label indicating how long ago the data was cached.
  ///
  /// - "Just now" if less than 1 minute ago
  /// - "X min ago" if less than 60 minutes ago
  /// - "X hr ago" otherwise
  String get lastUpdatedLabel {
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    return "${diff.inHours} hr ago";
  }
}
