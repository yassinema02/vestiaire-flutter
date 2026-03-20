import "dart:convert";
import "dart:io";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/bulk_import_preview_screen.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/extraction_progress_screen.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

/// Create temp image files for testing
List<String> createTempPhotoPaths(int count) {
  final paths = <String>[];
  for (int i = 0; i < count; i++) {
    final dir = Directory.systemTemp;
    final file = File("${dir.path}/test_photo_$i.jpg");
    if (!file.existsSync()) {
      // Write minimal JPEG header bytes
      file.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
    }
    paths.add(file.path);
  }
  return paths;
}

ApiClient _buildMockApiClient({
  bool signedUrlsShouldFail = false,
  bool uploadShouldFail = false,
  int uploadFailIndex = -1,
  bool createJobShouldFail = false,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    final path = request.url.path;
    final method = request.method;

    // POST /v1/uploads/signed-urls
    if (method == "POST" && path == "/v1/uploads/signed-urls") {
      if (signedUrlsShouldFail) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final count = body["count"] as int;
      final urls = List.generate(count, (i) => <String, dynamic>{
          "index": i,
          "uploadUrl": "https://upload.example.com/upload-$i",
          "publicUrl": "https://storage.example.com/photo-$i.jpg",
        });
      return http.Response(jsonEncode({"urls": urls}), 200);
    }

    // PUT (upload image to signed URL)
    if (method == "PUT") {
      if (uploadShouldFail) {
        throw Exception("upload failed");
      }
      // Check if this specific upload should fail
      final urlPath = request.url.toString();
      if (uploadFailIndex >= 0 && urlPath.contains("upload-$uploadFailIndex")) {
        throw Exception("upload failed for index $uploadFailIndex");
      }
      return http.Response("", 200);
    }

    // POST /v1/extraction-jobs
    if (method == "POST" && path == "/v1/extraction-jobs") {
      if (createJobShouldFail) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          "job": {
            "id": "job-1",
            "status": "processing",
            "totalPhotos": body["totalPhotos"],
          }
        }),
        201,
      );
    }

    // GET /v1/extraction-jobs/:id
    if (method == "GET" && path.startsWith("/v1/extraction-jobs/")) {
      return http.Response(
        jsonEncode({
          "job": {
            "id": "job-1",
            "status": "processing",
            "totalPhotos": 3,
            "photos": [],
          }
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

  group("BulkImportPreviewScreen", () {
    testWidgets("renders photo grid with correct count header",
        (tester) async {
      final paths = createTempPhotoPaths(3);

      await tester.pumpWidget(
        MaterialApp(
          home: BulkImportPreviewScreen(
            photoPaths: paths,
            apiClient: _buildMockApiClient(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check count header
      expect(find.text("3 photos selected"), findsOneWidget);

      // Check grid exists
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets("tapping a photo toggles its selection", (tester) async {
      final paths = createTempPhotoPaths(2);

      await tester.pumpWidget(
        MaterialApp(
          home: BulkImportPreviewScreen(
            photoPaths: paths,
            apiClient: _buildMockApiClient(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 2 photos selected
      expect(find.text("2 photos selected"), findsOneWidget);

      // Tap first photo to deselect
      final toggleFinders = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Toggle photo selection",
      );
      await tester.tap(toggleFinders.first);
      await tester.pumpAndSettle();

      // Now 1 photo selected
      expect(find.text("1 photos selected"), findsOneWidget);
    });

    testWidgets("count header updates when photos are toggled",
        (tester) async {
      final paths = createTempPhotoPaths(3);

      await tester.pumpWidget(
        MaterialApp(
          home: BulkImportPreviewScreen(
            photoPaths: paths,
            apiClient: _buildMockApiClient(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("3 photos selected"), findsOneWidget);

      // Deselect first photo
      final toggleFinders = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Toggle photo selection",
      );
      await tester.tap(toggleFinders.first);
      await tester.pumpAndSettle();

      expect(find.text("2 photos selected"), findsOneWidget);

      // Re-select first photo
      await tester.tap(toggleFinders.first);
      await tester.pumpAndSettle();

      expect(find.text("3 photos selected"), findsOneWidget);
    });

    testWidgets("Start Import button is disabled when all photos deselected",
        (tester) async {
      final paths = createTempPhotoPaths(1);

      await tester.pumpWidget(
        MaterialApp(
          home: BulkImportPreviewScreen(
            photoPaths: paths,
            apiClient: _buildMockApiClient(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially enabled
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Start Import"),
      );
      expect(button.onPressed, isNotNull);

      // Deselect the only photo
      final toggleFinders = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Toggle photo selection",
      );
      await tester.tap(toggleFinders.first);
      await tester.pumpAndSettle();

      // Now disabled
      final buttonAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Start Import"),
      );
      expect(buttonAfter.onPressed, isNull);
    });

    testWidgets("upload flow shows progress indicator and navigates to ExtractionProgressScreen",
        (tester) async {
      final paths = createTempPhotoPaths(2);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => BulkImportPreviewScreen(
                  photoPaths: paths,
                  apiClient: _buildMockApiClient(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Start Import
        await tester.tap(find.text("Start Import"));

        // Pump once to start the upload
        await tester.pump();

        // Should show progress overlay
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Wait for all uploads and job creation to complete
        await Future.delayed(const Duration(seconds: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Should have navigated to ExtractionProgressScreen
        expect(find.byType(ExtractionProgressScreen), findsOneWidget);
      });
    });

    testWidgets("individual photo failure does not block batch",
        (tester) async {
      final paths = createTempPhotoPaths(3);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => BulkImportPreviewScreen(
                  photoPaths: paths,
                  apiClient: _buildMockApiClient(uploadFailIndex: 1),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Start Import
        await tester.tap(find.text("Start Import"));

        // Wait for all uploads and job creation to complete
        await Future.delayed(const Duration(seconds: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Import should still complete despite one failure (navigates to progress)
        expect(find.byType(ExtractionProgressScreen), findsOneWidget);
      });
    });

    testWidgets("cancel during upload shows confirmation dialog",
        (tester) async {
      final paths = createTempPhotoPaths(5);

      // Use a slow upload to give time to cancel
      final mockHttp = http_testing.MockClient((request) async {
        final path = request.url.path;
        final method = request.method;

        if (method == "POST" && path == "/v1/uploads/signed-urls") {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final count = body["count"] as int;
          final urls = List.generate(count, (i) => <String, dynamic>{
              "index": i,
              "uploadUrl": "https://upload.example.com/upload-$i",
              "publicUrl": "https://storage.example.com/photo-$i.jpg",
            });
          return http.Response(jsonEncode({"urls": urls}), 200);
        }

        if (method == "PUT") {
          // Slow upload
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response("", 200);
        }

        if (method == "POST" && path == "/v1/extraction-jobs") {
          return http.Response(
            jsonEncode({"job": {"id": "job-1", "status": "processing", "totalPhotos": 5}}),
            201,
          );
        }

        return http.Response(jsonEncode({"code": "NOT_FOUND"}), 404);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BulkImportPreviewScreen(
            photoPaths: paths,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start upload
      await tester.tap(find.text("Start Import"));
      await tester.pump();

      // Try to go back while uploading
      // The WillPopScope should intercept
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text("Cancel Import"), findsWidgets);
      expect(find.text("Cancel import? Uploaded photos will be discarded."), findsOneWidget);
    });

    testWidgets("back button pops screen when not uploading", (tester) async {
      final paths = createTempPhotoPaths(2);
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BulkImportPreviewScreen(
                      photoPaths: paths,
                      apiClient: _buildMockApiClient(),
                      onImportComplete: () {},
                    ),
                  ),
                ).then((_) {
                  popped = true;
                });
              },
              child: const Text("Go"),
            ),
          ),
        ),
      );

      // Navigate to the screen
      await tester.tap(find.text("Go"));
      await tester.pumpAndSettle();

      expect(find.text("Bulk Import Preview"), findsOneWidget);

      // Tap back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should have popped
      expect(popped, isTrue);
    });

    testWidgets("Semantics labels present on interactive elements",
        (tester) async {
      final paths = createTempPhotoPaths(2);

      await tester.pumpWidget(
        MaterialApp(
          home: BulkImportPreviewScreen(
            photoPaths: paths,
            apiClient: _buildMockApiClient(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bulk Import Preview title
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Bulk Import Preview",
        ),
        findsOneWidget,
      );

      // Photo count
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "2 photos selected",
        ),
        findsOneWidget,
      );

      // Toggle photo selection
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Toggle photo selection",
        ),
        findsNWidgets(2),
      );

      // Start Import button
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Start Import",
        ),
        findsOneWidget,
      );

      // Cancel Import (back button)
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Cancel Import",
        ),
        findsOneWidget,
      );
    });
  });
}
