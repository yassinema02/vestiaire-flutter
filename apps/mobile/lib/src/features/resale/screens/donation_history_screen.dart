import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/networking/api_client.dart";
import "../models/donation_log.dart";
import "../services/donation_service.dart";

/// Screen displaying the user's donation history.
///
/// Story 13.3: Spring Clean Declutter Flow & Donations (FR-DON-03)
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({
    required this.apiClient,
    this.donationService,
    super.key,
  });

  final ApiClient apiClient;
  final DonationService? donationService;

  @override
  State<DonationHistoryScreen> createState() => DonationHistoryScreenState();
}

class DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<DonationLogEntry> _donations = [];
  DonationSummary? _summary;
  bool _isLoading = true;
  String? _error;

  late DonationService _donationService;

  @override
  void initState() {
    super.initState();
    _donationService = widget.donationService ?? DonationService(apiClient: widget.apiClient);
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    try {
      final result = await _donationService.fetchDonations();
      if (!mounted) return;
      if (result != null) {
        final donationsRaw = (result["donations"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        final summaryRaw = result["summary"] as Map<String, dynamic>?;
        setState(() {
          _donations = donationsRaw.map((json) => DonationLogEntry.fromJson(json)).toList();
          _summary = summaryRaw != null ? DonationSummary.fromJson(summaryRaw) : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load donations.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load donations.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Donation History"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Semantics(
        label: "Donation history",
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
      );
    }

    if (_donations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        if (_summary != null) _buildSummaryCard(),
        const SizedBox(height: 16),
        // Donation list
        ..._donations.map(_buildDonationRow),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.volunteer_activism, size: 32, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              "No donations yet.\nUse Spring Clean to declutter your wardrobe!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _summary!;
    final currencyFormat = NumberFormat.currency(symbol: "\u00A3");

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Semantics(
              label: "Total items donated: ${summary.totalDonated}",
              child: Column(
                children: [
                  Text(
                    "${summary.totalDonated}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const Text(
                    "Items Donated",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Semantics(
              label: "Total donation value: ${currencyFormat.format(summary.totalValue)}",
              child: Column(
                children: [
                  Text(
                    currencyFormat.format(summary.totalValue),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const Text(
                    "Total Value",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationRow(DonationLogEntry entry) {
    final dateFormat = DateFormat.yMMMd();
    final dateStr = dateFormat.format(entry.donationDate);
    final currencyFormat = NumberFormat.currency(symbol: "\u00A3");

    return Semantics(
      label: "${entry.itemName ?? "Item"}, donated${entry.charityName != null ? " to ${entry.charityName}" : ""}",
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: entry.itemPhotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: entry.itemPhotoUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.image, size: 20),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.image, size: 20),
                      ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.itemName ?? "Unnamed Item",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (entry.charityName != null)
                      Text(
                        entry.charityName!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              // Value and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(entry.estimatedValue),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Donated",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
