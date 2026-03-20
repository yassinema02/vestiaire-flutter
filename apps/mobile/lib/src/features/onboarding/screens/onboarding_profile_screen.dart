import "package:flutter/material.dart";

/// Style preferences available during onboarding.
const List<String> kStylePreferences = [
  "casual",
  "streetwear",
  "minimalist",
  "classic",
  "bohemian",
  "sporty",
  "vintage",
  "glamorous",
];

/// Onboarding step 1: display name and style preferences.
class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({
    required this.onContinue,
    required this.onSkip,
    super.key,
  });

  /// Called with display name and selected style preferences.
  final void Function(String displayName, List<String> styles) onContinue;

  /// Called when the user taps Skip.
  final VoidCallback onSkip;

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final _nameController = TextEditingController();
  final _selectedStyles = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Set Up Your Profile"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "What should we call you?",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1F2937),
                    ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: "Display name",
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Enter your display name",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Pick your style",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1F2937),
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kStylePreferences.map((style) {
                  final isSelected = _selectedStyles.contains(style);
                  return Semantics(
                    label: "$style style preference",
                    child: FilterChip(
                      label: Text(
                        style[0].toUpperCase() + style.substring(1),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF4F46E5),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1F2937),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedStyles.add(style);
                          } else {
                            _selectedStyles.remove(style);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              Semantics(
                label: "Continue",
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canContinue
                        ? () => widget.onContinue(
                              _nameController.text.trim(),
                              _selectedStyles.toList(),
                            )
                        : null,
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
