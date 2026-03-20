import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/settings/screens/account_deletion_screen.dart";

void main() {
  group("AccountDeletionScreen", () {
    late bool accountDeletedCalled;
    late Completer<void> deleteCompleter;

    setUp(() {
      accountDeletedCalled = false;
      deleteCompleter = Completer<void>();
    });

    Widget buildSubject({
      VoidCallback? onCancel,
      Future<void> Function()? onDeleteRequested,
    }) {
      return MaterialApp(
        home: AccountDeletionScreen(
          onAccountDeleted: () => accountDeletedCalled = true,
          onDeleteRequested: onDeleteRequested ?? () => deleteCompleter.future,
          onCancel: onCancel,
        ),
      );
    }

    testWidgets("renders warning icon", (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets("renders Delete Account title", (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text("Delete Account"), findsAtLeast(1));
    });

    testWidgets("renders deletion summary text listing all data categories",
        (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text("Your profile and personal information"), findsOneWidget);
      expect(find.text("All wardrobe items and photos"), findsOneWidget);
      expect(find.text("Notification preferences"), findsOneWidget);
      expect(find.text("Your sign-in credentials"), findsOneWidget);
    });

    testWidgets("renders 'This action cannot be undone.' text", (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text("This action cannot be undone."), findsOneWidget);
    });

    testWidgets("renders Delete My Account button", (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text("Delete My Account"), findsOneWidget);
    });

    testWidgets("renders Cancel button", (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text("Cancel"), findsOneWidget);
    });

    testWidgets("Cancel button calls onCancel callback", (tester) async {
      bool cancelCalled = false;
      await tester.pumpWidget(buildSubject(
        onCancel: () => cancelCalled = true,
      ));

      await tester.tap(find.text("Cancel"));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets("tapping Delete My Account shows confirmation dialog",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      expect(find.text("Are you sure?"), findsOneWidget);
      expect(
          find.text("Type DELETE to confirm account deletion."), findsOneWidget);
    });

    testWidgets("confirmation dialog Confirm button is disabled initially",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      // The Confirm button should be disabled (onPressed is null)
      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, "Confirm"),
      );
      expect(confirmButton.onPressed, isNull);
    });

    testWidgets("confirmation dialog Confirm button enables when DELETE is typed",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      // Type "DELETE" in the text field
      await tester.enterText(find.byType(TextField), "DELETE");
      await tester.pump();

      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, "Confirm"),
      );
      expect(confirmButton.onPressed, isNotNull);
    });

    testWidgets("confirmation dialog accepts case-insensitive DELETE",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "delete");
      await tester.pump();

      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, "Confirm"),
      );
      expect(confirmButton.onPressed, isNotNull);
    });

    testWidgets("confirmation dialog Cancel dismisses without deletion",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      // Tap Cancel in the dialog using Semantics label to disambiguate
      await tester.tap(find.bySemanticsLabel("Cancel confirmation"));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text("Are you sure?"), findsNothing);
      expect(accountDeletedCalled, isFalse);
    });

    testWidgets("successful deletion calls onAccountDeleted callback",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        onDeleteRequested: () async {
          // Simulate successful API call
        },
      ));

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "DELETE");
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, "Confirm"));
      // Use pump() instead of pumpAndSettle() since the callback completes synchronously
      await tester.pump();
      await tester.pump();

      expect(accountDeletedCalled, isTrue);
    });

    testWidgets("failed deletion shows error SnackBar", (tester) async {
      await tester.pumpWidget(buildSubject(
        onDeleteRequested: () async {
          throw Exception("Network error");
        },
      ));

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "DELETE");
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, "Confirm"));
      await tester.pumpAndSettle();

      expect(
        find.text("Failed to delete account. Please try again."),
        findsOneWidget,
      );
      expect(accountDeletedCalled, isFalse);
    });

    testWidgets("loading state shows progress indicator and hides buttons",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Delete My Account"));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "DELETE");
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, "Confirm"));
      // Pump once to show loading state (don't settle — future is pending)
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Delete My Account button should not be visible during loading
      expect(find.text("Delete My Account"), findsNothing);
    });

    testWidgets("Semantics labels are present on interactive elements",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Check Semantics on Delete My Account button
      expect(
        find.bySemanticsLabel("Delete My Account"),
        findsAtLeast(1),
      );

      // Check Semantics on Cancel button
      expect(
        find.bySemanticsLabel("Cancel"),
        findsAtLeast(1),
      );

      // Open dialog and check its elements
      await tester.tap(find.widgetWithText(ElevatedButton, "Delete My Account"));
      await tester.pumpAndSettle();

      // Dialog title and text field are present
      expect(find.text("Are you sure?"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // Dialog action buttons with Semantics labels
      expect(find.bySemanticsLabel("Cancel confirmation"), findsOneWidget);
      expect(find.bySemanticsLabel("Confirm account deletion"), findsOneWidget);
    });
  });
}
