import "dart:convert";

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
import "package:vestiaire_mobile/src/features/wardrobe/screens/wardrobe_screen.dart";
import "package:vestiaire_mobile/src/features/wardrobe/widgets/filter_bar.dart";

/// AuthService that returns a test token without requiring Firebase sign-in.
class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

ApiClient _buildMockApiClient({
  List<Map<String, dynamic>> items = const [],
  bool shouldFail = false,
  List<List<Map<String, dynamic>>>? itemSequence,
  bool healthScoreFail = false,
  Map<String, dynamic>? healthScoreData,
}) {
  int callCount = 0;
  final mockHttp = http_testing.MockClient((request) async {
    // Health score endpoint
    if (request.url.path == "/v1/analytics/wardrobe-health") {
      if (healthScoreFail || shouldFail) {
        return http.Response(
          jsonEncode({"code": "ERROR", "message": "fail"}),
          500,
        );
      }
      return http.Response(
        jsonEncode(healthScoreData ?? {
          "score": 65,
          "factors": {
            "utilizationScore": 50.0,
            "cpwScore": 60.0,
            "sizeUtilizationScore": 50.0,
          },
          "percentile": 35,
          "recommendation": "Wear 6 more items this month to reach Green status",
          "totalItems": 20,
          "itemsWorn90d": 10,
          "colorTier": "yellow",
        }),
        200,
      );
    }
    if (shouldFail) {
      return http.Response(
        jsonEncode({"code": "ERROR", "message": "fail"}),
        500,
      );
    }
    if (itemSequence != null) {
      final idx = callCount < itemSequence.length
          ? callCount
          : itemSequence.length - 1;
      callCount++;
      return http.Response(
        jsonEncode({"items": itemSequence[idx]}),
        200,
      );
    }
    return http.Response(
      jsonEncode({"items": items}),
      200,
    );
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

  group("WardrobeScreen", () {
    testWidgets("shows loading indicator while fetching", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: _buildMockApiClient()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("shows empty state when no items", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: _buildMockApiClient()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Your wardrobe is empty.\nTap + to add your first item!"),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.checkroom), findsOneWidget);
    });

    testWidgets("shows items in a grid when data is returned",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
        {
          "id": "2",
          "photo_url": "https://example.com/2.jpg",
          "name": null,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "View Blue Shirt",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "View Item",
        ),
        findsOneWidget,
      );
    });

    testWidgets("shows error state with retry button on fetch failure",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(shouldFail: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Failed to load items."), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("retry button reloads items", (tester) async {
      int callCount = 0;
      final mockHttp = http_testing.MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({"code": "ERROR", "message": "fail"}),
            500,
          );
        }
        return http.Response(jsonEncode({"items": []}), 200);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(home: WardrobeScreen(apiClient: apiClient)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Failed to load items."), findsOneWidget);

      await tester.tap(find.text("Retry"));
      await tester.pumpAndSettle();

      expect(
        find.text("Your wardrobe is empty.\nTap + to add your first item!"),
        findsOneWidget,
      );
    });

    // === Story 2.2: Background removal UI tests ===

    testWidgets("shows shimmer overlay for pending items", (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Pending Shirt",
          "bgRemovalStatus": "pending",
        },
        {
          "id": "2",
          "profileId": "p1",
          "photoUrl": "https://example.com/2.jpg",
          "name": "Normal Shirt",
          "bgRemovalStatus": "completed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() because shimmer animation repeats forever
      await tester.pump();
      await tester.pump();

      // Should find ShaderMask (used by shimmer overlay) for the pending item
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets("shows warning badge for failed items", (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Failed Shirt",
          "bgRemovalStatus": "failed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find the warning icon for failed items
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets("no warning badge or shimmer for completed items",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Good Shirt",
          "bgRemovalStatus": "completed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets("no warning badge or shimmer for null status items",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Old Shirt",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets("failed item long-press shows retry option", (tester) async {
      final items = [
        {
          "id": "item-1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Failed Shirt",
          "bgRemovalStatus": "failed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press the failed item tile (find by Semantics label)
      await tester.longPress(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "View Failed Shirt",
      ));
      await tester.pumpAndSettle();

      // Bottom sheet should appear with retry option
      expect(find.text("Retry Background Removal"), findsOneWidget);
    });

    testWidgets("polling stops after status changes from pending",
        (tester) async {
      // First call: items with pending status
      // Second call: items with completed status (after polling)
      final apiClient = _buildMockApiClient(
        itemSequence: [
          [
            {
              "id": "1",
              "profileId": "p1",
              "photoUrl": "https://example.com/1.jpg",
              "name": "Processing",
              "bgRemovalStatus": "pending",
            },
          ],
          [
            {
              "id": "1",
              "profileId": "p1",
              "photoUrl": "https://example.com/1_cleaned.jpg",
              "name": "Processing",
              "bgRemovalStatus": "completed",
            },
          ],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: apiClient),
        ),
      );
      // Use pump() instead of pumpAndSettle() because shimmer animation repeats
      await tester.pump();
      await tester.pump();

      // Initially should show shimmer (pending)
      expect(find.byType(ShaderMask), findsOneWidget);

      // Simulate polling timer firing
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // After poll, status changed to completed - no more shimmer
      expect(find.byType(ShaderMask), findsNothing);
    });

    // === Story 2.3: Categorization UI tests ===

    testWidgets(
        "shows shimmer overlay for categorization pending items",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Categorizing Shirt",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "pending",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      // Use pump() because shimmer animation repeats
      await tester.pump();
      await tester.pump();

      // Should find ShaderMask for categorization pending shimmer
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets(
        "shows info icon badge for categorization failed items",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Failed Cat Shirt",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "failed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find the info icon for categorization failed items
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets(
        "shows category label for categorization completed items",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "My Jacket",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "completed",
          "category": "outerwear",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find the formatted category label
      expect(find.text("Outerwear"), findsOneWidget);
    });

    testWidgets(
        "long-press on categorization failed item shows Retry Categorization",
        (tester) async {
      final items = [
        {
          "id": "item-1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Cat Failed Shirt",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "failed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press the failed categorization item tile (find by Semantics label)
      await tester.longPress(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "View Cat Failed Shirt",
      ));
      await tester.pumpAndSettle();

      // Bottom sheet should appear with retry categorization option
      expect(find.text("Retry Categorization"), findsOneWidget);
    });

    testWidgets(
        "polling is triggered when items have categorization pending",
        (tester) async {
      final apiClient = _buildMockApiClient(
        itemSequence: [
          [
            {
              "id": "1",
              "profileId": "p1",
              "photoUrl": "https://example.com/1.jpg",
              "name": "Categorizing",
              "bgRemovalStatus": "completed",
              "categorizationStatus": "pending",
            },
          ],
          [
            {
              "id": "1",
              "profileId": "p1",
              "photoUrl": "https://example.com/1.jpg",
              "name": "Categorizing",
              "bgRemovalStatus": "completed",
              "categorizationStatus": "completed",
              "category": "tops",
            },
          ],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: apiClient),
        ),
      );
      // Use pump() because shimmer animation repeats
      await tester.pump();
      await tester.pump();

      // Initially should show shimmer (categorization pending)
      expect(find.byType(ShaderMask), findsOneWidget);

      // Simulate polling timer firing
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // After poll, categorization completed - no more shimmer, category label shown
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text("Tops"), findsOneWidget);
    });

    testWidgets("displayLabel is used for Semantics label", (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "category": "dresses",
          "categorizationStatus": "completed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When name is null, displayLabel falls back to category
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "View dresses",
        ),
        findsOneWidget,
      );
    });

    // === Story 2.5: FilterBar and filtering tests ===

    testWidgets("FilterBar is rendered above the grid when items exist",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Shirt",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FilterBar should be present
      expect(find.byType(FilterBar), findsOneWidget);
      // Grid should also be present
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets("item count shows correct count when unfiltered",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Shirt",
        },
        {
          "id": "2",
          "profileId": "p1",
          "photoUrl": "https://example.com/2.jpg",
          "name": "Pants",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("2 items"), findsOneWidget);
    });

    testWidgets(
        "applying a filter calls apiClient.listItems with filter parameter",
        (tester) async {
      final requestUrls = <String>[];

      final mockHttp = http_testing.MockClient((request) async {
        requestUrls.add(request.url.toString());
        return http.Response(
          jsonEncode({
            "items": [
              {
                "id": "1",
                "profileId": "p1",
                "photoUrl": "https://example.com/1.jpg",
                "name": "Blue Shirt",
                "category": "tops",
              },
            ]
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(home: WardrobeScreen(apiClient: apiClient)),
      );
      await tester.pumpAndSettle();

      // Tap Category filter chip
      await tester.tap(find.widgetWithText(FilterChip, "Category"));
      await tester.pumpAndSettle();

      // Select "Tops"
      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      // Verify that a filtered request was made
      final filteredRequests = requestUrls
          .where((url) => url.contains("category=tops"))
          .toList();
      expect(filteredRequests, isNotEmpty);
    });

    testWidgets(
        "filtered empty state shows 'No items match your filters' with Clear Filters button",
        (tester) async {
      final mockHttp = http_testing.MockClient((request) async {
        final url = request.url.toString();
        // First call: unfiltered, returns items
        // After filter: unfiltered call returns items, filtered call returns empty
        if (url.contains("category=")) {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        return http.Response(
          jsonEncode({
            "items": [
              {
                "id": "1",
                "profileId": "p1",
                "photoUrl": "https://example.com/1.jpg",
                "name": "Shirt",
                "category": "bottoms",
              },
            ]
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(home: WardrobeScreen(apiClient: apiClient)),
      );
      await tester.pumpAndSettle();

      // Tap Category filter chip
      await tester.tap(find.widgetWithText(FilterChip, "Category"));
      await tester.pumpAndSettle();

      // Select "Tops" - which will return no items
      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      // Should show filtered empty state
      expect(find.text("No items match your filters"), findsOneWidget);
      expect(find.text("Clear Filters"), findsOneWidget);
    });

    testWidgets(
        "Clear Filters button resets filters and reloads items",
        (tester) async {
      final mockHttp = http_testing.MockClient((request) async {
        final url = request.url.toString();
        if (url.contains("category=")) {
          return http.Response(jsonEncode({"items": []}), 200);
        }
        return http.Response(
          jsonEncode({
            "items": [
              {
                "id": "1",
                "profileId": "p1",
                "photoUrl": "https://example.com/1.jpg",
                "name": "Shirt",
              },
            ]
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(home: WardrobeScreen(apiClient: apiClient)),
      );
      await tester.pumpAndSettle();

      // Apply a filter that returns empty
      await tester.tap(find.widgetWithText(FilterChip, "Category"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      expect(find.text("No items match your filters"), findsOneWidget);

      // Tap Clear Filters button
      await tester.tap(find.text("Clear Filters"));
      await tester.pumpAndSettle();

      // Should reload unfiltered items
      expect(find.text("No items match your filters"), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets("item count shows 'X of Y items' when filtered",
        (tester) async {
      final mockHttp = http_testing.MockClient((request) async {
        final url = request.url.toString();
        if (url.contains("category=tops")) {
          return http.Response(
            jsonEncode({
              "items": [
                {
                  "id": "1",
                  "profileId": "p1",
                  "photoUrl": "https://example.com/1.jpg",
                  "name": "Blue Top",
                  "category": "tops",
                },
              ]
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            "items": [
              {
                "id": "1",
                "profileId": "p1",
                "photoUrl": "https://example.com/1.jpg",
                "name": "Blue Top",
                "category": "tops",
              },
              {
                "id": "2",
                "profileId": "p1",
                "photoUrl": "https://example.com/2.jpg",
                "name": "Black Pants",
                "category": "bottoms",
              },
              {
                "id": "3",
                "profileId": "p1",
                "photoUrl": "https://example.com/3.jpg",
                "name": "Red Dress",
                "category": "dresses",
              },
            ]
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:3000",
        authService: _TestAuthService(),
        httpClient: mockHttp,
      );

      await tester.pumpWidget(
        MaterialApp(home: WardrobeScreen(apiClient: apiClient)),
      );
      await tester.pumpAndSettle();

      // Initially: unfiltered
      expect(find.text("3 items"), findsOneWidget);

      // Apply filter
      await tester.tap(find.widgetWithText(FilterChip, "Category"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      // Should show "1 of 3 items"
      expect(find.text("1 of 3 items"), findsOneWidget);
    });

    // === Story 2.6: Tap navigation to ItemDetailScreen ===

    testWidgets("tapping an item tile navigates to ItemDetailScreen",
        (tester) async {
      final mockHttp = http_testing.MockClient((request) async {
        final path = request.url.path;
        final method = request.method;
        // GET /v1/items (list)
        if (method == "GET" && path == "/v1/items") {
          return http.Response(
            jsonEncode({
              "items": [
                {
                  "id": "item-1",
                  "profileId": "p1",
                  "photoUrl": "https://example.com/1.jpg",
                  "name": "Blue Shirt",
                  "category": "tops",
                  "bgRemovalStatus": "completed",
                  "categorizationStatus": "completed",
                },
              ]
            }),
            200,
          );
        }
        // GET /v1/items/:id (single item for detail screen)
        if (method == "GET" && path.startsWith("/v1/items/")) {
          return http.Response(
            jsonEncode({
              "item": {
                "id": "item-1",
                "profileId": "p1",
                "photoUrl": "https://example.com/1.jpg",
                "name": "Blue Shirt",
                "category": "tops",
                "bgRemovalStatus": "completed",
                "categorizationStatus": "completed",
                "isFavorite": false,
              }
            }),
            200,
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
        MaterialApp(home: WardrobeScreen(apiClient: apiClient)),
      );
      await tester.pumpAndSettle();

      // Tap the item tile
      await tester.tap(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "View Blue Shirt",
      ));
      await tester.pumpAndSettle();

      // Should navigate to ItemDetailScreen (shows the item name or "Item Detail" in AppBar)
      // Verify we're on ItemDetailScreen by finding the favorite icon
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    // === Story 2.7: Neglect badge tests ===

    testWidgets("neglect badge is displayed on items with neglectStatus=neglected",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Old Shirt",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "completed",
          "category": "tops",
          "neglectStatus": "neglected",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Neglected"), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets("neglect badge is NOT displayed on items with neglectStatus=null",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "New Shirt",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "completed",
          "category": "tops",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Neglected"), findsNothing);
    });

    testWidgets("neglect badge has correct Semantics label",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Old Shirt",
          "bgRemovalStatus": "completed",
          "categorizationStatus": "completed",
          "neglectStatus": "neglected",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Neglected item",
        ),
        findsOneWidget,
      );
    });

    testWidgets("neglect badge is NOT shown on items still processing",
        (tester) async {
      final items = [
        {
          "id": "1",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Processing Shirt",
          "bgRemovalStatus": "pending",
          "neglectStatus": "neglected",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() because shimmer animation repeats
      await tester.pump();
      await tester.pump();

      // The neglect badge text should NOT appear since item is still processing
      expect(find.text("Neglected"), findsNothing);
    });

    testWidgets("existing long-press behavior on failed items still works",
        (tester) async {
      final items = [
        {
          "id": "item-fail",
          "profileId": "p1",
          "photoUrl": "https://example.com/1.jpg",
          "name": "Failed Item",
          "bgRemovalStatus": "failed",
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press the failed item - should show retry menu
      await tester.longPress(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "View Failed Item",
      ));
      await tester.pumpAndSettle();

      expect(find.text("Retry Background Removal"), findsOneWidget);
    });

    // === Story 10.1: Bulk Import entry point tests ===

    testWidgets("Bulk Import button is visible on the wardrobe screen",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: _buildMockApiClient()),
        ),
      );
      await tester.pumpAndSettle();

      // The Bulk Import icon button should be present in the AppBar
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.byTooltip("Bulk Import"), findsOneWidget);
    });

    testWidgets("Bulk Import button has correct Semantics label",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: _buildMockApiClient()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Bulk Import",
        ),
        findsOneWidget,
      );
    });

    testWidgets("tapping Bulk Import calls ImagePicker.pickMultiImage",
        (tester) async {
      bool pickMultiImageCalled = false;

      final mockPicker = _MockImagePicker(
        onPickMultiImage: () {
          pickMultiImageCalled = true;
          return [];
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the bulk import button
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      expect(pickMultiImageCalled, isTrue);
    });

    testWidgets("when picker returns empty list, no navigation occurs",
        (tester) async {
      final mockPicker = _MockImagePicker(
        onPickMultiImage: () => [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      // Should still be on the wardrobe screen
      expect(find.text("Wardrobe"), findsOneWidget);
      expect(find.text("Bulk Import Preview"), findsNothing);
    });

    testWidgets("when picker returns > 50 images, truncation SnackBar is shown",
        (tester) async {
      // Create 60 fake XFile paths
      final mockPicker = _MockImagePicker(
        onPickMultiImage: () => List.generate(
          60,
          (i) => XFile("/tmp/test_truncate_$i.jpg"),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      // SnackBar with truncation warning should appear
      expect(
        find.text("Maximum 50 photos. Only the first 50 were selected."),
        findsOneWidget,
      );
    });

    testWidgets("when picker throws PlatformException, permission error SnackBar shown",
        (tester) async {
      final mockPicker = _MockImagePicker(
        shouldThrowPlatformException: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(),
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Photo library access required. Please grant access in Settings.",
        ),
        findsOneWidget,
      );
    });

    // --- Mini Health Bar tests ---

    testWidgets("mini health bar renders with correct score and color",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Health bar should show score
      expect(find.text("65"), findsOneWidget);
      expect(find.text("Yellow"), findsOneWidget);
    });

    testWidgets("mini health bar shows recommendation text",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Wear 6 more items this month to reach Green status"),
        findsOneWidget,
      );
    });

    testWidgets("tapping mini health bar navigates to AnalyticsDashboardScreen",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the mini health bar
      await tester.tap(find.text("65"));
      await tester.pumpAndSettle();

      // Should navigate to Analytics dashboard
      expect(find.text("Analytics"), findsOneWidget);
    });

    testWidgets("mini health bar hidden when API call fails",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(
            apiClient: _buildMockApiClient(
              items: items,
              healthScoreFail: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mini health bar should NOT be visible
      expect(find.text("Yellow"), findsNothing);
      expect(find.text("Green"), findsNothing);
      expect(find.text("Red"), findsNothing);
      // But items should still show
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets("existing wardrobe grid tests continue to pass",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
        {
          "id": "2",
          "photo_url": "https://example.com/2.jpg",
          "name": "Red Pants",
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: _buildMockApiClient(items: items)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets("Spring Clean entry point is visible near the mini health bar",
        (tester) async {
      final items = [
        {
          "id": "1",
          "photo_url": "https://example.com/1.jpg",
          "name": "Blue Shirt",
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: WardrobeScreen(apiClient: _buildMockApiClient(items: items)),
        ),
      );
      await tester.pumpAndSettle();

      // The Spring Clean icon button should be visible near the mini health bar
      expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
    });
  });
}

/// Mock ImagePicker for testing bulk import flow.
class _MockImagePicker extends ImagePicker {
  _MockImagePicker({
    this.onPickMultiImage,
    this.shouldThrowPlatformException = false,
  });

  final List<XFile> Function()? onPickMultiImage;
  final bool shouldThrowPlatformException;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    if (shouldThrowPlatformException) {
      throw PlatformException(code: "photo_access_denied", message: "Access denied");
    }
    return onPickMultiImage?.call() ?? [];
  }
}
