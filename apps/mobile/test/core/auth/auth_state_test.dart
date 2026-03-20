import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/auth/auth_state.dart";

void main() {
  group("AuthState", () {
    test("unauthenticated factory creates correct state", () {
      const state = AuthState.unauthenticated();
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.userId, isNull);
      expect(state.email, isNull);
      expect(state.isEmailProvider, false);
    });

    test("authenticated state has correct properties", () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        userId: "uid123",
        email: "test@example.com",
        isEmailProvider: true,
      );
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, "uid123");
      expect(state.email, "test@example.com");
      expect(state.isEmailProvider, true);
    });

    test("copyWith produces new state with overrides", () {
      const original = AuthState(
        status: AuthStatus.unauthenticated,
        userId: "a",
        email: "a@a.com",
      );
      final copied = original.copyWith(
        status: AuthStatus.authenticated,
        userId: "b",
      );
      expect(copied.status, AuthStatus.authenticated);
      expect(copied.userId, "b");
      expect(copied.email, "a@a.com");
    });

    test("equality works correctly", () {
      const a = AuthState(
        status: AuthStatus.authenticated,
        userId: "uid",
        email: "e@e.com",
      );
      const b = AuthState(
        status: AuthStatus.authenticated,
        userId: "uid",
        email: "e@e.com",
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test("inequality when fields differ", () {
      const a = AuthState(
        status: AuthStatus.authenticated,
        userId: "uid1",
      );
      const b = AuthState(
        status: AuthStatus.authenticated,
        userId: "uid2",
      );
      expect(a, isNot(equals(b)));
    });

    test("toString includes status and userId", () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        userId: "abc",
        email: "x@x.com",
      );
      expect(state.toString(), contains("authenticated"));
      expect(state.toString(), contains("abc"));
    });
  });
}
