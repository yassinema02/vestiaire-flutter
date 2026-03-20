import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "../../../core/networking/api_client.dart";
import "../models/packing_list.dart";
import "../models/trip.dart";

/// Service for generating, caching, and managing packing lists.
class PackingListService {
  PackingListService({
    required this.apiClient,
    this.sharedPreferences,
  });

  final ApiClient apiClient;

  /// Optional SharedPreferences injection for testing.
  final SharedPreferences? sharedPreferences;

  Future<SharedPreferences> _getPrefs() async {
    return sharedPreferences ?? await SharedPreferences.getInstance();
  }

  /// Generate a packing list from the API.
  ///
  /// Returns null on error.
  Future<PackingList?> generatePackingList(Trip trip) async {
    try {
      final response = await apiClient.generatePackingList(trip.id, {
        "trip": trip.toJson(),
        "regenerate": false,
      });
      return PackingList.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Get a cached packing list from SharedPreferences.
  ///
  /// Returns null if no cache exists.
  Future<PackingList?> getCachedPackingList(String tripId) async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString("packing_list_$tripId");
    if (jsonStr == null) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PackingList.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Cache a packing list to SharedPreferences.
  Future<void> cachePackingList(String tripId, PackingList list) async {
    final prefs = await _getPrefs();
    final jsonStr = jsonEncode(list.toJson());
    await prefs.setString("packing_list_$tripId", jsonStr);
  }

  /// Get the packed status for all items in a trip.
  ///
  /// Returns a map of itemId/name -> isPacked.
  Future<Map<String, bool>> getPackedStatus(String tripId) async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString("packed_status_$tripId");
    if (jsonStr == null) return {};
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return json.map((key, value) => MapEntry(key, value as bool));
    } catch (_) {
      return {};
    }
  }

  /// Update the packed status for a specific item.
  Future<void> updatePackedStatus(
      String tripId, String itemId, bool packed) async {
    final prefs = await _getPrefs();
    final current = await getPackedStatus(tripId);
    current[itemId] = packed;
    await prefs.setString("packed_status_$tripId", jsonEncode(current));
  }

  /// Clear all packed status for a trip (used on regenerate).
  Future<void> clearPackedStatus(String tripId) async {
    final prefs = await _getPrefs();
    await prefs.remove("packed_status_$tripId");
  }
}
