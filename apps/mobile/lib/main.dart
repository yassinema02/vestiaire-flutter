import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";

import "firebase_options.dart";

import "src/app.dart";
import "src/config/app_config.dart";
import "src/core/networking/api_client.dart";
import "src/core/auth/auth_service.dart";
import "src/core/subscription/subscription_service.dart";
import "src/core/subscription/subscription_sync_service.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const config = AppConfig.fromEnvironment();

  // Create auth service and API client for subscription sync.
  final authService = AuthService();
  final apiClient = ApiClient(
    baseUrl: config.apiBaseUrl,
    authService: authService,
  );

  // Create subscription sync service for server-side entitlement persistence.
  final subscriptionSyncService = SubscriptionSyncService(
    apiClient: apiClient,
  );

  // Configure RevenueCat SDK before running the app.
  final subscriptionService = SubscriptionService(
    apiKey: config.revenueCatApiKey,
    syncService: subscriptionSyncService,
  );
  await subscriptionService.configure();

  // If user is already authenticated, log in to RevenueCat and sync.
  final currentAuth = authService.currentAuthState;
  if (currentAuth.userId != null) {
    try {
      await subscriptionService.logIn(currentAuth.userId!);
    } catch (e) {
      // Graceful degradation -- do not block app startup.
      debugPrint("RevenueCat startup logIn error: $e");
    }
  }

  runApp(VestiaireApp(
    config: config,
    subscriptionService: subscriptionService,
    authService: authService,
    apiClient: apiClient,
  ));
}
