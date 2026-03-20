import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

import "../auth/auth_service.dart";

/// Error codes returned by the API.
class ApiErrorCodes {
  static const String emailVerificationRequired = "EMAIL_VERIFICATION_REQUIRED";
  static const String unauthorized = "UNAUTHORIZED";
  static const String forbidden = "FORBIDDEN";
  static const String sessionExpired = "SESSION_EXPIRED";
}

/// Represents a structured API error response.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.responseBody,
  });

  final int statusCode;
  final String code;
  final String message;

  /// The full parsed response body, available for extracting extra fields
  /// (e.g., usage metadata from 429 responses).
  final Map<String, dynamic>? responseBody;

  bool get isEmailVerificationRequired =>
      code == ApiErrorCodes.emailVerificationRequired;

  bool get isSessionExpired => code == ApiErrorCodes.sessionExpired;

  @override
  String toString() => "ApiException($statusCode, $code: $message)";
}

/// Authenticated HTTP client that attaches Firebase ID tokens.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required AuthService authService,
    http.Client? httpClient,
    VoidCallback? onSessionExpired,
  })  : _baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _authService = authService,
        _httpClient = httpClient ?? http.Client(),
        _onSessionExpired = onSessionExpired;

  final String _baseUrl;
  final AuthService _authService;
  final http.Client _httpClient;
  final VoidCallback? _onSessionExpired;

  /// Fetch or create the profile for the currently authenticated user.
  ///
  /// Calls GET /v1/profiles/me on the Cloud Run API.
  /// Returns the profile data as a Map on success.
  Future<Map<String, dynamic>> getOrCreateProfile() async {
    final response = await _authenticatedGet("/v1/profiles/me");
    return response;
  }

  /// Update the authenticated user's profile.
  ///
  /// Calls PUT /v1/profiles/me with the provided fields.
  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    List<String>? stylePreferences,
    String? photoUrl,
    DateTime? onboardingCompletedAt,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body["display_name"] = displayName;
    if (stylePreferences != null) body["style_preferences"] = stylePreferences;
    if (photoUrl != null) body["photo_url"] = photoUrl;
    if (onboardingCompletedAt != null) {
      body["onboarding_completed_at"] = onboardingCompletedAt.toUtc().toIso8601String();
    }
    return authenticatedPut("/v1/profiles/me", body: body);
  }

  /// Get a signed upload URL for uploading images.
  ///
  /// Calls POST /v1/uploads/signed-url.
  Future<Map<String, dynamic>> getSignedUploadUrl({
    required String purpose,
    String contentType = "image/jpeg",
  }) async {
    return authenticatedPost("/v1/uploads/signed-url", body: {
      "purpose": purpose,
      "contentType": contentType,
    });
  }

  /// Upload an image file to the given upload URL.
  Future<void> uploadImage(String filePath, String uploadUrl) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final uri = Uri.parse(uploadUrl);
    await _httpClient.put(
      uri,
      headers: {"Content-Type": "image/jpeg"},
      body: bytes,
    );
  }

  /// Create a wardrobe item.
  ///
  /// Calls POST /v1/items.
  Future<Map<String, dynamic>> createItem({
    required String photoUrl,
    String? name,
  }) async {
    final body = <String, dynamic>{"photoUrl": photoUrl};
    if (name != null) body["name"] = name;
    return authenticatedPost("/v1/items", body: body);
  }

  /// Update the push token for the authenticated user.
  ///
  /// Pass `null` to clear the token (e.g., on sign-out).
  Future<Map<String, dynamic>> updatePushToken(String? token) async {
    return authenticatedPut("/v1/profiles/me", body: {
      "push_token": token,
    });
  }

  /// Update notification preferences for the authenticated user.
  ///
  /// [preferences] is a map of category keys to values (boolean for most keys,
  /// string for social: "all"/"morning"/"off").
  /// Uses JSONB merge on the server, so only changed keys need to be sent.
  Future<Map<String, dynamic>> updateNotificationPreferences(
      Map<String, dynamic> preferences) async {
    return authenticatedPut("/v1/profiles/me", body: {
      "notification_preferences": preferences,
    });
  }

  /// Delete the authenticated user's account and all associated data.
  ///
  /// Calls DELETE /v1/profiles/me. This is a permanent, irreversible action
  /// that removes the profile, items, uploaded files, and Firebase Auth account.
  Future<Map<String, dynamic>> deleteAccount() async {
    return authenticatedDelete("/v1/profiles/me");
  }

  /// List wardrobe items for the authenticated user.
  ///
  /// Calls GET /v1/items with optional filter query parameters.
  /// Supports server-side filtering by category, color, season, occasion, and brand.
  Future<Map<String, dynamic>> listItems({
    int? limit,
    String? category,
    String? color,
    String? season,
    String? occasion,
    String? brand,
    String? neglectStatus,
  }) async {
    final params = <String, String>{};
    if (limit != null) params["limit"] = limit.toString();
    if (category != null) params["category"] = category;
    if (color != null) params["color"] = color;
    if (season != null) params["season"] = season;
    if (occasion != null) params["occasion"] = occasion;
    if (brand != null) params["brand"] = brand;
    if (neglectStatus != null) params["neglect_status"] = neglectStatus;

    final query = params.isNotEmpty
        ? "?${params.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&")}"
        : "";
    return _authenticatedGet("/v1/items$query");
  }

  /// Retry background removal for a specific item.
  ///
  /// Calls POST /v1/items/$itemId/remove-background.
  /// Returns the response map (typically { "status": "processing" }).
  Future<Map<String, dynamic>> retryBackgroundRemoval(String itemId) async {
    return authenticatedPost("/v1/items/$itemId/remove-background");
  }

  /// Retry categorization for a specific item.
  ///
  /// Calls POST /v1/items/$itemId/categorize.
  /// Returns the response map (typically { "status": "processing" }).
  Future<Map<String, dynamic>> retryCategorization(String itemId) async {
    return authenticatedPost("/v1/items/$itemId/categorize");
  }

  /// Get a single wardrobe item by ID.
  ///
  /// Calls GET /v1/items/$itemId.
  /// Returns the response map containing the item data.
  Future<Map<String, dynamic>> getItem(String itemId) async {
    return _authenticatedGet("/v1/items/$itemId");
  }

  /// Delete a wardrobe item permanently.
  ///
  /// Calls DELETE /v1/items/$itemId.
  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    return authenticatedDelete("/v1/items/$itemId");
  }

  /// Update a wardrobe item's metadata.
  ///
  /// Calls PATCH /v1/items/$itemId with the provided fields.
  /// Only the specified fields are updated (PATCH semantics).
  Future<Map<String, dynamic>> updateItem(
    String itemId,
    Map<String, dynamic> fields,
  ) async {
    return _authenticatedPatch("/v1/items/$itemId", body: fields);
  }

  /// Sync calendar events to the API.
  ///
  /// Calls POST /v1/calendar/events/sync.
  Future<Map<String, dynamic>> syncCalendarEvents(
      List<Map<String, dynamic>> events) async {
    return authenticatedPost("/v1/calendar/events/sync",
        body: {"events": events});
  }

  /// Get calendar events for a date range.
  ///
  /// Calls GET /v1/calendar/events?start=YYYY-MM-DD&end=YYYY-MM-DD.
  Future<Map<String, dynamic>> getCalendarEvents({
    required String startDate,
    required String endDate,
  }) async {
    return _authenticatedGet(
        "/v1/calendar/events?start=$startDate&end=$endDate");
  }

  /// Update a calendar event's classification (user override).
  ///
  /// Calls PATCH /v1/calendar/events/$eventId.
  Future<Map<String, dynamic>> updateEventClassification(
    String eventId, {
    required String eventType,
    required int formalityScore,
  }) async {
    return authenticatedPatch("/v1/calendar/events/$eventId", body: {
      "eventType": eventType,
      "formalityScore": formalityScore,
    });
  }

  /// Generate AI outfit suggestions.
  ///
  /// Calls POST /v1/outfits/generate with the outfit context.
  Future<Map<String, dynamic>> generateOutfits(
      Map<String, dynamic> outfitContext) async {
    return authenticatedPost("/v1/outfits/generate", body: {
      "outfitContext": outfitContext,
    });
  }

  /// Generate AI outfit suggestions for a specific event.
  ///
  /// Calls POST /v1/outfits/generate-for-event with the outfit context and event.
  Future<Map<String, dynamic>> generateOutfitsForEvent(
    Map<String, dynamic> outfitContext,
    Map<String, dynamic> event,
  ) async {
    return authenticatedPost("/v1/outfits/generate-for-event", body: {
      "outfitContext": outfitContext,
      "event": event,
    });
  }

  /// Save an outfit to the API.
  ///
  /// Calls POST /v1/outfits with the provided body.
  Future<Map<String, dynamic>> saveOutfitToApi(
      Map<String, dynamic> body) async {
    return authenticatedPost("/v1/outfits", body: body);
  }

  /// List all outfits for the authenticated user.
  ///
  /// Calls GET /v1/outfits.
  Future<Map<String, dynamic>> listOutfits() async {
    return _authenticatedGet("/v1/outfits");
  }

  /// Update an outfit's fields.
  ///
  /// Calls PATCH /v1/outfits/$outfitId with the provided fields.
  Future<Map<String, dynamic>> updateOutfit(
    String outfitId,
    Map<String, dynamic> fields,
  ) async {
    return authenticatedPatch("/v1/outfits/$outfitId", body: fields);
  }

  /// Delete an outfit.
  ///
  /// Calls DELETE /v1/outfits/$outfitId.
  Future<Map<String, dynamic>> deleteOutfit(String outfitId) async {
    return authenticatedDelete("/v1/outfits/$outfitId");
  }

  /// Create a wear log.
  ///
  /// Calls POST /v1/wear-logs with the provided item IDs and optional fields.
  Future<Map<String, dynamic>> createWearLog({
    required List<String> itemIds,
    String? outfitId,
    String? photoUrl,
    String? loggedDate,
  }) async {
    final body = <String, dynamic>{
      "items": itemIds,
    };
    if (outfitId != null) body["outfitId"] = outfitId;
    if (photoUrl != null) body["photoUrl"] = photoUrl;
    if (loggedDate != null) body["loggedDate"] = loggedDate;
    return authenticatedPost("/v1/wear-logs", body: body);
  }

  /// Get wardrobe analytics summary.
  ///
  /// Calls GET /v1/analytics/wardrobe-summary.
  Future<Map<String, dynamic>> getWardrobeSummary() async {
    return _authenticatedGet("/v1/analytics/wardrobe-summary");
  }

  /// Get items with cost-per-wear data.
  ///
  /// Calls GET /v1/analytics/items-cpw.
  Future<Map<String, dynamic>> getItemsCpw() async {
    return _authenticatedGet("/v1/analytics/items-cpw");
  }

  /// Get top worn items with optional period filter.
  ///
  /// Calls GET /v1/analytics/top-worn?period=$period.
  /// [period] can be "all" (default), "30", or "90".
  Future<Map<String, dynamic>> getTopWornItems({String period = "all"}) async {
    return _authenticatedGet("/v1/analytics/top-worn?period=$period");
  }

  /// Get neglected items (not worn in 60+ days).
  ///
  /// Calls GET /v1/analytics/neglected.
  Future<Map<String, dynamic>> getNeglectedItems() async {
    return _authenticatedGet("/v1/analytics/neglected");
  }

  /// Get category distribution for the user's wardrobe.
  ///
  /// Calls GET /v1/analytics/category-distribution.
  Future<Map<String, dynamic>> getCategoryDistribution() async {
    return _authenticatedGet("/v1/analytics/category-distribution");
  }

  /// Get wear frequency by day of week.
  ///
  /// Calls GET /v1/analytics/wear-frequency.
  Future<Map<String, dynamic>> getWearFrequency() async {
    return _authenticatedGet("/v1/analytics/wear-frequency");
  }

  /// Get AI-generated analytics summary (premium only).
  ///
  /// Calls GET /v1/analytics/ai-summary.
  /// Returns `{ summary: String, isGeneric: bool }` on success.
  /// Throws [ApiException] with statusCode 403 for non-premium users.
  Future<Map<String, dynamic>> getAiAnalyticsSummary() async {
    return _authenticatedGet("/v1/analytics/ai-summary");
  }

  /// Get brand value analytics (premium only).
  ///
  /// Calls GET /v1/analytics/brand-value with optional category filter.
  /// Returns `{ brands: [...], availableCategories: [...],
  ///   bestValueBrand: {...}, mostInvestedBrand: {...} }`.
  /// Throws [ApiException] with statusCode 403 for non-premium users.
  Future<Map<String, dynamic>> getBrandValueAnalytics({String? category}) async {
    final query = category != null ? "?category=${Uri.encodeComponent(category)}" : "";
    return _authenticatedGet("/v1/analytics/brand-value$query");
  }

  /// Get sustainability analytics (premium only).
  ///
  /// Calls GET /v1/analytics/sustainability.
  /// Returns `{ score: int, factors: {...}, co2SavedKg: double,
  ///   co2CarKmEquivalent: double, percentile: int, badgeAwarded: bool, ... }`.
  /// Throws [ApiException] with statusCode 403 for non-premium users.
  Future<Map<String, dynamic>> getSustainabilityAnalytics() async {
    return _authenticatedGet("/v1/analytics/sustainability");
  }

  /// Get wardrobe gap analysis (premium only).
  ///
  /// Calls GET /v1/analytics/gap-analysis.
  /// Returns `{ gaps: [...], totalItems: int }`.
  /// Each gap includes id, dimension, title, description, severity, and recommendation.
  /// Throws [ApiException] with statusCode 403 for non-premium users.
  Future<Map<String, dynamic>> getGapAnalysis() async {
    return _authenticatedGet("/v1/analytics/gap-analysis");
  }

  /// Get seasonal reports (premium only).
  ///
  /// Calls GET /v1/analytics/seasonal-reports.
  /// Returns `{ seasons: [...], currentSeason: String, transitionAlert: Map|null, totalItems: int }`.
  /// Throws [ApiException] with statusCode 403 for non-premium users.
  Future<Map<String, dynamic>> getSeasonalReports() async {
    return _authenticatedGet("/v1/analytics/seasonal-reports");
  }

  /// Get wardrobe health score (FREE tier).
  ///
  /// Calls GET /v1/analytics/wardrobe-health.
  /// Returns `{ score: int, factors: {...}, percentile: int,
  ///   recommendation: String, totalItems: int, itemsWorn90d: int, colorTier: String }`.
  Future<Map<String, dynamic>> getWardrobeHealthScore() async {
    return _authenticatedGet("/v1/analytics/wardrobe-health");
  }

  /// Get heatmap data (premium only).
  ///
  /// Calls GET /v1/analytics/heatmap?start=$startDate&end=$endDate.
  /// Returns `{ dailyActivity: [...], streakStats: {...} }`.
  /// Throws [ApiException] with statusCode 403 for non-premium users.
  Future<Map<String, dynamic>> getHeatmapData({
    required String startDate,
    required String endDate,
  }) async {
    return _authenticatedGet(
        "/v1/analytics/heatmap?start=$startDate&end=$endDate");
  }

  /// Get user gamification stats.
  ///
  /// Calls GET /v1/user-stats.
  /// Returns `{ stats: { totalPoints, currentStreak, longestStreak, lastStreakDate,
  ///   streakFreezeUsedAt, currentLevel, currentLevelName, nextLevelThreshold, itemCount,
  ///   badges: [{ key, name, description, iconName, iconColor, category, awardedAt }],
  ///   badgeCount: int,
  ///   challenge: { key, name, status, currentProgress, targetCount, expiresAt,
  ///     timeRemainingSeconds, reward: { type, value, description } } | null } }`.
  Future<Map<String, dynamic>> getUserStats() async {
    return _authenticatedGet("/v1/user-stats");
  }

  /// Accept a challenge.
  ///
  /// Calls POST /v1/challenges/$challengeKey/accept.
  /// Returns `{ challenge: { key, name, status, acceptedAt, expiresAt,
  ///   currentProgress, targetCount, timeRemainingSeconds } }`.
  Future<Map<String, dynamic>> acceptChallenge(String challengeKey) async {
    return authenticatedPost("/v1/challenges/$challengeKey/accept");
  }

  /// Get the full badge catalog (all 15 badge definitions).
  ///
  /// Calls GET /v1/badges.
  /// Returns `{ badges: [{ key, name, description, iconName, iconColor, category, sortOrder }] }`.
  Future<List<Map<String, dynamic>>> getBadgeCatalog() async {
    final response = await _authenticatedGet("/v1/badges");
    final badges = response["badges"] as List<dynamic>? ?? [];
    return badges.cast<Map<String, dynamic>>();
  }

  /// List wear logs for a date range.
  ///
  /// Calls GET /v1/wear-logs?start=$startDate&end=$endDate.
  Future<Map<String, dynamic>> listWearLogs({
    required String startDate,
    required String endDate,
  }) async {
    return _authenticatedGet("/v1/wear-logs?start=$startDate&end=$endDate");
  }

  /// Generate an AI-powered resale listing.
  ///
  /// Calls POST /v1/resale/generate with the provided body.
  Future<Map<String, dynamic>> generateResaleListing(
      Map<String, dynamic> body) async {
    return authenticatedPost("/v1/resale/generate", body: body);
  }

  // --- Resale Prompts (Story 13.2) ---

  /// Get pending resale prompts for the current month.
  ///
  /// Calls GET /v1/resale/prompts.
  Future<Map<String, dynamic>> getResalePrompts() async {
    return authenticatedGet("/v1/resale/prompts");
  }

  /// Trigger monthly resale prompt evaluation.
  ///
  /// Calls POST /v1/resale/prompts/evaluate.
  Future<Map<String, dynamic>> evaluateResalePrompts() async {
    return authenticatedPost("/v1/resale/prompts/evaluate", body: {});
  }

  /// Update a resale prompt action (accept or dismiss).
  ///
  /// Calls PATCH /v1/resale/prompts/$promptId.
  Future<Map<String, dynamic>> updateResalePrompt(
      String promptId, Map<String, dynamic> body) async {
    return authenticatedPatch("/v1/resale/prompts/$promptId", body: body);
  }

  /// Get the count of pending resale prompts.
  ///
  /// Calls GET /v1/resale/prompts/count.
  Future<Map<String, dynamic>> getResalePromptsCount() async {
    return authenticatedGet("/v1/resale/prompts/count");
  }

  // --- Donations & Spring Clean (Story 13.3) ---

  /// Create a donation log entry.
  ///
  /// Calls POST /v1/donations.
  Future<Map<String, dynamic>> createDonationEntry(Map<String, dynamic> body) async {
    return authenticatedPost("/v1/donations", body: body);
  }

  /// Get donation history with summary.
  ///
  /// Calls GET /v1/donations.
  Future<Map<String, dynamic>> getDonations({int limit = 50, int offset = 0}) async {
    return authenticatedGet("/v1/donations?limit=$limit&offset=$offset");
  }

  /// Get neglected items eligible for Spring Clean.
  ///
  /// Calls GET /v1/spring-clean/items.
  Future<Map<String, dynamic>> getSpringCleanItems() async {
    return authenticatedGet("/v1/spring-clean/items");
  }

  /// Scan a product URL for shopping assistant analysis.
  ///
  /// Calls POST /v1/shopping/scan-url with the provided URL.
  /// Returns the response map containing `{ scan: {...}, status: "completed" }`.
  Future<Map<String, dynamic>> scanProductUrl(String url) async {
    return authenticatedPost("/v1/shopping/scan-url", body: {"url": url});
  }

  /// Scan a product screenshot for shopping assistant analysis.
  ///
  /// Calls POST /v1/shopping/scan-screenshot with the provided image URL.
  /// Returns the response map containing `{ scan: {...}, status: "completed" }`.
  Future<Map<String, dynamic>> scanProductScreenshot(String imageUrl) async {
    return authenticatedPost("/v1/shopping/scan-screenshot", body: {"imageUrl": imageUrl});
  }

  /// Generate match & insight analysis for a shopping scan.
  ///
  /// Calls POST /v1/shopping/scans/$scanId/insights.
  /// Returns the response map containing `{ scan, matches, insights, status }`.
  ///
  /// Story 8.5: Shopping Match & Insight Display (FR-SHP-08, FR-SHP-09)
  Future<Map<String, dynamic>> generateShoppingInsights(String scanId) async {
    return authenticatedPost("/v1/shopping/scans/$scanId/insights");
  }

  /// Score a shopping scan's compatibility against the user's wardrobe.
  ///
  /// Calls POST /v1/shopping/scans/$scanId/score.
  /// Returns the response map containing `{ scan, score, status }`.
  ///
  /// Story 8.4: Purchase Compatibility Scoring (FR-SHP-06)
  Future<Map<String, dynamic>> scoreShoppingScan(String scanId) async {
    return authenticatedPost("/v1/shopping/scans/$scanId/score");
  }

  /// Update a shopping scan's metadata.
  ///
  /// Calls PATCH /v1/shopping/scans/$scanId with the provided updates.
  /// Returns the response map containing `{ scan: {...} }`.
  ///
  /// Story 8.3: Review Extracted Product Data (FR-SHP-05)
  Future<Map<String, dynamic>> updateShoppingScan(
    String scanId,
    Map<String, dynamic> updates,
  ) async {
    return authenticatedPatch("/v1/shopping/scans/$scanId", body: updates);
  }

  // --- Squads ---

  /// Create a new squad.
  ///
  /// Calls POST /v1/squads.
  Future<Map<String, dynamic>> createSquad(Map<String, dynamic> body) async {
    return authenticatedPost("/v1/squads", body: body);
  }

  /// List all squads the current user belongs to.
  ///
  /// Calls GET /v1/squads.
  Future<Map<String, dynamic>> listSquads() async {
    return authenticatedGet("/v1/squads");
  }

  /// Join a squad via invite code.
  ///
  /// Calls POST /v1/squads/join.
  Future<Map<String, dynamic>> joinSquad(Map<String, dynamic> body) async {
    return authenticatedPost("/v1/squads/join", body: body);
  }

  /// Get a single squad by ID.
  ///
  /// Calls GET /v1/squads/:id.
  Future<Map<String, dynamic>> getSquad(String squadId) async {
    return authenticatedGet("/v1/squads/$squadId");
  }

  /// List all members of a squad.
  ///
  /// Calls GET /v1/squads/:id/members.
  Future<Map<String, dynamic>> listSquadMembers(String squadId) async {
    return authenticatedGet("/v1/squads/$squadId/members");
  }

  /// Leave a squad.
  ///
  /// Calls DELETE /v1/squads/:id/members/me.
  Future<Map<String, dynamic>> leaveSquad(String squadId) async {
    return authenticatedDelete("/v1/squads/$squadId/members/me");
  }

  /// Remove a member from a squad (admin only).
  ///
  /// Calls DELETE /v1/squads/:id/members/:memberId.
  Future<Map<String, dynamic>> removeSquadMember(String squadId, String memberId) async {
    return authenticatedDelete("/v1/squads/$squadId/members/$memberId");
  }

  // --- OOTD Posts ---

  /// Create a new OOTD post.
  ///
  /// Calls POST /v1/squads/posts.
  Future<Map<String, dynamic>> createOotdPost(Map<String, dynamic> body) async {
    return authenticatedPost("/v1/squads/posts", body: body);
  }

  /// List paginated posts across all user's squads (feed).
  ///
  /// Calls GET /v1/squads/posts/feed.
  Future<Map<String, dynamic>> listFeedPosts({int limit = 20, String? cursor}) async {
    final query = StringBuffer("/v1/squads/posts/feed?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    return authenticatedGet(query.toString());
  }

  /// List paginated posts for a specific squad.
  ///
  /// Calls GET /v1/squads/:id/posts.
  Future<Map<String, dynamic>> listSquadPosts(String squadId, {int limit = 20, String? cursor}) async {
    final query = StringBuffer("/v1/squads/$squadId/posts?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    return authenticatedGet(query.toString());
  }

  /// Get a single OOTD post by ID.
  ///
  /// Calls GET /v1/squads/posts/:postId.
  Future<Map<String, dynamic>> getOotdPost(String postId) async {
    return authenticatedGet("/v1/squads/posts/$postId");
  }

  /// Delete an OOTD post (soft delete).
  ///
  /// Calls DELETE /v1/squads/posts/:postId.
  Future<Map<String, dynamic>> deleteOotdPost(String postId) async {
    return authenticatedDelete("/v1/squads/posts/$postId");
  }

  // --- OOTD Reactions & Comments ---

  /// Toggle a fire reaction on an OOTD post.
  ///
  /// Calls POST /v1/squads/posts/:postId/reactions.
  Future<Map<String, dynamic>> toggleOotdReaction(String postId) async {
    return authenticatedPost("/v1/squads/posts/$postId/reactions");
  }

  /// Create a comment on an OOTD post.
  ///
  /// Calls POST /v1/squads/posts/:postId/comments.
  Future<Map<String, dynamic>> createOotdComment(String postId, Map<String, dynamic> body) async {
    return authenticatedPost("/v1/squads/posts/$postId/comments", body: body);
  }

  /// List comments for an OOTD post.
  ///
  /// Calls GET /v1/squads/posts/:postId/comments.
  Future<Map<String, dynamic>> listOotdComments(String postId, {int limit = 50, String? cursor}) async {
    final query = StringBuffer("/v1/squads/posts/$postId/comments?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    return authenticatedGet(query.toString());
  }

  /// Delete a comment on an OOTD post (soft delete).
  ///
  /// Calls DELETE /v1/squads/posts/:postId/comments/:commentId.
  Future<Map<String, dynamic>> deleteOotdComment(String postId, String commentId) async {
    return authenticatedDelete("/v1/squads/posts/$postId/comments/$commentId");
  }

  /// Steal This Look: find matching wardrobe items for a friend's OOTD post.
  ///
  /// Calls POST /v1/squads/posts/:postId/steal-look.
  /// Story 9.5: "Steal This Look" Matcher (FR-SOC-12)
  Future<Map<String, dynamic>> stealThisLook(String postId) async {
    return authenticatedPost("/v1/squads/posts/$postId/steal-look");
  }

  // --- Extraction Jobs (Story 10.1) ---

  /// Get bulk signed upload URLs for extraction photos.
  ///
  /// Calls POST /v1/uploads/signed-urls.
  Future<List<Map<String, dynamic>>> getBulkSignedUploadUrls({
    required int count,
  }) async {
    final purposes = List.generate(
      count,
      (i) => {"purpose": "extraction_photo", "index": i},
    );
    final response = await authenticatedPost("/v1/uploads/signed-urls", body: {
      "purposes": purposes,
      "count": count,
    });
    final urls = response["urls"] as List<dynamic>? ?? [];
    return urls.cast<Map<String, dynamic>>();
  }

  /// Create an extraction job.
  ///
  /// Calls POST /v1/extraction-jobs.
  Future<Map<String, dynamic>> createExtractionJob({
    required int totalPhotos,
    required List<Map<String, String>> photos,
  }) async {
    return authenticatedPost("/v1/extraction-jobs", body: {
      "totalPhotos": totalPhotos,
      "photos": photos,
    });
  }

  /// Get an extraction job by ID.
  ///
  /// Calls GET /v1/extraction-jobs/:id.
  /// Response includes `items` array with detected clothing items and metadata.
  Future<Map<String, dynamic>> getExtractionJob(String jobId) async {
    return authenticatedGet("/v1/extraction-jobs/$jobId");
  }

  /// Trigger extraction processing for a job (manual retry/fallback).
  ///
  /// Calls POST /v1/extraction-jobs/:id/process.
  /// Returns 202 if processing was started.
  /// Normally processing starts automatically on job creation.
  Future<Map<String, dynamic>> triggerExtractionProcessing(String jobId) async {
    return authenticatedPost("/v1/extraction-jobs/$jobId/process");
  }

  // --- Extraction Review Flow (Story 10.3) ---

  /// Confirm extraction job results, promoting kept items to the wardrobe.
  ///
  /// Calls POST /v1/extraction-jobs/$jobId/confirm.
  /// Returns `{ confirmedCount: int, items: [...] }`.
  Future<Map<String, dynamic>> confirmExtractionJob(
    String jobId, {
    required List<String> keptItemIds,
    Map<String, Map<String, dynamic>>? metadataEdits,
  }) async {
    final body = <String, dynamic>{
      "keptItemIds": keptItemIds,
    };
    if (metadataEdits != null) body["metadataEdits"] = metadataEdits;
    return authenticatedPost("/v1/extraction-jobs/$jobId/confirm", body: body);
  }

  /// Get duplicate detection results for an extraction job.
  ///
  /// Calls GET /v1/extraction-jobs/$jobId/duplicates.
  /// Returns `{ duplicates: [...] }`.
  Future<Map<String, dynamic>> getExtractionDuplicates(String jobId) async {
    return authenticatedGet("/v1/extraction-jobs/$jobId/duplicates");
  }

  // --- Trip Detection & Packing List ---

  /// Detect upcoming trips from calendar events.
  ///
  /// Calls POST /v1/calendar/trips/detect.
  Future<Map<String, dynamic>> detectTrips(Map<String, dynamic> body) async {
    return authenticatedPost("/v1/calendar/trips/detect", body: body);
  }

  /// Generate a packing list for a trip.
  ///
  /// Calls POST /v1/calendar/trips/$tripId/packing-list.
  Future<Map<String, dynamic>> generatePackingList(
      String tripId, Map<String, dynamic> body) async {
    return authenticatedPost("/v1/calendar/trips/$tripId/packing-list",
        body: body);
  }

  // --- Event Prep Tips ---

  /// Get an AI-generated preparation tip for a formal event.
  ///
  /// Calls POST /v1/outfits/event-prep-tips.
  Future<Map<String, dynamic>> getEventPrepTip(
    Map<String, dynamic> event,
    List<Map<String, dynamic>>? outfitItems,
  ) async {
    final body = <String, dynamic>{"event": event};
    if (outfitItems != null) body["outfitItems"] = outfitItems;
    return authenticatedPost("/v1/outfits/event-prep-tips", body: body);
  }

  // --- Calendar Outfits ---

  /// Create a calendar outfit assignment.
  ///
  /// Calls POST /v1/calendar/outfits.
  Future<Map<String, dynamic>> createCalendarOutfit(Map<String, dynamic> body) async {
    return authenticatedPost("/v1/calendar/outfits", body: body);
  }

  /// Get calendar outfits for a date range.
  ///
  /// Calls GET /v1/calendar/outfits?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD.
  Future<Map<String, dynamic>> getCalendarOutfits(String startDate, String endDate) async {
    return _authenticatedGet(
        "/v1/calendar/outfits?startDate=$startDate&endDate=$endDate");
  }

  /// Update a calendar outfit assignment.
  ///
  /// Calls PUT /v1/calendar/outfits/$id.
  Future<Map<String, dynamic>> updateCalendarOutfit(String id, Map<String, dynamic> body) async {
    return authenticatedPut("/v1/calendar/outfits/$id", body: body);
  }

  /// Delete a calendar outfit assignment.
  ///
  /// Calls DELETE /v1/calendar/outfits/$id.
  Future<Map<String, dynamic>> deleteCalendarOutfit(String id) async {
    return authenticatedDelete("/v1/calendar/outfits/$id");
  }

  /// Perform an authenticated PATCH request (public wrapper).
  Future<Map<String, dynamic>> authenticatedPatch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _authenticatedPatch(path, body: body);
  }

  /// Perform an authenticated PATCH request.
  Future<Map<String, dynamic>> _authenticatedPatch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _authenticatedRequest("PATCH", path, body: body);
  }

  /// Perform an authenticated GET request (public wrapper).
  Future<Map<String, dynamic>> authenticatedGet(String path) async {
    return _authenticatedRequest("GET", path);
  }

  /// Perform an authenticated GET request.
  Future<Map<String, dynamic>> _authenticatedGet(String path) async {
    return _authenticatedRequest("GET", path);
  }

  /// Perform an authenticated POST request.
  Future<Map<String, dynamic>> authenticatedPost(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _authenticatedRequest("POST", path, body: body);
  }

  /// Perform an authenticated PUT request.
  Future<Map<String, dynamic>> authenticatedPut(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _authenticatedRequest("PUT", path, body: body);
  }

  /// Perform an authenticated DELETE request.
  Future<Map<String, dynamic>> authenticatedDelete(String path) async {
    return _authenticatedRequest("DELETE", path);
  }

  /// Generalized authenticated request method that handles token refresh.
  ///
  /// On a 401 response, refreshes the token and retries once. If the retry
  /// also returns 401, invokes [_onSessionExpired] and throws a
  /// SESSION_EXPIRED [ApiException].
  Future<Map<String, dynamic>> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getIdToken();
    if (token == null) {
      throw const ApiException(
        statusCode: 401,
        code: ApiErrorCodes.unauthorized,
        message: "No authentication token available",
      );
    }

    var response = await _sendRequest(method, path, token, body);

    // If 401, try refreshing the token once and retry.
    if (response.statusCode == 401) {
      final refreshedToken = await _authService.getIdToken(forceRefresh: true);
      if (refreshedToken != null) {
        response = await _sendRequest(method, path, refreshedToken, body);

        // Double-401: session is truly expired/revoked.
        if (response.statusCode == 401) {
          _onSessionExpired?.call();
          throw const ApiException(
            statusCode: 401,
            code: ApiErrorCodes.sessionExpired,
            message: "Session expired. Please sign in again.",
          );
        }
      }
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: (responseBody["code"] as String?) ?? "UNKNOWN_ERROR",
      message: (responseBody["message"] as String?) ?? "An unexpected error occurred",
      responseBody: responseBody,
    );
  }

  /// Send a single HTTP request with the given method, path, and token.
  Future<http.Response> _sendRequest(
    String method,
    String path,
    String token,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse("$_baseUrl$path");
    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    switch (method) {
      case "GET":
        return _httpClient.get(uri, headers: headers);
      case "POST":
        return _httpClient.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      case "PUT":
        return _httpClient.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      case "PATCH":
        return _httpClient.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      case "DELETE":
        return _httpClient.delete(uri, headers: headers);
      default:
        return _httpClient.get(uri, headers: headers);
    }
  }

  /// Dispose the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
