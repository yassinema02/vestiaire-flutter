import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/wear_frequency_section.dart";

Widget _buildApp({required List<Map<String, dynamic>> days}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: WearFrequencySection(days: days),
      ),
    ),
  );
}

final _testDays = [
  {"day": "Mon", "dayIndex": 0, "logCount": 5},
  {"day": "Tue", "dayIndex": 1, "logCount": 3},
  {"day": "Wed", "dayIndex": 2, "logCount": 7},
  {"day": "Thu", "dayIndex": 3, "logCount": 2},
  {"day": "Fri", "dayIndex": 4, "logCount": 6},
  {"day": "Sat", "dayIndex": 5, "logCount": 8},
  {"day": "Sun", "dayIndex": 6, "logCount": 4},
];

final _zeroDays = [
  {"day": "Mon", "dayIndex": 0, "logCount": 0},
  {"day": "Tue", "dayIndex": 1, "logCount": 0},
  {"day": "Wed", "dayIndex": 2, "logCount": 0},
  {"day": "Thu", "dayIndex": 3, "logCount": 0},
  {"day": "Fri", "dayIndex": 4, "logCount": 0},
  {"day": "Sat", "dayIndex": 5, "logCount": 0},
  {"day": "Sun", "dayIndex": 6, "logCount": 0},
];

void main() {
  testWidgets("renders section header 'Wear Frequency'", (tester) async {
    await tester.pumpWidget(_buildApp(days: _testDays));
    expect(find.text("Wear Frequency"), findsOneWidget);
  });

  testWidgets("renders BarChart widget when days data is provided",
      (tester) async {
    await tester.pumpWidget(_buildApp(days: _testDays));
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets("displays 7 bars (Mon-Sun)", (tester) async {
    await tester.pumpWidget(_buildApp(days: _testDays));

    // Verify the BarChart is rendered with day labels
    expect(find.text("Mon"), findsOneWidget);
    expect(find.text("Tue"), findsOneWidget);
    expect(find.text("Wed"), findsOneWidget);
    expect(find.text("Thu"), findsOneWidget);
    expect(find.text("Fri"), findsOneWidget);
    expect(find.text("Sat"), findsOneWidget);
    expect(find.text("Sun"), findsOneWidget);
  });

  testWidgets("empty state shows prompt when all counts are 0",
      (tester) async {
    await tester.pumpWidget(_buildApp(days: _zeroDays));

    expect(
        find.text("Start logging outfits to see your weekly patterns!"),
        findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets("empty state also shown when days list is empty",
      (tester) async {
    await tester.pumpWidget(_buildApp(days: []));

    expect(
        find.text("Start logging outfits to see your weekly patterns!"),
        findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp(days: _testDays));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(
        labels.any((l) => l.contains("Wear frequency chart")), isTrue);
    expect(labels.any((l) => l.contains("outfits logged")), isTrue);
  });
}
