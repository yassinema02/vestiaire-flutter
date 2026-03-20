import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../models/saved_outfit.dart";
import "../services/outfit_persistence_service.dart";

/// Screen displaying the details of a saved outfit.
///
/// Shows outfit name, explanation, items list, and allows
/// favorite toggle and deletion.
class OutfitDetailScreen extends StatefulWidget {
  const OutfitDetailScreen({
    required this.outfit,
    required this.outfitPersistenceService,
    super.key,
  });

  final SavedOutfit outfit;
  final OutfitPersistenceService outfitPersistenceService;

  @override
  State<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends State<OutfitDetailScreen> {
  late SavedOutfit _outfit;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _outfit = widget.outfit;
  }

  Future<void> _handleFavoriteToggle() async {
    final previous = _outfit;
    setState(() {
      _outfit = _outfit.copyWith(isFavorite: !_outfit.isFavorite);
    });

    final result = await widget.outfitPersistenceService.toggleFavorite(
      _outfit.id,
      _outfit.isFavorite,
    );

    if (result == null && mounted) {
      setState(() {
        _outfit = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update favorite. Please try again."),
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
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

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final success =
        await widget.outfitPersistenceService.deleteOutfit(_outfit.id);

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete outfit. Please try again."),
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
        title: const Text("Outfit Details"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        actions: [
          Semantics(
            label: _outfit.isFavorite
                ? "Remove ${_outfit.name ?? 'outfit'} from favorites"
                : "Mark ${_outfit.name ?? 'outfit'} as favorite",
            child: IconButton(
              icon: Icon(
                _outfit.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _outfit.isFavorite
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF9CA3AF),
              ),
              onPressed: _handleFavoriteToggle,
            ),
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outfit name
                  Semantics(
                    label: "Outfit name: ${_outfit.name ?? 'Untitled'}",
                    child: Text(
                      _outfit.name ?? "Untitled Outfit",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Source + occasion chips
                  Row(
                    children: [
                      _buildSourceChip(_outfit.source),
                      if (_outfit.occasion != null) ...[
                        const SizedBox(width: 8),
                        _buildOccasionChip(_outfit.occasion!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Date
                  Text(
                    "Created ${_outfit.relativeDate}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Explanation
                  if (_outfit.explanation != null &&
                      _outfit.explanation!.isNotEmpty) ...[
                    const Text(
                      "Why this outfit?",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      label: "Outfit explanation: ${_outfit.explanation}",
                      child: Text(
                        _outfit.explanation!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Items section
                  const Text(
                    "Items",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Item cards
                  ...List.generate(_outfit.items.length, (index) {
                    final item = _outfit.items[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < _outfit.items.length - 1 ? 8 : 0,
                      ),
                      child: Semantics(
                        label:
                            "Item: ${item.category ?? item.name ?? 'Unknown'}",
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.photoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: item.photoUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 80,
                                          height: 80,
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 80,
                                          height: 80,
                                          color: const Color(0xFFE5E7EB),
                                          child: const Icon(
                                            Icons.image,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        color: const Color(0xFFE5E7EB),
                                        child: const Icon(
                                          Icons.image,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name ?? "Unnamed Item",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    if (item.category != null)
                                      Text(
                                        item.category!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    if (item.color != null)
                                      Text(
                                        item.color!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
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
                  }),
                  const SizedBox(height: 24),
                  // Delete button
                  Center(
                    child: Semantics(
                      label: "Delete this outfit",
                      child: TextButton(
                        onPressed: _handleDelete,
                        child: const Text(
                          "Delete Outfit",
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
