import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/weather/cached_weather.dart";
import "package:vestiaire_mobile/src/core/weather/daily_forecast.dart";
import "package:vestiaire_mobile/src/core/weather/weather_cache_service.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";

void main() {
  group("WeatherCacheService", () {
    late WeatherCacheService cacheService;
    late SharedPreferences prefs;

    final testWeather = WeatherData(
      temperature: 18.5,
      feelsLike: 16.2,
      weatherCode: 0,
      weatherDescription: "Clear sky",
      weatherIcon: Icons.wb_sunny,
      locationName: "Paris, France",
      fetchedAt: DateTime(2026, 3, 12, 10, 30),
    );

    final testForecast = [
      DailyForecast(
        date: DateTime(2026, 3, 12),
        highTemperature: 15.2,
        lowTemperature: 8.1,
        weatherCode: 3,
        weatherDescription: "Partly cloudy",
        weatherIcon: Icons.cloud_queue,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 13),
        highTemperature: 14.8,
        lowTemperature: 7.5,
        weatherCode: 61,
        weatherDescription: "Rain",
        weatherIcon: Icons.water_drop,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 14),
        highTemperature: 16.1,
        lowTemperature: 9.3,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 15),
        highTemperature: 13.5,
        lowTemperature: 6.8,
        weatherCode: 45,
        weatherDescription: "Fog",
        weatherIcon: Icons.foggy,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 16),
        highTemperature: 17.0,
        lowTemperature: 10.2,
        weatherCode: 1,
        weatherDescription: "Partly cloudy",
        weatherIcon: Icons.cloud_queue,
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheService = WeatherCacheService(prefs: prefs);
    });

    test("cacheWeatherData stores data in SharedPreferences", () async {
      await cacheService.cacheWeatherData(testWeather, testForecast);

      expect(
        prefs.getString(WeatherCacheService.kWeatherCacheKey),
        isNotNull,
      );
      expect(
        prefs.getString(WeatherCacheService.kWeatherCacheTimestampKey),
        isNotNull,
      );
    });

    test("getCachedWeather returns cached data when within TTL", () async {
      await cacheService.cacheWeatherData(testWeather, testForecast);

      final cached = await cacheService.getCachedWeather();

      expect(cached, isNotNull);
      expect(cached!.currentWeather.temperature, testWeather.temperature);
      expect(cached.currentWeather.locationName, testWeather.locationName);
      expect(cached.forecast.length, 5);
    });

    test("getCachedWeather returns null when cache is expired", () async {
      // Store data with an old timestamp (31 minutes ago)
      await cacheService.cacheWeatherData(testWeather, testForecast);
      // Overwrite timestamp to be 31 minutes ago
      final oldTime =
          DateTime.now().subtract(const Duration(minutes: 31)).toIso8601String();
      await prefs.setString(
          WeatherCacheService.kWeatherCacheTimestampKey, oldTime);

      final cached = await cacheService.getCachedWeather();

      expect(cached, isNull);
    });

    test("getCachedWeather returns null when no cache exists", () async {
      final cached = await cacheService.getCachedWeather();

      expect(cached, isNull);
    });

    test("clearCache removes cached data", () async {
      await cacheService.cacheWeatherData(testWeather, testForecast);
      await cacheService.clearCache();

      final cached = await cacheService.getCachedWeather();
      expect(cached, isNull);
      expect(
        prefs.getString(WeatherCacheService.kWeatherCacheKey),
        isNull,
      );
      expect(
        prefs.getString(WeatherCacheService.kWeatherCacheTimestampKey),
        isNull,
      );
    });

    test("isCacheValid returns true for recent timestamps", () {
      final recent = DateTime.now().subtract(const Duration(minutes: 10));
      expect(cacheService.isCacheValid(recent), isTrue);
    });

    test("isCacheValid returns false for old timestamps", () {
      final old = DateTime.now().subtract(const Duration(minutes: 31));
      expect(cacheService.isCacheValid(old), isFalse);
    });

    test("isCacheValid returns true at exactly 29 minutes", () {
      final atLimit = DateTime.now().subtract(const Duration(minutes: 29));
      expect(cacheService.isCacheValid(atLimit), isTrue);
    });

    test("round-trip: cache data, retrieve it, verify all fields match",
        () async {
      await cacheService.cacheWeatherData(testWeather, testForecast);

      final cached = await cacheService.getCachedWeather();

      expect(cached, isNotNull);
      expect(cached!.currentWeather.temperature, testWeather.temperature);
      expect(cached.currentWeather.feelsLike, testWeather.feelsLike);
      expect(cached.currentWeather.weatherCode, testWeather.weatherCode);
      expect(cached.currentWeather.weatherDescription,
          testWeather.weatherDescription);
      expect(cached.currentWeather.weatherIcon.codePoint,
          testWeather.weatherIcon.codePoint);
      expect(cached.currentWeather.locationName, testWeather.locationName);

      expect(cached.forecast.length, testForecast.length);
      for (var i = 0; i < testForecast.length; i++) {
        expect(cached.forecast[i].date, testForecast[i].date);
        expect(cached.forecast[i].highTemperature,
            testForecast[i].highTemperature);
        expect(
            cached.forecast[i].lowTemperature, testForecast[i].lowTemperature);
        expect(cached.forecast[i].weatherCode, testForecast[i].weatherCode);
        expect(cached.forecast[i].weatherDescription,
            testForecast[i].weatherDescription);
        expect(cached.forecast[i].weatherIcon.codePoint,
            testForecast[i].weatherIcon.codePoint);
      }
    });
  });

  group("CachedWeather.lastUpdatedLabel", () {
    test("returns 'Just now' for very recent cache", () {
      final cached = CachedWeather(
        currentWeather: WeatherData(
          temperature: 18.0,
          feelsLike: 16.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
          locationName: "Paris",
          fetchedAt: DateTime.now(),
        ),
        forecast: [],
        cachedAt: DateTime.now(),
      );
      expect(cached.lastUpdatedLabel, "Just now");
    });

    test("returns 'X min ago' for cache under 60 minutes", () {
      final cached = CachedWeather(
        currentWeather: WeatherData(
          temperature: 18.0,
          feelsLike: 16.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
          locationName: "Paris",
          fetchedAt: DateTime.now(),
        ),
        forecast: [],
        cachedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      expect(cached.lastUpdatedLabel, "15 min ago");
    });

    test("returns 'X hr ago' for cache over 60 minutes", () {
      final cached = CachedWeather(
        currentWeather: WeatherData(
          temperature: 18.0,
          feelsLike: 16.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
          locationName: "Paris",
          fetchedAt: DateTime.now(),
        ),
        forecast: [],
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(cached.lastUpdatedLabel, "2 hr ago");
    });
  });
}
