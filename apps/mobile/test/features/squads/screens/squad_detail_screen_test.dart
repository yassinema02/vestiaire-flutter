import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/models/squad.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";
import "package:vestiaire_mobile/src/features/squads/screens/squad_detail_screen.dart";
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

class MockSquadDetailService extends SquadService {
  MockSquadDetailService({
    required this.squad,
    required this.members,
    this.removeCalled = false,
    this.leaveCalled = false,
  }) : super(apiClient: _makeApiClient());

  final Squad squad;
  final List<SquadMember> members;
  bool removeCalled;
  bool leaveCalled;

  @override
  Future<Squad> getSquad(String squadId) async => squad;

  @override
  Future<List<SquadMember>> listMembers(String squadId) async => members;

  @override
  Future<void> removeMember(String squadId, String memberId) async {
    removeCalled = true;
  }

  @override
  Future<void> leaveSquad(String squadId) async {
    leaveCalled = true;
  }

  @override
  Future<List<Squad>> listMySquads() async => [squad];
}

class MockOotdServiceForDetail extends OotdService {
  MockOotdServiceForDetail({
    this.postsToReturn = const [],
  }) : super(apiClient: _makeApiClient());

  final List<OotdPost> postsToReturn;

  @override
  Future<OotdPost> createPost({
    required String photoUrl,
    String? caption,
    required List<String> squadIds,
    List<String> taggedItemIds = const [],
  }) async {
    return OotdPost(
      id: "post-1",
      authorId: "profile-1",
      photoUrl: photoUrl,
      caption: caption,
      createdAt: DateTime(2026, 3, 19),
      squadIds: squadIds,
    );
  }

  @override
  Future<Map<String, dynamic>> listSquadPosts(
    String squadId, {
    int limit = 20,
    String? cursor,
  }) async {
    return {
      "posts": postsToReturn,
      "nextCursor": null,
    };
  }

  @override
  Future<Map<String, dynamic>> listFeedPosts({
    int limit = 20,
    String? cursor,
  }) async {
    return {
      "posts": postsToReturn,
      "nextCursor": null,
    };
  }

  @override
  Future<OotdPost> getPost(String postId) async {
    return postsToReturn.firstWhere((p) => p.id == postId);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final testSquad = Squad(
    id: "squad-1",
    name: "Fashion Friends",
    description: "Our style group",
    inviteCode: "ABCD1234",
    createdBy: "admin-profile",
    createdAt: DateTime(2026, 3, 19),
    memberCount: 3,
  );

  final adminMember = SquadMember(
    id: "m1",
    squadId: "squad-1",
    userId: "admin-profile",
    role: "admin",
    joinedAt: DateTime(2026, 3, 19),
    displayName: "Alice Admin",
    photoUrl: null,
  );

  final regularMember = SquadMember(
    id: "m2",
    squadId: "squad-1",
    userId: "member-profile",
    role: "member",
    joinedAt: DateTime(2026, 3, 19),
    displayName: "Bob Member",
    photoUrl: null,
  );

  final testPosts = [
    OotdPost(
      id: "post-1",
      authorId: "author-1",
      photoUrl: "https://example.com/photo1.jpg",
      caption: "Test outfit",
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      authorDisplayName: "Charlie",
    ),
    OotdPost(
      id: "post-2",
      authorId: "author-2",
      photoUrl: "https://example.com/photo2.jpg",
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      authorDisplayName: "Diana",
    ),
  ];

  group("SquadDetailScreen", () {
    testWidgets("displays squad name, description, and invite code",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember, regularMember],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Fashion Friends"), findsWidgets);
      expect(find.text("Our style group"), findsOneWidget);
      expect(find.text("ABCD1234"), findsOneWidget);
    });

    testWidgets("displays members list with names and role badges",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember, regularMember],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Alice Admin"), findsOneWidget);
      expect(find.text("Bob Member"), findsOneWidget);
      expect(find.text("Admin"), findsOneWidget);
      expect(find.text("Members (2)"), findsOneWidget);
    });

    testWidgets("admin sees remove button on non-admin members",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember, regularMember],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets("non-admin does NOT see remove button", (tester) async {
      final allRegular = [
        SquadMember(
          id: "m1",
          squadId: "squad-1",
          userId: "u1",
          role: "member",
          joinedAt: DateTime(2026, 3, 19),
          displayName: "User 1",
        ),
        SquadMember(
          id: "m2",
          squadId: "squad-1",
          userId: "u2",
          role: "member",
          joinedAt: DateTime(2026, 3, 19),
          displayName: "User 2",
        ),
      ];

      final service = MockSquadDetailService(
        squad: testSquad,
        members: allRegular,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets("remove member triggers confirmation dialog",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember, regularMember],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Remove Member"), findsOneWidget);
      expect(find.text("Remove Bob Member from the squad?"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Remove"), findsOneWidget);
    });

    testWidgets("copy invite code button copies to clipboard",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Invite code copied to clipboard"), findsOneWidget);
    });

    testWidgets("Post OOTD button is visible on squad detail", (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail();

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // May find 2 "Post OOTD" buttons (one in empty posts section, one in OOTD section)
      expect(find.text("Post OOTD"), findsWidgets);
    });

    testWidgets("OOTD section shows share message", (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail();

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Share your outfit with the squad"), findsOneWidget);
    });

    testWidgets("Post OOTD button has semantics label", (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail();

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // May find multiple "Post OOTD" semantics labels (one in empty posts, one in OOTD section)
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Post OOTD",
        ),
        findsWidgets,
      );
    });

    testWidgets("semantics labels on member rows and action buttons",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember, regularMember],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Member: Alice Admin, Admin",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Member: Bob Member, Member",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Invite code: ABCD1234",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Copy invite code",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Share invite",
        ),
        findsOneWidget,
      );
    });

    // Story 9.3: Inline feed integration tests
    testWidgets("recent posts section renders when posts exist",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail(postsToReturn: testPosts);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Recent Posts"), findsOneWidget);
      expect(find.text("See All"), findsOneWidget);
    });

    testWidgets("post cards display in squad detail", (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail(postsToReturn: testPosts);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OotdPostCard), findsNWidgets(2));
      expect(find.text("Charlie"), findsOneWidget);
      expect(find.text("Diana"), findsOneWidget);
    });

    testWidgets("empty posts shows 'No posts yet' inline message",
        (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail(postsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text("No posts yet -- share your first OOTD!"),
        findsOneWidget,
      );
    });

    testWidgets("See All link is visible when posts exist", (tester) async {
      final service = MockSquadDetailService(
        squad: testSquad,
        members: [adminMember],
      );
      final ootdService = MockOotdServiceForDetail(postsToReturn: testPosts);

      await tester.pumpWidget(
        MaterialApp(
          home: SquadDetailScreen(
            squadId: "squad-1",
            squadService: service,
            ootdService: ootdService,
            apiClient: _makeApiClient(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("See All"), findsOneWidget);
    });
  });
}
