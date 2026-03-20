import "package:flutter/material.dart";

import "../../../core/calendar/calendar_event.dart";

/// Helper to get the icon for an event type.
///
/// Reuses the mapping from EventSummaryWidget (Story 3.5).
IconData iconForEventType(String eventType) {
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

/// Helper to get a color for an event type chip.
Color colorForEventType(String eventType) {
  switch (eventType) {
    case "work":
      return const Color(0xFF2563EB);
    case "social":
      return const Color(0xFF7C3AED);
    case "active":
      return const Color(0xFF059669);
    case "formal":
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF6B7280);
  }
}

/// Displays today's calendar events in an enhanced multi-event section.
///
/// Replaces the simpler EventSummaryWidget from Story 3.5 with a richer
/// display showing up to 3 events with type icons, formality badges, and
/// tap callbacks.
class EventsSection extends StatelessWidget {
  const EventsSection({
    required this.events,
    this.onEventTap,
    this.onEditClassification,
    super.key,
  });

  final List<CalendarEvent> events;

  /// Called when the user taps on an event card (opens outfit suggestions).
  final ValueChanged<CalendarEvent>? onEventTap;

  /// Called when the user taps the edit classification icon on an event card.
  final ValueChanged<CalendarEvent>? onEditClassification;

  String _formatTime(DateTime dateTime, bool allDay) {
    if (allDay) return "All day";
    final hour = dateTime.hour.toString().padLeft(2, "0");
    final minute = dateTime.minute.toString().padLeft(2, "0");
    return "$hour:$minute";
  }

  String _formatTimeRange(CalendarEvent event) {
    if (event.allDay) return "All day";
    return "${_formatTime(event.startTime, false)} - ${_formatTime(event.endTime, false)}";
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Today's events section",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Events",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty) _buildEmptyState() else _buildEventsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.calendar_today,
            size: 32,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 8),
          Text(
            "No events today",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    // Sort events chronologically
    final sorted = List<CalendarEvent>.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final displayEvents = sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildEventCard(event),
            )),
        if (events.length > 3)
          GestureDetector(
            child: Text(
              "View all ${events.length} events",
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Semantics(
      label:
          "Event: ${event.title} at ${_formatTimeRange(event)}, ${event.eventType}, formality ${event.formalityScore}",
      child: GestureDetector(
        onTap: () => onEventTap?.call(event),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                iconForEventType(event.eventType),
                size: 24,
                color: const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeRange(event),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Formality badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Formality ${event.formalityScore}/10",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Event type chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorForEventType(event.eventType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _capitalizeFirst(event.eventType),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorForEventType(event.eventType),
                  ),
                ),
              ),
              if (onEditClassification != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => onEditClassification?.call(event),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF9CA3AF),
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
