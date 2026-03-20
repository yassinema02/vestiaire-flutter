import "dart:convert";
import "dart:io";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:image_picker/image_picker.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/add_item_screen.dart";
import "package:vestiaire_mobile/src/features/wardrobe/screens/review_item_screen.dart";

/// AuthService that returns a test token without requiring Firebase sign-in.
class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

/// Mock ImagePicker that returns a controllable result.
class _MockImagePicker extends ImagePicker {
  _MockImagePicker({this.result, this.shouldThrow = false});

  final XFile? result;
  final bool shouldThrow;
  ImageSource? lastSource;
  double? lastMaxWidth;
  int? lastImageQuality;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastSource = source;
    lastMaxWidth = maxWidth;
    lastImageQuality = imageQuality;
    if (shouldThrow) {
      throw PlatformException(
        code: "camera_access_denied",
        message: "Camera not available",
      );
    }
    return result;
  }
}

ApiClient _buildMockApiClient({
  bool shouldFail = false,
  String? bgRemovalStatus,
  bool includePoints = false,
  Map<String, dynamic>? levelUpData,
  List<Map<String, dynamic>>? badgesAwarded,
  Map<String, dynamic>? challengeUpdate,
}) {
  final mockHttp = http_testing.MockClient((request) async {
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }
    if (request.url.path.contains("/v1/uploads/signed-url")) {
      return http.Response(
        jsonEncode({
          "uploadUrl": "https://storage.example.com/upload",
          "publicUrl": "https://storage.example.com/public/photo.jpg",
        }),
        200,
      );
    }
    if (request.url.path.contains("/v1/items") &&
        request.method == "POST") {
      final responseBody = <String, dynamic>{
        "item": {
          "id": "123",
          "profileId": "profile-1",
          "photoUrl": "https://storage.example.com/public/photo.jpg",
          "bgRemovalStatus": bgRemovalStatus,
          "categorizationStatus": "completed",
          "category": "tops",
          "color": "blue",
          "pattern": "solid",
          "material": "cotton",
          "style": "casual",
          "season": ["spring"],
          "occasion": ["everyday"],
        }
      };
      if (includePoints) {
        responseBody["pointsAwarded"] = {
          "pointsAwarded": 10,
          "totalPoints": 10,
          "action": "item_upload",
        };
      }
      if (levelUpData != null) {
        responseBody["levelUp"] = levelUpData;
      }
      if (badgesAwarded != null) {
        responseBody["badgesAwarded"] = badgesAwarded;
      }
      if (challengeUpdate != null) {
        responseBody["challengeUpdate"] = challengeUpdate;
      }
      return http.Response(
        jsonEncode(responseBody),
        200,
      );
    }
    // Handle PATCH /v1/items/:id (for ReviewItemScreen save)
    if (request.method == "PATCH" && request.url.path.contains("/v1/items/")) {
      return http.Response(
        jsonEncode({
          "item": {
            "id": "123",
            "profileId": "profile-1",
            "photoUrl": "https://storage.example.com/public/photo.jpg",
            "category": "tops",
          }
        }),
        200,
      );
    }
    // For uploadImage PUT and other requests - return valid JSON
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
    // Create a temporary test file for upload tests
    final testFile = File("/tmp/test_photo.jpg");
    if (!testFile.existsSync()) {
      testFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // minimal JPEG
    }
  });

  group("AddItemScreen", () {
    testWidgets("renders title and two option cards", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(apiClient: _buildMockApiClient()),
        ),
      );

      expect(find.text("Add Item"), findsOneWidget);
      expect(find.text("Take Photo"), findsOneWidget);
      expect(find.text("Choose from Gallery"), findsOneWidget);
    });

    testWidgets("tapping Take Photo calls pickImage with camera source",
        (tester) async {
      final mockPicker = _MockImagePicker(result: null);

      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );

      await tester.tap(find.text("Take Photo"));
      await tester.pumpAndSettle();

      expect(mockPicker.lastSource, ImageSource.camera);
      expect(mockPicker.lastMaxWidth, 512);
      expect(mockPicker.lastImageQuality, 85);
    });

    testWidgets(
        "tapping Choose from Gallery calls pickImage with gallery source",
        (tester) async {
      final mockPicker = _MockImagePicker(result: null);

      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );

      await tester.tap(find.text("Choose from Gallery"));
      await tester.pumpAndSettle();

      expect(mockPicker.lastSource, ImageSource.gallery);
      expect(mockPicker.lastMaxWidth, 512);
      expect(mockPicker.lastImageQuality, 85);
    });

    testWidgets("when pickImage returns null, screen stays in initial state",
        (tester) async {
      final mockPicker = _MockImagePicker(result: null);

      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );

      await tester.tap(find.text("Take Photo"));
      await tester.pumpAndSettle();

      expect(find.text("Take Photo"), findsOneWidget);
      expect(find.text("Choose from Gallery"), findsOneWidget);
    });

    testWidgets("when pickImage returns a file, upload flow begins",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));

      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(
            apiClient: _buildMockApiClient(shouldFail: true),
            imagePicker: mockPicker,
          ),
        ),
      );

      await tester.tap(find.text("Take Photo"));
      await tester.pump();
      await tester.pump();

      await tester.pumpAndSettle();

      expect(
        find.text("Failed to add item. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets("on successful upload, navigates to ReviewItemScreen",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pumpAndSettle();

      // Should navigate to ReviewItemScreen
      expect(find.byType(ReviewItemScreen), findsOneWidget);
    });

    testWidgets("on upload failure, error SnackBar appears and screen resets",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));

      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(
            apiClient: _buildMockApiClient(shouldFail: true),
            imagePicker: mockPicker,
          ),
        ),
      );

      await tester.tap(find.text("Take Photo"));
      await tester.pumpAndSettle();

      expect(
        find.text("Failed to add item. Please try again."),
        findsOneWidget,
      );

      expect(find.text("Take Photo"), findsOneWidget);
      expect(find.text("Choose from Gallery"), findsOneWidget);
    });

    testWidgets(
        "camera unavailable PlatformException shows appropriate SnackBar",
        (tester) async {
      final mockPicker = _MockImagePicker(shouldThrow: true);

      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );

      await tester.tap(find.text("Take Photo"));
      await tester.pumpAndSettle();

      expect(
        find.text("Camera not available on this device."),
        findsOneWidget,
      );
    });

    testWidgets("Semantics labels present on all interactive elements",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AddItemScreen(apiClient: _buildMockApiClient()),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Take Photo",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Choose from Gallery",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Close",
        ),
        findsOneWidget,
      );
    });

    testWidgets("close button pops the screen", (tester) async {
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: _buildMockApiClient(),
                    ),
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

      expect(find.text("Add Item"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.text("Add Item"), findsNothing);
    });

    // === Story 2.2: Background removal status in success message ===

    // === Story 2.4: Navigation to ReviewItemScreen ===

    testWidgets(
        "successful upload navigates to ReviewItemScreen",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pumpAndSettle();

      // Should navigate to ReviewItemScreen
      expect(find.byType(ReviewItemScreen), findsOneWidget);
      expect(find.text("Review Item"), findsOneWidget);
    });

    // === Story 2.2: Background removal status (legacy tests kept for regression) ===

    // Story 2.4: SnackBar tests removed -- upload now navigates to ReviewItemScreen
    // instead of showing a SnackBar. See "successful upload navigates to
    // ReviewItemScreen" test above.

    testWidgets(
        "successful upload with pending bg removal navigates to ReviewItemScreen",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(bgRemovalStatus: "pending");

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ReviewItemScreen), findsOneWidget);
      expect(find.text("Review Item"), findsOneWidget);
    });

    // === Story 6.1: Style Points Toast Integration ===

    testWidgets(
        "after successful item creation, points toast is displayed when pointsAwarded in response",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(includePoints: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pump();

      // Points toast should appear
      expect(find.text("+10 Style Points"), findsOneWidget);
    });

    testWidgets(
        "no toast displayed when pointsAwarded is absent from response (backward compatibility)",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(includePoints: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pump();

      // No points toast
      expect(find.text("+10 Style Points"), findsNothing);
    });

    // === Story 6.2: Level-Up Modal Integration ===

    testWidgets(
        "after successful item creation with levelUp in response, level-up modal is displayed",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(
        levelUpData: {
          "newLevel": 2,
          "newLevelName": "Style Starter",
          "previousLevelName": "Closet Rookie",
          "nextLevelThreshold": 25,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Start the image upload
      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        // Wait for network calls and the 500ms level-up delay
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      // Pump to process the Future.delayed timer and show the dialog
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Level-up modal should be displayed
      expect(find.text("Style Starter"), findsOneWidget);
      expect(find.text("You've reached Level 2!"), findsOneWidget);
    });

    testWidgets(
        "no modal when levelUp is null in response",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(levelUpData: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // No level-up modal
      expect(find.textContaining("You've reached Level"), findsNothing);
    });

    testWidgets(
        "both points toast and level-up modal appear when both are present",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(
        includePoints: true,
        levelUpData: {
          "newLevel": 2,
          "newLevelName": "Style Starter",
          "previousLevelName": "Closet Rookie",
          "nextLevelThreshold": 25,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        // Wait for all async work including the 500ms delay
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      // Pump to process the delayed timer and animations
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Level-up modal should appear
      expect(find.text("Style Starter"), findsOneWidget);
      expect(find.text("You've reached Level 2!"), findsOneWidget);
    });

    // === Story 6.4: Badge Modal Integration ===

    testWidgets(
        "after item creation with badgesAwarded in response, badge modal is displayed",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(
        badgesAwarded: [
          {"name": "First Step", "description": "Upload your first wardrobe item", "iconName": "star", "iconColor": "#FBBF24"},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      // Pump to process the 1000ms badge delay
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Badge modal should be displayed
      expect(find.text("Badge Earned!"), findsOneWidget);
      expect(find.text("First Step"), findsOneWidget);
    });

    testWidgets(
        "no badge modal when badgesAwarded is empty",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(badgesAwarded: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();

      // No badge modal
      expect(find.text("Badge Earned!"), findsNothing);
    });

    // === Story 6.5: Challenge Completion Modal Integration ===

    testWidgets(
        "after item creation with challengeUpdate.completed=true, completion modal is displayed",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(
        challengeUpdate: {
          "key": "closet_safari",
          "currentProgress": 20,
          "targetCount": 20,
          "completed": true,
          "rewardGranted": true,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      // Pump to process the 1000ms challenge modal delay
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Challenge completion modal should be displayed
      expect(find.text("Closet Safari Complete!"), findsOneWidget);
    });

    testWidgets(
        "no modal when challengeUpdate is null",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(challengeUpdate: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();

      expect(find.text("Closet Safari Complete!"), findsNothing);
    });

    testWidgets(
        "no modal when challengeUpdate.completed is false",
        (tester) async {
      final mockPicker =
          _MockImagePicker(result: XFile("/tmp/test_photo.jpg"));
      final apiClient = _buildMockApiClient(
        challengeUpdate: {
          "key": "closet_safari",
          "currentProgress": 10,
          "targetCount": 20,
          "completed": false,
          "rewardGranted": false,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddItemScreen(
                      apiClient: apiClient,
                      imagePicker: mockPicker,
                    ),
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text("Choose from Gallery"));
        await Future<void>.delayed(const Duration(milliseconds: 2000));
      });
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();

      expect(find.text("Closet Safari Complete!"), findsNothing);
    });
  });
}
