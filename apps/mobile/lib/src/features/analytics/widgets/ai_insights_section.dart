import "package:flutter/material.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";

/// Displays AI-generated wardrobe insights or a premium teaser.
///
/// Has four visual states:
/// 1. Premium with summary: shows AI insight card with summary text.
/// 2. Premium loading: shows shimmer placeholder.
/// 3. Premium error: shows error message with retry button.
/// 4. Free user teaser: shows locked card with "Go Premium" CTA via PremiumGateCard.
class AiInsightsSection extends StatelessWidget {
  const AiInsightsSection({
    required this.isPremium,
    this.summary,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onUpgrade,
    this.subscriptionService,
    super.key,
  });

  final bool isPremium;
  final String? summary;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onUpgrade;

  /// Optional subscription service for presenting the RevenueCat paywall.
  final SubscriptionService? subscriptionService;

  @override
  Widget build(BuildContext context) {
    if (!isPremium) {
      return _buildFreeTeaser();
    }

    if (isLoading) {
      return _buildLoadingState();
    }

    if (error != null) {
      return _buildErrorState();
    }

    if (summary != null) {
      return _buildSummaryCard();
    }

    // Fallback: nothing to show yet
    return const SizedBox.shrink();
  }

  Widget _buildSummaryCard() {
    return Semantics(
      label: "AI wardrobe insights",
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Color(0xFF4F46E5),
                ),
                SizedBox(width: 8),
                Text(
                  "AI Insights",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: "AI generated summary: $summary",
              child: Text(
                summary!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Powered by AI",
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: Color(0xFF4F46E5),
              ),
              SizedBox(width: 8),
              Text(
                "AI Insights",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Shimmer placeholder
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Semantics(
      label: "AI wardrobe insights",
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Color(0xFF4F46E5),
                ),
                SizedBox(width: 8),
                Text(
                  "AI Insights",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Unable to generate insights right now. Pull to refresh to try again.",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                "Retry",
                style: TextStyle(color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTeaser() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PremiumGateCard(
        title: "Unlock AI Wardrobe Insights",
        subtitle: "Get personalized analysis of your wardrobe habits",
        icon: Icons.lock_outline,
        onUpgrade: onUpgrade,
        subscriptionService: subscriptionService,
      ),
    );
  }
}
