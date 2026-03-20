import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../models/saved_outfit.dart";
import "../services/calendar_outfit_service.dart";
import "../services/outfit_generation_service.dart";
import "../services/outfit_persistence_service.dart";
import "create_outfit_screen.dart";
import "outfit_detail_screen.dart";
import "plan_week_screen.dart";

/// Screen displaying the user's saved outfit history.
///
/// Shows a list of outfits with swipe-to-delete, favorite toggle,
/// and navigation to outfit detail.
class OutfitHistoryScreen extends StatefulWidget {
  const OutfitHistoryScreen({
    required this.outfitPersistenceService,
    this.apiClient,
    super.key,
  });

  final OutfitPersistenceService outfitPersistenceService;
  final ApiClient? apiClient;

  @override
  State<OutfitHistoryScreen> createState() => _OutfitHistoryScreenState();
}

class _OutfitHistoryScreenState extends State<OutfitHistoryScreen> {
  List<SavedOutfit>? _outfits;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final outfits = await widget.outfitPersistenceService.listOutfits();
      if (mounted) {
        setState(() {
          _outfits = outfits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load outfits";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleFavoriteToggle(SavedOutfit outfit) async {
    final index = _outfits?.indexOf(outfit) ?? -1;
    if (index == -1) return;

    // Optimistic update
    setState(() {
      _outfits![index] = outfit.copyWith(isFavorite: !outfit.isFavorite);
    });

    final result = await widget.outfitPersistenceService.toggleFavorite(
      outfit.id,
      !outfit.isFavorite,
    );

    if (result == null && mounted) {
      // Revert on failure
      setState(() {
        _outfits![index] = outfit;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update favorite. Please try again."),
        ),
      );
    }
  }

  void _handleDelete(SavedOutfit outfit) {
    // Remove from list immediately (required by Dismissible)
    setState(() {
      _outfits?.removeWhere((o) => o.id == outfit.id);
    });
  }

  void _navigateToPlanWeek() {
    if (widget.apiClient == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanWeekScreen(
          calendarOutfitService:
              CalendarOutfitService(apiClient: widget.apiClient!),
          outfitPersistenceService: widget.outfitPersistenceService,
          outfitGenerationService:
              OutfitGenerationService(apiClient: widget.apiClient!),
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  Future<void> _onCardTap(SavedOutfit outfit) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OutfitDetailScreen(
          outfit: outfit,
          outfitPersistenceService: widget.outfitPersistenceService,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadOutfits();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Outfits"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Plan Week",
            onPressed: _navigateToPlanWeek,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_outfits != null && _outfits!.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOutfits,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _outfits?.length ?? 0,
        itemBuilder: (context, index) {
          final outfit = _outfits![index];
          return _buildOutfitCard(outfit);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadOutfits,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Semantics(
      label: "No outfits saved. Create outfits from the Home screen.",
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dry_cleaning,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 16),
              const Text(
                "No outfits saved yet",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Create outfits from the Home screen or build your own",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.apiClient != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateOutfitScreen(
                          apiClient: widget.apiClient!,
                          outfitPersistenceService:
                              widget.outfitPersistenceService,
                        ),
                      ),
                    );
                  },
                  child: const Text("Create Outfit"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitCard(SavedOutfit outfit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label:
            "Outfit: ${outfit.name ?? 'Untitled'}, ${outfit.source}, created ${outfit.relativeDate}",
        child: Dismissible(
          key: ValueKey(outfit.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Semantics(
              label: "Delete outfit: ${outfit.name ?? 'Untitled'}",
              child: const Icon(Icons.delete, color: Colors.white),
            ),
          ),
          confirmDismiss: (direction) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Delete this outfit?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text("Delete"),
                  ),
                ],
              ),
            );
            if (confirmed != true) return false;

            final success = await widget.outfitPersistenceService
                .deleteOutfit(outfit.id);
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Failed to delete outfit. Please try again."),
                ),
              );
              return false;
            }
            return true;
          },
          onDismissed: (_) => _handleDelete(outfit),
          child: GestureDetector(
            onTap: () => _onCardTap(outfit),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + favorite
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          outfit.name ?? "Untitled Outfit",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Semantics(
                        label: outfit.isFavorite
                            ? "Remove ${outfit.name ?? 'outfit'} from favorites"
                            : "Mark ${outfit.name ?? 'outfit'} as favorite",
                        child: IconButton(
                          icon: Icon(
                            outfit.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: outfit.isFavorite
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF9CA3AF),
                          ),
                          onPressed: () => _handleFavoriteToggle(outfit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Item thumbnails
                  SizedBox(
                    height: 48,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: outfit.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              label: item.category ?? item.name ?? "Item",
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.photoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: item.photoUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 48,
                                          height: 48,
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          color: const Color(0xFFE5E7EB),
                                          child: const Icon(
                                            Icons.image,
                                            size: 20,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: const Color(0xFFE5E7EB),
                                        child: const Icon(
                                          Icons.image,
                                          size: 20,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Source chip, occasion, date
                  Row(
                    children: [
                      _buildSourceChip(outfit.source),
                      if (outfit.occasion != null) ...[
                        const SizedBox(width: 8),
                        _buildOccasionChip(outfit.occasion!),
                      ],
                      const Spacer(),
                      Text(
                        outfit.relativeDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceChip(String source) {
    final isAi = source == "ai";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAi ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAi ? "AI" : "Manual",
        style: TextStyle(
          fontSize: 10,
          color: isAi ? const Color(0xFF4F46E5) : const Color(0xFF059669),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOccasionChip(String occasion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        occasion,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
