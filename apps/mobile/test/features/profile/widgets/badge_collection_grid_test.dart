import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/badge_collection_grid.dart";

List<Map<String, dynamic>> _buildCatalog({int count = 15}) {
  return List.generate(count, (i) => {
    "key": "badge_$i",
    "name": "Badge $i",
    "description": "Description $i",
    "iconName": i == 0 ? "star" : "checkroom",
    "iconColor": "#FBBF24",
    "category": "wardrobe",
    "sortOrder": i + 1,
  });
}

List<Map<String, dynamic>> _buildEarned(List<int> indices) {
  return indices.map((i) => {
    "key": "badge_$i",
    "name": "Badge $i",
    "description": "Description $i",
    "iconName": "star",
    "iconColor": "#FBBF24",
    "category": "wardrobe",
    "awardedAt": "2026-03-19T10:00:00Z",
  }).toList();
}

void main() {
  testWidgets("Renders 15 badge cells in a 3-column grid", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: _buildCatalog(),
            earnedBadges: [],
          ),
        ),
      ),
    ));

    // Should find 15 cells with badge names
    for (var i = 0; i < 15; i++) {
      expect(find.text("Badge $i"), findsOneWidget);
    }
  });

  testWidgets("Earned badges show colored icon", (tester) async {
    final catalog = _buildCatalog(count: 1);
    final earned = _buildEarned([0]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: earned,
          ),
        ),
      ),
    ));

    final iconWidget = tester.widget<Icon>(find.byType(Icon).first);
    // Earned badge color should be parsed from #FBBF24
    expect(iconWidget.color, const Color(0xFFFBBF24));
  });

  testWidgets("Unearned badges show gray icon (#D1D5DB)", (tester) async {
    final catalog = _buildCatalog(count: 1);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: [],
          ),
        ),
      ),
    ));

    final iconWidget = tester.widget<Icon>(find.byType(Icon).first);
    expect(iconWidget.color, const Color(0xFFD1D5DB));
  });

  testWidgets("Earned badges show glow border", (tester) async {
    final catalog = _buildCatalog(count: 1);
    final earned = _buildEarned([0]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: earned,
          ),
        ),
      ),
    ));

    // Find the container with border decoration
    final containers = tester.widgetList<Container>(find.byType(Container));
    final decorated = containers.where((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.border != null;
      }
      return false;
    });
    expect(decorated, isNotEmpty);
  });

  testWidgets("Badge name renders below icon", (tester) async {
    final catalog = [
      {
        "key": "test",
        "name": "Test Badge",
        "description": "Test",
        "iconName": "star",
        "iconColor": "#FBBF24",
        "category": "wardrobe",
        "sortOrder": 1,
      }
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: [],
          ),
        ),
      ),
    ));

    expect(find.text("Test Badge"), findsOneWidget);
  });

  testWidgets("Tapping a badge fires onBadgeTap callback with correct data", (tester) async {
    Map<String, dynamic>? tappedBadge;
    bool? tappedIsEarned;

    final catalog = _buildCatalog(count: 1);
    final earned = _buildEarned([0]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: earned,
            onBadgeTap: (badge, isEarned) {
              tappedBadge = badge;
              tappedIsEarned = isEarned;
            },
          ),
        ),
      ),
    ));

    await tester.tap(find.text("Badge 0"));
    await tester.pump();

    expect(tappedBadge, isNotNull);
    expect(tappedBadge!["key"], "badge_0");
    expect(tappedIsEarned, true);
  });

  testWidgets("Semantics labels present on each cell", (tester) async {
    final catalog = _buildCatalog(count: 2);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: _buildEarned([0]),
          ),
        ),
      ),
    ));

    expect(
      find.bySemanticsLabel(RegExp(r"Badge: Badge 0, earned")),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r"Badge: Badge 1, locked")),
      findsOneWidget,
    );
  });

  testWidgets("Unknown icon name falls back to help_outline", (tester) async {
    final catalog = [
      {
        "key": "unknown",
        "name": "Unknown",
        "description": "Test",
        "iconName": "nonexistent_icon",
        "iconColor": "#FBBF24",
        "category": "wardrobe",
        "sortOrder": 1,
      }
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BadgeCollectionGrid(
            allBadges: catalog,
            earnedBadges: [],
          ),
        ),
      ),
    ));

    final iconWidget = tester.widget<Icon>(find.byType(Icon).first);
    expect(iconWidget.icon, Icons.help_outline);
  });
}
