/// Data models for Style Squads.
///
/// Story 9.1: Squad Creation & Management (FR-SOC-01 through FR-SOC-05)

/// Represents a Style Squad.
class Squad {
  const Squad({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    required this.memberCount,
    this.lastActivity,
  });

  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;
  final DateTime? lastActivity;

  factory Squad.fromJson(Map<String, dynamic> json) {
    return Squad(
      id: json["id"] as String,
      name: json["name"] as String,
      description: json["description"] as String?,
      inviteCode: json["inviteCode"] as String,
      createdBy: json["createdBy"] as String,
      createdAt: DateTime.parse(json["createdAt"] as String),
      memberCount: json["memberCount"] as int? ?? 0,
      lastActivity: json["lastActivity"] != null
          ? DateTime.parse(json["lastActivity"] as String)
          : null,
    );
  }
}

/// Represents a member of a squad.
class SquadMember {
  const SquadMember({
    required this.id,
    required this.squadId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String squadId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? displayName;
  final String? photoUrl;

  /// Whether this member is an admin of the squad.
  bool get isAdmin => role == "admin";

  factory SquadMember.fromJson(Map<String, dynamic> json) {
    return SquadMember(
      id: json["id"] as String,
      squadId: json["squadId"] as String,
      userId: json["userId"] as String,
      role: json["role"] as String,
      joinedAt: DateTime.parse(json["joinedAt"] as String),
      displayName: json["displayName"] as String?,
      photoUrl: json["photoUrl"] as String?,
    );
  }
}
