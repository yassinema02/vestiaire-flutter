import "dart:async";

import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "auth_service.dart";
import "auth_state.dart";

/// Key used to store the Firebase ID token in secure storage.
const String kIdTokenKey = "vestiaire_firebase_id_token";

/// Key used to store the user ID in secure storage.
const String kUserIdKey = "vestiaire_user_id";

/// Manages session persistence using flutter_secure_storage.
///
/// Listens to auth state / ID token changes and persists tokens
/// in the iOS Keychain via flutter_secure_storage.
class SessionManager {
  SessionManager({
    required AuthService authService,
    FlutterSecureStorage? secureStorage,
  })  : _authService = authService,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;
  StreamSubscription<AuthState>? _tokenSubscription;

  /// Start listening to ID token changes and persisting them.
  void startListening() {
    _tokenSubscription = _authService.idTokenChanges.listen(_onTokenChange);
  }

  /// Stop listening to token changes.
  void dispose() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }

  Future<void> _onTokenChange(AuthState state) async {
    if (state.status == AuthStatus.unauthenticated) {
      await clearSession();
      return;
    }

    final token = await _authService.getIdToken();
    if (token != null) {
      await persistToken(token);
    }
    if (state.userId != null) {
      await _secureStorage.write(key: kUserIdKey, value: state.userId);
    }
  }

  /// Persist a Firebase ID token to secure storage.
  Future<void> persistToken(String token) async {
    await _secureStorage.write(key: kIdTokenKey, value: token);
  }

  /// Retrieve the persisted Firebase ID token, if any.
  Future<String?> getPersistedToken() async {
    return _secureStorage.read(key: kIdTokenKey);
  }

  /// Retrieve the persisted user ID, if any.
  Future<String?> getPersistedUserId() async {
    return _secureStorage.read(key: kUserIdKey);
  }

  /// Clear all persisted session data.
  Future<void> clearSession() async {
    await _secureStorage.delete(key: kIdTokenKey);
    await _secureStorage.delete(key: kUserIdKey);
  }

  /// Check if a persisted session exists.
  Future<bool> hasPersistedSession() async {
    final token = await getPersistedToken();
    return token != null;
  }
}
