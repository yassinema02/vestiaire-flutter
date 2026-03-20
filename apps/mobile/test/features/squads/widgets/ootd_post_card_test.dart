import "dart:io";

import "package:cached_network_image/cached_network_image.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";
import "package:vestiaire_mobile/src/features/squads/widgets/ootd_post_card.dart";

/// Override HTTP to prevent actual network calls in widget tests.
class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _TestHttpOverrides();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final basePost = OotdPost(
    id: "post-1",
    authorId: "author-1",
    photoUrl: "https://example.com/photo.jpg",
    caption: "My cool outfit today!",
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    authorDisplayName: "Jane Doe",
    authorPhotoUrl: null,
    taggedItems: [
      OotdPostItem(
        id: "ti-1",
        postId: "post-1",
        itemId: "item-1",
        itemName: "Blue Jacket",
        itemPhotoUrl: null,
        itemCategory: "Outerwear",
      ),
      OotdPostItem(
        id: "ti-2",
        postId: "post-1",
        itemId: "item-2",
        itemName: "Black Jeans",
        itemPhotoUrl: null,
        itemCategory: "Bottoms",
      ),
    ],
    squadIds: ["squad-1"],
    reactionCount: 5,
    commentCount: 3,
    hasReacted: false,
  );

  group("OotdPostCard", () {
    testWidgets("renders author name and avatar", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Jane Doe"), findsOneWidget);
      expect(find.text("JD"), findsOneWidget);
    });

    testWidgets("renders post photo", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets("renders caption when present", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("My cool outfit today!"), findsOneWidget);
    });

    testWidgets("hides caption section when caption is null", (tester) async {
      final postNoCaption = OotdPost(
        id: "post-2",
        authorId: "author-1",
        photoUrl: "https://example.com/photo.jpg",
        createdAt: DateTime.now(),
        authorDisplayName: "Jane Doe",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: postNoCaption),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("My cool outfit today!"), findsNothing);
    });

    testWidgets("renders tagged item chips when items present",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Blue Jacket"), findsOneWidget);
      expect(find.text("Black Jeans"), findsOneWidget);
    });

    testWidgets("hides tagged items section when no items", (tester) async {
      final postNoItems = OotdPost(
        id: "post-3",
        authorId: "author-1",
        photoUrl: "https://example.com/photo.jpg",
        createdAt: DateTime.now(),
        authorDisplayName: "Jane Doe",
        taggedItems: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: postNoItems),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Blue Jacket"), findsNothing);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets("renders reaction count and comment count", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("5"), findsOneWidget);
      expect(find.text("3"), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets("renders relative timestamp", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("2h ago"), findsOneWidget);
    });

    testWidgets("tapping card triggers onTap callback", (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: basePost,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(OotdPostCard));
      expect(tapped, isTrue);
    });

    testWidgets("fire icon shows outline when hasReacted is false",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      // The icon should be indigo (not reacted) color
      final icon = tester.widget<Icon>(find.byIcon(Icons.local_fire_department));
      expect(icon.color, const Color(0xFF4F46E5));
    });

    testWidgets("fire icon shows filled/colored when hasReacted is true",
        (tester) async {
      final reactedPost = OotdPost(
        id: "post-1",
        authorId: "author-1",
        photoUrl: "https://example.com/photo.jpg",
        createdAt: DateTime.now(),
        authorDisplayName: "Jane Doe",
        reactionCount: 5,
        commentCount: 3,
        hasReacted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: reactedPost),
            ),
          ),
        ),
      );
      await tester.pump();

      // The icon should be red (reacted) color
      final icon = tester.widget<Icon>(find.byIcon(Icons.local_fire_department));
      expect(icon.color, const Color(0xFFEF4444));
    });

    testWidgets("tapping fire icon triggers onReactionTap callback",
        (tester) async {
      bool reactionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: basePost,
                onReactionTap: () async {
                  reactionTapped = true;
                  return {"reacted": true, "reactionCount": 6};
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.local_fire_department));
      await tester.pump();

      expect(reactionTapped, isTrue);
    });

    testWidgets("optimistic count update on reaction tap", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: basePost,
                onReactionTap: () async {
                  return {"reacted": true, "reactionCount": 6};
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially shows 5
      expect(find.text("5"), findsOneWidget);

      // Tap reaction
      await tester.tap(find.byIcon(Icons.local_fire_department));
      await tester.pump();

      // Optimistically shows 6
      expect(find.text("6"), findsOneWidget);
    });

    // --- Steal This Look button tests (Story 9.5) ---

    testWidgets("Steal This Look icon visible when post has tagged items and onStealLookTap is set",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: basePost,
                onStealLookTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.style), findsOneWidget);
    });

    testWidgets("Steal This Look icon hidden when post has no tagged items",
        (tester) async {
      final postNoItems = OotdPost(
        id: "post-no-items",
        authorId: "author-1",
        photoUrl: "https://example.com/photo.jpg",
        createdAt: DateTime.now(),
        authorDisplayName: "Jane Doe",
        taggedItems: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: postNoItems,
                onStealLookTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.style), findsNothing);
    });

    testWidgets("Tapping steal-look triggers onStealLookTap callback",
        (tester) async {
      bool stealLookTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: basePost,
                onStealLookTap: () => stealLookTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.style));
      expect(stealLookTapped, isTrue);
    });

    testWidgets("Steal This Look icon has correct Semantics label",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(
                post: basePost,
                onStealLookTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel("Steal this look"),
        findsOneWidget,
      );
    });

    testWidgets("semantics labels present on card, photo, author, items, engagement",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OotdPostCard(post: basePost),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Post by Jane Doe",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "OOTD photo by Jane Doe",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Tagged item: Blue Jacket",
        ),
        findsOneWidget,
      );

      // Reaction semantics includes reacted state
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Not reacted: 5",
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Comments: 3",
        ),
        findsOneWidget,
      );
    });
  });
}
