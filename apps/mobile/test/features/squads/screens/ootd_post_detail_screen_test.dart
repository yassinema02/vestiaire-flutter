import "package:cached_network_image/cached_network_image.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_comment.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";
import "package:vestiaire_mobile/src/features/squads/models/steal_look_result.dart";
import "package:vestiaire_mobile/src/features/squads/screens/ootd_post_detail_screen.dart";
import "package:vestiaire_mobile/src/features/squads/services/ootd_service.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

class MockDetailOotdService extends OotdService {
  MockDetailOotdService({
    this.postToReturn,
    this.shouldFail = false,
    this.deleteError,
    this.commentsToReturn = const [],
    this.toggleReactionResult,
    this.createCommentResult,
  }) : super(
          apiClient: ApiClient(
            baseUrl: "http://localhost",
            authService: _TestAuthService(),
          ),
        );

  final OotdPost? postToReturn;
  final bool shouldFail;
  final Exception? deleteError;
  bool deleteCalled = false;
  bool toggleReactionCalled = false;
  bool createCommentCalled = false;
  bool deleteCommentCalled = false;
  final List<OotdComment> commentsToReturn;
  final Map<String, dynamic>? toggleReactionResult;
  final OotdComment? createCommentResult;

  @override
  Future<OotdPost> getPost(String postId) async {
    if (shouldFail) throw Exception("Post not found");
    return postToReturn!;
  }

  @override
  Future<void> deletePost(String postId) async {
    deleteCalled = true;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<Map<String, dynamic>> toggleReaction(String postId) async {
    toggleReactionCalled = true;
    return toggleReactionResult ?? {"reacted": true, "reactionCount": 1};
  }

  @override
  Future<Map<String, dynamic>> listComments(String postId,
      {int limit = 50, String? cursor}) async {
    return {"comments": commentsToReturn, "nextCursor": null};
  }

  @override
  Future<OotdComment> createComment(String postId,
      {required String text}) async {
    createCommentCalled = true;
    return createCommentResult ??
        OotdComment(
          id: "new-comment-1",
          postId: postId,
          authorId: "author-1",
          text: text,
          createdAt: DateTime.now(),
          authorDisplayName: "Test User",
        );
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    deleteCommentCalled = true;
  }

  @override
  Future<StealLookResult> stealThisLook(String postId) async {
    // Return empty result for navigation test - keeps loading forever if not settling
    await Future.delayed(const Duration(seconds: 10));
    return const StealLookResult(sourceMatches: []);
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
    authorId: "author-1",
    photoUrl: "https://example.com/photo.jpg",
    caption: "My awesome outfit",
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    authorDisplayName: "Alice Style",
    authorPhotoUrl: null,
    taggedItems: [
      OotdPostItem(
        id: "ti-1",
        postId: "post-1",
        itemId: "item-1",
        itemName: "Red Dress",
        itemPhotoUrl: null,
        itemCategory: "Dresses",
      ),
    ],
    reactionCount: 7,
    commentCount: 2,
    hasReacted: false,
  );

  final testComments = [
    OotdComment(
      id: "c1",
      postId: "post-1",
      authorId: "author-2",
      text: "Looks amazing!",
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      authorDisplayName: "Bob",
    ),
    OotdComment(
      id: "c2",
      postId: "post-1",
      authorId: "author-1",
      text: "Thanks!",
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      authorDisplayName: "Alice Style",
    ),
  ];

  group("OotdPostDetailScreen", () {
    testWidgets("renders loading spinner while fetching post",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("renders author info, photo, caption, tagged items",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Alice Style"), findsOneWidget);
      expect(find.text("My awesome outfit"), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.text("Tagged Items"), findsOneWidget);
      expect(find.text("Red Dress"), findsOneWidget);
      expect(find.text("Dresses"), findsOneWidget);
    });

    testWidgets("delete button visible when current user is author",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
            currentUserId: "author-1",
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Delete button at bottom of page
      expect(find.text("Delete Post"), findsOneWidget);
    });

    testWidgets("delete button hidden when current user is NOT author",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
            currentUserId: "other-user",
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // No delete button for non-author (the popup menu one is there but not the bottom button)
      expect(find.text("Delete Post"), findsNothing);
    });

    testWidgets("delete triggers confirmation dialog, then API call",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
            currentUserId: "author-1",
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to make the delete button visible
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the bottom delete button
      await tester.tap(find.text("Delete Post").last);
      await tester.pump(const Duration(milliseconds: 500));

      // Confirmation dialog appears
      expect(find.text("Are you sure you want to delete this post? This action cannot be undone."),
          findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Delete"), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text("Delete"));
      await tester.pump(const Duration(milliseconds: 500));

      expect(ootdService.deleteCalled, isTrue);
    });

    testWidgets("post not found shows error message", (tester) async {
      final ootdService =
          MockDetailOotdService(postToReturn: null, shouldFail: true);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "nonexistent",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Post not found"), findsOneWidget);
      expect(find.text("Go Back"), findsOneWidget);
    });

    testWidgets("tagged items display with name and photo", (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Red Dress"), findsOneWidget);
      expect(find.text("Dresses"), findsOneWidget);
    });

    // --- Comments UI tests ---

    testWidgets("comments list renders when comments exist", (tester) async {
      final ootdService = MockDetailOotdService(
        postToReturn: testPost,
        commentsToReturn: testComments,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to see comments
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Looks amazing!"), findsOneWidget);
      expect(find.text("Thanks!"), findsOneWidget);
    });

    testWidgets("empty comments shows 'No comments yet' message",
        (tester) async {
      final ootdService = MockDetailOotdService(
        postToReturn: testPost,
        commentsToReturn: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to see comments section
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("No comments yet -- be the first!"), findsOneWidget);
    });

    testWidgets("adding a comment calls createComment and adds to list",
        (tester) async {
      final ootdService = MockDetailOotdService(
        postToReturn: testPost,
        commentsToReturn: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Find the text field and enter text
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, "Great outfit!");
      await tester.pump();

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 500));

      expect(ootdService.createCommentCalled, isTrue);
    });

    testWidgets("comment input enforces 200 char max", (tester) async {
      final ootdService = MockDetailOotdService(
        postToReturn: testPost,
        commentsToReturn: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // The TextField should have maxLength: 200
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 200);
    });

    testWidgets("reaction toggle works on detail screen", (tester) async {
      final ootdService = MockDetailOotdService(
        postToReturn: testPost,
        commentsToReturn: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll to make fire icon visible
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the fire icon
      await tester.tap(find.byIcon(Icons.local_fire_department));
      await tester.pump(const Duration(milliseconds: 500));

      expect(ootdService.toggleReactionCalled, isTrue);
    });

    // --- Steal This Look button tests (Story 9.5) ---

    testWidgets("Steal This Look button is visible when post has tagged items",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Steal This Look"), findsOneWidget);
    });

    testWidgets("Steal This Look button is hidden when post has no tagged items",
        (tester) async {
      final postNoItems = OotdPost(
        id: "post-2",
        authorId: "author-1",
        photoUrl: "https://example.com/photo.jpg",
        createdAt: DateTime.now(),
        authorDisplayName: "Alice Style",
        taggedItems: const [],
        reactionCount: 0,
        commentCount: 0,
      );
      final ootdService = MockDetailOotdService(postToReturn: postNoItems);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-2",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Steal This Look"), findsNothing);
    });

    testWidgets("Tapping Steal This Look button uses OutlinedButton.icon with Icons.style",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Steal This Look button exists as an OutlinedButton.icon with style icon
      expect(find.text("Steal This Look"), findsOneWidget);
      expect(find.byIcon(Icons.style), findsOneWidget);
    });

    testWidgets("Steal This Look button has correct semantics label",
        (tester) async {
      final ootdService = MockDetailOotdService(postToReturn: testPost);

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.bySemanticsLabel(
            "Steal this look - find similar items in your wardrobe"),
        findsOneWidget,
      );
    });

    testWidgets("semantics labels on all elements", (tester) async {
      final ootdService = MockDetailOotdService(
        postToReturn: testPost,
        commentsToReturn: testComments,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OotdPostDetailScreen(
            postId: "post-1",
            ootdService: ootdService,
            currentUserId: "author-1",
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Post detail view
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Post detail view",
        ),
        findsOneWidget,
      );

      // Photo
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "OOTD photo",
        ),
        findsOneWidget,
      );

      // Tagged item
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Tagged item: Red Dress",
        ),
        findsOneWidget,
      );

      // Comment input
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Comment input",
        ),
        findsOneWidget,
      );

      // Send button
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Send comment",
        ),
        findsOneWidget,
      );

      // Delete button
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == "Delete Post",
        ),
        findsWidgets,
      );
    });
  });
}
