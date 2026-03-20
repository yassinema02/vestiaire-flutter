import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/auth/screens/email_sign_up_screen.dart";

void main() {
  Widget buildTestWidget({
    Future<void> Function(String, String)? onSignUp,
    VoidCallback? onBackPressed,
  }) {
    return MaterialApp(
      home: EmailSignUpScreen(
        onSignUp: onSignUp ?? (_, __) async {},
        onBackPressed: onBackPressed,
      ),
    );
  }

  group("EmailSignUpScreen", () {
    testWidgets("renders email and password fields", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Email"), findsOneWidget);
      expect(find.text("Password"), findsOneWidget);
    });

    testWidgets("renders Create Account button", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Create Account"), findsWidgets);
    });

    testWidgets("validates empty email", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap the submit button without entering anything.
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(find.text("Email is required"), findsOneWidget);
    });

    testWidgets("validates invalid email format", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "notanemail",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "12345678",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(
        find.text("Please enter a valid email address"),
        findsOneWidget,
      );
    });

    testWidgets("validates empty password", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "test@example.com",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(find.text("Password is required"), findsOneWidget);
    });

    testWidgets("validates password too short", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "test@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "short",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(
        find.text("Password must be at least 8 characters"),
        findsOneWidget,
      );
    });

    testWidgets("calls onSignUp with valid inputs", (tester) async {
      String? capturedEmail;
      String? capturedPassword;

      await tester.pumpWidget(buildTestWidget(
        onSignUp: (email, password) async {
          capturedEmail = email;
          capturedPassword = password;
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "test@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "securepassword",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(capturedEmail, "test@example.com");
      expect(capturedPassword, "securepassword");
    });

    testWidgets("shows error message on sign-up failure", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSignUp: (_, __) async {
          throw Exception("email-already-in-use");
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "test@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "securepassword",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(
        find.text("An account with this email already exists"),
        findsOneWidget,
      );
    });

    testWidgets("shows generic error for unknown failure", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSignUp: (_, __) async {
          throw Exception("some-unknown-error");
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "test@example.com",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Password"),
        "securepassword",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Create Account"));
      await tester.pumpAndSettle();

      expect(
        find.text("Something went wrong. Please try again"),
        findsOneWidget,
      );
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
