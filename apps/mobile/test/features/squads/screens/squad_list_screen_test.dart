import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";
import "package:vestiaire_mobile/src/features/squads/models/squad.dart";
import "package:vestiaire_mobile/src/features/squads/screens/squad_list_screen.dart";
import "package:vestiaire_mobile/src/features/squads/services/ootd_service.dart";
import "package:vestiaire_mobile/src/features/squads/services/squad_service.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

ApiClient _makeApiClient() => ApiClient(
      baseUrl: "http://localhost",
      authService: _TestAuthService(),
    );

/// Mock SquadService for testing.
class MockSquadService extends SquadService {
  MockSquadService({
    this.squadsToReturn = const [],
    this.createResult,
    this.joinResult,
    this.joinError,
  }) : super(apiClient: _makeApiClient());

  final List<Squad> squadsToReturn;
  final Squad? createResult;
  final Squad? joinResult;
  final Exception? joinError;

  @override
  Future<List<Squad>> listMySquads() async {
    return squadsToReturn;
  }

  @override
  Future<Squad> createSquad({required String name, String? description}) async {
    return createResult ??
        Squad(
          id: "new-squad",
          name: name,
          description: description,
          inviteCode: "NEWCODE1",
          createdBy: "p1",
          createdAt: DateTime(2026, 3, 19),
          memberCount: 1,
        );
  }

  @override
  Future<Squad> joinSquad({required String inviteCode}) async {
    if (joinError != null) throw joinError!;
    return joinResult ??
        Squad(
          id: "joined-squad",
          name: "Joined Squad",
          inviteCode: inviteCode,
          createdBy: "p2",
          createdAt: DateTime(2026, 3, 19),
          memberCount: 3,
        );
  }

  @override
  Future<Squad> getSquad(String squadId) async {
    return squadsToReturn.firstWhere(
      (s) => s.id == squadId,
      orElse: () => Squad(
        id: squadId,
        name: "Squad",
        inviteCode: "CODE1234",
        createdBy: "p1",
        createdAt: DateTime(2026, 3, 19),
        memberCount: 1,
      ),
    );
  }

  @override
  Future<List<SquadMember>> listMembers(String squadId) async => [];
}

class MockOotdServiceForList extends OotdService {
  MockOotdServiceForList({
    this.feedPosts = const [],
  }) : super(apiClient: _makeApiClient());

  final List<OotdPost> feedPosts;

  @override
  Future<Map<String, dynamic>> listFeedPosts({
    int limit = 20,
    String? cursor,
  }) async {
    return {"posts": feedPosts, "nextCursor": null};
  }

  @override
  Future<Map<String, dynamic>> listSquadPosts(
    String squadId, {
    int limit = 20,
    String? cursor,
  }) async {
    return {"posts": feedPosts, "nextCursor": null};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("SquadListScreen", () {
    testWidgets("renders empty state with Create and Join buttons when no squads",
        (tester) async {
      final service = MockSquadService(squadsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Your Style Squads"), findsOneWidget);
      expect(
        find.text(
          "Create a squad or join one with an invite code to start sharing outfits with friends.",
        ),
        findsOneWidget,
      );
      expect(find.text("Create Squad"), findsOneWidget);
      expect(find.text("Join Squad"), findsOneWidget);
    });

    testWidgets("renders squad cards with name and member count",
        (tester) async {
      final squads = [
        Squad(
          id: "s1",
          name: "Fashion Friends",
          inviteCode: "CODE0001",
          createdBy: "p1",
          createdAt: DateTime(2026, 3, 19),
          memberCount: 5,
          lastActivity: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Squad(
          id: "s2",
          name: "Style Squad",
          inviteCode: "CODE0002",
          createdBy: "p2",
          createdAt: DateTime(2026, 3, 18),
          memberCount: 12,
          lastActivity: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      final service = MockSquadService(squadsToReturn: squads);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Fashion Friends"), findsOneWidget);
      expect(find.text("5 members"), findsOneWidget);
      expect(find.text("Style Squad"), findsOneWidget);
      expect(find.text("12 members"), findsOneWidget);
    });

    testWidgets("tapping Create Squad opens create dialog", (tester) async {
      final service = MockSquadService(squadsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text("Create Squad"));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Squad Name"), findsOneWidget);
      expect(find.text("Description (optional)"), findsOneWidget);
      expect(find.text("Create"), findsOneWidget);
    });

    testWidgets("create form validates name is required", (tester) async {
      final service = MockSquadService(squadsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Create Squad"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Create"));
      await tester.pumpAndSettle();

      expect(find.text("Name is required"), findsOneWidget);
    });

    testWidgets("tapping Join Squad opens join dialog", (tester) async {
      final service = MockSquadService(squadsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text("Join Squad"));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Invite Code"), findsOneWidget);
      expect(find.text("Join"), findsOneWidget);
    });

    testWidgets("semantics labels present on squad cards and buttons",
        (tester) async {
      final squads = [
        Squad(
          id: "s1",
          name: "My Squad",
          inviteCode: "CODE0001",
          createdBy: "p1",
          createdAt: DateTime(2026, 3, 19),
          memberCount: 3,
        ),
      ];

      final service = MockSquadService(squadsToReturn: squads);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Squad: My Squad, 3 members",
        ),
        findsOneWidget,
      );
    });

    testWidgets("empty state has semantics on icon", (tester) async {
      final service = MockSquadService(squadsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(squadService: service),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Style squads icon",
        ),
        findsOneWidget,
      );
    });

    // Story 9.3: Feed tab tests
    testWidgets("feed tab is visible when ootdService is provided",
        (tester) async {
      final squadService = MockSquadService(squadsToReturn: []);
      final ootdService = MockOotdServiceForList();

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(
            squadService: squadService,
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("My Squads"), findsOneWidget);
      expect(find.text("Feed"), findsOneWidget);
    });

    testWidgets("tapping Feed tab shows feed screen", (tester) async {
      final squads = [
        Squad(
          id: "s1",
          name: "Fashion Friends",
          inviteCode: "CODE0001",
          createdBy: "p1",
          createdAt: DateTime(2026, 3, 19),
          memberCount: 5,
        ),
      ];
      final squadService = MockSquadService(squadsToReturn: squads);
      final ootdService = MockOotdServiceForList();

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(
            squadService: squadService,
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Feed tab
      await tester.tap(find.text("Feed"));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Feed screen content should be visible (empty state or feed)
      // Since ootdService returns empty posts, empty state shows
      expect(find.text("No posts yet"), findsOneWidget);
    });

    testWidgets("both My Squads and Feed tabs render correctly",
        (tester) async {
      final squads = [
        Squad(
          id: "s1",
          name: "Fashion Friends",
          inviteCode: "CODE0001",
          createdBy: "p1",
          createdAt: DateTime(2026, 3, 19),
          memberCount: 5,
        ),
      ];
      final squadService = MockSquadService(squadsToReturn: squads);
      final ootdService = MockOotdServiceForList();

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(
            squadService: squadService,
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // My Squads tab shows squad list
      expect(find.text("Fashion Friends"), findsOneWidget);

      // Switch to Feed tab
      await tester.tap(find.text("Feed"));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Feed tab content
      expect(find.text("No posts yet"), findsOneWidget);

      // Switch back to My Squads
      await tester.tap(find.text("My Squads"));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Fashion Friends"), findsOneWidget);
    });

    testWidgets("no tabs when ootdService is not provided", (tester) async {
      final squadService = MockSquadService(squadsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadListScreen(
            squadService: squadService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // No tab bar
      expect(find.text("My Squads"), findsNothing);
      expect(find.text("Feed"), findsNothing);
      // But still shows the social screen
      expect(find.text("Social"), findsOneWidget);
    });
  });
}
