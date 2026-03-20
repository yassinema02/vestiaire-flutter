import "package:flutter/material.dart";

import "../models/taxonomy.dart";

/// Filter dimensions available for wardrobe items.
const List<String> _filterDimensions = [
  "category",
  "color",
  "season",
  "occasion",
  "brand",
  "neglect",
];

/// Display labels for each filter dimension.
const Map<String, String> _dimensionLabels = {
  "category": "Category",
  "color": "Color",
  "season": "Season",
  "occasion": "Occasion",
  "brand": "Brand",
  "neglect": "Neglect",
};

/// A horizontal filter bar with chips for each filter dimension.
///
/// Displays filter chips for Category, Color, Season, Occasion, and Brand.
/// When a filter is active, the chip shows the selected value and is visually
/// highlighted. Includes a "Clear All" action when any filter is active.
class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.activeFilters,
    required this.onFiltersChanged,
    required this.availableBrands,
    super.key,
  });

  /// Currently active filters. Keys are dimension names (e.g., "category"),
  /// values are the selected filter value (e.g., "tops"), or null if unset.
  final Map<String, String?> activeFilters;

  /// Called when the user changes filters.
  final ValueChanged<Map<String, String?>> onFiltersChanged;

  /// List of available brand values derived from the user's wardrobe items.
  final List<String> availableBrands;

  bool get _hasActiveFilters =>
      activeFilters.values.any((v) => v != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterDimensions.map((dimension) {
                    final activeValue = activeFilters[dimension];
                    final isActive = activeValue != null;
                    final label = isActive
                        ? taxonomyDisplayLabel(activeValue)
                        : _dimensionLabels[dimension]!;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        label: "${_dimensionLabels[dimension]} filter${isActive ? ", selected: $label" : ""}",
                        child: FilterChip(
                          selected: isActive,
                          label: Text(label),
                          selectedColor: const Color(0xFF4F46E5),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isActive ? Colors.white : null,
                          ),
                          onSelected: (_) {
                            _showFilterOptions(context, dimension);
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_hasActiveFilters)
              Semantics(
                label: "Clear all filters",
                child: IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () {
                    onFiltersChanged({});
                  },
                  tooltip: "Clear All",
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(BuildContext context, String dimension) {
    final options = _getOptionsForDimension(dimension);
    final currentValue = activeFilters[dimension];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Semantics(
              label: "All ${_dimensionLabels[dimension]} options",
              child: ListTile(
                title: const Text("All"),
                leading: Icon(
                  currentValue == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: const Color(0xFF4F46E5),
                ),
                onTap: () {
                  final newFilters = Map<String, String?>.from(activeFilters);
                  newFilters.remove(dimension);
                  onFiltersChanged(newFilters);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
            ...options.map((option) {
              final isSelected = currentValue == option;
              return Semantics(
                label: "${taxonomyDisplayLabel(option)} option",
                child: ListTile(
                  title: Text(taxonomyDisplayLabel(option)),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: const Color(0xFF4F46E5),
                  ),
                  onTap: () {
                    final newFilters =
                        Map<String, String?>.from(activeFilters);
                    newFilters[dimension] = option;
                    onFiltersChanged(newFilters);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String> _getOptionsForDimension(String dimension) {
    switch (dimension) {
      case "category":
        return validCategories;
      case "color":
        return validColors;
      case "season":
        return validSeasons;
      case "occasion":
        return validOccasions;
      case "brand":
        return availableBrands;
      case "neglect":
        return ["neglected"];
      default:
        return [];
    }
  }
}
