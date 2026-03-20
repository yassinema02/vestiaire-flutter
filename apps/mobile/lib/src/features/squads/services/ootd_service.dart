import "../../../core/networking/api_client.dart";
import "../models/ootd_comment.dart";
import "../models/ootd_post.dart";
import "../models/steal_look_result.dart";

/// Service for OOTD post operations via the API.
///
/// Story 9.2: OOTD Post Creation (FR-SOC-06)
/// Story 9.4: Reactions & Comments (FR-SOC-09, FR-SOC-10, FR-SOC-11)
/// Story 9.5: "Steal This Look" Matcher (FR-SOC-12, FR-SOC-13)
class OotdService {
  OotdService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Create a new OOTD post.
  Future<OotdPost> createPost({
    required String photoUrl,
    String? caption,
    required List<String> squadIds,
    List<String> taggedItemIds = const [],
  }) async {
    final body = <String, dynamic>{
      "photoUrl": photoUrl,
      "squadIds": squadIds,
      "taggedItemIds": taggedItemIds,
    };
    if (caption != null) body["caption"] = caption;
    final response =
        await _apiClient.authenticatedPost("/v1/squads/posts", body: body);
    return OotdPost.fromJson(response["post"] as Map<String, dynamic>);
  }

  /// List paginated posts across all user's squads (feed).
  Future<Map<String, dynamic>> listFeedPosts({
    int limit = 20,
    String? cursor,
  }) async {
    final query = StringBuffer("/v1/squads/posts/feed?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    final response = await _apiClient.authenticatedGet(query.toString());
    final posts = (response["posts"] as List<dynamic>? ?? [])
        .map((p) => OotdPost.fromJson(p as Map<String, dynamic>))
        .toList();
    return {
      "posts": posts,
      "nextCursor": response["nextCursor"] as String?,
    };
  }

  /// List paginated posts for a specific squad.
  Future<Map<String, dynamic>> listSquadPosts(
    String squadId, {
    int limit = 20,
    String? cursor,
  }) async {
    final query = StringBuffer("/v1/squads/$squadId/posts?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    final response = await _apiClient.authenticatedGet(query.toString());
    final posts = (response["posts"] as List<dynamic>? ?? [])
        .map((p) => OotdPost.fromJson(p as Map<String, dynamic>))
        .toList();
    return {
      "posts": posts,
      "nextCursor": response["nextCursor"] as String?,
    };
  }

  /// Get a single post by ID.
  Future<OotdPost> getPost(String postId) async {
    final response =
        await _apiClient.authenticatedGet("/v1/squads/posts/$postId");
    return OotdPost.fromJson(response["post"] as Map<String, dynamic>);
  }

  /// Delete a post (soft delete).
  Future<void> deletePost(String postId) async {
    await _apiClient.authenticatedDelete("/v1/squads/posts/$postId");
  }

  // --- Reactions ---

  /// Toggle a fire reaction on a post.
  Future<Map<String, dynamic>> toggleReaction(String postId) async {
    return _apiClient.authenticatedPost("/v1/squads/posts/$postId/reactions");
  }

  // --- Comments ---

  /// Create a comment on a post.
  Future<OotdComment> createComment(String postId,
      {required String text}) async {
    final response = await _apiClient.authenticatedPost(
      "/v1/squads/posts/$postId/comments",
      body: {"text": text},
    );
    return OotdComment.fromJson(response["comment"] as Map<String, dynamic>);
  }

  /// List paginated comments for a post.
  Future<Map<String, dynamic>> listComments(String postId,
      {int limit = 50, String? cursor}) async {
    final query =
        StringBuffer("/v1/squads/posts/$postId/comments?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    final response = await _apiClient.authenticatedGet(query.toString());
    final comments = (response["comments"] as List<dynamic>? ?? [])
        .map((c) => OotdComment.fromJson(c as Map<String, dynamic>))
        .toList();
    return {
      "comments": comments,
      "nextCursor": response["nextCursor"] as String?,
    };
  }

  /// Delete a comment (soft delete).
  Future<void> deleteComment(String postId, String commentId) async {
    await _apiClient
        .authenticatedDelete("/v1/squads/posts/$postId/comments/$commentId");
  }

  // --- Steal This Look ---

  /// Find matching items in the user's wardrobe for a friend's OOTD post.
  ///
  /// Story 9.5: "Steal This Look" Matcher (FR-SOC-12)
  Future<StealLookResult> stealThisLook(String postId) async {
    final response =
        await _apiClient.stealThisLook(postId);
    return StealLookResult.fromJson(response);
  }

  /// Check if the user has posted at least one OOTD today.
  ///
  /// Uses the feed endpoint with a limit of 1 and checks if any posts
  /// were created today. Returns false on error (graceful degradation).
  ///
  /// Story 9.6: Social Notification Preferences (FR-NTF-05)
  Future<bool> hasPostedToday() async {
    try {
      final result = await listFeedPosts(limit: 20);
      final posts = result["posts"] as List<dynamic>? ?? [];
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      for (final post in posts) {
        final createdAt = post.createdAt;
        if (createdAt != null && createdAt.toString().startsWith(todayStr)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Save matched items as a new outfit with source = 'steal_look'.
  ///
  /// Reuses the existing POST /v1/outfits endpoint from Story 4.3.
  /// Story 9.5: "Steal This Look" Matcher (FR-SOC-13)
  Future<Map<String, dynamic>> saveStealLookOutfit({
    required List<String> itemIds,
    required String name,
  }) async {
    return _apiClient.saveOutfitToApi({
      "itemIds": itemIds,
      "name": name,
      "source": "steal_look",
    });
  }
}
