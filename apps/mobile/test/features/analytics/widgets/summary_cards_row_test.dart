import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/summary_cards_row.dart";

Widget _buildApp({
  int totalItems = 10,
  double? totalValue = 1500.0,
  double? averageCpw = 12.50,
  String? currency = "GBP",
}) {
  return MaterialApp(
    home: Scaffold(
      body: SummaryCardsRow(
        totalItems: totalItems,
        totalValue: totalValue,
        averageCpw: averageCpw,
        currency: currency,
      ),
    ),
  );
}

void main() {
  testWidgets("displays correct total items count", (tester) async {
    await tester.pumpWidget(_buildApp(totalItems: 42));
    expect(find.text("42"), findsOneWidget);
    expect(find.text("Total Items"), findsOneWidget);
  });

  testWidgets("displays formatted wardrobe value with GBP currency symbol", (tester) async {
    await tester.pumpWidget(_buildApp(totalValue: 2450.0, currency: "GBP"));
    await tester.pumpAndSettle();
    // NumberFormat.currency with GBP symbol
    expect(find.textContaining("\u00a32,450"), findsOneWidget);
  });

  testWidgets("displays formatted average CPW with currency symbol", (tester) async {
    await tester.pumpWidget(_buildApp(averageCpw: 8.50, currency: "GBP"));
    await tester.pumpAndSettle();
    expect(find.textContaining("\u00a38.50"), findsOneWidget);
  });

  testWidgets("shows N/A when totalValue is null", (tester) async {
    await tester.pumpWidget(_buildApp(totalValue: null, averageCpw: 5.0));
    expect(find.text("N/A"), findsOneWidget);
  });

  testWidgets("shows N/A when averageCpw is null", (tester) async {
    await tester.pumpWidget(_buildApp(totalValue: 100.0, averageCpw: null));
    expect(find.text("N/A"), findsOneWidget);
  });

  testWidgets("shows N/A for both when value is zero", (tester) async {
    await tester.pumpWidget(_buildApp(totalValue: 0.0, averageCpw: null));
    expect(find.text("N/A"), findsNWidgets(2));
  });

  testWidgets("formats EUR correctly", (tester) async {
    await tester.pumpWidget(_buildApp(totalValue: 500.0, currency: "EUR"));
    await tester.pumpAndSettle();
    expect(find.textContaining("\u20ac"), findsAtLeastNWidgets(1));
  });

  testWidgets("formats USD correctly", (tester) async {
    await tester.pumpWidget(_buildApp(totalValue: 500.0, currency: "USD"));
    await tester.pumpAndSettle();
    expect(find.textContaining("\$"), findsAtLeastNWidgets(1));
  });

  testWidgets("semantics labels present on all cards", (tester) async {
    await tester.pumpWidget(_buildApp(totalItems: 10));
    await tester.pumpAndSettle();

    // Verify Semantics widgets exist with correct labels
    final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Total items: 10")), isTrue);
    expect(labels.any((l) => l.contains("Wardrobe value:")), isTrue);
    expect(labels.any((l) => l.contains("Average cost per wear:")), isTrue);
  });

  testWidgets("renders three metric card icons", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.checkroom), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
  });
}
