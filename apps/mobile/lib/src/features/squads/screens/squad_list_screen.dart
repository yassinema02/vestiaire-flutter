import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../../../core/utils/time_utils.dart";
import "../models/squad.dart";
import "../services/ootd_service.dart";
import "../services/squad_service.dart";
import "ootd_create_screen.dart";
import "ootd_feed_screen.dart";
import "squad_detail_screen.dart";

/// Displays the list of squads the user belongs to, with create/join flows
/// and a Feed tab for browsing OOTD posts.
///
/// Story 9.1: Squad Creation & Management (FR-SOC-01, FR-SOC-02, FR-SOC-04)
/// Story 9.3: Added Feed tab (FR-SOC-07, FR-SOC-08)
class SquadListScreen extends StatefulWidget {
  const SquadListScreen({
    required this.squadService,
    this.ootdService,
    this.apiClient,
    super.key,
  });

  final SquadService squadService;
  final OotdService? ootdService;
  final ApiClient? apiClient;

  @override
  State<SquadListScreen> createState() => SquadListScreenState();
}

class SquadListScreenState extends State<SquadListScreen> {
  List<Squad>? _squads;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSquads();
  }

  Future<void> _loadSquads() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final squads = await widget.squadService.listMySquads();
      if (!mounted) return;
      setState(() {
        _squads = squads;
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

  void _showCreateSquadSheet() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Create Squad",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Squad Name",
                    hintText: "Enter squad name",
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Name is required";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Description (optional)",
                    hintText: "What is this squad about?",
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(ctx).pop();
                    try {
                      final squad = await widget.squadService.createSquad(
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                      );
                      if (!mounted) return;
                      await _loadSquads();
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SquadDetailScreen(
                            squadId: squad.id,
                            squadService: widget.squadService,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to create squad: $e")),
                      );
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJoinSquadSheet() {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Join Squad",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: "Invite Code",
                    hintText: "Enter 8-character code",
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Invite code is required";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(ctx).pop();
                    try {
                      final squad = await widget.squadService.joinSquad(
                        inviteCode: codeController.text.trim(),
                      );
                      if (!mounted) return;
                      await _loadSquads();
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SquadDetailScreen(
                            squadId: squad.id,
                            squadService: widget.squadService,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      String message = "Failed to join squad";
                      if (e.toString().contains("SQUAD_FULL")) {
                        message = "This squad is full (max 20 members)";
                      } else if (e.toString().contains("INVALID_INVITE_CODE") ||
                          e.toString().contains("404")) {
                        message = "Invalid invite code";
                      } else if (e.toString().contains("ALREADY_MEMBER")) {
                        message = "You are already a member of this squad";
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  },
                  child: const Text("Join"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If ootdService is available, show tabs; otherwise just the squad list
    if (widget.ootdService != null) {
      return _buildWithTabs();
    }
    return _buildWithoutTabs();
  }

  Widget _buildWithTabs() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: const Text("Social"),
          actions: _buildActions(),
          bottom: const TabBar(
            tabs: [
              Tab(text: "My Squads"),
              Tab(text: "Feed"),
            ],
            labelColor: Color(0xFF4F46E5),
            unselectedLabelColor: Color(0xFF6B7280),
            indicatorColor: Color(0xFF4F46E5),
          ),
        ),
        body: TabBarView(
          children: [
            _buildSquadListBody(),
            OotdFeedScreen(
              ootdService: widget.ootdService!,
              squadService: widget.squadService,
              apiClient: widget.apiClient,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithoutTabs() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Social"),
        actions: _buildActions(),
      ),
      body: _buildSquadListBody(),
    );
  }

  List<Widget> _buildActions() {
    return [
      if (widget.ootdService != null && widget.apiClient != null)
        Semantics(
          label: "Post OOTD",
          child: IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OotdCreateScreen(
                    ootdService: widget.ootdService!,
                    squadService: widget.squadService,
                    apiClient: widget.apiClient!,
                  ),
                ),
              );
            },
            tooltip: "Post OOTD",
          ),
        ),
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.group_add,
                          color: Color(0xFF4F46E5)),
                      title: const Text("Create Squad"),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showCreateSquadSheet();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.login,
                          color: Color(0xFF4F46E5)),
                      title: const Text("Join Squad"),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showJoinSquadSheet();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        tooltip: "Add or join squad",
      ),
    ];
  }

  Widget _buildSquadListBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text("Error: $_error"));
    }
    if (_squads == null || _squads!.isEmpty) {
      return _buildEmptyState();
    }
    return _buildSquadList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: "Style squads icon",
              child: const Icon(
                Icons.groups,
                size: 64,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Your Style Squads",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create a squad or join one with an invite code to start sharing outfits with friends.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: "Create Squad",
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: _showCreateSquadSheet,
                child: const Text("Create Squad"),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: "Join Squad",
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: _showJoinSquadSheet,
                child: const Text("Join Squad"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadList() {
    return RefreshIndicator(
      onRefresh: _loadSquads,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _squads!.length,
        itemBuilder: (context, index) {
          final squad = _squads![index];
          return Semantics(
            label: "Squad: ${squad.name}, ${squad.memberCount} members",
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                title: Text(
                  squad.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                subtitle: Text(
                  "${squad.memberCount} members",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                trailing: Text(
                  formatRelativeTime(squad.lastActivity),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SquadDetailScreen(
                        squadId: squad.id,
                        squadService: widget.squadService,
                        ootdService: widget.ootdService,
                        apiClient: widget.apiClient,
                      ),
                    ),
                  );
                  _loadSquads();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
