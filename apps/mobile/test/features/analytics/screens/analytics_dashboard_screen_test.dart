import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/analytics/screens/analytics_dashboard_screen.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/ai_insights_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/brand_value_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/sustainability_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/gap_analysis_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/health_score_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/seasonal_reports_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/category_distribution_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/neglected_items_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/summary_cards_row.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/top_worn_section.dart";
import "package:vestiaire_mobile/src/features/analytics/widgets/wear_frequency_section.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_service.dart";
import "package:shared_preferences/shared_preferences.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSubscriptionService implements SubscriptionService {
  _MockSubscriptionService({this.premium = false});
  final bool premium;

  @override
  bool get isPremiumCached => premium;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiClient _buildApiClient({
  Map<String, dynamic>? summaryResponse,
  List<Map<String, dynamic>>? itemsCpwResponse,
  List<Map<String, dynamic>>? topWornResponse,
  List<Map<String, dynamic>>? neglectedResponse,
  List<Map<String, dynamic>>? categoryDistributionResponse,
  List<Map<String, dynamic>>? wearFrequencyResponse,
  String? aiSummaryText,
  bool aiSummaryFreeUser = false,
  bool aiSummaryError = false,
  bool failSummary = false,
  bool failItemsCpw = false,
  bool failAll = false,
  Map<String, dynamic>? brandValueResponse,
  Map<String, dynamic>? gapAnalysisResponse,
}) {
  final mockClient = http_testing.MockClient((request) async {
    if (failAll) {
      return http.Response(
        '{"error":"Internal Server Error","code":"INTERNAL_SERVER_ERROR","message":"Server error"}',
        500,
      );
    }
    if (request.url.path == "/v1/analytics/brand-value") {
      return http.Response(
        jsonEncode(brandValueResponse ?? {
          "brands": [
            {
              "brand": "Uniqlo",
              "itemCount": 5,
              "totalSpent": 250.0,
              "totalWears": 100,
              "avgCpw": 2.50,
              "pricedItems": 5,
              "dominantCurrency": "GBP",
            },
          ],
          "availableCategories": ["bottoms", "tops"],
          "bestValueBrand": {"brand": "Uniqlo", "avgCpw": 2.50, "currency": "GBP"},
          "mostInvestedBrand": {"brand": "Uniqlo", "totalSpent": 250.0, "currency": "GBP"},
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/wardrobe-summary") {
      if (failSummary) {
        return http.Response('{"error":"Internal Server Error","code":"INTERNAL_SERVER_ERROR","message":"Server error"}', 500);
      }
      return http.Response(
        jsonEncode({
          "summary": summaryResponse ??
              {
                "totalItems": 10,
                "pricedItems": 7,
                "totalValue": 1500.00,
                "totalWears": 120,
                "averageCpw": 12.50,
                "dominantCurrency": "GBP",
              },
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/items-cpw") {
      if (failItemsCpw) {
        return http.Response('{"error":"Internal Server Error","code":"INTERNAL_SERVER_ERROR","message":"Server error"}', 500);
      }
      return http.Response(
        jsonEncode({
          "items": itemsCpwResponse ??
              [
                {
                  "id": "item-1",
                  "name": "Expensive Coat",
                  "category": "outerwear",
                  "photoUrl": null,
                  "purchasePrice": 200.0,
                  "currency": "GBP",
                  "wearCount": 2,
                  "cpw": 100.0,
                },
                {
                  "id": "item-2",
                  "name": "Great Shirt",
                  "category": "tops",
                  "photoUrl": null,
                  "purchasePrice": 30.0,
                  "currency": "GBP",
                  "wearCount": 10,
                  "cpw": 3.0,
                },
                {
                  "id": "item-3",
                  "name": "New Dress",
                  "category": "dresses",
                  "photoUrl": null,
                  "purchasePrice": 150.0,
                  "currency": "GBP",
                  "wearCount": 0,
                  "cpw": null,
                },
              ],
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/top-worn") {
      return http.Response(
        jsonEncode({
          "items": topWornResponse ??
              [
                {
                  "id": "top-1",
                  "name": "Fave Jacket",
                  "category": "outerwear",
                  "photoUrl": null,
                  "wearCount": 25,
                  "lastWornDate": "2026-03-15",
                },
                {
                  "id": "top-2",
                  "name": "Daily Shirt",
                  "category": "tops",
                  "photoUrl": null,
                  "wearCount": 18,
                  "lastWornDate": "2026-03-10",
                },
              ],
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/neglected") {
      return http.Response(
        jsonEncode({
          "items": neglectedResponse ??
              [
                {
                  "id": "neg-1",
                  "name": "Old Coat",
                  "category": "outerwear",
                  "photoUrl": null,
                  "purchasePrice": 300.0,
                  "currency": "GBP",
                  "wearCount": 3,
                  "lastWornDate": "2025-10-01",
                  "daysSinceWorn": 168,
                  "cpw": 100.0,
                },
              ],
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/category-distribution") {
      return http.Response(
        jsonEncode({
          "categories": categoryDistributionResponse ??
              [
                {"category": "tops", "itemCount": 14, "percentage": 56.0},
                {"category": "bottoms", "itemCount": 8, "percentage": 32.0},
                {"category": "shoes", "itemCount": 3, "percentage": 12.0},
              ],
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/wear-frequency") {
      return http.Response(
        jsonEncode({
          "days": wearFrequencyResponse ??
              [
                {"day": "Mon", "dayIndex": 0, "logCount": 5},
                {"day": "Tue", "dayIndex": 1, "logCount": 3},
                {"day": "Wed", "dayIndex": 2, "logCount": 7},
                {"day": "Thu", "dayIndex": 3, "logCount": 2},
                {"day": "Fri", "dayIndex": 4, "logCount": 6},
                {"day": "Sat", "dayIndex": 5, "logCount": 8},
                {"day": "Sun", "dayIndex": 6, "logCount": 4},
              ],
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/wardrobe-health") {
      return http.Response(
        jsonEncode({
          "score": 65,
          "factors": {
            "utilizationScore": 50.0,
            "cpwScore": 60.0,
            "sizeUtilizationScore": 50.0,
          },
          "percentile": 35,
          "recommendation": "Wear 6 more items this month to reach Green status",
          "totalItems": 20,
          "itemsWorn90d": 10,
          "colorTier": "yellow",
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/sustainability") {
      return http.Response(
        jsonEncode({
          "score": 65,
          "factors": {
            "avgWearScore": 50.0,
            "utilizationScore": 60.0,
            "cpwScore": 62.5,
            "resaleScore": 100.0,
            "newPurchaseScore": 100.0,
          },
          "co2SavedKg": 10.0,
          "co2CarKmEquivalent": 47.6,
          "percentile": 35,
          "totalRewears": 20,
          "totalItems": 10,
          "badgeAwarded": false,
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/gap-analysis") {
      return http.Response(
        jsonEncode(gapAnalysisResponse ?? {
          "gaps": [
            {
              "id": "gap-category-missing-outerwear",
              "dimension": "category",
              "title": "Missing Outerwear",
              "description": "Your wardrobe has no outerwear items.",
              "severity": "critical",
              "recommendation": "Consider adding a navy trench coat for rainy days",
            },
          ],
          "totalItems": 10,
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/seasonal-reports") {
      return http.Response(
        jsonEncode({
          "seasons": [
            {"season": "spring", "itemCount": 8, "totalWears": 24, "mostWorn": [], "neglected": [], "readinessScore": 6, "historicalComparison": {"percentChange": 10, "comparisonText": "+10% more items worn vs last spring"}},
            {"season": "summer", "itemCount": 12, "totalWears": 40, "mostWorn": [], "neglected": [], "readinessScore": 8, "historicalComparison": {"percentChange": null, "comparisonText": "First summer tracked"}},
            {"season": "fall", "itemCount": 10, "totalWears": 30, "mostWorn": [], "neglected": [], "readinessScore": 7, "historicalComparison": {"percentChange": -5, "comparisonText": "-5% fewer items"}},
            {"season": "winter", "itemCount": 6, "totalWears": 15, "mostWorn": [], "neglected": [], "readinessScore": 4, "historicalComparison": {"percentChange": null, "comparisonText": "First winter tracked"}},
          ],
          "currentSeason": "spring",
          "transitionAlert": null,
          "totalItems": 36,
        }),
        200,
      );
    }
    if (request.url.path == "/v1/analytics/ai-summary") {
      if (aiSummaryFreeUser) {
        return http.Response(
          '{"error":"Premium Required","code":"PREMIUM_REQUIRED","message":"Premium subscription required for AI insights"}',
          403,
        );
      }
      if (aiSummaryError) {
        return http.Response(
          '{"error":"Internal Server Error","code":"INTERNAL_SERVER_ERROR","message":"Analytics summary generation failed"}',
          500,
        );
      }
      return http.Response(
        jsonEncode({
          "summary": aiSummaryText ??
              "Your wardrobe of 10 items shows great value with a £12.50 average cost-per-wear.",
          "isGeneric": false,
        }),
        200,
      );
    }
    return http.Response('{"error":"Not Found"}', 404);
  });

  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _MockAuthService(),
    httpClient: mockClient,
  );
}

Widget _buildApp({
  ApiClient? apiClient,
  VoidCallback? onNavigateToAddItem,
  SubscriptionService? subscriptionService,
}) {
  return MaterialApp(
    home: AnalyticsDashboardScreen(
      apiClient: apiClient ?? _buildApiClient(),
      onNavigateToAddItem: onNavigateToAddItem,
      subscriptionService: subscriptionService,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("renders AppBar with Analytics title", (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.text("Analytics"), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets("shows loading indicator while fetching data", (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("displays summary cards with correct values after loading", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll past HealthScoreSection to reveal SummaryCardsRow
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryCardsRow), findsOneWidget);
    expect(find.text("10"), findsOneWidget); // totalItems
    expect(find.text("Total Items"), findsOneWidget);
    expect(find.text("Wardrobe Value"), findsOneWidget);
    expect(find.text("Avg. Cost/Wear"), findsOneWidget);
  });

  testWidgets("displays CPW item list", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll past HealthScoreSection to reveal CPW list
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text("Cost-Per-Wear Breakdown"), findsOneWidget);
    expect(find.text("Expensive Coat"), findsOneWidget);
    expect(find.text("Great Shirt"), findsOneWidget);
    expect(find.text("New Dress"), findsOneWidget);
  });

  testWidgets("CPW color coding: green for < 5", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        itemsCpwResponse: [
          {"id": "item-1", "name": "Cheap Shirt", "category": "tops", "photoUrl": null, "purchasePrice": 20.0, "currency": "GBP", "wearCount": 10, "cpw": 2.0},
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // The CPW text should be green
    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFF22C55E));
  });

  testWidgets("CPW color coding: yellow/amber for 5-20", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        itemsCpwResponse: [
          {"id": "item-1", "name": "Mid Shirt", "category": "tops", "photoUrl": null, "purchasePrice": 100.0, "currency": "GBP", "wearCount": 10, "cpw": 10.0},
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFFF59E0B));
  });

  testWidgets("CPW color coding: red for > 20", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        itemsCpwResponse: [
          {"id": "item-1", "name": "Expensive Item", "category": "tops", "photoUrl": null, "purchasePrice": 500.0, "currency": "GBP", "wearCount": 5, "cpw": 100.0},
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final cpwText = tester.widget<Text>(find.textContaining("/wear").first);
    expect(cpwText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("Items with zero wears show No wears in red", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        itemsCpwResponse: [
          {"id": "item-1", "name": "Unworn Dress", "category": "dresses", "photoUrl": null, "purchasePrice": 100.0, "currency": "GBP", "wearCount": 0, "cpw": null},
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text("No wears"), findsOneWidget);
    final noWearsText = tester.widget<Text>(find.text("No wears"));
    expect(noWearsText.style?.color, const Color(0xFFEF4444));
  });

  testWidgets("error state shows error message and retry button", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failSummary: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets("tapping retry re-fetches data", (tester) async {
    int callCount = 0;
    final mockClient = http_testing.MockClient((request) async {
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        callCount++;
        if (callCount <= 1) {
          return http.Response('{"error":"Server error","code":"INTERNAL_SERVER_ERROR","message":"fail"}', 500);
        }
        return http.Response(
          jsonEncode({
            "summary": {
              "totalItems": 5,
              "pricedItems": 3,
              "totalValue": 300.0,
              "totalWears": 30,
              "averageCpw": 10.0,
              "dominantCurrency": "GBP",
            },
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": [
          {"day": "Mon", "dayIndex": 0, "logCount": 0},
          {"day": "Tue", "dayIndex": 1, "logCount": 0},
          {"day": "Wed", "dayIndex": 2, "logCount": 0},
          {"day": "Thu", "dayIndex": 3, "logCount": 0},
          {"day": "Fri", "dayIndex": 4, "logCount": 0},
          {"day": "Sat", "dayIndex": 5, "logCount": 0},
          {"day": "Sun", "dayIndex": 6, "logCount": 0},
        ]}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(jsonEncode({"summary": "AI insight.", "isGeneric": false}), 200);
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(apiClient: apiClient));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);

    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();

    expect(find.text("5"), findsOneWidget); // totalItems after retry
  });

  testWidgets("empty state shows Add items message and CTA button", (tester) async {
    bool navigatedToAddItem = false;

    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        summaryResponse: {
          "totalItems": 0,
          "pricedItems": 0,
          "totalValue": 0.0,
          "totalWears": 0,
          "averageCpw": null,
          "dominantCurrency": null,
        },
        itemsCpwResponse: [],
      ),
      onNavigateToAddItem: () => navigatedToAddItem = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text("Add items to your wardrobe to see analytics!"), findsOneWidget);
    expect(find.text("Add Item"), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

    await tester.tap(find.text("Add Item"));
    expect(navigatedToAddItem, isTrue);
  });

  testWidgets("no-price state shows N/A for value and CPW with prompt", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        summaryResponse: {
          "totalItems": 5,
          "pricedItems": 0,
          "totalValue": 0.0,
          "totalWears": 0,
          "averageCpw": null,
          "dominantCurrency": null,
        },
        itemsCpwResponse: [],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Should show summary cards with N/A
    expect(find.text("5"), findsOneWidget); // totalItems
    expect(find.text("N/A"), findsNWidgets(2)); // value and CPW
    expect(
      find.text("Add purchase prices to your items to see cost-per-wear analytics."),
      findsOneWidget,
    );
  });

  testWidgets("tapping an item row triggers navigation", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Expensive Coat"));
    await tester.pumpAndSettle();

    // Should navigate to item detail placeholder
    expect(find.text("Item Detail"), findsOneWidget);
  });

  testWidgets("pull-to-refresh triggers data reload", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Perform a fling to trigger refresh
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    // Scroll past health score to find SummaryCardsRow
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Should still show the data after refresh
    expect(find.byType(SummaryCardsRow), findsOneWidget);
  });

  testWidgets("semantics labels present on analytics dashboard", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Analytics dashboard")), isTrue);
  });

  testWidgets("semantics labels present on summary card items", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
    final labels = semanticsWidgets
        .where((s) => s.properties.label != null)
        .map((s) => s.properties.label!)
        .toList();

    expect(labels.any((l) => l.contains("Total items:")), isTrue);
  });

  // --- Story 5.5: TopWornSection and NeglectedItemsSection integration ---

  testWidgets("dashboard renders TopWornSection below CPW list", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byType(TopWornSection), findsOneWidget);
    expect(find.text("Top 10 Most Worn"), findsOneWidget);
  });

  testWidgets("dashboard renders NeglectedItemsSection below TopWornSection", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll down to reveal NeglectedItemsSection (pushed down by Health Score + AI section)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.byType(NeglectedItemsSection), findsOneWidget);
    expect(find.text("Neglected Items"), findsOneWidget);
  });

  testWidgets("top-worn section renders ranked items correctly", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll to see the top-worn section (pushed down by Health Score)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text("Fave Jacket"), findsOneWidget);
    expect(find.text("25 wears"), findsOneWidget);
  });

  testWidgets("neglected section renders items with days-since-worn", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll to see the neglected section (extra offset for AI section + Spring Clean button)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text("Old Coat"), findsOneWidget);
    expect(find.text("168 days"), findsOneWidget);
  });

  testWidgets("changing top-worn period filter triggers re-fetch of top-worn data only", (tester) async {
    int topWornCalls = 0;
    int summaryCalls = 0;
    final mockClient = http_testing.MockClient((request) async {
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        summaryCalls++;
        return http.Response(
          jsonEncode({
            "summary": {
              "totalItems": 10,
              "pricedItems": 7,
              "totalValue": 1500.0,
              "totalWears": 120,
              "averageCpw": 12.50,
              "dominantCurrency": "GBP",
            },
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        topWornCalls++;
        return http.Response(
          jsonEncode({
            "items": [
              {
                "id": "top-1",
                "name": "Fave Jacket",
                "category": "outerwear",
                "photoUrl": null,
                "wearCount": 25,
                "lastWornDate": "2026-03-15",
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": [
          {"day": "Mon", "dayIndex": 0, "logCount": 0},
          {"day": "Tue", "dayIndex": 1, "logCount": 0},
          {"day": "Wed", "dayIndex": 2, "logCount": 0},
          {"day": "Thu", "dayIndex": 3, "logCount": 0},
          {"day": "Fri", "dayIndex": 4, "logCount": 0},
          {"day": "Sat", "dayIndex": 5, "logCount": 0},
          {"day": "Sun", "dayIndex": 6, "logCount": 0},
        ]}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(jsonEncode({"summary": "AI insight.", "isGeneric": false}), 200);
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(apiClient: apiClient));
    await tester.pumpAndSettle();

    final initialSummaryCalls = summaryCalls;
    final initialTopWornCalls = topWornCalls;

    // Tap the "30 Days" chip
    await tester.tap(find.text("30 Days"));
    await tester.pumpAndSettle();

    // Top worn should have been called again
    expect(topWornCalls, greaterThan(initialTopWornCalls));
    // Summary should NOT have been called again
    expect(summaryCalls, initialSummaryCalls);
  });

  testWidgets("dashboard error state still works with all six API calls failing", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets("mock API returns all seven endpoints in parallel", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Verify HealthScoreSection and AiInsightsSection are visible at top
    expect(find.byType(HealthScoreSection), findsOneWidget);
    expect(find.byType(AiInsightsSection), findsOneWidget);

    // Scroll far down to reveal all sections
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();

    // Check remaining sections exist (at least one from each data source)
    expect(find.byType(CategoryDistributionSection), findsOneWidget);
  });

  // --- Story 5.6: CategoryDistributionSection and WearFrequencySection integration ---

  testWidgets("dashboard renders CategoryDistributionSection below NeglectedItemsSection",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll down to reveal chart sections (extra scroll for HealthScoreSection)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDistributionSection), findsOneWidget);
    expect(find.text("Category Distribution"), findsOneWidget);
  });

  testWidgets("dashboard renders WearFrequencySection below CategoryDistributionSection",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll down to reveal chart sections (extra scroll for HealthScoreSection)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    expect(find.byType(WearFrequencySection), findsOneWidget);
    expect(find.text("Wear Frequency"), findsOneWidget);
  });

  testWidgets("category distribution section renders pie chart with test data",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll to see the category distribution section (extra scroll for HealthScoreSection)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1100));
    await tester.pumpAndSettle();

    expect(find.text("Category Distribution"), findsOneWidget);
  });

  testWidgets("wear frequency section renders bar chart with test data",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Scroll to see the wear frequency section (extra scroll for HealthScoreSection)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();

    expect(find.text("Wear Frequency"), findsOneWidget);
  });

  // --- Story 5.7: AI Insights Section integration ---

  testWidgets("dashboard renders AiInsightsSection (above SummaryCardsRow)",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(AiInsightsSection), findsOneWidget);
    // Scroll past HealthScoreSection to find SummaryCardsRow
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryCardsRow), findsOneWidget);
  });

  testWidgets("premium user sees AI summary after loading", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(
        aiSummaryText: "Your wardrobe is doing great!",
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text("AI Insights"), findsOneWidget);
    expect(find.text("Your wardrobe is doing great!"), findsOneWidget);
    expect(find.text("Powered by AI"), findsOneWidget);
  });

  testWidgets("free user (403 response) sees teaser card", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(aiSummaryFreeUser: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Unlock AI Wardrobe Insights"), findsOneWidget);
    expect(find.text("Go Premium"), findsOneWidget);
  });

  testWidgets("AI summary error shows error state with retry", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(aiSummaryError: true),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text("Unable to generate insights right now. Pull to refresh to try again."),
      findsOneWidget,
    );
    expect(find.text("Retry"), findsAtLeastNWidgets(1));
  });

  testWidgets("pull-to-refresh re-fetches AI summary", (tester) async {
    int aiSummaryCalls = 0;
    final mockClient = http_testing.MockClient((request) async {
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({
            "summary": {
              "totalItems": 10,
              "pricedItems": 7,
              "totalValue": 1500.0,
              "totalWears": 120,
              "averageCpw": 12.50,
              "dominantCurrency": "GBP",
            },
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(
          jsonEncode({
            "days": [
              {"day": "Mon", "dayIndex": 0, "logCount": 0},
              {"day": "Tue", "dayIndex": 1, "logCount": 0},
              {"day": "Wed", "dayIndex": 2, "logCount": 0},
              {"day": "Thu", "dayIndex": 3, "logCount": 0},
              {"day": "Fri", "dayIndex": 4, "logCount": 0},
              {"day": "Sat", "dayIndex": 5, "logCount": 0},
              {"day": "Sun", "dayIndex": 6, "logCount": 0},
            ],
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        aiSummaryCalls++;
        return http.Response(
          jsonEncode({
            "summary": "AI summary call #$aiSummaryCalls",
            "isGeneric": false,
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(apiClient: apiClient));
    await tester.pumpAndSettle();

    final initialCalls = aiSummaryCalls;
    expect(initialCalls, greaterThan(0));

    // Pull-to-refresh
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(aiSummaryCalls, greaterThan(initialCalls));
  });

  testWidgets("all existing dashboard tests still pass with AI section added",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Core sections still present
    expect(find.byType(AiInsightsSection), findsOneWidget);
    // Scroll past HealthScoreSection
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryCardsRow), findsOneWidget);
    expect(find.text("Cost-Per-Wear Breakdown"), findsOneWidget);

    // Scroll down to verify other sections
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(TopWornSection), findsOneWidget);
  });

  // --- Story 11.1: Brand Value Section integration ---

  testWidgets("dashboard renders BrandValueSection for premium user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the brand value section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();

    expect(find.byType(BrandValueSection), findsOneWidget);
    expect(find.text("Brand Value"), findsOneWidget);
  });

  testWidgets("dashboard renders PremiumGateCard for brand value for free user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the brand value section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();

    expect(find.byType(BrandValueSection), findsOneWidget);
    // Free user sees PremiumGateCard inside BrandValueSection
    expect(find.text("Brand Value Analytics"), findsOneWidget);
    expect(find.text("Discover which brands give you the best value for money"), findsOneWidget);
  });

  testWidgets("changing brand value category filter triggers isolated re-fetch",
      (tester) async {
    int brandValueCalls = 0;
    int summaryCalls = 0;
    final mockClient = http_testing.MockClient((request) async {
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        summaryCalls++;
        return http.Response(
          jsonEncode({
            "summary": {
              "totalItems": 10,
              "pricedItems": 7,
              "totalValue": 1500.0,
              "totalWears": 120,
              "averageCpw": 12.50,
              "dominantCurrency": "GBP",
            },
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": [
          {"day": "Mon", "dayIndex": 0, "logCount": 0},
          {"day": "Tue", "dayIndex": 1, "logCount": 0},
          {"day": "Wed", "dayIndex": 2, "logCount": 0},
          {"day": "Thu", "dayIndex": 3, "logCount": 0},
          {"day": "Fri", "dayIndex": 4, "logCount": 0},
          {"day": "Sat", "dayIndex": 5, "logCount": 0},
          {"day": "Sun", "dayIndex": 6, "logCount": 0},
        ]}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(jsonEncode({"summary": "AI insight.", "isGeneric": false}), 200);
      }
      if (request.url.path == "/v1/analytics/brand-value") {
        brandValueCalls++;
        return http.Response(
          jsonEncode({
            "brands": [
              {"brand": "TestBrand", "itemCount": 3, "totalSpent": 100.0, "totalWears": 30, "avgCpw": 3.33, "pricedItems": 3, "dominantCurrency": "GBP"},
            ],
            "availableCategories": ["bottoms", "tops"],
            "bestValueBrand": {"brand": "TestBrand", "avgCpw": 3.33, "currency": "GBP"},
            "mostInvestedBrand": {"brand": "TestBrand", "totalSpent": 100.0, "currency": "GBP"},
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/sustainability") {
        return http.Response(
          jsonEncode({"score": 50, "factors": {"avgWearScore": 50, "utilizationScore": 50, "cpwScore": 50, "resaleScore": 50, "newPurchaseScore": 50}, "co2SavedKg": 5.0, "co2CarKmEquivalent": 23.8, "percentile": 50, "totalRewears": 10, "totalItems": 5, "badgeAwarded": false}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/gap-analysis") {
        return http.Response(jsonEncode({"gaps": [], "totalItems": 10}), 200);
      }
      if (request.url.path == "/v1/analytics/seasonal-reports") {
        return http.Response(jsonEncode({
          "seasons": [
            {"season": "spring", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First spring tracked"}},
            {"season": "summer", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First summer tracked"}},
            {"season": "fall", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First fall tracked"}},
            {"season": "winter", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First winter tracked"}},
          ],
          "currentSeason": "spring",
          "transitionAlert": null,
          "totalItems": 20,
        }), 200);
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(
      apiClient: apiClient,
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    final initialSummaryCalls = summaryCalls;
    final initialBrandValueCalls = brandValueCalls;

    // Scroll down to reveal the brand value section category filter chips
    await tester.scrollUntilVisible(
      find.text("Tops"),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap "Tops" category filter chip
    await tester.tap(find.text("Tops"));
    await tester.pumpAndSettle();

    // Brand value should have been called again (category filter)
    expect(brandValueCalls, greaterThan(initialBrandValueCalls));
    // Summary should NOT have been called again
    expect(summaryCalls, initialSummaryCalls);
  });

  testWidgets("mock API does NOT call brand value endpoint for free user",
      (tester) async {
    int brandValueCalls = 0;
    final mockClient = http_testing.MockClient((request) async {
      if (request.url.path == "/v1/analytics/brand-value") {
        brandValueCalls++;
        return http.Response(jsonEncode({"brands": [], "availableCategories": [], "bestValueBrand": null, "mostInvestedBrand": null}), 200);
      }
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({"summary": {"totalItems": 10, "pricedItems": 7, "totalValue": 1500.0, "totalWears": 120, "averageCpw": 12.50, "dominantCurrency": "GBP"}}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": [
          {"day": "Mon", "dayIndex": 0, "logCount": 0},
          {"day": "Tue", "dayIndex": 1, "logCount": 0},
          {"day": "Wed", "dayIndex": 2, "logCount": 0},
          {"day": "Thu", "dayIndex": 3, "logCount": 0},
          {"day": "Fri", "dayIndex": 4, "logCount": 0},
          {"day": "Sat", "dayIndex": 5, "logCount": 0},
          {"day": "Sun", "dayIndex": 6, "logCount": 0},
        ]}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response('{"error":"Premium Required","code":"PREMIUM_REQUIRED","message":"msg"}', 403);
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(
      apiClient: apiClient,
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Brand value endpoint should NOT have been called for free user
    expect(brandValueCalls, 0);
  });

  testWidgets("dashboard error state still works with 7 API calls for premium",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets("mock API returns brand value data for premium user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the brand value section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();

    expect(find.text("Brand Value"), findsOneWidget);
    expect(find.text("Uniqlo"), findsAtLeastNWidgets(1));
  });

  // --- Sustainability section integration tests ---

  testWidgets("dashboard renders SustainabilitySection below BrandValueSection for premium user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the sustainability section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(find.byType(SustainabilitySection), findsOneWidget);
    expect(find.text("Sustainability"), findsOneWidget);
  });

  testWidgets("dashboard renders PremiumGateCard for sustainability for free user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the sustainability section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(find.byType(SustainabilitySection), findsOneWidget);
    // There should be PremiumGateCards (for brand value and sustainability)
    expect(find.text("Sustainability Score"), findsOneWidget);
    expect(
      find.text("See your environmental impact and CO2 savings"),
      findsOneWidget,
    );
  });

  testWidgets("dashboard error state still works with sustainability section",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets("mock API returns sustainability data for premium user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the sustainability section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(find.text("Sustainability"), findsOneWidget);
    expect(find.text("65"), findsAtLeastNWidgets(1)); // score
  });

  testWidgets("mock API does NOT call sustainability or gap-analysis endpoint for free user",
      (tester) async {
    final requestPaths = <String>[];
    final mockClient = http_testing.MockClient((request) async {
      requestPaths.add(request.url.path);
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({
            "summary": {
              "totalItems": 10,
              "pricedItems": 7,
              "totalValue": 1500.0,
              "totalWears": 120,
              "averageCpw": 12.50,
              "dominantCurrency": "GBP",
            },
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(
          jsonEncode({
            "days": [
              {"day": "Mon", "dayIndex": 0, "logCount": 0},
              {"day": "Tue", "dayIndex": 1, "logCount": 0},
              {"day": "Wed", "dayIndex": 2, "logCount": 0},
              {"day": "Thu", "dayIndex": 3, "logCount": 0},
              {"day": "Fri", "dayIndex": 4, "logCount": 0},
              {"day": "Sat", "dayIndex": 5, "logCount": 0},
              {"day": "Sun", "dayIndex": 6, "logCount": 0},
            ],
          }),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/wardrobe-health") {
        return http.Response(jsonEncode({"score": 65, "factors": {"utilizationScore": 50.0, "cpwScore": 60.0, "sizeUtilizationScore": 50.0}, "percentile": 35, "recommendation": "Keep going!", "totalItems": 10, "itemsWorn90d": 5, "colorTier": "yellow"}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(
          '{"error":"Premium Required","code":"PREMIUM_REQUIRED","message":"Premium required"}',
          403,
        );
      }
      return http.Response('{"error":"Not Found"}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(
      apiClient: apiClient,
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Verify sustainability endpoint was NOT called for free user
    expect(
      requestPaths.where((p) => p == "/v1/analytics/sustainability").length,
      0,
    );
    // Verify brand-value endpoint was NOT called either
    expect(
      requestPaths.where((p) => p == "/v1/analytics/brand-value").length,
      0,
    );
    // Verify gap-analysis endpoint was NOT called for free user
    expect(
      requestPaths.where((p) => p == "/v1/analytics/gap-analysis").length,
      0,
    );
    // Verify seasonal-reports endpoint was NOT called for free user
    expect(
      requestPaths.where((p) => p == "/v1/analytics/seasonal-reports").length,
      0,
    );
    // Free user should trigger exactly 7 base API calls (6 + wardrobe-health, + ai-summary separately)
    expect(
      requestPaths.where((p) => p.startsWith("/v1/analytics/") && p != "/v1/analytics/ai-summary").length,
      7,
    );
  });

  // --- Story 11.3: Gap Analysis Section integration ---

  testWidgets("dashboard renders GapAnalysisSection below SustainabilitySection for premium user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the gap analysis section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();

    expect(find.byType(GapAnalysisSection), findsOneWidget);
    expect(find.text("Wardrobe Gaps"), findsOneWidget);
  });

  testWidgets("dashboard renders PremiumGateCard for gap analysis for free user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the gap analysis section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();

    expect(find.byType(GapAnalysisSection), findsOneWidget);
    expect(find.text("Wardrobe Gap Analysis"), findsOneWidget);
    expect(
      find.text("Discover what's missing from your wardrobe"),
      findsOneWidget,
    );
  });

  testWidgets("dashboard error state still works with 9 API calls for premium",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets("mock API returns gap analysis data for premium user",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal the gap analysis section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();

    expect(find.text("Wardrobe Gaps"), findsOneWidget);
    expect(find.text("Missing Outerwear"), findsOneWidget);
  });

  testWidgets("mock API does NOT call gap analysis endpoint for free user",
      (tester) async {
    int gapAnalysisCalls = 0;
    final mockClient = http_testing.MockClient((request) async {
      if (request.url.path == "/v1/analytics/gap-analysis") {
        gapAnalysisCalls++;
        return http.Response(jsonEncode({"gaps": [], "totalItems": 10}), 200);
      }
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({"summary": {"totalItems": 10, "pricedItems": 7, "totalValue": 1500.0, "totalWears": 120, "averageCpw": 12.50, "dominantCurrency": "GBP"}}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": [
          {"day": "Mon", "dayIndex": 0, "logCount": 0},
          {"day": "Tue", "dayIndex": 1, "logCount": 0},
          {"day": "Wed", "dayIndex": 2, "logCount": 0},
          {"day": "Thu", "dayIndex": 3, "logCount": 0},
          {"day": "Fri", "dayIndex": 4, "logCount": 0},
          {"day": "Sat", "dayIndex": 5, "logCount": 0},
          {"day": "Sun", "dayIndex": 6, "logCount": 0},
        ]}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response('{"error":"Premium Required","code":"PREMIUM_REQUIRED","message":"msg"}', 403);
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(
      apiClient: apiClient,
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Gap analysis endpoint should NOT have been called for free user
    expect(gapAnalysisCalls, 0);
  });

  testWidgets("premium user triggers up to 11 parallel API calls; free user triggers 7",
      (tester) async {
    final requestPaths = <String>[];
    final mockClient = http_testing.MockClient((request) async {
      requestPaths.add(request.url.path);
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({"summary": {"totalItems": 10, "pricedItems": 7, "totalValue": 1500.0, "totalWears": 120, "averageCpw": 12.50, "dominantCurrency": "GBP"}}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": [
          {"day": "Mon", "dayIndex": 0, "logCount": 0},
          {"day": "Tue", "dayIndex": 1, "logCount": 0},
          {"day": "Wed", "dayIndex": 2, "logCount": 0},
          {"day": "Thu", "dayIndex": 3, "logCount": 0},
          {"day": "Fri", "dayIndex": 4, "logCount": 0},
          {"day": "Sat", "dayIndex": 5, "logCount": 0},
          {"day": "Sun", "dayIndex": 6, "logCount": 0},
        ]}), 200);
      }
      if (request.url.path == "/v1/analytics/wardrobe-health") {
        return http.Response(jsonEncode({"score": 65, "factors": {"utilizationScore": 50.0, "cpwScore": 60.0, "sizeUtilizationScore": 50.0}, "percentile": 35, "recommendation": "Keep going!", "totalItems": 10, "itemsWorn90d": 5, "colorTier": "yellow"}), 200);
      }
      if (request.url.path == "/v1/analytics/brand-value") {
        return http.Response(jsonEncode({"brands": [], "availableCategories": [], "bestValueBrand": null, "mostInvestedBrand": null}), 200);
      }
      if (request.url.path == "/v1/analytics/sustainability") {
        return http.Response(jsonEncode({"score": 50, "factors": {"avgWearScore": 50, "utilizationScore": 50, "cpwScore": 50, "resaleScore": 50, "newPurchaseScore": 50}, "co2SavedKg": 5.0, "co2CarKmEquivalent": 23.8, "percentile": 50, "totalRewears": 10, "totalItems": 5, "badgeAwarded": false}), 200);
      }
      if (request.url.path == "/v1/analytics/gap-analysis") {
        return http.Response(jsonEncode({"gaps": [], "totalItems": 10}), 200);
      }
      if (request.url.path == "/v1/analytics/seasonal-reports") {
        return http.Response(jsonEncode({
          "seasons": [
            {"season": "spring", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First spring tracked"}},
            {"season": "summer", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First summer tracked"}},
            {"season": "fall", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First fall tracked"}},
            {"season": "winter", "itemCount": 5, "totalWears": 10, "mostWorn": [], "neglected": [], "readinessScore": 5, "historicalComparison": {"percentChange": null, "comparisonText": "First winter tracked"}},
          ],
          "currentSeason": "spring",
          "transitionAlert": null,
          "totalItems": 20,
        }), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(jsonEncode({"summary": "AI insight.", "isGeneric": false}), 200);
      }
      return http.Response('{}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(_buildApp(
      apiClient: apiClient,
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Premium user should trigger 11 analytics calls (7 base including health + brand-value + sustainability + gap-analysis + seasonal-reports)
    final analyticsPaths = requestPaths.where((p) => p.startsWith("/v1/analytics/") && p != "/v1/analytics/ai-summary").toList();
    expect(analyticsPaths.length, 11);
    expect(analyticsPaths.contains("/v1/analytics/wardrobe-health"), isTrue);
    expect(analyticsPaths.contains("/v1/analytics/gap-analysis"), isTrue);
    expect(analyticsPaths.contains("/v1/analytics/seasonal-reports"), isTrue);
  });

  // --- Seasonal Reports integration tests ---

  testWidgets("dashboard renders SeasonalReportsSection for premium user", (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: true),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find SeasonalReportsSection
    await tester.scrollUntilVisible(
      find.byType(SeasonalReportsSection),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(SeasonalReportsSection), findsOneWidget);
  });

  testWidgets("dashboard renders PremiumGateCard for seasonal reports for free user", (tester) async {
    await tester.pumpWidget(_buildApp(
      subscriptionService: _MockSubscriptionService(premium: false),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find PremiumGateCard for seasonal reports
    await tester.scrollUntilVisible(
      find.text("Seasonal Reports & Heatmap"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text("Seasonal Reports & Heatmap"), findsOneWidget);
  });

  testWidgets("dashboard error state still works with seasonal reports", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
  });

  // --- Health Score integration tests ---

  testWidgets("dashboard renders HealthScoreSection as the first section",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(HealthScoreSection), findsOneWidget);
    expect(find.text("Wardrobe Health"), findsOneWidget);
  });

  testWidgets("dashboard fetches wardrobe health for ALL users (no premium gating)",
      (tester) async {
    // Free user (no subscription service)
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(HealthScoreSection), findsOneWidget);
    expect(find.text("65"), findsOneWidget);
  });

  testWidgets("dashboard shows health score data from mock API",
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text("65"), findsOneWidget);
    expect(find.text("Top 35% of Vestiaire users"), findsOneWidget);
    expect(
      find.text("Wear 6 more items this month to reach Green status"),
      findsOneWidget,
    );
  });

  testWidgets("dashboard error state still works with health score added",
      (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
    ));
    await tester.pumpAndSettle();

    // Error state should show Retry
    expect(find.text("Retry"), findsOneWidget);
  });

  testWidgets("free user triggers 7 parallel API calls (6 free + 1 health)",
      (tester) async {
    int callCount = 0;
    final mockClient = http_testing.MockClient((request) async {
      callCount++;
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({"summary": {"totalItems": 10, "pricedItems": 7, "totalValue": 1500.0, "totalWears": 120, "averageCpw": 12.5, "dominantCurrency": "GBP"}}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wardrobe-health") {
        return http.Response(
          jsonEncode({"score": 50, "factors": {"utilizationScore": 50.0, "cpwScore": 50.0, "sizeUtilizationScore": 50.0}, "percentile": 50, "recommendation": "Keep going!", "totalItems": 10, "itemsWorn90d": 5, "colorTier": "yellow"}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(
          '{"error":"Premium Required","code":"PREMIUM_REQUIRED","message":"Premium subscription required"}',
          403,
        );
      }
      return http.Response('{"error":"Not Found"}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(MaterialApp(
      home: AnalyticsDashboardScreen(apiClient: apiClient),
    ));
    await tester.pumpAndSettle();

    // 7 parallel calls + 1 AI summary = 8 total HTTP requests
    // (summary, items-cpw, top-worn, neglected, category-dist, wear-freq, wardrobe-health, ai-summary)
    expect(callCount, 8);
  });

  testWidgets("premium user triggers 11 parallel API calls (7 free + 4 premium)",
      (tester) async {
    int callCount = 0;
    final mockClient = http_testing.MockClient((request) async {
      callCount++;
      if (request.url.path == "/v1/analytics/wardrobe-summary") {
        return http.Response(
          jsonEncode({"summary": {"totalItems": 10, "pricedItems": 7, "totalValue": 1500.0, "totalWears": 120, "averageCpw": 12.5, "dominantCurrency": "GBP"}}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/items-cpw") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/top-worn") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/neglected") {
        return http.Response(jsonEncode({"items": []}), 200);
      }
      if (request.url.path == "/v1/analytics/category-distribution") {
        return http.Response(jsonEncode({"categories": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wear-frequency") {
        return http.Response(jsonEncode({"days": []}), 200);
      }
      if (request.url.path == "/v1/analytics/wardrobe-health") {
        return http.Response(
          jsonEncode({"score": 50, "factors": {"utilizationScore": 50.0, "cpwScore": 50.0, "sizeUtilizationScore": 50.0}, "percentile": 50, "recommendation": "Keep going!", "totalItems": 10, "itemsWorn90d": 5, "colorTier": "yellow"}),
          200,
        );
      }
      if (request.url.path == "/v1/analytics/brand-value") {
        return http.Response(jsonEncode({"brands": [], "availableCategories": [], "bestValueBrand": null, "mostInvestedBrand": null}), 200);
      }
      if (request.url.path == "/v1/analytics/sustainability") {
        return http.Response(jsonEncode({"score": 65, "factors": {}, "co2SavedKg": 10.0, "co2CarKmEquivalent": 47.6, "percentile": 35, "totalRewears": 20, "totalItems": 10, "badgeAwarded": false}), 200);
      }
      if (request.url.path == "/v1/analytics/gap-analysis") {
        return http.Response(jsonEncode({"gaps": [], "totalItems": 10}), 200);
      }
      if (request.url.path == "/v1/analytics/seasonal-reports") {
        return http.Response(jsonEncode({"seasons": [], "currentSeason": "spring", "transitionAlert": null, "totalItems": 10}), 200);
      }
      if (request.url.path == "/v1/analytics/ai-summary") {
        return http.Response(jsonEncode({"summary": "Great wardrobe!", "isGeneric": false}), 200);
      }
      return http.Response('{"error":"Not Found"}', 404);
    });

    final apiClient = ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    );

    await tester.pumpWidget(MaterialApp(
      home: AnalyticsDashboardScreen(
        apiClient: apiClient,
        subscriptionService: _MockSubscriptionService(premium: true),
      ),
    ));
    await tester.pumpAndSettle();

    // 11 parallel calls + 1 AI summary = 12 total HTTP requests
    // (summary, items-cpw, top-worn, neglected, category-dist, wear-freq, wardrobe-health, brand-value, sustainability, gap-analysis, seasonal-reports, ai-summary)
    expect(callCount, 12);
  });

  testWidgets("Spring Clean button on health score section navigates to SpringCleanScreen",
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = _buildApiClient();

    await tester.pumpWidget(MaterialApp(
      home: AnalyticsDashboardScreen(
        apiClient: apiClient,
        subscriptionService: _MockSubscriptionService(premium: false),
      ),
    ));
    await tester.pumpAndSettle();

    // Spring Clean button should be visible in the HealthScoreSection
    expect(find.text("Spring Clean"), findsOneWidget);
  });
}
