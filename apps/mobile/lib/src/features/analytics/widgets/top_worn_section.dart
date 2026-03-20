import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

/// A section displaying the top 10 most worn items as a ranked leaderboard.
///
/// Supports three time period filters: "30 Days", "90 Days", and "All Time".
class TopWornSection extends StatefulWidget {
  const TopWornSection({
    required this.items,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onItemTap,
    super.key,
  });

  final List<Map<String, dynamic>> items;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<Map<String, dynamic>> onItemTap;

  @override
  State<TopWornSection> createState() => _TopWornSectionState();
}

class _TopWornSectionState extends State<TopWornSection> {
  static const _periods = [
    {"label": "30 Days", "value": "30"},
    {"label": "90 Days", "value": "90"},
    {"label": "All Time", "value": "all"},
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Top worn items, ${_periodLabel(widget.selectedPeriod)} filter",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Header row with title and filter chips
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Top 10 Most Worn",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                ..._periods.map((p) {
                  final isSelected = widget.selectedPeriod == p["value"];
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text(
                        p["label"]!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : const Color(0xFF6B7280),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: const Color(0xFFF3F4F6),
                      onSelected: (_) => widget.onPeriodChanged(p["value"]!),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // Items list or empty state
            if (widget.items.isEmpty) _buildEmptyState() else _buildItemsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 8),
            Text(
              "Start logging outfits to see your most worn items!",
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
      children: List.generate(widget.items.length, (index) {
        final item = widget.items[index];
        final rank = index + 1;
        final name = (item["name"] as String?) ??
            (item["category"] as String?) ??
            "Item";
        final wearCount = widget.selectedPeriod == "all"
            ? (item["wearCount"] as num?)?.toInt() ?? 0
            : (item["periodWearCount"] as num?)?.toInt() ??
                (item["wearCount"] as num?)?.toInt() ??
                0;
        final lastWornDate = item["lastWornDate"] as String?;
        final photoUrl = item["photoUrl"] as String?;

        return Semantics(
          label: "Rank $rank, $name, $wearCount wears",
          child: InkWell(
            onTap: () => widget.onItemTap(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4F46E5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$rank",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
                  // Name and last worn
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lastWornDate != null)
                          Text(
                            _formatRelativeDate(lastWornDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Wear count
                  Text(
                    "$wearCount wears",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  String _periodLabel(String period) {
    switch (period) {
      case "30":
        return "30 Days";
      case "90":
        return "90 Days";
      default:
        return "All Time";
    }
  }

  String _formatRelativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return "Today";
      if (diff == 1) return "Yesterday";
      if (diff < 7) return "$diff days ago";
      if (diff < 14) return "1 week ago";
      if (diff < 30) return "${diff ~/ 7} weeks ago";
      if (diff < 60) return "1 month ago";
      // Format as month day
      const months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
      ];
      return "${months[date.month - 1]} ${date.day}";
    } catch (_) {
      return dateStr;
    }
  }
}
