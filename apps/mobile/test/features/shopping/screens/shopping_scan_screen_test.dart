import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:image_picker/image_picker.dart";
import "package:purchases_flutter/purchases_flutter.dart";
import "package:purchases_ui_flutter/purchases_ui_flutter.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/core/subscription/subscription_service.dart";
import "package:vestiaire_mobile/src/core/widgets/premium_gate_card.dart";
import "package:vestiaire_mobile/src/features/shopping/models/shopping_scan.dart";
import "package:vestiaire_mobile/src/features/shopping/screens/shopping_scan_screen.dart";
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

/// A mock ApiClient that avoids real file I/O.
/// Overrides getSignedUploadUrl and uploadImage to be synchronous.
class _MockApiClient extends ApiClient {
  _MockApiClient() : super(
    baseUrl: "http://localhost:8080",
    authService: _FakeAuthService(),
  );

  String? lastUploadPurpose;
  String? lastUploadedFilePath;
  String? lastUploadUrl;

  @override
  Future<Map<String, dynamic>> getSignedUploadUrl({
    required String purpose,
    String contentType = "image/jpeg",
  }) async {
    lastUploadPurpose = purpose;
    return {
      "uploadUrl": "https://storage.example.com/mock-upload",
      "publicUrl": "https://storage.example.com/public/screenshot.jpg",
    };
  }

  @override
  Future<void> uploadImage(String filePath, String uploadUrl) async {
    lastUploadedFilePath = filePath;
    lastUploadUrl = uploadUrl;
    // No-op: skip real file I/O
  }
}

class _MockShoppingScanService extends ShoppingScanService {
  _MockShoppingScanService({
    this.result,
    this.shouldThrowRateLimit = false,
    this.shouldThrowExtractionError = false,
    this.shouldThrowScreenshotRateLimit = false,
    this.shouldThrowScreenshotExtractionError = false,
    this.completer,
  }) : super(apiClient: _dummyApiClient());

  final ShoppingScan? result;
  final bool shouldThrowRateLimit;
  final bool shouldThrowExtractionError;
  final bool shouldThrowScreenshotRateLimit;
  final bool shouldThrowScreenshotExtractionError;
  final Completer<void>? completer;

  @override
  Future<ShoppingScan> scanUrl(String url) async {
    if (completer != null) {
      await completer!.future;
    }
    if (shouldThrowRateLimit) {
      throw const ApiException(
        statusCode: 429,
        code: "RATE_LIMIT_EXCEEDED",
        message: "Free tier limit: 3 shopping scans per day",
      );
    }
    if (shouldThrowExtractionError) {
      throw const ApiException(
        statusCode: 422,
        code: "EXTRACTION_FAILED",
        message: "Unable to extract product information from this URL. Try uploading a screenshot instead.",
      );
    }
    return result!;
  }

  @override
  Future<ShoppingScan> scanScreenshot(String imageUrl) async {
    if (shouldThrowScreenshotRateLimit) {
      throw const ApiException(
        statusCode: 429,
        code: "RATE_LIMIT_EXCEEDED",
        message: "Free tier limit: 3 shopping scans per day",
      );
    }
    if (shouldThrowScreenshotExtractionError) {
      throw const ApiException(
        statusCode: 422,
        code: "EXTRACTION_FAILED",
        message: "Unable to identify clothing in this image. Try a clearer photo or paste a product URL instead.",
      );
    }
    return result!;
  }
}

class _FakeSubscriptionService extends SubscriptionService {
  _FakeSubscriptionService() : super(apiKey: "mock_key");

  bool paywallPresented = false;

  @override
  Future<void> configure({String? appUserId}) async {}

  @override
  Future<CustomerInfo> getCustomerInfo() async {
    throw Exception("Not configured in mock");
  }

  @override
  Future<bool> isProUser() async => false;

  @override
  Future<CustomerInfo> restorePurchases() async {
    return getCustomerInfo();
  }

  @override
  Future<PaywallResult> presentPaywall() async {
    return PaywallResult.notPresented;
  }

  @override
  Future<PaywallResult> presentPaywallIfNeeded() async {
    paywallPresented = true;
    return PaywallResult.notPresented;
  }

  @override
  Future<void> presentCustomerCenter() async {}

  @override
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {}

  @override
  void removeCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {}

  @override
  Future<void> syncWithBackend(String firebaseUid) async {}
}

class _MockImagePicker extends ImagePicker {
  _MockImagePicker({this.imageToReturn});

  XFile? imageToReturn;
  ImageSource? lastCalledSource;
  double? lastCalledMaxWidth;
  int? lastCalledImageQuality;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    lastCalledSource = source;
    lastCalledMaxWidth = maxWidth;
    lastCalledImageQuality = imageQuality;
    return imageToReturn;
  }
}

ShoppingScan _makeTestScan() {
  return ShoppingScan.fromJson({
    "id": "scan-1",
    "url": "https://www.zara.com/shirt",
    "scanType": "url",
    "productName": "Blue Cotton Shirt",
    "brand": "Zara",
    "price": 29.99,
    "currency": "GBP",
    "imageUrl": "https://example.com/shirt.jpg",
    "category": "tops",
    "color": "blue",
    "style": "casual",
    "pattern": "solid",
    "material": "cotton",
    "extractionMethod": "og_tags+json_ld",
    "createdAt": "2026-03-19T00:00:00.000Z",
  });
}

void main() {
  group("ShoppingScanScreen", () {
    testWidgets("Renders URL input field and Analyze button", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      expect(find.text("Shopping Assistant"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("Analyze"), findsOneWidget);
      expect(find.text("Paste product URL here..."), findsOneWidget);
    });

    testWidgets("Analyze button is disabled when URL is empty", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
      expect(button.onPressed, isNull);
    });

    testWidgets("Shows loading state when scan is in progress", (tester) async {
      final completer = Completer<void>();
      final service = _MockShoppingScanService(
        result: _makeTestScan(),
        completer: completer,
      );
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      // Type a URL
      await tester.enterText(find.byType(TextField), "https://www.zara.com/shirt");
      await tester.pump();

      // Tap analyze
      await tester.tap(find.text("Analyze"));
      await tester.pump();

      // Should show loading text
      expect(find.text("Scraping product details..."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets("Displays scan result card on success", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      await tester.enterText(find.byType(TextField), "https://www.zara.com/shirt");
      await tester.pump();
      await tester.tap(find.text("Analyze"));
      await tester.pumpAndSettle();

      expect(find.text("Blue Cotton Shirt"), findsOneWidget);
      expect(find.text("Zara"), findsOneWidget);
      expect(find.text("GBP 29.99"), findsOneWidget);
      expect(find.text("tops"), findsOneWidget);
      expect(find.text("blue"), findsOneWidget);
      expect(find.text("casual"), findsOneWidget);
    });

    testWidgets("Shows PremiumGateCard on 429 rate limit error", (tester) async {
      final service = _MockShoppingScanService(shouldThrowRateLimit: true);
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      await tester.enterText(find.byType(TextField), "https://www.zara.com/shirt");
      await tester.pump();
      await tester.tap(find.text("Analyze"));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateCard), findsOneWidget);
      expect(find.text("Daily Scan Limit Reached"), findsOneWidget);
    });

    testWidgets("Shows error message on 422 extraction failure", (tester) async {
      final service = _MockShoppingScanService(shouldThrowExtractionError: true);
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      await tester.enterText(find.byType(TextField), "https://www.empty-page.com/nothing");
      await tester.pump();
      await tester.tap(find.text("Analyze"));
      await tester.pumpAndSettle();

      expect(find.textContaining("Unable to extract product information"), findsOneWidget);
      expect(find.text("Try a URL instead"), findsOneWidget);
    });

    // === Story 8.2: Screenshot upload flow tests ===

    testWidgets("Screenshot card is fully visible and tappable", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      // Card should be visible (not dimmed)
      expect(find.text("Upload Screenshot"), findsOneWidget);
      expect(find.text("Analyze from photo or screenshot"), findsOneWidget);

      // Should NOT have "Coming Soon"
      expect(find.text("Coming Soon"), findsNothing);

      // Opacity widget wrapping the card should NOT exist (it was removed)
      // The card icon should be the active color (indigo)
      final icon = tester.widget<Icon>(find.byIcon(Icons.camera_alt));
      expect(icon.color, const Color(0xFF4F46E5));
    });

    testWidgets("Tapping screenshot card shows bottom sheet with options", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();

      expect(find.text("Take Photo"), findsOneWidget);
      expect(find.text("Choose from Gallery"), findsOneWidget);
    });

    testWidgets("Selecting gallery option calls ImagePicker with correct params", (tester) async {
      final mockImagePicker = _MockImagePicker(imageToReturn: null);
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
          imagePicker: mockImagePicker,
        ),
      ));

      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Choose from Gallery"));
      await tester.pumpAndSettle();

      expect(mockImagePicker.lastCalledSource, ImageSource.gallery);
      expect(mockImagePicker.lastCalledMaxWidth, 1024);
      expect(mockImagePicker.lastCalledImageQuality, 90);
    });

    testWidgets("Selecting camera option calls ImagePicker with camera source", (tester) async {
      final mockImagePicker = _MockImagePicker(imageToReturn: null);
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
          imagePicker: mockImagePicker,
        ),
      ));

      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Take Photo"));
      await tester.pumpAndSettle();

      expect(mockImagePicker.lastCalledSource, ImageSource.camera);
    });

    testWidgets("Cancellation (null from ImagePicker) returns to initial state", (tester) async {
      final mockImagePicker = _MockImagePicker(imageToReturn: null);
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
          imagePicker: mockImagePicker,
        ),
      ));

      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Choose from Gallery"));
      await tester.pumpAndSettle();

      // Should still show the initial state (no loading, no error)
      expect(find.text("Analyzing screenshot..."), findsNothing);
      expect(find.text("Upload Screenshot"), findsOneWidget);
    });

    testWidgets("On 429 error during screenshot, PremiumGateCard is shown", (tester) async {
      final mockImagePicker = _MockImagePicker(
        imageToReturn: XFile("/tmp/fake_screenshot.jpg"),
      );
      final service = _MockShoppingScanService(
        result: _makeTestScan(),
        shouldThrowScreenshotRateLimit: true,
      );
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _MockApiClient(),
          imagePicker: mockImagePicker,
        ),
      ));

      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Choose from Gallery"));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateCard), findsOneWidget);
    });

    testWidgets("On 422 error during screenshot, error message with URL suggestion is shown", (tester) async {
      final mockImagePicker = _MockImagePicker(
        imageToReturn: XFile("/tmp/fake_screenshot.jpg"),
      );
      final service = _MockShoppingScanService(
        result: _makeTestScan(),
        shouldThrowScreenshotExtractionError: true,
      );
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _MockApiClient(),
          imagePicker: mockImagePicker,
        ),
      ));

      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Choose from Gallery"));
      await tester.pumpAndSettle();

      expect(find.textContaining("Unable to identify clothing"), findsOneWidget);
      expect(find.text("Try a URL instead"), findsOneWidget);
    });

    // === Story 8.3: Review & Edit button tests ===

    testWidgets("Review & Edit button is enabled and visible when scan result is displayed", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      await tester.enterText(find.byType(TextField), "https://www.zara.com/shirt");
      await tester.pump();
      await tester.tap(find.text("Analyze"));
      await tester.pumpAndSettle();

      // Should show "Review & Edit" button instead of disabled "Continue to Analysis"
      expect(find.text("Review & Edit"), findsOneWidget);
      expect(find.text("Continue to Analysis"), findsNothing);

      // The button should be enabled (ElevatedButton with onPressed != null)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Review & Edit"),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets("Tapping Review & Edit navigates to ProductReviewScreen", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      await tester.enterText(find.byType(TextField), "https://www.zara.com/shirt");
      await tester.pump();
      await tester.tap(find.text("Analyze"));
      await tester.pumpAndSettle();

      // Scroll to the Review & Edit button (it may be off-screen)
      await tester.scrollUntilVisible(
        find.text("Review & Edit"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text("Review & Edit"));
      await tester.pumpAndSettle();

      // Should have navigated to ProductReviewScreen
      expect(find.text("Review Product"), findsOneWidget);
    });

    testWidgets("Semantics labels present on screenshot card and bottom sheet options", (tester) async {
      final service = _MockShoppingScanService(result: _makeTestScan());
      final subService = _FakeSubscriptionService();

      await tester.pumpWidget(MaterialApp(
        home: ShoppingScanScreen(
          shoppingScanService: service,
          subscriptionService: subService,
          apiClient: _dummyApiClient(),
        ),
      ));

      // Verify Semantics on screenshot card
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Upload Screenshot",
        ),
        findsOneWidget,
      );

      // Verify Semantics on other interactive elements
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Product URL input",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Paste from clipboard",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Analyze product URL",
        ),
        findsOneWidget,
      );

      // Open bottom sheet and check semantics on options
      await tester.tap(find.text("Upload Screenshot"));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Take Photo",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Choose from Gallery",
        ),
        findsOneWidget,
      );
    });
  });
}
