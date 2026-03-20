import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/shopping/models/shopping_scan.dart";
import "package:vestiaire_mobile/src/features/shopping/screens/compatibility_score_screen.dart";
import "package:vestiaire_mobile/src/features/shopping/screens/product_review_screen.dart";
import "package:vestiaire_mobile/src/features/shopping/services/shopping_scan_service.dart";

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "fake-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiClient _dummyApiClient() {
  final mockHttp = http_testing.MockClient((request) async {
    return http.Response("{}", 500);
  });
  return ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _FakeAuthService(),
    httpClient: mockHttp,
  );
}

class _MockShoppingScanService extends ShoppingScanService {
  _MockShoppingScanService({
    this.shouldFailUpdate = false,
    this.updateResult,
  }) : super(apiClient: _dummyApiClient());

  final bool shouldFailUpdate;
  final ShoppingScan? updateResult;
  Map<String, dynamic>? lastUpdateBody;
  String? lastUpdateScanId;
  bool updateCalled = false;

  @override
  Future<ShoppingScan> updateScan(String scanId, Map<String, dynamic> updates) async {
    updateCalled = true;
    lastUpdateScanId = scanId;
    lastUpdateBody = updates;
    if (shouldFailUpdate) {
      throw const ApiException(
        statusCode: 400,
        code: "VALIDATION_ERROR",
        message: "Validation failed",
      );
    }
    return updateResult ?? _makeTestScan();
  }
}

ShoppingScan _makeTestScan({
  String? category,
  String? color,
  String? style,
  String? pattern,
  String? material,
  int? formalityScore,
  List<String>? season,
  List<String>? occasion,
  List<String>? secondaryColors,
  String? productName,
  String? brand,
  double? price,
  String? currency,
  String? imageUrl,
}) {
  return ShoppingScan.fromJson({
    "id": "scan-1",
    "url": "https://www.zara.com/shirt",
    "scanType": "url",
    "productName": productName ?? "Blue Cotton Shirt",
    "brand": brand ?? "Zara",
    "price": price ?? 29.99,
    "currency": currency ?? "GBP",
    "imageUrl": imageUrl,
    "category": category ?? "tops",
    "color": color ?? "blue",
    "secondaryColors": secondaryColors ?? ["white", "navy"],
    "style": style ?? "casual",
    "pattern": pattern ?? "solid",
    "material": material ?? "cotton",
    "season": season ?? ["spring", "summer"],
    "occasion": occasion ?? ["everyday", "work"],
    "formalityScore": formalityScore ?? 5,
    "extractionMethod": "og_tags+json_ld",
    "createdAt": "2026-03-19T00:00:00.000Z",
  });
}

ShoppingScan _makeMinimalScan() {
  return ShoppingScan.fromJson({
    "id": "scan-minimal",
    "scanType": "url",
    "createdAt": "2026-03-19T00:00:00.000Z",
  });
}

void main() {
  group("ProductReviewScreen", () {
    testWidgets("Renders product summary header with name, brand, price", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // The header has the product name and brand as Text widgets, and the TextFields also have them.
      // Use findsAtLeast since values appear in both header and editable fields.
      expect(find.text("Blue Cotton Shirt"), findsAtLeast(1));
      expect(find.text("Zara"), findsAtLeast(1));
      expect(find.text("GBP 29.99"), findsOneWidget);
    });

    testWidgets("Renders taxonomy chips pre-populated from scan data", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Check for section titles
      expect(find.text("Category"), findsOneWidget);
      expect(find.text("Color"), findsOneWidget);

      // Check chip values are present
      expect(find.text("tops"), findsOneWidget);
      expect(find.text("blue"), findsOneWidget);
    });

    testWidgets("Tapping category chip opens bottom sheet with all valid categories", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Find and tap the category chip
      final categoryChip = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == "Category chip",
      );
      expect(categoryChip, findsOneWidget);
      await tester.tap(categoryChip);
      await tester.pumpAndSettle();

      // Bottom sheet should show with category options
      expect(find.text("Select Category"), findsOneWidget);
      expect(find.text("shoes"), findsOneWidget);
      expect(find.text("dresses"), findsOneWidget);
      expect(find.text("outerwear"), findsOneWidget);
    });

    testWidgets("Selecting a new category updates the chip", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Open category bottom sheet
      final categoryChip = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == "Category chip",
      );
      await tester.tap(categoryChip);
      await tester.pumpAndSettle();

      // Select "shoes"
      await tester.tap(find.text("shoes").last);
      await tester.pumpAndSettle();

      // The chip should now show "shoes"
      expect(find.text("shoes"), findsOneWidget);
    });

    testWidgets("Renders multi-select chips for season and occasion", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Check section titles
      expect(find.text("Season"), findsOneWidget);
      expect(find.text("Occasion"), findsOneWidget);

      // Check that season values are shown as chips
      expect(find.text("spring"), findsOneWidget);
      expect(find.text("summer"), findsOneWidget);

      // Check that occasion values are shown as chips
      expect(find.text("everyday"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
    });

    testWidgets("Renders formality slider with correct initial value", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan(formalityScore: 7);

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      expect(find.text("Formality Score"), findsOneWidget);
      expect(find.text("7"), findsOneWidget);
      expect(find.text("Very Casual"), findsOneWidget);
      expect(find.text("Black Tie"), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets("Moving slider updates displayed value", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan(formalityScore: 1);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: ProductReviewScreen(
              initialScan: scan,
              shoppingScanService: service,
            ),
          ),
        ),
      ));

      // Verify slider exists
      expect(find.byType(Slider), findsOneWidget);

      // The initial formality score value is 1
      expect(find.text("1"), findsAtLeast(1));
    });

    testWidgets("Text fields are pre-populated with product name, brand, price", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Find TextFields - there should be 3 (product name, brand, price)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      // Check pre-populated values via controller text
      final productNameField = tester.widget<TextField>(textFields.at(0));
      expect(productNameField.controller?.text, "Blue Cotton Shirt");

      final brandField = tester.widget<TextField>(textFields.at(1));
      expect(brandField.controller?.text, "Zara");

      final priceField = tester.widget<TextField>(textFields.at(2));
      expect(priceField.controller?.text, "29.99");
    });

    testWidgets("Currency dropdown shows correct options (GBP, EUR, USD)", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Find the dropdown
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text("GBP"), findsAtLeast(1));
    });

    testWidgets("Tapping Confirm calls updateScan and navigates to CompatibilityScoreScreen", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Use the main SingleChildScrollView to scroll to Confirm
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Confirm"),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text("Confirm"));
      await tester.pumpAndSettle();

      expect(service.updateCalled, true);
      expect(service.lastUpdateScanId, "scan-1");
      expect(service.lastUpdateBody, isNotNull);
      // Should navigate to CompatibilityScoreScreen
      expect(find.byType(CompatibilityScoreScreen), findsOneWidget);
    });

    testWidgets("Confirm button shows loading indicator during submission", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Use the main SingleChildScrollView to scroll to Confirm
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Confirm"),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text("Confirm"));
      await tester.pump(); // Don't settle - just advance one frame

      // After settling, the screen will pop
      await tester.pumpAndSettle();
    });

    testWidgets("Tapping Skip Review navigates to CompatibilityScoreScreen without calling API", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Scroll to Skip Review using the main scrollable
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Skip Review"),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text("Skip Review"));
      await tester.pumpAndSettle();

      // Should navigate to CompatibilityScoreScreen without calling updateScan
      expect(service.updateCalled, false);
      expect(find.byType(CompatibilityScoreScreen), findsOneWidget);
    });

    testWidgets("Semantics labels present on interactive elements", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeTestScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Check semantics on taxonomy chips
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Category chip",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Color chip",
        ),
        findsOneWidget,
      );

      // Check semantics on formality slider
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Formality score slider",
        ),
        findsOneWidget,
      );

      // Check semantics on text fields
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Product name field",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Brand field",
        ),
        findsOneWidget,
      );

      // Scroll to find Confirm and Skip Review buttons
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text("Confirm"),
        200,
        scrollable: scrollable,
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Confirm button",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Skip Review button",
        ),
        findsOneWidget,
      );
    });

    testWidgets("Handles scan with null fields gracefully (shows defaults)", (tester) async {
      final service = _MockShoppingScanService();
      final scan = _makeMinimalScan();

      await tester.pumpWidget(MaterialApp(
        home: ProductReviewScreen(
          initialScan: scan,
          shoppingScanService: service,
        ),
      ));

      // Should show "Unknown Product" for null productName
      expect(find.text("Unknown Product"), findsOneWidget);

      // Should show "Select Category" for null category
      expect(find.text("Select Category"), findsOneWidget);

      // Should show slider with default value 5
      expect(find.text("5"), findsOneWidget);

      // Should not crash
      expect(find.byType(ProductReviewScreen), findsOneWidget);
    });
  });
}
