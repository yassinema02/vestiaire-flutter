import "package:flutter/foundation.dart";

import "../networking/api_client.dart";
import "models/subscription_status.dart";

/// Service that syncs subscription status with the backend API.
///
/// After a purchase completes or on app launch, this service pushes
/// the entitlement state to the server so that `profiles.is_premium`
/// stays in sync with RevenueCat.
class SubscriptionSyncService {
  SubscriptionSyncService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Sync the current subscription status with the backend.
  ///
  /// Calls POST /v1/subscription/sync with the user's Firebase UID
  /// (which is also their RevenueCat app_user_id).
  ///
  /// Returns the server's view of subscription status.
  Future<SubscriptionStatus> syncSubscription(String appUserId) async {
    try {
      final response = await _apiClient.authenticatedPost(
        "/v1/subscription/sync",
        body: {"appUserId": appUserId},
      );
      return SubscriptionStatus.fromJson(response);
    } catch (e) {
      debugPrint("Subscription sync error: $e");
      rethrow;
    }
  }
}
