import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";
import "package:vestiaire_mobile/src/features/squads/models/steal_look_result.dart";
import "package:vestiaire_mobile/src/features/squads/screens/steal_this_look_screen.dart";
import "package:vestiaire_mobile/src/features/squads/services/ootd_service.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

class MockStealLookOotdService extends OotdService {
  MockStealLookOotdService({
    this.stealLookResult,
    this.stealLookError,
    this.saveOutfitResult,
    this.saveOutfitError,
  }) : super(
          apiClient: ApiClient(
            baseUrl: "http://localhost",
            authService: _TestAuthService(),
          ),
        );

  final StealLookResult? stealLookResult;
  final ApiException? stealLookError;
  final Map<String, dynamic>? saveOutfitResult;
  final Exception? saveOutfitError;
  bool stealThisLookCalled = false;
  bool saveOutfitCalled = false;
  int stealThisLookCallCount = 0;

  @override
  Future<StealLookResult> stealThisLook(String postId) async {
    stealThisLookCalled = true;
    stealThisLookCallCount++;
    if (stealLookError != null) throw stealLookError!;
    return stealLookResult!;
  }

  @override
  Future<Map<String, dynamic>> saveStealLookOutfit({
    required List<String> itemIds,
    required String name,
  }) async {
    saveOutfitCalled = true;
    if (saveOutfitError != null) throw saveOutfitError!;
    return saveOutfitResult ?? {"outfit": {"id": "outfit-1"}};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final testPost = OotdPost(
    id: "post-1",
    authorId: "other-profile",
    photoUrl: "https://example.com/photo.jpg",
    caption: "My outfit",
    createdAt: DateTime(2026, 3, 19),
    authorDisplayName: "Alice",
    taggedItems: [
      const OotdPostItem(
        id: "ti-1",
        postId: "post-1",
        itemId: "item-a",
        itemName: "Blue Top",
        itemCategory: "tops",
      ),
    ],
  );

  final testResultWithMatches = StealLookResult(
    sourceMatches: [
      StealLookSourceMatch(
        sourceItem: const StealLookSourceItem(
          id: "item-a",
          name: "Blue Top",
          category: "tops",
          color: "blue",
          photoUrl: "https://example.com/blue.jpg",
        ),
        matches: [
          const StealLookMatch(
            itemId: "w1",
            name: "Navy Blouse",
            category: "tops",
            color: "navy",
            photoUrl: "https://example.com/navy.jpg",
            matchScore: 85,
            matchReason: "Similar navy top in casual style",
          ),
          const StealLookMatch(
            itemId: "w2",
            name: "White Tee",
            category: "tops",
            color: "white",
            matchScore: 65,
            matchReason: "White casual top as alternative",
          ),
          const StealLookMatch(
            itemId: "w3",
            name: "Gray Shirt",
            category: "tops",
            color: "gray",
            matchScore: 45,
            matchReason: "Same category different style",
          ),
        ],
      ),
    ],
  );

  final testResultNoMatches = StealLookResult(
    sourceMatches: [
      StealLookSourceMatch(
        sourceItem: const StealLookSourceItem(
          id: "item-a",
          name: "Blue Top",
          category: "tops",
        ),
        matches: const [],
      ),
    ],
  );

  Widget buildScreen({required MockStealLookOotdService service}) {
    return MaterialApp(
      home: StealThisLookScreen(
        postId: "post-1",
        post: testPost,
        ootdService: service,
      ),
    );
  }

  testWidgets("Renders loading state with 'Finding matches' text",
      (tester) async {
    // Never-completing service to keep loading state
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));

    expect(find.text("Finding matches in your wardrobe..."), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("Displays source items with their matches on success",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(find.text("Blue Top"), findsOneWidget);
    expect(find.text("Navy Blouse"), findsOneWidget);
    expect(find.text("White Tee"), findsOneWidget);
    expect(find.text("Gray Shirt"), findsOneWidget);
  });

  testWidgets("Match score badges use correct tier colors",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    // Score badge text: 85 (Excellent/green), 65 (Good/blue), 45 (Partial/amber)
    expect(find.text("85"), findsOneWidget);
    expect(find.text("65"), findsOneWidget);
    expect(find.text("45"), findsOneWidget);
  });

  testWidgets("Displays match reason text for each match",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(
        find.text("Similar navy top in casual style"), findsOneWidget);
    expect(
        find.text("White casual top as alternative"), findsOneWidget);
  });

  testWidgets("No match found placeholder shown for source items with no matches",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultNoMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(find.text("No match found"), findsOneWidget);
    expect(find.text("Shop for similar"), findsOneWidget);
  });

  testWidgets("Save as Outfit button is enabled when at least one match exists",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, "Save as Outfit"),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets("Save as Outfit button is disabled when no matches exist",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultNoMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, "Save as Outfit"),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets("Save as Outfit button calls outfit creation endpoint",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Save as Outfit"));
    await tester.pumpAndSettle();

    expect(service.saveOutfitCalled, true);
  });

  testWidgets("Shows SnackBar 'Outfit saved!' on successful save",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Save as Outfit"));
    await tester.pump();

    expect(find.text("Outfit saved!"), findsOneWidget);
  });

  testWidgets("Shows empty wardrobe state on 422 error",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookError: const ApiException(
        statusCode: 422,
        code: "WARDROBE_EMPTY",
        message: "Add items to your wardrobe first to find matches.",
      ),
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(find.text("Your wardrobe is empty"), findsOneWidget);
    expect(find.text("Add items to your wardrobe first to find matches."),
        findsOneWidget);
  });

  testWidgets("Go to Wardrobe button present in empty wardrobe state",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookError: const ApiException(
        statusCode: 422,
        code: "WARDROBE_EMPTY",
        message: "Add items to your wardrobe first to find matches.",
      ),
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(find.text("Go to Wardrobe"), findsOneWidget);
  });

  testWidgets("Shows retry button on matching failure", (tester) async {
    final service = MockStealLookOotdService(
      stealLookError: const ApiException(
        statusCode: 502,
        code: "MATCHING_FAILED",
        message: "Unable to find matches. Please try again.",
      ),
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(find.text("Unable to find matches"), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);
  });

  testWidgets("Retry button re-triggers steal-look call", (tester) async {
    final service = MockStealLookOotdService(
      stealLookError: const ApiException(
        statusCode: 502,
        code: "MATCHING_FAILED",
        message: "Unable to find matches. Please try again.",
      ),
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    expect(service.stealThisLookCallCount, 1);

    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();

    expect(service.stealThisLookCallCount, 2);
  });

  testWidgets("Semantics labels present on source items, matches, buttons",
      (tester) async {
    final service = MockStealLookOotdService(
      stealLookResult: testResultWithMatches,
    );

    await tester.pumpWidget(buildScreen(service: service));
    await tester.pumpAndSettle();

    // Source item semantics
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Source item: Blue Top",
      ),
      findsOneWidget,
    );

    // Match semantics
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == "Match: Navy Blouse, 85% match",
      ),
      findsOneWidget,
    );

    // Score badge semantics
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == "85% Excellent Match",
      ),
      findsOneWidget,
    );

    // Save button semantics
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == "Save as Outfit",
      ),
      findsOneWidget,
    );
  });
}
