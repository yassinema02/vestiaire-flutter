import "package:flutter/material.dart";

import "../../../core/calendar/calendar_preferences_service.dart";
import "../../../core/calendar/calendar_service.dart";

/// Screen for selecting which device calendars to sync.
///
/// Displays all available calendars with toggle switches. On "Done",
/// persists the user's selection via [CalendarPreferencesService].
class CalendarSelectionScreen extends StatefulWidget {
  const CalendarSelectionScreen({
    required this.calendars,
    this.calendarPreferencesService,
    this.previouslySelectedIds,
    super.key,
  });

  final List<DeviceCalendar> calendars;

  /// Optional for test injection.
  final CalendarPreferencesService? calendarPreferencesService;

  /// If provided, restores previous selection state (for returning users).
  final List<String>? previouslySelectedIds;

  @override
  State<CalendarSelectionScreen> createState() =>
      _CalendarSelectionScreenState();
}

class _CalendarSelectionScreenState extends State<CalendarSelectionScreen> {
  late Map<String, bool> _selection;
  late CalendarPreferencesService _prefsService;

  @override
  void initState() {
    super.initState();
    _prefsService =
        widget.calendarPreferencesService ?? CalendarPreferencesService();
    _initSelection();
  }

  void _initSelection() {
    if (widget.previouslySelectedIds != null) {
      final selectedSet = widget.previouslySelectedIds!.toSet();
      _selection = {
        for (final cal in widget.calendars)
          cal.id: selectedSet.contains(cal.id),
      };
    } else {
      // Default all calendars to selected (toggled ON)
      _selection = {
        for (final cal in widget.calendars) cal.id: true,
      };
    }
  }

  Future<void> _handleDone() async {
    final selectedIds = _selection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await _prefsService.saveSelectedCalendarIds(selectedIds);
    await _prefsService.setCalendarConnected(true);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // User pressed back without tapping Done -- pop with false
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Select Calendars"),
          actions: [
            TextButton(
              onPressed: _handleDone,
              child: const Text(
                "Done",
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: widget.calendars.length,
          itemBuilder: (context, index) {
            final calendar = widget.calendars[index];
            final isSelected = _selection[calendar.id] ?? false;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: calendar.color ?? const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calendar.name,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (calendar.accountName != null)
                          Text(
                            calendar.accountName!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: "Toggle sync for ${calendar.name}",
                    child: Switch(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          _selection[calendar.id] = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
