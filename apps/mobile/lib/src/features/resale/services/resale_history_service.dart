/// Service for resale history and status management.
///
/// Story 7.4: Resale Status & History Tracking (FR-RSL-04, FR-RSL-07)
import "../../../core/networking/api_client.dart";

/// Exception thrown when an invalid status transition is attempted (409).
class StatusTransitionException implements Exception {
  const StatusTransitionException({this.message = "Invalid status transition"});

  final String message;

  @override
  String toString() => "StatusTransitionException($message)";
}

/// Service that communicates with the API for resale history and status updates.
class ResaleHistoryService {
  ResaleHistoryService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Fetch resale history with summary and monthly earnings.
  ///
  /// Returns parsed map with `history`, `summary`, `monthlyEarnings` keys.
  /// Returns null on error.
  Future<Map<String, dynamic>?> fetchHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.authenticatedGet(
        "/v1/resale/history?limit=$limit&offset=$offset",
      );
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Update an item's resale status (mark as sold or donated).
  ///
  /// Returns the response on success, null on generic error.
  /// Throws [StatusTransitionException] on 409 (invalid transition).
  Future<Map<String, dynamic>?> updateResaleStatus(
    String itemId, {
    required String status,
    double? salePrice,
    String? saleCurrency,
    String? saleDate,
  }) async {
    final body = <String, dynamic>{"status": status};
    if (salePrice != null) body["salePrice"] = salePrice;
    if (saleCurrency != null) body["saleCurrency"] = saleCurrency;
    if (saleDate != null) body["saleDate"] = saleDate;

    try {
      final response = await _apiClient.authenticatedPatch(
        "/v1/items/$itemId/resale-status",
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
}
