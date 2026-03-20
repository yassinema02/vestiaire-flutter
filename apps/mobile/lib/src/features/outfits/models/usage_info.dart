/// Model representing AI usage quota information.
///
/// Returned as part of the outfit generation response to indicate
/// how many generations the user has remaining today.
class UsageInfo {
  const UsageInfo({
    this.dailyLimit,
    required this.used,
    this.remaining,
    this.resetsAt,
    required this.isPremium,
  });

  final int? dailyLimit;
  final int used;
  final int? remaining;
  final String? resetsAt;
  final bool isPremium;

  /// Whether the daily limit has been reached (free users only).
  bool get isLimitReached => !isPremium && remaining != null && remaining! <= 0;

  /// Human-readable text describing remaining generations.
  String get remainingText {
    if (isPremium) return "";
    if (remaining != null && remaining! > 0) {
      return "$remaining of $dailyLimit generations remaining today";
    }
    if (isLimitReached) return "Daily limit reached";
    return "";
  }

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      dailyLimit: json["dailyLimit"] as int?,
      used: (json["used"] as num?)?.toInt() ?? 0,
      remaining: json["remaining"] as int?,
      resetsAt: json["resetsAt"] as String?,
      isPremium: json["isPremium"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        "dailyLimit": dailyLimit,
        "used": used,
        "remaining": remaining,
        "resetsAt": resetsAt,
        "isPremium": isPremium,
      };
}
