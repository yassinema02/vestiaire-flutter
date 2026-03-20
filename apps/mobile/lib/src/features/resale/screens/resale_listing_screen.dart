/// Screen for displaying an AI-generated resale listing.
///
/// Shows the item image, editable title/description, condition estimate,
/// hashtags, and copy/share actions.
///
/// Story 7.3: AI Resale Listing Generation (FR-RSL-02, FR-RSL-03)
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";
import "../../wardrobe/models/wardrobe_item.dart";
import "../models/resale_listing.dart";
import "../services/resale_listing_service.dart";

/// Screen that generates and displays a resale listing for a wardrobe item.
class ResaleListingScreen extends StatefulWidget {
  const ResaleListingScreen({
    required this.item,
    this.resaleListingService,
    this.subscriptionService,
    super.key,
  });

  final WardrobeItem item;
  final ResaleListingService? resaleListingService;
  final SubscriptionService? subscriptionService;

  @override
  State<ResaleListingScreen> createState() => _ResaleListingScreenState();
}

enum _ScreenState { loading, success, error, usageLimitExceeded }

class _ResaleListingScreenState extends State<ResaleListingScreen> {
  _ScreenState _state = _ScreenState.loading;
  ResaleListingResult? _result;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _generateListing();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _generateListing() async {
    if (!mounted) return;
    setState(() {
      _state = _ScreenState.loading;
    });

    final service = widget.resaleListingService;
    if (service == null) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
        });
      }
      return;
    }

    try {
      final result = await service.generateListing(widget.item.id);
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _result = result;
          _titleController.text = result.listing.title;
          _descriptionController.text = result.listing.description;
          _state = _ScreenState.success;
        });
      } else {
        setState(() {
          _state = _ScreenState.error;
        });
      }
    } on UsageLimitException {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.usageLimitExceeded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.error;
      });
    }
  }

  String _formatListingText() {
    final title = _titleController.text;
    final description = _descriptionController.text;
    final condition = _result?.listing.conditionEstimate ?? "";
    final hashtags = _result?.listing.hashtags ?? [];
    final hashtagString = hashtags.map((h) => "#$h").join(" ");

    return "$title\n\n$description\n\nCondition: $condition\n\n$hashtagString";
  }

  void _copyToClipboard() {
    final formatted = _formatListingText();
    Clipboard.setData(ClipboardData(text: formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard!")),
    );
  }

  void _shareListing() {
    final formatted = _formatListingText();
    Share.share(formatted);
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case "New":
        return const Color(0xFF10B981);
      case "Like New":
        return const Color(0xFF3B82F6);
      case "Good":
        return const Color(0xFFF59E0B);
      case "Fair":
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Resale Listing",
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
        label: "Resale listing for ${widget.item.name ?? 'item'}",
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.loading:
        return _buildLoadingState();
      case _ScreenState.success:
        return _buildSuccessState();
      case _ScreenState.error:
        return _buildErrorState();
      case _ScreenState.usageLimitExceeded:
        return _buildUsageLimitState();
    }
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Shimmer-like placeholders
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 24,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 32,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Generating your listing...",
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    final listing = _result!.listing;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: widget.item.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFFE5E7EB),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Center(
                    child: Icon(Icons.image, size: 48, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Editable title
          Semantics(
            label: "Listing title",
            child: TextFormField(
              controller: _titleController,
              maxLength: 80,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Editable description
          Semantics(
            label: "Listing description",
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Condition estimate chip
          Row(
            children: [
              const Text(
                "Condition: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              Chip(
                label: Text(
                  listing.conditionEstimate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                backgroundColor: _conditionColor(listing.conditionEstimate),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hashtags
          if (listing.hashtags.isNotEmpty) ...[
            const Text(
              "Hashtags",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: listing.hashtags
                  .map((tag) => Chip(
                        label: Text(
                          "#$tag",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: "Copy listing to clipboard",
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.content_copy),
                    label: const Text("Copy to Clipboard"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: "Share listing",
                  child: ElevatedButton.icon(
                    onPressed: _shareListing,
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          const Text(
            "Unable to generate listing. Please try again.",
            style: TextStyle(color: Color(0xFF1F2937), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: "Try again",
            child: ElevatedButton(
              onPressed: _generateListing,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Try Again"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageLimitState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumGateCard(
          title: "Resale Listing Limit Reached",
          subtitle:
              "Free users get 2 AI listings per month. Go Premium for unlimited.",
          icon: Icons.sell,
          subscriptionService: widget.subscriptionService,
        ),
      ),
    );
  }
}
