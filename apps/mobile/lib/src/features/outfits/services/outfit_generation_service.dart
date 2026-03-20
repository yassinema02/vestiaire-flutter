import "../../../core/calendar/calendar_event.dart";
import "../../../core/networking/api_client.dart";
import "../../../core/weather/outfit_context.dart";
import "../models/outfit_suggestion.dart";
import "../models/usage_limit_result.dart";

/// Service for generating AI outfit suggestions via the API.
///
/// Wraps the POST /v1/outfits/generate endpoint and handles response
/// parsing and error handling.
class OutfitGenerationService {
  OutfitGenerationService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Generate outfit suggestions based on the given context.
  ///
  /// Returns an [OutfitGenerationResponse] that distinguishes between:
  /// - Success: `result` is set with suggestions and usage metadata.
  /// - Rate limit reached (429): `limitReached` is set with usage info.
  /// - Generic error: `isError` is true.
  ///
  /// This method never throws -- errors are caught and wrapped in the response
  /// so the caller can show a user-friendly error state.
  Future<OutfitGenerationResponse> generateOutfits(OutfitContext context) async {
    try {
      final contextJson = context.toJson();
      final response = await _apiClient.authenticatedPost(
        "/v1/outfits/generate",
        body: {"outfitContext": contextJson},
      );
      return OutfitGenerationResponse(
        result: OutfitGenerationResult.fromJson(response),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 429 && e.responseBody != null) {
        return OutfitGenerationResponse(
          limitReached: UsageLimitReachedResult.fromJson(e.responseBody!),
        );
      }
      if (e.statusCode == 429) {
        return OutfitGenerationResponse(
          limitReached: const UsageLimitReachedResult(
            dailyLimit: 3,
            used: 3,
            remaining: 0,
            resetsAt: "",
          ),
        );
      }
      return const OutfitGenerationResponse(isError: true);
    } catch (e) {
      return const OutfitGenerationResponse(isError: true);
    }
  }

  /// Generate event-specific outfit suggestions.
  ///
  /// Returns an [OutfitGenerationResult] on success, or `null` on error.
  /// This method never throws -- errors are caught and null is returned.
  Future<OutfitGenerationResult?> generateOutfitsForEvent(
    OutfitContext? context,
    CalendarEvent event,
  ) async {
    try {
      final contextJson = context?.toJson() ?? {};
      final eventJson = <String, dynamic>{
        "title": event.title,
        "eventType": event.eventType,
        "formalityScore": event.formalityScore,
        "startTime": event.startTime.toIso8601String(),
        "endTime": event.endTime.toIso8601String(),
        "location": event.location,
      };
      final response = await _apiClient.generateOutfitsForEvent(
        contextJson,
        eventJson,
      );
      return OutfitGenerationResult.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get an AI-generated preparation tip for a formal event.
  ///
  /// Returns the tip string on success, or `null` on any error.
  /// This method never throws -- errors are caught and null is returned.
  Future<String?> getEventPrepTip(
    CalendarEvent event,
    List<Map<String, dynamic>>? outfitItems,
  ) async {
    try {
      final eventJson = <String, dynamic>{
        "title": event.title,
        "eventType": event.eventType,
        "formalityScore": event.formalityScore,
        "startTime": event.startTime.toIso8601String(),
      };
      final response = await _apiClient.getEventPrepTip(eventJson, outfitItems);
      return response["tip"] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Check if the user has enough categorized items for outfit generation.
  ///
  /// Returns `true` if the list has >= 3 items with
  /// `categorizationStatus == 'completed'`.
  static bool hasEnoughItems(List<dynamic> items) {
    int count = 0;
    for (final item in items) {
      if (item is Map<String, dynamic> &&
          item["categorizationStatus"] == "completed") {
        count++;
      }
      if (count >= 3) return true;
    }
    return false;
  }
}
