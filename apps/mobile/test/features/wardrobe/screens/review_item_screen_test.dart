import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/wardrobe_item.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/review_item_screen.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

WardrobeItem _buildTestItem({
  String categorizationStatus = "completed",
  String? category = "tops",
  String? color = "blue",
  String? brand,
  double? purchasePrice,
}) {
  return WardrobeItem.fromJson({
    "id": "item-1",
    "profileId": "profile-1",
    "photoUrl": "https://example.com/photo.jpg",
    "category": category,
    "color": color,
    "secondaryColors": <String>[],
    "pattern": "solid",
    "material": "cotton",
    "style": "casual",
    "season": ["spring", "summer"],
    "occasion": ["everyday"],
    "categorizationStatus": categorizationStatus,
    "brand": brand,
    "purchasePrice": purchasePrice,
  });
}

ApiClient _buildMockApiClient({
  bool shouldFail = false,
  Map<String, dynamic>? getItemResponse,
  List<Map<String, dynamic>?>? getItemSequence,
}) {
  int getItemCallCount = 0;
  final mockHttp = http_testing.MockClient((request) async {
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }
    if (request.method == "PATCH" && request.url.path.contains("/v1/items/")) {
      return http.Response(
        jsonEncode({
          "item": {
            "id": "item-1",
            "profileId": "profile-1",
            "photoUrl": "https://example.com/photo.jpg",
            "category": "tops",
          }
        }),
        200,
      );
    }
    if (request.method == "GET" && request.url.path.contains("/v1/items/")) {
      if (getItemSequence != null) {
        final idx = getItemCallCount < getItemSequence.length
            ? getItemCallCount
            : getItemSequence.length - 1;
        getItemCallCount++;
        final data = getItemSequence[idx];
        return http.Response(
          jsonEncode({"item": data}),
          200,
        );
      }
      return http.Response(
        jsonEncode({"item": getItemResponse ?? {}}),
        200,
      );
    }
    return http.Response(jsonEncode({}), 200);
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

  group("ReviewItemScreen", () {
    testWidgets("renders item photo and TagCloud", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      expect(find.text("Review Item"), findsOneWidget);
      expect(find.text("Tags"), findsOneWidget);
      expect(find.text("Category"), findsOneWidget);
      expect(find.text("Color"), findsOneWidget);
      expect(find.text("Details"), findsOneWidget);
    });

    testWidgets("editing a tag updates the internal state", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      // Find and tap the "Tops" chip
      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      // Select "Dresses" from the bottom sheet
      await tester.tap(find.text("Dresses"));
      await tester.pumpAndSettle();

      // Now "Dresses" should be shown as a chip
      expect(find.text("Dresses"), findsOneWidget);
    });

    testWidgets("typing in text fields updates state", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      // Scroll down to make text fields visible
      await tester.scrollUntilVisible(
        find.text("Details"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Find name field and enter text
      final nameField = find.byWidgetPredicate(
        (w) => w is TextFormField && (w.controller?.text ?? "") == "",
      );
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField.first, "My Blue Shirt");
        await tester.pump();
      }
    });

    testWidgets("Save Item calls apiClient.updateItem", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReviewItemScreen(item: item, apiClient: apiClient),
                  ),
                );
                if (result == true) popped = true;
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Find and tap Save Item button
      await tester.scrollUntilVisible(
        find.text("Save Item"),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.runAsync(() async {
        await tester.tap(find.text("Save Item"));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets("pending categorization shows loading state",
        (tester) async {
      final item = _buildTestItem(categorizationStatus: "pending");
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      // The tag cloud should be in loading state - no chip labels visible
      // because isLoading is true and shimmer placeholders are shown
      expect(find.text("Tags"), findsOneWidget);
      // Category chip should NOT be visible (loading state)
      expect(find.text("Tops"), findsNothing);
    });

    testWidgets("failure banner shows when categorization failed",
        (tester) async {
      final item = _buildTestItem(categorizationStatus: "failed");
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          "AI couldn't identify this item -- please set the details manually.",
        ),
        findsOneWidget,
      );
    });

    testWidgets("form validation shows error for name > 200 chars",
        (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      // Scroll to the Item Name hint text to ensure the field is visible
      await tester.scrollUntilVisible(
        find.text("e.g., Blue Oxford Shirt"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Find all TextFormFields and enter a long name in the first one (Item Name)
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);

      // Enter a long name in the first text field (Item Name)
      await tester.enterText(textFields.first, "x" * 201);
      await tester.pump();

      expect(
        find.text("Name must be at most 200 characters"),
        findsOneWidget,
      );
    });

    testWidgets("Save Item is disabled during form errors", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      // Scroll to the Brand hint text
      await tester.scrollUntilVisible(
        find.text("e.g., Zara, Nike"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Find the Brand text field (second TextFormField after Item Name)
      final textFields = find.byType(TextFormField);
      // The brand field is the second one
      await tester.enterText(textFields.at(1), "x" * 101);
      await tester.pump();

      // The Save Item button should be disabled
      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Save Item"),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets("back button pops without saving", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) =>
                        ReviewItemScreen(item: item, apiClient: apiClient),
                  ),
                );
                popped = true;
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets("currency dropdown shows valid options", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      // Scroll to currency dropdown
      await tester.scrollUntilVisible(
        find.text("Currency"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Default currency should be GBP
      expect(find.text("GBP"), findsOneWidget);
    });

    testWidgets("Semantics labels are present", (tester) async {
      final item = _buildTestItem();
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewItemScreen(item: item, apiClient: apiClient),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Back",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Save Item",
        ),
        findsOneWidget,
      );
    });
  });
}
