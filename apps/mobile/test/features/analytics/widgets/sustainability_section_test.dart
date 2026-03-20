import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/sustainability_section.dart";

Widget _buildApp({
  bool isPremium = true,
  int score = 65,
  Map<String, dynamic>? factors,
  double co2SavedKg = 10.0,
  double co2CarKmEquivalent = 47.6,
  int percentile = 35,
  bool badgeAwarded = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SustainabilitySection(
          isPremium: isPremium,
          score: score,
          factors: factors ??
              {
                "avgWearScore": 50.0,
                "utilizationScore": 60.0,
                "cpwScore": 62.5,
                "resaleScore": 100.0,
                "newPurchaseScore": 100.0,
              },
          co2SavedKg: co2SavedKg,
          co2CarKmEquivalent: co2CarKmEquivalent,
          percentile: percentile,
          badgeAwarded: badgeAwarded,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("renders PremiumGateCard when isPremium is false", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false));

    expect(find.byType(PremiumGateCard), findsOneWidget);
    expect(find.text("Sustainability Score"), findsOneWidget);
    expect(
      find.text("See your environmental impact and CO2 savings"),
      findsOneWidget,
    );
  });

  testWidgets("does NOT render score or factors when isPremium is false",
      (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false));

    expect(find.text("Sustainability"), findsNothing);
    expect(find.text("out of 100"), findsNothing);
    expect(find.text("Wear Frequency (30%)"), findsNothing);
  });

  testWidgets("renders section header 'Sustainability' with leaf icon when isPremium is true",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Sustainability"), findsOneWidget);
    expect(find.byIcon(Icons.eco), findsWidgets); // header + CO2 card
  });

  testWidgets("renders circular score ring with correct score value",
      (tester) async {
    await tester.pumpWidget(_buildApp(score: 75));

    expect(find.text("75"), findsOneWidget);
    expect(find.text("out of 100"), findsOneWidget);
  });

  testWidgets("score ring color: red for 0-33", (tester) async {
    await tester.pumpWidget(_buildApp(score: 20, co2SavedKg: 1.0));

    final scoreText = tester.widget<Text>(find.text("20"));
    expect(scoreText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("score ring color: yellow for 34-66", (tester) async {
    await tester.pumpWidget(_buildApp(score: 45));

    final scoreText = tester.widget<Text>(find.text("45"));
    expect(scoreText.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("score ring color: green for 67-100", (tester) async {
    await tester.pumpWidget(_buildApp(score: 85));

    final scoreText = tester.widget<Text>(find.text("85"));
    expect(scoreText.style?.color, const Color(0xFF22C55E));
  });

  testWidgets("renders percentile badge with correct text",
      (tester) async {
    await tester.pumpWidget(_buildApp(percentile: 35));

    expect(find.text("Top 35% of Vestiaire users"), findsOneWidget);
  });

  testWidgets("renders 5 factor rows with correct names and weights",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Wear Frequency (30%)"), findsOneWidget);
    expect(find.text("Wardrobe Utilization (25%)"), findsOneWidget);
    expect(find.text("Cost Efficiency (20%)"), findsOneWidget);
    expect(find.text("Resale Activity (15%)"), findsOneWidget);
    expect(find.text("Purchase Restraint (10%)"), findsOneWidget);
  });

  testWidgets("renders CO2 savings card with correct kg value and km equivalent",
      (tester) async {
    await tester.pumpWidget(_buildApp(co2SavedKg: 10.0, co2CarKmEquivalent: 47.6));

    expect(find.text("Estimated CO2 Saved"), findsOneWidget);
    expect(find.text("10.0 kg CO2"), findsOneWidget);
    expect(find.text("Equivalent to 47.6 km not driven"), findsOneWidget);
  });

  testWidgets("empty state shows prompt when score is 0 and co2SavedKg is 0",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      score: 0,
      co2SavedKg: 0.0,
      co2CarKmEquivalent: 0.0,
      factors: {
        "avgWearScore": 0,
        "utilizationScore": 0,
        "cpwScore": 0,
        "resaleScore": 0,
        "newPurchaseScore": 100,
      },
    ));

    expect(
      find.text("Start logging your outfits to see your sustainability impact!"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
  });

  testWidgets("badge awarded banner shows when badgeAwarded is true",
      (tester) async {
    await tester.pumpWidget(_buildApp(badgeAwarded: true));

    expect(find.text("You earned the Eco Warrior badge!"), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
  });

  testWidgets("badge awarded banner hidden when badgeAwarded is false",
      (tester) async {
    await tester.pumpWidget(_buildApp(badgeAwarded: false));

    expect(find.text("You earned the Eco Warrior badge!"), findsNothing);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
  });

  testWidgets("Semantics labels present on all key elements",
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_buildApp(
      score: 75,
      percentile: 25,
      co2SavedKg: 15.0,
    ));

    // Verify Semantics widgets exist with the correct labels
    final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Sustainability score, 75 out of 100")), isTrue);
    expect(labels.any((l) => l.contains("Top 25 percent of users")), isTrue);
    expect(labels.any((l) => l.contains("Estimated CO2 saved")), isTrue);
    expect(labels.any((l) => l.contains("Factor Wear Frequency")), isTrue);

    handle.dispose();
  });
}
