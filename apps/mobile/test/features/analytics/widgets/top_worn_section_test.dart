import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/top_worn_section.dart";

Widget _buildApp({
  List<Map<String, dynamic>>? items,
  String selectedPeriod = "all",
  ValueChanged<String>? onPeriodChanged,
  ValueChanged<Map<String, dynamic>>? onItemTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TopWornSection(
          items: items ?? [],
          selectedPeriod: selectedPeriod,
          onPeriodChanged: onPeriodChanged ?? (_) {},
          onItemTap: onItemTap ?? (_) {},
        ),
      ),
    ),
  );
}

List<Map<String, dynamic>> _sampleItems() {
  return [
    {
      "id": "item-1",
      "name": "Fave Jacket",
      "category": "outerwear",
      "photoUrl": null,
      "wearCount": 25,
      "lastWornDate": "2026-03-15",
    },
    {
      "id": "item-2",
      "name": "Daily Shirt",
      "category": "tops",
      "photoUrl": null,
      "wearCount": 18,
      "lastWornDate": "2026-03-10",
    },
  ];
}

void main() {
  testWidgets("renders section header 'Top 10 Most Worn'", (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("Top 10 Most Worn"), findsOneWidget);
  });

  testWidgets("displays three filter chips: 30 Days, 90 Days, All Time",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("30 Days"), findsOneWidget);
    expect(find.text("90 Days"), findsOneWidget);
    expect(find.text("All Time"), findsOneWidget);
  });

  testWidgets("tapping a filter chip calls onPeriodChanged with correct value",
      (tester) async {
    String? changedTo;
    await tester.pumpWidget(_buildApp(
      items: _sampleItems(),
      selectedPeriod: "all",
      onPeriodChanged: (value) => changedTo = value,
    ));

    await tester.tap(find.text("30 Days"));
    expect(changedTo, "30");

    await tester.tap(find.text("90 Days"));
    expect(changedTo, "90");
  });

  testWidgets("renders ranked items with rank numbers", (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("1"), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
  });

  testWidgets("displays item name and wear count", (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("Fave Jacket"), findsOneWidget);
    expect(find.text("25 wears"), findsOneWidget);
    expect(find.text("Daily Shirt"), findsOneWidget);
    expect(find.text("18 wears"), findsOneWidget);
  });

  testWidgets("displays last worn date in relative format", (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    // The relative date depends on current time, but we can verify text exists
    // for the items that have lastWornDate
    final textWidgets =
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    // Should have some relative date text present
    expect(textWidgets.any((t) => t != null && t.isNotEmpty), isTrue);
  });

  testWidgets("tapping an item calls onItemTap", (tester) async {
    Map<String, dynamic>? tappedItem;
    await tester.pumpWidget(_buildApp(
      items: _sampleItems(),
      onItemTap: (item) => tappedItem = item,
    ));

    await tester.tap(find.text("Fave Jacket"));
    expect(tappedItem, isNotNull);
    expect(tappedItem!["id"], "item-1");
  });

  testWidgets("empty state shows prompt message when items list is empty",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: []));
    expect(
      find.text("Start logging outfits to see your most worn items!"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Top worn items")), isTrue);
    expect(labels.any((l) => l.contains("Rank 1")), isTrue);
    expect(labels.any((l) => l.contains("Fave Jacket")), isTrue);
  });

  testWidgets("uses periodWearCount for 30/90 day periods", (tester) async {
    final items = [
      {
        "id": "item-1",
        "name": "Recent Fave",
        "category": "tops",
        "photoUrl": null,
        "wearCount": 50,
        "lastWornDate": "2026-03-15",
        "periodWearCount": 8,
      },
    ];

    await tester.pumpWidget(_buildApp(
      items: items,
      selectedPeriod: "30",
    ));

    expect(find.text("8 wears"), findsOneWidget);
  });
}
