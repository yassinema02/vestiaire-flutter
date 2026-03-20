import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/auth/screens/verification_pending_screen.dart";

void main() {
  Widget buildTestWidget({
    String email = "test@example.com",
    Future<bool> Function()? onCheckVerification,
    Future<void> Function()? onResendEmail,
    VoidCallback? onSignOut,
  }) {
    return MaterialApp(
      home: VerificationPendingScreen(
        email: email,
        onCheckVerification: onCheckVerification ?? () async => false,
        onResendEmail: onResendEmail ?? () async {},
        onSignOut: onSignOut ?? () {},
      ),
    );
  }

  group("VerificationPendingScreen", () {
    testWidgets("renders verification message with email", (tester) async {
      await tester.pumpWidget(buildTestWidget(email: "user@test.com"));

      expect(find.text("Verify your email"), findsOneWidget);
      expect(
        find.textContaining("user@test.com"),
        findsOneWidget,
      );
    });

    testWidgets("renders check verification button", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("I've verified my email"), findsOneWidget);
    });

    testWidgets("renders resend verification button", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Resend verification email"), findsOneWidget);
    });

    testWidgets("renders use different account link", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Use a different account"), findsOneWidget);
    });

    testWidgets("check verification button calls callback", (tester) async {
      bool called = false;
      await tester.pumpWidget(buildTestWidget(
        onCheckVerification: () async {
          called = true;
          return false;
        },
      ));

      await tester.tap(find.text("I've verified my email"));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets("shows not-yet-verified message when check fails",
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onCheckVerification: () async => false,
      ));

      await tester.tap(find.text("I've verified my email"));
      await tester.pumpAndSettle();

      expect(
        find.text("Email not yet verified. Please check your inbox."),
        findsOneWidget,
      );
    });

    testWidgets("resend button calls callback", (tester) async {
      bool called = false;
      await tester.pumpWidget(buildTestWidget(
        onResendEmail: () async {
          called = true;
        },
      ));

      await tester.tap(find.text("Resend verification email"));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets("shows success message after resending email", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onResendEmail: () async {},
      ));

      await tester.tap(find.text("Resend verification email"));
      await tester.pumpAndSettle();

      expect(
        find.text("Verification email sent! Check your inbox."),
        findsOneWidget,
      );
    });

    testWidgets("sign out button calls callback", (tester) async {
      bool called = false;
      await tester.pumpWidget(buildTestWidget(
        onSignOut: () {
          called = true;
        },
      ));

      await tester.tap(find.text("Use a different account"));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets("shows error when check verification throws", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onCheckVerification: () async {
          throw Exception("Network error");
        },
      ));

      await tester.tap(find.text("I've verified my email"));
      await tester.pumpAndSettle();

      expect(
        find.text(
            "Could not check verification status. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets("shows error when resend throws", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onResendEmail: () async {
          throw Exception("Network error");
        },
      ));

      await tester.tap(find.text("Resend verification email"));
      await tester.pumpAndSettle();

      expect(
        find.text(
            "Could not send verification email. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets("email icon is displayed", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byIcon(Icons.mark_email_unread_outlined),
        findsOneWidget,
      );
    });
  });
}
