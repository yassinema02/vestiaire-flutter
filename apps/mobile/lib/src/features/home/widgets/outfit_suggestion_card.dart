import "package:flutter/material.dart";

import "../../outfits/models/outfit_suggestion.dart";

/// Displays a single AI-generated outfit suggestion on the Home screen.
///
/// Shows the outfit name with an AI badge, a horizontal scrollable row of
/// item thumbnails, and a "Why this outfit?" explanation section.
/// Item thumbnails are NOT tappable in this story (Story 4.4 adds navigation).
class OutfitSuggestionCard extends StatelessWidget {
  const OutfitSuggestionCard({
    required this.suggestion,
    super.key,
  });

  final OutfitSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Outfit suggestion: ${suggestion.name}",
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: outfit name + AI badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      suggestion.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "AI",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Item thumbnails - horizontal scrollable row
              SizedBox(
                height: 88,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestion.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Semantics(
                          label:
                              "Outfit item: ${item.category ?? item.name ?? 'item'}",
                          child: Column(
                            children: [
                              // Thumbnail image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.photoUrl != null
                                    ? Image.network(
                                        item.photoUrl!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _placeholderBox(),
                                      )
                                    : _placeholderBox(),
                              ),
                              const SizedBox(height: 4),
                              // Category label
                              SizedBox(
                                width: 64,
                                child: Text(
                                  item.category ?? "",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Explanation section
              Semantics(
                label: "Outfit explanation: ${suggestion.explanation}",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Why this outfit?",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.explanation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
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

  Widget _placeholderBox() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.checkroom,
        color: Color(0xFF9CA3AF),
        size: 24,
      ),
    );
  }
}
