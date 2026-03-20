import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "cached_weather.dart";
import "daily_forecast.dart";
import "weather_data.dart";

/// Service for caching weather data locally using SharedPreferences.
///
/// Weather data (current + forecast) is cached as a single JSON string with
/// a 30-minute TTL. This enables instant rendering on subsequent Home screen
/// visits within the TTL window.
class WeatherCacheService {
  WeatherCacheService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// Cache time-to-live: 30 minutes per FR-CTX-04.
  static const cacheTtl = Duration(minutes: 30);

  /// SharedPreferences key for the serialized weather JSON.
  static const kWeatherCacheKey = "weather_cache_data";

  /// SharedPreferences key for the ISO 8601 cache timestamp.
  static const kWeatherCacheTimestampKey = "weather_cache_timestamp";

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Caches current weather and forecast data with the current timestamp.
  Future<void> cacheWeatherData(
    WeatherData currentWeather,
    List<DailyForecast> forecast,
  ) async {
    final prefs = await _getPrefs();
    final data = jsonEncode({
      "current": currentWeather.toJson(),
      "forecast": forecast.map((f) => f.toJson()).toList(),
    });
    await prefs.setString(kWeatherCacheKey, data);
    await prefs.setString(
      kWeatherCacheTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Returns cached weather data if it exists and is within the TTL.
  ///
  /// Returns `null` if no cache exists or the cache has expired.
  Future<CachedWeather?> getCachedWeather() async {
    final prefs = await _getPrefs();
    final dataStr = prefs.getString(kWeatherCacheKey);
    final timestampStr = prefs.getString(kWeatherCacheTimestampKey);
    if (dataStr == null || timestampStr == null) return null;

    final cachedAt = DateTime.parse(timestampStr);
    if (!isCacheValid(cachedAt)) return null;

    final json = jsonDecode(dataStr) as Map<String, dynamic>;
    final current = WeatherData.fromJson(
      json["current"] as Map<String, dynamic>,
    );
    final forecast = (json["forecast"] as List)
        .map((f) => DailyForecast.fromJson(f as Map<String, dynamic>))
        .toList();
    return CachedWeather(
      currentWeather: current,
      forecast: forecast,
      cachedAt: cachedAt,
    );
  }

  /// Returns cached weather data regardless of TTL expiry.
  ///
  /// Used for offline fallback when fresh data cannot be fetched.
  Future<CachedWeather?> getStaleCachedWeather() async {
    final prefs = await _getPrefs();
    final dataStr = prefs.getString(kWeatherCacheKey);
    final timestampStr = prefs.getString(kWeatherCacheTimestampKey);
    if (dataStr == null || timestampStr == null) return null;

    final cachedAt = DateTime.parse(timestampStr);
    final json = jsonDecode(dataStr) as Map<String, dynamic>;
    final current = WeatherData.fromJson(
      json["current"] as Map<String, dynamic>,
    );
    final forecast = (json["forecast"] as List)
        .map((f) => DailyForecast.fromJson(f as Map<String, dynamic>))
        .toList();
    return CachedWeather(
      currentWeather: current,
      forecast: forecast,
      cachedAt: cachedAt,
    );
  }

  /// Removes all cached weather data. Called on pull-to-refresh.
  Future<void> clearCache() async {
    final prefs = await _getPrefs();
    await prefs.remove(kWeatherCacheKey);
    await prefs.remove(kWeatherCacheTimestampKey);
  }

  /// Returns `true` if [cachedAt] is within the [cacheTtl] window.
  bool isCacheValid(DateTime cachedAt) =>
      DateTime.now().difference(cachedAt) < cacheTtl;
}
