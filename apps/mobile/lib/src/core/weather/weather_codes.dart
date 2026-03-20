import "package:flutter/material.dart";

/// Represents a weather condition with description and icon.
class WeatherCondition {
  const WeatherCondition({
    required this.description,
    required this.icon,
  });

  final String description;
  final IconData icon;
}

/// Maps a WMO weather code to a human-readable description and Material icon.
///
/// WMO codes follow the international standard (0-99).
/// Reference: https://open-meteo.com/en/docs
WeatherCondition mapWeatherCode(int code) {
  switch (code) {
    case 0:
      return const WeatherCondition(
        description: "Clear sky",
        icon: Icons.wb_sunny,
      );
    case 1:
    case 2:
    case 3:
      return const WeatherCondition(
        description: "Partly cloudy",
        icon: Icons.cloud_queue,
      );
    case 45:
    case 48:
      return const WeatherCondition(
        description: "Fog",
        icon: Icons.foggy,
      );
    case 51:
    case 53:
    case 55:
      return const WeatherCondition(
        description: "Drizzle",
        icon: Icons.grain,
      );
    case 56:
    case 57:
      return const WeatherCondition(
        description: "Freezing drizzle",
        icon: Icons.ac_unit,
      );
    case 61:
    case 63:
    case 65:
      return const WeatherCondition(
        description: "Rain",
        icon: Icons.water_drop,
      );
    case 66:
    case 67:
      return const WeatherCondition(
        description: "Freezing rain",
        icon: Icons.ac_unit,
      );
    case 71:
    case 73:
    case 75:
    case 77:
      return const WeatherCondition(
        description: "Snow",
        icon: Icons.snowing,
      );
    case 80:
    case 81:
    case 82:
      return const WeatherCondition(
        description: "Rain showers",
        icon: Icons.umbrella,
      );
    case 85:
    case 86:
      return const WeatherCondition(
        description: "Snow showers",
        icon: Icons.snowing,
      );
    case 95:
    case 96:
    case 99:
      return const WeatherCondition(
        description: "Thunderstorm",
        icon: Icons.thunderstorm,
      );
    default:
      return const WeatherCondition(
        description: "Unknown",
        icon: Icons.help_outline,
      );
  }
}
