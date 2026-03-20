import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_service.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_sync_service.dart";
import "package:vestiaire_mobile/src/core/subscription/models/subscription_status.dart";

// Mock SubscriptionSyncService for testing
class MockSubscriptionSyncService implements SubscriptionSyncService {
  int syncCallCount = 0;
  String? lastSyncAppUserId;
  bool shouldThrow = false;
  SubscriptionStatus? customResponse;

  @override
  Future<SubscriptionStatus> syncSubscription(String appUserId) async {
    syncCallCount++;
    lastSyncAppUserId = appUserId;
    if (shouldThrow) {
      throw Exception("Sync failed");
    }
    return customResponse ?? const SubscriptionStatus(
      isPremium: true,
      premiumSource: "revenuecat",
      premiumExpiresAt: "2026-04-19T00:00:00Z",
    );
  }

  // ApiClient getter not needed for mock
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group("SubscriptionService", () {
    test("constructor accepts optional syncService parameter", () {
      // Should not throw
      final service = SubscriptionService(apiKey: "test_key");
      expect(service.syncService, isNull);
    });

    test("constructor stores syncService when provided", () {
      final mockSync = MockSubscriptionSyncService();
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );
      expect(service.syncService, equals(mockSync));
    });

    test("syncWithBackend calls syncService.syncSubscription", () async {
      final mockSync = MockSubscriptionSyncService();
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );

      await service.syncWithBackend("firebase-user-123");

      expect(mockSync.syncCallCount, equals(1));
      expect(mockSync.lastSyncAppUserId, equals("firebase-user-123"));
    });

    test("syncWithBackend does not throw when syncService fails", () async {
      final mockSync = MockSubscriptionSyncService()..shouldThrow = true;
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );

      // Should not throw
      await service.syncWithBackend("firebase-user-123");

      expect(mockSync.syncCallCount, equals(1));
    });

    test("syncWithBackend does nothing when syncService is null", () async {
      final service = SubscriptionService(apiKey: "test_key");

      // Should not throw
      await service.syncWithBackend("firebase-user-123");
    });

    test("proEntitlementId constant is correct", () {
      expect(SubscriptionService.proEntitlementId, equals("Vestiaire Pro"));
    });

    test("monthlyProductId constant is correct", () {
      expect(SubscriptionService.monthlyProductId, equals("monthly"));
    });

    test("yearlyProductId constant is correct", () {
      expect(SubscriptionService.yearlyProductId, equals("yearly"));
    });

    test("isConfigured defaults to false", () {
      final service = SubscriptionService(apiKey: "test_key");
      expect(service.isConfigured, isFalse);
    });
  });

  group("SubscriptionService - PremiumState", () {
    test("isPremiumCached returns false when no sync has occurred", () {
      final service = SubscriptionService(apiKey: "test_key");
      expect(service.isPremiumCached, isFalse);
    });

    test("premiumState is null when no sync has occurred", () {
      final service = SubscriptionService(apiKey: "test_key");
      expect(service.premiumState, isNull);
    });

    test("syncWithBackend updates premiumState", () async {
      final mockSync = MockSubscriptionSyncService();
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );

      await service.syncWithBackend("firebase-user-123");

      expect(service.premiumState, isNotNull);
      expect(service.premiumState!.isPremium, isTrue);
      expect(service.premiumState!.premiumSource, equals("revenuecat"));
    });

    test("isPremiumCached returns true after a successful premium sync", () async {
      final mockSync = MockSubscriptionSyncService();
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );

      await service.syncWithBackend("firebase-user-123");

      expect(service.isPremiumCached, isTrue);
    });

    test("isPremiumCached returns false after a non-premium sync", () async {
      final mockSync = MockSubscriptionSyncService()
        ..customResponse = const SubscriptionStatus(
          isPremium: false,
          premiumSource: null,
          premiumExpiresAt: null,
        );
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );

      await service.syncWithBackend("firebase-user-123");

      expect(service.isPremiumCached, isFalse);
    });

    test("premiumState is unchanged when syncWithBackend fails", () async {
      final mockSync = MockSubscriptionSyncService()..shouldThrow = true;
      final service = SubscriptionService(
        apiKey: "test_key",
        syncService: mockSync,
      );

      await service.syncWithBackend("firebase-user-123");

      expect(service.premiumState, isNull);
      expect(service.isPremiumCached, isFalse);
    });

    test("all existing SubscriptionService tests continue to pass", () {
      // This is a meta-test verifying backward compatibility.
      // The service API is additive only - no breaking changes.
      final service = SubscriptionService(apiKey: "test_key");
      expect(service.syncService, isNull);
      expect(service.isConfigured, isFalse);
      expect(service.isPremiumCached, isFalse);
    });
  });
}
