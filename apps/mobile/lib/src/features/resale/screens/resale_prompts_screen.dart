/// Screen displaying monthly resale suggestions for neglected wardrobe items.
///
/// Shows a health score summary card, list of resale candidate item cards
/// with accept/dismiss actions, and an empty state when no suggestions exist.
///
/// Story 13.2: Monthly Resale Prompts (FR-RSL-05, FR-RSL-06)
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../../wardrobe/models/wardrobe_item.dart";
import "../models/resale_prompt.dart";
import "../services/resale_prompt_service.dart";
import "../services/resale_listing_service.dart";
import "resale_listing_screen.dart";

/// Screen that displays resale suggestions for neglected items.
class ResalePromptsScreen extends StatefulWidget {
  const ResalePromptsScreen({
    required this.apiClient,
    this.resalePromptService,
    this.resaleListingService,
    super.key,
  });

  final ApiClient apiClient;
  final ResalePromptService? resalePromptService;
  final ResaleListingService? resaleListingService;

  @override
  State<ResalePromptsScreen> createState() => ResalePromptsScreenState();
}

/// Visible for testing.
class ResalePromptsScreenState extends State<ResalePromptsScreen> {
  late ResalePromptService _resalePromptService;
  List<ResalePrompt> _prompts = [];
  bool _isLoading = true;
  int? _healthScore;
  String? _healthRecommendation;

  @override
  void initState() {
    super.initState();
    _resalePromptService =
        widget.resalePromptService ?? ResalePromptService(apiClient: widget.apiClient);
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    try {
      final results = await Future.wait([
        _resalePromptService.fetchPendingPrompts(),
        _fetchHealthScore(),
      ]);

      if (!mounted) return;
      setState(() {
        _prompts = results[0] as List<ResalePrompt>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHealthScore() async {
    try {
      final response =
          await widget.apiClient.authenticatedGet("/v1/analytics/wardrobe-health");
      if (!mounted) return;
      final score = response["score"];
      final recommendation = response["recommendation"] as String?;
      setState(() {
        _healthScore = score is int ? score : (score as num?)?.toInt();
        _healthRecommendation = recommendation;
      });
    } catch (_) {
      // Health score is optional -- graceful degradation.
    }
  }

  Future<void> _acceptPrompt(ResalePrompt prompt) async {
    try {
      await _resalePromptService.acceptPrompt(prompt.id);
    } catch (_) {
      // Best effort
    }

    // Navigate to ResaleListingScreen
    if (!mounted) return;
    final item = WardrobeItem(
      id: prompt.itemId,
      profileId: "",
      photoUrl: prompt.itemPhotoUrl ?? "",
      name: prompt.itemName,
      category: prompt.itemCategory,
      brand: prompt.itemBrand,
      wearCount: prompt.itemWearCount,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResaleListingScreen(item: item),
      ),
    );

    if (!mounted) return;
    setState(() {
      _prompts.removeWhere((p) => p.id == prompt.id);
    });
  }

  Future<void> _dismissPrompt(ResalePrompt prompt) async {
    try {
      await _resalePromptService.dismissPrompt(prompt.id);
    } catch (_) {
      // Best effort
    }

    if (!mounted) return;
    setState(() {
      _prompts.removeWhere((p) => p.id == prompt.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Resale Suggestions"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Semantics(
        label: "Resale suggestions",
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _prompts.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 32, color: Color(0xFF22C55E)),
          SizedBox(height: 16),
          Text(
            "No items to declutter right now.\nKeep wearing your wardrobe!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHealthScoreCard(),
        const SizedBox(height: 16),
        ..._prompts.map((prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPromptCard(prompt),
            )),
      ],
    );
  }

  Widget _buildHealthScoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        children: [
          if (_healthScore != null) ...[
            Text(
              "${_healthScore}",
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Wardrobe Health Score",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
          if (_healthRecommendation != null) ...[
            const SizedBox(height: 8),
            Text(
              _healthRecommendation!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            "Improve your score by decluttering!",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard(ResalePrompt prompt) {
    return Semantics(
      label:
          "Item ${prompt.itemName ?? 'Unknown'}, estimated sale price ${prompt.estimatedPrice.toStringAsFixed(0)} ${prompt.estimatedCurrency}, not worn in ${prompt.daysSinceLastWorn} days",
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: prompt.itemPhotoUrl != null && prompt.itemPhotoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: prompt.itemPhotoUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFE5E7EB),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.image_not_supported),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
            const SizedBox(width: 12),
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt.itemName ?? "Unknown Item",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [prompt.itemCategory, prompt.itemBrand]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(" \u2022 "),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        "Not worn in ${prompt.daysSinceLastWorn} days",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "~${prompt.estimatedPrice.toStringAsFixed(0)} ${prompt.estimatedCurrency}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: "List item for sale",
                          child: ElevatedButton.icon(
                            onPressed: () => _acceptPrompt(prompt),
                            icon: const Icon(Icons.sell, size: 16),
                            label: const Text("List for Sale"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          label: "Keep this item",
                          child: OutlinedButton.icon(
                            onPressed: () => _dismissPrompt(prompt),
                            icon: const Icon(Icons.favorite_border, size: 16),
                            label: const Text("I'll Keep It"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(color: Color(0xFF6B7280)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
