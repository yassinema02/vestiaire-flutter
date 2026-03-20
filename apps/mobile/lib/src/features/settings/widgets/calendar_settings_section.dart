import "package:flutter/material.dart";

/// Settings section widget displaying calendar sync status.
///
/// Shows connection state and the number of synced calendars.
/// Tapping navigates to the calendar selection screen or initiates
/// the permission flow.
class CalendarSettingsSection extends StatelessWidget {
  const CalendarSettingsSection({
    required this.isConnected,
    required this.selectedCalendarCount,
    required this.onTap,
    super.key,
  });

  final bool isConnected;
  final int selectedCalendarCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.calendar_month),
      title: const Text("Calendar Sync"),
      subtitle: Text(
        isConnected
            ? "Connected - $selectedCalendarCount calendars synced"
            : "Not connected",
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
