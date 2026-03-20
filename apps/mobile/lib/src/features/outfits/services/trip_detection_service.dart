import "../../../core/networking/api_client.dart";
import "../models/trip.dart";

/// Service for detecting upcoming trips from calendar events.
class TripDetectionService {
  TripDetectionService({required this.apiClient});

  final ApiClient apiClient;

  /// Detect upcoming trips from calendar events.
  ///
  /// Returns empty list on error (graceful degradation).
  Future<List<Trip>> detectTrips({int lookaheadDays = 14}) async {
    try {
      final response = await apiClient.detectTrips({
        "lookaheadDays": lookaheadDays,
      });
      final tripsJson = response["trips"] as List<dynamic>? ?? [];
      return tripsJson
          .map((t) => Trip.fromJson(t as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
