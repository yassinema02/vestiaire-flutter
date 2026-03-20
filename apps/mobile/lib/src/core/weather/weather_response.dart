import "daily_forecast.dart";
import "weather_data.dart";

/// Contains both current weather and 5-day forecast data from the Open-Meteo API.
class WeatherResponse {
  const WeatherResponse({
    required this.current,
    required this.forecast,
  });

  final WeatherData current;
  final List<DailyForecast> forecast;
}
