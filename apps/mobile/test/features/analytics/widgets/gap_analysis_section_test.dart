import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/gap_analysis_section.dart";

Widget _buildApp({
  bool isPremium = true,
  List<Map<String, dynamic>> gaps = const [],
  int totalItems = 10,
  ValueChanged<String>? onDismissGap,
  Set<String> dismissedGapIds = const {},
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GapAnalysisSection(
          isPremium: isPremium,
          gaps: gaps,
          totalItems: totalItems,
          onDismissGap: onDismissGap ?? (_) {},
          dismissedGapIds: dismissedGapIds,
        ),
      ),
    ),
  );
}

final _sampleGaps = <Map<String, dynamic>>[
  {
    "id": "gap-category-missing-outerwear",
    "dimension": "category",
    "title": "Missing Outerwear",
    "description": "Your wardrobe has no outerwear items.",
    "severity": "critical",
    "recommendation": "Consider adding a navy trench coat for rainy days",
  },
  {
    "id": "gap-weather-no-winter",
    "dimension": "weather",
    "title": "No Winter Items",
    "description": "You have no winter-appropriate clothing.",
    "severity": "critical",
    "recommendation": "Consider adding a warm wool coat for cold weather",
  },
  {
    "id": "gap-formality-no-formal",
    "dimension": "formality",
    "title": "No Formal Wear",
    "description": "Your wardrobe has no formal occasion items.",
    "severity": "important",
    "recommendation": "Consider adding a black blazer for formal events",
  },
  {
    "id": "gap-color-limited-variety",
    "dimension": "color",
    "title": "Limited Color Variety",
    "description": "Your wardrobe only uses one color group.",
    "severity": "optional",
    "recommendation": null,
  },
];

void main() {
  testWidgets("renders PremiumGateCard when isPremium is false", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false));

    expect(find.byType(PremiumGateCard), findsOneWidget);
    expect(find.text("Wardrobe Gap Analysis"), findsOneWidget);
    expect(
      find.text("Discover what's missing from your wardrobe"),
      findsOneWidget,
    );
  });

  testWidgets("does NOT render gap list when isPremium is false", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false, gaps: _sampleGaps));

    expect(find.text("Wardrobe Gaps"), findsNothing);
    expect(find.text("Missing Outerwear"), findsNothing);
  });

  testWidgets("renders section header 'Wardrobe Gaps' when isPremium is true",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: _sampleGaps));

    expect(find.text("Wardrobe Gaps"), findsOneWidget);
  });

  testWidgets("renders gap cards with correct title, description, and severity badge",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: _sampleGaps));

    expect(find.text("Missing Outerwear"), findsOneWidget);
    expect(find.text("Your wardrobe has no outerwear items."), findsOneWidget);
    expect(find.text("Critical"), findsNWidgets(2)); // two critical gaps
    expect(find.text("Important"), findsOneWidget);
    expect(find.text("Optional"), findsOneWidget);
  });

  testWidgets("severity badge colors: red for Critical, yellow for Important, grey for Optional",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: _sampleGaps));

    // Find severity badge containers by text and verify their decoration
    final criticalChips = tester.widgetList<Container>(
      find.ancestor(
        of: find.text("Critical"),
        matching: find.byType(Container),
      ),
    );
    // At least one container should have the red color
    final hasRedBg = criticalChips.any((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == const Color(0xFFEF4444);
      }
      return false;
    });
    expect(hasRedBg, isTrue);

    final importantChips = tester.widgetList<Container>(
      find.ancestor(
        of: find.text("Important"),
        matching: find.byType(Container),
      ),
    );
    final hasYellowBg = importantChips.any((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == const Color(0xFFF59E0B);
      }
      return false;
    });
    expect(hasYellowBg, isTrue);

    final optionalChips = tester.widgetList<Container>(
      find.ancestor(
        of: find.text("Optional"),
        matching: find.byType(Container),
      ),
    );
    final hasGreyBg = optionalChips.any((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == const Color(0xFF6B7280);
      }
      return false;
    });
    expect(hasGreyBg, isTrue);
  });

  testWidgets("renders dimension icons correctly for each dimension type",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: _sampleGaps));

    expect(find.byIcon(Icons.category_outlined), findsOneWidget); // category
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget); // weather
    expect(find.byIcon(Icons.business_center_outlined), findsOneWidget); // formality
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget); // color
  });

  testWidgets("renders AI recommendation when available", (tester) async {
    await tester.pumpWidget(_buildApp(gaps: [_sampleGaps[0]]));

    expect(
      find.text("Consider adding a navy trench coat for rainy days"),
      findsOneWidget,
    );
  });

  testWidgets("renders 'AI recommendation unavailable' when recommendation is null",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: [_sampleGaps[3]]));

    expect(find.text("AI recommendation unavailable"), findsOneWidget);
  });

  testWidgets("tapping dismiss button calls onDismissGap with correct gap id",
      (tester) async {
    String? dismissedId;
    await tester.pumpWidget(_buildApp(
      gaps: [_sampleGaps[0]],
      onDismissGap: (id) => dismissedId = id,
    ));

    await tester.tap(find.byIcon(Icons.close).first);
    expect(dismissedId, "gap-category-missing-outerwear");
  });

  testWidgets("dismissed gaps are filtered out of display", (tester) async {
    await tester.pumpWidget(_buildApp(
      gaps: _sampleGaps,
      dismissedGapIds: {"gap-category-missing-outerwear"},
    ));

    expect(find.text("Missing Outerwear"), findsNothing);
    expect(find.text("No Winter Items"), findsOneWidget);
    expect(find.text("No Formal Wear"), findsOneWidget);
  });

  testWidgets("empty state shows 'well-balanced' message when gaps list is empty",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: [], totalItems: 10));

    expect(
      find.text("Your wardrobe is well-balanced! No gaps detected."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_outlined), findsOneWidget);
  });

  testWidgets("empty state shows 'add more items' when totalItems < 5",
      (tester) async {
    await tester.pumpWidget(_buildApp(gaps: [], totalItems: 3));

    expect(
      find.text("Add more items to your wardrobe to see gap analysis! At least 5 items are needed."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });

  testWidgets("gaps are grouped by dimension with sub-headers", (tester) async {
    await tester.pumpWidget(_buildApp(gaps: _sampleGaps));

    expect(find.text("Category Balance"), findsOneWidget);
    expect(find.text("Weather Coverage"), findsOneWidget);
    expect(find.text("Formality Spectrum"), findsOneWidget);
    expect(find.text("Color Range"), findsOneWidget);
  });

  testWidgets("semantics labels present on key elements", (tester) async {
    await tester.pumpWidget(_buildApp(gaps: _sampleGaps));

    final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Wardrobe gap analysis")), isTrue);
    expect(labels.any((l) => l.contains("Gap: Missing Outerwear")), isTrue);
    expect(labels.any((l) => l.contains("Dismiss gap")), isTrue);
  });

  testWidgets("all gaps dismissed shows well-balanced message", (tester) async {
    final allIds = _sampleGaps.map((g) => g["id"] as String).toSet();
    await tester.pumpWidget(_buildApp(
      gaps: _sampleGaps,
      dismissedGapIds: allIds,
    ));

    expect(
      find.text("Your wardrobe is well-balanced! No gaps detected."),
      findsOneWidget,
    );
  });
}
