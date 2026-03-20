import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/shopping/models/compatibility_score_result.dart";
import "package:vestiaire_mobile/src/features/shopping/models/shopping_scan.dart";
import "package:vestiaire_mobile/src/features/shopping/screens/compatibility_score_screen.dart";
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
    this.scoreResult,
    this.shouldFailWithCode,
    this.shouldFailWithMessage,
    this.shouldFailGeneric = false,
  }) : super(apiClient: _dummyApiClient());

  final CompatibilityScoreResult? scoreResult;
  final String? shouldFailWithCode;
  final String? shouldFailWithMessage;
  final bool shouldFailGeneric;
  int scoreCallCount = 0;

  @override
  Future<CompatibilityScoreResult> scoreCompatibility(String scanId) async {
    scoreCallCount++;
    if (shouldFailWithCode != null) {
      throw ApiException(
        statusCode: shouldFailWithCode == "WARDROBE_EMPTY" ? 422 : 502,
        code: shouldFailWithCode!,
        message: shouldFailWithMessage ?? "Error",
      );
    }
    if (shouldFailGeneric) {
      throw Exception("Network error");
    }
    return scoreResult ?? _defaultScoreResult();
  }
}

CompatibilityScoreResult _defaultScoreResult() {
  return CompatibilityScoreResult.fromJson({
    "scan": {
      "id": "scan-1",
      "scanType": "url",
      "productName": "Blue Shirt",
      "brand": "Zara",
      "price": 29.99,
      "currency": "GBP",
      "category": "tops",
      "color": "blue",
      "compatibilityScore": 75,
      "createdAt": "2026-03-19T00:00:00.000Z",
    },
    "score": {
      "total": 75,
      "breakdown": {
        "colorHarmony": 80,
        "styleConsistency": 70,
        "gapFilling": 75,
        "versatility": 65,
        "formalityMatch": 80,
      },
      "tier": "great_choice",
      "tierLabel": "Great Choice",
      "tierColor": "#3B82F6",
      "tierIcon": "thumb_up",
      "reasoning": "Good match with your wardrobe.",
    },
    "status": "scored",
  });
}

ShoppingScan _makeTestScan({String? imageUrl}) {
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
    "createdAt": "2026-03-19T00:00:00.000Z",
  });
}

/// A mock service that never completes, allowing us to test the loading state.
class _HangingShoppingScanService extends ShoppingScanService {
  _HangingShoppingScanService() : super(apiClient: _dummyApiClient());

  final Completer<CompatibilityScoreResult> _completer = Completer();

  @override
  Future<CompatibilityScoreResult> scoreCompatibility(String scanId) {
    return _completer.future;
  }
}

void main() {
  group("CompatibilityScoreScreen", () {
    testWidgets("Renders loading state with product name and calculating text",
        (tester) async {
      final service = _HangingShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      // Pump one frame to trigger build
      await tester.pump();

      // Should show loading state immediately
      expect(find.text("Blue Cotton Shirt"), findsOneWidget);
      expect(find.text("Calculating compatibility..."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer issues
      service._completer.complete(_defaultScoreResult());
      await tester.pumpAndSettle();
    });

    testWidgets("Displays score gauge with correct score on success",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Score should be visible (75 from default result - appears in gauge and breakdown)
      expect(find.text("75"), findsAtLeast(1));
    });

    testWidgets("Displays correct tier label, color, and icon",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Great Choice"), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    });

    testWidgets("Displays all 5 breakdown bars with correct labels and scores",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Score Breakdown"), findsOneWidget);
      expect(find.text("Color Harmony"), findsOneWidget);
      expect(find.text("Style Consistency"), findsOneWidget);
      expect(find.text("Gap Filling"), findsOneWidget);
      expect(find.text("Versatility"), findsOneWidget);
      expect(find.text("Formality Match"), findsOneWidget);

      // Score values
      expect(find.text("80"), findsAtLeast(1)); // colorHarmony and formalityMatch
      expect(find.text("70"), findsOneWidget);
      expect(find.text("65"), findsOneWidget);
    });

    testWidgets("Displays reasoning text", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Good match with your wardrobe."), findsOneWidget);
    });

    testWidgets("View Matches & Insights button is enabled",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Scroll to find the button
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("View Matches & Insights"),
        200,
        scrollable: scrollable,
      );

      expect(
        find.text("View Matches & Insights"),
        findsOneWidget,
      );

      // Button should be enabled (onPressed is not null)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "View Matches & Insights"),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets("Tapping 'View Matches & Insights' navigates to MatchInsightScreen",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Scroll to find the button
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("View Matches & Insights"),
        200,
        scrollable: scrollable,
      );

      await tester.tap(find.text("View Matches & Insights"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify navigation occurred (MatchInsightScreen title)
      expect(find.text("Matches & Insights"), findsOneWidget);
    });

    testWidgets("Shows empty wardrobe state on 422 WARDROBE_EMPTY error",
        (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "WARDROBE_EMPTY",
        shouldFailWithMessage: "Add items to your wardrobe first.",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
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
          "Add some items to your wardrobe first so we can score how well this purchase matches.",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Go to Wardrobe button is present in empty state",
        (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "WARDROBE_EMPTY",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Go to Wardrobe"), findsOneWidget);
    });

    testWidgets("Shows retry button on scoring failure", (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "SCORING_FAILED",
        shouldFailWithMessage: "Unable to calculate compatibility score.",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Scoring failed"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("Retry button re-triggers scoring call", (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "SCORING_FAILED",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(service.scoreCallCount, 1);

      // Tap retry
      await tester.tap(find.text("Retry"));
      await tester.pumpAndSettle();

      expect(service.scoreCallCount, 2);
    });

    testWidgets("Semantics labels present on score gauge, tier, breakdown bars, buttons",
        (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Score gauge semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Compatibility score:"),
        ),
        findsOneWidget,
      );

      // Tier label semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Tier:"),
        ),
        findsOneWidget,
      );

      // Breakdown bar semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Color Harmony:"),
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains("Style Consistency:"),
        ),
        findsOneWidget,
      );

      // Scroll to find the View Matches button
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("View Matches & Insights"),
        200,
        scrollable: scrollable,
      );

      // View Matches button semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "View Matches and Insights button",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Semantics labels on retry button", (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "SCORING_FAILED",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == "Retry button",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Semantics labels on Go to Wardrobe button", (tester) async {
      final service = _MockShoppingScanService(
        shouldFailWithCode: "WARDROBE_EMPTY",
      );
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: CompatibilityScoreScreen(
          scanId: "scan-1",
          scan: scan,
          shoppingScanService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Go to Wardrobe button",
        ),
        findsOneWidget,
      );
    });
  });
}
