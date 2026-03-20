import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/badge_awarded_modal.dart";

void main() {
  testWidgets("Renders badge icon, 'Badge Earned!' text, name, description",
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BadgeAwardedModal(
          name: "First Step",
          description: "Upload your first wardrobe item",
          iconName: "star",
          iconColor: "#FBBF24",
        ),
      ),
    ));

    expect(find.text("Badge Earned!"), findsOneWidget);
    expect(find.text("First Step"), findsOneWidget);
    expect(find.text("Upload your first wardrobe item"), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets("Renders 'Continue' button", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BadgeAwardedModal(
          name: "First Step",
          description: "Upload your first wardrobe item",
          iconName: "star",
          iconColor: "#FBBF24",
        ),
      ),
    ));

    expect(find.text("Continue"), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets("Tapping 'Continue' dismisses dialog", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const BadgeAwardedModal(
                  name: "First Step",
                  description: "Upload your first wardrobe item",
                  iconName: "star",
                  iconColor: "#FBBF24",
                ),
              );
            },
            child: const Text("Show"),
          ),
        ),
      ),
    ));

    // Open dialog
    await tester.tap(find.text("Show"));
    await tester.pumpAndSettle();
    expect(find.text("Badge Earned!"), findsOneWidget);

    // Tap Continue to dismiss
    await tester.tap(find.text("Continue"));
    await tester.pumpAndSettle();
    expect(find.text("Badge Earned!"), findsNothing);
  });

  testWidgets("Semantics label present", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BadgeAwardedModal(
          name: "First Step",
          description: "Upload your first wardrobe item",
          iconName: "star",
          iconColor: "#FBBF24",
        ),
      ),
    ));

    expect(
      find.bySemanticsLabel(RegExp(r"Badge earned: First Step")),
      findsOneWidget,
    );
  });

  testWidgets("showBadgeAwardedModals shows modals sequentially for multiple badges",
      (tester) async {
    final badges = [
      {"name": "First Step", "description": "Upload first item", "iconName": "star", "iconColor": "#FBBF24"},
      {"name": "Week Warrior", "description": "7-day streak", "iconName": "local_fire_department", "iconColor": "#F97316"},
    ];

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showBadgeAwardedModals(context, badges);
            },
            child: const Text("Trigger"),
          ),
        ),
      ),
    ));

    // Trigger the modals
    await tester.tap(find.text("Trigger"));
    await tester.pumpAndSettle();

    // First badge modal should be visible
    expect(find.text("First Step"), findsOneWidget);
    expect(find.text("Week Warrior"), findsNothing);

    // Dismiss first modal
    await tester.tap(find.text("Continue"));
    await tester.pumpAndSettle();

    // Second badge modal should now be visible
    expect(find.text("Week Warrior"), findsOneWidget);

    // Dismiss second
    await tester.tap(find.text("Continue"));
    await tester.pumpAndSettle();

    expect(find.text("Badge Earned!"), findsNothing);
  });
}
