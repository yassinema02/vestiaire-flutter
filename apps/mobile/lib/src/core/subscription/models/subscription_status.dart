/// Represents the subscription status returned by the server
/// after a subscription sync.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.isPremium,
    this.premiumSource,
    this.premiumExpiresAt,
  });

  final bool isPremium;
  final String? premiumSource;
  final String? premiumExpiresAt;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isPremium: json["isPremium"] as bool? ?? false,
      premiumSource: json["premiumSource"] as String?,
      premiumExpiresAt: json["premiumExpiresAt"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "isPremium": isPremium,
      "premiumSource": premiumSource,
      "premiumExpiresAt": premiumExpiresAt,
    };
  }
}
