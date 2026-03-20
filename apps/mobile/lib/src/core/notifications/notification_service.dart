import "package:firebase_messaging/firebase_messaging.dart";

/// Service for managing push notification permissions and FCM tokens.
///
/// Accepts an optional [FirebaseMessaging] instance for dependency injection
/// in tests.
class NotificationService {
  NotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Requests push notification permission from the OS.
  ///
  /// Returns `true` if the user authorized or provisionally authorized
  /// notifications, `false` otherwise.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Returns the current FCM device token, or `null` if unavailable.
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Deletes the local FCM token, revoking it on the device.
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
  }

  /// Stream that emits new FCM tokens when they rotate.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Returns the current notification permission status.
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }
}
