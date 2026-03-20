import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/core/weather/outfit_context.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";

void main() {
  group("OutfitContext", () {
    WeatherData _makeWeatherData({
      double temperature = 18.5,
      double feelsLike = 16.2,
      int weatherCode = 0,
      String weatherDescription = "Clear sky",
      String locationName = "Paris, France",
    }) {
      return WeatherData(
        temperature: temperature,
        feelsLike: feelsLike,
        weatherCode: weatherCode,
        weatherDescription: weatherDescription,
        weatherIcon: Icons.wb_sunny,
        locationName: locationName,
        fetchedAt: DateTime(2026, 3, 12, 10, 0),
      );
    }

    group("fromWeatherData", () {
      test("creates correct context with all fields", () {
        final weather = _makeWeatherData();
        final date = DateTime(2026, 3, 12); // Thursday in spring
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: date,
        );

        expect(context.temperature, 18.5);
        expect(context.feelsLike, 16.2);
        expect(context.weatherCode, 0);
        expect(context.weatherDescription, "Clear sky");
        expect(context.locationName, "Paris, France");
        expect(context.date, date);
        expect(context.dayOfWeek, "Thursday");
        expect(context.season, "spring");
        expect(context.temperatureCategory, "mild");
        expect(context.clothingConstraints, isNotNull);
      });

      test("clothing constraints match weather conditions", () {
        final weather = _makeWeatherData(feelsLike: -3.0, weatherCode: 71);
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: DateTime(2026, 1, 15),
        );

        expect(context.temperatureCategory, "cold");
        expect(context.clothingConstraints.requiresWaterproof, true);
        expect(
          context.clothingConstraints.requiredCategories,
          contains("outerwear"),
        );
      });
    });

    group("deriveSeason", () {
      test("March is spring", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 3, 1)), "spring");
      });

      test("May is spring", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 5, 31)), "spring");
      });

      test("June is summer", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 6, 1)), "summer");
      });

      test("July is summer", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 7, 15)), "summer");
      });

      test("August is summer", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 8, 31)), "summer");
      });

      test("September is fall", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 9, 1)), "fall");
      });

      test("October is fall", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 10, 15)), "fall");
      });

      test("November is fall", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 11, 30)), "fall");
      });

      test("December is winter", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 12, 1)), "winter");
      });

      test("January is winter", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 1, 15)), "winter");
      });

      test("February is winter", () {
        expect(OutfitContext.deriveSeason(DateTime(2026, 2, 28)), "winter");
      });
    });

    group("deriveDayOfWeek", () {
      test("Monday for weekday 1", () {
        // 2026-03-09 is a Monday
        expect(
          OutfitContext.deriveDayOfWeek(DateTime(2026, 3, 9)),
          "Monday",
        );
      });

      test("Thursday for weekday 4", () {
        // 2026-03-12 is a Thursday
        expect(
          OutfitContext.deriveDayOfWeek(DateTime(2026, 3, 12)),
          "Thursday",
        );
      });

      test("Sunday for weekday 7", () {
        // 2026-03-15 is a Sunday
        expect(
          OutfitContext.deriveDayOfWeek(DateTime(2026, 3, 15)),
          "Sunday",
        );
      });

      test("Saturday for weekday 6", () {
        // 2026-03-14 is a Saturday
        expect(
          OutfitContext.deriveDayOfWeek(DateTime(2026, 3, 14)),
          "Saturday",
        );
      });
    });

    group("toJson", () {
      test("produces expected structure with all fields", () {
        final weather = _makeWeatherData();
        final date = DateTime(2026, 3, 12);
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: date,
        );
        final json = context.toJson();

        expect(json["temperature"], 18.5);
        expect(json["feelsLike"], 16.2);
        expect(json["weatherCode"], 0);
        expect(json["weatherDescription"], "Clear sky");
        expect(json["locationName"], "Paris, France");
        expect(json["date"], "2026-03-12");
        expect(json["dayOfWeek"], "Thursday");
        expect(json["season"], "spring");
        expect(json["temperatureCategory"], "mild");
        expect(json["clothingConstraints"], isA<Map<String, dynamic>>());
      });
    });

    group("fromJson round-trip", () {
      test("round-trips correctly", () {
        final weather = _makeWeatherData(
          temperature: 5.0,
          feelsLike: 2.0,
          weatherCode: 71,
          weatherDescription: "Snow",
          locationName: "Berlin, Germany",
        );
        final date = DateTime(2026, 1, 20);
        final original = OutfitContext.fromWeatherData(
          weather,
          overrideDate: date,
        );
        final json = original.toJson();
        final restored = OutfitContext.fromJson(json);

        expect(restored.temperature, original.temperature);
        expect(restored.feelsLike, original.feelsLike);
        expect(restored.weatherCode, original.weatherCode);
        expect(restored.weatherDescription, original.weatherDescription);
        expect(restored.locationName, original.locationName);
        expect(restored.date, original.date);
        expect(restored.dayOfWeek, original.dayOfWeek);
        expect(restored.season, original.season);
        expect(restored.temperatureCategory, original.temperatureCategory);
        expect(
          restored.clothingConstraints.requiresWaterproof,
          original.clothingConstraints.requiresWaterproof,
        );
        expect(
          restored.clothingConstraints.temperatureCategory,
          original.clothingConstraints.temperatureCategory,
        );
      });
    });

    // --- New tests for Story 3.5 (calendarEvents extension) ---

    group("calendarEvents extension", () {
      test("OutfitContext with calendarEvents serializes events in toJson",
          () {
        final weather = _makeWeatherData();
        final date = DateTime(2026, 3, 12);
        final events = [
          CalendarEventContext(
            title: "Sprint Planning",
            eventType: "work",
            formalityScore: 5,
            startTime: DateTime.utc(2026, 3, 12, 10, 0),
            endTime: DateTime.utc(2026, 3, 12, 11, 0),
            allDay: false,
          ),
        ];
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: date,
          calendarEvents: events,
        );
        final json = context.toJson();

        expect(json["calendarEvents"], isA<List>());
        expect((json["calendarEvents"] as List).length, 1);
        expect(
          (json["calendarEvents"] as List)[0]["title"],
          "Sprint Planning",
        );
        expect(
          (json["calendarEvents"] as List)[0]["eventType"],
          "work",
        );
      });

      test("fromJson with calendarEvents field parses correctly", () {
        final weather = _makeWeatherData();
        final date = DateTime(2026, 3, 12);
        final events = [
          CalendarEventContext(
            title: "Team lunch",
            eventType: "social",
            formalityScore: 3,
            startTime: DateTime.utc(2026, 3, 12, 12, 0),
            endTime: DateTime.utc(2026, 3, 12, 13, 0),
            allDay: false,
          ),
        ];
        final original = OutfitContext.fromWeatherData(
          weather,
          overrideDate: date,
          calendarEvents: events,
        );
        final json = original.toJson();
        final restored = OutfitContext.fromJson(json);

        expect(restored.calendarEvents.length, 1);
        expect(restored.calendarEvents[0].title, "Team lunch");
        expect(restored.calendarEvents[0].eventType, "social");
        expect(restored.calendarEvents[0].formalityScore, 3);
      });

      test(
          "fromJson without calendarEvents field defaults to empty list (backward compat)",
          () {
        // Simulate JSON from Story 3.3 (no calendarEvents field)
        final weather = _makeWeatherData();
        final date = DateTime(2026, 3, 12);
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: date,
        );
        final json = context.toJson();
        // Remove calendarEvents to simulate old cached data
        json.remove("calendarEvents");

        final restored = OutfitContext.fromJson(json);

        expect(restored.calendarEvents, isEmpty);
      });

      test(
          "fromWeatherData with calendarEvents passes them through",
          () {
        final weather = _makeWeatherData();
        final events = [
          CalendarEventContext(
            title: "Gym",
            eventType: "active",
            formalityScore: 1,
            startTime: DateTime.utc(2026, 3, 12, 7, 0),
            endTime: DateTime.utc(2026, 3, 12, 8, 0),
            allDay: false,
          ),
        ];
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: DateTime(2026, 3, 12),
          calendarEvents: events,
        );

        expect(context.calendarEvents.length, 1);
        expect(context.calendarEvents[0].title, "Gym");
      });

      test("default calendarEvents is empty list", () {
        final weather = _makeWeatherData();
        final context = OutfitContext.fromWeatherData(
          weather,
          overrideDate: DateTime(2026, 3, 12),
        );

        expect(context.calendarEvents, isEmpty);
      });
    });
  });
}
