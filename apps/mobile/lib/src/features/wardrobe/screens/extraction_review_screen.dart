import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../models/taxonomy.dart";

/// Extraction Review screen showing all extracted items with
/// Keep/Remove toggles, duplicate warnings, metadata editing,
/// and a confirm button to promote items to the wardrobe.
///
/// Story 10.3: Extraction Progress & Review Flow (FR-EXT-05, FR-EXT-06, FR-EXT-10)
class ExtractionReviewScreen extends StatefulWidget {
  const ExtractionReviewScreen({
    required this.jobId,
    required this.jobData,
    required this.apiClient,
    super.key,
  });

  final String jobId;
  final Map<String, dynamic> jobData;
  final ApiClient apiClient;

  @override
  State<ExtractionReviewScreen> createState() =>
      _ExtractionReviewScreenState();
}

class _ExtractionReviewScreenState extends State<ExtractionReviewScreen> {
  late List<Map<String, dynamic>> _items;
  final Map<String, bool> _keepState = {};
  final Map<String, Map<String, dynamic>> _metadataEdits = {};
  Map<String, Map<String, dynamic>> _duplicateMap = {};
  bool _isConfirming = false;
  bool _loadingDuplicates = false;
  String? _expandedItemId;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(
      (widget.jobData["items"] as List<dynamic>?) ?? [],
    );
    for (final item in _items) {
      final id = item["id"] as String;
      _keepState[id] = true;
    }
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    setState(() {
      _loadingDuplicates = true;
    });
    try {
      final result =
          await widget.apiClient.getExtractionDuplicates(widget.jobId);
      final duplicates = (result["duplicates"] as List<dynamic>?) ?? [];
      final map = <String, Map<String, dynamic>>{};
      for (final d in duplicates) {
        final dup = d as Map<String, dynamic>;
        map[dup["extractionItemId"] as String] = dup;
      }
      if (mounted) {
        setState(() {
          _duplicateMap = map;
          _loadingDuplicates = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDuplicates = false;
        });
      }
    }
  }

  int get _keptCount =>
      _keepState.values.where((v) => v).length;

  bool get _allSelected =>
      _keepState.values.isNotEmpty && _keepState.values.every((v) => v);

  void _toggleSelectAll() {
    final newValue = !_allSelected;
    setState(() {
      for (final key in _keepState.keys) {
        _keepState[key] = newValue;
      }
    });
  }

  void _toggleItem(String itemId) {
    setState(() {
      _keepState[itemId] = !(_keepState[itemId] ?? true);
    });
  }

  void _toggleExpand(String itemId) {
    setState(() {
      _expandedItemId = _expandedItemId == itemId ? null : itemId;
    });
  }

  void _updateMetadata(String itemId, String field, dynamic value) {
    setState(() {
      _metadataEdits.putIfAbsent(itemId, () => {});
      _metadataEdits[itemId]![field] = value;
    });
  }

  Future<void> _confirmSelection() async {
    final keptIds = _keepState.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // If zero items kept, show discard dialog
    if (keptIds.isEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("No Items Selected"),
          content: const Text(
            "No items selected. Discard all extracted items?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Discard"),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      // Filter metadataEdits to only include kept items
      final editsForKept = <String, Map<String, dynamic>>{};
      for (final id in keptIds) {
        if (_metadataEdits.containsKey(id)) {
          editsForKept[id] = _metadataEdits[id]!;
        }
      }

      final result = await widget.apiClient.confirmExtractionJob(
        widget.jobId,
        keptItemIds: keptIds,
        metadataEdits: editsForKept.isNotEmpty ? editsForKept : null,
      );

      if (!mounted) return;

      final confirmedCount = (result["confirmedCount"] as num?)?.toInt() ?? 0;

      // Navigate back to wardrobe
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$confirmedCount items added to your wardrobe!"),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to add items. Please try again."),
          ),
        );
      }
    }
  }

  void _showDuplicateComparison(
      Map<String, dynamic> extractionItem,
      Map<String, dynamic> duplicate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Possible Duplicate"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Extracted Item",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (extractionItem["photoUrl"] != null)
                Image.network(
                  extractionItem["photoUrl"] as String,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 100),
                ),
              Text(
                "${extractionItem["color"] ?? ""} ${extractionItem["category"] ?? ""}",
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Existing Item",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (duplicate["matchingItemPhotoUrl"] != null)
                Image.network(
                  duplicate["matchingItemPhotoUrl"] as String,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 100),
                ),
              Text(duplicate["matchingItemName"] as String? ?? "Existing Item"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Semantics(
          label: "Extraction Review",
          child: const Text("Review Extracted Items"),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  label: _loadingDuplicates
                      ? "Loading duplicates..."
                      : "${_items.length} items found, $_keptCount selected",
                  child: Text(
                    "${_items.length} items found, $_keptCount selected",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Semantics(
                  label: _allSelected ? "Deselect All" : "Select All",
                  child: TextButton(
                    onPressed: _toggleSelectAll,
                    child: Text(
                      _allSelected ? "Deselect All" : "Select All",
                      style: const TextStyle(
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final item = _items[index];
                final itemId = item["id"] as String;
                return _buildItemCard(item, itemId);
              },
            ),
          ),
          // Add to Wardrobe button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: Semantics(
                label: "Add to Wardrobe",
                child: ElevatedButton(
                  onPressed: _isConfirming ? null : _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isConfirming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          "Add to Wardrobe",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String itemId) {
    final isKept = _keepState[itemId] ?? true;
    final hasDuplicate = _duplicateMap.containsKey(itemId);
    final isExpanded = _expandedItemId == itemId;
    final edits = _metadataEdits[itemId] ?? {};

    return Semantics(
      label: "Edit item metadata",
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleExpand(itemId),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: item["photoUrl"] != null
                            ? Image.network(
                                item["photoUrl"] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFE5E7EB),
                                  child: const Icon(Icons.image,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              )
                            : Container(
                                color: const Color(0xFFE5E7EB),
                                child: const Icon(Icons.image,
                                    color: Color(0xFF9CA3AF)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item["category"] != null)
                                Chip(
                                  label: Text(
                                    taxonomyDisplayLabel(
                                      edits["category"] as String? ??
                                          item["category"] as String,
                                    ),
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              const SizedBox(width: 4),
                              if (item["color"] != null)
                                Chip(
                                  label: Text(
                                    taxonomyDisplayLabel(
                                      edits["color"] as String? ??
                                          item["color"] as String,
                                    ),
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          if (hasDuplicate) ...[
                            const SizedBox(height: 4),
                            Semantics(
                              label: "Possible duplicate warning",
                              child: GestureDetector(
                                onTap: () => _showDuplicateComparison(
                                  item,
                                  _duplicateMap[itemId]!,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber,
                                        color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      "Possible duplicate",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Keep/Remove toggle
                    Semantics(
                      label: isKept ? "Keep item" : "Remove item",
                      child: Switch(
                        value: isKept,
                        onChanged: (_) => _toggleItem(itemId),
                        activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        activeThumbColor: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded metadata editor
            if (isExpanded)
              _buildMetadataEditor(item, itemId, edits),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataEditor(
    Map<String, dynamic> item,
    String itemId,
    Map<String, dynamic> edits,
  ) {
    final currentName = edits["name"] as String? ??
        item["name"] as String? ??
        _generateDefaultName(item, edits);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Name
          TextFormField(
            initialValue: currentName,
            decoration: const InputDecoration(labelText: "Name"),
            onChanged: (val) => _updateMetadata(itemId, "name", val),
          ),
          const SizedBox(height: 8),
          // Category dropdown
          _buildDropdown(
            label: "Category",
            value: edits["category"] as String? ?? item["category"] as String?,
            items: validCategories,
            onChanged: (val) => _updateMetadata(itemId, "category", val),
          ),
          const SizedBox(height: 8),
          // Color dropdown
          _buildDropdown(
            label: "Color",
            value: edits["color"] as String? ?? item["color"] as String?,
            items: validColors,
            onChanged: (val) => _updateMetadata(itemId, "color", val),
          ),
          const SizedBox(height: 8),
          // Pattern dropdown
          _buildDropdown(
            label: "Pattern",
            value: edits["pattern"] as String? ?? item["pattern"] as String?,
            items: validPatterns,
            onChanged: (val) => _updateMetadata(itemId, "pattern", val),
          ),
          const SizedBox(height: 8),
          // Material dropdown
          _buildDropdown(
            label: "Material",
            value: edits["material"] as String? ?? item["material"] as String?,
            items: validMaterials,
            onChanged: (val) => _updateMetadata(itemId, "material", val),
          ),
          const SizedBox(height: 8),
          // Style dropdown
          _buildDropdown(
            label: "Style",
            value: edits["style"] as String? ?? item["style"] as String?,
            items: validStyles,
            onChanged: (val) => _updateMetadata(itemId, "style", val),
          ),
          const SizedBox(height: 8),
          // Season multi-select
          _buildMultiSelect(
            label: "Season",
            selected: (edits["season"] as List<String>?) ??
                ((item["season"] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                    []),
            options: validSeasons,
            onChanged: (val) => _updateMetadata(itemId, "season", val),
          ),
          const SizedBox(height: 8),
          // Occasion multi-select
          _buildMultiSelect(
            label: "Occasion",
            selected: (edits["occasion"] as List<String>?) ??
                ((item["occasion"] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                    []),
            options: validOccasions,
            onChanged: (val) => _updateMetadata(itemId, "occasion", val),
          ),
        ],
      ),
    );
  }

  String _generateDefaultName(
      Map<String, dynamic> item, Map<String, dynamic> edits) {
    final color = edits["color"] as String? ?? item["color"] as String?;
    final category = edits["category"] as String? ?? item["category"] as String?;
    if (color != null && category != null) {
      return "${taxonomyDisplayLabel(color)} ${taxonomyDisplayLabel(category)}";
    }
    return "";
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure the current value is in the items list
    final effectiveValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(taxonomyDisplayLabel(v)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMultiSelect({
    required String label,
    required List<String> selected,
    required List<String> options,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(taxonomyDisplayLabel(option)),
              selected: isSelected,
              selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.2),
              onSelected: (val) {
                final updated = List<String>.from(selected);
                if (val) {
                  updated.add(option);
                } else {
                  updated.remove(option);
                }
                onChanged(updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
