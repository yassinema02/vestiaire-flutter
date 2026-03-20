import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/weather/daily_forecast.dart";
import "package:vestiaire_mobile/src/features/home/widgets/forecast_widget.dart";

void main() {
  group("ForecastWidget", () {
    final testForecast = [
      DailyForecast(
        date: DateTime(2026, 3, 12), // Thursday
        highTemperature: 15.2,
        lowTemperature: 8.1,
        weatherCode: 3,
        weatherDescription: "Partly cloudy",
        weatherIcon: Icons.cloud_queue,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 13), // Friday
        highTemperature: 14.8,
        lowTemperature: 7.5,
        weatherCode: 61,
        weatherDescription: "Rain",
        weatherIcon: Icons.water_drop,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 14), // Saturday
        highTemperature: 16.1,
        lowTemperature: 9.3,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 15), // Sunday
        highTemperature: 13.5,
        lowTemperature: 6.8,
        weatherCode: 45,
        weatherDescription: "Fog",
        weatherIcon: Icons.foggy,
      ),
      DailyForecast(
        date: DateTime(2026, 3, 16), // Monday
        highTemperature: 17.0,
        lowTemperature: 10.2,
        weatherCode: 1,
        weatherDescription: "Partly cloudy",
        weatherIcon: Icons.cloud_queue,
      ),
    ];

    testWidgets("renders 5 day cards with correct day names", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastWidget(forecast: testForecast),
          ),
        ),
      );

      expect(find.text("Thu"), findsOneWidget);
      expect(find.text("Fri"), findsOneWidget);
      expect(find.text("Sat"), findsOneWidget);
      expect(find.text("Sun"), findsOneWidget);
      expect(find.text("Mon"), findsOneWidget);
    });

    testWidgets("each card shows weather icon", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastWidget(forecast: testForecast),
          ),
        ),
      );

      // cloud_queue appears twice (Thu and Mon)
      expect(find.byIcon(Icons.cloud_queue), findsNWidgets(2));
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.byIcon(Icons.foggy), findsOneWidget);
    });

    testWidgets("each card shows high and low temperature", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastWidget(forecast: testForecast),
          ),
        ),
      );

      // 15.2->15, 14.8->15 (both round to 15), so "15°" appears twice
      expect(find.text("15\u00B0"), findsNWidgets(2));
      expect(find.text("16\u00B0"), findsOneWidget); // 16.1 high
      expect(find.text("14\u00B0"), findsOneWidget); // 13.5 rounds to 14 (high)
      expect(find.text("17\u00B0"), findsOneWidget); // 17.0 high

      // Low temps: 8.1->8, 7.5->8 (both round to 8), 9.3->9, 6.8->7, 10.2->10
      expect(find.text("8\u00B0"), findsNWidgets(2)); // 8.1 and 7.5 both round to 8
      expect(find.text("9\u00B0"), findsOneWidget); // 9.3 rounds to 9
      expect(find.text("7\u00B0"), findsOneWidget); // 6.8 rounds to 7
      expect(find.text("10\u00B0"), findsOneWidget); // 10.2 rounds to 10
    });

    testWidgets("forecast row is horizontally scrollable", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastWidget(forecast: testForecast),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
    });

    testWidgets("has Semantics label on the forecast row", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastWidget(forecast: testForecast),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label == "5-day forecast",
        ),
        findsOneWidget,
      );
    });

    testWidgets("each day card has correct Semantics label", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastWidget(forecast: testForecast),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Thu: Partly cloudy") &&
              w.properties.label!.contains("high 15 degrees") &&
              w.properties.label!.contains("low 8 degrees"),
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Fri: Rain"),
        ),
        findsOneWidget,
      );
    });
  });
}
