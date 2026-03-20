import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";

void main() {
  group("WeatherData serialization", () {
    final sampleData = WeatherData(
      temperature: 18.5,
      feelsLike: 16.2,
      weatherCode: 0,
      weatherDescription: "Clear sky",
      weatherIcon: Icons.wb_sunny,
      locationName: "Paris, France",
      fetchedAt: DateTime(2026, 3, 12, 10, 30),
    );

    test("toJson produces expected JSON structure with all fields", () {
      final json = sampleData.toJson();

      expect(json["temperature"], 18.5);
      expect(json["feelsLike"], 16.2);
      expect(json["weatherCode"], 0);
      expect(json["weatherDescription"], "Clear sky");
      expect(json["iconCodePoint"], Icons.wb_sunny.codePoint);
      expect(json["locationName"], "Paris, France");
      expect(json["fetchedAt"], "2026-03-12T10:30:00.000");
    });

    test("fromJson reconstructs WeatherData with matching field values", () {
      final json = {
        "temperature": 18.5,
        "feelsLike": 16.2,
        "weatherCode": 0,
        "weatherDescription": "Clear sky",
        "iconCodePoint": Icons.wb_sunny.codePoint,
        "locationName": "Paris, France",
        "fetchedAt": "2026-03-12T10:30:00.000",
      };

      final data = WeatherData.fromJson(json);

      expect(data.temperature, 18.5);
      expect(data.feelsLike, 16.2);
      expect(data.weatherCode, 0);
      expect(data.weatherDescription, "Clear sky");
      expect(data.weatherIcon.codePoint, Icons.wb_sunny.codePoint);
      expect(data.locationName, "Paris, France");
      expect(data.fetchedAt, DateTime(2026, 3, 12, 10, 30));
    });

    test("round-trip preserves all fields", () {
      final json = sampleData.toJson();
      final restored = WeatherData.fromJson(json);

      expect(restored.temperature, sampleData.temperature);
      expect(restored.feelsLike, sampleData.feelsLike);
      expect(restored.weatherCode, sampleData.weatherCode);
      expect(restored.weatherDescription, sampleData.weatherDescription);
      expect(
          restored.weatherIcon.codePoint, sampleData.weatherIcon.codePoint);
      expect(restored.locationName, sampleData.locationName);
      expect(restored.fetchedAt, sampleData.fetchedAt);
    });

    test("weatherIcon codePoint serialization and deserialization is correct",
        () {
      final iconData = WeatherData(
        temperature: 5.0,
        feelsLike: 2.0,
        weatherCode: 71,
        weatherDescription: "Snow",
        weatherIcon: Icons.snowing,
        locationName: "London, UK",
        fetchedAt: DateTime(2026, 3, 12),
      );

      final json = iconData.toJson();
      expect(json["iconCodePoint"], Icons.snowing.codePoint);

      final restored = WeatherData.fromJson(json);
      expect(restored.weatherIcon.codePoint, Icons.snowing.codePoint);
      expect(restored.weatherIcon.fontFamily, "MaterialIcons");
    });
  });
}
