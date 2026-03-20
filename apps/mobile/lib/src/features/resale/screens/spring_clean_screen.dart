import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../services/donation_service.dart";
import "../services/resale_history_service.dart";
import "../../analytics/screens/analytics_dashboard_screen.dart";

/// Guided Spring Clean declutter flow.
///
/// Presents neglected items one at a time with Keep/Sell/Donate actions.
/// Story 13.3: Spring Clean Declutter Flow & Donations (FR-HLT-05)
class SpringCleanScreen extends StatefulWidget {
  const SpringCleanScreen({
    required this.apiClient,
    this.donationService,
    this.resaleHistoryService,
    super.key,
  });

  final ApiClient apiClient;
  final DonationService? donationService;
  final ResaleHistoryService? resaleHistoryService;

  @override
  State<SpringCleanScreen> createState() => SpringCleanScreenState();
}

class SpringCleanScreenState extends State<SpringCleanScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  int _currentIndex = 0;
  int _keptCount = 0;
  int _sellCount = 0;
  int _donatedCount = 0;
  final List<Map<String, dynamic>> _sellQueue = [];
  final List<Map<String, dynamic>> _donatedItems = [];
  double _totalDonationValue = 0;
  bool _sessionComplete = false;

  late DonationService _donationService;

  @override
  void initState() {
    super.initState();
    _donationService = widget.donationService ?? DonationService(apiClient: widget.apiClient);
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final result = await widget.apiClient.getSpringCleanItems();
      final rawItems = (result["items"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _items = rawItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load items.";
          _isLoading = false;
        });
      }
    }
  }

  void _onKeep() {
    setState(() {
      _keptCount++;
      _advanceToNext();
    });
  }

  void _onSell() {
    setState(() {
      _sellQueue.add(_items[_currentIndex]);
      _sellCount++;
      _advanceToNext();
    });
  }

  void _onDonate() {
    final item = _items[_currentIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DonateBottomSheet(
        itemName: item["name"] as String? ?? "Item",
        onConfirm: (charityName) async {
          Navigator.of(ctx).pop();
          await _confirmDonation(item, charityName);
        },
      ),
    );
  }

  Future<void> _confirmDonation(Map<String, dynamic> item, String? charityName) async {
    final itemId = item["id"] as String;
    final estimatedValue = (item["estimatedValue"] as num?)?.toDouble() ?? 0;

    try {
      await _donationService.createDonation(
        itemId: itemId,
        charityName: charityName,
        estimatedValue: estimatedValue,
      );
    } catch (_) {
      // Best-effort; continue flow even if donation API fails
    }

    if (mounted) {
      setState(() {
        _donatedItems.add(item);
        _donatedCount++;
        _totalDonationValue += estimatedValue;
        _advanceToNext();
      });
    }
  }

  void _advanceToNext() {
    if (_currentIndex + 1 >= _items.length) {
      _sessionComplete = true;
    } else {
      _currentIndex++;
    }
  }

  void _finishEarly() {
    setState(() {
      _sessionComplete = true;
    });
  }

  int get _totalReviewed => _keptCount + _sellCount + _donatedCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cleaning_services, size: 20),
            SizedBox(width: 8),
            Text("Spring Clean"),
          ],
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        actions: [
          if (!_sessionComplete && !_isLoading && _items.isNotEmpty)
            TextButton(
              onPressed: _finishEarly,
              child: const Text(
                "Finish",
                style: TextStyle(color: Color(0xFF4F46E5)),
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

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
      );
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    if (_sessionComplete) {
      return _buildSummary();
    }

    return _buildReviewCard();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Color(0xFF22C55E),
            ),
            const SizedBox(height: 16),
            const Text(
              "Your wardrobe is in great shape!\nNo neglected items to review.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Back to Wardrobe"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard() {
    final item = _items[_currentIndex];
    final name = item["name"] as String? ?? "Unnamed Item";
    final category = item["category"] as String? ?? "";
    final brand = item["brand"] as String? ?? "";
    final photoUrl = item["photoUrl"] as String? ?? "";
    final daysUnworn = (item["daysUnworn"] as num?)?.toInt() ?? 0;
    final estimatedValue = (item["estimatedValue"] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Semantics(
            label: "Spring Clean review, item ${_currentIndex + 1} of ${_items.length}",
            child: Column(
              children: [
                Text(
                  "Reviewing ${_currentIndex + 1} of ${_items.length} items",
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _items.length,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ],
            ),
          ),
        ),

        // Item card
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SingleChildScrollView(
              key: ValueKey(_currentIndex),
              padding: const EdgeInsets.all(16),
              child: Semantics(
                label: "Item $name, not worn in $daysUnworn days, estimated value $estimatedValue",
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 300,
                                color: const Color(0xFFE5E7EB),
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 300,
                                color: const Color(0xFFE5E7EB),
                                child: const Icon(Icons.image_not_supported, size: 48),
                              ),
                            )
                          : Container(
                              height: 300,
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.image_not_supported, size: 48),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (category.isNotEmpty || brand.isNotEmpty)
                      Text(
                        [category, brand].where((s) => s.isNotEmpty).join(" \u2022 "),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          "Not worn in $daysUnworn days",
                          style: const TextStyle(fontSize: 14, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Est. value: ~$estimatedValue GBP",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: "Keep this item",
                  child: OutlinedButton.icon(
                    onPressed: _onKeep,
                    icon: const Icon(Icons.favorite_border),
                    label: const Text("Keep"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFF6B7280)),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: "Sell this item",
                  child: FilledButton.icon(
                    onPressed: _onSell,
                    icon: const Icon(Icons.sell),
                    label: const Text("Sell"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: "Donate this item",
                  child: FilledButton.icon(
                    onPressed: _onDonate,
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text("Donate"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Semantics(
      label: "Spring Clean complete, $_keptCount kept, $_sellCount to sell, $_donatedCount donated",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.celebration, size: 48, color: Color(0xFF22C55E)),
            const SizedBox(height: 16),
            const Text(
              "Spring Clean Complete!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard("Reviewed", "$_totalReviewed", const Color(0xFF4F46E5)),
                _buildStatCard("Kept", "$_keptCount", const Color(0xFF6B7280)),
                _buildStatCard("To Sell", "$_sellCount", const Color(0xFF4F46E5)),
                _buildStatCard("Donated", "$_donatedCount", const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 24),

            // Sell queue CTA
            if (_sellCount > 0) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // Navigate to generate resale listings
                    Navigator.of(context).pop(_sellQueue);
                  },
                  icon: const Icon(Icons.sell),
                  label: const Text("Generate Resale Listings"),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Donation summary
            if (_donatedCount > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "Total Donation Value: ~${_totalDonationValue.toStringAsFixed(0)} GBP",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // User can navigate to donation history
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "View Donation History",
                        style: TextStyle(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // View Updated Health Score
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AnalyticsDashboardScreen(
                        apiClient: widget.apiClient,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.health_and_safety),
                label: const Text("View Updated Health Score"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

/// Bottom sheet for donating with optional charity name.
class _DonateBottomSheet extends StatefulWidget {
  const _DonateBottomSheet({
    required this.itemName,
    required this.onConfirm,
  });

  final String itemName;
  final Future<void> Function(String? charityName) onConfirm;

  @override
  State<_DonateBottomSheet> createState() => _DonateBottomSheetState();
}

class _DonateBottomSheetState extends State<_DonateBottomSheet> {
  final _charityController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _charityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Donate ${widget.itemName}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _charityController,
            decoration: const InputDecoration(
              hintText: "Charity or organization (optional)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      final charity = _charityController.text.trim().isNotEmpty
                          ? _charityController.text.trim()
                          : null;
                      await widget.onConfirm(charity);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                minimumSize: const Size(0, 48),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Confirm Donation"),
            ),
          ),
        ],
      ),
    );
  }
}
