import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:share_plus/share_plus.dart";

import "../models/packing_list.dart";
import "../models/trip.dart";
import "../services/packing_list_service.dart";

/// Screen displaying a smart packing list for an upcoming trip.
///
/// Shows items grouped by category with checkboxes, progress indicator,
/// day-by-day outfit suggestions, and packing tips.
class PackingListScreen extends StatefulWidget {
  const PackingListScreen({
    required this.trip,
    required this.packingListService,
    super.key,
  });

  final Trip trip;
  final PackingListService packingListService;

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  PackingList? _packingList;
  bool _isLoading = true;
  String? _error;
  Map<String, bool> _packedStatus = {};
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadPackingList();
  }

  Future<void> _loadPackingList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Try cached first
    final cached = await widget.packingListService
        .getCachedPackingList(widget.trip.id);
    if (cached != null) {
      final packedStatus =
          await widget.packingListService.getPackedStatus(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _packingList = cached;
        _packedStatus = packedStatus;
        _isLoading = false;
        // Expand all categories by default
        for (final category in cached.categories) {
          _expandedCategories.add(category.name);
        }
      });
      return;
    }

    // Generate fresh
    final result =
        await widget.packingListService.generatePackingList(widget.trip);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _error = "Failed to generate packing list. Please try again.";
      });
      return;
    }

    // Cache the result
    await widget.packingListService.cachePackingList(widget.trip.id, result);

    setState(() {
      _packingList = result;
      _isLoading = false;
      for (final category in result.categories) {
        _expandedCategories.add(category.name);
      }
    });
  }

  int get _packedCount {
    int count = 0;
    if (_packingList == null) return 0;
    for (final category in _packingList!.categories) {
      for (final item in category.items) {
        final key = item.itemId ?? item.name;
        if (_packedStatus[key] == true) {
          count++;
        }
      }
    }
    return count;
  }

  int get _totalCount {
    if (_packingList == null) return 0;
    return _packingList!.totalItems;
  }

  void _togglePacked(PackingListItem item) {
    final key = item.itemId ?? item.name;
    final newPacked = !(_packedStatus[key] ?? false);
    setState(() {
      _packedStatus[key] = newPacked;
    });
    widget.packingListService
        .updatePackedStatus(widget.trip.id, key, newPacked);
  }

  Future<void> _handleRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Regenerate Packing List?"),
        content: const Text(
            "This will regenerate the list and reset all packed items. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Regenerate"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.packingListService.clearPackedStatus(widget.trip.id);
    setState(() {
      _packedStatus = {};
    });

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result =
        await widget.packingListService.generatePackingList(widget.trip);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _error = "Failed to regenerate packing list.";
      });
      return;
    }

    await widget.packingListService.cachePackingList(widget.trip.id, result);
    setState(() {
      _packingList = result;
      _isLoading = false;
      _expandedCategories.clear();
      for (final category in result.categories) {
        _expandedCategories.add(category.name);
      }
    });
  }

  void _handleExport() {
    if (_packingList == null) return;

    final buffer = StringBuffer();
    buffer.writeln(
        "Packing List: Trip to ${widget.trip.destination}");
    final formatter = DateFormat("MMM d, yyyy");
    buffer.writeln(
        "${formatter.format(widget.trip.startDate)} - ${formatter.format(widget.trip.endDate)} (${widget.trip.durationDays} days)");
    buffer.writeln();

    for (final category in _packingList!.categories) {
      buffer.writeln(category.name.toUpperCase());
      for (final item in category.items) {
        final key = item.itemId ?? item.name;
        final packed = _packedStatus[key] == true;
        final checkbox = packed ? "[x]" : "[ ]";
        final packedLabel = packed ? " (packed)" : "";
        buffer.writeln("$checkbox ${item.name}$packedLabel");
      }
      buffer.writeln();
    }

    if (_packingList!.dailyOutfits.isNotEmpty) {
      buffer.writeln("DAY-BY-DAY OUTFITS");
      for (final outfit in _packingList!.dailyOutfits) {
        final dateStr = DateFormat("MMM d").format(outfit.date);
        buffer.writeln(
            "Day ${outfit.day} ($dateStr): ${outfit.outfitItemIds.join(", ")} - ${outfit.occasion}");
      }
      buffer.writeln();
    }

    if (_packingList!.tips.isNotEmpty) {
      buffer.writeln("TIPS");
      for (final tip in _packingList!.tips) {
        buffer.writeln("- $tip");
      }
      buffer.writeln();
    }

    buffer.writeln("Generated by Vestiaire");

    Share.share(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Semantics(
          label:
              "Packing list for trip to ${widget.trip.destination}",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Packing List", style: TextStyle(fontSize: 18)),
              Text(
                "${widget.trip.destination} (${widget.trip.durationDays} days)",
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        actions: [
          Semantics(
            label: "Export packing list",
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: _packingList != null ? _handleExport : null,
            ),
          ),
          Semantics(
            label: "Regenerate packing list",
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: !_isLoading ? _handleRegenerate : null,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmer();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadPackingList,
              child: const Text("Try Again"),
            ),
          ],
        ),
      );
    }

    if (_packingList == null) {
      return const Center(child: Text("No packing list available"));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress indicator
        _buildProgressIndicator(),
        const SizedBox(height: 12),

        // Fallback banner
        if (_packingList!.fallback) ...[
          _buildFallbackBanner(),
          const SizedBox(height: 12),
        ],

        // Weather unavailable note
        if (_packingList!.weatherUnavailable && !_packingList!.fallback) ...[
          _buildWeatherUnavailableNote(),
          const SizedBox(height: 12),
        ],

        // Category sections
        for (final category in _packingList!.categories)
          _buildCategorySection(category),

        // Day-by-day outfits
        if (_packingList!.dailyOutfits.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDailyOutfitsSection(),
        ],

        // Tips
        if (_packingList!.tips.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTipsSection(),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _totalCount > 0 ? _packedCount / _totalCount : 0.0;
    return Semantics(
      label: "$_packedCount of $_totalCount items packed",
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$_packedCount of $_totalCount items packed",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        "AI-generated list unavailable. Showing general recommendations based on trip duration.",
        style: TextStyle(fontSize: 14, color: Color(0xFF92400E)),
      ),
    );
  }

  Widget _buildWeatherUnavailableNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        "Weather data unavailable for destination. Pack for variable conditions.",
        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
    );
  }

  Widget _buildCategorySection(PackingListCategory category) {
    final isExpanded = _expandedCategories.contains(category.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category.name);
                } else {
                  _expandedCategories.add(category.name);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${category.name} (${category.items.length})",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            ...category.items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(PackingListItem item) {
    final key = item.itemId ?? item.name;
    final isPacked = _packedStatus[key] == true;

    return Semantics(
      label:
          "Mark ${item.name} as ${isPacked ? 'unpacked' : 'packed'}",
      child: InkWell(
        onTap: () => _togglePacked(item),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isPacked,
                  onChanged: (_) => _togglePacked(item),
                  activeColor: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              // Thumbnail
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE5E7EB),
                ),
                child: item.thumbnailUrl != null
                    ? ClipOval(
                        child: Image.network(
                          item.thumbnailUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.checkroom,
                                  size: 16, color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : const Icon(Icons.checkroom,
                        size: 16, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: const Color(0xFF111827),
                        decoration: isPacked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.reason.isNotEmpty)
                      Text(
                        item.reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyOutfitsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Day-by-Day Outfits",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          for (final outfit in _packingList!.dailyOutfits)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Day ${outfit.day} - ${DateFormat("MMM d").format(outfit.date)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                  if (outfit.occasion.isNotEmpty)
                    Text(
                      outfit.occasion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tips",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          for (final tip in _packingList!.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("  \u2022  ",
                      style: TextStyle(color: Color(0xFF6B7280))),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    // Simple loading shimmer placeholder
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(
                3,
                (j) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
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
}
