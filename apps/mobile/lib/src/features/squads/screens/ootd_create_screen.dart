import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../../../core/networking/api_client.dart";
import "../models/squad.dart";
import "../services/ootd_service.dart";
import "../services/squad_service.dart";
import "squad_list_screen.dart";

/// Screen for creating an OOTD (Outfit of the Day) post with photo, caption,
/// item tagging, and squad selection.
///
/// Story 9.2: OOTD Post Creation (FR-SOC-06)
class OotdCreateScreen extends StatefulWidget {
  const OotdCreateScreen({
    required this.ootdService,
    required this.squadService,
    required this.apiClient,
    this.preselectedSquadId,
    this.imagePicker,
    super.key,
  });

  final OotdService ootdService;
  final SquadService squadService;
  final ApiClient apiClient;
  final String? preselectedSquadId;

  /// Optional image picker for dependency injection in tests.
  final ImagePicker? imagePicker;

  @override
  State<OotdCreateScreen> createState() => _OotdCreateScreenState();
}

class _OotdCreateScreenState extends State<OotdCreateScreen> {
  String? _selectedImagePath;
  final TextEditingController _captionController = TextEditingController();
  final List<_TaggedItem> _taggedItems = [];
  List<Squad> _squads = [];
  final Set<String> _selectedSquadIds = {};
  bool _loadingSquads = true;
  bool _posting = false;

  ImagePicker get _picker => widget.imagePicker ?? ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSquads();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadSquads() async {
    try {
      final squads = await widget.squadService.listMySquads();
      if (!mounted) return;
      setState(() {
        _squads = squads;
        _loadingSquads = false;
        if (widget.preselectedSquadId != null) {
          _selectedSquadIds.add(widget.preselectedSquadId!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSquads = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _selectedImagePath = image.path);
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera not available on this device.")),
        );
      }
    }
  }

  Future<void> _chooseFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _selectedImagePath = image.path);
    }
  }

  Future<void> _openItemPicker() async {
    final result = await showModalBottomSheet<List<_TaggedItem>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ItemPickerSheet(
        apiClient: widget.apiClient,
        alreadySelected: _taggedItems.map((t) => t.id).toList(),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _taggedItems.clear();
        _taggedItems.addAll(result);
      });
    }
  }

  void _removeTaggedItem(String itemId) {
    setState(() {
      _taggedItems.removeWhere((t) => t.id == itemId);
    });
  }

  Future<void> _submitPost() async {
    if (_selectedImagePath == null || _selectedSquadIds.isEmpty) return;

    setState(() => _posting = true);

    try {
      // Step 1: Get signed upload URL
      final uploadResult = await widget.apiClient.getSignedUploadUrl(
        purpose: "ootd_post",
      );
      final uploadUrl = uploadResult["uploadUrl"] as String;
      final publicUrl = uploadResult["publicUrl"] as String;

      // Step 2: Upload image
      await widget.apiClient.uploadImage(_selectedImagePath!, uploadUrl);

      // Step 3: Create OOTD post
      await widget.ootdService.createPost(
        photoUrl: publicUrl,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        squadIds: _selectedSquadIds.toList(),
        taggedItemIds: _taggedItems.map((t) => t.id).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OOTD posted!")),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Post OOTD"),
      ),
      body: _loadingSquads
          ? const Center(child: CircularProgressIndicator())
          : _squads.isEmpty
              ? _buildEmptySquadsGuard()
              : _selectedImagePath == null
                  ? _buildPhotoSelection()
                  : _buildForm(),
    );
  }

  Widget _buildEmptySquadsGuard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 64, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text(
              "Join or create a squad first to share your OOTD",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: "Go to Squads",
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
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => SquadListScreen(
                        squadService: widget.squadService,
                      ),
                    ),
                  );
                },
                child: const Text("Go to Squads"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSelection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera_outlined,
                size: 64, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text(
              "Share your outfit of the day",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: "Take Photo",
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  minimumSize: const Size(220, 48),
                ),
                icon: const Icon(Icons.camera_alt),
                onPressed: _takePhoto,
                label: const Text("Take Photo"),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: "Choose from Gallery",
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  minimumSize: const Size(220, 48),
                ),
                icon: const Icon(Icons.photo_library),
                onPressed: _chooseFromGallery,
                label: const Text("Choose from Gallery"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo preview
              Semantics(
                label: "Selected photo preview",
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_selectedImagePath!),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _selectedImagePath = null),
                child: const Text("Change Photo"),
              ),
              const SizedBox(height: 8),

              // Caption field
              Semantics(
                label: "Caption text field",
                child: TextFormField(
                  controller: _captionController,
                  maxLength: 150,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: InputDecoration(
                    hintText: "What are you wearing today?",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 16),

              // Tag Items section
              _buildTagItemsSection(),
              const SizedBox(height: 16),

              // Squad selection section
              _buildSquadSelectionSection(),
              const SizedBox(height: 80), // Space for post button
            ],
          ),
        ),

        // Post button at bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Semantics(
            label: "Post OOTD",
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              onPressed: _selectedSquadIds.isEmpty || _posting
                  ? null
                  : _submitPost,
              child: Text(_posting ? "Posting..." : "Post"),
            ),
          ),
        ),

        // Loading overlay
        if (_posting)
          Positioned.fill(
            child: Semantics(
              label: "Uploading post",
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagItemsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tag Your Items",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._taggedItems.map((item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          label: "Tagged item: ${item.name ?? 'Unknown'}",
                          child: Chip(
                            avatar: item.photoUrl != null
                                ? CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(item.photoUrl!),
                                    radius: 12,
                                  )
                                : const CircleAvatar(
                                    radius: 12,
                                    child: Icon(Icons.checkroom, size: 12),
                                  ),
                            label: Text(
                              item.name ?? "Item",
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon:
                                const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeTaggedItem(item.id),
                          ),
                        ),
                      )),
                  Semantics(
                    label: "Add Items",
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text("Add Items"),
                      onPressed: _openItemPicker,
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

  Widget _buildSquadSelectionSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Share to Squads",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            ..._squads.map((squad) => Semantics(
                  label: "Squad: ${squad.name}, ${squad.memberCount} members",
                  child: CheckboxListTile(
                    title: Text(
                      squad.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    subtitle: Text(
                      "${squad.memberCount} members",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    value: _selectedSquadIds.contains(squad.id),
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedSquadIds.add(squad.id);
                        } else {
                          _selectedSquadIds.remove(squad.id);
                        }
                      });
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Simple model for tagged items in the create screen.
class _TaggedItem {
  const _TaggedItem({
    required this.id,
    this.name,
    this.photoUrl,
  });

  final String id;
  final String? name;
  final String? photoUrl;
}

/// Bottom sheet for picking wardrobe items to tag.
class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({
    required this.apiClient,
    required this.alreadySelected,
  });

  final ApiClient apiClient;
  final List<String> alreadySelected;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  List<Map<String, dynamic>> _items = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.alreadySelected);
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final response = await widget.apiClient.listItems();
      if (!mounted) return;
      setState(() {
        _items = (response["items"] as List<dynamic>? ?? [])
            .map((i) => i as Map<String, dynamic>)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items.where((item) {
      final name = (item["name"] as String? ?? "").toLowerCase();
      final category = (item["category"] as String? ?? "").toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
  }

  void _done() {
    final selected = _items
        .where((item) => _selectedIds.contains(item["id"] as String))
        .map((item) => _TaggedItem(
              id: item["id"] as String,
              name: item["name"] as String?,
              photoUrl: item["photo_url"] as String?,
            ))
        .toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    "Select Items",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: "Done (${_selectedIds.length})",
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _done,
                      child: Text("Done (${_selectedIds.length})"),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search items...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final itemId = item["id"] as String;
                        final isSelected = _selectedIds.contains(itemId);
                        final photoUrl = item["photo_url"] as String?;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(itemId);
                              } else {
                                _selectedIds.add(itemId);
                              }
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color(0xFF4F46E5),
                                          width: 3)
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: photoUrl != null
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.checkroom),
                                        )
                                      : const Center(
                                          child: Icon(Icons.checkroom,
                                              size: 32,
                                              color: Color(0xFF6B7280))),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4F46E5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.check,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
