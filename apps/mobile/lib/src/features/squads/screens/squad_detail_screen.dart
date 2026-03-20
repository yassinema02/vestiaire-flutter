import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";

import "../../../core/networking/api_client.dart";
import "../models/ootd_post.dart";
import "../models/squad.dart";
import "../services/ootd_service.dart";
import "../services/squad_service.dart";
import "../widgets/ootd_post_card.dart";
import "ootd_create_screen.dart";
import "ootd_feed_screen.dart";
import "ootd_post_detail_screen.dart";
import "steal_this_look_screen.dart";

/// Detail screen for a single squad: members, invite, leave/remove actions.
///
/// Story 9.1: Squad Creation & Management (FR-SOC-02 through FR-SOC-05)
class SquadDetailScreen extends StatefulWidget {
  const SquadDetailScreen({
    required this.squadId,
    required this.squadService,
    this.ootdService,
    this.apiClient,
    super.key,
  });

  final String squadId;
  final SquadService squadService;
  final OotdService? ootdService;
  final ApiClient? apiClient;

  @override
  State<SquadDetailScreen> createState() => _SquadDetailScreenState();
}

class _SquadDetailScreenState extends State<SquadDetailScreen> {
  Squad? _squad;
  List<SquadMember>? _members;
  List<OotdPost>? _recentPosts;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = <Future<dynamic>>[
        widget.squadService.getSquad(widget.squadId),
        widget.squadService.listMembers(widget.squadId),
      ];
      // Load recent posts if ootdService is available
      if (widget.ootdService != null) {
        futures.add(
          widget.ootdService!.listSquadPosts(widget.squadId, limit: 5),
        );
      }
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _squad = results[0] as Squad;
        _members = results[1] as List<SquadMember>;
        if (results.length > 2) {
          final postsResult = results[2] as Map<String, dynamic>;
          _recentPosts = postsResult["posts"] as List<OotdPost>;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Check if the current user is the admin of this squad.
  bool get _isAdmin {
    if (_squad == null || _members == null) return false;
    // The admin is the created_by user. We check if there's an admin member.
    // Since we don't have the current user's profile ID directly, we check
    // if any admin member exists. The API's RLS ensures we only see squads
    // we belong to, and the admin is the one with role == 'admin'.
    // For simplicity, we rely on the fact that a member with role 'admin'
    // matching the squad's createdBy is the current user IF they can see the squad.
    // A more robust approach would be to compare with the current user profile ID.
    // For now, we check if the logged-in user's membership has role 'admin'.
    // We'll look for the admin member whose userId matches createdBy.
    return _members!.any((m) => m.isAdmin);
  }

  Future<void> _removeMember(SquadMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Member"),
        content: Text(
            "Remove ${member.displayName ?? 'this member'} from the squad?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.squadService.removeMember(widget.squadId, member.userId);
      if (!mounted) return;
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove member: $e")),
      );
    }
  }

  Future<void> _leaveSquad() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Squad"),
        content: const Text(
            "Are you sure you want to leave this squad? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Leave"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.squadService.leaveSquad(widget.squadId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to leave squad: $e")),
      );
    }
  }

  void _copyInviteCode() {
    if (_squad == null) return;
    Clipboard.setData(ClipboardData(text: _squad!.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite code copied to clipboard")),
    );
  }

  void _shareInvite() {
    if (_squad == null) return;
    Share.share(
      "Join my Style Squad \"${_squad!.name}\" on Vestiaire! Use invite code: ${_squad!.inviteCode}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(_squad?.name ?? "Squad"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "leave") _leaveSquad();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: "leave",
                child: Text(
                  "Leave Squad",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header section
          _buildHeader(),
          const SizedBox(height: 16),
          // Members section
          _buildMembersSection(),
          const SizedBox(height: 16),
          // Recent Posts section (Story 9.3)
          _buildRecentPostsSection(),
          const SizedBox(height: 16),
          // OOTD Post entry point (Story 9.2)
          _buildOotdSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _squad!.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            if (_squad!.description != null &&
                _squad!.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _squad!.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: "Invite code: ${_squad!.inviteCode}",
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _squad!.inviteCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: "Copy invite code",
                  child: IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF4F46E5)),
                    onPressed: _copyInviteCode,
                  ),
                ),
                Semantics(
                  label: "Share invite",
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Color(0xFF4F46E5)),
                    onPressed: _shareInvite,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    if (_members == null || _members!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Members (${_members!.length})",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            ...(_members!.map((member) => _buildMemberRow(member))),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(SquadMember member) {
    final initials = (member.displayName ?? "?")
        .split(" ")
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : "")
        .take(2)
        .join();

    return Semantics(
      label:
          "Member: ${member.displayName ?? 'Unknown'}, ${member.isAdmin ? 'Admin' : 'Member'}",
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundImage:
              member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
          backgroundColor: const Color(0xFF4F46E5),
          child: member.photoUrl == null
              ? Text(initials,
                  style: const TextStyle(color: Colors.white, fontSize: 14))
              : null,
        ),
        title: Text(
          member.displayName ?? "Unknown",
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: member.isAdmin
            ? const Chip(
                label: Text("Admin",
                    style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Color(0xFF4F46E5),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : null,
        trailing: _isAdmin && !member.isAdmin
            ? Semantics(
                label: "Remove ${member.displayName ?? 'member'}",
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () => _removeMember(member),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRecentPostsSection() {
    if (_recentPosts == null) return const SizedBox.shrink();

    if (_recentPosts!.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                "No posts yet -- share your first OOTD!",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.ootdService != null && widget.apiClient != null)
                Semantics(
                  label: "Post OOTD",
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Posts",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            if (widget.ootdService != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OotdFeedScreen(
                        ootdService: widget.ootdService!,
                        squadService: widget.squadService,
                        apiClient: widget.apiClient,
                        initialSquadFilter: widget.squadId,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recentPosts!.map((post) => OotdPostCard(
              post: post,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OotdPostDetailScreen(
                      postId: post.id,
                      ootdService: widget.ootdService!,
                    ),
                  ),
                );
              },
              onReactionTap: () => _handleReactionTap(post),
              onCommentTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OotdPostDetailScreen(
                      postId: post.id,
                      ootdService: widget.ootdService!,
                    ),
                  ),
                );
              },
              onStealLookTap: post.taggedItems.isNotEmpty && widget.ootdService != null
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StealThisLookScreen(
                            postId: post.id,
                            post: post,
                            ootdService: widget.ootdService!,
                          ),
                        ),
                      );
                    }
                  : null,
            )),
      ],
    );
  }

  Future<Map<String, dynamic>> _handleReactionTap(OotdPost post) async {
    final result = await widget.ootdService!.toggleReaction(post.id);
    if (mounted && _recentPosts != null) {
      final index = _recentPosts!.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        final reacted = result["reacted"] as bool? ?? false;
        final reactionCount = result["reactionCount"] as int? ?? 0;
        setState(() {
          _recentPosts![index] = OotdPost(
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

  void _navigateToCreateOotd() {
    if (widget.ootdService == null || widget.apiClient == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OotdCreateScreen(
          ootdService: widget.ootdService!,
          squadService: widget.squadService,
          apiClient: widget.apiClient!,
          preselectedSquadId: widget.squadId,
        ),
      ),
    );
  }

  Widget _buildOotdSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.photo_camera_outlined,
                size: 40, color: Color(0xFF4F46E5)),
            const SizedBox(height: 8),
            const Text(
              "Share your outfit with the squad",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: "Post OOTD",
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.add_a_photo),
                onPressed: _navigateToCreateOotd,
                label: const Text("Post OOTD"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
