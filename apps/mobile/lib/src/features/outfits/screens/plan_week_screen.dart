import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/calendar/calendar_event.dart";
import "../../../core/calendar/calendar_event_service.dart";
import "../../../core/networking/api_client.dart";
import "../../../core/weather/daily_forecast.dart";
import "../../../core/weather/weather_cache_service.dart";
import "../../home/widgets/events_section.dart";
import "../models/calendar_outfit.dart";
import "../services/calendar_outfit_service.dart";
import "../services/outfit_generation_service.dart";
import "../services/outfit_persistence_service.dart";
import "../widgets/outfit_assignment_bottom_sheet.dart";

/// Screen for planning outfits for the upcoming week.
///
/// Displays a 7-day horizontal calendar strip with weather previews,
/// event summaries, and scheduled outfit assignments.
class PlanWeekScreen extends StatefulWidget {
  const PlanWeekScreen({
    required this.calendarOutfitService,
    required this.outfitPersistenceService,
    required this.outfitGenerationService,
    this.calendarEventService,
    this.weatherCacheService,
    this.apiClient,
    super.key,
  });

  final CalendarOutfitService calendarOutfitService;
  final OutfitPersistenceService outfitPersistenceService;
  final OutfitGenerationService outfitGenerationService;
  final CalendarEventService? calendarEventService;
  final WeatherCacheService? weatherCacheService;
  final ApiClient? apiClient;

  @override
  State<PlanWeekScreen> createState() => _PlanWeekScreenState();
}

class _PlanWeekScreenState extends State<PlanWeekScreen> {
  static const _dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  static const _accentColor = Color(0xFF4F46E5);

  late final List<DateTime> _days;
  int _selectedDayIndex = 0;
  bool _isLoading = true;
  String? _error;

  List<CalendarOutfit> _calendarOutfits = [];
  List<CalendarEvent> _events = [];
  List<DailyForecast> _forecasts = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(7, (i) => today.add(Duration(days: i)));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startStr = _formatDate(_days.first);
      final endStr = _formatDate(_days.last);

      // Load all data in parallel
      final results = await Future.wait([
        widget.calendarOutfitService
            .getCalendarOutfitsForDateRange(startStr, endStr),
        _loadEvents(startStr, endStr),
        _loadWeather(),
      ]);

      if (mounted) {
        setState(() {
          _calendarOutfits = results[0] as List<CalendarOutfit>;
          _events = results[1] as List<CalendarEvent>;
          _forecasts = results[2] as List<DailyForecast>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load data";
          _isLoading = false;
        });
      }
    }
  }

  Future<List<CalendarEvent>> _loadEvents(
      String startDate, String endDate) async {
    if (widget.apiClient == null) return [];
    try {
      final response = await widget.apiClient!.getCalendarEvents(
        startDate: startDate,
        endDate: endDate,
      );
      final eventsList = response["events"] as List<dynamic>? ?? [];
      return eventsList
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DailyForecast>> _loadWeather() async {
    if (widget.weatherCacheService == null) return [];
    try {
      final cached = await widget.weatherCacheService!.getCachedWeather();
      return cached?.forecast ?? [];
    } catch (e) {
      return [];
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  List<CalendarOutfit> _outfitsForDay(DateTime day) {
    return _calendarOutfits.where((co) {
      final d = co.scheduledDate;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    return _events.where((e) {
      final d = e.startTime;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  DailyForecast? _forecastForDay(DateTime day) {
    for (final f in _forecasts) {
      if (f.date.year == day.year &&
          f.date.month == day.month &&
          f.date.day == day.day) {
        return f;
      }
    }
    return null;
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  Future<void> _openAssignmentSheet(DateTime day,
      {CalendarEvent? forEvent}) async {
    final result = await showModalBottomSheet<CalendarOutfit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OutfitAssignmentBottomSheet(
        selectedDate: day,
        forEvent: forEvent,
        outfitPersistenceService: widget.outfitPersistenceService,
        outfitGenerationService: widget.outfitGenerationService,
        calendarOutfitService: widget.calendarOutfitService,
      ),
    );

    if (result != null && mounted) {
      await _loadData();
    }
  }

  Future<void> _handleEditOutfit(CalendarOutfit calendarOutfit) async {
    final result = await showModalBottomSheet<CalendarOutfit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OutfitAssignmentBottomSheet(
        selectedDate: calendarOutfit.scheduledDate,
        outfitPersistenceService: widget.outfitPersistenceService,
        outfitGenerationService: widget.outfitGenerationService,
        calendarOutfitService: widget.calendarOutfitService,
        existingCalendarOutfitId: calendarOutfit.id,
      ),
    );

    if (result != null && mounted) {
      await _loadData();
    }
  }

  Future<void> _handleRemoveOutfit(CalendarOutfit calendarOutfit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove scheduled outfit?"),
        content: const Text(
            "This will remove the outfit from this day's schedule."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.calendarOutfitService
          .deleteCalendarOutfit(calendarOutfit.id);
      if (success && mounted) {
        await _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to remove outfit. Please try again.")),
        );
      }
    }
  }

  Future<void> _handleWearToday(CalendarOutfit calendarOutfit) async {
    if (widget.apiClient == null) return;
    final outfit = calendarOutfit.outfit;
    if (outfit == null || outfit.items.isEmpty) return;

    try {
      final itemIds = outfit.items.map((i) => i.id).toList();
      await widget.apiClient!.createWearLog(
        itemIds: itemIds,
        outfitId: outfit.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Outfit logged as worn today!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to log outfit. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Plan Your Week"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Semantics(
      label: "Loading plan week data",
      child: const Center(
        child: CircularProgressIndicator(color: _accentColor),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadData,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildCalendarStrip(),
        const SizedBox(height: 8),
        Expanded(child: _buildDayDetail()),
      ],
    );
  }

  Widget _buildCalendarStrip() {
    return Semantics(
      label: "7-day calendar strip",
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(7, (index) {
            final day = _days[index];
            final isSelected = index == _selectedDayIndex;
            final isToday = _isToday(day);
            final forecast = _forecastForDay(day);
            final dayEvents = _eventsForDay(day);

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = index),
                child: Semantics(
                  label:
                      "${_dayNames[day.weekday - 1]} ${day.day}${isToday ? ', Today' : ''}${forecast != null ? ', ${forecast.highTemperature.round()}/${forecast.lowTemperature.round()} degrees' : ''}${dayEvents.isNotEmpty ? ', ${dayEvents.length} events' : ''}",
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: _accentColor, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isToday)
                          const Text(
                            "Today",
                            style: TextStyle(
                              fontSize: 9,
                              color: _accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          _dayNames[day.weekday - 1],
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? _accentColor
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${day.day}",
                          style: TextStyle(
                            fontSize: 18,
                            color: isSelected
                                ? _accentColor
                                : const Color(0xFF111827),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (forecast != null) ...[
                          Icon(
                            forecast.weatherIcon,
                            size: 16,
                            color: const Color(0xFF6B7280),
                          ),
                          Text(
                            "${forecast.highTemperature.round()}/${forecast.lowTemperature.round()}",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            "N/A",
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                        if (dayEvents.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${dayEvents.length}",
                              style: const TextStyle(
                                fontSize: 9,
                                color: _accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayDetail() {
    final day = _days[_selectedDayIndex];
    final dayEvents = _eventsForDay(day);
    final dayOutfits = _outfitsForDay(day);
    final forecast = _forecastForDay(day);
    final isToday = _isToday(day);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Semantics(
            label: "Selected day details",
            child: Text(
              "${_dayNames[day.weekday - 1]}, ${_monthName(day.month)} ${day.day}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Weather summary
          if (forecast != null)
            Row(
              children: [
                Icon(forecast.weatherIcon,
                    size: 20, color: const Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  "${forecast.weatherDescription} - ${forecast.highTemperature.round()}/${forecast.lowTemperature.round()}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            )
          else
            const Text(
              "No forecast available",
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          const SizedBox(height: 16),

          // Events list
          if (dayEvents.isNotEmpty) ...[
            Text(
              "${dayEvents.length} Event${dayEvents.length > 1 ? 's' : ''}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            ...dayEvents.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildEventRow(event),
                )),
            const SizedBox(height: 16),
          ],

          // Outfit cards
          if (dayOutfits.isNotEmpty) ...[
            const Text(
              "Scheduled Outfits",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            ...dayOutfits.map((co) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOutfitCard(co, isToday),
                )),
          ] else ...[
            _buildEmptyOutfitState(day),
          ],
        ],
      ),
    );
  }

  Widget _buildEventRow(CalendarEvent event) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(
            iconForEventType(event.eventType),
            size: 20,
            color: colorForEventType(event.eventType),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorForEventType(event.eventType).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${event.eventType[0].toUpperCase()}${event.eventType.substring(1)}",
              style: TextStyle(
                fontSize: 11,
                color: colorForEventType(event.eventType),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCard(CalendarOutfit calendarOutfit, bool isToday) {
    final outfit = calendarOutfit.outfit;

    return Semantics(
      label:
          "Scheduled outfit: ${outfit?.name ?? 'Outfit'}${isToday ? ', Wear this today available' : ''}",
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    outfit?.name ?? "Outfit",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (outfit?.occasion != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      outfit!.occasion!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (calendarOutfit.calendarEventId != null) ...[
              const SizedBox(height: 4),
              Text(
                "Event-specific outfit",
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor.withValues(alpha: 0.8),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Item thumbnails
            if (outfit != null && outfit.items.isNotEmpty)
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    ...outfit.items.take(5).map((item) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipOval(
                            child: item.photoUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: item.photoUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      width: 40,
                                      height: 40,
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 40,
                                      height: 40,
                                      color: const Color(0xFFE5E7EB),
                                      child: const Icon(Icons.image,
                                          size: 16,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: const Color(0xFFE5E7EB),
                                    child: const Icon(Icons.image,
                                        size: 16, color: Color(0xFF9CA3AF)),
                                  ),
                          ),
                        )),
                    if (outfit.items.length > 5)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "+${outfit.items.length - 5}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                if (isToday)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _handleWearToday(calendarOutfit),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text("Wear This Today"),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accentColor,
                      ),
                    ),
                  ),
                if (isToday) const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _handleEditOutfit(calendarOutfit),
                  child: const Text("Edit"),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _handleRemoveOutfit(calendarOutfit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text("Remove"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOutfitState(DateTime day) {
    return Semantics(
      label: "No outfit scheduled. Assign outfit button available.",
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.dry_cleaning,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            const Text(
              "No outfit scheduled",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _openAssignmentSheet(day),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
              ),
              child: const Text("Assign Outfit"),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return months[month - 1];
  }
}
