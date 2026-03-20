import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/resale/models/resale_history.dart";
import "package:vestiaire_mobile/src/features/resale/widgets/earnings_chart.dart";

void main() {
  group("EarningsChart", () {
    testWidgets("renders chart with provided monthly data", (tester) async {
      final data = [
        MonthlyEarnings(month: DateTime(2026, 1), earnings: 100),
        MonthlyEarnings(month: DateTime(2026, 2), earnings: 200),
        MonthlyEarnings(month: DateTime(2026, 3), earnings: 150),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarningsChart(data: data),
          ),
        ),
      );

      // Should render CustomPaint
      expect(find.byType(CustomPaint), findsWidgets);
      // Should have height of 180
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 180,
        ),
        findsOneWidget,
      );
    });

    testWidgets("shows 'No earnings data yet' when data is empty", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarningsChart(data: const []),
          ),
        ),
      );

      expect(find.text("No earnings data yet"), findsOneWidget);
    });

    testWidgets("Semantics label present", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarningsChart(data: const []),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Monthly earnings chart",
        ),
        findsOneWidget,
      );
    });
  });
}
