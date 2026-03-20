import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../models/match_insight_result.dart";
import "../models/shopping_scan.dart";
import "../services/shopping_scan_service.dart";

/// Screen displaying wardrobe matches and AI-generated insights for a shopping scan.
///
/// Shows grouped match cards, 3 insight cards, and a wishlist toggle button.
/// Handles loading, error, empty wardrobe, and not scored states.
///
/// Story 8.5: Shopping Match & Insight Display (FR-SHP-08, FR-SHP-09, FR-SHP-10)
class MatchInsightScreen extends StatefulWidget {
  const MatchInsightScreen({
    required this.scanId,
    required this.scan,
    required this.shoppingScanService,
    super.key,
  });

  final String scanId;
  final ShoppingScan scan;
  final ShoppingScanService shoppingScanService;

  @override
  State<MatchInsightScreen> createState() => _MatchInsightScreenState();
}

class _MatchInsightScreenState extends State<MatchInsightScreen> {
  List<WardrobeMatch>? _matches;
  List<ShoppingInsight>? _insights;
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorCode;
  bool _isWishlisted = false;
  bool _isTogglingWishlist = false;

  @override
  void initState() {
    super.initState();
    _isWishlisted = widget.scan.wishlisted;
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    // Check for cached insights first
    if (widget.scan.insights != null) {
      final cached = widget.scan.insights!;
      final matchesList = cached["matches"] as List<dynamic>? ?? [];
      final insightsList = cached["insights"] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _matches = matchesList
              .map((m) =>
                  WardrobeMatch.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList();
          _insights = insightsList
              .map((i) =>
                  ShoppingInsight.fromJson(Map<String, dynamic>.from(i as Map)))
              .toList();
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorCode = null;
    });

    try {
      final result =
          await widget.shoppingScanService.generateInsights(widget.scanId);
      if (!mounted) return;
      setState(() {
        _matches = result.matches;
        _insights = result.insights;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == "NOT_SCORED") {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Score the product first")),
        );
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
        _errorCode = e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred.";
      });
    }
  }

  Future<void> _toggleWishlist() async {
    if (_isTogglingWishlist) return;

    setState(() {
      _isTogglingWishlist = true;
    });

    try {
      await widget.shoppingScanService.updateScan(
        widget.scanId,
        {"wishlisted": !_isWishlisted},
      );
      if (!mounted) return;
      setState(() {
        _isWishlisted = !_isWishlisted;
        _isTogglingWishlist = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTogglingWishlist = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Matches & Insights"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorCode == "WARDROBE_EMPTY") {
      return _buildEmptyWardrobeState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_matches != null && _insights != null) {
      return _buildInsightDisplay();
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.scan.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.scan.imageUrl!,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    width: 80,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 32, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              widget.scan.displayName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Finding matches & generating insights...",
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

  Widget _buildEmptyWardrobeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.checkroom,
                  size: 64,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Your wardrobe is empty",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Add items to your wardrobe first to see matches and insights.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: "Go to Wardrobe button",
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text("Go to Wardrobe"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't generate insights",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? "An unexpected error occurred.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: "Retry button",
                  child: ElevatedButton(
                    onPressed: _loadInsights,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text("Retry"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightDisplay() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (a) Product Header
          _buildProductHeader(),
          const SizedBox(height: 24),

          // (b) Top Matches
          _buildMatchesSection(),
          const SizedBox(height: 24),

          // (c) AI Insights
          _buildInsightsSection(),
          const SizedBox(height: 24),

          // (d) Wishlist Button
          _buildWishlistButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    final scan = widget.scan;
    return Semantics(
      label:
          "Product: ${scan.displayName}, score: ${scan.compatibilityScore ?? 'N/A'}",
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (scan.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  scan.imageUrl!,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    width: 80,
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.broken_image,
                        size: 24, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            if (scan.hasImage) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (scan.brand != null)
                    Text(
                      scan.brand!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
            if (scan.compatibilityScore != null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _tierColor(scan.compatibilityScore!),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${scan.compatibilityScore}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _tierColor(int score) {
    if (score >= 90) return const Color(0xFF22C55E);
    if (score >= 75) return const Color(0xFF3B82F6);
    if (score >= 60) return const Color(0xFFF59E0B);
    if (score >= 40) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  Widget _buildMatchesSection() {
    final matches = _matches!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Top Wardrobe Matches (${matches.length})",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              "No close matches found in your wardrobe.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          )
        else
          ..._buildGroupedMatches(matches),
      ],
    );
  }

  List<Widget> _buildGroupedMatches(List<WardrobeMatch> matches) {
    // Group by category
    final Map<String, List<WardrobeMatch>> grouped = {};
    for (final match in matches) {
      final category = match.category ?? "Other";
      grouped.putIfAbsent(category, () => []).add(match);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            entry.key[0].toUpperCase() + entry.key.substring(1),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
      widgets.add(
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entry.value.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final match = entry.value[index];
              return _buildMatchCard(match);
            },
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildMatchCard(WardrobeMatch match) {
    return Semantics(
      label:
          "Match: ${match.itemName ?? 'Item'}, ${match.matchReasons.isNotEmpty ? match.matchReasons.first : 'compatible'}",
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: match.itemImageUrl != null
                  ? Image.network(
                      match.itemImageUrl!,
                      height: 48,
                      width: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _matchPlaceholder(),
                    )
                  : _matchPlaceholder(),
            ),
            const SizedBox(height: 4),
            Text(
              match.itemName ?? "Item",
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1F2937),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (match.matchReasons.isNotEmpty)
              Text(
                match.matchReasons.first,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _matchPlaceholder() {
    return Container(
      height: 48,
      width: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.checkroom, size: 24, color: Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI Insights",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        ..._insights!.map(_buildInsightCard),
      ],
    );
  }

  Widget _buildInsightCard(ShoppingInsight insight) {
    Color iconColor;
    switch (insight.type) {
      case "style_feedback":
        iconColor = const Color(0xFF4F46E5); // indigo
        break;
      case "gap_assessment":
        iconColor = const Color(0xFF0D9488); // teal
        break;
      case "value_proposition":
        iconColor = const Color(0xFF16A34A); // green
        break;
      default:
        iconColor = const Color(0xFF4F46E5);
    }

    return Semantics(
      label: "Insight: ${insight.title}",
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              insight.icon,
              color: iconColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.body,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistButton() {
    return Semantics(
      label: _isWishlisted
          ? "Saved to Wishlist button"
          : "Save to Wishlist button",
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: _isWishlisted
            ? ElevatedButton.icon(
                onPressed: _isTogglingWishlist ? null : _toggleWishlist,
                icon: const Icon(Icons.bookmark),
                label: const Text("Saved to Wishlist"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: _isTogglingWishlist ? null : _toggleWishlist,
                icon: const Icon(Icons.bookmark_border),
                label: const Text("Save to Wishlist"),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  foregroundColor: const Color(0xFF4F46E5),
                ),
              ),
      ),
    );
  }
}
