import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/squads/models/ootd_comment.dart";

void main() {
  group("OotdComment.fromJson", () {
    test("parses all fields correctly", () {
      final json = {
        "id": "comment-1",
        "postId": "post-1",
        "authorId": "profile-1",
        "text": "Great outfit!",
        "createdAt": "2026-03-19T00:00:00.000Z",
        "authorDisplayName": "Alice",
        "authorPhotoUrl": "https://example.com/avatar.jpg",
      };

      final comment = OotdComment.fromJson(json);

      expect(comment.id, "comment-1");
      expect(comment.postId, "post-1");
      expect(comment.authorId, "profile-1");
      expect(comment.text, "Great outfit!");
      expect(comment.createdAt, DateTime.utc(2026, 3, 19));
      expect(comment.authorDisplayName, "Alice");
      expect(comment.authorPhotoUrl, "https://example.com/avatar.jpg");
    });

    test("handles null authorDisplayName and authorPhotoUrl", () {
      final json = {
        "id": "comment-2",
        "postId": "post-1",
        "authorId": "profile-1",
        "text": "Hello!",
        "createdAt": "2026-03-19T01:00:00.000Z",
        "authorDisplayName": null,
        "authorPhotoUrl": null,
      };

      final comment = OotdComment.fromJson(json);

      expect(comment.authorDisplayName, null);
      expect(comment.authorPhotoUrl, null);
    });

    test("handles missing optional fields", () {
      final json = {
        "id": "comment-3",
        "postId": "post-2",
        "authorId": "profile-2",
        "text": "Looks good",
        "createdAt": "2026-03-19T02:00:00.000Z",
      };

      final comment = OotdComment.fromJson(json);

      expect(comment.id, "comment-3");
      expect(comment.text, "Looks good");
      expect(comment.authorDisplayName, null);
      expect(comment.authorPhotoUrl, null);
    });
  });
}
