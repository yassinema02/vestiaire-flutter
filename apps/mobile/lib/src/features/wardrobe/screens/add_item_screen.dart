import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../../../core/networking/api_client.dart";
import "../../../core/widgets/style_points_toast.dart";
import "../../profile/widgets/badge_awarded_modal.dart";
import "../../profile/widgets/challenge_completion_modal.dart";
import "../../profile/widgets/level_up_modal.dart";
import "../models/wardrobe_item.dart";
import "review_item_screen.dart";

/// Screen for adding a new wardrobe item via camera or gallery.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    required this.apiClient,
    this.onItemAdded,
    this.imagePicker,
    super.key,
  });

  final ApiClient apiClient;

  /// Called when an item is successfully added.
  final VoidCallback? onItemAdded;

  /// Optional image picker for dependency injection in tests.
  final ImagePicker? imagePicker;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  bool _isUploading = false;
  String? _selectedImagePath;

  ImagePicker get _picker => widget.imagePicker ?? ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        imageQuality: 85,
      );
      if (image != null) {
        await _handleImage(image.path);
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Camera not available on this device."),
          ),
        );
      }
    }
  }

  Future<void> _chooseFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (image != null) {
      await _handleImage(image.path);
    }
  }

  Future<void> _handleImage(String imagePath) async {
    if (!mounted) return;
    setState(() {
      _isUploading = true;
      _selectedImagePath = imagePath;
    });

    try {
      // Step 1: Get signed upload URL
      final uploadResult = await widget.apiClient.getSignedUploadUrl(
        purpose: "item_photo",
      );
      final uploadUrl = uploadResult["uploadUrl"] as String;
      final publicUrl = uploadResult["publicUrl"] as String;

      // Step 2: Upload image
      await widget.apiClient.uploadImage(imagePath, uploadUrl);

      // Step 3: Create item record
      final createResult = await widget.apiClient.createItem(photoUrl: publicUrl);

      // Show style points toast if points were awarded
      if (mounted) {
        final pointsData = createResult["pointsAwarded"] as Map<String, dynamic>?;
        if (pointsData != null) {
          final pts = pointsData["pointsAwarded"] as int?;
          if (pts != null && pts > 0) {
            showStylePointsToast(context, pointsAwarded: pts);
          }
        }
      }

      // Show level-up modal if user leveled up
      if (mounted) {
        final levelUp = createResult["levelUp"] as Map<String, dynamic>?;
        if (levelUp != null) {
          // Brief delay so the toast appears first
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            showLevelUpModal(
              context,
              newLevel: levelUp["newLevel"] as int,
              newLevelName: levelUp["newLevelName"] as String,
              previousLevelName: levelUp["previousLevelName"] as String?,
              nextLevelThreshold: levelUp["nextLevelThreshold"] as int?,
            );
          }
        }
      }

      // Show badge awarded modals if badges were earned
      if (mounted) {
        final badgesAwarded = createResult["badgesAwarded"] as List<dynamic>?;
        if (badgesAwarded != null && badgesAwarded.isNotEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            await showBadgeAwardedModals(
              context,
              badgesAwarded.cast<Map<String, dynamic>>(),
            );
          }
        }
      }

      // Show challenge completion modal if challenge was completed
      if (mounted) {
        final challengeUpdate = createResult["challengeUpdate"] as Map<String, dynamic>?;
        if (challengeUpdate != null && challengeUpdate["completed"] == true) {
          await Future<void>.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            showChallengeCompletionModal(
              context,
              challengeName: "Closet Safari",
              rewardDescription: "1 month Premium free",
            );
          }
        }
      }

      if (mounted) {
        final itemData = createResult["item"] as Map<String, dynamic>? ?? {};
        final item = WardrobeItem.fromJson(itemData);
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ReviewItemScreen(
              item: item,
              apiClient: widget.apiClient,
            ),
          ),
        );
        if (saved == true) {
          widget.onItemAdded?.call();
        }
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to add item. Please try again."),
          ),
        );
        setState(() {
          _isUploading = false;
          _selectedImagePath = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Add Item",
          style: TextStyle(color: Color(0xFF1F2937)),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: Semantics(
          label: "Close",
          child: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: _isUploading ? _buildUploadingState() : _buildOptionCards(),
      ),
    );
  }

  Widget _buildUploadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_selectedImagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Image.file(
                  File(_selectedImagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Icons.image, size: 64),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: Color(0xFF4F46E5),
          ),
          const SizedBox(height: 16),
          const Text(
            "Uploading...",
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCards() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: "Take Photo",
            child: _OptionCard(
              icon: Icons.camera_alt,
              title: "Take Photo",
              onTap: _takePhoto,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: "Choose from Gallery",
            child: _OptionCard(
              icon: Icons.photo_library,
              title: "Choose from Gallery",
              onTap: _chooseFromGallery,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
