import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/neglected_items_section.dart";

Widget _buildApp({
  List<Map<String, dynamic>>? items,
  ValueChanged<Map<String, dynamic>>? onItemTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: NeglectedItemsSection(
          items: items ?? [],
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
      "name": "Old Jacket",
      "category": "outerwear",
      "photoUrl": null,
      "purchasePrice": 200.0,
      "currency": "GBP",
      "wearCount": 5,
      "lastWornDate": "2025-10-01",
      "daysSinceWorn": 168,
      "cpw": 40.0,
    },
    {
      "id": "item-2",
      "name": "Unworn Dress",
      "category": "dresses",
      "photoUrl": null,
      "purchasePrice": 150.0,
      "currency": "GBP",
      "wearCount": 0,
      "lastWornDate": null,
      "daysSinceWorn": 200,
      "cpw": null,
    },
  ];
}

void main() {
  testWidgets("renders section header 'Neglected Items' with count",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("Neglected Items"), findsOneWidget);
    expect(find.text("(2)"), findsOneWidget);
  });

  testWidgets("displays neglected items with days since worn",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("Old Jacket"), findsOneWidget);
    expect(find.text("168 days"), findsOneWidget);
  });

  testWidgets("shows 'Never worn' for items with no last_worn_date",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    expect(find.text("Never worn"), findsOneWidget);
  });

  testWidgets("tapping an item calls onItemTap", (tester) async {
    Map<String, dynamic>? tappedItem;
    await tester.pumpWidget(_buildApp(
      items: _sampleItems(),
      onItemTap: (item) => tappedItem = item,
    ));

    await tester.tap(find.text("Old Jacket"));
    expect(tappedItem, isNotNull);
    expect(tappedItem!["id"], "item-1");
  });

  testWidgets("empty state shows positive 'great job' message",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: []));
    expect(
      find.text("No neglected items -- great job wearing your wardrobe!"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.celebration), findsOneWidget);
  });

  testWidgets("does not show count badge when items list is empty",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: []));
    expect(find.text("(0)"), findsNothing);
  });

  testWidgets("displays CPW label for items with purchase price",
      (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));
    // Item 1 has cpw = 40.0
    expect(find.textContaining("/wear"), findsOneWidget);
  });

  testWidgets("days since worn text is red", (tester) async {
    await tester.pumpWidget(_buildApp(items: [
      {
        "id": "item-1",
        "name": "Test",
        "category": "tops",
        "photoUrl": null,
        "purchasePrice": null,
        "currency": null,
        "wearCount": 1,
        "lastWornDate": "2025-10-01",
        "daysSinceWorn": 100,
        "cpw": null,
      },
    ]));
    final daysText = tester.widget<Text>(find.text("100 days"));
    expect(daysText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp(items: _sampleItems()));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Neglected items")), isTrue);
    expect(labels.any((l) => l.contains("Old Jacket")), isTrue);
  });
}
