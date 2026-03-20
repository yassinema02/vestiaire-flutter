/// Data model for OOTD post comments.
///
/// Story 9.4: Reactions & Comments (FR-SOC-10, FR-SOC-11)

/// Represents a text comment on an OOTD post.
class OotdComment {
  const OotdComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.authorDisplayName,
    this.authorPhotoUrl,
  });

  final String id;
  final String postId;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorPhotoUrl;

  factory OotdComment.fromJson(Map<String, dynamic> json) {
    return OotdComment(
      id: json["id"] as String,
      postId: json["postId"] as String,
      authorId: json["authorId"] as String,
      text: json["text"] as String,
      createdAt: DateTime.parse(json["createdAt"] as String),
      authorDisplayName: json["authorDisplayName"] as String?,
      authorPhotoUrl: json["authorPhotoUrl"] as String?,
    );
  }
}
