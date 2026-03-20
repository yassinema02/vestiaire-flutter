/// A simple data class representing the cached premium state.
///
/// Used by UI components for fast, synchronous premium status checks
/// for gate display. The authoritative check remains server-side.
class PremiumState {
  const PremiumState({
    required this.isPremium,
    this.premiumSource,
    this.premiumExpiresAt,
  });

  /// Whether the user currently has premium access.
  final bool isPremium;

  /// The source of premium status (e.g., "revenuecat", "trial").
  final String? premiumSource;

  /// When the premium subscription expires.
  final DateTime? premiumExpiresAt;
}
