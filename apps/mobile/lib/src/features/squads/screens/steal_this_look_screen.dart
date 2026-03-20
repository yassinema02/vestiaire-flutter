import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../models/ootd_post.dart";
import "../models/steal_look_result.dart";
import "../services/ootd_service.dart";

/// Screen showing "Steal This Look" AI match results.
///
/// Story 9.5: "Steal This Look" Matcher (FR-SOC-12, FR-SOC-13)
///
/// Displays the friend's tagged items alongside the user's best matching
/// wardrobe items, color-coded by match quality tier.
class StealThisLookScreen extends StatefulWidget {
  const StealThisLookScreen({
    required this.postId,
    required this.post,
    required this.ootdService,
    super.key,
  });

  final String postId;
  final OotdPost post;
  final OotdService ootdService;

  @override
  State<StealThisLookScreen> createState() => _StealThisLookScreenState();
}

class _StealThisLookScreenState extends State<StealThisLookScreen> {
  StealLookResult? _result;
  bool _isLoading = true;
  String? _errorCode;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorCode = null;
      _errorMessage = null;
    });

    try {
      final result = await widget.ootdService.stealThisLook(widget.postId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Extract error code from ApiException
      String? code;
      String? message;
      if (e is ApiException) {
        code = e.code;
        message = e.message;
      } else {
        message = e.toString();
      }
      setState(() {
        _isLoading = false;
        _errorCode = code;
        _errorMessage = message;
      });
    }
  }

  bool get _hasAnyMatch {
    if (_result == null) return false;
    return _result!.sourceMatches.any((sm) => sm.matches.isNotEmpty);
  }

  Future<void> _saveAsOutfit() async {
    if (_result == null || !_hasAnyMatch) return;

    setState(() => _isSaving = true);

    try {
      // Collect the best match for each source item that has matches
      final itemIds = <String>[];
      for (final sm in _result!.sourceMatches) {
        if (sm.matches.isNotEmpty) {
          itemIds.add(sm.matches.first.itemId);
        }
      }

      if (itemIds.isEmpty) return;

      final authorName = widget.post.authorDisplayName ?? "a friend";
      await widget.ootdService.saveStealLookOutfit(
        itemIds: itemIds,
        name: "Inspired by $authorName's look",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Outfit saved!")),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save outfit: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Steal This Look"),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorCode == "WARDROBE_EMPTY") {
      return _buildEmptyWardrobeState();
    }

    if (_errorCode != null || _errorMessage != null) {
      return _buildErrorState();
    }

    return _buildResultState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.post.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.post.photoUrl,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    width: 120,
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Icons.broken_image,
                        color: Color(0xFF6B7280)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              "Finding matches in your wardrobe...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWardrobeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checkroom, size: 64, color: Color(0xFF6B7280)),
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
              "Add items to your wardrobe first to find matches.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: "Go to Wardrobe",
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () {
                  // Pop back and navigate to wardrobe tab
                  Navigator.of(context).pop();
                },
                child: const Text("Go to Wardrobe"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text(
              "Unable to find matches",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "Something went wrong. Please try again.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: "Retry",
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(0, 44),
                ),
                onPressed: _loadMatches,
                child: const Text("Retry"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultState() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _result!.sourceMatches.length,
            itemBuilder: (context, index) {
              return _buildSourceMatchCard(_result!.sourceMatches[index]);
            },
          ),
        ),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildSourceMatchCard(StealLookSourceMatch sourceMatch) {
    return Semantics(
      label: "Source item: ${sourceMatch.sourceItem.name ?? 'Unknown'}",
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source item header
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: sourceMatch.sourceItem.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: sourceMatch.sourceItem.photoUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: const Color(0xFFE5E7EB),
                                child: const Icon(Icons.checkroom,
                                    size: 20, color: Color(0xFF6B7280)),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.checkroom,
                                  size: 20, color: Color(0xFF6B7280)),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sourceMatch.sourceItem.name ?? "Unknown Item",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (sourceMatch.sourceItem.category != null)
                            Text(
                              sourceMatch.sourceItem.category!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Matches
              if (sourceMatch.matches.isEmpty)
                _buildNoMatchPlaceholder()
              else
                ...sourceMatch.matches
                    .map((match) => _buildMatchRow(match)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.search_off, size: 24, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "No match found",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          Chip(
            label: const Text(
              "Shop for similar",
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            backgroundColor: const Color(0xFFF3F4F6),
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRow(StealLookMatch match) {
    return Semantics(
      label: "Match: ${match.name ?? 'Unknown'}, ${match.matchScore}% match",
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: match.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: match.photoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.checkroom,
                            size: 24, color: Color(0xFF6B7280)),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.checkroom,
                          size: 24, color: Color(0xFF6B7280)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.name ?? "Unknown Item",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  if (match.category != null)
                    Text(
                      match.category!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  if (match.matchReason != null)
                    Text(
                      match.matchReason!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: "${match.matchScore}% ${match.tier.label}",
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: match.tier.color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  "${match.matchScore}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Semantics(
      label: "Save as Outfit",
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: const Color(0xFFD1D5DB),
              ),
              onPressed: _hasAnyMatch && !_isSaving ? _saveAsOutfit : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save as Outfit"),
            ),
          ),
        ),
      ),
    );
  }
}
