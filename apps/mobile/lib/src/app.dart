import "package:flutter/material.dart";

import "config/app_config.dart";
import "core/auth/auth_service.dart";
import "core/auth/auth_state.dart";
import "core/auth/session_manager.dart";
import "core/networking/api_client.dart";
import "core/subscription/subscription_service.dart";
import "features/auth/screens/email_sign_in_screen.dart";
import "features/auth/screens/email_sign_up_screen.dart";
import "features/auth/screens/forgot_password_screen.dart";
import "features/auth/screens/verification_pending_screen.dart";
import "features/auth/screens/welcome_screen.dart";
import "features/onboarding/onboarding_flow.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "core/location/location_service.dart";
import "core/notifications/notification_service.dart";
import "core/notifications/evening_reminder_preferences.dart";
import "core/notifications/evening_reminder_service.dart";
import "core/notifications/morning_notification_preferences.dart";
import "core/notifications/morning_notification_service.dart";
import "core/notifications/posting_reminder_preferences.dart";
import "core/notifications/posting_reminder_service.dart";
import "core/notifications/event_reminder_preferences.dart";
import "core/notifications/event_reminder_service.dart";
import "core/weather/weather_cache_service.dart";
import "core/weather/weather_service.dart";
import "features/notifications/screens/notification_preferences_screen.dart";
import "features/onboarding/screens/first_five_items_screen.dart";
import "features/settings/screens/account_deletion_screen.dart";
import "features/shell/screens/main_shell_screen.dart";

/// The root widget of the Vestiaire app.
///
/// Accepts an [AppConfig] for environment configuration and optional
/// injected dependencies for testing.
class VestiaireApp extends StatefulWidget {
  const VestiaireApp({
    required this.config,
    this.authService,
    this.sessionManager,
    this.apiClient,
    this.notificationService,
    this.locationService,
    this.weatherService,
    this.subscriptionService,
    this.morningNotificationService,
    this.morningNotificationPreferences,
    this.eveningReminderService,
    this.eveningReminderPreferences,
    this.postingReminderService,
    this.postingReminderPreferences,
    this.eventReminderService,
    this.eventReminderPreferences,
    super.key,
  });

  final AppConfig config;
  final AuthService? authService;
  final SessionManager? sessionManager;
  final ApiClient? apiClient;
  final NotificationService? notificationService;
  final LocationService? locationService;
  final WeatherService? weatherService;
  final SubscriptionService? subscriptionService;
  final MorningNotificationService? morningNotificationService;
  final MorningNotificationPreferences? morningNotificationPreferences;
  final EveningReminderService? eveningReminderService;
  final EveningReminderPreferences? eveningReminderPreferences;
  final PostingReminderService? postingReminderService;
  final PostingReminderPreferences? postingReminderPreferences;
  final EventReminderService? eventReminderService;
  final EventReminderPreferences? eventReminderPreferences;

  @override
  State<VestiaireApp> createState() => _VestiaireAppState();
}

class _VestiaireAppState extends State<VestiaireApp> {
  late final AuthService _authService;
  late final SessionManager _sessionManager;
  late final ApiClient _apiClient;
  late final NotificationService _notificationService;
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  late final SubscriptionService _subscriptionService;
  late final MorningNotificationService _morningNotificationService;
  late final MorningNotificationPreferences _morningNotificationPreferences;
  late final EveningReminderService _eveningReminderService;
  late final EveningReminderPreferences _eveningReminderPreferences;
  late final PostingReminderService _postingReminderService;
  late final PostingReminderPreferences _postingReminderPreferences;
  late final EventReminderService _eventReminderService;
  late final EventReminderPreferences _eventReminderPreferences;

  /// Current auth state driving the UI.
  AuthState _authState = const AuthState.unauthenticated();

  /// Current sub-screen for auth flow navigation.
  _AuthScreen _currentScreen = _AuthScreen.welcome;

  /// Whether to show the onboarding flow.
  bool _showOnboarding = false;

  /// Items added during the first-5-items challenge.
  List<OnboardingItem> _onboardingItems = [];

  /// Loading flag for async sign-in operations.
  bool _isLoading = false;

  /// Error message for the welcome screen.
  String? _welcomeError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _sessionManager = widget.sessionManager ??
        SessionManager(authService: _authService);
    _apiClient = widget.apiClient ??
        ApiClient(
          baseUrl: widget.config.apiBaseUrl,
          authService: _authService,
          onSessionExpired: _handleSignOut,
        );
    _notificationService =
        widget.notificationService ?? NotificationService();
    _locationService = widget.locationService ?? LocationService();
    _weatherService = widget.weatherService ?? WeatherService();
    _subscriptionService = widget.subscriptionService ??
        SubscriptionService(apiKey: widget.config.revenueCatApiKey);
    _morningNotificationService = widget.morningNotificationService ??
        MorningNotificationService();
    _morningNotificationPreferences =
        widget.morningNotificationPreferences ??
            MorningNotificationPreferences();
    _eveningReminderService = widget.eveningReminderService ??
        EveningReminderService();
    _eveningReminderPreferences = widget.eveningReminderPreferences ??
        EveningReminderPreferences();
    _postingReminderService = widget.postingReminderService ??
        PostingReminderService();
    _postingReminderPreferences = widget.postingReminderPreferences ??
        PostingReminderPreferences();
    _eventReminderService = widget.eventReminderService ??
        EventReminderService();
    _eventReminderPreferences = widget.eventReminderPreferences ??
        EventReminderPreferences();

    // Initialize morning notification service.
    _morningNotificationService.initialize();
    _morningNotificationService.setOnNotificationTap(() {
      // Notification tap brings app to foreground on Home tab.
      // Home is the default tab (index 0), so no navigation needed.
      // Check if this is an evening wear log notification -- the payload
      // is handled in the notification response callback. For now, trigger
      // the wear log navigation flag.
    });

    // Handle FCM push notification taps for social notifications (Story 9.6).
    _setupFcmMessageHandlers();

    // Start persisting session tokens.
    _sessionManager.startListening();

    // Listen to auth state changes.
    _authService.authStateChanges.listen(_onAuthStateChanged);

    // Check current auth state on startup.
    _authState = _authService.currentAuthState;
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  void _onAuthStateChanged(AuthState state) {
    if (!mounted) return;
    setState(() {
      _authState = state;
      if (state.status == AuthStatus.unauthenticated) {
        _currentScreen = _AuthScreen.welcome;
        _showOnboarding = false;
        _onboardingItems = [];
      }
    });

    // Sync RevenueCat user identity with auth state.
    if (state.status == AuthStatus.authenticated && state.userId != null) {
      _syncRevenueCatLogin(state.userId!);
    } else if (state.status == AuthStatus.unauthenticated) {
      _syncRevenueCatLogout();
    }
  }

  /// Set up FCM message handlers for social notification deep linking.
  ///
  /// Story 9.6: When the user taps a social notification, navigate to the
  /// Social tab or post detail screen.
  void _setupFcmMessageHandlers() {
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleFcmNotificationTap(message.data);
    });

    // Handle notification tap when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleFcmNotificationTap(message.data);
      }
    });
  }

  void _handleFcmNotificationTap(Map<String, dynamic> data) {
    final type = data["type"] as String?;
    if (type == "ootd_post" || type == "ootd_comment") {
      // Navigate to Social tab (index 2) -- handled by setting index
      // on MainShellScreen. Since we cannot directly control MainShellScreen
      // state from here, this is a best-effort approach. The app will
      // foreground on the current tab. A deep-link framework could be
      // added in a future story for precise navigation.
      debugPrint("[FCM] Social notification tap: type=$type, data=$data");
    }
  }

  Future<void> _syncRevenueCatLogin(String userId) async {
    try {
      await _subscriptionService.logIn(userId);
      // logIn now also calls syncWithBackend internally
    } catch (e) {
      debugPrint("RevenueCat login error: $e");
    }
  }

  Future<void> _syncRevenueCatLogout() async {
    try {
      await _subscriptionService.logOut();
    } catch (e) {
      debugPrint("RevenueCat logout error: $e");
    }
  }

  Future<void> _handleSignInWithApple() async {
    setState(() {
      _isLoading = true;
      _welcomeError = null;
    });
    try {
      await _authService.signInWithApple();
      await _provisionProfile();
    } on AuthCancelledException {
      // User cancelled — do nothing.
    } catch (e) {
      if (mounted) {
        setState(() {
          _welcomeError = "Apple sign-in failed. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _welcomeError = null;
    });
    try {
      await _authService.signInWithGoogle();
      await _provisionProfile();
    } on AuthCancelledException {
      // User cancelled — do nothing.
    } catch (e) {
      if (mounted) {
        setState(() {
          _welcomeError = "Google sign-in failed. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignUp(String email, String password) async {
    await _authService.signUpWithEmail(email, password);
    // After sign-up, auth state changes to authenticatedUnverified,
    // which drives the UI to show VerificationPendingScreen.
  }

  Future<void> _handleEmailSignIn(String email, String password) async {
    final state = await _authService.signInWithEmail(email, password);
    if (state.status == AuthStatus.authenticated) {
      await _provisionProfile();
    }
    // If unverified, the auth state listener will drive to verification screen.
  }

  Future<bool> _handleCheckVerification() async {
    final state = await _authService.reloadUser();
    if (state.status == AuthStatus.authenticated) {
      await _provisionProfile();
      return true;
    }
    return false;
  }

  Future<void> _handleResendVerification() async {
    await _authService.resendVerificationEmail();
  }

  Future<void> _handleSignOut() async {
    // Clear push token server-side and locally (best effort).
    try {
      await _apiClient.updatePushToken(null);
    } catch (_) {
      // Don't block sign-out on token clearing failure.
    }
    try {
      await _notificationService.deleteToken();
    } catch (_) {
      // Don't block sign-out on local token deletion failure.
    }
    try {
      await _morningNotificationService.cancelAllNotifications();
    } catch (_) {
      // Don't block sign-out on notification cancellation failure.
    }
    await _authService.signOut();
    await _sessionManager.clearSession();
  }

  Future<void> _handleDeleteAccount() async {
    await _apiClient.deleteAccount();
    // Clear session and sign out — auth state listener drives UI to welcome screen
    try {
      await _notificationService.deleteToken();
    } catch (_) {
      // Best effort — don't block deletion flow
    }
    try {
      await _morningNotificationService.cancelAllNotifications();
    } catch (_) {
      // Best effort — don't block deletion flow
    }
    await _sessionManager.clearSession();
    await _authService.signOut();
  }

  Future<void> _handleSendPasswordReset(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  Future<void> _handleEnableNotifications() async {
    try {
      final granted = await _notificationService.requestPermission();
      if (granted) {
        final token = await _notificationService.getToken();
        if (token != null) {
          await _apiClient.updatePushToken(token);
        }
      }
    } catch (e) {
      debugPrint("Error enabling notifications: $e");
    }
  }

  Future<void> _scheduleMorningNotificationIfEnabled() async {
    try {
      final enabled =
          await _morningNotificationPreferences.isOutfitRemindersEnabled();
      if (!enabled) return;

      final morningTime =
          await _morningNotificationPreferences.getMorningTime();

      // Attempt to get cached weather for the notification snippet.
      String weatherSnippet =
          MorningNotificationService.buildWeatherSnippet(null, null);
      try {
        final cacheService = WeatherCacheService();
        final cached = await cacheService.getCachedWeather();
        if (cached != null) {
          weatherSnippet = MorningNotificationService.buildWeatherSnippet(
            cached.currentWeather.temperature,
            cached.currentWeather.weatherDescription,
          );
        }
      } catch (_) {
        // Use fallback snippet
      }

      await _morningNotificationService.scheduleMorningNotification(
        time: morningTime,
        weatherSnippet: weatherSnippet,
      );
    } catch (e) {
      debugPrint("Error scheduling morning notification: $e");
    }
  }

  Future<void> _schedulePostingReminderIfEnabled() async {
    try {
      final enabled =
          await _postingReminderPreferences.isPostingReminderEnabled();
      if (!enabled) return;

      final time =
          await _postingReminderPreferences.getPostingReminderTime();

      await _postingReminderService.schedulePostingReminder(
        time: time,
      );
    } catch (e) {
      debugPrint("Error scheduling posting reminder: $e");
    }
  }

  Future<void> _scheduleEveningReminderIfEnabled() async {
    try {
      final enabled =
          await _eveningReminderPreferences.isWearLoggingEnabled();
      if (!enabled) return;

      final eveningTime =
          await _eveningReminderPreferences.getEveningTime();

      bool hasLoggedToday = false;
      try {
        if (_eveningReminderService.wearLogService != null) {
          hasLoggedToday = await _eveningReminderService
              .hasLoggedToday(_eveningReminderService.wearLogService!);
        }
      } catch (_) {
        // Graceful degradation
      }

      await _eveningReminderService.scheduleEveningReminder(
        time: eveningTime,
        hasLoggedToday: hasLoggedToday,
      );
    } catch (e) {
      debugPrint("Error scheduling evening reminder: $e");
    }
  }

  Future<void> _scheduleEventReminderIfEnabled() async {
    try {
      final enabled =
          await _eventReminderPreferences.isEventRemindersEnabled();
      if (!enabled) return;

      // Event reminder scheduling is handled in HomeScreen when calendar
      // data is loaded. This is a placeholder for the app lifecycle hook.
      // The actual scheduling with formal event filtering happens on
      // HomeScreen load when calendar events are available.
    } catch (e) {
      debugPrint("Error scheduling event reminder: $e");
    }
  }

  Future<void> _provisionProfile() async {
    try {
      final result = await _apiClient.getOrCreateProfile();
      if (mounted) {
        final profile = result["profile"] as Map<String, dynamic>?;
        final onboardingCompletedAt = profile?["onboardingCompletedAt"];
        if (onboardingCompletedAt == null) {
          setState(() {
            _showOnboarding = true;
          });
        } else {
          // Profile provisioned and onboarding complete -- schedule
          // morning notification if enabled.
          _scheduleMorningNotificationIfEnabled();
          _scheduleEveningReminderIfEnabled();
          _schedulePostingReminderIfEnabled();
          _scheduleEventReminderIfEnabled();
        }
      }
    } on ApiException catch (e) {
      if (e.isEmailVerificationRequired) {
        // Server says email not verified — stay on verification screen.
        return;
      }
      // For other API errors during profile provisioning, log but don't block.
      debugPrint("Profile provisioning error: $e");
    } catch (e) {
      debugPrint("Profile provisioning error: $e");
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      await _apiClient.updateProfile(
        onboardingCompletedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint("Error completing onboarding: $e");
    }
    if (mounted) {
      setState(() {
        _showOnboarding = false;
        _onboardingItems = [];
      });
    }
  }

  void _handleProfileSubmit(String displayName, List<String> styles) {
    // Fire and forget the API call
    _apiClient
        .updateProfile(displayName: displayName, stylePreferences: styles)
        .then((_) {})
        .catchError((Object e) {
      debugPrint("Error updating profile: $e");
    });
  }

  void _handlePhotoSubmit(String? photoPath) {
    if (photoPath == null) return;
    // In a real implementation, we would upload to Cloud Storage first
    // and then update the profile with the public URL.
    _apiClient.getSignedUploadUrl(purpose: "profile_photo").then((result) {
      final uploadUrl = result["uploadUrl"] as String;
      final publicUrl = result["publicUrl"] as String;
      return _apiClient.uploadImage(photoPath, uploadUrl).then((_) {
        return _apiClient.updateProfile(photoUrl: publicUrl);
      });
    }).then((_) {}).catchError((Object e) {
      debugPrint("Error uploading profile photo: $e");
    });
  }

  void _handleAddItem(String photoPath) {
    _apiClient.getSignedUploadUrl(purpose: "item_photo").then((result) {
      final uploadUrl = result["uploadUrl"] as String;
      final publicUrl = result["publicUrl"] as String;
      return _apiClient.uploadImage(photoPath, uploadUrl).then((_) {
        return _apiClient.createItem(photoUrl: publicUrl);
      }).then((itemResult) {
        if (mounted) {
          setState(() {
            _onboardingItems = [
              ..._onboardingItems,
              OnboardingItem(photoUrl: publicUrl),
            ];
          });
          // Auto-complete if 5 items reached
          if (_onboardingItems.length >= 5) {
            _completeOnboarding();
          }
        }
      });
    }).then((_) {}).catchError((Object e) {
      debugPrint("Error adding item: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Vestiaire",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (_authState.status) {
      case AuthStatus.authenticated:
        if (_showOnboarding) {
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            body: SafeArea(
              child: OnboardingFlow(
                items: _onboardingItems,
                onComplete: _completeOnboarding,
                onSkip: _completeOnboarding,
                onProfileSubmit: _handleProfileSubmit,
                onPhotoSubmit: _handlePhotoSubmit,
                onAddItem: _handleAddItem,
                onEnableNotifications: _handleEnableNotifications,
              ),
            ),
          );
        }
        return MainShellScreen(
          config: widget.config,
          onSignOut: _handleSignOut,
          onDeleteAccount: _handleDeleteAccount,
          apiClient: _apiClient,
          notificationService: _notificationService,
          locationService: _locationService,
          weatherService: _weatherService,
          subscriptionService: _subscriptionService,
          morningNotificationService: _morningNotificationService,
          morningNotificationPreferences: _morningNotificationPreferences,
          eveningReminderService: _eveningReminderService,
          eveningReminderPreferences: _eveningReminderPreferences,
          postingReminderService: _postingReminderService,
          postingReminderPreferences: _postingReminderPreferences,
          eventReminderService: _eventReminderService,
          eventReminderPreferences: _eventReminderPreferences,
        );

      case AuthStatus.authenticatedUnverified:
        return VerificationPendingScreen(
          email: _authState.email ?? "",
          onCheckVerification: _handleCheckVerification,
          onResendEmail: _handleResendVerification,
          onSignOut: _handleSignOut,
        );

      case AuthStatus.unauthenticated:
        return _buildAuthScreen();
    }
  }

  Widget _buildAuthScreen() {
    switch (_currentScreen) {
      case _AuthScreen.welcome:
        return WelcomeScreen(
          onSignInWithApple: _handleSignInWithApple,
          onSignInWithGoogle: _handleSignInWithGoogle,
          onSignUpWithEmail: () =>
              setState(() => _currentScreen = _AuthScreen.emailSignUp),
          onSignIn: () =>
              setState(() => _currentScreen = _AuthScreen.emailSignIn),
          isLoading: _isLoading,
          errorMessage: _welcomeError,
        );

      case _AuthScreen.emailSignUp:
        return EmailSignUpScreen(
          onSignUp: _handleEmailSignUp,
          onBackPressed: () =>
              setState(() => _currentScreen = _AuthScreen.welcome),
        );

      case _AuthScreen.emailSignIn:
        return EmailSignInScreen(
          onSignIn: _handleEmailSignIn,
          onBackPressed: () =>
              setState(() => _currentScreen = _AuthScreen.welcome),
          onForgotPassword: () =>
              setState(() => _currentScreen = _AuthScreen.forgotPassword),
        );

      case _AuthScreen.forgotPassword:
        return ForgotPasswordScreen(
          onSendResetLink: _handleSendPasswordReset,
          onBackToSignIn: () =>
              setState(() => _currentScreen = _AuthScreen.emailSignIn),
        );
    }
  }
}

enum _AuthScreen { welcome, emailSignUp, emailSignIn, forgotPassword }

/// The authenticated home screen with bottom navigation (Home, Wardrobe, Profile).
///
/// This is the placeholder home shell from Story 1.1, preserved as-is.
class BootstrapHomeScreen extends StatelessWidget {
  const BootstrapHomeScreen({
    required this.config,
    this.onSignOut,
    this.onDeleteAccount,
    this.apiClient,
    this.notificationService,
    super.key,
  });

  static const routeName = "/";
  final AppConfig config;
  final VoidCallback? onSignOut;
  final Future<void> Function()? onDeleteAccount;
  final ApiClient? apiClient;
  final NotificationService? notificationService;

  Future<void> _openNotificationPreferences(BuildContext context) async {
    // Load current profile to get notification preferences
    Map<String, bool> preferences = {
      "outfit_reminders": true,
      "wear_logging": true,
      "analytics": true,
      "social": true,
    };
    bool notificationsEnabled = true;

    try {
      if (apiClient != null) {
        final result = await apiClient!.getOrCreateProfile();
        final profile = result["profile"] as Map<String, dynamic>?;
        final prefs = profile?["notificationPreferences"];
        if (prefs is Map) {
          preferences = {
            "outfit_reminders": prefs["outfit_reminders"] as bool? ?? true,
            "wear_logging": prefs["wear_logging"] as bool? ?? true,
            "analytics": prefs["analytics"] as bool? ?? true,
            "social": prefs["social"] as bool? ?? true,
          };
        }
      }
    } catch (e) {
      debugPrint("Error loading notification preferences: $e");
    }

    // Check OS notification status
    if (notificationService != null) {
      try {
        final status = await notificationService!.getPermissionStatus();
        notificationsEnabled =
            status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
      } catch (_) {
        // Assume enabled if we can't check
      }
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationPreferencesScreen(
          initialPreferences: preferences,
          notificationsEnabled: notificationsEnabled,
          onPreferenceChanged: (key, value) async {
            try {
              if (apiClient != null) {
                await apiClient!.updateNotificationPreferences({key: value});
              }
              return true;
            } catch (e) {
              debugPrint("Error updating notification preference: $e");
              return false;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vestiaire"),
        actions: [
          Semantics(
            label: "Notification settings",
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: "Notification settings",
              onPressed: () => _openNotificationPreferences(context),
            ),
          ),
          if (onSignOut != null)
            Semantics(
              label: "Sign out",
              child: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: "Sign out",
                onPressed: onSignOut,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Vestiaire bootstrap ready",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text("Environment: ${config.environment}"),
              Text("API: ${config.apiBaseUrl}"),
              const SizedBox(height: 32),
              if (onDeleteAccount != null)
                Semantics(
                  label: "Delete Account",
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountDeletionScreen(
                            onDeleteRequested: () async {
                              if (apiClient != null) {
                                await apiClient!.deleteAccount();
                              }
                            },
                            onAccountDeleted: () {
                              // Pop back first, then trigger cleanup
                              Navigator.of(context).popUntil((route) => route.isFirst);
                              onDeleteAccount!();
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Delete Account",
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: "Wardrobe",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        selectedIndex: 0,
      ),
    );
  }
}
