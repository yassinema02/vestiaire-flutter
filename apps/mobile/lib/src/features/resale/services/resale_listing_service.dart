/// Service for generating AI-powered resale listings.
///
/// Story 7.3: AI Resale Listing Generation (FR-RSL-02)
import "../../../core/networking/api_client.dart";
import "../models/resale_listing.dart";

/// Exception thrown when the user has exceeded their free usage quota.
class UsageLimitException implements Exception {
  const UsageLimitException({
    this.message = "Usage limit exceeded",
    this.monthlyLimit,
    this.used,
    this.remaining,
    this.resetsAt,
  });

  final String message;
  final int? monthlyLimit;
  final int? used;
  final int? remaining;
  final String? resetsAt;

  @override
  String toString() => "UsageLimitException($message)";
}

/// Service that communicates with the API to generate resale listings.
class ResaleListingService {
  ResaleListingService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Generate a resale listing for the given item.
  ///
  /// Returns [ResaleListingResult] on success, or `null` on non-429 errors.
  /// Throws [UsageLimitException] when the user hits their free tier limit (429).
  Future<ResaleListingResult?> generateListing(String itemId) async {
    try {
      final response = await _apiClient.authenticatedPost(
        "/v1/resale/generate",
        body: {"itemId": itemId},
      );
      return ResaleListingResult.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        throw UsageLimitException(
          message: e.message,
          monthlyLimit: (e.responseBody?["monthlyLimit"] as num?)?.toInt(),
          used: (e.responseBody?["used"] as num?)?.toInt(),
          remaining: (e.responseBody?["remaining"] as num?)?.toInt(),
          resetsAt: e.responseBody?["resetsAt"] as String?,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
