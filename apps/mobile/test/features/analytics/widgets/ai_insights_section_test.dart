import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/ai_insights_section.dart";

Widget _buildApp({
  required bool isPremium,
  String? summary,
  bool isLoading = false,
  String? error,
  VoidCallback? onRetry,
  VoidCallback? onUpgrade,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AiInsightsSection(
          isPremium: isPremium,
          summary: summary,
          isLoading: isLoading,
          error: error,
          onRetry: onRetry,
          onUpgrade: onUpgrade,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders "AI Insights" header with icon when premium and summary available',
      (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      summary: "Your wardrobe is fantastic!",
    ));

    expect(find.text("AI Insights"), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets("renders summary text in the card", (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      summary: "Your wardrobe of 10 items shows great value.",
    ));

    expect(
      find.text("Your wardrobe of 10 items shows great value."),
      findsOneWidget,
    );
  });

  testWidgets('renders "Powered by AI" label', (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      summary: "Test summary.",
    ));

    expect(find.text("Powered by AI"), findsOneWidget);
  });

  testWidgets("renders shimmer/loading state when isLoading is true",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      isLoading: true,
    ));

    // Should show the header
    expect(find.text("AI Insights"), findsOneWidget);
    // Should NOT show "Powered by AI" (loading, not loaded)
    expect(find.text("Powered by AI"), findsNothing);
  });

  testWidgets("renders error message and retry button when error is set",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      error: "Network error",
    ));

    expect(
      find.text(
        "Unable to generate insights right now. Pull to refresh to try again.",
      ),
      findsOneWidget,
    );
    expect(find.text("Retry"), findsOneWidget);
  });

  testWidgets("tapping retry calls onRetry", (tester) async {
    bool retryCalled = false;

    await tester.pumpWidget(_buildApp(
      isPremium: true,
      error: "Some error",
      onRetry: () => retryCalled = true,
    ));

    await tester.tap(find.text("Retry"));
    expect(retryCalled, isTrue);
  });

  testWidgets(
      'renders free-user teaser with "Unlock AI Wardrobe Insights" when not premium',
      (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: false,
    ));

    expect(find.text("Unlock AI Wardrobe Insights"), findsOneWidget);
    expect(
      find.text("Get personalized analysis of your wardrobe habits"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('renders "Go Premium" button in teaser state', (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: false,
    ));

    expect(find.text("Go Premium"), findsOneWidget);
  });

  testWidgets("does NOT render summary text in teaser state", (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: false,
      summary: "Should not appear",
    ));

    expect(find.text("Should not appear"), findsNothing);
    expect(find.text("Unlock AI Wardrobe Insights"), findsOneWidget);
  });

  testWidgets("semantics labels present on premium summary state",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      summary: "Great wardrobe habits!",
    ));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(
      labels.any((l) => l.contains("AI wardrobe insights")),
      isTrue,
    );
    expect(
      labels.any((l) => l.contains("AI generated summary")),
      isTrue,
    );
  });

  testWidgets("semantics labels present on free teaser state",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: false,
    ));

    final semanticsWidgets =
        tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    // PremiumGateCard uses "$title, upgrade to premium" pattern
    expect(
      labels.any((l) => l.contains("Unlock AI Wardrobe Insights")),
      isTrue,
    );
  });

  testWidgets('"Go Premium" CTA calls onUpgrade when tapped',
      (tester) async {
    bool upgradeCalled = false;

    await tester.pumpWidget(_buildApp(
      isPremium: false,
      onUpgrade: () => upgradeCalled = true,
    ));

    await tester.tap(find.text("Go Premium"));
    expect(upgradeCalled, isTrue);
  });
}
