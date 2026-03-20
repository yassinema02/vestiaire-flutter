import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/outfits/screens/name_outfit_screen.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/wardrobe_item.dart";

List<WardrobeItem> _testItems() {
  return [
    const WardrobeItem(
      id: "item-1",
      profileId: "p1",
      photoUrl: "https://example.com/1.jpg",
      name: "White Shirt",
      category: "tops",
    ),
    const WardrobeItem(
      id: "item-2",
      profileId: "p1",
      photoUrl: "https://example.com/2.jpg",
      name: "Blue Jeans",
      category: "bottoms",
    ),
  ];
}

class _MockOutfitPersistenceService implements OutfitPersistenceService {
  bool shouldSucceed = true;
  int saveManualCallCount = 0;
  String? lastSavedName;
  String? lastSavedOccasion;
  List<Map<String, dynamic>>? lastSavedItems;

  @override
  Future<Map<String, dynamic>?> saveManualOutfit({
    required String name,
    String? occasion,
    required List<Map<String, dynamic>> items,
  }) async {
    saveManualCallCount++;
    lastSavedName = name;
    lastSavedOccasion = occasion;
    lastSavedItems = items;
    if (!shouldSucceed) return null;
    return {"outfit": {"id": "outfit-uuid-1", "name": name}};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A mock service that uses a Completer so we can control when it resolves.
class _SlowOutfitPersistenceService implements OutfitPersistenceService {
  final Completer<Map<String, dynamic>?> completer = Completer<Map<String, dynamic>?>();

  @override
  Future<Map<String, dynamic>?> saveManualOutfit({
    required String name,
    String? occasion,
    required List<Map<String, dynamic>> items,
  }) {
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> pumpNameOutfitScreen(
  WidgetTester tester, {
  List<WardrobeItem>? items,
  OutfitPersistenceService? persistenceService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NameOutfitScreen(
        selectedItems: items ?? _testItems(),
        outfitPersistenceService:
            persistenceService ?? _MockOutfitPersistenceService(),
      ),
    ),
  );
}

void main() {
  group("NameOutfitScreen", () {
    testWidgets("renders selected items preview", (tester) async {
      await pumpNameOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Should show item labels
      expect(find.text("White Shirt"), findsOneWidget);
      expect(find.text("Blue Jeans"), findsOneWidget);
    });

    testWidgets("renders outfit name text field with My Outfit hint",
        (tester) async {
      await pumpNameOutfitScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text("Outfit Name"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // Hint text
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration!.hintText, "My Outfit");
    });

    testWidgets("renders occasion dropdown with valid occasions",
        (tester) async {
      await pumpNameOutfitScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text("Occasion"), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets("name field accepts text input", (tester) async {
      await pumpNameOutfitScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "My Summer Look");
      await tester.pumpAndSettle();

      expect(find.text("My Summer Look"), findsOneWidget);
    });

    testWidgets("tapping Save Outfit calls saveManualOutfit with correct parameters",
        (tester) async {
      final mockService = _MockOutfitPersistenceService();

      await pumpNameOutfitScreen(tester, persistenceService: mockService);
      await tester.pumpAndSettle();

      // Enter a name
      await tester.enterText(find.byType(TextField), "Weekend Vibes");
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text("Save Outfit"));
      await tester.pumpAndSettle();

      expect(mockService.saveManualCallCount, 1);
      expect(mockService.lastSavedName, "Weekend Vibes");
      expect(mockService.lastSavedItems!.length, 2);
      expect(mockService.lastSavedItems![0]["itemId"], "item-1");
      expect(mockService.lastSavedItems![0]["position"], 0);
      expect(mockService.lastSavedItems![1]["itemId"], "item-2");
      expect(mockService.lastSavedItems![1]["position"], 1);
    });

    testWidgets("uses default name My Outfit when name field is empty",
        (tester) async {
      final mockService = _MockOutfitPersistenceService();

      await pumpNameOutfitScreen(tester, persistenceService: mockService);
      await tester.pumpAndSettle();

      // Don't enter any name, tap Save
      await tester.tap(find.text("Save Outfit"));
      await tester.pumpAndSettle();

      expect(mockService.lastSavedName, "My Outfit");
    });

    testWidgets("uses entered name when name field has text", (tester) async {
      final mockService = _MockOutfitPersistenceService();

      await pumpNameOutfitScreen(tester, persistenceService: mockService);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "Custom Name");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save Outfit"));
      await tester.pumpAndSettle();

      expect(mockService.lastSavedName, "Custom Name");
    });

    testWidgets("passes selected occasion to save call", (tester) async {
      final mockService = _MockOutfitPersistenceService();

      await pumpNameOutfitScreen(tester, persistenceService: mockService);
      await tester.pumpAndSettle();

      // Open dropdown and select an occasion
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Work").last);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save Outfit"));
      await tester.pumpAndSettle();

      expect(mockService.lastSavedOccasion, "work");
    });

    testWidgets("on save success, pops screen with true result",
        (tester) async {
      final mockService = _MockOutfitPersistenceService();

      // Wrap in a navigator so pop works
      bool? popResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NameOutfitScreen(
                        selectedItems: _testItems(),
                        outfitPersistenceService: mockService,
                      ),
                    ),
                  );
                  popResult = result;
                },
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to NameOutfitScreen
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save Outfit"));
      await tester.pumpAndSettle();

      // Screen should have popped with true
      expect(popResult, isTrue);
      // Snackbar should be visible (shown before pop)
      expect(find.text("Outfit created!"), findsOneWidget);
    });

    testWidgets("on save failure, shows error snackbar and re-enables button",
        (tester) async {
      final mockService = _MockOutfitPersistenceService()..shouldSucceed = false;

      await pumpNameOutfitScreen(tester, persistenceService: mockService);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save Outfit"));
      await tester.pumpAndSettle();

      expect(
        find.text("Failed to create outfit. Please try again."),
        findsOneWidget,
      );

      // Button should be re-enabled (shows "Save Outfit" text, not spinner)
      expect(find.text("Save Outfit"), findsOneWidget);
    });

    testWidgets("Save Outfit button shows loading spinner during save",
        (tester) async {
      final slowService = _SlowOutfitPersistenceService();

      await pumpNameOutfitScreen(tester, persistenceService: slowService);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save Outfit"));
      await tester.pump(); // Just pump once to see the loading state

      // Should show spinner
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Save text should be gone
      expect(find.text("Save Outfit"), findsNothing);

      // Complete the future to avoid pending timer issues
      slowService.completer.complete({"outfit": {"id": "outfit-uuid-1"}});
      await tester.pumpAndSettle();
    });

    testWidgets("Save Outfit button is disabled during save", (tester) async {
      final slowService = _SlowOutfitPersistenceService();

      await pumpNameOutfitScreen(tester, persistenceService: slowService);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Save Outfit"));
      await tester.pump();

      // Button should be disabled
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);

      // Complete the future to avoid pending timer issues
      slowService.completer.complete({"outfit": {"id": "outfit-uuid-1"}});
      await tester.pumpAndSettle();
    });

    testWidgets("semantics labels are present on name field, dropdown, and save button",
        (tester) async {
      await pumpNameOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Check Semantics widgets exist with correct labels
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Outfit name input",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Select occasion for this outfit",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Save outfit",
        ),
        findsOneWidget,
      );
    });
  });
}
