import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../wardrobe/models/taxonomy.dart";
import "../../wardrobe/models/wardrobe_item.dart";
import "../services/outfit_persistence_service.dart";

/// Screen for naming a manually-built outfit and selecting an occasion
/// before saving it via the API.
class NameOutfitScreen extends StatefulWidget {
  const NameOutfitScreen({
    required this.selectedItems,
    required this.outfitPersistenceService,
    super.key,
  });

  final List<WardrobeItem> selectedItems;
  final OutfitPersistenceService outfitPersistenceService;

  @override
  State<NameOutfitScreen> createState() => _NameOutfitScreenState();
}

class _NameOutfitScreenState extends State<NameOutfitScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedOccasion;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim().isEmpty
        ? "My Outfit"
        : _nameController.text.trim();

    final itemsList = widget.selectedItems
        .asMap()
        .entries
        .map((e) => <String, dynamic>{
              "itemId": e.value.id,
              "position": e.key,
            })
        .toList();

    final result = await widget.outfitPersistenceService.saveManualOutfit(
      name: name,
      occasion: _selectedOccasion,
      items: itemsList,
    );

    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Outfit created!")),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to create outfit. Please try again."),
        ),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        title: const Text("Name Your Outfit"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected items preview
            SizedBox(
              height: 90,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.selectedItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: CachedNetworkImage(
                                imageUrl: item.photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                    color: const Color(0xFFE5E7EB)),
                                errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFFE5E7EB)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.displayLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Outfit name
            const Text(
              "Outfit Name",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: "Outfit name input",
              child: TextField(
                controller: _nameController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: "My Outfit",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Occasion
            const Text(
              "Occasion",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: "Select occasion for this outfit",
              child: DropdownButtonFormField<String>(
                initialValue: _selectedOccasion,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text("None"),
                  ),
                  ...validOccasions.map((occasion) {
                    return DropdownMenuItem<String>(
                      value: occasion,
                      child: Text(taxonomyDisplayLabel(occasion)),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedOccasion = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Semantics(
                label: "Save outfit",
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF4F46E5),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save Outfit"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
