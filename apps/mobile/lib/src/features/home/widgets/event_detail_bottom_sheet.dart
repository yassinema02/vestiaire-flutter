import "package:flutter/material.dart";

import "../../../core/calendar/calendar_event.dart";

/// Bottom sheet for viewing event details and overriding classification.
///
/// Displays event title, time, location, event type chips, and formality slider.
/// Follows Vibrant Soft-UI bottom sheet pattern.
class EventDetailBottomSheet extends StatefulWidget {
  const EventDetailBottomSheet({
    required this.event,
    required this.onSave,
    this.onCancel,
    super.key,
  });

  final CalendarEvent event;
  final ValueChanged<CalendarEvent> onSave;
  final VoidCallback? onCancel;

  @override
  State<EventDetailBottomSheet> createState() => _EventDetailBottomSheetState();
}

class _EventDetailBottomSheetState extends State<EventDetailBottomSheet> {
  late String _selectedEventType;
  late double _formalityScore;

  static const _accentColor = Color(0xFF4F46E5);

  static const _eventTypes = [
    ("work", "Work", Icons.work),
    ("social", "Social", Icons.people),
    ("active", "Active", Icons.fitness_center),
    ("formal", "Formal", Icons.star),
    ("casual", "Casual", Icons.event),
  ];

  @override
  void initState() {
    super.initState();
    _selectedEventType = widget.event.eventType;
    _formalityScore = widget.event.formalityScore.toDouble();
  }

  String _formatTimeRange(CalendarEvent event) {
    if (event.allDay) return "All day";
    final startHour = event.startTime.hour.toString().padLeft(2, "0");
    final startMinute = event.startTime.minute.toString().padLeft(2, "0");
    final endHour = event.endTime.hour.toString().padLeft(2, "0");
    final endMinute = event.endTime.minute.toString().padLeft(2, "0");
    return "$startHour:$startMinute - $endHour:$endMinute";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Event header
          Text(
            widget.event.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimeRange(widget.event),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          if (widget.event.location != null &&
              widget.event.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.event.location!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (widget.event.classificationSource == "user") ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "User override",
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Event Type section
          const Text(
            "Event Type",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: "Event type selector",
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _eventTypes.map((type) {
                final isSelected = _selectedEventType == type.$1;
                return ChoiceChip(
                  avatar: Icon(
                    type.$3,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  ),
                  label: Text(type.$2),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedEventType = type.$1;
                      });
                    }
                  },
                  selectedColor: _accentColor,
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    color:
                        isSelected ? Colors.white : const Color(0xFF4B5563),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Formality Score section
          const Text(
            "Formality Score",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: "Formality score: ${_formalityScore.round()}",
            child: Slider(
              value: _formalityScore,
              min: 1,
              max: 10,
              divisions: 9,
              label: _formalityScore.round().toString(),
              activeColor: _accentColor,
              onChanged: (value) {
                setState(() {
                  _formalityScore = value;
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "1 - Very Casual",
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              Text(
                "10 - Very Formal",
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: "Save event classification",
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      final updatedEvent = widget.event.copyWith(
                        eventType: _selectedEventType,
                        formalityScore: _formalityScore.round(),
                        classificationSource: "user",
                      );
                      widget.onSave(updatedEvent);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Save"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Show the event detail bottom sheet.
///
/// Returns when the sheet is dismissed.
void showEventDetailBottomSheet(
  BuildContext context, {
  required CalendarEvent event,
  required ValueChanged<CalendarEvent> onSave,
  VoidCallback? onCancel,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.white,
    builder: (context) => EventDetailBottomSheet(
      event: event,
      onSave: onSave,
      onCancel: onCancel,
    ),
  );
}
