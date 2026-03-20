import "dart:async";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../../../core/networking/api_client.dart";
import "../../analytics/screens/analytics_dashboard_screen.dart";
import "../../resale/screens/spring_clean_screen.dart";
import "../models/wardrobe_item.dart";
import "../widgets/filter_bar.dart";
import "bulk_import_preview_screen.dart";
import "item_detail_screen.dart";

/// Wardrobe tab screen displaying the user's items in a grid.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({
    required this.apiClient,
    this.imagePicker,
    super.key,
  });

  final ApiClient apiClient;
  final ImagePicker? imagePicker;

  @override
  State<WardrobeScreen> createState() => WardrobeScreenState();
}

class WardrobeScreenState extends State<WardrobeScreen>
    with TickerProviderStateMixin {
  List<WardrobeItem>? _items;
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPollRetries = 10;

  /// Filter state: keys are dimension names, values are selected filter values.
  Map<String, String?> _activeFilters = {};

  /// Total item count (unfiltered) for "X of Y items" display.
  int _totalItemCount = 0;

  /// Available brands derived from the full unfiltered item list.
  List<String> _availableBrands = [];

  /// Health score mini bar state.
  Map<String, dynamic>? _healthScoreData;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadHealthScore();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  /// Reload items from the API. Can be called externally via a GlobalKey.
  Future<void> refresh() async {
    await _loadItems();
  }

  bool get _hasActiveFilters =>
      _activeFilters.values.any((v) => v != null);

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // If filters are active, load both unfiltered (for total count & brands)
      // and filtered results. Otherwise, just load all items.
      if (_hasActiveFilters) {
        final results = await Future.wait([
          widget.apiClient.listItems(),
          widget.apiClient.listItems(
            category: _activeFilters["category"],
            color: _activeFilters["color"],
            season: _activeFilters["season"],
            occasion: _activeFilters["occasion"],
            brand: _activeFilters["brand"],
            neglectStatus: _activeFilters["neglect"],
          ),
        ]);

        final allRawItems = (results[0]["items"] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final allItems =
            allRawItems.map((json) => WardrobeItem.fromJson(json)).toList();

        final filteredRawItems = (results[1]["items"] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final filteredItems =
            filteredRawItems.map((json) => WardrobeItem.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _totalItemCount = allItems.length;
            _availableBrands = _extractBrands(allItems);
            _items = filteredItems;
            _isLoading = false;
          });
          _checkAndStartPolling();
        }
      } else {
        final result = await widget.apiClient.listItems();
        final rawItems = (result["items"] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final items =
            rawItems.map((json) => WardrobeItem.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _items = items;
            _totalItemCount = items.length;
            _availableBrands = _extractBrands(items);
            _isLoading = false;
          });
          _checkAndStartPolling();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load items.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHealthScore() async {
    try {
      final result = await widget.apiClient.getWardrobeHealthScore();
      if (mounted) {
        setState(() {
          _healthScoreData = result;
        });
      }
    } catch (_) {
      // Fail silently -- hide the mini health bar on error
      if (mounted) {
        setState(() {
          _healthScoreData = null;
        });
      }
    }
  }

  /// Extract unique, sorted brand values from items.
  List<String> _extractBrands(List<WardrobeItem> items) {
    return items
        .map((item) => item.brand)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }

  void _onFiltersChanged(Map<String, String?> newFilters) {
    setState(() {
      _activeFilters = newFilters;
    });
    _loadItems();
  }

  void _checkAndStartPolling() {
    final hasPendingItems = _items?.any((item) =>
            item.isProcessing || item.isCategorizationPending) ??
        false;

    if (hasPendingItems && _pollCount < _maxPollRetries) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_pollingTimer?.isActive ?? false) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForUpdates();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollCount = 0;
  }

  Future<void> _pollForUpdates() async {
    if (!mounted) {
      _stopPolling();
      return;
    }

    _pollCount++;
    if (_pollCount > _maxPollRetries) {
      _stopPolling();
      return;
    }

    try {
      // Poll with current filters applied
      final result = _hasActiveFilters
          ? await widget.apiClient.listItems(
              category: _activeFilters["category"],
              color: _activeFilters["color"],
              season: _activeFilters["season"],
              occasion: _activeFilters["occasion"],
              brand: _activeFilters["brand"],
              neglectStatus: _activeFilters["neglect"],
            )
          : await widget.apiClient.listItems();
      final rawItems = (result["items"] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final items = rawItems.map((json) => WardrobeItem.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _items = items;
          if (!_hasActiveFilters) {
            _totalItemCount = items.length;
          }
        });

        final stillPending = items.any(
            (item) => item.isProcessing || item.isCategorizationPending);
        if (!stillPending) {
          _stopPolling();
        }
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  Future<void> _retryBackgroundRemoval(String itemId) async {
    try {
      await widget.apiClient.retryBackgroundRemoval(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Retrying background removal..."),
          ),
        );
        // Refresh to show pending state
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to retry. Please try again."),
          ),
        );
      }
    }
  }

  Future<void> _retryCategorization(String itemId) async {
    try {
      await widget.apiClient.retryCategorization(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Retrying categorization..."),
          ),
        );
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to retry. Please try again."),
          ),
        );
      }
    }
  }

  static const int _maxBulkPhotos = 50;

  Future<void> _startBulkImport() async {
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 512,
      );

      if (!mounted || images.isEmpty) return;

      List<String> photoPaths = images.map((xf) => xf.path).toList();

      if (photoPaths.length > _maxBulkPhotos) {
        photoPaths = photoPaths.take(_maxBulkPhotos).toList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Maximum 50 photos. Only the first 50 were selected.",
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulkImportPreviewScreen(
            photoPaths: photoPaths,
            apiClient: widget.apiClient,
            onImportComplete: () {
              refresh();
            },
          ),
        ),
      );
    } on PlatformException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Photo library access required. Please grant access in Settings.",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Wardrobe"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        actions: [
          Semantics(
            label: "Bulk Import",
            child: IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: "Bulk Import",
              onPressed: _startBulkImport,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: "Retry",
              child: ElevatedButton(
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
            ),
          ],
        ),
      );
    }

    // Empty wardrobe (no items at all, unfiltered)
    if ((_items == null || _items!.isEmpty) && !_hasActiveFilters) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checkroom,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              "Your wardrobe is empty.\nTap + to add your first item!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Build the item count text
    final itemCountText = _hasActiveFilters
        ? "${_items?.length ?? 0} of $_totalItemCount items"
        : "${_items?.length ?? 0} items";

    return Column(
      children: [
        if (_healthScoreData != null) _buildMiniHealthBar(),
        FilterBar(
          activeFilters: _activeFilters,
          onFiltersChanged: _onFiltersChanged,
          availableBrands: _availableBrands,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              itemCountText,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
          ),
        ),
        // Filtered empty state
        if (_items != null && _items!.isEmpty && _hasActiveFilters)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_list_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No items match your filters",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _onFiltersChanged({});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Clear Filters"),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _items!.length,
                itemBuilder: (context, index) {
                  final item = _items![index];
                  return _buildItemTile(item);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniHealthBar() {
    final data = _healthScoreData!;
    final score = (data["score"] as num?)?.toInt() ?? 0;
    final colorTier = data["colorTier"] as String? ?? "red";
    final recommendation = data["recommendation"] as String? ?? "";

    Color tierColor;
    String tierLabel;
    switch (colorTier) {
      case "green":
        tierColor = const Color(0xFF22C55E);
        tierLabel = "Green";
        break;
      case "yellow":
        tierColor = const Color(0xFFF59E0B);
        tierLabel = "Yellow";
        break;
      default:
        tierColor = const Color(0xFFEF4444);
        tierLabel = "Red";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Semantics(
        label: "Wardrobe health score $score, tap to view details",
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AnalyticsDashboardScreen(
                  apiClient: widget.apiClient,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: tierColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                Text(
                  "$score",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tierLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: "Spring Clean",
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SpringCleanScreen(
                            apiClient: widget.apiClient,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cleaning_services,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(WardrobeItem item) {
    Widget child = Semantics(
      label: "View ${item.displayLabel}",
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(
                item: item,
                apiClient: widget.apiClient,
              ),
            ),
          );
          if (result == true) {
            refresh();
          }
        },
        child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.photoUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: const Color(0xFFE5E7EB),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFE5E7EB),
                child: const Icon(
                  Icons.image,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            // Shimmer overlay for bg removal pending items
            if (item.isProcessing) const _ShimmerOverlay(),
            // Shimmer overlay for categorization pending items (bottom portion)
            if (item.isCategorizationPending)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 32,
                child: _ShimmerOverlay(),
              ),
            // Warning badge for bg removal failed items
            if (item.isFailed)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            // Info icon badge for categorization failed items
            if (item.isCategorizationFailed)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            // Category label for completed categorization
            if (item.isCategorizationCompleted && item.category != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: Colors.black54,
                  child: Text(
                    _formatCategory(item.category!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Neglect badge for neglected items (not processing/pending)
            if (!item.isProcessing && !item.isCategorizationPending && item.isNeglected)
              Positioned(
                bottom: 0,
                left: 0,
                child: Semantics(
                  label: "Neglected item",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          "Neglected",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );

    // Long-press context menu for failed items (bg removal or categorization)
    if (item.isFailed || item.isCategorizationFailed) {
      child = GestureDetector(
        onLongPress: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.isFailed)
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text("Retry Background Removal"),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _retryBackgroundRemoval(item.id);
                      },
                    ),
                  if (item.isCategorizationFailed)
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text("Retry Categorization"),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _retryCategorization(item.id);
                      },
                    ),
                ],
              ),
            ),
          );
        },
        child: child,
      );
    }

    return child;
  }

  /// Format category for display (capitalize first letter).
  String _formatCategory(String category) {
    if (category.isEmpty) return category;
    return category[0].toUpperCase() + category.substring(1);
  }
}

/// A shimmer/skeleton overlay effect using built-in Flutter animation primitives.
class _ShimmerOverlay extends StatefulWidget {
  const _ShimmerOverlay();

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x80FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: Container(
        color: const Color(0x40FFFFFF),
      ),
    );
  }
}
