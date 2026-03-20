import "../calendar/calendar_event.dart";
import "weather_clothing_mapper.dart";
import "weather_data.dart";

/// Compiled context object containing weather conditions, clothing constraints,
/// and temporal metadata for AI outfit generation.
///
/// This is the weather portion of the full context object. Story 3.5-3.6 will
/// add calendar event data. Story 4.1 will consume this via [toJson] for the
/// Gemini prompt payload.
class OutfitContext {
  const OutfitContext({
    required this.temperature,
    required this.feelsLike,
    required this.weatherCode,
    required this.weatherDescription,
    required this.clothingConstraints,
    required this.locationName,
    required this.date,
    required this.dayOfWeek,
    required this.season,
    required this.temperatureCategory,
    this.calendarEvents = const [],
  });

  final double temperature;
  final double feelsLike;
  final int weatherCode;
  final String weatherDescription;
  final ClothingConstraints clothingConstraints;
  final String locationName;
  final DateTime date;
  final String dayOfWeek;
  final String season;
  final String temperatureCategory;
  final List<CalendarEventContext> calendarEvents;

  static const _dayNames = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  /// Derives the meteorological season from a date (Northern Hemisphere).
  ///
  /// March-May = spring, June-August = summer,
  /// September-November = fall, December-February = winter.
  static String deriveSeason(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return "spring";
    if (month >= 6 && month <= 8) return "summer";
    if (month >= 9 && month <= 11) return "fall";
    return "winter";
  }

  /// Derives the full day-of-week name from a date.
  static String deriveDayOfWeek(DateTime date) => _dayNames[date.weekday - 1];

  /// Creates an [OutfitContext] from existing [WeatherData].
  ///
  /// [overrideDate] allows tests to inject a fixed date. Defaults to now.
  factory OutfitContext.fromWeatherData(
    WeatherData weatherData, {
    DateTime? overrideDate,
    List<CalendarEventContext>? calendarEvents,
  }) {
    final date = overrideDate ?? DateTime.now();
    final constraints = WeatherClothingMapper.mapWeatherToClothing(
      weatherData.weatherCode,
      weatherData.feelsLike,
    );
    return OutfitContext(
      temperature: weatherData.temperature,
      feelsLike: weatherData.feelsLike,
      weatherCode: weatherData.weatherCode,
      weatherDescription: weatherData.weatherDescription,
      clothingConstraints: constraints,
      locationName: weatherData.locationName,
      date: date,
      dayOfWeek: deriveDayOfWeek(date),
      season: deriveSeason(date),
      temperatureCategory: constraints.temperatureCategory,
      calendarEvents: calendarEvents ?? const [],
    );
  }

  /// Serializes the full context for use in AI prompt construction (Story 4.1).
  Map<String, dynamic> toJson() => {
        "temperature": temperature,
        "feelsLike": feelsLike,
        "weatherCode": weatherCode,
        "weatherDescription": weatherDescription,
        "clothingConstraints": clothingConstraints.toJson(),
        "locationName": locationName,
        "date":
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        "dayOfWeek": dayOfWeek,
        "season": season,
        "temperatureCategory": temperatureCategory,
        "calendarEvents":
            calendarEvents.map((e) => e.toJson()).toList(),
      };

  /// Deserializes an [OutfitContext] from JSON.
  factory OutfitContext.fromJson(Map<String, dynamic> json) {
    final constraints = ClothingConstraints.fromJson(
      json["clothingConstraints"] as Map<String, dynamic>,
    );
    final dateStr = json["date"] as String;
    final dateParts = dateStr.split("-");
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    final calendarEventsJson = json["calendarEvents"] as List<dynamic>?;
    final calendarEvents = calendarEventsJson != null
        ? calendarEventsJson
            .map((e) =>
                CalendarEventContext.fromJson(e as Map<String, dynamic>))
            .toList()
        : <CalendarEventContext>[];
    return OutfitContext(
      temperature: (json["temperature"] as num).toDouble(),
      feelsLike: (json["feelsLike"] as num).toDouble(),
      weatherCode: json["weatherCode"] as int,
      weatherDescription: json["weatherDescription"] as String,
      clothingConstraints: constraints,
      locationName: json["locationName"] as String,
      date: date,
      dayOfWeek: json["dayOfWeek"] as String,
      season: json["season"] as String,
      temperatureCategory: json["temperatureCategory"] as String,
      calendarEvents: calendarEvents,
    );
  }
}
