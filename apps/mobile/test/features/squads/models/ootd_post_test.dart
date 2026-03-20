import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_post.dart";

void main() {
  group("OotdPost.fromJson", () {
    test("parses all fields correctly", () {
      final json = {
        "id": "post-1",
        "authorId": "profile-1",
        "photoUrl": "https://storage.example.com/photo.jpg",
        "caption": "My outfit today",
        "createdAt": "2026-03-19T00:00:00.000Z",
        "authorDisplayName": "Alice",
        "authorPhotoUrl": "https://storage.example.com/avatar.jpg",
        "taggedItems": [
          {
            "id": "ti-1",
            "postId": "post-1",
            "itemId": "item-1",
            "itemName": "Blue Jacket",
            "itemPhotoUrl": "https://storage.example.com/jacket.jpg",
            "itemCategory": "outerwear",
          }
        ],
        "squadIds": ["squad-1", "squad-2"],
        "reactionCount": 5,
        "commentCount": 3,
      };

      final post = OotdPost.fromJson(json);

      expect(post.id, "post-1");
      expect(post.authorId, "profile-1");
      expect(post.photoUrl, "https://storage.example.com/photo.jpg");
      expect(post.caption, "My outfit today");
      expect(post.createdAt, DateTime.utc(2026, 3, 19));
      expect(post.authorDisplayName, "Alice");
      expect(post.authorPhotoUrl, "https://storage.example.com/avatar.jpg");
      expect(post.taggedItems.length, 1);
      expect(post.taggedItems[0].itemName, "Blue Jacket");
      expect(post.squadIds.length, 2);
      expect(post.reactionCount, 5);
      expect(post.commentCount, 3);
    });

    test("handles null caption and authorPhotoUrl", () {
      final json = {
        "id": "post-2",
        "authorId": "profile-1",
        "photoUrl": "https://storage.example.com/photo.jpg",
        "caption": null,
        "createdAt": "2026-03-19T00:00:00.000Z",
        "authorDisplayName": "Alice",
        "authorPhotoUrl": null,
        "taggedItems": [],
        "squadIds": ["squad-1"],
        "reactionCount": 0,
        "commentCount": 0,
      };

      final post = OotdPost.fromJson(json);

      expect(post.caption, null);
      expect(post.authorPhotoUrl, null);
    });

    test("parses taggedItems array", () {
      final json = {
        "id": "post-3",
        "authorId": "profile-1",
        "photoUrl": "https://storage.example.com/photo.jpg",
        "createdAt": "2026-03-19T00:00:00.000Z",
        "taggedItems": [
          {
            "id": "ti-1",
            "postId": "post-3",
            "itemId": "item-1",
            "itemName": "Blue Jacket",
            "itemPhotoUrl": null,
            "itemCategory": "outerwear",
          },
          {
            "id": "ti-2",
            "postId": "post-3",
            "itemId": "item-2",
            "itemName": "White Sneakers",
            "itemPhotoUrl": "https://storage.example.com/sneakers.jpg",
            "itemCategory": "shoes",
          },
        ],
        "squadIds": ["squad-1"],
      };

      final post = OotdPost.fromJson(json);

      expect(post.taggedItems.length, 2);
      expect(post.taggedItems[0].itemId, "item-1");
      expect(post.taggedItems[1].itemId, "item-2");
    });

    test("handles empty taggedItems", () {
      final json = {
        "id": "post-4",
        "authorId": "profile-1",
        "photoUrl": "https://storage.example.com/photo.jpg",
        "createdAt": "2026-03-19T00:00:00.000Z",
        "taggedItems": [],
        "squadIds": ["squad-1"],
      };

      final post = OotdPost.fromJson(json);

      expect(post.taggedItems.length, 0);
    });

    test("handles missing optional fields with defaults", () {
      final json = {
        "id": "post-5",
        "authorId": "profile-1",
        "photoUrl": "https://storage.example.com/photo.jpg",
        "createdAt": "2026-03-19T00:00:00.000Z",
      };

      final post = OotdPost.fromJson(json);

      expect(post.caption, null);
      expect(post.authorDisplayName, null);
      expect(post.authorPhotoUrl, null);
      expect(post.taggedItems, isEmpty);
      expect(post.squadIds, isEmpty);
      expect(post.reactionCount, 0);
      expect(post.commentCount, 0);
    });
  });

  group("OotdPostItem.fromJson", () {
    test("parses all fields correctly", () {
      final json = {
        "id": "ti-1",
        "postId": "post-1",
        "itemId": "item-1",
        "itemName": "Blue Jacket",
        "itemPhotoUrl": "https://storage.example.com/jacket.jpg",
        "itemCategory": "outerwear",
      };

      final item = OotdPostItem.fromJson(json);

      expect(item.id, "ti-1");
      expect(item.postId, "post-1");
      expect(item.itemId, "item-1");
      expect(item.itemName, "Blue Jacket");
      expect(item.itemPhotoUrl, "https://storage.example.com/jacket.jpg");
      expect(item.itemCategory, "outerwear");
    });

    test("handles null itemName and itemPhotoUrl", () {
      final json = {
        "id": "ti-2",
        "postId": "post-1",
        "itemId": "item-2",
        "itemName": null,
        "itemPhotoUrl": null,
        "itemCategory": null,
      };

      final item = OotdPostItem.fromJson(json);

      expect(item.itemName, null);
      expect(item.itemPhotoUrl, null);
      expect(item.itemCategory, null);
    });
  });
}
