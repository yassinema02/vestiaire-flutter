import "package:flutter/material.dart";

import "../../outfits/models/usage_info.dart";

/// Compact usage indicator displayed below the outfit suggestion section.
///
/// Shows remaining generation count for free users, or nothing for premium users.
class UsageIndicator extends StatelessWidget {
  const UsageIndicator({
    required this.usageInfo,
    super.key,
  });

  final UsageInfo usageInfo;

  @override
  Widget build(BuildContext context) {
    // Premium users see no indicator
    if (usageInfo.isPremium) {
      return const SizedBox.shrink();
    }

    final isLimitReached = usageInfo.isLimitReached;

    return Semantics(
      label: usageInfo.remainingText,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLimitReached ? Icons.warning_amber_rounded : Icons.auto_awesome,
            size: 14,
            color: isLimitReached
                ? const Color(0xFFF59E0B)
                : const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 4),
          Text(
            isLimitReached ? "Daily limit reached" : usageInfo.remainingText,
            style: TextStyle(
              fontSize: 12,
              color: isLimitReached
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF6B7280),
              fontWeight: isLimitReached ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
