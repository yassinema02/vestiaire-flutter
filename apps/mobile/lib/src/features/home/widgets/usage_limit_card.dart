import "package:flutter/material.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../outfits/models/usage_limit_result.dart";

/// Card displayed when a free-tier user has reached their daily
/// AI outfit generation limit.
///
/// Shows a message about the limit being reached, when it resets,
/// and a CTA to upgrade to premium.
class UsageLimitCard extends StatelessWidget {
  const UsageLimitCard({
    required this.limitInfo,
    this.onUpgrade,
    this.subscriptionService,
    super.key,
  });

  final UsageLimitReachedResult limitInfo;
  final VoidCallback? onUpgrade;

  /// Optional subscription service for presenting the RevenueCat paywall.
  /// When provided, the CTA button calls presentPaywallIfNeeded().
  /// When null, falls back to the onUpgrade callback (backward compat).
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
      label: "Daily outfit generation limit reached",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            const Text(
              "Daily Limit Reached",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "You've used all 3 outfit suggestions for today",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Resets at midnight UTC",
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Semantics(
              label: "Upgrade to premium for unlimited suggestions",
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _handleUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Go Premium for Unlimited Suggestions",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
