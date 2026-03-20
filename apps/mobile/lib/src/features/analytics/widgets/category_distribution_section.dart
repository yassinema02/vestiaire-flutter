import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

/// Color map for wardrobe categories.
const Map<String, Color> categoryColors = {
  "tops": Color(0xFF4F46E5),
  "bottoms": Color(0xFF22C55E),
  "dresses": Color(0xFFEC4899),
  "outerwear": Color(0xFFF59E0B),
  "shoes": Color(0xFFEF4444),
  "bags": Color(0xFF8B5CF6),
  "accessories": Color(0xFF06B6D4),
  "activewear": Color(0xFF14B8A6),
  "swimwear": Color(0xFF3B82F6),
  "underwear": Color(0xFFA78BFA),
  "sleepwear": Color(0xFF6366F1),
  "suits": Color(0xFF0EA5E9),
  "other": Color(0xFF9CA3AF),
};

/// Fallback color for unrecognized categories.
const Color _fallbackColor = Color(0xFF9CA3AF);

/// Returns the display name for a category, mapping null to "Uncategorized".
String _displayName(dynamic category) {
  if (category == null) return "Uncategorized";
  return category.toString();
}

/// Returns the color for a category.
Color _colorForCategory(dynamic category) {
  if (category == null) return _fallbackColor;
  return categoryColors[category.toString()] ?? _fallbackColor;
}

/// Displays a pie chart of wardrobe category distribution with a legend.
class CategoryDistributionSection extends StatefulWidget {
  const CategoryDistributionSection({
    required this.categories,
    super.key,
  });

  final List<Map<String, dynamic>> categories;

  @override
  State<CategoryDistributionSection> createState() =>
      _CategoryDistributionSectionState();
}

class _CategoryDistributionSectionState
    extends State<CategoryDistributionSection> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Category Distribution",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.categories.isEmpty)
            _buildEmptyState()
          else
            ...[
              Semantics(
                label:
                    "Category distribution chart, ${widget.categories.length} categories",
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: PieChart(
                    PieChartData(
                      sections: _buildSections(),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            if (_touchedIndex != -1) {
                              setState(() => _touchedIndex = -1);
                            }
                            return;
                          }
                          final index = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                          if (index != _touchedIndex) {
                            setState(() => _touchedIndex = index);
                          }
                        },
                      ),
                      centerSpaceRadius: 0,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLegend(),
            ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return List.generate(widget.categories.length, (index) {
      final cat = widget.categories[index];
      final category = cat["category"];
      final itemCount = (cat["itemCount"] as num?)?.toDouble() ?? 0;
      final percentage = (cat["percentage"] as num?)?.toDouble() ?? 0;
      final isTouched = index == _touchedIndex;

      return PieChartSectionData(
        value: itemCount,
        title: "${_displayName(category)} ${percentage.toStringAsFixed(percentage.truncateToDouble() == percentage ? 0 : 1)}%",
        color: _colorForCategory(category),
        radius: isTouched ? 90 : 80,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgePositionPercentageOffset: isTouched ? 1.2 : null,
      );
    });
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: widget.categories.map((cat) {
        final category = cat["category"];
        final itemCount = (cat["itemCount"] as num?)?.toInt() ?? 0;
        final percentage = (cat["percentage"] as num?)?.toDouble() ?? 0;

        return Semantics(
          label:
              "Category ${_displayName(category)}, $itemCount items, ${percentage.toStringAsFixed(percentage.truncateToDouble() == percentage ? 0 : 1)} percent",
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _colorForCategory(category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _displayName(category),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                "($itemCount, ${percentage.toStringAsFixed(percentage.truncateToDouble() == percentage ? 0 : 1)}%)",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            "Add items to see your wardrobe distribution!",
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
