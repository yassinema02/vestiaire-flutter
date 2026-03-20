import "package:flutter/material.dart";

/// Card prompting the user to enable location access.
///
/// Shown on the Home screen when location permission has not yet been requested
/// and the user has not previously dismissed it.
class LocationPermissionCard extends StatelessWidget {
  const LocationPermissionCard({
    required this.onEnableLocation,
    required this.onNotNow,
    super.key,
  });

  final VoidCallback onEnableLocation;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.location_on,
            size: 48,
            color: Color(0xFF4F46E5),
          ),
          const SizedBox(height: 16),
          const Text(
            "Enable Location",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "To show weather and tailor outfit suggestions to your conditions",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Semantics(
              label: "Enable Location",
              child: ElevatedButton(
                onPressed: onEnableLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Enable Location",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: Semantics(
              label: "Not Now",
              child: TextButton(
                onPressed: onNotNow,
                child: const Text(
                  "Not Now",
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
