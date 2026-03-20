import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/weather/weather_codes.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";
import "package:vestiaire_mobile/src/core/weather/weather_service.dart";

void main() {
  group("WeatherService", () {
    final validResponse = jsonEncode({
      "current": {
        "time": "2026-03-12T10:00",
        "interval": 900,
        "temperature_2m": 12.4,
        "apparent_temperature": 10.1,
        "weather_code": 3,
      },
      "current_units": {
        "temperature_2m": "\u00B0C",
        "apparent_temperature": "\u00B0C",
      },
    });

    test("fetchCurrentWeather parses Open-Meteo response correctly", () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.host, "api.open-meteo.com");
        expect(request.url.path, "/v1/forecast");
        expect(request.url.queryParameters["latitude"], "48.85");
        expect(request.url.queryParameters["longitude"], "2.35");
        return http.Response(validResponse, 200);
      });

      final service = WeatherService(client: mockClient);
      final data = await service.fetchCurrentWeather(48.85, 2.35, "Paris, FR");

      expect(data.temperature, 12.4);
      expect(data.feelsLike, 10.1);
      expect(data.weatherCode, 3);
      expect(data.weatherDescription, "Partly cloudy");
      expect(data.locationName, "Paris, FR");
    });

    test("fetchCurrentWeather throws WeatherFetchException on network error",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final service = WeatherService(client: mockClient);
      expect(
        () => service.fetchCurrentWeather(48.85, 2.35, "Paris, FR"),
        throwsA(isA<WeatherFetchException>()),
      );
    });

    test("fetchCurrentWeather throws WeatherFetchException on non-200 status",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response("Server Error", 500);
      });

      final service = WeatherService(client: mockClient);
      expect(
        () => service.fetchCurrentWeather(48.85, 2.35, "Paris, FR"),
        throwsA(
          isA<WeatherFetchException>().having(
            (e) => e.message,
            "message",
            contains("500"),
          ),
        ),
      );
    });

    test(
        "fetchCurrentWeather throws WeatherFetchException on malformed JSON",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response("not json at all", 200);
      });

      final service = WeatherService(client: mockClient);
      expect(
        () => service.fetchCurrentWeather(48.85, 2.35, "Paris, FR"),
        throwsA(isA<WeatherFetchException>()),
      );
    });

    test("temperature and feelsLike are correctly extracted", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "current": {
              "temperature_2m": 25.7,
              "apparent_temperature": 28.3,
              "weather_code": 0,
            },
          }),
          200,
        );
      });

      final service = WeatherService(client: mockClient);
      final data =
          await service.fetchCurrentWeather(40.71, -74.01, "New York, US");

      expect(data.temperature, 25.7);
      expect(data.feelsLike, 28.3);
    });

    test("weather code is correctly mapped to description", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "current": {
              "temperature_2m": 5.0,
              "apparent_temperature": 2.0,
              "weather_code": 71,
            },
          }),
          200,
        );
      });

      final service = WeatherService(client: mockClient);
      final data = await service.fetchCurrentWeather(51.5, -0.13, "London, UK");

      expect(data.weatherDescription, "Snow");
      expect(data.weatherIcon, Icons.snowing);
    });
  });

  group("WeatherService.fetchWeather (with forecast)", () {
    final validResponseWithForecast = jsonEncode({
      "current": {
        "time": "2026-03-12T10:00",
        "interval": 900,
        "temperature_2m": 12.4,
        "apparent_temperature": 10.1,
        "weather_code": 3,
      },
      "current_units": {
        "temperature_2m": "\u00B0C",
        "apparent_temperature": "\u00B0C",
      },
      "daily": {
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
      },
      "daily_units": {
        "temperature_2m_max": "\u00B0C",
        "temperature_2m_min": "\u00B0C",
      },
    });

    test("fetchWeather parses both current weather and daily forecast",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.queryParameters["daily"],
            "temperature_2m_max,temperature_2m_min,weather_code");
        expect(request.url.queryParameters["forecast_days"], "5");
        return http.Response(validResponseWithForecast, 200);
      });

      final service = WeatherService(client: mockClient);
      final response = await service.fetchWeather(48.85, 2.35, "Paris, FR");

      expect(response.current.temperature, 12.4);
      expect(response.current.feelsLike, 10.1);
      expect(response.current.weatherCode, 3);
      expect(response.current.locationName, "Paris, FR");
    });

    test("response includes 5 DailyForecast objects", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(validResponseWithForecast, 200);
      });

      final service = WeatherService(client: mockClient);
      final response = await service.fetchWeather(48.85, 2.35, "Paris, FR");

      expect(response.forecast.length, 5);
    });

    test("forecast objects have correct high/low temps and weather codes",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(validResponseWithForecast, 200);
      });

      final service = WeatherService(client: mockClient);
      final response = await service.fetchWeather(48.85, 2.35, "Paris, FR");

      expect(response.forecast[0].highTemperature, 15.2);
      expect(response.forecast[0].lowTemperature, 8.1);
      expect(response.forecast[0].weatherCode, 3);
      expect(response.forecast[0].weatherDescription, "Partly cloudy");

      expect(response.forecast[1].highTemperature, 14.8);
      expect(response.forecast[1].weatherCode, 61);
      expect(response.forecast[1].weatherDescription, "Rain");

      expect(response.forecast[2].weatherCode, 0);
      expect(response.forecast[2].weatherDescription, "Clear sky");

      expect(response.forecast[3].weatherCode, 45);
      expect(response.forecast[3].weatherDescription, "Fog");

      expect(response.forecast[4].highTemperature, 17.0);
      expect(response.forecast[4].lowTemperature, 10.2);
    });

    test("fetchWeather throws WeatherFetchException on network error",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final service = WeatherService(client: mockClient);
      expect(
        () => service.fetchWeather(48.85, 2.35, "Paris, FR"),
        throwsA(isA<WeatherFetchException>()),
      );
    });

    test("fetchWeather throws WeatherFetchException on non-200 status",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response("Server Error", 500);
      });

      final service = WeatherService(client: mockClient);
      expect(
        () => service.fetchWeather(48.85, 2.35, "Paris, FR"),
        throwsA(
          isA<WeatherFetchException>().having(
            (e) => e.message,
            "message",
            contains("500"),
          ),
        ),
      );
    });

    test("fetchWeather throws WeatherFetchException on malformed JSON",
        () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response("not json at all", 200);
      });

      final service = WeatherService(client: mockClient);
      expect(
        () => service.fetchWeather(48.85, 2.35, "Paris, FR"),
        throwsA(isA<WeatherFetchException>()),
      );
    });
  });

  group("WeatherData.fromOpenMeteoJson", () {
    test("parses valid JSON correctly", () {
      final json = {
        "current": {
          "temperature_2m": 15.0,
          "apparent_temperature": 13.5,
          "weather_code": 0,
        },
      };

      final data = WeatherData.fromOpenMeteoJson(json, "Test City");
      expect(data.temperature, 15.0);
      expect(data.feelsLike, 13.5);
      expect(data.weatherCode, 0);
      expect(data.weatherDescription, "Clear sky");
      expect(data.weatherIcon, Icons.wb_sunny);
      expect(data.locationName, "Test City");
    });
  });

  group("mapWeatherCode", () {
    test("maps code 0 to Clear sky", () {
      final c = mapWeatherCode(0);
      expect(c.description, "Clear sky");
      expect(c.icon, Icons.wb_sunny);
    });

    test("maps codes 1-3 to Partly cloudy", () {
      for (final code in [1, 2, 3]) {
        final c = mapWeatherCode(code);
        expect(c.description, "Partly cloudy");
      }
    });

    test("maps codes 45, 48 to Fog", () {
      for (final code in [45, 48]) {
        final c = mapWeatherCode(code);
        expect(c.description, "Fog");
      }
    });

    test("maps codes 61-65 to Rain", () {
      for (final code in [61, 63, 65]) {
        final c = mapWeatherCode(code);
        expect(c.description, "Rain");
      }
    });

    test("maps codes 95-99 to Thunderstorm", () {
      for (final code in [95, 96, 99]) {
        final c = mapWeatherCode(code);
        expect(c.description, "Thunderstorm");
      }
    });

    test("maps unknown code to Unknown", () {
      final c = mapWeatherCode(999);
      expect(c.description, "Unknown");
      expect(c.icon, Icons.help_outline);
    });
  });
}
