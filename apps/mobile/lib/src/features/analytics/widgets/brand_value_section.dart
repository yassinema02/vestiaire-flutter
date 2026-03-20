import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";

/// A section displaying brand value analytics as a ranked list.
///
/// Shows brands ranked by average cost-per-wear (best value first),
/// with category filter chips, summary metrics, and tap-to-navigate.
class BrandValueSection extends StatelessWidget {
  const BrandValueSection({
    required this.isPremium,
    required this.brands,
    required this.availableCategories,
    required this.bestValueBrand,
    required this.mostInvestedBrand,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onBrandTap,
    this.subscriptionService,
    super.key,
  });

  final bool isPremium;
  final List<Map<String, dynamic>> brands;
  final List<String> availableCategories;
  final Map<String, dynamic>? bestValueBrand;
  final Map<String, dynamic>? mostInvestedBrand;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<Map<String, dynamic>> onBrandTap;
  final SubscriptionService? subscriptionService;

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

  static Color _cpwColor(double? cpw) {
    if (cpw == null) return const Color(0xFF9CA3AF);
    if (cpw < 5) return const Color(0xFF22C55E);
    if (cpw <= 20) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  static String _formatCpw(double? cpw, String? currency) {
    if (cpw == null) return "N/A";
    final symbol = _currencySymbol(currency);
    return "$symbol${cpw.toStringAsFixed(2)}/wear";
  }

  static String _formatSpent(double? spent, String? currency) {
    if (spent == null || spent == 0) return "N/A";
    final symbol = _currencySymbol(currency);
    return "$symbol${NumberFormat("#,##0").format(spent.round())}";
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Check if all brands have null avgCpw (no-price state).
  bool get _allBrandsNoPricing =>
      brands.isNotEmpty && brands.every((b) => b["avgCpw"] == null);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Brand value analytics, ${brands.length} brands",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (!isPremium)
              PremiumGateCard(
                title: "Brand Value Analytics",
                subtitle:
                    "Discover which brands give you the best value for money",
                icon: Icons.diamond_outlined,
                subscriptionService: subscriptionService,
              )
            else ...[
              // Section header with info tooltip
              Row(
                children: [
                  const Text(
                    "Brand Value",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        "Brands ranked by average cost-per-wear. Minimum 3 items per brand.",
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (brands.isEmpty)
                _buildEmptyState()
              else ...[
                // Summary metrics row
                _buildSummaryMetrics(),
                const SizedBox(height: 8),
                // Category filter chips
                if (availableCategories.isNotEmpty) ...[
                  _buildCategoryFilters(),
                  const SizedBox(height: 8),
                ],
                // No-price note
                if (_allBrandsNoPricing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Add purchase prices to see cost-per-wear by brand.",
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                // Ranked brand list
                _buildBrandList(),
              ],
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.loyalty_outlined,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 8),
            Text(
              "Add more branded items to see brand analytics! Brands need at least 3 items to appear.",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    final bestBrand = bestValueBrand;
    final topSpender = mostInvestedBrand;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Best Value",
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Text(
                  bestBrand?["brand"] as String? ?? "N/A",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bestBrand != null && bestBrand["avgCpw"] != null)
                  Text(
                    _formatCpw(
                      (bestBrand["avgCpw"] as num).toDouble(),
                      bestBrand["currency"] as String?,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Most Invested",
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Text(
                  topSpender?["brand"] as String? ?? "N/A",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (topSpender != null && topSpender["totalSpent"] != null)
                  Text(
                    _formatSpent(
                      (topSpender["totalSpent"] as num).toDouble(),
                      topSpender["currency"] as String?,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    return Semantics(
      label: "Filter by category ${_capitalize(selectedCategory)}",
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(
                  "All",
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedCategory == "all"
                        ? Colors.white
                        : const Color(0xFF6B7280),
                  ),
                ),
                selected: selectedCategory == "all",
                selectedColor: const Color(0xFF4F46E5),
                backgroundColor: const Color(0xFFF3F4F6),
                onSelected: (_) => onCategoryChanged("all"),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            ...availableCategories.map((cat) {
              final isSelected = selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(
                    _capitalize(cat),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isSelected ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4F46E5),
                  backgroundColor: const Color(0xFFF3F4F6),
                  onSelected: (_) => onCategoryChanged(cat),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandList() {
    return Column(
      children: List.generate(brands.length, (index) {
        final brand = brands[index];
        final rank = index + 1;
        final brandName = brand["brand"] as String? ?? "Unknown";
        final avgCpw = (brand["avgCpw"] as num?)?.toDouble();
        final totalSpent = (brand["totalSpent"] as num?)?.toDouble();
        final totalWears = (brand["totalWears"] as num?)?.toInt() ?? 0;
        final itemCount = (brand["itemCount"] as num?)?.toInt() ?? 0;
        final currency = brand["dominantCurrency"] as String?;

        return Semantics(
          label:
              "Rank $rank, $brandName, average cost per wear ${avgCpw != null ? avgCpw.toStringAsFixed(2) : "N/A"}, $totalWears wears",
          child: InkWell(
            onTap: () => onBrandTap(brand),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4F46E5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$rank",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Brand name and metrics
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brandName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(
                              "Spent: ${_formatSpent(totalSpent, currency)}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$totalWears wears",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$itemCount items",
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
                  // Avg CPW
                  Text(
                    _formatCpw(avgCpw, currency),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _cpwColor(avgCpw),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
