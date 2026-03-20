import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;

import "daily_forecast.dart";
import "weather_data.dart";
import "weather_response.dart";

/// Exception thrown when weather data cannot be fetched.
class WeatherFetchException implements Exception {
  WeatherFetchException(this.message);

  final String message;

  @override
  String toString() => "WeatherFetchException: $message";
}

/// Service for fetching weather data from the Open-Meteo API.
///
/// Accepts an optional [http.Client] for dependency injection in tests.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches current weather and 5-day forecast data for the given coordinates.
  ///
  /// Throws [WeatherFetchException] on network errors, non-200 responses,
  /// or JSON parsing failures.
  Future<WeatherResponse> fetchWeather(
    double latitude,
    double longitude,
    String locationName,
  ) async {
    final uri = Uri.parse(
      "https://api.open-meteo.com/v1/forecast"
      "?latitude=$latitude"
      "&longitude=$longitude"
      "&current=temperature_2m,apparent_temperature,weather_code"
      "&daily=temperature_2m_max,temperature_2m_min,weather_code"
      "&forecast_days=5"
      "&timezone=auto",
    );
    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        throw WeatherFetchException(
          "Weather service returned ${response.statusCode}",
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = WeatherData.fromOpenMeteoJson(json, locationName);

      final daily = json["daily"] as Map<String, dynamic>;
      final forecastCount = (daily["time"] as List).length;
      final forecast = List<DailyForecast>.generate(
        forecastCount,
        (i) => DailyForecast.fromOpenMeteoDaily(daily, i),
      );

      return WeatherResponse(current: current, forecast: forecast);
    } on TimeoutException {
      throw WeatherFetchException("Weather request timed out");
    } catch (e) {
      if (e is WeatherFetchException) rethrow;
      throw WeatherFetchException("Unable to fetch weather data");
    }
  }

  /// Fetches current weather data for the given coordinates.
  ///
  /// @deprecated Use [fetchWeather] instead which also returns forecast data.
  /// Kept for backward compatibility during migration.
  Future<WeatherData> fetchCurrentWeather(
    double latitude,
    double longitude,
    String locationName,
  ) async {
    final uri = Uri.parse(
      "https://api.open-meteo.com/v1/forecast"
      "?latitude=$latitude"
      "&longitude=$longitude"
      "&current=temperature_2m,apparent_temperature,weather_code"
      "&timezone=auto",
    );
    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        throw WeatherFetchException(
          "Weather service returned ${response.statusCode}",
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return WeatherData.fromOpenMeteoJson(json, locationName);
    } on TimeoutException {
      throw WeatherFetchException("Weather request timed out");
    } catch (e) {
      if (e is WeatherFetchException) rethrow;
      throw WeatherFetchException("Unable to fetch weather data");
    }
  }
}
