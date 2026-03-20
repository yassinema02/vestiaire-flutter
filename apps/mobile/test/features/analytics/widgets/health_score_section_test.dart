import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/health_score_section.dart";

Widget _buildApp({
  int score = 65,
  String colorTier = "yellow",
  Map<String, dynamic>? factors,
  int percentile = 35,
  String recommendation = "Wear 6 more items this month to reach Green status",
  int totalItems = 20,
  int itemsWorn90d = 10,
  VoidCallback? onSpringCleanTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HealthScoreSection(
          score: score,
          colorTier: colorTier,
          factors: factors ??
              {
                "utilizationScore": 50.0,
                "cpwScore": 60.0,
                "sizeUtilizationScore": 50.0,
              },
          percentile: percentile,
          recommendation: recommendation,
          totalItems: totalItems,
          itemsWorn90d: itemsWorn90d,
          onSpringCleanTap: onSpringCleanTap,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("renders section header 'Wardrobe Health' with health icon",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Wardrobe Health"), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
  });

  testWidgets("renders circular score ring with correct score value",
      (tester) async {
    await tester.pumpWidget(_buildApp(score: 75));

    expect(find.text("75"), findsOneWidget);
    expect(find.text("out of 100"), findsOneWidget);
  });

  testWidgets("score ring color: red for 0-49", (tester) async {
    await tester.pumpWidget(_buildApp(score: 30, colorTier: "red"));

    final scoreText = tester.widget<Text>(
      find.text("30"),
    );
    expect(scoreText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("score ring color: yellow for 50-79", (tester) async {
    await tester.pumpWidget(_buildApp(score: 65, colorTier: "yellow"));

    final scoreText = tester.widget<Text>(
      find.text("65"),
    );
    expect(scoreText.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("score ring color: green for 80-100", (tester) async {
    await tester.pumpWidget(_buildApp(score: 90, colorTier: "green"));

    final scoreText = tester.widget<Text>(
      find.text("90"),
    );
    expect(scoreText.style?.color, const Color(0xFF22C55E));
  });

  testWidgets("renders percentile badge with correct text", (tester) async {
    await tester.pumpWidget(_buildApp(percentile: 35));

    expect(find.text("Top 35% of Vestiaire users"), findsOneWidget);
  });

  testWidgets("renders 3 factor rows with correct names and weights",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Items Worn in 90 Days (50%)"), findsOneWidget);
    expect(find.text("Cost-Per-Wear Efficiency (30%)"), findsOneWidget);
    expect(find.text("Wardrobe Size Efficiency (20%)"), findsOneWidget);
  });

  testWidgets("renders recommendation card with correct text and tier-colored background",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      colorTier: "yellow",
      recommendation: "Wear 6 more items this month to reach Green status",
    ));

    expect(find.text("Recommendation"), findsOneWidget);
    expect(
      find.text("Wear 6 more items this month to reach Green status"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
  });

  testWidgets("recommendation card has green background for green tier",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      score: 90,
      colorTier: "green",
      recommendation: "Great job!",
    ));

    // Find the recommendation container by its decoration
    final containers = tester.widgetList<Container>(find.byType(Container));
    final greenBgContainer = containers.where((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == const Color(0xFFF0FDF4);
      }
      return false;
    });
    expect(greenBgContainer.isNotEmpty, true);
  });

  testWidgets("empty state shows prompt when totalItems is 0",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      score: 0,
      colorTier: "red",
      totalItems: 0,
      recommendation: "Add items to your wardrobe to start tracking your health score!",
    ));

    expect(
      find.text("Add items to your wardrobe to see your health score!"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
  });

  testWidgets("semantics labels present on all key elements",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      score: 65,
      percentile: 35,
      recommendation: "Wear 6 more items",
    ));

    // Check key semantics labels exist
    final semanticsWidgets = find.byType(Semantics);
    expect(semanticsWidgets, findsWidgets);

    // Verify Semantics nodes contain expected labels
    final allSemantics = tester.widgetList<Semantics>(semanticsWidgets);
    final labels = allSemantics
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Wardrobe health score")), true);
    expect(labels.any((l) => l.contains("percent of users")), true);
    expect(labels.any((l) => l.contains("Factor")), true);
    expect(labels.any((l) => l.contains("Recommendation")), true);
  });

  testWidgets("renders score 0 with ring at zero", (tester) async {
    await tester.pumpWidget(_buildApp(score: 0, colorTier: "red"));

    expect(find.text("0"), findsOneWidget);
    expect(find.text("out of 100"), findsOneWidget);
  });

  testWidgets("renders score 100 correctly", (tester) async {
    await tester.pumpWidget(_buildApp(score: 100, colorTier: "green"));

    expect(find.text("100"), findsOneWidget);
  });

  testWidgets("renders factor progress bars", (tester) async {
    await tester.pumpWidget(_buildApp());

    // Should have 3 LinearProgressIndicator widgets (one per factor)
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
  });

  testWidgets("Spring Clean button is visible on HealthScoreSection",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Spring Clean"), findsOneWidget);
    expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
  });

  testWidgets("Tapping Spring Clean triggers the callback", (tester) async {
    bool tapped = false;
    await tester.pumpWidget(_buildApp(
      onSpringCleanTap: () => tapped = true,
    ));

    await tester.tap(find.text("Spring Clean"));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
