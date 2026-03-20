import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/weather/weather_data.dart";
import "package:vestiaire_mobile/src/features/home/widgets/weather_widget.dart";

void main() {
  group("WeatherWidget", () {
    testWidgets("loading state shows shimmer placeholder", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeatherWidget(isLoading: true),
          ),
        ),
      );

      // Shimmer placeholder renders containers for the animation
      expect(find.byType(WeatherWidget), findsOneWidget);
      // Should not show error or data elements
      expect(find.text("Retry"), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets("success state renders temperature, feels-like, condition icon, description, and location name",
        (tester) async {
      final data = WeatherData(
        temperature: 18.5,
        feelsLike: 16.2,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
        locationName: "Paris, France",
        fetchedAt: DateTime(2026, 3, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(weatherData: data),
          ),
        ),
      );

      expect(find.text("19\u00B0C"), findsOneWidget); // 18.5 rounds to 19
      expect(find.text("Feels like 16\u00B0C"), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.text("Clear sky"), findsOneWidget);
      expect(find.text("Paris, France"), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets("success state has correct Semantics label", (tester) async {
      final data = WeatherData(
        temperature: 22.0,
        feelsLike: 20.0,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
        locationName: "London, UK",
        fetchedAt: DateTime(2026, 3, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(weatherData: data),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Current weather: 22 degrees") &&
              w.properties.label!.contains("Clear sky") &&
              w.properties.label!.contains("London, UK"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("error state renders error message and retry button",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(
              errorMessage: "Weather unavailable",
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text("Weather unavailable"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("retry button triggers onRetry callback", (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(
              errorMessage: "Weather unavailable",
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Retry"));
      expect(retryCalled, true);
    });

    testWidgets("when lastUpdatedLabel is provided, it is displayed",
        (tester) async {
      final data = WeatherData(
        temperature: 18.5,
        feelsLike: 16.2,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
        locationName: "Paris, France",
        fetchedAt: DateTime(2026, 3, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(
              weatherData: data,
              lastUpdatedLabel: "15 min ago",
            ),
          ),
        ),
      );

      expect(find.text("Last updated 15 min ago"), findsOneWidget);
    });

    testWidgets("when lastUpdatedLabel is null, no staleness indicator is shown",
        (tester) async {
      final data = WeatherData(
        temperature: 18.5,
        feelsLike: 16.2,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
        locationName: "Paris, France",
        fetchedAt: DateTime(2026, 3, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(weatherData: data),
          ),
        ),
      );

      expect(find.textContaining("Last updated"), findsNothing);
    });

    testWidgets(
        "Semantics label includes 'Last updated' when label is present",
        (tester) async {
      final data = WeatherData(
        temperature: 22.0,
        feelsLike: 20.0,
        weatherCode: 0,
        weatherDescription: "Clear sky",
        weatherIcon: Icons.wb_sunny,
        locationName: "London, UK",
        fetchedAt: DateTime(2026, 3, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherWidget(
              weatherData: data,
              lastUpdatedLabel: "10 min ago",
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Last updated 10 min ago"),
        ),
        findsOneWidget,
      );
    });
  });
}
