import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../../resale/screens/resale_listing_screen.dart";
import "../../resale/services/resale_history_service.dart";
import "../../resale/services/resale_listing_service.dart";
import "../models/taxonomy.dart";
import "../models/wardrobe_item.dart";
import "review_item_screen.dart";

/// Full detail screen for a wardrobe item.
///
/// Shows the item photo, stats (wear count, CPW, last worn), and all
/// metadata. Supports editing, favoriting, and deleting the item.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    required this.item,
    required this.apiClient,
    this.resaleHistoryService,
    super.key,
  });

  final WardrobeItem item;
  final ApiClient apiClient;
  final ResaleHistoryService? resaleHistoryService;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late WardrobeItem _item;
  late final ResaleHistoryService _resaleHistoryService;
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _resaleHistoryService = widget.resaleHistoryService ??
        ResaleHistoryService(apiClient: widget.apiClient);
    _fetchItem();
  }

  Future<void> _fetchItem() async {
    try {
      final result = await widget.apiClient.getItem(widget.item.id);
      final itemData = result["item"] as Map<String, dynamic>?;
      if (itemData != null && mounted) {
        setState(() {
          _item = WardrobeItem.fromJson(itemData);
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final previous = _item.isFavorite;
    // Optimistic update
    setState(() {
      _item = WardrobeItem(
        id: _item.id,
        profileId: _item.profileId,
        photoUrl: _item.photoUrl,
        originalPhotoUrl: _item.originalPhotoUrl,
        name: _item.name,
        bgRemovalStatus: _item.bgRemovalStatus,
        category: _item.category,
        color: _item.color,
        secondaryColors: _item.secondaryColors,
        pattern: _item.pattern,
        material: _item.material,
        style: _item.style,
        season: _item.season,
        occasion: _item.occasion,
        categorizationStatus: _item.categorizationStatus,
        brand: _item.brand,
        purchasePrice: _item.purchasePrice,
        purchaseDate: _item.purchaseDate,
        currency: _item.currency,
        isFavorite: !previous,
        wearCount: _item.wearCount,
        lastWornDate: _item.lastWornDate,
        resaleStatus: _item.resaleStatus,
        createdAt: _item.createdAt,
        updatedAt: _item.updatedAt,
      );
      _hasChanged = true;
    });

    try {
      await widget.apiClient.updateItem(
        _item.id,
        {"isFavorite": !previous},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!previous ? "Added to favorites" : "Removed from favorites"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _item = WardrobeItem(
            id: _item.id,
            profileId: _item.profileId,
            photoUrl: _item.photoUrl,
            originalPhotoUrl: _item.originalPhotoUrl,
            name: _item.name,
            bgRemovalStatus: _item.bgRemovalStatus,
            category: _item.category,
            color: _item.color,
            secondaryColors: _item.secondaryColors,
            pattern: _item.pattern,
            material: _item.material,
            style: _item.style,
            season: _item.season,
            occasion: _item.occasion,
            categorizationStatus: _item.categorizationStatus,
            brand: _item.brand,
            purchasePrice: _item.purchasePrice,
            purchaseDate: _item.purchaseDate,
            currency: _item.currency,
            isFavorite: previous,
            wearCount: _item.wearCount,
            lastWornDate: _item.lastWornDate,
            resaleStatus: _item.resaleStatus,
            createdAt: _item.createdAt,
            updatedAt: _item.updatedAt,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update favorite status"),
          ),
        );
      }
    }
  }

  Future<void> _editItem() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewItemScreen(
          item: _item,
          apiClient: widget.apiClient,
        ),
      ),
    );
    if (result == true && mounted) {
      _hasChanged = true;
      await _fetchItem();
    }
  }

  Future<void> _navigateToResaleListing() async {
    final resaleService = ResaleListingService(apiClient: widget.apiClient);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResaleListingScreen(
          item: _item,
          resaleListingService: resaleService,
        ),
      ),
    );
    // Refresh item to reflect any resaleStatus change
    if (mounted) {
      _hasChanged = true;
      await _fetchItem();
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Delete this item? This action cannot be undone."),
        actions: [
          Semantics(
            label: "Cancel delete",
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel"),
            ),
          ),
          Semantics(
            label: "Confirm delete",
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              child: const Text("Delete"),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.apiClient.deleteItem(_item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item deleted")),
          );
          Navigator.of(context).pop(true);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to delete item. Please try again."),
            ),
          );
        }
      }
    }
  }

  Future<void> _showMarkAsSoldSheet() async {
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Mark Item as Sold",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: "Sale price",
                child: TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Sale Price",
                    prefixText: _currencySymbol,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Price is required";
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) return "Must be a positive number";
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Semantics(
                  label: "Confirm sale",
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.of(ctx).pop(true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Confirm Sale"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final price = double.tryParse(priceController.text);
      if (price != null && price > 0) {
        try {
          await _resaleHistoryService.updateResaleStatus(
            _item.id,
            status: "sold",
            salePrice: price,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Item marked as sold!")),
            );
            _hasChanged = true;
            await _fetchItem();
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to update status.")),
            );
          }
        }
      }
    }
  }

  Future<void> _showDonateConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Donate Item"),
        content: const Text("Mark this item as donated? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          Semantics(
            label: "Confirm donate",
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
              ),
              child: const Text("Donate"),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _resaleHistoryService.updateResaleStatus(
          _item.id,
          status: "donated",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item marked as donated!")),
          );
          _hasChanged = true;
          await _fetchItem();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update status.")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          _item.name ?? "Item Detail",
          style: const TextStyle(color: Color(0xFF1F2937)),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: Semantics(
          label: "Back",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
        ),
        actions: [
          Semantics(
            label: _item.isFavorite ? "Remove from favorites" : "Add to favorites",
            child: IconButton(
              icon: Icon(
                _item.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _item.isFavorite
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF1F2937),
              ),
              onPressed: _toggleFavorite,
            ),
          ),
          Semantics(
            label: "More options",
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "edit") {
                  _editItem();
                } else if (value == "delete") {
                  _deleteItem();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: "edit",
                  child: Text("Edit"),
                ),
                const PopupMenuItem(
                  value: "delete",
                  child: Text("Delete"),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Failed to load item details.",
              style: TextStyle(color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: "Retry",
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                  _fetchItem();
                },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item photo
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: CachedNetworkImage(
                  imageUrl: _item.photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    height: 300,
                    color: const Color(0xFFE5E7EB),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 300,
                    color: const Color(0xFFE5E7EB),
                    child: const Center(
                      child: Icon(Icons.image, size: 64, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Neglect banner
          if (_item.isNeglected)
            Semantics(
              label: "This item is neglected",
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "This item has been neglected \u2014 consider wearing or decluttering it",
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard("Wears", "${_item.wearCount}"),
              _buildStatCard("CPW", _item.costPerWearDisplay),
              _buildStatCard("Last Worn", _item.lastWornDate ?? "Never"),
            ],
          ),
          const SizedBox(height: 16),

          // Details section
          const Text(
            "Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),

          _buildMetadataRow("Category", _item.category != null ? taxonomyDisplayLabel(_item.category!) : null),
          _buildMetadataRow("Color", _item.color != null ? taxonomyDisplayLabel(_item.color!) : null),
          _buildMetadataRow(
            "Secondary Colors",
            _item.secondaryColors != null && _item.secondaryColors!.isNotEmpty
                ? _item.secondaryColors!.map((c) => taxonomyDisplayLabel(c)).join(", ")
                : null,
          ),
          _buildMetadataRow("Pattern", _item.pattern != null ? taxonomyDisplayLabel(_item.pattern!) : null),
          _buildMetadataRow("Material", _item.material != null ? taxonomyDisplayLabel(_item.material!) : null),
          _buildMetadataRow("Style", _item.style != null ? taxonomyDisplayLabel(_item.style!) : null),
          _buildMetadataRow(
            "Season",
            _item.season != null && _item.season!.isNotEmpty
                ? _item.season!.map((s) => taxonomyDisplayLabel(s)).join(", ")
                : null,
          ),
          _buildMetadataRow(
            "Occasion",
            _item.occasion != null && _item.occasion!.isNotEmpty
                ? _item.occasion!.map((o) => taxonomyDisplayLabel(o)).join(", ")
                : null,
          ),
          _buildMetadataRow("Brand", _item.brand),
          _buildMetadataRow(
            "Purchase Price",
            _item.purchasePrice != null
                ? "${_currencySymbol}${_item.purchasePrice!.toStringAsFixed(2)}"
                : null,
          ),
          _buildMetadataRow("Purchase Date", _item.purchaseDate),
          _buildMetadataRow("Currency", _item.currency),
          _buildMetadataRow("Neglect Status", _item.isNeglected ? "Neglected" : "Active"),
          _buildMetadataRow("Added on", _formatDate(_item.createdAt)),
          _buildMetadataRow("Last Updated", _formatDate(_item.updatedAt)),
          const SizedBox(height: 16),

          // Sold badge
          if (_item.resaleStatus == "sold")
            Semantics(
              label: "Sold",
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "Sold",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            ),

          // Donated badge
          if (_item.resaleStatus == "donated")
            Semantics(
              label: "Donated",
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "Donated",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),
            ),

          // Generate Resale Listing button (hidden for sold/donated)
          if (_item.resaleStatus != "sold" && _item.resaleStatus != "donated")
            Semantics(
              label: _item.resaleStatus == "listed"
                  ? "Regenerate resale listing"
                  : "Generate resale listing",
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _navigateToResaleListing,
                  icon: const Icon(Icons.sell),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _item.resaleStatus == "listed"
                            ? "Regenerate Listing"
                            : "Generate Resale Listing",
                      ),
                      if (_item.resaleStatus == "listed")
                        const Text(
                          "(already listed)",
                          style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                        ),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Mark as Sold button (only for 'listed' items)
          if (_item.resaleStatus == "listed") ...[
            const SizedBox(height: 8),
            Semantics(
              label: "Mark as Sold",
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _showMarkAsSoldSheet,
                  icon: const Icon(Icons.attach_money),
                  label: const Text("Mark as Sold"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Mark as Donated button (for 'listed' or null resaleStatus)
          if (_item.resaleStatus == "listed" || _item.resaleStatus == null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: "Mark as Donated",
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _showDonateConfirmation,
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text("Mark as Donated"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String get _currencySymbol {
    switch (_item.currency) {
      case "EUR":
        return "\u20ac";
      case "USD":
        return "\$";
      default:
        return "\u00a3";
    }
  }

  String? _formatDate(String? isoDate) {
    if (isoDate == null) return null;
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? "Not set",
              style: TextStyle(
                fontSize: 14,
                color: value != null
                    ? const Color(0xFF1F2937)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
