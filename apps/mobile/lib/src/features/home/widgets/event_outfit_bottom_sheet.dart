import "package:flutter/material.dart";

import "../../../core/calendar/calendar_event.dart";
import "../../../core/weather/outfit_context.dart";
import "../../outfits/models/outfit_suggestion.dart";
import "../../outfits/services/outfit_generation_service.dart";
import "events_section.dart";
import "outfit_suggestion_card.dart";

/// Bottom sheet displaying event details and event-specific outfit suggestions.
///
/// Automatically triggers event outfit generation on init and shows loading,
/// success, or error states accordingly.
class EventOutfitBottomSheet extends StatefulWidget {
  const EventOutfitBottomSheet({
    required this.event,
    required this.outfitGenerationService,
    this.outfitContext,
    super.key,
  });

  final CalendarEvent event;
  final OutfitGenerationService outfitGenerationService;
  final OutfitContext? outfitContext;

  @override
  State<EventOutfitBottomSheet> createState() => _EventOutfitBottomSheetState();
}

class _EventOutfitBottomSheetState extends State<EventOutfitBottomSheet> {
  bool _isLoading = true;
  String? _error;
  OutfitGenerationResult? _result;

  @override
  void initState() {
    super.initState();
    _generateEventOutfits();
  }

  Future<void> _generateEventOutfits() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result =
        await widget.outfitGenerationService.generateOutfitsForEvent(
      widget.outfitContext,
      widget.event,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result != null) {
        _result = result;
        _error = null;
      } else {
        _error = "Unable to generate suggestions for this event.";
      }
    });
  }

  String _formatTimeRange(CalendarEvent event) {
    if (event.allDay) return "All day";
    final startHour = event.startTime.hour.toString().padLeft(2, "0");
    final startMinute = event.startTime.minute.toString().padLeft(2, "0");
    final endHour = event.endTime.hour.toString().padLeft(2, "0");
    final endMinute = event.endTime.minute.toString().padLeft(2, "0");
    return "$startHour:$startMinute - $endHour:$endMinute";
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Outfit suggestions for ${widget.event.title}",
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 12),
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
                // Event details
                _buildEventDetails(),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                // Suggestions header
                const Text(
                  "Event Outfit Suggestions",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                // Suggestions content
                _buildSuggestionsContent(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 8),
        Row(
          children: [
            // Event type chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorForEventType(widget.event.eventType)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconForEventType(widget.event.eventType),
                    size: 14,
                    color: colorForEventType(widget.event.eventType),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _capitalizeFirst(widget.event.eventType),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorForEventType(widget.event.eventType),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Formality badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Formality ${widget.event.formalityScore}/10",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
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
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionsContent() {
    if (_isLoading) {
      return Semantics(
        label: "Loading event outfit suggestions",
        child: Column(
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          const SizedBox(height: 12),
          const Icon(
            Icons.calendar_today,
            size: 32,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _generateEventOutfits,
            child: const Text(
              "Try Again",
              style: TextStyle(
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
        ],
      );
    }

    if (_result != null && _result!.suggestions.isNotEmpty) {
      return Column(
        children: _result!.suggestions
            .map((suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutfitSuggestionCard(suggestion: suggestion),
                ))
            .toList(),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Show the event outfit bottom sheet.
void showEventOutfitBottomSheet(
  BuildContext context, {
  required CalendarEvent event,
  required OutfitGenerationService outfitGenerationService,
  OutfitContext? outfitContext,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EventOutfitBottomSheet(
      event: event,
      outfitGenerationService: outfitGenerationService,
      outfitContext: outfitContext,
    ),
  );
}
