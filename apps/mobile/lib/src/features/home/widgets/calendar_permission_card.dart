import "package:flutter/material.dart";

/// Card prompting the user to connect their calendar.
///
/// Shown on the Home screen when calendar permission has not yet been
/// requested and the user has not previously dismissed it.
class CalendarPermissionCard extends StatelessWidget {
  const CalendarPermissionCard({
    required this.onConnectCalendar,
    required this.onNotNow,
    super.key,
  });

  final VoidCallback onConnectCalendar;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Connect calendar to get event-aware outfit suggestions",
      child: Container(
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
              Icons.calendar_month,
              size: 48,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(height: 16),
            const Text(
              "Plan outfits around your events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connect your calendar so Vestiaire can suggest outfits that match your meetings, dinners, and activities",
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
              child: ElevatedButton(
                onPressed: onConnectCalendar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Connect Calendar",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
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
          ],
        ),
      ),
    );
  }
}

/// Card shown when calendar permission has been denied.
///
/// Provides a path for the user to grant calendar access later
/// via the "Grant Access" button which opens device settings.
class CalendarDeniedCard extends StatelessWidget {
  const CalendarDeniedCard({
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
            Icons.calendar_month,
            size: 40,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            "Calendar access needed",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Enable calendar access to get outfit suggestions tailored to your upcoming events",
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
