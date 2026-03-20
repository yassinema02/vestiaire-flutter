import "package:flutter/material.dart";

/// Card shown when the user has fewer than 3 categorized items in their
/// wardrobe. Prompts the user to add more items before AI outfit suggestions
/// can be generated.
class OutfitMinimumItemsCard extends StatelessWidget {
  const OutfitMinimumItemsCard({
    required this.onAddItems,
    super.key,
  });

  final VoidCallback onAddItems;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Add more items to receive outfit suggestions",
      child: Container(
        padding: const EdgeInsets.all(20),
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
          children: [
            const Icon(
              Icons.checkroom,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            const Text(
              "Build your wardrobe",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add at least 3 items to get AI outfit suggestions",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onAddItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Add Items",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
