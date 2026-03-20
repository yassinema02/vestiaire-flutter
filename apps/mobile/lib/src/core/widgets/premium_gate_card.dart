import "package:flutter/material.dart";

import "../subscription/subscription_service.dart";

/// A reusable card widget that displays a premium feature gate.
///
/// Shows a locked/blurred card with a descriptive title, brief value
/// proposition subtitle, and a "Go Premium" CTA button styled with
/// the brand color (#4F46E5).
///
/// The CTA calls [subscriptionService.presentPaywallIfNeeded()] if
/// provided, otherwise falls back to [onUpgrade].
class PremiumGateCard extends StatelessWidget {
  const PremiumGateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onUpgrade,
    this.subscriptionService,
    super.key,
  });

  /// Title text describing the premium feature.
  final String title;

  /// Subtitle text with a brief value proposition.
  final String subtitle;

  /// Icon displayed above the title.
  final IconData icon;

  /// Fallback callback when [subscriptionService] is null.
  final VoidCallback? onUpgrade;

  /// Optional subscription service for presenting the RevenueCat paywall.
  final SubscriptionService? subscriptionService;

  void _handleUpgrade() {
    if (subscriptionService != null) {
      subscriptionService!.presentPaywallIfNeeded();
    } else if (onUpgrade != null) {
      onUpgrade!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "$title, upgrade to premium",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230), // 0.9 opacity
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: Semantics(
                label: "Upgrade to premium for $title",
                child: ElevatedButton(
                  onPressed: _handleUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Go Premium"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
