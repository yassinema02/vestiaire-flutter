import "package:flutter/material.dart";

import "../models/taxonomy.dart";

/// A modal bottom sheet for selecting taxonomy values.
///
/// Supports both single-select (auto-closes on selection) and
/// multi-select (requires tapping "Done") modes. Includes a
/// search/filter text field for long option lists.
class TagSelectionSheet extends StatefulWidget {
  const TagSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValues,
    this.isMultiSelect = false,
    super.key,
  });

  /// The title displayed at the top of the sheet.
  final String title;

  /// All valid options for this field.
  final List<String> options;

  /// Currently selected value(s).
  final List<String> selectedValues;

  /// Whether multiple values can be selected.
  final bool isMultiSelect;

  @override
  State<TagSelectionSheet> createState() => _TagSelectionSheetState();
}

class _TagSelectionSheetState extends State<TagSelectionSheet> {
  late List<String> _selected;
  String _filter = "";

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedValues);
  }

  List<String> get _filteredOptions {
    if (_filter.isEmpty) return widget.options;
    final lower = _filter.toLowerCase();
    return widget.options
        .where((o) => taxonomyDisplayLabel(o).toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                if (widget.isMultiSelect)
                  Semantics(
                    label: "Done",
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              label: "Filter options",
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredOptions.length,
              itemBuilder: (context, index) {
                final option = _filteredOptions[index];
                final isSelected = _selected.contains(option);
                final label = taxonomyDisplayLabel(option);

                return Semantics(
                  label: label,
                  child: ListTile(
                    title: Text(label),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                        : null,
                    onTap: () {
                      if (widget.isMultiSelect) {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(option);
                          } else {
                            _selected.add(option);
                          }
                        });
                      } else {
                        Navigator.of(context).pop([option]);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
