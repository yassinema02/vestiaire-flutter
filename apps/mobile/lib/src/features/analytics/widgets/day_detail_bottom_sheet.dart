import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/networking/api_client.dart";
import "../models/wear_log.dart";

/// A bottom sheet showing wear log details for a specific day.
///
/// Displays each log entry with timestamp, outfit label (if applicable),
/// and item IDs. Item thumbnails are loaded on-demand via [apiClient].
class DayDetailBottomSheet extends StatefulWidget {
  const DayDetailBottomSheet({
    required this.date,
    required this.wearLogs,
    this.apiClient,
    super.key,
  });

  /// ISO date string (YYYY-MM-DD).
  final String date;
  final List<WearLog> wearLogs;
  final ApiClient? apiClient;

  @override
  State<DayDetailBottomSheet> createState() => _DayDetailBottomSheetState();
}

class _DayDetailBottomSheetState extends State<DayDetailBottomSheet> {
  Map<String, Map<String, dynamic>> _itemDetails = {};
  // ignore: unused_field
  bool _loadingItems = false;

  @override
  void initState() {
    super.initState();
    _loadItemDetails();
  }

  Future<void> _loadItemDetails() async {
    if (widget.apiClient == null) return;

    // Collect all unique item IDs
    final itemIds = <String>{};
    for (final log in widget.wearLogs) {
      itemIds.addAll(log.itemIds);
    }
    if (itemIds.isEmpty) return;

    setState(() => _loadingItems = true);

    try {
      final response = await widget.apiClient!.listItems();
      final items = (response["items"] as List<dynamic>?) ?? [];
      final details = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final id = map["id"] as String? ?? "";
        if (itemIds.contains(id)) {
          details[id] = map;
        }
      }
      if (!mounted) return;
      setState(() {
        _itemDetails = details;
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  String _formatDate() {
    try {
      final parsed = DateTime.parse(widget.date);
      return DateFormat("EEEE, MMMM d, yyyy").format(parsed);
    } catch (_) {
      return widget.date;
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return "";
    try {
      final parsed = DateTime.parse(createdAt);
      return DateFormat("h:mm a").format(parsed);
    } catch (_) {
      return "";
    }
  }

  int get _totalItemCount {
    int count = 0;
    for (final log in widget.wearLogs) {
      count += log.itemIds.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Outfit details for ${_formatDate()}",
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Text(
                _formatDate(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                label: "Logged $_totalItemCount items",
                child: Text(
                  "$_totalItemCount items logged",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Log entries
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.wearLogs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = widget.wearLogs[index];
                    return _buildLogEntry(log);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogEntry(WearLog log) {
    final time = _formatTime(log.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (time.isNotEmpty)
              Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            if (log.outfitId != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Logged outfit",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: log.itemIds.map((itemId) {
            final details = _itemDetails[itemId];
            final name = details?["name"] as String? ??
                details?["category"] as String? ??
                itemId;
            final photoUrl = details?["photo_url"] as String? ??
                details?["photoUrl"] as String?;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoUrl != null)
                  ClipOval(
                    child: Image.network(
                      photoUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
                    ),
                  )
                else
                  _buildPlaceholderAvatar(),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E7EB),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.checkroom, size: 16, color: Color(0xFF9CA3AF)),
    );
  }
}
