class AppConfig {
  static const defaultEnvironment = String.fromEnvironment(
    "VESTIAIRE_APP_ENV",
    defaultValue: "development"
  );
  static const defaultApiBaseUrl = String.fromEnvironment(
    "VESTIAIRE_API_BASE_URL",
    defaultValue: "http://127.0.0.1:8080"
  );
  static const defaultRevenueCatApiKey = String.fromEnvironment(
    "VESTIAIRE_REVENUECAT_API_KEY",
    defaultValue: "test_dFNiKupYjeDJiXspEUhcwDwygyg"
  );

  final String environment;
  final String apiBaseUrl;
  final String revenueCatApiKey;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.revenueCatApiKey,
  });

  const AppConfig.fromEnvironment()
    : this(
        environment: defaultEnvironment,
        apiBaseUrl: defaultApiBaseUrl,
        revenueCatApiKey: defaultRevenueCatApiKey,
      );
}
