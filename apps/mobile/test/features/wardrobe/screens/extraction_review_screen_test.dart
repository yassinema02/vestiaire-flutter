import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/extraction_review_screen.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

Map<String, dynamic> _buildJobData({
  List<Map<String, dynamic>>? items,
}) {
  return {
    "id": "job-1",
    "status": "completed",
    "totalPhotos": 2,
    "processedPhotos": 2,
    "totalItemsFound": items?.length ?? 2,
    "items": items ??
        [
          {
            "id": "item-1",
            "photoUrl": "https://example.com/cleaned1.png",
            "category": "tops",
            "color": "blue",
            "secondaryColors": <dynamic>[],
            "pattern": "solid",
            "material": "cotton",
            "style": "casual",
            "season": <dynamic>["all"],
            "occasion": <dynamic>["everyday"],
            "bgRemovalStatus": "completed",
            "categorizationStatus": "completed",
          },
          {
            "id": "item-2",
            "photoUrl": "https://example.com/cleaned2.png",
            "category": "bottoms",
            "color": "black",
            "secondaryColors": <dynamic>[],
            "pattern": "solid",
            "material": "denim",
            "style": "casual",
            "season": <dynamic>["all"],
            "occasion": <dynamic>["everyday"],
            "bgRemovalStatus": "completed",
            "categorizationStatus": "completed",
          },
        ],
    "photos": <dynamic>[],
  };
}

ApiClient _buildMockApiClient({
  List<Map<String, dynamic>>? duplicates,
  bool confirmShouldFail = false,
  int confirmedCount = 2,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    final path = request.url.path;
    final method = request.method;

    // GET /v1/extraction-jobs/:id/duplicates
    if (method == "GET" && path.contains("/duplicates")) {
      return http.Response(
        jsonEncode({
          "duplicates": duplicates ?? [],
        }),
        200,
      );
    }

    // POST /v1/extraction-jobs/:id/confirm
    if (method == "POST" && path.contains("/confirm")) {
      if (confirmShouldFail) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final keptIds = (body["keptItemIds"] as List<dynamic>?) ?? [];
      return http.Response(
        jsonEncode({
          "confirmedCount": keptIds.length,
          "items": keptIds
              .map((id) => {
                    "id": "new-$id",
                    "creationMethod": "ai_extraction",
                    "extractionJobId": "job-1",
                  })
              .toList(),
        }),
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

  group("ExtractionReviewScreen", () {
    testWidgets("renders all extracted items with categories and Keep toggles",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Should show item count header
        expect(find.textContaining("2 items found"), findsOneWidget);

        // Should show Keep toggles (2 Switch widgets)
        expect(find.byType(Switch), findsNWidgets(2));

        // Should show category chips
        expect(find.text("Tops"), findsOneWidget);
        expect(find.text("Bottoms"), findsOneWidget);
      });
    });

    testWidgets("toggling an item updates the selected count",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Initially 2 selected
        expect(find.textContaining("2 selected"), findsOneWidget);

        // Toggle the first switch off
        await tester.tap(find.byType(Switch).first);
        await tester.pump();

        // Now 1 selected
        expect(find.textContaining("1 selected"), findsOneWidget);
      });
    });

    testWidgets("duplicate warning badge appears for items with duplicates",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(
                duplicates: [
                  {
                    "extractionItemId": "item-1",
                    "matchingItemId": "existing-1",
                    "matchingItemPhotoUrl": "https://example.com/existing.jpg",
                    "matchingItemName": "Blue Top"
                  }
                ],
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        expect(find.text("Possible duplicate"), findsOneWidget);
      });
    });

    testWidgets("tapping duplicate badge shows comparison dialog",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(
                duplicates: [
                  {
                    "extractionItemId": "item-1",
                    "matchingItemId": "existing-1",
                    "matchingItemPhotoUrl": "https://example.com/existing.jpg",
                    "matchingItemName": "Blue Top"
                  }
                ],
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // Tap the duplicate badge
        await tester.tap(find.text("Possible duplicate"));
        await tester.pumpAndSettle();

        // Dialog should appear
        expect(find.text("Possible Duplicate"), findsOneWidget);
        expect(find.text("Extracted Item"), findsOneWidget);
        expect(find.text("Existing Item"), findsOneWidget);
        expect(find.text("Blue Top"), findsOneWidget);
      });
    });

    testWidgets("tapping item card expands metadata editor", (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Tap the first item card (the InkWell inside the Card)
        // Use the category chip text to locate the correct InkWell
        await tester.tap(find.text("Tops"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should show metadata editor fields (TextFormField for name, DropdownButtonFormField labels)
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsAtLeastNWidgets(1));
      });
    });

    testWidgets("'Add to Wardrobe' calls confirm endpoint",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => ExtractionReviewScreen(
                  jobId: "job-1",
                  jobData: _buildJobData(),
                  apiClient: _buildMockApiClient(),
                ),
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Tap "Add to Wardrobe"
        await tester.tap(find.text("Add to Wardrobe"));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should show success SnackBar
        expect(find.textContaining("items added to your wardrobe"), findsOneWidget);
      });
    });

    testWidgets("zero items selected shows discard confirmation dialog",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Toggle both items off
        await tester.tap(find.byType(Switch).first);
        await tester.pump();
        await tester.tap(find.byType(Switch).last);
        await tester.pump();

        // Tap "Add to Wardrobe"
        await tester.tap(find.text("Add to Wardrobe"));
        await tester.pumpAndSettle();

        expect(find.text("No Items Selected"), findsOneWidget);
        expect(
          find.text("No items selected. Discard all extracted items?"),
          findsOneWidget,
        );
      });
    });

    testWidgets("'Select All' / 'Deselect All' toggle works",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Initially all selected, should show "Deselect All"
        expect(find.text("Deselect All"), findsOneWidget);

        // Tap "Deselect All"
        await tester.tap(find.text("Deselect All"));
        await tester.pump();

        // Should now show "Select All" and 0 selected
        expect(find.text("Select All"), findsOneWidget);
        expect(find.textContaining("0 selected"), findsOneWidget);

        // Tap "Select All"
        await tester.tap(find.text("Select All"));
        await tester.pump();

        // Should show "Deselect All" again and 2 selected
        expect(find.text("Deselect All"), findsOneWidget);
        expect(find.textContaining("2 selected"), findsOneWidget);
      });
    });

    testWidgets("semantics labels present on all interactive elements",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionReviewScreen(
              jobId: "job-1",
              jobData: _buildJobData(),
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Extraction Review title semantics
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == "Extraction Review",
          ),
          findsOneWidget,
        );

        // Add to Wardrobe button semantics
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == "Add to Wardrobe",
          ),
          findsOneWidget,
        );

        // Keep/Remove item semantics
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label == "Keep item" ||
                    w.properties.label == "Remove item"),
          ),
          findsNWidgets(2),
        );

        // Edit item metadata semantics
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == "Edit item metadata",
          ),
          findsNWidgets(2),
        );
      });
    });
  });
}
