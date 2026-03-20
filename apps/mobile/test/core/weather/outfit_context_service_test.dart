import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:vestiaire_mobile/src/core/weather/daily_forecast.dart";
import "package:vestiaire_mobile/src/core/weather/outfit_context_service.dart";
import "package:vestiaire_mobile/src/core/weather/weather_cache_service.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";

void main() {
  group("OutfitContextService", () {
    late WeatherCacheService cacheService;
    late OutfitContextService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cacheService = WeatherCacheService(prefs: prefs);
      service = OutfitContextService(cacheService: cacheService);
    });

    WeatherData _makeWeatherData({
      double temperature = 22.0,
      double feelsLike = 20.0,
      int weatherCode = 0,
      String weatherDescription = "Clear sky",
      String locationName = "Paris, France",
    }) {
      return WeatherData(
        temperature: temperature,
        feelsLike: feelsLike,
        weatherCode: weatherCode,
        weatherDescription: weatherDescription,
        weatherIcon: Icons.wb_sunny,
        locationName: locationName,
        fetchedAt: DateTime.now(),
      );
    }

    test("getCurrentContext returns OutfitContext when cached weather exists",
        () async {
      final weather = _makeWeatherData();
      final forecast = <DailyForecast>[
        DailyForecast(
          date: DateTime(2026, 3, 12),
          highTemperature: 15.0,
          lowTemperature: 8.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
        ),
      ];
      await cacheService.cacheWeatherData(weather, forecast);

      final context = await service.getCurrentContext();

      expect(context, isNotNull);
      expect(context!.temperature, 22.0);
      expect(context.feelsLike, 20.0);
      expect(context.weatherCode, 0);
      expect(context.locationName, "Paris, France");
      expect(context.temperatureCategory, "mild");
    });

    test("getCurrentContext returns null when no cached weather exists",
        () async {
      final context = await service.getCurrentContext();
      expect(context, isNull);
    });

    test("buildContextFromWeather produces correct OutfitContext", () {
      final weather = _makeWeatherData(
        temperature: 5.0,
        feelsLike: 2.0,
        weatherCode: 71,
        weatherDescription: "Snow",
        locationName: "Berlin, Germany",
      );

      final context = service.buildContextFromWeather(weather);

      expect(context.temperature, 5.0);
      expect(context.feelsLike, 2.0);
      expect(context.weatherCode, 71);
      expect(context.weatherDescription, "Snow");
      expect(context.locationName, "Berlin, Germany");
      expect(context.temperatureCategory, "cold");
      expect(context.clothingConstraints.requiresWaterproof, true);
      expect(
        context.clothingConstraints.requiredCategories,
        contains("outerwear"),
      );
      expect(
        context.clothingConstraints.requiredCategories,
        contains("shoes"),
      );
    });

    test("clothing constraints match expected values for hot weather", () {
      final weather = _makeWeatherData(feelsLike: 35.0);
      final context = service.buildContextFromWeather(weather);

      expect(context.temperatureCategory, "hot");
      expect(
        context.clothingConstraints.preferredMaterials,
        contains("cotton"),
      );
      expect(
        context.clothingConstraints.avoidMaterials,
        contains("wool"),
      );
      expect(context.clothingConstraints.requiresLayering, false);
    });
  });
}
