/// Data models for OOTD (Outfit of the Day) posts.
///
/// Story 9.2: OOTD Post Creation (FR-SOC-06)

/// Represents an OOTD post shared to one or more squads.
class OotdPost {
  const OotdPost({
    required this.id,
    required this.authorId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
    this.authorDisplayName,
    this.authorPhotoUrl,
    this.taggedItems = const [],
    this.squadIds = const [],
    this.reactionCount = 0,
    this.commentCount = 0,
    this.hasReacted = false,
  });

  final String id;
  final String authorId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorPhotoUrl;
  final List<OotdPostItem> taggedItems;
  final List<String> squadIds;
  final int reactionCount;
  final int commentCount;
  final bool hasReacted;

  factory OotdPost.fromJson(Map<String, dynamic> json) {
    final taggedItemsList = json["taggedItems"] as List<dynamic>? ?? [];
    final squadIdsList = json["squadIds"] as List<dynamic>? ?? [];

    return OotdPost(
      id: json["id"] as String,
      authorId: json["authorId"] as String,
      photoUrl: json["photoUrl"] as String,
      caption: json["caption"] as String?,
      createdAt: DateTime.parse(json["createdAt"] as String),
      authorDisplayName: json["authorDisplayName"] as String?,
      authorPhotoUrl: json["authorPhotoUrl"] as String?,
      taggedItems: taggedItemsList
          .map((item) => OotdPostItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      squadIds: squadIdsList.map((id) => id as String).toList(),
      reactionCount: json["reactionCount"] as int? ?? 0,
      commentCount: json["commentCount"] as int? ?? 0,
      hasReacted: json["hasReacted"] as bool? ?? false,
    );
  }
}

/// Represents a tagged wardrobe item on an OOTD post.
class OotdPostItem {
  const OotdPostItem({
    required this.id,
    required this.postId,
    required this.itemId,
    this.itemName,
    this.itemPhotoUrl,
    this.itemCategory,
  });

  final String id;
  final String postId;
  final String itemId;
  final String? itemName;
  final String? itemPhotoUrl;
  final String? itemCategory;

  factory OotdPostItem.fromJson(Map<String, dynamic> json) {
    return OotdPostItem(
      id: json["id"] as String,
      postId: json["postId"] as String,
      itemId: json["itemId"] as String,
      itemName: json["itemName"] as String?,
      itemPhotoUrl: json["itemPhotoUrl"] as String?,
      itemCategory: json["itemCategory"] as String?,
    );
  }
}
