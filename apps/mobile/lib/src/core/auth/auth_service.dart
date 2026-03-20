import "dart:async";
import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:google_sign_in/google_sign_in.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";

import "auth_state.dart";

/// Exception thrown when an auth operation is cancelled by the user.
class AuthCancelledException implements Exception {
  const AuthCancelledException([this.message = "Sign-in was cancelled"]);
  final String message;
  @override
  String toString() => message;
}

/// Service that wraps FirebaseAuth and provides a unified auth API.
///
/// Accepts injected dependencies for testability.
class AuthService {
  AuthService({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppleSignInDelegate? appleSignInDelegate,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _appleSignInDelegate =
            appleSignInDelegate ?? const DefaultAppleSignInDelegate();

  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppleSignInDelegate _appleSignInDelegate;

  /// Stream of auth state changes mapped to our domain [AuthState].
  Stream<AuthState> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  /// Stream of ID token changes for session management.
  Stream<AuthState> get idTokenChanges {
    return _firebaseAuth.idTokenChanges().map(_mapUser);
  }

  /// Returns the current [AuthState] synchronously.
  AuthState get currentAuthState {
    return _mapUser(_firebaseAuth.currentUser);
  }

  /// Returns the current Firebase user, if any.
  fb.User? get currentUser => _firebaseAuth.currentUser;

  /// Sign up with email and password. Sends a verification email on success.
  Future<AuthState> signUpWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.sendEmailVerification();
    return _mapUser(credential.user);
  }

  /// Sign in with email and password.
  Future<AuthState> signInWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapUser(credential.user);
  }

  /// Sign in with Apple.
  Future<AuthState> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final appleCredential = await _appleSignInDelegate.getCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    if (appleCredential == null) {
      throw const AuthCancelledException("Apple Sign-In was cancelled");
    }

    final oAuthCredential = fb.OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential =
        await _firebaseAuth.signInWithCredential(oAuthCredential);
    return _mapUser(userCredential.user);
  }

  /// Sign in with Google.
  Future<AuthState> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthCancelledException("Google Sign-In was cancelled");
    }

    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _firebaseAuth.signInWithCredential(credential);
    return _mapUser(userCredential.user);
  }

  /// Reload the current user to get updated email verification status.
  Future<AuthState> reloadUser() async {
    await _firebaseAuth.currentUser?.reload();
    // After reload, currentUser is refreshed in place.
    return _mapUser(_firebaseAuth.currentUser);
  }

  /// Sign out from all providers.
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Resend the verification email to the current user.
  Future<void> resendVerificationEmail() async {
    await _firebaseAuth.currentUser?.sendEmailVerification();
  }

  /// Send a password reset email.
  ///
  /// Swallows `user-not-found` errors to prevent email enumeration.
  /// Other Firebase errors are rethrown so the UI can display a generic message.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == "user-not-found") {
        // Swallow to prevent email enumeration.
        return;
      }
      rethrow;
    }
  }

  /// Get the current ID token for API calls.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _firebaseAuth.currentUser?.getIdToken(forceRefresh);
  }

  AuthState _mapUser(fb.User? user) {
    if (user == null) {
      return const AuthState.unauthenticated();
    }

    final isEmailProvider = user.providerData.any(
      (info) => info.providerId == "password",
    );

    if (isEmailProvider && !user.emailVerified) {
      return AuthState(
        status: AuthStatus.authenticatedUnverified,
        userId: user.uid,
        email: user.email,
        isEmailProvider: true,
      );
    }

    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.uid,
      email: user.email,
      isEmailProvider: isEmailProvider,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._";
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Abstraction for Apple Sign-In to enable testing.
abstract class AppleSignInDelegate {
  const AppleSignInDelegate();

  Future<AuthorizationCredentialAppleID?> getCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  });
}

/// Default implementation that calls the real Apple Sign-In.
class DefaultAppleSignInDelegate extends AppleSignInDelegate {
  const DefaultAppleSignInDelegate();

  @override
  Future<AuthorizationCredentialAppleID?> getCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) async {
    try {
      return await SignInWithApple.getAppleIDCredential(
        scopes: scopes,
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }
  }
}
