import "package:flutter/material.dart";

import "../models/taxonomy.dart";
import "tag_selection_sheet.dart";

/// Describes a group of tags for a single taxonomy field.
class TagGroup {
  const TagGroup({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.isMultiSelect = false,
  });

  /// Display label for this group (e.g., "Category", "Color").
  final String label;

  /// Current value(s). Single-select uses a one-element list.
  final List<String> value;

  /// All valid taxonomy options for this field.
  final List<String> options;

  /// Called when the user changes the selection.
  final ValueChanged<List<String>> onChanged;

  /// Whether this field supports multiple selections.
  final bool isMultiSelect;
}

/// A reusable tag cloud widget that displays taxonomy fields as chips.
///
/// Each group renders as a labeled row of chips. Tapping a chip opens
/// a [TagSelectionSheet] bottom sheet. Supports a loading state with
/// shimmer placeholders.
class TagCloud extends StatelessWidget {
  const TagCloud({
    required this.groups,
    this.isLoading = false,
    super.key,
  });

  /// The tag groups to display.
  final List<TagGroup> groups;

  /// When true, renders shimmer placeholders instead of real chips.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildShimmerPlaceholders();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) => _buildGroup(context, group)).toList(),
    );
  }

  Widget _buildShimmerPlaceholders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 72,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, TagGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.value.isEmpty
                ? [
                    _buildChip(
                      context,
                      group,
                      "Not set",
                      isPlaceholder: true,
                    ),
                  ]
                : group.value
                    .map((v) => _buildChip(context, group, v))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    TagGroup group,
    String value, {
    bool isPlaceholder = false,
  }) {
    final label = isPlaceholder ? value : taxonomyDisplayLabel(value);

    return Semantics(
      label: "${group.label}: $label",
      child: SizedBox(
        height: 44,
        child: ActionChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isPlaceholder
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF1F2937),
            ),
          ),
          backgroundColor:
              isPlaceholder ? const Color(0xFFF3F4F6) : const Color(0xFFEEF2FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPlaceholder
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF4F46E5).withValues(alpha: 0.3),
            ),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => _openSelectionSheet(context, group),
        ),
      ),
    );
  }

  Future<void> _openSelectionSheet(BuildContext context, TagGroup group) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TagSelectionSheet(
        title: group.label,
        options: group.options,
        selectedValues: group.value,
        isMultiSelect: group.isMultiSelect,
      ),
    );

    if (result != null) {
      group.onChanged(result);
    }
  }
}
