import "../../../core/networking/api_client.dart";
import "../models/outfit_suggestion.dart";
import "../models/saved_outfit.dart";

/// Service for persisting outfit suggestions via the API.
///
/// Wraps the POST /v1/outfits endpoint and handles response
/// parsing and error handling.
class OutfitPersistenceService {
  OutfitPersistenceService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Save an outfit suggestion to the API.
  ///
  /// Maps the suggestion to the API request body and calls POST /v1/outfits.
  /// Returns the parsed response map on success, or `null` on any error.
  /// This method never throws -- errors are caught and null is returned
  /// so the caller can show a user-friendly error state.
  Future<Map<String, dynamic>?> saveOutfit(OutfitSuggestion suggestion) async {
    try {
      final requestBody = <String, dynamic>{
        "name": suggestion.name,
        "explanation": suggestion.explanation,
        "occasion": suggestion.occasion,
        "source": "ai",
        "items": suggestion.items
            .asMap()
            .entries
            .map((e) => <String, dynamic>{
                  "itemId": e.value.id,
                  "position": e.key,
                })
            .toList(),
      };

      final response = await _apiClient.authenticatedPost(
        "/v1/outfits",
        body: requestBody,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// List all saved outfits for the authenticated user.
  ///
  /// Calls GET /v1/outfits and parses the response into a list of [SavedOutfit].
  /// Returns an empty list on any error.
  Future<List<SavedOutfit>> listOutfits() async {
    try {
      final response = await _apiClient.listOutfits();
      final outfits = response["outfits"] as List<dynamic>? ?? [];
      return outfits
          .map((e) => SavedOutfit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Toggle the favorite status of an outfit.
  ///
  /// Calls PATCH /v1/outfits/:id with the new isFavorite value.
  /// Returns the updated [SavedOutfit] on success, or `null` on error.
  Future<SavedOutfit?> toggleFavorite(String outfitId, bool isFavorite) async {
    try {
      final response = await _apiClient.updateOutfit(
        outfitId,
        {"isFavorite": isFavorite},
      );
      return SavedOutfit.fromJson(response["outfit"] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Delete an outfit by ID.
  ///
  /// Calls DELETE /v1/outfits/:id.
  /// Returns `true` on success, `false` on any error.
  Future<bool> deleteOutfit(String outfitId) async {
    try {
      await _apiClient.deleteOutfit(outfitId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save a manually-built outfit to the API.
  ///
  /// Builds the request body from raw parameters and calls POST /v1/outfits
  /// with `source: "manual"`. Returns the parsed response map on success,
  /// or `null` on any error.
  Future<Map<String, dynamic>?> saveManualOutfit({
    required String name,
    String? occasion,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        "name": name,
        "source": "manual",
        "occasion": occasion,
        "items": items,
      };

      final response = await _apiClient.authenticatedPost(
        "/v1/outfits",
        body: requestBody,
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
