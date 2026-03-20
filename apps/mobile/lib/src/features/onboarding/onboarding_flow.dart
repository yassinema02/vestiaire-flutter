import "package:flutter/material.dart";

import "../notifications/screens/notification_permission_screen.dart";
import "screens/first_five_items_screen.dart";
import "screens/onboarding_photo_screen.dart";
import "screens/onboarding_profile_screen.dart";

/// Steps in the onboarding flow.
enum OnboardingStep { profile, photo, notifications, firstFiveItems }

/// Coordinates the multi-step onboarding flow.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    required this.onComplete,
    required this.onSkip,
    required this.onProfileSubmit,
    required this.onPhotoSubmit,
    required this.onAddItem,
    this.onEnableNotifications,
    this.onChallengeAutoAccept,
    this.items = const [],
    super.key,
  });

  /// Called when onboarding is fully completed (all 5 items or user taps Done).
  final VoidCallback onComplete;

  /// Called when user taps Skip at any step.
  final VoidCallback onSkip;

  /// Called when profile step is submitted.
  final void Function(String displayName, List<String> styles) onProfileSubmit;

  /// Called when photo step is submitted.
  final void Function(String? photoPath) onPhotoSubmit;

  /// Called when user adds an item photo.
  final void Function(String photoPath) onAddItem;

  /// Called when the user taps "Enable Notifications" during onboarding.
  final VoidCallback? onEnableNotifications;

  /// Called to auto-accept the Closet Safari challenge when onboarding completes.
  /// Fires in the background -- does not block onboarding completion.
  final VoidCallback? onChallengeAutoAccept;

  /// Current items for the first-5-items screen.
  final List<OnboardingItem> items;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingStep _currentStep = OnboardingStep.profile;

  void _goToStep(OnboardingStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Step indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Semantics(
            label: "Onboarding step ${_currentStep.index + 1} of ${OnboardingStep.values.length}",
            child: Row(
              children: OnboardingStep.values.map((step) {
                final isActive = step.index <= _currentStep.index;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Current step screen
        Expanded(
          child: _buildCurrentStep(),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case OnboardingStep.profile:
        return OnboardingProfileScreen(
          onContinue: (name, styles) {
            widget.onProfileSubmit(name, styles);
            _goToStep(OnboardingStep.photo);
          },
          onSkip: widget.onSkip,
        );
      case OnboardingStep.photo:
        return OnboardingPhotoScreen(
          onContinue: (photoPath) {
            widget.onPhotoSubmit(photoPath);
            _goToStep(OnboardingStep.notifications);
          },
          onSkip: () => _goToStep(OnboardingStep.notifications),
        );
      case OnboardingStep.notifications:
        return NotificationPermissionScreen(
          onEnable: () {
            widget.onEnableNotifications?.call();
            _goToStep(OnboardingStep.firstFiveItems);
          },
          onSkip: () => _goToStep(OnboardingStep.firstFiveItems),
        );
      case OnboardingStep.firstFiveItems:
        return FirstFiveItemsScreen(
          items: widget.items,
          onDone: () {
            widget.onChallengeAutoAccept?.call();
            widget.onComplete();
          },
          onSkip: widget.onSkip,
          onAddItem: widget.onAddItem,
        );
    }
  }
}
