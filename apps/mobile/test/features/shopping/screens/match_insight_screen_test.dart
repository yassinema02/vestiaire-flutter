import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/shopping/models/match_insight_result.dart";
import "package:vestiaire_mobile/src/features/shopping/models/shopping_scan.dart";
import "package:vestiaire_mobile/src/features/shopping/screens/match_insight_screen.dart";
import "package:vestiaire_mobile/src/features/shopping/services/shopping_scan_service.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "fake-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiClient _dummyApiClient() {
  final mockHttp = http_testing.MockClient((request) async {
    return http.Response("{}", 500);
  });
  return ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _FakeAuthService(),
    httpClient: mockHttp,
  );
}

class _MockShoppingScanService extends ShoppingScanService {
  _MockShoppingScanService({
    this.insightResult,
    this.shouldFailWithCode,
    this.shouldFailWithMessage,
    this.shouldFailGeneric = false,
    this.updateScanResult,
  }) : super(apiClient: _dummyApiClient());

  final MatchInsightResult? insightResult;
  final String? shouldFailWithCode;
  final String? shouldFailWithMessage;
  final bool shouldFailGeneric;
  final ShoppingScan? updateScanResult;
  int generateInsightsCallCount = 0;
  int updateScanCallCount = 0;
  Map<String, dynamic>? lastUpdateBody;

  @override
  Future<MatchInsightResult> generateInsights(String scanId) async {
    generateInsightsCallCount++;
    if (shouldFailWithCode != null) {
      int statusCode = 502;
      if (shouldFailWithCode == "WARDROBE_EMPTY") statusCode = 422;
      if (shouldFailWithCode == "NOT_SCORED") statusCode = 422;
      throw ApiException(
        statusCode: statusCode,
        code: shouldFailWithCode!,
        message: shouldFailWithMessage ?? "Error",
      );
    }
    if (shouldFailGeneric) {
      throw Exception("Network error");
    }
    return insightResult ?? _defaultInsightResult();
  }

  @override
  Future<ShoppingScan> updateScan(
      String scanId, Map<String, dynamic> updates) async {
    updateScanCallCount++;
    lastUpdateBody = updates;
    return updateScanResult ?? _makeTestScan(wishlisted: updates["wishlisted"] as bool? ?? false);
  }
}

class _HangingShoppingScanService extends ShoppingScanService {
  _HangingShoppingScanService() : super(apiClient: _dummyApiClient());

  final Completer<MatchInsightResult> _completer = Completer();

  @override
  Future<MatchInsightResult> generateInsights(String scanId) {
    return _completer.future;
  }
}

MatchInsightResult _defaultInsightResult() {
  return MatchInsightResult.fromJson({
    "scan": {
      "id": "scan-1",
      "scanType": "url",
      "productName": "Blue Shirt",
      "brand": "Zara",
      "compatibilityScore": 75,
      "createdAt": "2026-03-19T00:00:00.000Z",
    },
    "matches": [
      {
        "itemId": "item-1",
        "itemName": "Navy Blazer",
        "itemImageUrl": "https://example.com/blazer.jpg",
        "category": "outerwear",
        "matchReasons": ["Complementary navy pairs well"],
      },
      {
        "itemId": "item-2",
        "itemName": "Black Jeans",
        "itemImageUrl": "https://example.com/jeans.jpg",
        "category": "bottoms",
        "matchReasons": ["Good style match"],
      },
    ],
    "insights": [
      {
        "type": "style_feedback",
        "title": "Consistent Style",
        "body": "This item fits your casual wardrobe well.",
      },
      {
        "type": "gap_assessment",
        "title": "Fills a Gap",
        "body": "You don't have many items in this color.",
      },
      {
        "type": "value_proposition",
        "title": "Good Value",
        "body": "Versatile and affordable.",
      },
    ],
  });
}

MatchInsightResult _emptyMatchesResult() {
  return MatchInsightResult.fromJson({
    "scan": {
      "id": "scan-1",
      "scanType": "url",
      "productName": "Blue Shirt",
      "createdAt": "2026-03-19T00:00:00.000Z",
    },
    "matches": <dynamic>[],
    "insights": [
      {"type": "style_feedback", "title": "Style", "body": "Analysis."},
      {"type": "gap_assessment", "title": "Gap", "body": "Analysis."},
      {"type": "value_proposition", "title": "Value", "body": "Analysis."},
    ],
  });
}

ShoppingScan _makeTestScan({
  String? imageUrl = "https://example.com/shirt.jpg",
  int? compatibilityScore = 75,
  Map<String, dynamic>? insights,
  bool wishlisted = false,
}) {
  return ShoppingScan.fromJson({
    "id": "scan-1",
    "url": "https://www.zara.com/shirt",
    "scanType": "url",
    "productName": "Blue Cotton Shirt",
    "brand": "Zara",
    "price": 29.99,
    "currency": "GBP",
    "imageUrl": imageUrl,
    "category": "tops",
    "color": "blue",
    "compatibilityScore": compatibilityScore,
    "wishlisted": wishlisted,
    if (insights != null) "insights": insights,
    "createdAt": "2026-03-19T00:00:00.000Z",
  });
}

void main() {
  group("MatchInsightScreen", () {
    testWidgets("Renders loading state with product name and 'Finding matches' text",
        (tester) async {
      final service = _HangingShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pump();

      expect(find.text("Blue Cotton Shirt"), findsOneWidget);
      expect(find.text("Finding matches & generating insights..."),
          findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service._completer.complete(_defaultInsightResult());
      await tester.pumpAndSettle();
    });

    testWidgets("Displays match cards grouped by category on success",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Category headers
      expect(find.text("Outerwear"), findsOneWidget);
      expect(find.text("Bottoms"), findsOneWidget);
      expect(find.text("Top Wardrobe Matches (2)"), findsOneWidget);
    });

    testWidgets("Each match card shows item name and reason",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Navy Blazer"), findsOneWidget);
      expect(find.text("Black Jeans"), findsOneWidget);
    });

    testWidgets("Shows 'No close matches found' when matches list is empty",
        (tester) async {
      final service =
          _MockShoppingScanService(insightResult: _emptyMatchesResult());
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("No close matches found in your wardrobe."),
          findsOneWidget);
    });

    testWidgets("Displays 3 insight cards with correct icons, titles, and bodies",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("AI Insights"), findsOneWidget);
      expect(find.text("Consistent Style"), findsOneWidget);
      expect(find.text("Fills a Gap"), findsOneWidget);
      expect(find.text("Good Value"), findsOneWidget);
      expect(find.byIcon(Icons.palette), findsOneWidget);
      expect(find.byIcon(Icons.space_dashboard), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets("Wishlist button shows 'Save to Wishlist' when not wishlisted",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan(wishlisted: false);

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Scroll to wishlist button
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Save to Wishlist"),
        200,
        scrollable: scrollable,
      );

      expect(find.text("Save to Wishlist"), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets(
        "Tapping wishlist button calls updateScan with wishlisted: true",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan(wishlisted: false);

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Save to Wishlist"),
        200,
        scrollable: scrollable,
      );

      await tester.tap(find.text("Save to Wishlist"));
      await tester.pumpAndSettle();

      expect(service.updateScanCallCount, 1);
      expect(service.lastUpdateBody?["wishlisted"], true);
    });

    testWidgets("Wishlist button toggles to 'Saved to Wishlist' after save",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan(wishlisted: false);

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Save to Wishlist"),
        200,
        scrollable: scrollable,
      );

      await tester.tap(find.text("Save to Wishlist"));
      await tester.pumpAndSettle();

      expect(find.text("Saved to Wishlist"), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets("Shows empty wardrobe state on 422 WARDROBE_EMPTY error",
        (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "WARDROBE_EMPTY",
        shouldFailWithMessage:
            "Add items to your wardrobe first to see matches and insights.",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Your wardrobe is empty"), findsOneWidget);
      expect(find.byIcon(Icons.checkroom), findsOneWidget);
      expect(
        find.text(
          "Add items to your wardrobe first to see matches and insights.",
        ),
        findsOneWidget,
      );
    });

    testWidgets("'Go to Wardrobe' button is present in empty state",
        (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "WARDROBE_EMPTY",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Go to Wardrobe"), findsOneWidget);
    });

    testWidgets("Shows retry button on insight generation failure",
        (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "INSIGHT_FAILED",
        shouldFailWithMessage:
            "Unable to generate insights. Please try again.",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Couldn't generate insights"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("Retry button re-triggers generateInsights call",
        (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "INSIGHT_FAILED",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(service.generateInsightsCallCount, 1);

      await tester.tap(find.text("Retry"));
      await tester.pumpAndSettle();

      expect(service.generateInsightsCallCount, 2);
    });

    testWidgets("Loads cached insights from scan.insights without API call",
        (tester) async {
      final cachedInsights = {
        "matches": [
          {
            "itemId": "item-1",
            "itemName": "Cached Item",
            "category": "tops",
            "matchReasons": ["Cached reason"],
          }
        ],
        "insights": [
          {
            "type": "style_feedback",
            "title": "Cached Style",
            "body": "Cached analysis.",
          },
          {
            "type": "gap_assessment",
            "title": "Cached Gap",
            "body": "Cached analysis.",
          },
          {
            "type": "value_proposition",
            "title": "Cached Value",
            "body": "Cached analysis.",
          },
        ],
      };

      final service = _MockShoppingScanService();
      final scan = _makeTestScan(insights: cachedInsights);

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Should display cached data
      expect(find.text("Cached Item"), findsOneWidget);
      expect(find.text("Cached Style"), findsOneWidget);
      // generateInsights should NOT have been called
      expect(service.generateInsightsCallCount, 0);
    });

    testWidgets(
        "Semantics labels present on match cards, insight cards, wishlist button",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: MatchInsightScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Product header semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Product:"),
        ),
        findsOneWidget,
      );

      // Match card semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Match:"),
        ),
        findsAtLeast(1),
      );

      // Insight card semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Insight:"),
        ),
        findsAtLeast(1),
      );

      // Scroll to wishlist button
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Save to Wishlist"),
        200,
        scrollable: scrollable,
      );

      // Wishlist button semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Wishlist button"),
        ),
        findsOneWidget,
      );
    });
  });
}
