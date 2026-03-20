import "package:flutter/material.dart";

import "../../../core/calendar/calendar_event.dart";

/// Compact card showing the next upcoming calendar event or empty state.
///
/// Follows the Vibrant Soft-UI design system (white background, 16px radius,
/// subtle border and shadow).
class EventSummaryWidget extends StatelessWidget {
  const EventSummaryWidget({
    required this.events,
    this.onEventTap,
    super.key,
  });

  final List<CalendarEvent> events;

  /// Called when the user taps on the next event row.
  final ValueChanged<CalendarEvent>? onEventTap;

  IconData _iconForType(String eventType) {
    switch (eventType) {
      case "work":
        return Icons.work;
      case "social":
        return Icons.people;
      case "active":
        return Icons.fitness_center;
      case "formal":
        return Icons.star;
      default:
        return Icons.event;
    }
  }

  String _formatTime(DateTime dateTime, bool allDay) {
    if (allDay) return "All day";
    final hour = dateTime.hour.toString().padLeft(2, "0");
    final minute = dateTime.minute.toString().padLeft(2, "0");
    return "$hour:$minute";
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Semantics(
        label: "No events scheduled for today",
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 24,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              const Text(
                "No events today",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by start time and pick the next upcoming event
    final sorted = List<CalendarEvent>.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final nextEvent = sorted.first;
    final remainingCount = sorted.length - 1;

    return Semantics(
      label:
          "Upcoming event: ${nextEvent.title} at ${_formatTime(nextEvent.startTime, nextEvent.allDay)}",
      hint: "Double tap to edit classification",
      child: GestureDetector(
        onTap: () => onEventTap?.call(nextEvent),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _iconForType(nextEvent.eventType),
                size: 28,
                color: const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextEvent.title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(nextEvent.startTime, nextEvent.allDay),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _capitalizeFirst(nextEvent.eventType),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              if (remainingCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  "+$remainingCount more",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
