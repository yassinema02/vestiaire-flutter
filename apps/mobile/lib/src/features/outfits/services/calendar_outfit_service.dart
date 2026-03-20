import "../../../core/networking/api_client.dart";
import "../models/calendar_outfit.dart";

/// Service for managing calendar outfit assignments via the API.
///
/// Wraps the calendar outfit CRUD endpoints and handles response
/// parsing and error handling. Never throws -- returns safe defaults on error.
class CalendarOutfitService {
  CalendarOutfitService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Create a calendar outfit assignment.
  ///
  /// Returns the created [CalendarOutfit] on success, or `null` on error.
  Future<CalendarOutfit?> createCalendarOutfit({
    required String outfitId,
    String? calendarEventId,
    required String scheduledDate,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        "outfitId": outfitId,
        "scheduledDate": scheduledDate,
      };
      if (calendarEventId != null) body["calendarEventId"] = calendarEventId;
      if (notes != null) body["notes"] = notes;

      final response = await _apiClient.createCalendarOutfit(body);
      final data = response["calendarOutfit"] as Map<String, dynamic>?;
      if (data == null) return null;
      return CalendarOutfit.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get calendar outfits for a date range.
  ///
  /// Returns a list of [CalendarOutfit] on success, or an empty list on error.
  Future<List<CalendarOutfit>> getCalendarOutfitsForDateRange(
      String startDate, String endDate) async {
    try {
      final response = await _apiClient.getCalendarOutfits(startDate, endDate);
      final list = response["calendarOutfits"] as List<dynamic>? ?? [];
      return list
          .map((e) => CalendarOutfit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Update a calendar outfit assignment.
  ///
  /// Returns the updated [CalendarOutfit] on success, or `null` on error.
  Future<CalendarOutfit?> updateCalendarOutfit(
    String id, {
    required String outfitId,
    String? calendarEventId,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        "outfitId": outfitId,
      };
      if (calendarEventId != null) body["calendarEventId"] = calendarEventId;
      if (notes != null) body["notes"] = notes;

      final response = await _apiClient.updateCalendarOutfit(id, body);
      final data = response["calendarOutfit"] as Map<String, dynamic>?;
      if (data == null) return null;
      return CalendarOutfit.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Delete a calendar outfit assignment.
  ///
  /// Returns `true` on success, `false` on error.
  Future<bool> deleteCalendarOutfit(String id) async {
    try {
      await _apiClient.deleteCalendarOutfit(id);
      return true;
    } catch (e) {
      return false;
    }
  }
}
