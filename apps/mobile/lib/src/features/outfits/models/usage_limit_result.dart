/// Model representing a 429 rate-limit response from the outfit generation endpoint.
///
/// Contains the usage metadata returned when a free-tier user has
/// exceeded their daily outfit generation limit.
class UsageLimitReachedResult {
  const UsageLimitReachedResult({
    required this.dailyLimit,
    required this.used,
    required this.remaining,
    required this.resetsAt,
  });

  final int dailyLimit;
  final int used;
  final int remaining;
  final String resetsAt;

  factory UsageLimitReachedResult.fromJson(Map<String, dynamic> json) {
    return UsageLimitReachedResult(
      dailyLimit: (json["dailyLimit"] as num?)?.toInt() ?? 3,
      used: (json["used"] as num?)?.toInt() ?? 0,
      remaining: (json["remaining"] as num?)?.toInt() ?? 0,
      resetsAt: json["resetsAt"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "dailyLimit": dailyLimit,
        "used": used,
        "remaining": remaining,
        "resetsAt": resetsAt,
      };
}
