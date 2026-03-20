import "dart:collection";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../../wardrobe/models/wardrobe_item.dart";
import "../services/outfit_persistence_service.dart";
import "name_outfit_screen.dart";

/// Category tab definitions for grouping wardrobe items.
const List<Map<String, dynamic>> _categoryGroups = [
  {"key": "tops", "label": "Tops"},
  {"key": "bottoms", "label": "Bottoms"},
  {"key": "dresses", "label": "Dresses"},
  {"key": "outerwear", "label": "Outerwear"},
  {"key": "shoes", "label": "Shoes"},
  {"key": "bags", "label": "Bags"},
  {"key": "accessories", "label": "Accessories"},
  {"key": "other", "label": "Other"},
];

/// Categories that map to the "Other" tab.
const Set<String> _otherCategories = {
  "activewear",
  "swimwear",
  "underwear",
  "sleepwear",
  "suits",
  "other",
};

/// Screen for selecting wardrobe items to build a manual outfit.
///
/// Displays categorized items in a tabbed grid view. Users can select
/// 1-7 items across categories, preview selections, and proceed to
/// naming the outfit.
class CreateOutfitScreen extends StatefulWidget {
  const CreateOutfitScreen({
    required this.apiClient,
    required this.outfitPersistenceService,
    super.key,
  });

  final ApiClient apiClient;
  final OutfitPersistenceService outfitPersistenceService;

  @override
  State<CreateOutfitScreen> createState() => _CreateOutfitScreenState();
}

class _CreateOutfitScreenState extends State<CreateOutfitScreen> {
  List<WardrobeItem>? _items;
  bool _isLoading = true;
  String? _error;
  final Set<String> _selectedItemIds = LinkedHashSet<String>();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.apiClient.listItems();
      final itemsList = response["items"] as List<dynamic>? ?? [];
      final parsed = itemsList
          .map((json) => WardrobeItem.fromJson(json as Map<String, dynamic>))
          .where((item) => item.categorizationStatus == "completed")
          .toList();

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load items";
        _isLoading = false;
      });
    }
  }

  /// Get items for a given category key.
  List<WardrobeItem> _itemsForCategory(String categoryKey) {
    if (_items == null) return [];
    if (categoryKey == "other") {
      return _items!.where((item) {
        final cat = item.category;
        return cat == null || _otherCategories.contains(cat);
      }).toList();
    }
    return _items!.where((item) => item.category == categoryKey).toList();
  }

  /// Get category groups that have at least one item.
  List<Map<String, dynamic>> _activeCategories() {
    return _categoryGroups
        .where((group) =>
            _itemsForCategory(group["key"] as String).isNotEmpty)
        .toList();
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else if (_selectedItemIds.length < 7) {
        _selectedItemIds.add(itemId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Maximum 7 items per outfit")),
        );
      }
    });
  }

  void _removeSelection(String itemId) {
    setState(() {
      _selectedItemIds.remove(itemId);
    });
  }

  WardrobeItem? _findItem(String id) {
    if (_items == null) return null;
    try {
      return _items!.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _navigateToNameScreen() async {
    // Build selected items list preserving selection order.
    final selectedItems = <WardrobeItem>[];
    for (final id in _selectedItemIds) {
      final item = _findItem(id);
      if (item != null) selectedItems.add(item);
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NameOutfitScreen(
          selectedItems: selectedItems,
          outfitPersistenceService: widget.outfitPersistenceService,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_items != null && _items!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checkroom, size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "No items available. Add and categorize items in your wardrobe first.",
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Go to Wardrobe"),
              ),
            ],
          ),
        ),
      );
    }

    final activeCategories = _activeCategories();

    return DefaultTabController(
      length: activeCategories.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Category tabs
            Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                indicatorColor: const Color(0xFF4F46E5),
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: const Color(0xFF6B7280),
                tabs: activeCategories.map((group) {
                  final key = group["key"] as String;
                  final label = group["label"] as String;
                  final count = _itemsForCategory(key).length;
                  return Semantics(
                    label: "Category: $label, $count items",
                    child: Tab(text: "$label ($count)"),
                  );
                }).toList(),
              ),
            ),
            // Item grids
            Expanded(
              child: TabBarView(
                children: activeCategories.map((group) {
                  final key = group["key"] as String;
                  final items = _itemsForCategory(key);
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildItemTile(items[index]);
                    },
                  );
                }).toList(),
              ),
            ),
            // Selected items preview strip
            if (_selectedItemIds.isNotEmpty) _buildPreviewStrip(),
            // Next button
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final count = _selectedItemIds.length;
    final subtitle = count == 0 ? "Select items" : "$count items selected";
    return AppBar(
      backgroundColor: const Color(0xFFF3F4F6),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Create Outfit",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(WardrobeItem item) {
    final isSelected = _selectedItemIds.contains(item.id);
    final label = item.displayLabel;
    final semanticsLabel = isSelected
        ? "Selected: $label. Tap to deselect."
        : "Select $label";

    return Semantics(
      label: semanticsLabel,
      child: GestureDetector(
        onTap: () => _toggleSelection(item.id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Item image
              CachedNetworkImage(
                imageUrl: item.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFFE5E7EB)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(Icons.image_not_supported,
                      color: Color(0xFF9CA3AF)),
                ),
              ),
              // Selection overlay
              if (isSelected)
                Container(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                ),
              // Checkmark badge
              if (isSelected)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFF4F46E5),
                    child: Icon(Icons.check_circle, size: 24, color: Colors.white),
                  ),
                ),
              // Bottom label
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewStrip() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: _selectedItemIds.map((id) {
            final item = _findItem(id);
            if (item == null) return const SizedBox.shrink();
            return Semantics(
              label: "Remove ${item.displayLabel} from outfit",
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _removeSelection(id),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CachedNetworkImage(
                        imageUrl: item.photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFFE5E7EB)),
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final count = _selectedItemIds.length;
    final isEnabled = count >= 1 && count <= 7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isEnabled ? _navigateToNameScreen : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text("Next"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (count > 7)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Maximum 7 items per outfit",
                style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),
        ],
      ),
    );
  }
}
