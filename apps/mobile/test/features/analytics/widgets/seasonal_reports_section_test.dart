import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/seasonal_reports_section.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_service.dart";

class _MockSubscriptionService implements SubscriptionService {
  @override
  bool get isPremiumCached => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Map<String, dynamic>> _buildSeasons({int itemCount = 5}) {
  return [
    {
      "season": "spring",
      "itemCount": itemCount,
      "totalWears": 12,
      "mostWorn": [
        {"id": "item-1", "name": "Blue Shirt", "photoUrl": null, "category": "tops", "wearCount": 10},
        {"id": "item-2", "name": "Green Pants", "photoUrl": null, "category": "bottoms", "wearCount": 8},
      ],
      "neglected": [
        {"id": "item-3", "name": "Old Jacket", "photoUrl": null, "category": "outerwear", "wearCount": 0},
      ],
      "readinessScore": 6,
      "historicalComparison": {"percentChange": 10, "comparisonText": "+10% more items worn vs last spring"},
    },
    {
      "season": "summer",
      "itemCount": itemCount,
      "totalWears": 20,
      "mostWorn": [],
      "neglected": [],
      "readinessScore": 8,
      "historicalComparison": {"percentChange": null, "comparisonText": "First summer tracked -- keep logging to see trends!"},
    },
    {
      "season": "fall",
      "itemCount": itemCount,
      "totalWears": 15,
      "mostWorn": [],
      "neglected": [],
      "readinessScore": 3,
      "historicalComparison": {"percentChange": -5, "comparisonText": "-5% fewer items worn vs last fall"},
    },
    {
      "season": "winter",
      "itemCount": itemCount,
      "totalWears": 8,
      "mostWorn": [],
      "neglected": [],
      "readinessScore": 4,
      "historicalComparison": {"percentChange": null, "comparisonText": "First winter tracked -- keep logging to see trends!"},
    },
  ];
}

Widget _buildApp({
  bool isPremium = true,
  List<Map<String, dynamic>>? seasons,
  String currentSeason = "spring",
  Map<String, dynamic>? transitionAlert,
  VoidCallback? onViewHeatmap,
  SubscriptionService? subscriptionService,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SeasonalReportsSection(
          isPremium: isPremium,
          seasons: seasons ?? _buildSeasons(),
          currentSeason: currentSeason,
          transitionAlert: transitionAlert,
          onViewHeatmap: onViewHeatmap ?? () {},
          subscriptionService: subscriptionService,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("renders PremiumGateCard when isPremium is false", (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: false,
      subscriptionService: _MockSubscriptionService(),
    ));

    expect(find.byType(PremiumGateCard), findsOneWidget);
    expect(find.text("Seasonal Reports & Heatmap"), findsOneWidget);
  });

  testWidgets("does NOT render season accordion when isPremium is false", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: false));

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text("Seasonal Reports"), findsNothing);
  });

  testWidgets("renders section header 'Seasonal Reports' when isPremium is true", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true));

    expect(find.text("Seasonal Reports"), findsOneWidget);
  });

  testWidgets("renders 4 season expansion tiles", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true));

    expect(find.byType(ExpansionTile), findsNWidgets(4));
    expect(find.text("Spring"), findsOneWidget);
    expect(find.text("Summer"), findsOneWidget);
    expect(find.text("Fall"), findsOneWidget);
    expect(find.text("Winter"), findsOneWidget);
  });

  testWidgets("current season is expanded by default", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true, currentSeason: "spring"));

    // Spring should be expanded - check for readiness score content
    expect(find.text("6/10"), findsOneWidget);
  });

  testWidgets("renders readiness score with progress bar", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true, currentSeason: "spring"));

    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text("6/10"), findsOneWidget);
  });

  testWidgets("renders historical comparison text", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true, currentSeason: "spring"));

    expect(find.text("+10% more items worn vs last spring"), findsOneWidget);
  });

  testWidgets("renders transition alert card when transitionAlert is not null", (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      transitionAlert: {
        "upcomingSeason": "summer",
        "daysUntil": 7,
        "readinessScore": 8,
      },
    ));

    expect(find.textContaining("Summer is coming in 7 days"), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });

  testWidgets("hides transition alert when transitionAlert is null", (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      transitionAlert: null,
    ));

    expect(find.byIcon(Icons.notifications_active), findsNothing);
  });

  testWidgets("renders View Heatmap button for premium users", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true));

    expect(find.text("View Heatmap"), findsOneWidget);
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
  });

  testWidgets("tapping View Heatmap calls onViewHeatmap callback", (tester) async {
    bool callbackCalled = false;

    await tester.pumpWidget(_buildApp(
      isPremium: true,
      onViewHeatmap: () => callbackCalled = true,
    ));

    // Scroll down to make View Heatmap visible using the outer ScrollView
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text("View Heatmap"), 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(find.text("View Heatmap"));
    expect(callbackCalled, isTrue);
  });

  testWidgets("empty state shows correct prompt when all seasons have 0 items", (tester) async {
    await tester.pumpWidget(_buildApp(
      isPremium: true,
      seasons: _buildSeasons(itemCount: 0),
    ));

    expect(find.text("Start logging your outfits to see seasonal patterns!"), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
  });

  testWidgets("most worn items render as horizontal scrollable thumbnails", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true, currentSeason: "spring"));

    // Spring is expanded with most worn items
    expect(find.text("Most Worn"), findsOneWidget);
    expect(find.text("Blue Shirt"), findsOneWidget);
    expect(find.text("Green Pants"), findsOneWidget);
  });

  testWidgets("neglected items render with warning badge", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true, currentSeason: "spring"));

    // Spring is expanded with neglected items
    expect(find.text("Neglected"), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets("semantics labels present on key elements", (tester) async {
    await tester.pumpWidget(_buildApp(isPremium: true, currentSeason: "spring"));

    // Check for semantics
    expect(
      find.bySemanticsLabel(RegExp("Seasonal reports")),
      findsWidgets,
    );
  });
}
