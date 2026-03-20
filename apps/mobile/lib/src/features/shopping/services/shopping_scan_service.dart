import "../../../core/networking/api_client.dart";
import "../models/compatibility_score_result.dart";
import "../models/match_insight_result.dart";
import "../models/shopping_scan.dart";

/// Service for shopping scan operations.
///
/// Wraps API calls for URL-based product scanning.
/// Story 8.1: Product URL Scraping (FR-SHP-02)
class ShoppingScanService {
  ShoppingScanService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Scan a product URL and return the extracted scan result.
  ///
  /// Calls POST /v1/shopping/scan-url.
  /// Throws [ApiException] on errors (429 for rate limit, 422 for extraction failure).
  Future<ShoppingScan> scanUrl(String url) async {
    final response = await _apiClient.authenticatedPost(
      "/v1/shopping/scan-url",
      body: {"url": url},
    );
    final scanJson = response["scan"] as Map<String, dynamic>;
    return ShoppingScan.fromJson(scanJson);
  }

  /// Scan a product screenshot and return the extracted scan result.
  ///
  /// Calls POST /v1/shopping/scan-screenshot.
  /// Throws [ApiException] on errors (429 for rate limit, 422 for extraction failure).
  Future<ShoppingScan> scanScreenshot(String imageUrl) async {
    final response = await _apiClient.authenticatedPost(
      "/v1/shopping/scan-screenshot",
      body: {"imageUrl": imageUrl},
    );
    final scanJson = response["scan"] as Map<String, dynamic>;
    return ShoppingScan.fromJson(scanJson);
  }

  /// Generate match & insight analysis for a shopping scan.
  ///
  /// Calls POST /v1/shopping/scans/:id/insights.
  /// Returns a [MatchInsightResult] with matches and insights.
  /// Throws [ApiException] on errors (422 for empty wardrobe/not scored, 502 for failure).
  ///
  /// Story 8.5: Shopping Match & Insight Display (FR-SHP-08, FR-SHP-09)
  Future<MatchInsightResult> generateInsights(String scanId) async {
    final response = await _apiClient.generateShoppingInsights(scanId);
    return MatchInsightResult.fromJson(response);
  }

  /// Score a shopping scan's compatibility against the user's wardrobe.
  ///
  /// Calls POST /v1/shopping/scans/:id/score.
  /// Returns a [CompatibilityScoreResult] with the score breakdown and tier.
  /// Throws [ApiException] on errors (422 for empty wardrobe, 502 for scoring failure).
  ///
  /// Story 8.4: Purchase Compatibility Scoring (FR-SHP-06)
  Future<CompatibilityScoreResult> scoreCompatibility(String scanId) async {
    final response = await _apiClient.scoreShoppingScan(scanId);
    return CompatibilityScoreResult.fromJson(response);
  }

  /// Update a shopping scan's metadata.
  ///
  /// Calls PATCH /v1/shopping/scans/:id with the provided updates.
  /// Returns the updated [ShoppingScan].
  /// Throws [ApiException] on errors (400 for validation, 404 for not found).
  ///
  /// Story 8.3: Review Extracted Product Data (FR-SHP-05)
  Future<ShoppingScan> updateScan(String scanId, Map<String, dynamic> updates) async {
    final response = await _apiClient.updateShoppingScan(scanId, updates);
    final scanJson = response["scan"] as Map<String, dynamic>;
    return ShoppingScan.fromJson(scanJson);
  }
}
