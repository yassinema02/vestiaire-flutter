import "../calendar/calendar_event.dart";
import "outfit_context.dart";
import "weather_cache_service.dart";
import "weather_data.dart";

/// Service that bridges the weather layer (Epic 3) and the AI outfit
/// generation layer (Epic 4).
///
/// Reads cached weather data and constructs an [OutfitContext] containing
/// weather conditions, clothing constraints, and temporal metadata.
/// The [OutfitContext.toJson] output will be injected into the Gemini
/// prompt by the outfit generation service in Story 4.1.
class OutfitContextService {
  OutfitContextService({WeatherCacheService? cacheService})
      : _cacheService = cacheService ?? WeatherCacheService();

  final WeatherCacheService _cacheService;

  /// Returns an [OutfitContext] from the latest cached weather data.
  ///
  /// Returns `null` if no weather data is cached (e.g., location denied
  /// or fresh app install).
  Future<OutfitContext?> getCurrentContext({
    List<CalendarEventContext>? calendarEvents,
  }) async {
    final cached = await _cacheService.getCachedWeather();
    if (cached == null) return null;
    return OutfitContext.fromWeatherData(
      cached.currentWeather,
      calendarEvents: calendarEvents,
    );
  }

  /// Synchronously creates an [OutfitContext] from given [WeatherData].
  ///
  /// Used by HomeScreen when fresh weather data has just been fetched
  /// (before caching).
  OutfitContext buildContextFromWeather(
    WeatherData weatherData, {
    List<CalendarEventContext>? calendarEvents,
  }) {
    return OutfitContext.fromWeatherData(
      weatherData,
      calendarEvents: calendarEvents,
    );
  }
}
