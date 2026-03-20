import "package:flutter/material.dart";
import "package:intl/intl.dart";

/// A row of three summary metric cards for the analytics dashboard.
///
/// Displays total items, wardrobe value, and average cost-per-wear.
class SummaryCardsRow extends StatelessWidget {
  const SummaryCardsRow({
    required this.totalItems,
    required this.totalValue,
    required this.averageCpw,
    required this.currency,
    super.key,
  });

  final int totalItems;
  final double? totalValue;
  final double? averageCpw;
  final String? currency;

  static String _currencySymbol(String? currency) {
    switch (currency?.toUpperCase()) {
      case "GBP":
        return "\u00a3";
      case "EUR":
        return "\u20ac";
      case "USD":
        return "\$";
      default:
        return "\u00a3";
    }
  }

  static String _formatCurrency(double value, String symbol, {int decimals = 0}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimals,
    );
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _currencySymbol(currency);

    final valueDisplay = (totalValue != null && totalValue! > 0)
        ? _formatCurrency(totalValue!, symbol)
        : "N/A";

    final cpwDisplay = averageCpw != null
        ? _formatCurrency(averageCpw!, symbol, decimals: 2)
        : "N/A";

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.checkroom,
            value: "$totalItems",
            label: "Total Items",
            semanticsLabel: "Total items: $totalItems",
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.account_balance_wallet_outlined,
            value: valueDisplay,
            label: "Wardrobe Value",
            semanticsLabel: "Wardrobe value: $valueDisplay",
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.trending_down,
            value: cpwDisplay,
            label: "Avg. Cost/Wear",
            semanticsLabel: "Average cost per wear: $cpwDisplay",
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String value;
  final String label;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
