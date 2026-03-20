/// Screen displaying resale history with earnings summary and chart.
///
/// Story 7.4: Resale Status & History Tracking (FR-RSL-07, FR-RSL-08)
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/networking/api_client.dart";
import "../models/resale_history.dart";
import "../services/resale_history_service.dart";
import "../widgets/earnings_chart.dart";

/// Screen showing resale history, earnings summary, and monthly chart.
class ResaleHistoryScreen extends StatefulWidget {
  const ResaleHistoryScreen({
    required this.apiClient,
    this.resaleHistoryService,
    super.key,
  });

  final ApiClient apiClient;
  final ResaleHistoryService? resaleHistoryService;

  @override
  State<ResaleHistoryScreen> createState() => _ResaleHistoryScreenState();
}

class _ResaleHistoryScreenState extends State<ResaleHistoryScreen> {
  late final ResaleHistoryService _service;
  bool _isLoading = true;
  bool _hasError = false;

  List<ResaleHistoryEntry> _history = [];
  ResaleEarningsSummary? _summary;
  List<MonthlyEarnings> _monthlyEarnings = [];

  @override
  void initState() {
    super.initState();
    _service =
        widget.resaleHistoryService ?? ResaleHistoryService(apiClient: widget.apiClient);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final result = await _service.fetchHistory();
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    final historyRaw = result["history"] as List<dynamic>? ?? [];
    final summaryRaw = result["summary"] as Map<String, dynamic>?;
    final monthlyRaw = result["monthlyEarnings"] as List<dynamic>? ?? [];

    setState(() {
      _history = historyRaw
          .map((e) => ResaleHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      _summary = summaryRaw != null
          ? ResaleEarningsSummary.fromJson(summaryRaw)
          : const ResaleEarningsSummary(
              itemsSold: 0, itemsDonated: 0, totalEarnings: 0);
      _monthlyEarnings = monthlyRaw
          .map((e) => MonthlyEarnings.fromJson(e as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Resale History",
          style: TextStyle(color: Color(0xFF1F2937)),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: Semantics(
          label: "Back",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Semantics(
        label: "Resale history",
        child: _buildBody(),
      ),
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
              "Failed to load resale history.",
              style: TextStyle(color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _loadHistory();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 16),
              const Text(
                "No resale history yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "List items for sale from their detail screen.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: "\u00A3");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          _buildSummaryCard(currencyFormat),
          const SizedBox(height: 16),

          // Earnings chart
          if (_summary != null && _summary!.itemsSold > 0) ...[
            EarningsChart(data: _monthlyEarnings),
            const SizedBox(height: 16),
          ],

          // History list
          const Text(
            "History",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          ..._history.map((entry) => _buildHistoryEntry(entry, currencyFormat)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat currencyFormat) {
    final summary = _summary ??
        const ResaleEarningsSummary(
            itemsSold: 0, itemsDonated: 0, totalEarnings: 0);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Semantics(
                label: "Items sold: ${summary.itemsSold}",
                child: Column(
                  children: [
                    Text(
                      "${summary.itemsSold}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Items Sold",
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label: "Items donated: ${summary.itemsDonated}",
                child: Column(
                  children: [
                    Text(
                      "${summary.itemsDonated}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Items Donated",
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label:
                    "Total earnings: ${currencyFormat.format(summary.totalEarnings)}",
                child: Column(
                  children: [
                    Text(
                      currencyFormat.format(summary.totalEarnings),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Total Earnings",
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(
      ResaleHistoryEntry entry, NumberFormat currencyFormat) {
    final dateStr =
        "${entry.saleDate.year}-${entry.saleDate.month.toString().padLeft(2, '0')}-${entry.saleDate.day.toString().padLeft(2, '0')}";

    return Semantics(
      label: "${entry.itemName ?? 'Item'} ${entry.type}",
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: entry.itemPhotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: entry.itemPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: const Color(0xFFE5E7EB),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Icon(Icons.image,
                                size: 20, color: Color(0xFF9CA3AF)),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.image,
                              size: 20, color: Color(0xFF9CA3AF)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Item name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.itemName ?? "Item",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: entry.isSold
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.isSold ? "Sold" : "Donated",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: entry.isSold
                        ? const Color(0xFF10B981)
                        : const Color(0xFF8B5CF6),
                  ),
                ),
              ),
              // Price (for sold items)
              if (entry.isSold) ...[
                const SizedBox(width: 8),
                Text(
                  currencyFormat.format(entry.salePrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
