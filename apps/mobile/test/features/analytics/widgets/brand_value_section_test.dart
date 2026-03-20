import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/brand_value_section.dart";

const _sentinel = Object();

Widget _buildApp({
  bool isPremium = true,
  List<Map<String, dynamic>>? brands,
  List<String>? availableCategories,
  Object? bestValueBrand = _sentinel,
  Object? mostInvestedBrand = _sentinel,
  String selectedCategory = "all",
  ValueChanged<String>? onCategoryChanged,
  ValueChanged<Map<String, dynamic>>? onBrandTap,
}) {
  final resolvedBestValue = identical(bestValueBrand, _sentinel)
      ? <String, dynamic>{"brand": "Uniqlo", "avgCpw": 2.50, "currency": "GBP"}
      : bestValueBrand as Map<String, dynamic>?;
  final resolvedMostInvested = identical(mostInvestedBrand, _sentinel)
      ? <String, dynamic>{"brand": "Gucci", "totalSpent": 3000.0, "currency": "GBP"}
      : mostInvestedBrand as Map<String, dynamic>?;

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BrandValueSection(
          isPremium: isPremium,
          brands: brands ??
              [
                {
                  "brand": "Uniqlo",
                  "itemCount": 5,
                  "totalSpent": 250.0,
                  "totalWears": 100,
                  "avgCpw": 2.50,
                  "pricedItems": 5,
                  "dominantCurrency": "GBP",
                },
                {
                  "brand": "Zara",
                  "itemCount": 4,
                  "totalSpent": 400.0,
                  "totalWears": 60,
                  "avgCpw": 10.0,
                  "pricedItems": 4,
                  "dominantCurrency": "GBP",
                },
                {
                  "brand": "Gucci",
                  "itemCount": 3,
                  "totalSpent": 3000.0,
                  "totalWears": 30,
                  "avgCpw": 100.0,
                  "pricedItems": 3,
                  "dominantCurrency": "GBP",
                },
              ],
          availableCategories: availableCategories ?? ["bottoms", "tops"],
          bestValueBrand: resolvedBestValue,
          mostInvestedBrand: resolvedMostInvested,
          selectedCategory: selectedCategory,
          onCategoryChanged: onCategoryChanged ?? (_) {},
          onBrandTap: onBrandTap ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("renders PremiumGateCard when isPremium is false", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false));

    expect(find.byType(PremiumGateCard), findsOneWidget);
    expect(find.text("Brand Value Analytics"), findsOneWidget);
    expect(
      find.text("Discover which brands give you the best value for money"),
      findsOneWidget,
    );
  });

  testWidgets("does NOT render brand list when isPremium is false",
      (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false));

    expect(find.text("Brand Value"), findsNothing);
    expect(find.text("Uniqlo"), findsNothing);
    expect(find.text("Zara"), findsNothing);
  });

  testWidgets("renders section header 'Brand Value' when isPremium is true",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Brand Value"), findsOneWidget);
  });

  testWidgets("renders summary metrics row with best value and most invested brands",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Best Value"), findsOneWidget);
    expect(find.text("Most Invested"), findsOneWidget);
    expect(find.text("Uniqlo"), findsAtLeastNWidgets(1)); // In summary + list
    expect(find.text("Gucci"), findsAtLeastNWidgets(1)); // In summary + list
  });

  testWidgets("renders category filter chips including All and available categories",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("All"), findsOneWidget);
    expect(find.text("Bottoms"), findsOneWidget);
    expect(find.text("Tops"), findsOneWidget);
  });

  testWidgets("tapping a category chip calls onCategoryChanged with correct value",
      (tester) async {
    String? changedCategory;
    await tester.pumpWidget(_buildApp(
      onCategoryChanged: (cat) => changedCategory = cat,
    ));

    await tester.tap(find.text("Tops"));
    expect(changedCategory, "tops");
  });

  testWidgets("renders ranked brand list with rank numbers, brand names, CPW",
      (tester) async {
    await tester.pumpWidget(_buildApp());

    // Rank badges
    expect(find.text("1"), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
    expect(find.text("3"), findsOneWidget);

    // Brand names
    expect(find.text("Uniqlo"), findsAtLeastNWidgets(1));
    expect(find.text("Zara"), findsAtLeastNWidgets(1));
    expect(find.text("Gucci"), findsAtLeastNWidgets(1));

    // CPW values
    expect(find.textContaining("/wear"), findsAtLeastNWidgets(3));

    // Wears and items
    expect(find.text("100 wears"), findsOneWidget);
    expect(find.text("5 items"), findsOneWidget);
  });

  testWidgets("CPW color coding: green < 5", (tester) async {
    await tester.pumpWidget(_buildApp(
      brands: [
        {
          "brand": "CheapBrand",
          "itemCount": 3,
          "totalSpent": 30.0,
          "totalWears": 60,
          "avgCpw": 2.0,
          "pricedItems": 3,
          "dominantCurrency": "GBP",
        },
      ],
      bestValueBrand: {"brand": "CheapBrand", "avgCpw": 2.0, "currency": "GBP"},
      mostInvestedBrand: {"brand": "CheapBrand", "totalSpent": 30.0, "currency": "GBP"},
    ));

    // Find cpw text in the brand row (bold, colored)
    final cpwTexts = tester.widgetList<Text>(find.textContaining("/wear"));
    final brandRowCpw = cpwTexts.where((t) => t.style?.fontWeight == FontWeight.bold).first;
    expect(brandRowCpw.style?.color, const Color(0xFF22C55E));
  });

  testWidgets("CPW color coding: yellow 5-20", (tester) async {
    await tester.pumpWidget(_buildApp(
      brands: [
        {
          "brand": "MidBrand",
          "itemCount": 3,
          "totalSpent": 300.0,
          "totalWears": 30,
          "avgCpw": 10.0,
          "pricedItems": 3,
          "dominantCurrency": "GBP",
        },
      ],
      bestValueBrand: {"brand": "MidBrand", "avgCpw": 10.0, "currency": "GBP"},
      mostInvestedBrand: {"brand": "MidBrand", "totalSpent": 300.0, "currency": "GBP"},
    ));

    final cpwTexts = tester.widgetList<Text>(find.textContaining("/wear"));
    final brandRowCpw = cpwTexts.where((t) => t.style?.fontWeight == FontWeight.bold).first;
    expect(brandRowCpw.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("CPW color coding: red > 20", (tester) async {
    await tester.pumpWidget(_buildApp(
      brands: [
        {
          "brand": "ExpBrand",
          "itemCount": 3,
          "totalSpent": 3000.0,
          "totalWears": 30,
          "avgCpw": 100.0,
          "pricedItems": 3,
          "dominantCurrency": "GBP",
        },
      ],
      bestValueBrand: {"brand": "ExpBrand", "avgCpw": 100.0, "currency": "GBP"},
      mostInvestedBrand: {"brand": "ExpBrand", "totalSpent": 3000.0, "currency": "GBP"},
    ));

    final cpwTexts = tester.widgetList<Text>(find.textContaining("/wear"));
    final brandRowCpw = cpwTexts.where((t) => t.style?.fontWeight == FontWeight.bold).first;
    expect(brandRowCpw.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("tapping a brand row calls onBrandTap", (tester) async {
    Map<String, dynamic>? tappedBrand;
    await tester.pumpWidget(_buildApp(
      brands: [
        {
          "brand": "TapBrand",
          "itemCount": 3,
          "totalSpent": 100.0,
          "totalWears": 50,
          "avgCpw": 5.0,
          "pricedItems": 3,
          "dominantCurrency": "GBP",
        },
      ],
      onBrandTap: (brand) => tappedBrand = brand,
    ));

    await tester.tap(find.text("TapBrand"));
    expect(tappedBrand, isNotNull);
    expect(tappedBrand!["brand"], "TapBrand");
  });

  testWidgets("empty state shows correct prompt when brands list is empty",
      (tester) async {
    await tester.pumpWidget(_buildApp(brands: []));

    expect(
      find.text(
          "Add more branded items to see brand analytics! Brands need at least 3 items to appear."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.loyalty_outlined), findsOneWidget);
  });

  testWidgets("no-price state shows N/A for CPW and note about purchase prices",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      brands: [
        {
          "brand": "NoPriceBrand",
          "itemCount": 4,
          "totalSpent": 0.0,
          "totalWears": 80,
          "avgCpw": null,
          "pricedItems": 0,
          "dominantCurrency": null,
        },
      ],
      bestValueBrand: null,
      mostInvestedBrand: null,
    ));

    expect(find.text("N/A"), findsAtLeastNWidgets(1));
    expect(
      find.text("Add purchase prices to see cost-per-wear by brand."),
      findsOneWidget,
    );
  });

  testWidgets("summary metrics show N/A when bestValueBrand or mostInvestedBrand is null",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      brands: [
        {
          "brand": "TestBrand",
          "itemCount": 3,
          "totalSpent": 100.0,
          "totalWears": 30,
          "avgCpw": 3.33,
          "pricedItems": 3,
          "dominantCurrency": "GBP",
        },
      ],
      bestValueBrand: null,
      mostInvestedBrand: null,
      availableCategories: [],
    ));

    // Both summary cards should show N/A for brand name
    expect(find.text("Best Value"), findsOneWidget);
    expect(find.text("Most Invested"), findsOneWidget);
    expect(find.text("N/A"), findsAtLeastNWidgets(2));
  });

  testWidgets("semantics labels present on key elements", (tester) async {
    await tester.pumpWidget(_buildApp());

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    // Main section semantics
    expect(labels.any((l) => l.contains("Brand value analytics")), isTrue);
    // Brand row semantics
    expect(labels.any((l) => l.contains("Rank 1")), isTrue);
    expect(labels.any((l) => l.contains("Uniqlo")), isTrue);
    // Filter semantics
    expect(labels.any((l) => l.contains("Filter by category")), isTrue);
  });
}
