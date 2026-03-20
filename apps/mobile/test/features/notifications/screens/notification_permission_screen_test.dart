import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/notifications/screens/notification_permission_screen.dart";

void main() {
  group("NotificationPermissionScreen", () {
    late bool enableCalled;
    late bool skipCalled;

    setUp(() {
      enableCalled = false;
      skipCalled = false;
    });

    Widget buildSubject() {
      return MaterialApp(
        home: NotificationPermissionScreen(
          onEnable: () => enableCalled = true,
          onSkip: () => skipCalled = true,
        ),
      );
    }

    testWidgets("renders bell icon", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });

    testWidgets("renders title text", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Stay in the Loop"), findsOneWidget);
    });

    testWidgets("renders explanation text", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.textContaining("Get timely reminders"),
        findsOneWidget,
      );
    });

    testWidgets("renders all four notification category descriptions",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Outfit Reminders"), findsOneWidget);
      expect(find.text("Wear Logging"), findsOneWidget);
      expect(find.text("Style Insights"), findsOneWidget);
      expect(find.text("Social Updates"), findsOneWidget);
    });

    testWidgets("Enable Notifications button renders with correct styling",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Enable Notifications"),
      );
      expect(button, isNotNull);
    });

    testWidgets("Enable Notifications button calls onEnable callback",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Enable Notifications"));
      await tester.pumpAndSettle();

      expect(enableCalled, isTrue);
    });

    testWidgets("Not Now button renders and calls skip callback",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.ensureVisible(find.text("Not Now"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Not Now"));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets("Semantics labels present on interactive elements",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Verify Semantics widgets with correct labels are present
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final labels = semanticsWidgets
          .where((s) => s.properties.label != null)
          .map((s) => s.properties.label)
          .toList();
      expect(labels, contains("Enable Notifications"));
      expect(labels, contains("Not Now"));
    });
  });
}
