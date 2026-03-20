import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

/// CPW color thresholds (currency-agnostic per FR-ANA-02).
const double cpwGreenThreshold = 5.0;
const double cpwYellowThreshold = 20.0;

/// A single item row in the cost-per-wear breakdown list.
///
/// Displays item thumbnail, name/category, purchase price, wear count,
/// CPW value with color coding, and handles tap navigation.
class CpwItemRow extends StatelessWidget {
  const CpwItemRow({
    required this.itemId,
    required this.name,
    required this.category,
    required this.photoUrl,
    required this.purchasePrice,
    required this.currency,
    required this.wearCount,
    required this.cpw,
    required this.onTap,
    super.key,
  });

  final String itemId;
  final String? name;
  final String? category;
  final String? photoUrl;
  final double? purchasePrice;
  final String? currency;
  final int wearCount;
  final double? cpw;
  final VoidCallback onTap;

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

  /// Get the CPW color based on thresholds.
  static Color getCpwColor(double? cpw, int wearCount) {
    if (wearCount == 0) return const Color(0xFFEF4444);
    if (cpw == null) return const Color(0xFF9CA3AF);
    if (cpw < cpwGreenThreshold) return const Color(0xFF22C55E);
    if (cpw <= cpwYellowThreshold) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  /// Get the CPW display text.
  static String getCpwDisplayText(double? cpw, int wearCount, String symbol) {
    if (wearCount == 0) return "No wears";
    if (cpw == null) return "No price";
    final formatted = NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(cpw);
    return "$formatted/wear";
  }

  /// Get the value rating label for semantics.
  static String getValueRating(double? cpw, int wearCount) {
    if (wearCount == 0) return "No wears";
    if (cpw == null) return "No price";
    if (cpw < cpwGreenThreshold) return "Great value";
    if (cpw <= cpwYellowThreshold) return "Fair value";
    return "Low value";
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = name ?? category ?? "Item";
    final symbol = _currencySymbol(currency);
    final cpwText = getCpwDisplayText(cpw, wearCount, symbol);
    final cpwColor = getCpwColor(cpw, wearCount);
    final valueRating = getValueRating(cpw, wearCount);
    final priceText = purchasePrice != null
        ? NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(purchasePrice)
        : "";

    return Semantics(
      label: "$displayLabel, cost per wear: $cpwText, $valueRating",
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Thumbnail
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: photoUrl != null && photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(
                            Icons.checkroom,
                            color: Color(0xFF9CA3AF),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.checkroom,
                            color: Color(0xFF9CA3AF),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(
                            Icons.checkroom,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (priceText.isNotEmpty)
                      Text(
                        priceText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              // CPW and wear count
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cpwText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cpwColor,
                    ),
                  ),
                  Text(
                    "$wearCount wear${wearCount == 1 ? "" : "s"}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
