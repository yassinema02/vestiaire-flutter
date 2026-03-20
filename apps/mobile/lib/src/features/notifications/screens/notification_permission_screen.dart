import "package:flutter/material.dart";

/// Onboarding screen that requests push notification permission.
///
/// Shows motivational copy explaining notification benefits and provides
/// an "Enable Notifications" button to trigger the OS permission dialog,
/// and a "Not Now" button to skip.
class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({
    required this.onEnable,
    required this.onSkip,
    super.key,
  });

  /// Called when the user taps "Enable Notifications".
  final VoidCallback onEnable;

  /// Called when the user taps "Not Now" to skip.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Icon(
                Icons.notifications_active,
                size: 80,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(height: 32),
              Text(
                "Stay in the Loop",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1F2937),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Get timely reminders to plan your outfits, log what you wear, "
                "discover style insights, and stay connected with your squad.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotificationCategory(
                      icon: Icons.wb_sunny_outlined,
                      title: "Outfit Reminders",
                      subtitle: "Morning outfit suggestions",
                    ),
                    SizedBox(height: 12),
                    _NotificationCategory(
                      icon: Icons.edit_note,
                      title: "Wear Logging",
                      subtitle: "Evening reminders to log outfits",
                    ),
                    SizedBox(height: 12),
                    _NotificationCategory(
                      icon: Icons.insights,
                      title: "Style Insights",
                      subtitle: "Wardrobe analytics and tips",
                    ),
                    SizedBox(height: 12),
                    _NotificationCategory(
                      icon: Icons.people_outline,
                      title: "Social Updates",
                      subtitle: "Squad posts and reactions",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Semantics(
                label: "Enable Notifications",
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onEnable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Enable Notifications"),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: "Not Now",
                child: SizedBox(
                  height: 50,
                  child: TextButton(
                    onPressed: onSkip,
                    child: const Text(
                      "Not Now",
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

class _NotificationCategory extends StatelessWidget {
  const _NotificationCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
