import "../../../core/networking/api_client.dart";
import "../models/wear_log.dart";

/// Result of a wear log operation, including optional points, streak, and badge data.
class WearLogResult {
  const WearLogResult({
    required this.wearLog,
    this.pointsAwarded,
    this.streakUpdate,
    this.badgesAwarded,
  });

  final WearLog wearLog;
  final Map<String, dynamic>? pointsAwarded;
  final Map<String, dynamic>? streakUpdate;

  /// List of newly awarded badges from this action, or null.
  final List<Map<String, dynamic>>? badgesAwarded;
}

/// Service for creating and querying wear logs.
///
/// Delegates to [ApiClient] for HTTP communication.
/// Constructor accepts [ApiClient] for dependency injection.
class WearLogService {
  WearLogService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Log individual items as worn today.
  ///
  /// Calls [ApiClient.createWearLog] with the given item IDs.
  /// Returns a [WearLogResult] with the wear log and optional points data.
  Future<WearLogResult> logItems(List<String> itemIds) async {
    final response = await _apiClient.createWearLog(itemIds: itemIds);
    final wearLogData = response["wearLog"] as Map<String, dynamic>;
    final pointsData = response["pointsAwarded"] as Map<String, dynamic>?;
    final streakData = response["streakUpdate"] as Map<String, dynamic>?;
    final badgesRaw = response["badgesAwarded"] as List<dynamic>?;
    final badges = badgesRaw?.cast<Map<String, dynamic>>();
    return WearLogResult(
      wearLog: WearLog.fromJson(wearLogData),
      pointsAwarded: pointsData,
      streakUpdate: streakData,
      badgesAwarded: badges,
    );
  }

  /// Log a saved outfit as worn today.
  ///
  /// Calls [ApiClient.createWearLog] with the outfit ID and its item IDs.
  /// Returns a [WearLogResult] with the wear log and optional points data.
  Future<WearLogResult> logOutfit(String outfitId, List<String> itemIds) async {
    final response = await _apiClient.createWearLog(
      itemIds: itemIds,
      outfitId: outfitId,
    );
    final wearLogData = response["wearLog"] as Map<String, dynamic>;
    final pointsData = response["pointsAwarded"] as Map<String, dynamic>?;
    final streakData = response["streakUpdate"] as Map<String, dynamic>?;
    final badgesRaw = response["badgesAwarded"] as List<dynamic>?;
    final badges = badgesRaw?.cast<Map<String, dynamic>>();
    return WearLogResult(
      wearLog: WearLog.fromJson(wearLogData),
      pointsAwarded: pointsData,
      streakUpdate: streakData,
      badgesAwarded: badges,
    );
  }

  /// Get wear logs for a date range.
  ///
  /// Returns a list of [WearLog] objects within the specified date range.
  Future<List<WearLog>> getLogsForDateRange(
    String startDate,
    String endDate,
  ) async {
    final response = await _apiClient.listWearLogs(
      startDate: startDate,
      endDate: endDate,
    );
    final wearLogs = response["wearLogs"] as List<dynamic>;
    return wearLogs
        .map((e) => WearLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
