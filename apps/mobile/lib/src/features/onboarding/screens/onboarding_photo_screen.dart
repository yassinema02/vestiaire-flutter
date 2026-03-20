import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

/// Onboarding step 2: profile photo selection.
class OnboardingPhotoScreen extends StatefulWidget {
  const OnboardingPhotoScreen({
    required this.onContinue,
    required this.onSkip,
    this.imagePicker,
    super.key,
  });

  /// Called with the selected photo file path (or null if skipped).
  final void Function(String? photoPath) onContinue;

  /// Called when the user taps Skip.
  final VoidCallback onSkip;

  /// Optional image picker for testing.
  final ImagePicker? imagePicker;

  @override
  State<OnboardingPhotoScreen> createState() => _OnboardingPhotoScreenState();
}

class _OnboardingPhotoScreenState extends State<OnboardingPhotoScreen> {
  String? _selectedPhotoPath;

  Future<void> _pickPhoto() async {
    final picker = widget.imagePicker ?? ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _selectedPhotoPath = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Add a Profile Photo"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Semantics(
                label: "Profile photo",
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFFD1D5DB),
                  backgroundImage: _selectedPhotoPath != null
                      ? FileImage(File(_selectedPhotoPath!))
                      : null,
                  child: _selectedPhotoPath == null
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color: Color(0xFF9CA3AF),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                label: "Choose Photo",
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Choose Photo"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Semantics(
                label: "Continue",
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => widget.onContinue(_selectedPhotoPath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Continue"),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: "Skip",
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: widget.onSkip,
                    child: const Text(
                      "Skip for now",
                      style: TextStyle(color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
