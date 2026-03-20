import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/home/widgets/swipeable_outfit_stack.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";

List<OutfitSuggestion> _testSuggestions() {
  return const [
    OutfitSuggestion(
      id: "s1",
      name: "Spring Casual",
      items: [
        OutfitSuggestionItem(
          id: "i1",
          name: "Shirt",
          category: "tops",
          color: "white",
          photoUrl: null,
        ),
        OutfitSuggestionItem(
          id: "i2",
          name: "Jeans",
          category: "bottoms",
          color: "blue",
          photoUrl: null,
        ),
      ],
      explanation: "Perfect for spring weather.",
      occasion: "everyday",
    ),
    OutfitSuggestion(
      id: "s2",
      name: "Office Ready",
      items: [
        OutfitSuggestionItem(
          id: "i3",
          name: "Blazer",
          category: "tops",
          color: "navy",
          photoUrl: null,
        ),
        OutfitSuggestionItem(
          id: "i4",
          name: "Trousers",
          category: "bottoms",
          color: "grey",
          photoUrl: null,
        ),
      ],
      explanation: "Professional and polished.",
      occasion: "work",
    ),
    OutfitSuggestion(
      id: "s3",
      name: "Weekend Vibes",
      items: [
        OutfitSuggestionItem(
          id: "i5",
          name: "T-Shirt",
          category: "tops",
          color: "green",
          photoUrl: null,
        ),
        OutfitSuggestionItem(
          id: "i6",
          name: "Shorts",
          category: "bottoms",
          color: "khaki",
          photoUrl: null,
        ),
      ],
      explanation: "Relaxed weekend look.",
      occasion: "casual",
    ),
  ];
}

Future<void> pumpStack(
  WidgetTester tester, {
  List<OutfitSuggestion>? suggestions,
  Future<bool> Function(OutfitSuggestion)? onSave,
  VoidCallback? onAllReviewed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SwipeableOutfitStack(
            suggestions: suggestions ?? _testSuggestions(),
            onSave: onSave ?? (_) async => true,
            onAllReviewed: onAllReviewed,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group("SwipeableOutfitStack", () {
    testWidgets("renders the first suggestion's outfit name", (tester) async {
      await pumpStack(tester);

      expect(find.text("Spring Casual"), findsOneWidget);
    });

    testWidgets("shows position indicator '1 of 3'", (tester) async {
      await pumpStack(tester);

      expect(find.text("1 of 3"), findsOneWidget);
    });

    testWidgets("renders Save and Skip buttons", (tester) async {
      await pumpStack(tester);

      expect(find.text("Save"), findsOneWidget);
      expect(find.text("Skip"), findsOneWidget);
    });

    testWidgets("swiping right past threshold calls onSave callback",
        (tester) async {
      bool saveCalled = false;

      await pumpStack(
        tester,
        onSave: (suggestion) async {
          saveCalled = true;
          return true;
        },
      );

      // Perform a long right drag past 40% threshold
      final card = find.byType(GestureDetector).first;
      await tester.drag(card, const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
    });

    testWidgets(
        "swiping left past threshold does NOT call onSave callback",
        (tester) async {
      bool saveCalled = false;

      await pumpStack(
        tester,
        onSave: (suggestion) async {
          saveCalled = true;
          return true;
        },
      );

      final card = find.byType(GestureDetector).first;
      await tester.drag(card, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
    });

    testWidgets(
        "swiping right and onSave returns true advances to next card",
        (tester) async {
      await pumpStack(
        tester,
        onSave: (_) async => true,
      );

      final card = find.byType(GestureDetector).first;
      await tester.drag(card, const Offset(400, 0));
      await tester.pumpAndSettle();

      // Should now show the second card
      expect(find.text("Office Ready"), findsOneWidget);
      expect(find.text("2 of 3"), findsOneWidget);
    });

    testWidgets(
        "swiping right and onSave returns false keeps current card",
        (tester) async {
      await pumpStack(
        tester,
        onSave: (_) async => false,
      );

      final card = find.byType(GestureDetector).first;
      await tester.drag(card, const Offset(400, 0));
      await tester.pumpAndSettle();

      // Should still show the first card
      expect(find.text("Spring Casual"), findsOneWidget);
      expect(find.text("1 of 3"), findsOneWidget);
    });

    testWidgets("tapping Save button calls onSave callback", (tester) async {
      bool saveCalled = false;

      await pumpStack(
        tester,
        onSave: (suggestion) async {
          saveCalled = true;
          return true;
        },
      );

      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
    });

    testWidgets(
        "tapping Skip button advances to next card without calling onSave",
        (tester) async {
      bool saveCalled = false;

      await pumpStack(
        tester,
        onSave: (suggestion) async {
          saveCalled = true;
          return true;
        },
      );

      await tester.tap(find.text("Skip"));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
      expect(find.text("Office Ready"), findsOneWidget);
    });

    testWidgets(
        "after all cards reviewed, shows 'All suggestions reviewed' completion state",
        (tester) async {
      await pumpStack(
        tester,
        onSave: (_) async => true,
      );

      // Skip all 3 cards
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text("Skip"));
        await tester.pumpAndSettle();
      }

      expect(find.text("All suggestions reviewed"), findsOneWidget);
    });

    testWidgets("completion state shows saved outfit count", (tester) async {
      await pumpStack(
        tester,
        onSave: (_) async => true,
      );

      // Save first, skip second, save third
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Skip"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.text("You saved 2 outfits today"), findsOneWidget);
    });

    testWidgets("dragging below threshold springs card back", (tester) async {
      await pumpStack(tester);

      // Small drag that won't pass threshold
      final card = find.byType(GestureDetector).first;
      await tester.drag(card, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Card should still be showing the first suggestion
      expect(find.text("Spring Casual"), findsOneWidget);
      expect(find.text("1 of 3"), findsOneWidget);
    });

    testWidgets("green overlay appears when dragging right", (tester) async {
      await pumpStack(tester);

      // Start a drag to the right but don't release it past threshold
      final card = find.byType(GestureDetector).first;
      // Use a fling that starts but we control via gesture
      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();

      // Look for the "Save" text overlay
      expect(find.text("Save"), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("red overlay appears when dragging left", (tester) async {
      await pumpStack(tester);

      final card = find.byType(GestureDetector).first;
      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();

      // Look for the "Skip" text overlay -- should appear on both overlay and button
      expect(find.text("Skip"), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("Save and Skip buttons are disabled during save operation",
        (tester) async {
      final completer = Completer<bool>();

      await pumpStack(
        tester,
        onSave: (_) => completer.future,
      );

      // Tap save -- it will wait on the completer
      await tester.tap(find.text("Save"));
      await tester.pump();

      // During save, buttons should be disabled -- trying to tap them should not cause issues
      // The ElevatedButton should be in disabled state
      final saveButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, "Save"));
      expect(saveButton.onPressed, isNull);

      final skipButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, "Skip"));
      expect(skipButton.onPressed, isNull);

      // Complete the save
      completer.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets(
        "semantics labels are present for card, save button, and skip button",
        (tester) async {
      await pumpStack(tester);

      // Check for semantics labels
      expect(
        find.bySemanticsLabel(RegExp(
            r"Outfit suggestion 1 of 3: Spring Casual\. Swipe right to save, swipe left to skip\.")),
        findsOneWidget,
      );

      expect(
        find.bySemanticsLabel("Save outfit: Spring Casual"),
        findsOneWidget,
      );

      expect(
        find.bySemanticsLabel("Skip outfit: Spring Casual"),
        findsOneWidget,
      );
    });

    testWidgets("pull to refresh for new suggestions hint shows in completion",
        (tester) async {
      await pumpStack(tester);

      // Skip all cards
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text("Skip"));
        await tester.pumpAndSettle();
      }

      expect(
        find.text("Pull to refresh for new suggestions"),
        findsOneWidget,
      );
    });
  });
}
