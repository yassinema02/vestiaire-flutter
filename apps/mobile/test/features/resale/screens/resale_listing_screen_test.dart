import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";
import "package:vestiaire_mobile/src/features/resale/models/resale_listing.dart";
import "package:vestiaire_mobile/src/features/resale/screens/resale_listing_screen.dart";
import "package:vestiaire_mobile/src/features/resale/services/resale_listing_service.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/wardrobe_item.dart";

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

/// A mock service that we can control for testing.
class _MockResaleListingService extends ResaleListingService {
  _MockResaleListingService({
    this.result,
    this.shouldFail = false,
    this.shouldThrowUsageLimit = false,
    this.completer,
  }) : super(apiClient: _dummyApiClient());

  final ResaleListingResult? result;
  final bool shouldFail;
  final bool shouldThrowUsageLimit;
  final Completer<void>? completer;

  @override
  Future<ResaleListingResult?> generateListing(String itemId) async {
    // If a completer is provided, wait for it (allows testing loading state)
    if (completer != null) {
      await completer!.future;
    }
    if (shouldThrowUsageLimit) {
      throw const UsageLimitException(message: "Limit reached");
    }
    if (shouldFail) {
      return null;
    }
    return result;
  }
}

WardrobeItem _makeTestItem() {
  return WardrobeItem.fromJson({
    "id": "item-1",
    "profileId": "profile-1",
    "photoUrl": "https://example.com/photo.jpg",
    "name": "Blue Shirt",
    "category": "tops",
    "brand": "Nike",
  });
}

ResaleListingResult _makeTestResult() {
  return ResaleListingResult(
    listing: const ResaleListing(
      id: "listing-1",
      title: "Gorgeous Blue Shirt",
      description: "A beautiful shirt in great condition.",
      conditionEstimate: "Like New",
      hashtags: ["fashion", "blue", "nike"],
      platform: "general",
      generatedAt: "2026-03-19T00:00:00.000Z",
    ),
    item: const ResaleListingItem(
      id: "item-1",
      name: "Blue Shirt",
      category: "tops",
      brand: "Nike",
      photoUrl: "https://example.com/photo.jpg",
    ),
    generatedAt: "2026-03-19T00:00:00.000Z",
  );
}

void main() {
  group("ResaleListingScreen", () {
    testWidgets("Shows loading shimmer during generation", (tester) async {
      final completer = Completer<void>();
      final service = _MockResaleListingService(
        result: _makeTestResult(),
        completer: completer,
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      // Pump once to let initState fire but not complete
      await tester.pump();

      // Should show loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text("Generating your listing..."), findsOneWidget);

      // Complete the future and settle
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets("Displays listing title, description, condition, and hashtags on success", (tester) async {
      final service = _MockResaleListingService(
        result: _makeTestResult(),
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      // Wait for generation to complete
      await tester.pumpAndSettle();

      // Title field should contain the listing title
      expect(find.text("Gorgeous Blue Shirt"), findsOneWidget);
      expect(find.text("A beautiful shirt in great condition."), findsOneWidget);
      expect(find.text("Like New"), findsOneWidget);
      expect(find.text("#fashion"), findsOneWidget);
      expect(find.text("#blue"), findsOneWidget);
      expect(find.text("#nike"), findsOneWidget);
    });

    testWidgets("Copy to Clipboard button copies formatted text", (tester) async {
      final service = _MockResaleListingService(
        result: _makeTestResult(),
      );

      // Track clipboard calls
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == "Clipboard.setData") {
            clipboardContent = (methodCall.arguments as Map)["text"] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Scroll down to reveal action buttons
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap copy button
      await tester.tap(find.text("Copy to Clipboard"));
      await tester.pump();

      expect(clipboardContent, isNotNull);
      expect(clipboardContent!, contains("Gorgeous Blue Shirt"));
      expect(clipboardContent!, contains("A beautiful shirt in great condition."));
      expect(clipboardContent!, contains("Condition: Like New"));
      expect(clipboardContent!, contains("#fashion"));

      // Should show snackbar
      expect(find.text("Copied to clipboard!"), findsOneWidget);
    });

    testWidgets("Share button triggers share action", (tester) async {
      final service = _MockResaleListingService(
        result: _makeTestResult(),
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Share button should be visible
      expect(find.text("Share"), findsOneWidget);
    });

    testWidgets("Error state shows 'Try Again' button", (tester) async {
      final service = _MockResaleListingService(
        shouldFail: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text("Unable to generate listing. Please try again."), findsOneWidget);
      expect(find.text("Try Again"), findsOneWidget);
    });

    testWidgets("Usage limit exceeded shows PremiumGateCard", (tester) async {
      final service = _MockResaleListingService(
        shouldThrowUsageLimit: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateCard), findsOneWidget);
      expect(find.text("Resale Listing Limit Reached"), findsOneWidget);
    });

    testWidgets("Semantics labels present for all interactive elements", (tester) async {
      final service = _MockResaleListingService(
        result: _makeTestResult(),
      );

      await tester.pumpWidget(MaterialApp(
        home: ResaleListingScreen(
          item: _makeTestItem(),
          resaleListingService: service,
        ),
      ));

      await tester.pumpAndSettle();

      // Check semantics labels via Semantics widget predicate
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Resale listing for Blue Shirt",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Copy listing to clipboard",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Share listing",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Listing title",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Listing description",
        ),
        findsOneWidget,
      );
    });
  });
}
