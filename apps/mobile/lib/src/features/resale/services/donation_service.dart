/// Service for donation operations.
///
/// Story 13.3: Spring Clean Declutter Flow & Donations (FR-DON-01, FR-DON-03, FR-DON-05)
import "../../../core/networking/api_client.dart";
import "resale_history_service.dart";

/// Service that communicates with the API for donation operations.
class DonationService {
  DonationService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Create a donation log entry.
  ///
  /// Returns parsed response on success, null on non-409 error.
  /// Throws [StatusTransitionException] on 409 (invalid transition).
  Future<Map<String, dynamic>?> createDonation({
    required String itemId,
    String? charityName,
    double? estimatedValue,
  }) async {
    final body = <String, dynamic>{
      "itemId": itemId,
    };
    if (charityName != null) body["charityName"] = charityName;
    if (estimatedValue != null) body["estimatedValue"] = estimatedValue;

    try {
      final response = await _apiClient.authenticatedPost(
        "/v1/donations",
        body: body,
      );
      return response;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw StatusTransitionException(message: e.message);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch donation history with summary.
  ///
  /// Returns parsed map with `donations` and `summary` keys.
  /// Returns null on error.
  Future<Map<String, dynamic>?> fetchDonations({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.authenticatedGet(
        "/v1/donations?limit=$limit&offset=$offset",
      );
      return response;
    } catch (_) {
      return null;
    }
  }
}
