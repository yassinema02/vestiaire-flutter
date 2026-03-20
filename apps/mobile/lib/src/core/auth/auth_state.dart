/// Represents the authentication state of the current user.
enum AuthStatus {
  /// No user is signed in.
  unauthenticated,

  /// A user is signed in but email is not verified (email/password provider).
  authenticatedUnverified,

  /// A user is signed in and fully verified (or social provider).
  authenticated,
}

/// Immutable snapshot of authentication state.
class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.isEmailProvider = false,
  });

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        userId = null,
        email = null,
        isEmailProvider = false;

  final AuthStatus status;
  final String? userId;
  final String? email;
  final bool isEmailProvider;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    bool? isEmailProvider,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isEmailProvider: isEmailProvider ?? this.isEmailProvider,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.userId == userId &&
        other.email == email &&
        other.isEmailProvider == isEmailProvider;
  }

  @override
  int get hashCode => Object.hash(status, userId, email, isEmailProvider);

  @override
  String toString() =>
      "AuthState(status: $status, userId: $userId, email: $email)";
}
