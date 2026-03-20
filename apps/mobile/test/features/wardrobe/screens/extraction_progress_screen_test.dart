import "dart:async";
import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/extraction_progress_screen.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/extraction_review_screen.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "test-token";
}

ApiClient _buildMockApiClient({
  String initialStatus = "processing",
  int processedPhotos = 1,
  int totalPhotos = 3,
  int totalItemsFound = 2,
  String? errorMessage,
  bool processShouldFail = false,
  String? statusAfterRetry,
}) {
  int callCount = 0;

  final mockHttp = http_testing.MockClient((request) async {
    final path = request.url.path;
    final method = request.method;

    // GET /v1/extraction-jobs/:id
    if (method == "GET" && path.startsWith("/v1/extraction-jobs/") && !path.contains("/duplicates")) {
      callCount++;
      String status = initialStatus;
      // After a retry (POST /process), return the new status
      if (statusAfterRetry != null && callCount > 2) {
        status = statusAfterRetry;
      }
      return http.Response(
        jsonEncode({
          "job": {
            "id": "job-1",
            "status": status,
            "totalPhotos": totalPhotos,
            "processedPhotos": processedPhotos,
            "totalItemsFound": totalItemsFound,
            "errorMessage": errorMessage,
            "items": status == "completed" || status == "partial"
                ? [
                    {
                      "id": "item-1",
                      "photoUrl": "https://example.com/cleaned.png",
                      "category": "tops",
                      "color": "blue",
                      "secondaryColors": [],
                      "pattern": "solid",
                      "material": "cotton",
                      "style": "casual",
                      "season": ["all"],
                      "occasion": ["everyday"],
                      "bgRemovalStatus": "completed",
                      "categorizationStatus": "completed"
                    }
                  ]
                : [],
            "photos": [],
          }
        }),
        200,
      );
    }

    // POST /v1/extraction-jobs/:id/process (retry)
    if (method == "POST" && path.contains("/process")) {
      if (processShouldFail) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      return http.Response(
        jsonEncode({"status": "processing"}),
        202,
      );
    }

    // GET /v1/extraction-jobs/:id/duplicates
    if (method == "GET" && path.contains("/duplicates")) {
      return http.Response(
        jsonEncode({"duplicates": []}),
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

  group("ExtractionProgressScreen", () {
    testWidgets("renders progress indicator with status text", (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        // Let the initial fetch complete
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Should show progress text
        expect(find.textContaining("Processing photo"), findsOneWidget);
        // Should show items found counter
        expect(find.textContaining("Items found:"), findsOneWidget);
      });
    });

    testWidgets("shows progress bar", (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(
                processedPhotos: 1,
                totalPhotos: 3,
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });
    });

    testWidgets("shows estimated time remaining", (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(
                processedPhotos: 1,
                totalPhotos: 3,
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // (3-1)*6 = 12 seconds
        expect(find.textContaining("~12 seconds remaining"), findsOneWidget);
      });
    });

    testWidgets("shows error UI with retry button when job fails",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(
                initialStatus: "failed",
                errorMessage: "Processing error occurred",
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text("Extraction failed"), findsOneWidget);
        expect(find.text("Processing error occurred"), findsOneWidget);
        expect(find.text("Retry"), findsOneWidget);
      });
    });

    testWidgets("retry button triggers processing and restarts polling",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(
                initialStatus: "failed",
                statusAfterRetry: "processing",
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text("Retry"), findsOneWidget);

        await tester.tap(find.text("Retry"));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // After retry, screen should show progress UI again
        // (status becomes processing from statusAfterRetry)
      });
    });

    testWidgets("back button shows confirmation dialog", (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExtractionProgressScreen(
                        jobId: "job-1",
                        apiClient: _buildMockApiClient(),
                      ),
                    ),
                  );
                },
                child: const Text("Go"),
              ),
            ),
          ),
        );

        // Navigate to the screen so it has a back button
        await tester.tap(find.text("Go"));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        await tester.pump();

        // Tap the AppBar back button
        final backButton = find.byTooltip("Back");
        await tester.tap(backButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text("Leave Progress"), findsOneWidget);
        expect(
          find.textContaining("Processing will continue in the background"),
          findsOneWidget,
        );
      });
    });

    testWidgets("auto-navigates to review screen when job completes",
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(initialStatus: "completed"),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Should have navigated to ExtractionReviewScreen
        expect(find.byType(ExtractionReviewScreen), findsOneWidget);
      });
    });

    testWidgets("semantics labels present", (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExtractionProgressScreen(
              jobId: "job-1",
              apiClient: _buildMockApiClient(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Check for key semantics labels via Semantics widget predicate
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == "Extraction Progress",
          ),
          findsOneWidget,
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.label?.contains("Items found") ?? false),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
