import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/profile/widgets/badge_detail_sheet.dart";

void main() {
  final earnedBadge = {
    "key": "first_step",
    "name": "First Step",
    "description": "Upload your first wardrobe item",
    "iconName": "star",
    "iconColor": "#FBBF24",
    "category": "wardrobe",
  };

  testWidgets("Renders badge icon, name, description for earned badge",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BadgeDetailSheet(
          badge: earnedBadge,
          isEarned: true,
          awardedAt: "2026-03-19T10:00:00Z",
        ),
      ),
    ));

    expect(find.text("First Step"), findsOneWidget);
    expect(find.text("Upload your first wardrobe item"), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets("Renders 'Earned on [date]' for earned badge", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BadgeDetailSheet(
          badge: earnedBadge,
          isEarned: true,
          awardedAt: "2026-03-19T10:00:00Z",
        ),
      ),
    ));

    expect(find.text("Earned on 19/3/2026"), findsOneWidget);
  });

  testWidgets("Renders 'Keep going!' message for unearned badge",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BadgeDetailSheet(
          badge: earnedBadge,
          isEarned: false,
        ),
      ),
    ));

    expect(
      find.text("Keep going! Upload your first wardrobe item"),
      findsOneWidget,
    );
  });

  testWidgets("Icon is colored for earned badge, gray for unearned",
      (tester) async {
    // Earned
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BadgeDetailSheet(
          badge: earnedBadge,
          isEarned: true,
          awardedAt: "2026-03-19T10:00:00Z",
        ),
      ),
    ));

    var icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.color, const Color(0xFFFBBF24));

    // Unearned
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BadgeDetailSheet(
          badge: earnedBadge,
          isEarned: false,
        ),
      ),
    ));

    icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.color, const Color(0xFFD1D5DB));
  });

  testWidgets("Semantics labels present", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BadgeDetailSheet(
          badge: earnedBadge,
          isEarned: true,
          awardedAt: "2026-03-19T10:00:00Z",
        ),
      ),
    ));

    expect(
      find.bySemanticsLabel(RegExp(r"Badge detail: First Step")),
      findsOneWidget,
    );
  });
}
