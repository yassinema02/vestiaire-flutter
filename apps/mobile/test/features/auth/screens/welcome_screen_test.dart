import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/auth/screens/welcome_screen.dart";

void main() {
  Widget buildTestWidget({
    Future<void> Function()? onSignInWithApple,
    Future<void> Function()? onSignInWithGoogle,
    VoidCallback? onSignUpWithEmail,
    VoidCallback? onSignIn,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return MaterialApp(
      home: WelcomeScreen(
        onSignInWithApple: onSignInWithApple ?? () async {},
        onSignInWithGoogle: onSignInWithGoogle ?? () async {},
        onSignUpWithEmail: onSignUpWithEmail ?? () {},
        onSignIn: onSignIn ?? () {},
        isLoading: isLoading,
        errorMessage: errorMessage,
      ),
    );
  }

  group("WelcomeScreen", () {
    testWidgets("renders branding text", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Vestiaire"), findsOneWidget);
      expect(
        find.text("Your AI-powered wardrobe assistant"),
        findsOneWidget,
      );
    });

    testWidgets("renders all three sign-in buttons", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("Continue with Apple"), findsOneWidget);
      expect(find.text("Continue with Google"), findsOneWidget);
      expect(find.text("Sign up with Email"), findsOneWidget);
    });

    testWidgets('renders "Already have an account? Sign in" link',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.text("Already have an account? Sign in"),
        findsOneWidget,
      );
    });

    testWidgets("Apple sign-in button is tappable", (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestWidget(
        onSignInWithApple: () async {
          tapped = true;
        },
      ));

      await tester.tap(find.text("Continue with Apple"));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets("Google sign-in button is tappable", (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestWidget(
        onSignInWithGoogle: () async {
          tapped = true;
        },
      ));

      await tester.tap(find.text("Continue with Google"));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets("Email sign-up button is tappable", (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestWidget(
        onSignUpWithEmail: () {
          tapped = true;
        },
      ));

      await tester.tap(find.text("Sign up with Email"));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets("Sign-in link is tappable", (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestWidget(
        onSignIn: () {
          tapped = true;
        },
      ));

      await tester.tap(find.text("Already have an account? Sign in"));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets("shows loading indicator when isLoading is true",
        (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Sign-in link should be hidden during loading.
      expect(
        find.text("Already have an account? Sign in"),
        findsNothing,
      );
    });

    testWidgets("shows error message when provided", (tester) async {
      await tester.pumpWidget(buildTestWidget(
        errorMessage: "Something went wrong",
      ));

      expect(find.text("Something went wrong"), findsOneWidget);
    });

    testWidgets("buttons are disabled when loading", (tester) async {
      bool appleTapped = false;
      await tester.pumpWidget(buildTestWidget(
        isLoading: true,
        onSignInWithApple: () async {
          appleTapped = true;
        },
      ));

      // The button should exist but be disabled.
      final appleButton = find.text("Continue with Apple");
      expect(appleButton, findsOneWidget);
      await tester.tap(appleButton);
      await tester.pump();
      expect(appleTapped, isFalse);
    });
  });
}
