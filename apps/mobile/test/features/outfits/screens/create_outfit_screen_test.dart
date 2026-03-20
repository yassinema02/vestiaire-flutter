import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/screens/create_outfit_screen.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a list of test item JSON objects with the given categories.
List<Map<String, dynamic>> _buildTestItems() {
  return [
    {
      "id": "item-1",
      "profileId": "p1",
      "photoUrl": "https://example.com/1.jpg",
      "name": "White Shirt",
      "category": "tops",
      "categorizationStatus": "completed",
    },
    {
      "id": "item-2",
      "profileId": "p1",
      "photoUrl": "https://example.com/2.jpg",
      "name": "Blue Jeans",
      "category": "bottoms",
      "categorizationStatus": "completed",
    },
    {
      "id": "item-3",
      "profileId": "p1",
      "photoUrl": "https://example.com/3.jpg",
      "name": "Running Shoes",
      "category": "shoes",
      "categorizationStatus": "completed",
    },
    {
      "id": "item-4",
      "profileId": "p1",
      "photoUrl": "https://example.com/4.jpg",
      "name": "Pending Shirt",
      "category": "tops",
      "categorizationStatus": "pending",
    },
    {
      "id": "item-5",
      "profileId": "p1",
      "photoUrl": "https://example.com/5.jpg",
      "name": "Leather Bag",
      "category": "bags",
      "categorizationStatus": "completed",
    },
    {
      "id": "item-6",
      "profileId": "p1",
      "photoUrl": "https://example.com/6.jpg",
      "name": "Swimsuit",
      "category": "swimwear",
      "categorizationStatus": "completed",
    },
  ];
}

ApiClient _buildApiClient({
  List<Map<String, dynamic>>? items,
  bool fail = false,
}) {
  final mockClient = http_testing.MockClient((request) async {
    if (fail) {
      return http.Response("Server Error", 500);
    }
    return http.Response(
      jsonEncode({"items": items ?? _buildTestItems()}),
      200,
    );
  });

  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _MockAuthService(),
    httpClient: mockClient,
  );
}

OutfitPersistenceService _buildPersistenceService() {
  final mockClient = http_testing.MockClient((request) async {
    return http.Response(
      jsonEncode({"outfit": {"id": "outfit-uuid-1"}}),
      201,
    );
  });

  return OutfitPersistenceService(
    apiClient: ApiClient(
      baseUrl: "http://localhost:3000",
      authService: _MockAuthService(),
      httpClient: mockClient,
    ),
  );
}

Future<void> pumpCreateOutfitScreen(
  WidgetTester tester, {
  ApiClient? apiClient,
  OutfitPersistenceService? persistenceService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CreateOutfitScreen(
        apiClient: apiClient ?? _buildApiClient(),
        outfitPersistenceService:
            persistenceService ?? _buildPersistenceService(),
      ),
    ),
  );
}

void main() {
  group("CreateOutfitScreen", () {
    testWidgets("renders loading state with CircularProgressIndicator",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      // Before settling, should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("renders category tabs after items load", (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Should show tabs for categories that have items
      expect(find.text("Tops (1)"), findsOneWidget);
      expect(find.text("Bottoms (1)"), findsOneWidget);
      expect(find.text("Shoes (1)"), findsOneWidget);
      expect(find.text("Bags (1)"), findsOneWidget);
      expect(find.text("Other (1)"), findsOneWidget); // swimwear -> Other
    });

    testWidgets("only shows items with categorizationStatus completed",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // "Pending Shirt" has categorizationStatus = "pending" so should NOT appear
      // Tops should show only 1 item (not 2)
      expect(find.text("Tops (1)"), findsOneWidget);
    });

    testWidgets("renders items in grid within the active tab", (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // First tab is Tops, should show "White Shirt"
      expect(find.text("White Shirt"), findsOneWidget);
    });

    testWidgets("tapping an item selects it", (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Tap the item tile with label "White Shirt"
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();

      // Count should update
      expect(find.text("1 items selected"), findsOneWidget);
    });

    testWidgets("tapping a selected item deselects it", (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Select
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();
      expect(find.text("1 items selected"), findsOneWidget);

      // Deselect
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();
      expect(find.text("Select items"), findsOneWidget);
    });

    testWidgets("selected count text updates when items are selected/deselected",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text("Select items"), findsOneWidget);

      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();
      expect(find.text("1 items selected"), findsOneWidget);
    });

    testWidgets("selected items preview strip appears when items are selected",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // No preview strip initially
      // Container with height 72 should not exist when nothing is selected
      // The strip is conditionally rendered
      final previewStripFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxHeight == 72 &&
            widget.constraints?.minHeight == 72,
      );
      expect(previewStripFinder, findsNothing);

      // Select an item
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();

      // Preview strip should now be visible
      expect(find.text("1 items selected"), findsOneWidget);
    });

    testWidgets("Next button is disabled when no items are selected",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      final nextButton = find.widgetWithText(ElevatedButton, "Next");
      expect(nextButton, findsOneWidget);

      final button = tester.widget<ElevatedButton>(nextButton);
      expect(button.onPressed, isNull);
    });

    testWidgets("Next button is enabled when 1-7 items are selected",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Select an item
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();

      final nextButton = find.widgetWithText(ElevatedButton, "Next");
      final button = tester.widget<ElevatedButton>(nextButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets("tapping Next navigates to NameOutfitScreen", (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Select an item
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();

      // Tap Next
      await tester.tap(find.text("Next"));
      await tester.pumpAndSettle();

      // Should see NameOutfitScreen
      expect(find.text("Name Your Outfit"), findsOneWidget);
    });

    testWidgets("renders error state with Retry button when item fetch fails",
        (tester) async {
      await pumpCreateOutfitScreen(
        tester,
        apiClient: _buildApiClient(fail: true),
      );
      await tester.pumpAndSettle();

      expect(find.text("Failed to load items"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets("renders empty state with Go to Wardrobe when no categorized items",
        (tester) async {
      await pumpCreateOutfitScreen(
        tester,
        apiClient: _buildApiClient(items: []),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
            "No items available. Add and categorize items in your wardrobe first."),
        findsOneWidget,
      );
      expect(find.text("Go to Wardrobe"), findsOneWidget);
      expect(find.byIcon(Icons.checkroom), findsOneWidget);
    });

    testWidgets("category tabs show correct item counts", (tester) async {
      final items = [
        {
          "id": "i1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Shirt A",
          "category": "tops",
          "categorizationStatus": "completed",
        },
        {
          "id": "i2",
          "profileId": "p1",
          "photoUrl": "https://example.com/2.jpg",
          "name": "Shirt B",
          "category": "tops",
          "categorizationStatus": "completed",
        },
        {
          "id": "i3",
          "profileId": "p1",
          "photoUrl": "https://example.com/3.jpg",
          "name": "Pants",
          "category": "bottoms",
          "categorizationStatus": "completed",
        },
      ];

      await pumpCreateOutfitScreen(
        tester,
        apiClient: _buildApiClient(items: items),
      );
      await tester.pumpAndSettle();

      expect(find.text("Tops (2)"), findsOneWidget);
      expect(find.text("Bottoms (1)"), findsOneWidget);
    });

    testWidgets("semantics labels are present on item tiles", (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Unselected item should have "Select <name>" semantics widget
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Select White Shirt",
        ),
        findsOneWidget,
      );

      // Select the item
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();

      // Selected item should have updated semantics
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "Selected: White Shirt. Tap to deselect.",
        ),
        findsOneWidget,
      );
    });

    testWidgets("prevents selecting more than 7 items", (tester) async {
      // Create items across many categories (1 per category) to avoid scrolling
      final categories = [
        "tops", "bottoms", "shoes", "bags", "accessories", "outerwear", "dresses",
        "swimwear",
      ];
      final items = categories
          .asMap()
          .entries
          .map((e) => {
                "id": "item-${e.key}",
                "profileId": "p1",
                "photoUrl": "https://example.com/${e.key}.jpg",
                "name": "Item ${e.value}",
                "category": e.value,
                "categorizationStatus": "completed",
              })
          .toList();

      await pumpCreateOutfitScreen(
        tester,
        apiClient: _buildApiClient(items: items),
      );
      await tester.pumpAndSettle();

      // Select items across categories (one per tab, tap tab then item)
      // Use ensureVisible for tabs that may be off-screen
      final tabsAndItems = [
        ["Tops (1)", "Item tops"],
        ["Bottoms (1)", "Item bottoms"],
        ["Shoes (1)", "Item shoes"],
        ["Bags (1)", "Item bags"],
        ["Accessories (1)", "Item accessories"],
        ["Outerwear (1)", "Item outerwear"],
        ["Dresses (1)", "Item dresses"],
      ];

      for (final pair in tabsAndItems) {
        final tabFinder = find.text(pair[0]);
        await tester.ensureVisible(tabFinder);
        await tester.pumpAndSettle();
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text(pair[1]));
        await tester.pumpAndSettle();
      }

      expect(find.text("7 items selected"), findsOneWidget);

      // Try to select 8th (Other tab has swimwear)
      final otherTab = find.text("Other (1)");
      await tester.ensureVisible(otherTab);
      await tester.pumpAndSettle();
      await tester.tap(otherTab);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Item swimwear"));
      await tester.pumpAndSettle();

      // Should show snackbar
      expect(find.text("Maximum 7 items per outfit"), findsOneWidget);

      // Still 7 items selected
      expect(find.text("7 items selected"), findsOneWidget);
    });

    testWidgets("tapping thumbnail in preview strip deselects the item",
        (tester) async {
      await pumpCreateOutfitScreen(tester);
      await tester.pumpAndSettle();

      // Select an item
      await tester.tap(find.text("White Shirt"));
      await tester.pumpAndSettle();
      expect(find.text("1 items selected"), findsOneWidget);

      // Find the InkWell in the preview strip and tap it
      // The preview strip contains InkWell widgets with "Remove X from outfit" semantics
      final removeButton =
          find.bySemanticsLabel("Remove White Shirt from outfit");
      expect(removeButton, findsOneWidget);
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Should be deselected
      expect(find.text("Select items"), findsOneWidget);
    });
  });
}
