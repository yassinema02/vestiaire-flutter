import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/cpw_item_row.dart";

Widget _buildApp({
  String itemId = "item-1",
  String? name = "Blue Shirt",
  String? category = "tops",
  String? photoUrl,
  double? purchasePrice = 50.0,
  String? currency = "GBP",
  int wearCount = 10,
  double? cpw = 5.0,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CpwItemRow(
        itemId: itemId,
        name: name,
        category: category,
        photoUrl: photoUrl,
        purchasePrice: purchasePrice,
        currency: currency,
        wearCount: wearCount,
        cpw: cpw,
        onTap: onTap ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets("renders item name, purchase price, wear count, CPW value", (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.text("Blue Shirt"), findsOneWidget);
    expect(find.textContaining("\u00a350.00"), findsOneWidget); // purchase price
    expect(find.text("10 wears"), findsOneWidget);
    expect(find.textContaining("/wear"), findsOneWidget);
  });

  testWidgets("green color for CPW < 5", (tester) async {
    await tester.pumpWidget(_buildApp(cpw: 2.0, wearCount: 25));
    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFF22C55E));
  });

  testWidgets("yellow/amber color for CPW 5-20", (tester) async {
    await tester.pumpWidget(_buildApp(cpw: 10.0, wearCount: 5));
    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("red color for CPW > 20", (tester) async {
    await tester.pumpWidget(_buildApp(cpw: 50.0, wearCount: 2));
    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("No wears text for zero wear count", (tester) async {
    await tester.pumpWidget(_buildApp(wearCount: 0, cpw: null));
    expect(find.text("No wears"), findsOneWidget);
    final noWearsText = tester.widget<Text>(find.text("No wears"));
    expect(noWearsText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("tap invokes onTap callback", (tester) async {
    bool tapped = false;
    await tester.pumpWidget(_buildApp(onTap: () => tapped = true));
    await tester.tap(find.text("Blue Shirt"));
    expect(tapped, isTrue);
  });

  testWidgets("thumbnail renders fallback icon when no photoUrl", (tester) async {
    await tester.pumpWidget(_buildApp(photoUrl: null));
    expect(find.byIcon(Icons.checkroom), findsOneWidget);
  });

  testWidgets("displays category when name is null", (tester) async {
    await tester.pumpWidget(_buildApp(name: null, category: "outerwear"));
    expect(find.text("outerwear"), findsOneWidget);
  });

  testWidgets("displays Item when name and category are null", (tester) async {
    await tester.pumpWidget(_buildApp(name: null, category: null));
    expect(find.text("Item"), findsOneWidget);
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp(name: "Blue Shirt", cpw: 5.0, wearCount: 10));

    final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Blue Shirt") && l.contains("Fair value")), isTrue);
  });

  testWidgets("CPW at exactly 5.0 is yellow (boundary test)", (tester) async {
    await tester.pumpWidget(_buildApp(cpw: 5.0, wearCount: 10));
    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("CPW at exactly 20.0 is yellow (boundary test)", (tester) async {
    await tester.pumpWidget(_buildApp(cpw: 20.0, wearCount: 5));
    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("singular wear text for wearCount 1", (tester) async {
    await tester.pumpWidget(_buildApp(wearCount: 1, cpw: 50.0));
    expect(find.text("1 wear"), findsOneWidget);
  });
}
