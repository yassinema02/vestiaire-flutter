/// Data model for a wear log entry.
///
/// Represents a single wear log event where the user logged
/// one or more wardrobe items (optionally as part of a saved outfit).
class WearLog {
  const WearLog({
    required this.id,
    required this.profileId,
    required this.loggedDate,
    this.outfitId,
    this.photoUrl,
    required this.itemIds,
    this.createdAt,
  });

  /// Create a WearLog from a JSON map (API response).
  ///
  /// Supports both camelCase and snake_case keys following
  /// the dual-key pattern used by WardrobeItem.
  factory WearLog.fromJson(Map<String, dynamic> json) {
    return WearLog(
      id: json["id"] as String? ?? "",
      profileId:
          json["profileId"] as String? ?? json["profile_id"] as String? ?? "",
      loggedDate: json["loggedDate"] as String? ??
          json["logged_date"] as String? ??
          "",
      outfitId:
          json["outfitId"] as String? ?? json["outfit_id"] as String?,
      photoUrl:
          json["photoUrl"] as String? ?? json["photo_url"] as String?,
      itemIds: _parseItemIds(json["itemIds"] ?? json["item_ids"]),
      createdAt:
          json["createdAt"] as String? ?? json["created_at"] as String?,
    );
  }

  final String id;
  final String profileId;
  final String loggedDate;
  final String? outfitId;
  final String? photoUrl;
  final List<String> itemIds;
  final String? createdAt;

  /// Serialize to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "profileId": profileId,
      "loggedDate": loggedDate,
      if (outfitId != null) "outfitId": outfitId,
      if (photoUrl != null) "photoUrl": photoUrl,
      "itemIds": itemIds,
      if (createdAt != null) "createdAt": createdAt,
    };
  }

  static List<String> _parseItemIds(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
