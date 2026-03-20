import "package:flutter/material.dart";

import "weather_codes.dart";

/// Represents a single day's forecast data from the Open-Meteo API.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.highTemperature,
    required this.lowTemperature,
    required this.weatherCode,
    required this.weatherDescription,
    required this.weatherIcon,
  });

  final DateTime date;
  final double highTemperature;
  final double lowTemperature;
  final int weatherCode;
  final String weatherDescription;
  final IconData weatherIcon;

  /// Day name abbreviations indexed by [DateTime.weekday] - 1.
  static const _dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  /// Returns the abbreviated day name (e.g., "Mon", "Tue").
  String get dayName => _dayNames[date.weekday - 1];

  /// Creates a [DailyForecast] from the Open-Meteo daily response arrays
  /// at the given [index].
  factory DailyForecast.fromOpenMeteoDaily(
    Map<String, dynamic> daily,
    int index,
  ) {
    final code = (daily["weather_code"] as List)[index] as int;
    final condition = mapWeatherCode(code);
    return DailyForecast(
      date: DateTime.parse((daily["time"] as List)[index] as String),
      highTemperature:
          ((daily["temperature_2m_max"] as List)[index] as num).toDouble(),
      lowTemperature:
          ((daily["temperature_2m_min"] as List)[index] as num).toDouble(),
      weatherCode: code,
      weatherDescription: condition.description,
      weatherIcon: condition.icon,
    );
  }

  /// Serializes this forecast to JSON for cache storage.
  Map<String, dynamic> toJson() => {
        "date": date.toIso8601String(),
        "highTemperature": highTemperature,
        "lowTemperature": lowTemperature,
        "weatherCode": weatherCode,
        "weatherDescription": weatherDescription,
        "iconCodePoint": weatherIcon.codePoint,
      };

  /// Deserializes a [DailyForecast] from JSON cache data.
  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
        date: DateTime.parse(json["date"] as String),
        highTemperature: (json["highTemperature"] as num).toDouble(),
        lowTemperature: (json["lowTemperature"] as num).toDouble(),
        weatherCode: json["weatherCode"] as int,
        weatherDescription: json["weatherDescription"] as String,
        weatherIcon: IconData(
          json["iconCodePoint"] as int,
          fontFamily: "MaterialIcons",
        ),
      );
}
