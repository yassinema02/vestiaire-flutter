import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:purchases_flutter/purchases_flutter.dart";
import "package:purchases_ui_flutter/purchases_ui_flutter.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_service.dart";
import "package:vestiaire_mobile/src/features/subscription/screens/subscription_screen.dart";

/// A mock SubscriptionService that does not call RevenueCat SDK.
class _MockSubscriptionService extends SubscriptionService {
  _MockSubscriptionService() : super(apiKey: "mock_key");

  bool shouldThrowOnGetCustomerInfo = false;
  bool presentPaywallCalled = false;
  bool presentCustomerCenterCalled = false;
  bool restorePurchasesCalled = false;

  @override
  Future<void> configure({String? appUserId}) async {}

  @override
  Future<CustomerInfo> getCustomerInfo() async {
    if (shouldThrowOnGetCustomerInfo) {
      throw Exception("Cannot load customer info");
    }
    throw Exception("No customer info configured in mock");
  }

  @override
  Future<bool> isProUser() async => false;

  @override
  Future<CustomerInfo> restorePurchases() async {
    restorePurchasesCalled = true;
    return getCustomerInfo();
  }

  @override
  Future<PaywallResult> presentPaywall() async {
    presentPaywallCalled = true;
    return PaywallResult.notPresented;
  }

  @override
  Future<PaywallResult> presentPaywallIfNeeded() async {
    presentPaywallCalled = true;
    return PaywallResult.notPresented;
  }

  @override
  Future<void> presentCustomerCenter() async {
    presentCustomerCenterCalled = true;
  }

  @override
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {}

  @override
  void removeCustomerInfoUpdateListener(
      void Function(CustomerInfo) listener) {}

  @override
  Future<void> syncWithBackend(String firebaseUid) async {}
}

void main() {
  group("SubscriptionScreen", () {
    testWidgets("Shows loading indicator initially", (tester) async {
      final mockService = _MockSubscriptionService();

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            subscriptionService: mockService,
          ),
        ),
      );

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("Shows error state when loading fails", (tester) async {
      final mockService = _MockSubscriptionService()
        ..shouldThrowOnGetCustomerInfo = true;

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            subscriptionService: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
          find.text("Could not load subscription status."), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("Shows 'Vestiaire Pro' title in app bar", (tester) async {
      final mockService = _MockSubscriptionService()
        ..shouldThrowOnGetCustomerInfo = true;

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            subscriptionService: mockService,
          ),
        ),
      );

      expect(find.text("Vestiaire Pro"), findsOneWidget);
    });

    testWidgets("Renders without crashing with all optional params null",
        (tester) async {
      final mockService = _MockSubscriptionService()
        ..shouldThrowOnGetCustomerInfo = true;

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionScreen(
            subscriptionService: mockService,
            syncService: null,
            firebaseUid: null,
            onSubscriptionChanged: null,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
    });
  });
}
