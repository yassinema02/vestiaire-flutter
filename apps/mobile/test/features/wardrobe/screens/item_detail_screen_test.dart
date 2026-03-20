import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/item_detail_screen.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/wardrobe_item.dart";

/// AuthService that returns a test token without requiring Firebase sign-in.
class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

Map<String, dynamic> _sampleItemJson({
  bool isFavorite = false,
  double? purchasePrice,
  int? wearCount,
  String? lastWornDate,
  String? currency,
}) {
  return {
    "id": "item-1",
    "profileId": "profile-1",
    "photoUrl": "https://example.com/photo.jpg",
    "name": "Blue Oxford Shirt",
    "bgRemovalStatus": "completed",
    "category": "tops",
    "color": "blue",
    "secondaryColors": ["white"],
    "pattern": "solid",
    "material": "cotton",
    "style": "casual",
    "season": ["spring", "fall"],
    "occasion": ["everyday", "work"],
    "categorizationStatus": "completed",
    "brand": "Nike",
    "purchasePrice": purchasePrice,
    "purchaseDate": "2025-06-15",
    "currency": currency ?? "GBP",
    "isFavorite": isFavorite,
    "wearCount": wearCount ?? 0,
    "lastWornDate": lastWornDate,
    "createdAt": "2025-06-10T10:00:00.000Z",
    "updatedAt": "2025-06-15T10:00:00.000Z",
  };
}

WardrobeItem _sampleItem({
  bool isFavorite = false,
  double? purchasePrice,
  int wearCount = 0,
  String? lastWornDate,
  String? currency,
}) {
  return WardrobeItem.fromJson(_sampleItemJson(
    isFavorite: isFavorite,
    purchasePrice: purchasePrice,
    wearCount: wearCount,
    lastWornDate: lastWornDate,
    currency: currency,
  ));
}

ApiClient _buildMockApiClient({
  Map<String, dynamic>? getItemResponse,
  bool getItemFails = false,
  bool updateItemFails = false,
  bool deleteItemFails = false,
  List<String>? capturedUpdatePaths,
  List<Map<String, dynamic>>? capturedUpdateBodies,
  List<String>? capturedDeletePaths,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    final path = request.url.path;
    final method = request.method;

    // GET /v1/items/:id
    if (method == "GET" && path.startsWith("/v1/items/")) {
      if (getItemFails) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      return http.Response(
        jsonEncode({"item": getItemResponse ?? _sampleItemJson()}),
        200,
      );
    }

    // PATCH /v1/items/:id
    if (method == "PATCH" && path.startsWith("/v1/items/")) {
      capturedUpdatePaths?.add(path);
      if (request.body.isNotEmpty) {
        capturedUpdateBodies?.add(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
      }
      if (updateItemFails) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      final body = request.body.isNotEmpty
          ? jsonDecode(request.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final updatedItem = {..._sampleItemJson(), ...body};
      return http.Response(
        jsonEncode({"item": updatedItem}),
        200,
      );
    }

    // DELETE /v1/items/:id
    if (method == "DELETE" && path.startsWith("/v1/items/")) {
      capturedDeletePaths?.add(path);
      if (deleteItemFails) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      return http.Response(
        jsonEncode({"deleted": true}),
        200,
      );
    }

    return http.Response(jsonEncode({"code": "NOT_FOUND"}), 404);
  });

  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _TestAuthService(),
    httpClient: mockHttp,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("ItemDetailScreen", () {
    testWidgets("renders item photo, name, and all metadata fields",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Title
      expect(find.text("Blue Oxford Shirt"), findsWidgets);
      // Stats
      expect(find.text("0"), findsOneWidget); // wear count
      expect(find.text("N/A"), findsOneWidget); // CPW
      expect(find.text("Never"), findsOneWidget); // last worn
      // Metadata labels
      expect(find.text("Category"), findsOneWidget);
      expect(find.text("Tops"), findsOneWidget);
      expect(find.text("Color"), findsOneWidget);
      expect(find.text("Blue"), findsOneWidget);
      expect(find.text("Pattern"), findsOneWidget);
      expect(find.text("Solid"), findsOneWidget);
      expect(find.text("Material"), findsOneWidget);
      expect(find.text("Cotton"), findsOneWidget);
      expect(find.text("Brand"), findsOneWidget);
      expect(find.text("Nike"), findsOneWidget);
    });

    testWidgets("stats row shows 0 wears, N/A CPW, Never for new item",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Wears"), findsOneWidget);
      expect(find.text("CPW"), findsOneWidget);
      expect(find.text("Last Worn"), findsOneWidget);
      expect(find.text("0"), findsOneWidget);
      expect(find.text("N/A"), findsOneWidget);
      expect(find.text("Never"), findsOneWidget);
    });

    testWidgets("stats row shows formatted CPW when price and wearCount set",
        (tester) async {
      final apiClient = _buildMockApiClient(
        getItemResponse: _sampleItemJson(
          purchasePrice: 100.0,
          wearCount: 10,
          currency: "GBP",
        ),
      );
      final item = _sampleItem(
        purchasePrice: 100.0,
        wearCount: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // CPW = 100/10 = 10.00, currency GBP -> pound sign
      expect(find.text("\u00a310.00/wear"), findsOneWidget);
    });

    testWidgets("tapping favorite icon calls apiClient.updateItem with toggled isFavorite",
        (tester) async {
      final capturedBodies = <Map<String, dynamic>>[];
      final apiClient = _buildMockApiClient(
        capturedUpdateBodies: capturedBodies,
      );
      final item = _sampleItem(isFavorite: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Tap favorite icon
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(capturedBodies.length, greaterThanOrEqualTo(1));
      expect(capturedBodies.last["isFavorite"], true);
    });

    testWidgets("favorite icon updates optimistically",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem(isFavorite: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Initially unfavorited
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap favorite
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump(); // Just pump once for optimistic update

      // Should immediately show filled heart
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets("tapping Edit in PopupMenu navigates to ReviewItemScreen",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.text("Edit"));
      await tester.pumpAndSettle();

      // Should navigate to ReviewItemScreen
      expect(find.text("Review Item"), findsOneWidget);
    });

    testWidgets("tapping Delete in PopupMenu shows confirmation dialog",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text("Delete Item"), findsOneWidget);
      expect(
        find.text("Delete this item? This action cannot be undone."),
        findsOneWidget,
      );
      expect(find.text("Cancel"), findsOneWidget);
      // "Delete" appears in dialog and as menu text - find specifically in dialog
      expect(find.widgetWithText(TextButton, "Delete"), findsOneWidget);
    });

    testWidgets("confirming delete calls apiClient.deleteItem and pops screen",
        (tester) async {
      final capturedDeletes = <String>[];
      final apiClient = _buildMockApiClient(
        capturedDeletePaths: capturedDeletes,
      );
      final item = _sampleItem();

      // Use a Navigator observer to detect pops
      bool didPop = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(
                      item: item,
                      apiClient: apiClient,
                    ),
                  ),
                );
                if (result == true) didPop = true;
              },
              child: const Text("Go"),
            ),
          ),
        ),
      );

      // Navigate to detail screen
      await tester.tap(find.text("Go"));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.widgetWithText(TextButton, "Delete"));
      await tester.pumpAndSettle();

      // Should have called delete API
      expect(capturedDeletes, isNotEmpty);
      expect(capturedDeletes.first, contains("item-1"));
      // Should have popped back
      expect(didPop, true);
    });

    testWidgets("canceling delete dismisses dialog without calling API",
        (tester) async {
      final capturedDeletes = <String>[];
      final apiClient = _buildMockApiClient(
        capturedDeletePaths: capturedDeletes,
      );
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      // Cancel deletion
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      // API should not have been called
      expect(capturedDeletes, isEmpty);
      // Dialog should be gone, still on detail screen
      expect(find.text("Delete Item"), findsNothing);
      expect(find.text("Blue Oxford Shirt"), findsWidgets);
    });

    testWidgets("Semantics labels are present on interactive elements",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Back button semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Back",
        ),
        findsOneWidget,
      );

      // Favorite semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Add to favorites",
        ),
        findsOneWidget,
      );

      // More options semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "More options",
        ),
        findsOneWidget,
      );
    });

    testWidgets("error state renders when getItem fails",
        (tester) async {
      final apiClient = _buildMockApiClient(getItemFails: true);
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Failed to load item details."), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    // === Story 2.7: Neglect indicator tests ===

    testWidgets("neglect banner is displayed when item has neglectStatus=neglected",
        (tester) async {
      final neglectedJson = {
        ..._sampleItemJson(),
        "neglectStatus": "neglected",
      };
      final apiClient = _buildMockApiClient(getItemResponse: neglectedJson);
      final item = WardrobeItem.fromJson(neglectedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("neglected"),
        findsWidgets,
      );
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "This item is neglected",
        ),
        findsOneWidget,
      );
    });

    testWidgets("neglect banner is NOT displayed when item has neglectStatus=null",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // The neglect banner text should not appear
      expect(
        find.textContaining("consider wearing or decluttering"),
        findsNothing,
      );
    });

    testWidgets("neglect status row in metadata shows Neglected or Active",
        (tester) async {
      // Test with neglected item
      final neglectedJson = {
        ..._sampleItemJson(),
        "neglectStatus": "neglected",
      };
      final apiClient = _buildMockApiClient(getItemResponse: neglectedJson);
      final item = WardrobeItem.fromJson(neglectedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Neglect Status"), findsOneWidget);
      expect(find.text("Neglected"), findsOneWidget);
    });

    testWidgets("neglect status row shows Active for non-neglected item",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Neglect Status"), findsOneWidget);
      expect(find.text("Active"), findsOneWidget);
    });

    testWidgets("taxonomy values are displayed with proper formatting",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Season values formatted and joined
      expect(find.text("Spring, Fall"), findsOneWidget);
      // Occasion values formatted and joined
      expect(find.text("Everyday, Work"), findsOneWidget);
      // Secondary colors formatted
      expect(find.text("White"), findsOneWidget);
    });

    // === Story 7.3: Resale listing integration tests ===

    testWidgets("'Generate Resale Listing' button is visible for items with null resaleStatus",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find the button
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text("Generate Resale Listing"), findsOneWidget);
    });

    testWidgets("'Regenerate Listing' button shown for items with resaleStatus 'listed'",
        (tester) async {
      final listedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "listed",
      };
      final apiClient = _buildMockApiClient(getItemResponse: listedJson);
      final item = WardrobeItem.fromJson(listedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find the button
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text("Regenerate Listing"), findsOneWidget);
      expect(find.text("(already listed)"), findsOneWidget);
    });

    testWidgets("Button hidden for items with resaleStatus 'sold'",
        (tester) async {
      final soldJson = {
        ..._sampleItemJson(),
        "resaleStatus": "sold",
      };
      final apiClient = _buildMockApiClient(getItemResponse: soldJson);
      final item = WardrobeItem.fromJson(soldJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Generate Resale Listing"), findsNothing);
      expect(find.text("Regenerate Listing"), findsNothing);
    });

    testWidgets("Button hidden for items with resaleStatus 'donated'",
        (tester) async {
      final donatedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "donated",
      };
      final apiClient = _buildMockApiClient(getItemResponse: donatedJson);
      final item = WardrobeItem.fromJson(donatedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Generate Resale Listing"), findsNothing);
      expect(find.text("Regenerate Listing"), findsNothing);
    });

    testWidgets("Tapping button navigates to ResaleListingScreen",
        (tester) async {
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll until the resale button is visible
      await tester.scrollUntilVisible(
        find.text("Generate Resale Listing"),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.text("Generate Resale Listing"));
      await tester.pumpAndSettle();

      // Should navigate to ResaleListingScreen
      expect(find.text("Resale Listing"), findsOneWidget);
    });

    // === Story 7.4: Resale status transition tests ===

    testWidgets("'Mark as Sold' button visible for items with resaleStatus 'listed'",
        (tester) async {
      final listedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "listed",
      };
      final apiClient = _buildMockApiClient(getItemResponse: listedJson);
      final item = WardrobeItem.fromJson(listedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find buttons
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text("Mark as Sold"), findsOneWidget);
    });

    testWidgets("'Mark as Donated' button visible for items with resaleStatus 'listed' or null",
        (tester) async {
      // Test with null resaleStatus
      final apiClient = _buildMockApiClient();
      final item = _sampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text("Mark as Donated"), findsOneWidget);
    });

    testWidgets("Buttons hidden for items with resaleStatus 'sold'",
        (tester) async {
      final soldJson = {
        ..._sampleItemJson(),
        "resaleStatus": "sold",
      };
      final apiClient = _buildMockApiClient(getItemResponse: soldJson);
      final item = WardrobeItem.fromJson(soldJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Mark as Sold"), findsNothing);
      expect(find.text("Mark as Donated"), findsNothing);
      expect(find.text("Generate Resale Listing"), findsNothing);
      expect(find.text("Regenerate Listing"), findsNothing);
    });

    testWidgets("Buttons hidden for items with resaleStatus 'donated'",
        (tester) async {
      final donatedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "donated",
      };
      final apiClient = _buildMockApiClient(getItemResponse: donatedJson);
      final item = WardrobeItem.fromJson(donatedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Mark as Sold"), findsNothing);
      expect(find.text("Mark as Donated"), findsNothing);
      expect(find.text("Generate Resale Listing"), findsNothing);
    });

    testWidgets("'Sold' badge shown for sold items",
        (tester) async {
      final soldJson = {
        ..._sampleItemJson(),
        "resaleStatus": "sold",
      };
      final apiClient = _buildMockApiClient(getItemResponse: soldJson);
      final item = WardrobeItem.fromJson(soldJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text("Sold"), findsOneWidget);
    });

    testWidgets("'Donated' badge shown for donated items",
        (tester) async {
      final donatedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "donated",
      };
      final apiClient = _buildMockApiClient(getItemResponse: donatedJson);
      final item = WardrobeItem.fromJson(donatedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text("Donated"), findsOneWidget);
    });

    testWidgets("Tapping 'Mark as Sold' shows bottom sheet with price field",
        (tester) async {
      final listedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "listed",
      };
      final apiClient = _buildMockApiClient(getItemResponse: listedJson);
      final item = WardrobeItem.fromJson(listedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find the button
      await tester.scrollUntilVisible(
        find.text("Mark as Sold"),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Mark as Sold"));
      await tester.pumpAndSettle();

      expect(find.text("Mark Item as Sold"), findsOneWidget);
      expect(find.text("Sale Price"), findsOneWidget);
      expect(find.text("Confirm Sale"), findsOneWidget);
    });

    testWidgets("Tapping 'Mark as Donated' shows confirmation dialog",
        (tester) async {
      final listedJson = {
        ..._sampleItemJson(),
        "resaleStatus": "listed",
      };
      final apiClient = _buildMockApiClient(getItemResponse: listedJson);
      final item = WardrobeItem.fromJson(listedJson);

      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find the button
      await tester.scrollUntilVisible(
        find.text("Mark as Donated"),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Mark as Donated"));
      await tester.pumpAndSettle();

      expect(find.text("Donate Item"), findsOneWidget);
      expect(find.text("Mark this item as donated? This cannot be undone."), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Donate"), findsOneWidget);
    });
  });
}
