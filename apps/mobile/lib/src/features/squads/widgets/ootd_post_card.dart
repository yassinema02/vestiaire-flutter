import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/utils/time_utils.dart";
import "../models/ootd_post.dart";

/// A reusable card widget for displaying an OOTD post in a feed.
///
/// Story 9.3: Social Feed & Filtering (AC: 1, 6)
/// Story 9.4: Reactions & Comments (AC: 1) -- interactive reaction toggle
///
/// Displays author info, post photo, optional caption, tagged items,
/// and engagement counts (reactions + comments) with optimistic UI for reactions.
class OotdPostCard extends StatefulWidget {
  const OotdPostCard({
    required this.post,
    this.onTap,
    this.onReactionTap,
    this.onCommentTap,
    this.onStealLookTap,
    super.key,
  });

  final OotdPost post;
  final VoidCallback? onTap;

  /// Reaction toggle callback. Returns a Future that resolves to
  /// `{ "reacted": bool, "reactionCount": int }` on success,
  /// or throws on failure (triggering revert).
  final Future<Map<String, dynamic>> Function()? onReactionTap;
  final VoidCallback? onCommentTap;

  /// Callback for "Steal This Look" quick action (Story 9.5).
  final VoidCallback? onStealLookTap;

  @override
  State<OotdPostCard> createState() => _OotdPostCardState();
}

class _OotdPostCardState extends State<OotdPostCard> {
  bool _captionExpanded = false;
  late bool _hasReacted;
  late int _reactionCount;

  @override
  void initState() {
    super.initState();
    _hasReacted = widget.post.hasReacted;
    _reactionCount = widget.post.reactionCount;
  }

  @override
  void didUpdateWidget(OotdPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.hasReacted != widget.post.hasReacted ||
        oldWidget.post.reactionCount != widget.post.reactionCount) {
      _hasReacted = widget.post.hasReacted;
      _reactionCount = widget.post.reactionCount;
    }
  }

  String _getAuthorInitials() {
    final name = widget.post.authorDisplayName ?? "?";
    return name
        .split(" ")
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : "")
        .take(2)
        .join();
  }

  Future<void> _onReactionTap() async {
    if (widget.onReactionTap == null) return;

    // Optimistic update
    final previousReacted = _hasReacted;
    final previousCount = _reactionCount;
    setState(() {
      _hasReacted = !_hasReacted;
      _reactionCount += _hasReacted ? 1 : -1;
    });

    try {
      await widget.onReactionTap!();
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _hasReacted = previousReacted;
          _reactionCount = previousCount;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Post by ${widget.post.authorDisplayName ?? 'Unknown'}",
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuthorRow(),
                const SizedBox(height: 8),
                _buildPhoto(),
                if (widget.post.caption != null &&
                    widget.post.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCaption(),
                ],
                if (widget.post.taggedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildTaggedItems(),
                ],
                const SizedBox(height: 8),
                _buildEngagementRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorRow() {
    final post = widget.post;
    return Semantics(
      label:
          "Author: ${post.authorDisplayName ?? 'Unknown'}, ${formatRelativeTime(post.createdAt)}",
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: post.authorPhotoUrl != null
                ? NetworkImage(post.authorPhotoUrl!)
                : null,
            backgroundColor: const Color(0xFF4F46E5),
            child: post.authorPhotoUrl == null
                ? Text(
                    _getAuthorInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              post.authorDisplayName ?? "Unknown",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          Text(
            formatRelativeTime(post.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return Semantics(
      label: "OOTD photo by ${widget.post.authorDisplayName ?? 'Unknown'}",
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: CachedNetworkImage(
            imageUrl: widget.post.photoUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: const Color(0xFFE5E7EB),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: const Color(0xFFE5E7EB),
              child: const Center(
                child: Icon(Icons.broken_image, size: 48, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaption() {
    return GestureDetector(
      onTap: () {
        setState(() => _captionExpanded = !_captionExpanded);
      },
      child: Text(
        widget.post.caption!,
        maxLines: _captionExpanded ? null : 3,
        overflow: _captionExpanded ? null : TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget _buildTaggedItems() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.post.taggedItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = widget.post.taggedItems[index];
          return Semantics(
            label: "Tagged item: ${item.itemName ?? 'Unknown'}",
            child: Chip(
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: item.itemPhotoUrl != null
                  ? CircleAvatar(
                      radius: 10,
                      backgroundImage: NetworkImage(item.itemPhotoUrl!),
                    )
                  : const CircleAvatar(
                      radius: 10,
                      child: Icon(Icons.checkroom, size: 10),
                    ),
              label: Text(
                item.itemName ?? "Item",
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEngagementRow() {
    return Row(
      children: [
        Semantics(
          label: _hasReacted
              ? "Reacted: $_reactionCount"
              : "Not reacted: $_reactionCount",
          child: InkWell(
            onTap: _onReactionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 20,
                    color: _hasReacted
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$_reactionCount",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          label: "Comments: ${widget.post.commentCount}",
          child: InkWell(
            onTap: widget.onCommentTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${widget.post.commentCount}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.post.taggedItems.isNotEmpty && widget.onStealLookTap != null) ...[
          const SizedBox(width: 16),
          Semantics(
            label: "Steal this look",
            child: InkWell(
              onTap: widget.onStealLookTap,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.style,
                  size: 20,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
