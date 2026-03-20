import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/weather/daily_forecast.dart";

void main() {
  group("DailyForecast", () {
    final sampleDaily = {
      "time": [
        "2026-03-12",
        "2026-03-13",
        "2026-03-14",
        "2026-03-15",
        "2026-03-16",
      ],
      "temperature_2m_max": [15.2, 14.8, 16.1, 13.5, 17.0],
      "temperature_2m_min": [8.1, 7.5, 9.3, 6.8, 10.2],
      "weather_code": [3, 61, 0, 45, 1],
    };

    group("fromOpenMeteoDaily", () {
      test("correctly parses first day (index 0)", () {
        final forecast = DailyForecast.fromOpenMeteoDaily(sampleDaily, 0);
        expect(forecast.date, DateTime(2026, 3, 12));
        expect(forecast.highTemperature, 15.2);
        expect(forecast.lowTemperature, 8.1);
        expect(forecast.weatherCode, 3);
        expect(forecast.weatherDescription, "Partly cloudy");
      });

      test("correctly parses last day (index 4)", () {
        final forecast = DailyForecast.fromOpenMeteoDaily(sampleDaily, 4);
        expect(forecast.date, DateTime(2026, 3, 16));
        expect(forecast.highTemperature, 17.0);
        expect(forecast.lowTemperature, 10.2);
        expect(forecast.weatherCode, 1);
        expect(forecast.weatherDescription, "Partly cloudy");
      });

      test("maps weather code 61 to Rain", () {
        final forecast = DailyForecast.fromOpenMeteoDaily(sampleDaily, 1);
        expect(forecast.weatherDescription, "Rain");
        expect(forecast.weatherIcon, Icons.water_drop);
      });

      test("maps weather code 0 to Clear sky", () {
        final forecast = DailyForecast.fromOpenMeteoDaily(sampleDaily, 2);
        expect(forecast.weatherDescription, "Clear sky");
        expect(forecast.weatherIcon, Icons.wb_sunny);
      });

      test("maps weather code 45 to Fog", () {
        final forecast = DailyForecast.fromOpenMeteoDaily(sampleDaily, 3);
        expect(forecast.weatherDescription, "Fog");
        expect(forecast.weatherIcon, Icons.foggy);
      });
    });

    group("toJson / fromJson round-trip", () {
      test("preserves all fields including icon", () {
        final original = DailyForecast(
          date: DateTime(2026, 3, 12),
          highTemperature: 15.2,
          lowTemperature: 8.1,
          weatherCode: 3,
          weatherDescription: "Partly cloudy",
          weatherIcon: Icons.cloud_queue,
        );

        final json = original.toJson();
        final restored = DailyForecast.fromJson(json);

        expect(restored.date, original.date);
        expect(restored.highTemperature, original.highTemperature);
        expect(restored.lowTemperature, original.lowTemperature);
        expect(restored.weatherCode, original.weatherCode);
        expect(restored.weatherDescription, original.weatherDescription);
        expect(restored.weatherIcon.codePoint, original.weatherIcon.codePoint);
      });

      test("icon codePoint is serialized as int", () {
        final forecast = DailyForecast(
          date: DateTime(2026, 3, 12),
          highTemperature: 15.0,
          lowTemperature: 8.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
        );

        final json = forecast.toJson();
        expect(json["iconCodePoint"], isA<int>());
        expect(json["iconCodePoint"], Icons.wb_sunny.codePoint);
      });
    });

    group("dayName", () {
      test("returns correct abbreviated day names", () {
        // 2026-03-12 is a Thursday
        final thursday = DailyForecast(
          date: DateTime(2026, 3, 12),
          highTemperature: 15.0,
          lowTemperature: 8.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
        );
        expect(thursday.dayName, "Thu");

        // 2026-03-16 is a Monday
        final monday = DailyForecast(
          date: DateTime(2026, 3, 16),
          highTemperature: 15.0,
          lowTemperature: 8.0,
          weatherCode: 0,
          weatherDescription: "Clear sky",
          weatherIcon: Icons.wb_sunny,
        );
        expect(monday.dayName, "Mon");
      });
    });
  });
}
