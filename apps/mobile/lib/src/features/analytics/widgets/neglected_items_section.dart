import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

/// A section displaying items that have not been worn in 60+ days.
///
/// Shows items sorted by staleness with days-since-worn indicators
/// and CPW values where available.
class NeglectedItemsSection extends StatelessWidget {
  const NeglectedItemsSection({
    required this.items,
    required this.onItemTap,
    super.key,
  });

  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Neglected items, ${items.length} items",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Header with count badge
            Row(
              children: [
                const Text(
                  "Neglected Items",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "(${items.length})",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Items list or positive state
            if (items.isEmpty) _buildPositiveState() else _buildItemsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPositiveState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.celebration,
              size: 32,
              color: Color(0xFF22C55E),
            ),
            SizedBox(height: 8),
            Text(
              "No neglected items -- great job wearing your wardrobe!",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      children: items.map((item) {
        final name = (item["name"] as String?) ??
            (item["category"] as String?) ??
            "Item";
        final photoUrl = item["photoUrl"] as String?;
        final daysSinceWorn = (item["daysSinceWorn"] as num?)?.toInt();
        final lastWornDate = item["lastWornDate"];
        final purchasePrice = (item["purchasePrice"] as num?)?.toDouble();
        final wearCount = (item["wearCount"] as num?)?.toInt() ?? 0;
        final cpw = (item["cpw"] as num?)?.toDouble();

        final daysText = lastWornDate == null ? "Never worn" : "$daysSinceWorn days";

        return Semantics(
          label: "$name, not worn for ${lastWornDate == null ? 'never' : '$daysSinceWorn'} days",
          child: InkWell(
            onTap: () => onItemTap(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Thumbnail
                  ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Icon(
                                Icons.checkroom,
                                color: Color(0xFF9CA3AF),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.checkroom,
                                color: Color(0xFF9CA3AF),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(
                                Icons.checkroom,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name/category
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Days since worn and CPW
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        daysText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      if (purchasePrice != null && cpw != null)
                        Text(
                          "\u00a3${cpw.toStringAsFixed(2)}/wear",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        )
                      else if (purchasePrice != null && wearCount == 0)
                        Text(
                          "\u00a3${purchasePrice.toStringAsFixed(0)} unworn",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
