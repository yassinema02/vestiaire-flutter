import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/auth/screens/email_sign_in_screen.dart";

void main() {
  Widget buildTestWidget({
    Future<void> Function(String, String)? onSignIn,
    VoidCallback? onBackPressed,
    VoidCallback? onForgotPassword,
  }) {
    return MaterialApp(
      home: EmailSignInScreen(
        onSignIn: onSignIn ?? (_, __) async {},
        onBackPressed: onBackPressed,
        onForgotPassword: onForgotPassword,
      ),
    );
  }

  group("EmailSignInScreen", () {
    testWidgets("renders email and password fields", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Email"), findsOneWidget);
      expect(find.text("Password"), findsOneWidget);
    });

    testWidgets("renders Sign In button", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Sign In"), findsWidgets);
    });

    testWidgets("validates empty email", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, "Sign In"));
      await tester.pumpAndSettle();

      expect(find.text("Email is required"), findsOneWidget);
    });

    testWidgets("validates empty password", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "test@example.com",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Sign In"));
      await tester.pumpAndSettle();

      expect(find.text("Password is required"), findsOneWidget);
    });

    testWidgets("calls onSignIn with valid inputs", (tester) async {
      String? capturedEmail;
      String? capturedPassword;

      await tester.pumpWidget(buildTestWidget(
        onSignIn: (email, password) async {
          capturedEmail = email;
          capturedPassword = password;
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "user@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "mypassword",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Sign In"));
      await tester.pumpAndSettle();

      expect(capturedEmail, "user@example.com");
      expect(capturedPassword, "mypassword");
    });

    testWidgets("shows error for wrong password", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSignIn: (_, __) async {
          throw Exception("wrong-password");
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "user@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "wrongpass",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Sign In"));
      await tester.pumpAndSettle();

      expect(
        find.text("Incorrect password. Please try again"),
        findsOneWidget,
      );
    });

    testWidgets("shows error for user not found", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSignIn: (_, __) async {
          throw Exception("user-not-found");
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "nonexistent@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "somepass1",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Sign In"));
      await tester.pumpAndSettle();

      expect(
        find.text("No account found with this email"),
        findsOneWidget,
      );
    });

    testWidgets("shows generic error for unknown failure", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSignIn: (_, __) async {
          throw Exception("unknown");
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "user@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "password1",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Sign In"));
      await tester.pumpAndSettle();

      expect(
        find.text("Sign-in failed. Please try again"),
        findsOneWidget,
      );
    });

    testWidgets("renders Forgot password? link when callback provided", (tester) async {
      bool forgotPasswordCalled = false;
      await tester.pumpWidget(buildTestWidget(
        onForgotPassword: () {
          forgotPasswordCalled = true;
        },
      ));

      expect(find.text("Forgot password?"), findsOneWidget);

      await tester.tap(find.text("Forgot password?"));
      await tester.pumpAndSettle();
      expect(forgotPasswordCalled, isTrue);
    });

    testWidgets("does not render Forgot password? link when no callback", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Forgot password?"), findsNothing);
    });

    testWidgets("back button calls onBackPressed", (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(buildTestWidget(
        onBackPressed: () {
          backPressed = true;
        },
      ));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(backPressed, isTrue);
    });
  });
}
