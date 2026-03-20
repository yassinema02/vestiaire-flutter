import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/utils/time_utils.dart";
import "../models/ootd_comment.dart";
import "../models/ootd_post.dart";
import "../services/ootd_service.dart";
import "steal_this_look_screen.dart";

/// Detail screen for a single OOTD post.
///
/// Story 9.3: Social Feed & Filtering (AC: 5)
/// Story 9.4: Reactions & Comments (AC: 1, 2, 4, 5) -- interactive reactions + comments
///
/// Shows full post details including larger photo, author info, caption,
/// tagged items, engagement counts, interactive reaction toggle,
/// comments list, and comment input.
class OotdPostDetailScreen extends StatefulWidget {
  const OotdPostDetailScreen({
    required this.postId,
    required this.ootdService,
    this.currentUserId,
    super.key,
  });

  final String postId;
  final OotdService ootdService;

  /// Current user's profile ID for ownership checks (delete button visibility).
  final String? currentUserId;

  @override
  State<OotdPostDetailScreen> createState() => _OotdPostDetailScreenState();
}

class _OotdPostDetailScreenState extends State<OotdPostDetailScreen> {
  OotdPost? _post;
  bool _isLoading = true;
  String? _error;

  // Reaction state
  late bool _hasReacted;
  late int _reactionCount;

  // Comments state
  List<OotdComment> _comments = [];
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _hasReacted = false;
    _reactionCount = 0;
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final post = await widget.ootdService.getPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _hasReacted = post.hasReacted;
        _reactionCount = post.reactionCount;
        _isLoading = false;
      });
      _loadComments();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final result =
          await widget.ootdService.listComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = result["comments"] as List<OotdComment>;
        _isLoadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingComments = false);
    }
  }

  bool get _isAuthor {
    if (_post == null || widget.currentUserId == null) return false;
    return _post!.authorId == widget.currentUserId;
  }

  Future<void> _toggleReaction() async {
    // Optimistic update
    final previousReacted = _hasReacted;
    final previousCount = _reactionCount;
    setState(() {
      _hasReacted = !_hasReacted;
      _reactionCount += _hasReacted ? 1 : -1;
    });

    try {
      await widget.ootdService.toggleReaction(widget.postId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasReacted = previousReacted;
          _reactionCount = previousCount;
        });
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);
    try {
      final comment = await widget.ootdService.createComment(
        widget.postId,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        _comments.add(comment);
        _commentController.clear();
        _isSendingComment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add comment: $e")),
      );
    }
  }

  Future<void> _deleteComment(OotdComment comment) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Delete Comment",
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text("Cancel"),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.ootdService.deleteComment(widget.postId, comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete comment: $e")),
      );
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text(
          "Are you sure you want to delete this post? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.ootdService.deletePost(widget.postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted")),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete post: $e")),
      );
    }
  }

  String _getAuthorInitials() {
    final name = _post?.authorDisplayName ?? "?";
    return name
        .split(" ")
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : "")
        .take(2)
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Post"),
        actions: [
          if (_isAuthor)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "delete") _deletePost();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: "delete",
                  child: Semantics(
                    label: "Delete Post",
                    child: const Text(
                      "Delete Post",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFF6B7280)),
              const SizedBox(height: 16),
              const Text(
                "Post not found",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    return _buildPostDetail();
  }

  Widget _buildPostDetail() {
    final post = _post!;
    return Semantics(
      label: "Post detail view",
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthorHeader(post),
                  const SizedBox(height: 12),
                  _buildPhoto(post),
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.caption!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                  if (post.taggedItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTaggedItemsSection(post),
                    const SizedBox(height: 12),
                    _buildStealThisLookButton(post),
                  ],
                  const SizedBox(height: 16),
                  _buildEngagementSection(),
                  const SizedBox(height: 16),
                  _buildCommentsSection(),
                  if (_isAuthor) ...[
                    const SizedBox(height: 24),
                    _buildDeleteButton(),
                  ],
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader(OotdPost post) {
    return Semantics(
      label:
          "Author: ${post.authorDisplayName ?? 'Unknown'}, ${formatRelativeTime(post.createdAt)}",
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: post.authorPhotoUrl != null
                ? NetworkImage(post.authorPhotoUrl!)
                : null,
            backgroundColor: const Color(0xFF4F46E5),
            child: post.authorPhotoUrl == null
                ? Text(
                    _getAuthorInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorDisplayName ?? "Unknown",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  formatRelativeTime(post.createdAt),
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
    );
  }

  Widget _buildPhoto(OotdPost post) {
    return Semantics(
      label: "OOTD photo",
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: post.photoUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 300,
              color: const Color(0xFFE5E7EB),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 300,
              color: const Color(0xFFE5E7EB),
              child: const Center(
                child:
                    Icon(Icons.broken_image, size: 48, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaggedItemsSection(OotdPost post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tagged Items",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        ...post.taggedItems.map((item) => Semantics(
              label: "Tagged item: ${item.itemName ?? 'Unknown'}",
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: item.itemPhotoUrl != null
                      ? NetworkImage(item.itemPhotoUrl!)
                      : null,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: item.itemPhotoUrl == null
                      ? const Icon(Icons.checkroom,
                          size: 20, color: Color(0xFF6B7280))
                      : null,
                ),
                title: Text(
                  item.itemName ?? "Unknown Item",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
                subtitle: item.itemCategory != null
                    ? Text(
                        item.itemCategory!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      )
                    : null,
              ),
            )),
      ],
    );
  }

  Widget _buildEngagementSection() {
    return Row(
      children: [
        Semantics(
          label: _hasReacted
              ? "Reacted: $_reactionCount"
              : "Not reacted: $_reactionCount",
          child: InkWell(
            onTap: _toggleReaction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 24,
                    color: _hasReacted
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$_reactionCount",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Semantics(
          label: "Comments: ${_comments.length}",
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 24, color: Color(0xFF4F46E5)),
              const SizedBox(width: 4),
              Text(
                "${_comments.length}",
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Comments",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingComments)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                "No comments yet -- be the first!",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          )
        else
          ..._comments.map(_buildCommentRow),
      ],
    );
  }

  Widget _buildCommentRow(OotdComment comment) {
    final canDelete = widget.currentUserId != null &&
        (comment.authorId == widget.currentUserId || _isAuthor);

    final initials = (comment.authorDisplayName ?? "?")
        .split(" ")
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : "")
        .take(2)
        .join();

    return Semantics(
      label:
          "Comment by ${comment.authorDisplayName ?? 'Unknown'}: ${comment.text}",
      child: GestureDetector(
        onLongPress: canDelete ? () => _deleteComment(comment) : null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: comment.authorPhotoUrl != null
                    ? NetworkImage(comment.authorPhotoUrl!)
                    : null,
                backgroundColor: const Color(0xFF4F46E5),
                child: comment.authorPhotoUrl == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorDisplayName ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      formatRelativeTime(comment.createdAt),
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
      ),
    );
  }

  Widget _buildCommentInput() {
    return Semantics(
      label: "Comment input",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: "Add a comment",
                  child: TextField(
                    controller: _commentController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText: "Add a comment...",
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      counterText: "",
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: "Send comment",
                child: IconButton(
                  icon: _isSendingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Color(0xFF4F46E5)),
                  onPressed: _isSendingComment ? null : _addComment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStealThisLookButton(OotdPost post) {
    return Semantics(
      label: "Steal this look - find similar items in your wardrobe",
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            side: const BorderSide(color: Color(0xFF4F46E5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.style),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StealThisLookScreen(
                  postId: widget.postId,
                  post: post,
                  ootdService: widget.ootdService,
                ),
              ),
            );
          },
          label: const Text("Steal This Look"),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Semantics(
      label: "Delete Post",
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.delete_outline),
          onPressed: _deletePost,
          label: const Text("Delete Post"),
        ),
      ),
    );
  }
}
