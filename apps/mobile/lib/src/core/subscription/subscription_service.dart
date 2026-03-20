import "dart:async";

import "package:flutter/foundation.dart";
import "package:purchases_flutter/purchases_flutter.dart";
import "package:purchases_ui_flutter/purchases_ui_flutter.dart";

import "premium_state.dart";
import "subscription_sync_service.dart";

/// Service that wraps RevenueCat SDK for subscription management.
///
/// Handles initialization, entitlement checking, paywall presentation,
/// and Customer Center access.
class SubscriptionService {
  SubscriptionService({
    required String apiKey,
    this.syncService,
  }) : _apiKey = apiKey;

  final String _apiKey;

  /// Optional sync service for pushing entitlement state to the backend.
  /// Nullable for backward compatibility (tests can pass null).
  final SubscriptionSyncService? syncService;

  bool _isConfigured = false;

  /// Cached premium state, updated on sync and CustomerInfo changes.
  PremiumState? _premiumState;

  /// Whether the SDK has been configured.
  bool get isConfigured => _isConfigured;

  /// The cached premium state, or null if no sync has occurred.
  PremiumState? get premiumState => _premiumState;

  /// Quick synchronous check for premium status.
  /// Returns false if no sync has occurred yet.
  bool get isPremiumCached => _premiumState?.isPremium ?? false;

  /// The entitlement identifier for the Pro subscription.
  static const String proEntitlementId = "Vestiaire Pro";

  /// Product identifiers.
  static const String monthlyProductId = "monthly";
  static const String yearlyProductId = "yearly";

  /// Configures the RevenueCat SDK. Call once at app startup.
  Future<void> configure({String? appUserId}) async {
    if (_isConfigured) return;

    final configuration = PurchasesConfiguration(_apiKey)
      ..appUserID = appUserId;

    await Purchases.configure(configuration);
    _isConfigured = true;
  }

  /// Logs in a user to RevenueCat. Call after authentication.
  Future<CustomerInfo> logIn(String appUserId) async {
    final result = await Purchases.logIn(appUserId);
    // Sync with backend after login
    await syncWithBackend(appUserId);
    return result.customerInfo;
  }

  /// Logs out the current user from RevenueCat.
  Future<void> logOut() async {
    if (await Purchases.isAnonymous) return;
    await Purchases.logOut();
  }

  /// Returns the current customer info.
  Future<CustomerInfo> getCustomerInfo() async {
    return Purchases.getCustomerInfo();
  }

  /// Checks whether the user has an active "Vestiaire Pro" entitlement.
  Future<bool> isProUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint("Error checking pro entitlement: $e");
      return false;
    }
  }

  /// Fetches the current offerings.
  Future<Offerings> getOfferings() async {
    return Purchases.getOfferings();
  }

  /// Purchases a package.
  Future<PurchaseResult> purchasePackage(Package package) async {
    return Purchases.purchase(PurchaseParams.package(package));
  }

  /// Restores previous purchases.
  Future<CustomerInfo> restorePurchases() async {
    return Purchases.restorePurchases();
  }

  /// Presents the RevenueCat paywall modally.
  Future<PaywallResult> presentPaywall() async {
    return RevenueCatUI.presentPaywall();
  }

  /// Presents the paywall only if the user doesn't have the Pro entitlement.
  Future<PaywallResult> presentPaywallIfNeeded() async {
    return RevenueCatUI.presentPaywallIfNeeded(proEntitlementId);
  }

  /// Presents the Customer Center for subscription management.
  Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter();
  }

  /// Listens to customer info updates.
  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo) listener,
  ) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Removes a customer info update listener.
  void removeCustomerInfoUpdateListener(
    void Function(CustomerInfo) listener,
  ) {
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  /// Syncs subscription state with the backend API.
  ///
  /// Best-effort: failures are logged but do not propagate.
  /// Updates [_premiumState] from the server response.
  Future<void> syncWithBackend(String firebaseUid) async {
    if (syncService == null) return;

    try {
      final status = await syncService!.syncSubscription(firebaseUid);
      _premiumState = PremiumState(
        isPremium: status.isPremium,
        premiumSource: status.premiumSource,
        premiumExpiresAt: status.premiumExpiresAt != null
            ? DateTime.tryParse(status.premiumExpiresAt!)
            : null,
      );
    } catch (e) {
      debugPrint("syncWithBackend error: $e");
    }
  }

  /// Updates the cached premium state from a RevenueCat CustomerInfo.
  ///
  /// Called when CustomerInfo changes (e.g., after a purchase).
  void updatePremiumStateFromCustomerInfo(
    CustomerInfo customerInfo,
  ) {
    // Check if the "Vestiaire Pro" entitlement is active
    try {
      final isActive = customerInfo.entitlements.all[proEntitlementId]?.isActive == true;
      _premiumState = PremiumState(
        isPremium: isActive,
        premiumSource: isActive ? "revenuecat" : null,
      );
    } catch (e) {
      debugPrint("updatePremiumStateFromCustomerInfo error: $e");
    }
  }
}
