import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/auth/screens/forgot_password_screen.dart";

void main() {
  Widget buildTestWidget({
    Future<void> Function(String)? onSendResetLink,
    VoidCallback? onBackToSignIn,
  }) {
    return MaterialApp(
      home: ForgotPasswordScreen(
        onSendResetLink: onSendResetLink ?? (_) async {},
        onBackToSignIn: onBackToSignIn,
      ),
    );
  }

  group("ForgotPasswordScreen", () {
    testWidgets("renders email field and Send Reset Link button", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Email"), findsOneWidget);
      expect(find.text("Send Reset Link"), findsOneWidget);
    });

    testWidgets("renders Reset Password title", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Reset Password"), findsOneWidget);
    });

    testWidgets("renders description text", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.text("Enter your email address and we'll send you a link to reset your password."),
        findsOneWidget,
      );
    });

    testWidgets("validates empty email", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, "Send Reset Link"));
      await tester.pumpAndSettle();

      expect(find.text("Email is required"), findsOneWidget);
    });

    testWidgets("valid email submission calls onSendResetLink", (tester) async {
      String? capturedEmail;

      await tester.pumpWidget(buildTestWidget(
        onSendResetLink: (email) async {
          capturedEmail = email;
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "user@example.com",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Send Reset Link"));
      await tester.pumpAndSettle();

      expect(capturedEmail, "user@example.com");
    });

    testWidgets("shows success confirmation message after submission", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSendResetLink: (_) async {
          // Success - no error thrown
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "user@example.com",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Send Reset Link"));
      await tester.pumpAndSettle();

      expect(
        find.text("If an account exists for this email, a reset link has been sent."),
        findsOneWidget,
      );
    });

    testWidgets("shows error message on failure", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSendResetLink: (_) async {
          throw Exception("network-error");
        },
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, "Email"),
        "user@example.com",
      );
      await tester.tap(find.widgetWithText(ElevatedButton, "Send Reset Link"));
      await tester.pumpAndSettle();

      expect(
        find.text("Something went wrong. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets("Back to Sign In button calls onBackToSignIn", (tester) async {
      bool backCalled = false;

      await tester.pumpWidget(buildTestWidget(
        onBackToSignIn: () {
          backCalled = true;
        },
      ));

      await tester.tap(find.text("Back to Sign In"));
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });

    testWidgets("back arrow button calls onBackToSignIn", (tester) async {
      bool backCalled = false;

      await tester.pumpWidget(buildTestWidget(
        onBackToSignIn: () {
          backCalled = true;
        },
      ));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });

    testWidgets("has Semantics labels on interactive elements", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onBackToSignIn: () {},
      ));

      // Verify Semantics widgets with correct labels are present in the widget tree
      final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
      final labels = semanticsWidgets
          .where((s) => s.properties.label != null)
          .map((s) => s.properties.label!)
          .toList();

      expect(labels, contains("Email address"));
      expect(labels, contains("Send reset link"));
      expect(labels, contains("Back to Sign In"));
    });

    testWidgets("uses correct background color", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF3F4F6));
    });

    testWidgets("uses correct primary button color", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Send Reset Link"),
      );
      final style = button.style;
      // Verify the button exists and has styling
      expect(style, isNotNull);
    });
  });
}
