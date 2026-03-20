import "package:flutter/material.dart";

/// Card shown when location permission has been denied.
///
/// Provides a path for the user to grant location access later
/// via the "Grant Access" button which opens system settings.
class WeatherDeniedCard extends StatelessWidget {
  const WeatherDeniedCard({
    required this.onGrantAccess,
    super.key,
  });

  final VoidCallback onGrantAccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.location_off,
            size: 40,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            "Location access needed for weather",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Enable location to see local weather and get outfit suggestions tailored to your conditions",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: Semantics(
              label: "Grant Access",
              child: OutlinedButton(
                onPressed: onGrantAccess,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Grant Access",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
