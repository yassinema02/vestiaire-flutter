import "../../../core/networking/api_client.dart";
import "../models/squad.dart";

/// Service for squad operations via the API.
///
/// Story 9.1: Squad Creation & Management (FR-SOC-01 through FR-SOC-05)
class SquadService {
  SquadService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Create a new squad.
  Future<Squad> createSquad({required String name, String? description}) async {
    final body = <String, dynamic>{"name": name};
    if (description != null) body["description"] = description;
    final response = await _apiClient.authenticatedPost("/v1/squads", body: body);
    return Squad.fromJson(response["squad"] as Map<String, dynamic>);
  }

  /// List all squads the current user belongs to.
  Future<List<Squad>> listMySquads() async {
    final response = await _apiClient.authenticatedGet("/v1/squads");
    final squads = response["squads"] as List<dynamic>? ?? [];
    return squads
        .map((s) => Squad.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Join a squad via invite code.
  Future<Squad> joinSquad({required String inviteCode}) async {
    final response = await _apiClient.authenticatedPost("/v1/squads/join",
        body: {"inviteCode": inviteCode});
    return Squad.fromJson(response["squad"] as Map<String, dynamic>);
  }

  /// Get a single squad by ID.
  Future<Squad> getSquad(String squadId) async {
    final response =
        await _apiClient.authenticatedGet("/v1/squads/$squadId");
    return Squad.fromJson(response["squad"] as Map<String, dynamic>);
  }

  /// List all members of a squad.
  Future<List<SquadMember>> listMembers(String squadId) async {
    final response =
        await _apiClient.authenticatedGet("/v1/squads/$squadId/members");
    final members = response["members"] as List<dynamic>? ?? [];
    return members
        .map((m) => SquadMember.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Leave a squad.
  Future<void> leaveSquad(String squadId) async {
    await _apiClient.authenticatedDelete("/v1/squads/$squadId/members/me");
  }

  /// Remove a member from a squad (admin only).
  Future<void> removeMember(String squadId, String memberId) async {
    await _apiClient
        .authenticatedDelete("/v1/squads/$squadId/members/$memberId");
  }
}
