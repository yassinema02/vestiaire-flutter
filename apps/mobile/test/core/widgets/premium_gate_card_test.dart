import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";

Widget _buildApp({
  String title = "Test Feature",
  String subtitle = "Test subtitle description",
  IconData icon = Icons.lock_outline,
  VoidCallback? onUpgrade,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PremiumGateCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onUpgrade: onUpgrade,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("renders title text", (tester) async {
    await tester.pumpWidget(_buildApp(title: "Unlock Feature X"));

    expect(find.text("Unlock Feature X"), findsOneWidget);
  });

  testWidgets("renders subtitle text", (tester) async {
    await tester.pumpWidget(_buildApp(subtitle: "Get amazing analytics"));

    expect(find.text("Get amazing analytics"), findsOneWidget);
  });

  testWidgets("renders icon", (tester) async {
    await tester.pumpWidget(_buildApp(icon: Icons.lock_outline));

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('renders "Go Premium" CTA button', (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text("Go Premium"), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets("CTA calls onUpgrade fallback when subscriptionService is null",
      (tester) async {
    bool upgradeCalled = false;

    await tester.pumpWidget(_buildApp(
      onUpgrade: () => upgradeCalled = true,
    ));

    await tester.tap(find.text("Go Premium"));
    expect(upgradeCalled, isTrue);
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp(
      title: "AI Insights",
    ));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(
      labels.any((l) => l.contains("AI Insights, upgrade to premium")),
      isTrue,
    );
    expect(
      labels.any((l) => l.contains("Upgrade to premium for AI Insights")),
      isTrue,
    );
  });
}
