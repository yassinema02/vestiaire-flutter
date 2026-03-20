import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

/// Item data for the first-5-items challenge.
class OnboardingItem {
  const OnboardingItem({required this.photoUrl, this.name});

  final String photoUrl;
  final String? name;
}

/// Onboarding step 3: add your first 5 wardrobe items.
class FirstFiveItemsScreen extends StatefulWidget {
  const FirstFiveItemsScreen({
    required this.onDone,
    required this.onSkip,
    required this.onAddItem,
    this.items = const [],
    this.imagePicker,
    super.key,
  });

  /// Called when user taps Done (at least 1 item or all 5).
  final VoidCallback onDone;

  /// Called when user taps Skip.
  final VoidCallback onSkip;

  /// Called when user picks a photo to add an item. Returns the file path.
  final void Function(String photoPath) onAddItem;

  /// Current list of added items.
  final List<OnboardingItem> items;

  /// Optional image picker for testing.
  final ImagePicker? imagePicker;

  @override
  State<FirstFiveItemsScreen> createState() => _FirstFiveItemsScreenState();
}

class _FirstFiveItemsScreenState extends State<FirstFiveItemsScreen> {
  Future<void> _pickItemPhoto() async {
    final picker = widget.imagePicker ?? ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      widget.onAddItem(image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length;
    final progress = itemCount / 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Build Your Wardrobe!"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Motivational header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "First 5 Items Challenge",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF1F2937),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Start building your digital wardrobe by adding 5 items. "
                      "Take a photo or pick from your gallery!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Progress indicator
              Semantics(
                label: "Progress $itemCount of 5 items",
                child: Column(
                  children: [
                    Text(
                      "$itemCount/5 items added",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Item thumbnails grid
              if (widget.items.isNotEmpty)
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.items[index].photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Icon(Icons.image, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text(
                      "No items yet. Tap below to get started!",
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),

              // Add Item button
              Semantics(
                label: "Add Item",
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: itemCount < 5 ? _pickItemPhoto : null,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text("Add Item"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Done button (enabled when at least 1 item)
              Semantics(
                label: "Done",
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: itemCount > 0 ? widget.onDone : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Done"),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip button
              Semantics(
                label: "Skip",
                child: SizedBox(
                  height: 50,
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
