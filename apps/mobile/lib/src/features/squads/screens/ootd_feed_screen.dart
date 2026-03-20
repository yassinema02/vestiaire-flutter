import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../models/ootd_post.dart";
import "../models/squad.dart";
import "../services/ootd_service.dart";
import "../services/squad_service.dart";
import "../widgets/ootd_post_card.dart";
import "ootd_create_screen.dart";
import "ootd_post_detail_screen.dart";
import "steal_this_look_screen.dart";

/// Full-screen OOTD feed with pagination and squad filtering.
///
/// Story 9.3: Social Feed & Filtering (AC: 1, 2, 3, 4)
///
/// Shows a chronological (newest-first) feed of OOTD posts from all
/// the user's joined squads, with filter chips for individual squads
/// and cursor-based infinite scroll pagination.
class OotdFeedScreen extends StatefulWidget {
  const OotdFeedScreen({
    required this.ootdService,
    required this.squadService,
    this.apiClient,
    this.initialSquadFilter,
    this.embedded = false,
    super.key,
  });

  final OotdService ootdService;
  final SquadService squadService;
  final ApiClient? apiClient;
  final String? initialSquadFilter;

  /// When true, omits the Scaffold/AppBar so the widget can be embedded
  /// inside a parent screen (e.g., as a tab in SquadListScreen).
  final bool embedded;

  @override
  State<OotdFeedScreen> createState() => OotdFeedScreenState();
}

class OotdFeedScreenState extends State<OotdFeedScreen> {
  List<OotdPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _cursor;
  String? _selectedSquadId;
  List<Squad> _squads = [];
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedSquadId = widget.initialSquadFilter;
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadSquads(),
      _loadPosts(refresh: true),
    ]);
  }

  Future<void> _loadSquads() async {
    try {
      final squads = await widget.squadService.listMySquads();
      if (!mounted) return;
      setState(() => _squads = squads);
    } catch (_) {
      // Squads filter is non-critical, continue without it
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _cursor = null;
        _posts = [];
        _isLoading = true;
        _hasMore = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final Map<String, dynamic> result;
      if (_selectedSquadId != null) {
        result = await widget.ootdService.listSquadPosts(
          _selectedSquadId!,
          limit: 20,
          cursor: _cursor,
        );
      } else {
        result = await widget.ootdService.listFeedPosts(
          limit: 20,
          cursor: _cursor,
        );
      }

      if (!mounted) return;

      final newPosts = result["posts"] as List<OotdPost>;
      final nextCursor = result["nextCursor"] as String?;

      setState(() {
        if (refresh) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        _cursor = nextCursor;
        _hasMore = nextCursor != null;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = e.toString();
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadPosts();
      }
    }
  }

  void _onSquadFilterChanged(String? squadId) {
    setState(() => _selectedSquadId = squadId);
    _loadPosts(refresh: true);
  }

  Future<Map<String, dynamic>> _handleReactionTap(OotdPost post) async {
    final result = await widget.ootdService.toggleReaction(post.id);
    // Update the post in the local list with new reaction state
    if (mounted) {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        final reacted = result["reacted"] as bool? ?? false;
        final reactionCount = result["reactionCount"] as int? ?? 0;
        setState(() {
          _posts[index] = OotdPost(
            id: post.id,
            authorId: post.authorId,
            photoUrl: post.photoUrl,
            caption: post.caption,
            createdAt: post.createdAt,
            authorDisplayName: post.authorDisplayName,
            authorPhotoUrl: post.authorPhotoUrl,
            taggedItems: post.taggedItems,
            squadIds: post.squadIds,
            reactionCount: reactionCount,
            commentCount: post.commentCount,
            hasReacted: reacted,
          );
        });
      }
    }
    return result;
  }

  void _navigateToPostDetail(OotdPost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OotdPostDetailScreen(
          postId: post.id,
          ootdService: widget.ootdService,
        ),
      ),
    );
  }

  void _navigateToCreateOotd() {
    if (widget.apiClient == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OotdCreateScreen(
          ootdService: widget.ootdService,
          squadService: widget.squadService,
          apiClient: widget.apiClient!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildFilterChips(),
        Expanded(child: _buildBody()),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Feed"),
        actions: [
          if (widget.apiClient != null)
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              onPressed: _navigateToCreateOotd,
              tooltip: "Post OOTD",
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildFilterChips() {
    if (_squads.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: "Squad filter",
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: "Filter: All Squads",
                child: ChoiceChip(
                  label: const Text("All Squads"),
                  selected: _selectedSquadId == null,
                  selectedColor: const Color(0xFF4F46E5),
                  labelStyle: TextStyle(
                    color:
                        _selectedSquadId == null ? Colors.white : const Color(0xFF1F2937),
                  ),
                  onSelected: (_) => _onSquadFilterChanged(null),
                ),
              ),
            ),
            ..._squads.map((squad) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    label: "Filter: ${squad.name}",
                    child: ChoiceChip(
                      label: Text(squad.name),
                      selected: _selectedSquadId == squad.id,
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(
                        color: _selectedSquadId == squad.id
                            ? Colors.white
                            : const Color(0xFF1F2937),
                      ),
                      onSelected: (_) => _onSquadFilterChanged(squad.id),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _posts.isEmpty) {
      return _buildErrorState();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return _buildFeed();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text(
              "Failed to load feed",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
              onPressed: () => _loadPosts(refresh: true),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: "No posts icon",
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 64,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "No posts yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Be the first to share your OOTD!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            if (widget.apiClient != null)
              Semantics(
                label: "Post OOTD",
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  onPressed: _navigateToCreateOotd,
                  child: const Text("Post OOTD"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return Semantics(
      label: "OOTD Feed",
      child: RefreshIndicator(
        onRefresh: () => _loadPosts(refresh: true),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _posts.length + 1,
          itemBuilder: (context, index) {
            if (index < _posts.length) {
              final post = _posts[index];
              return OotdPostCard(
                post: post,
                onTap: () => _navigateToPostDetail(post),
                onReactionTap: () => _handleReactionTap(post),
                onCommentTap: () => _navigateToPostDetail(post),
                onStealLookTap: post.taggedItems.isNotEmpty
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StealThisLookScreen(
                              postId: post.id,
                              post: post,
                              ootdService: widget.ootdService,
                            ),
                          ),
                        );
                      }
                    : null,
              );
            }

            // Last item: loading indicator or end-of-feed
            if (_hasMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "You're all caught up!",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
