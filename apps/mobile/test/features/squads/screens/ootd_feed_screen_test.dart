import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";
import "package:vestiaire_mobile/src/features/squads/models/squad.dart";
import "package:vestiaire_mobile/src/features/squads/screens/ootd_feed_screen.dart";
import "package:vestiaire_mobile/src/features/squads/services/ootd_service.dart";
import "package:vestiaire_mobile/src/features/squads/services/squad_service.dart";
import "package:vestiaire_mobile/src/features/squads/widgets/ootd_post_card.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

ApiClient _makeApiClient() => ApiClient(
      baseUrl: "http://localhost",
      authService: _TestAuthService(),
    );

class MockFeedOotdService extends OotdService {
  MockFeedOotdService({
    this.feedPosts = const [],
    this.feedNextCursor,
    this.squadPosts = const [],
    this.squadNextCursor,
    this.shouldFail = false,
  }) : super(apiClient: _makeApiClient());

  final List<OotdPost> feedPosts;
  final String? feedNextCursor;
  final List<OotdPost> squadPosts;
  final String? squadNextCursor;
  final bool shouldFail;

  int listFeedPostsCalled = 0;
  int listSquadPostsCalled = 0;
  String? lastSquadId;

  @override
  Future<Map<String, dynamic>> listFeedPosts({
    int limit = 20,
    String? cursor,
  }) async {
    listFeedPostsCalled++;
    if (shouldFail) throw Exception("Feed load failed");
    return {
      "posts": feedPosts,
      "nextCursor": feedNextCursor,
    };
  }

  @override
  Future<Map<String, dynamic>> listSquadPosts(
    String squadId, {
    int limit = 20,
    String? cursor,
  }) async {
    listSquadPostsCalled++;
    lastSquadId = squadId;
    if (shouldFail) throw Exception("Squad posts load failed");
    return {
      "posts": squadPosts,
      "nextCursor": squadNextCursor,
    };
  }
}

class MockFeedSquadService extends SquadService {
  MockFeedSquadService({this.squads = const []})
      : super(apiClient: _makeApiClient());

  final List<Squad> squads;

  @override
  Future<List<Squad>> listMySquads() async => squads;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final testSquads = [
    Squad(
      id: "squad-1",
      name: "Fashion Friends",
      inviteCode: "CODE0001",
      createdBy: "p1",
      createdAt: DateTime(2026, 3, 19),
      memberCount: 5,
    ),
    Squad(
      id: "squad-2",
      name: "Street Crew",
      inviteCode: "CODE0002",
      createdBy: "p2",
      createdAt: DateTime(2026, 3, 19),
      memberCount: 3,
    ),
  ];

  final testPosts = [
    OotdPost(
      id: "post-1",
      authorId: "author-1",
      photoUrl: "https://example.com/photo1.jpg",
      caption: "Outfit one",
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      authorDisplayName: "Alice",
    ),
    OotdPost(
      id: "post-2",
      authorId: "author-2",
      photoUrl: "https://example.com/photo2.jpg",
      caption: "Outfit two",
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      authorDisplayName: "Bob",
    ),
  ];

  group("OotdFeedScreen", () {
    testWidgets("renders loading spinner on initial load", (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: testPosts);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );

      // Before async completes, should show loading
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets("renders feed with post cards when posts available",
        (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: testPosts);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OotdPostCard), findsNWidgets(2));
      expect(find.text("Alice"), findsOneWidget);
      expect(find.text("Bob"), findsOneWidget);
    });

    testWidgets("renders empty state when no posts", (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: []);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("No posts yet"), findsOneWidget);
      expect(
        find.text("Be the first to share your OOTD!"),
        findsOneWidget,
      );
    });

    testWidgets("empty state Post OOTD button is present with apiClient",
        (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: []);
      final squadService = MockFeedSquadService(squads: testSquads);
      final apiClient = _makeApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Post OOTD"), findsOneWidget);
    });

    testWidgets("squad filter chips render with All Squads and squad names",
        (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: testPosts);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("All Squads"), findsOneWidget);
      expect(find.text("Fashion Friends"), findsOneWidget);
      expect(find.text("Street Crew"), findsOneWidget);
    });

    testWidgets("tapping a squad filter chip reloads feed", (tester) async {
      final ootdService = MockFeedOotdService(
        feedPosts: testPosts,
        squadPosts: [testPosts.first],
      );
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text("Fashion Friends"));
      await tester.pump(const Duration(milliseconds: 500));

      expect(ootdService.listSquadPostsCalled, greaterThan(0));
      expect(ootdService.lastSquadId, equals("squad-1"));
    });

    testWidgets("tapping All Squads chip reloads unfiltered feed",
        (tester) async {
      final ootdService = MockFeedOotdService(
        feedPosts: testPosts,
        squadPosts: [testPosts.first],
      );
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
            initialSquadFilter: "squad-1",
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text("All Squads"));
      await tester.pump(const Duration(milliseconds: 500));

      // After tapping All Squads, listFeedPosts should be called
      expect(ootdService.listFeedPostsCalled, greaterThan(0));
    });

    testWidgets("pull-to-refresh triggers reload", (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: testPosts);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final callsBefore = ootdService.listFeedPostsCalled;

      // Pull to refresh on the vertical ListView (the feed list)
      final verticalListView = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      await tester.fling(verticalListView, const Offset(0, 300), 800);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(ootdService.listFeedPostsCalled, greaterThan(callsBefore));
    });

    testWidgets("end-of-feed shows 'You're all caught up' when no more posts",
        (tester) async {
      final ootdService = MockFeedOotdService(
        feedPosts: testPosts,
        feedNextCursor: null, // No more posts
      );
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to see end message
      final verticalListView = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      await tester.drag(verticalListView, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("You're all caught up!"), findsOneWidget);
    });

    testWidgets("error state shows retry option", (tester) async {
      final ootdService = MockFeedOotdService(
        feedPosts: [],
        shouldFail: true,
      );
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Failed to load feed"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("semantics labels on feed, filters, empty state",
        (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: testPosts);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Feed semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "OOTD Feed",
        ),
        findsOneWidget,
      );

      // Filter semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Filter: All Squads",
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Filter: Fashion Friends",
        ),
        findsOneWidget,
      );
    });

    testWidgets("empty state semantics labels", (tester) async {
      final ootdService = MockFeedOotdService(feedPosts: []);
      final squadService = MockFeedSquadService(squads: testSquads);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdFeedScreen(
            ootdService: ootdService,
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "No posts icon",
        ),
        findsOneWidget,
      );
    });
  });
}
