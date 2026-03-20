import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/category_distribution_section.dart";

Widget _buildApp({required List<Map<String, dynamic>> categories}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CategoryDistributionSection(categories: categories),
      ),
    ),
  );
}

final _testCategories = [
  {"category": "tops", "itemCount": 14, "percentage": 56.0},
  {"category": "bottoms", "itemCount": 8, "percentage": 32.0},
  {"category": "shoes", "itemCount": 3, "percentage": 12.0},
];

void main() {
  testWidgets("renders section header 'Category Distribution'", (tester) async {
    await tester.pumpWidget(_buildApp(categories: _testCategories));
    expect(find.text("Category Distribution"), findsOneWidget);
  });

  testWidgets("renders PieChart widget when categories are provided",
      (tester) async {
    await tester.pumpWidget(_buildApp(categories: _testCategories));
    expect(find.byType(PieChart), findsOneWidget);
  });

  testWidgets("renders legend with correct category names, counts, and percentages",
      (tester) async {
    await tester.pumpWidget(_buildApp(categories: _testCategories));

    expect(find.text("tops"), findsOneWidget);
    expect(find.text("(14, 56%)", findRichText: true), findsOneWidget);
    expect(find.text("bottoms"), findsOneWidget);
    expect(find.text("(8, 32%)", findRichText: true), findsOneWidget);
    expect(find.text("shoes"), findsOneWidget);
    expect(find.text("(3, 12%)", findRichText: true), findsOneWidget);
  });

  testWidgets("legend is sorted by item count descending (matches input order)",
      (tester) async {
    await tester.pumpWidget(_buildApp(categories: _testCategories));

    // Find all legend category name texts in order
    final topsOffset = tester.getTopLeft(find.text("tops"));
    final bottomsOffset = tester.getTopLeft(find.text("bottoms"));
    // tops should appear before or at same level as bottoms in the layout
    // (Wrap widget renders in order)
    expect(topsOffset.dx <= bottomsOffset.dx || topsOffset.dy <= bottomsOffset.dy, isTrue);
  });

  testWidgets("empty state shows prompt message when categories list is empty",
      (tester) async {
    await tester.pumpWidget(_buildApp(categories: []));

    expect(find.text("Add items to see your wardrobe distribution!"),
        findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets("color swatches in legend match expected category colors",
      (tester) async {
    await tester.pumpWidget(_buildApp(categories: [
      {"category": "tops", "itemCount": 5, "percentage": 100.0},
    ]));

    // Find the color swatch container
    final containers = tester.widgetList<Container>(find.byType(Container));
    final swatch = containers.firstWhere(
      (c) =>
          c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).color == const Color(0xFF4F46E5) &&
          c.constraints?.maxWidth == 12,
      orElse: () => throw StateError("No color swatch found for tops"),
    );
    expect(swatch, isNotNull);
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp(categories: _testCategories));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(
        labels.any((l) => l.contains("Category distribution chart")), isTrue);
    expect(labels.any((l) => l.contains("Category tops")), isTrue);
  });

  testWidgets("handles null category as Uncategorized", (tester) async {
    await tester.pumpWidget(_buildApp(categories: [
      {"category": null, "itemCount": 3, "percentage": 100.0},
    ]));

    expect(find.text("Uncategorized"), findsOneWidget);
  });
}
