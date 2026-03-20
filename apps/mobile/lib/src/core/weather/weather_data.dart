import "package:flutter/material.dart";

import "weather_codes.dart";

/// Holds weather data fetched from the Open-Meteo API.
class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.weatherCode,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.locationName,
    required this.fetchedAt,
  });

  final double temperature;
  final double feelsLike;
  final int weatherCode;
  final String weatherDescription;
  final IconData weatherIcon;
  final String locationName;
  final DateTime fetchedAt;

  /// Creates a [WeatherData] from an Open-Meteo API JSON response.
  factory WeatherData.fromOpenMeteoJson(
    Map<String, dynamic> json,
    String locationName,
  ) {
    final current = json["current"] as Map<String, dynamic>;
    final code = current["weather_code"] as int;
    final condition = mapWeatherCode(code);
    return WeatherData(
      temperature: (current["temperature_2m"] as num).toDouble(),
      feelsLike: (current["apparent_temperature"] as num).toDouble(),
      weatherCode: code,
      weatherDescription: condition.description,
      weatherIcon: condition.icon,
      locationName: locationName,
      fetchedAt: DateTime.now(),
    );
  }

  /// Serializes this [WeatherData] to JSON for cache storage.
  Map<String, dynamic> toJson() => {
        "temperature": temperature,
        "feelsLike": feelsLike,
        "weatherCode": weatherCode,
        "weatherDescription": weatherDescription,
        "iconCodePoint": weatherIcon.codePoint,
        "locationName": locationName,
        "fetchedAt": fetchedAt.toIso8601String(),
      };

  /// Deserializes a [WeatherData] from JSON cache data.
  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json["temperature"] as num).toDouble(),
        feelsLike: (json["feelsLike"] as num).toDouble(),
        weatherCode: json["weatherCode"] as int,
        weatherDescription: json["weatherDescription"] as String,
        weatherIcon: IconData(
          json["iconCodePoint"] as int,
          fontFamily: "MaterialIcons",
        ),
        locationName: json["locationName"] as String,
        fetchedAt: DateTime.parse(json["fetchedAt"] as String),
      );
}
