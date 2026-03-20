import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/calendar/calendar_event.dart";
import "../../../core/weather/outfit_context.dart";
import "../../../core/weather/weather_clothing_mapper.dart";
import "../models/calendar_outfit.dart";
import "../models/outfit_suggestion.dart";
import "../models/saved_outfit.dart";
import "../services/calendar_outfit_service.dart";
import "../services/outfit_generation_service.dart";
import "../services/outfit_persistence_service.dart";

/// Bottom sheet for assigning an outfit to a calendar day.
///
/// Offers two tabs:
/// 1. "Saved Outfits" - pick from existing saved outfits
/// 2. "Generate New" - trigger AI outfit generation for the day's context
class OutfitAssignmentBottomSheet extends StatefulWidget {
  const OutfitAssignmentBottomSheet({
    required this.selectedDate,
    this.forEvent,
    required this.outfitPersistenceService,
    required this.outfitGenerationService,
    required this.calendarOutfitService,
    this.existingCalendarOutfitId,
    super.key,
  });

  final DateTime selectedDate;
  final CalendarEvent? forEvent;
  final OutfitPersistenceService outfitPersistenceService;
  final OutfitGenerationService outfitGenerationService;
  final CalendarOutfitService calendarOutfitService;
  /// If set, this is an edit operation and the existing calendar outfit
  /// will be updated instead of creating a new one.
  final String? existingCalendarOutfitId;

  @override
  State<OutfitAssignmentBottomSheet> createState() =>
      _OutfitAssignmentBottomSheetState();
}

class _OutfitAssignmentBottomSheetState
    extends State<OutfitAssignmentBottomSheet>
    with SingleTickerProviderStateMixin {
  static const _accentColor = Color(0xFF4F46E5);

  late TabController _tabController;

  List<SavedOutfit>? _savedOutfits;
  bool _loadingSaved = true;
  List<OutfitSuggestion>? _generatedOutfits;
  bool _generating = false;
  String? _error;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedOutfits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedOutfits() async {
    setState(() => _loadingSaved = true);
    try {
      final outfits = await widget.outfitPersistenceService.listOutfits();
      if (mounted) {
        setState(() {
          _savedOutfits = outfits;
          _loadingSaved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savedOutfits = [];
          _loadingSaved = false;
        });
      }
    }
  }

  Future<void> _generateOutfits() async {
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      // Build a minimal OutfitContext for the selected date
      final date = widget.selectedDate;
      final outfitCtx = OutfitContext(
        temperature: 20,
        feelsLike: 20,
        weatherCode: 0,
        weatherDescription: "Unknown",
        clothingConstraints: const ClothingConstraints(),
        locationName: "Unknown",
        date: date,
        dayOfWeek: OutfitContext.deriveDayOfWeek(date),
        season: OutfitContext.deriveSeason(date),
        temperatureCategory: "mild",
      );
      final response =
          await widget.outfitGenerationService.generateOutfits(outfitCtx);
      if (mounted) {
        setState(() {
          _generatedOutfits = response.result?.suggestions ?? [];
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to generate outfits";
          _generating = false;
        });
      }
    }
  }

  Future<void> _assignSavedOutfit(SavedOutfit outfit) async {
    setState(() {
      _assigning = true;
      _error = null;
    });

    try {
      final dateStr =
          "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

      CalendarOutfit? result;
      if (widget.existingCalendarOutfitId != null) {
        result = await widget.calendarOutfitService.updateCalendarOutfit(
          widget.existingCalendarOutfitId!,
          outfitId: outfit.id,
          calendarEventId: widget.forEvent?.id,
        );
      } else {
        result = await widget.calendarOutfitService.createCalendarOutfit(
          outfitId: outfit.id,
          calendarEventId: widget.forEvent?.id,
          scheduledDate: dateStr,
        );
      }

      if (result != null && mounted) {
        Navigator.of(context).pop(result);
      } else if (mounted) {
        setState(() {
          _error = "Failed to assign outfit";
          _assigning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to assign outfit";
          _assigning = false;
        });
      }
    }
  }

  Future<void> _assignGeneratedOutfit(OutfitSuggestion suggestion) async {
    setState(() {
      _assigning = true;
      _error = null;
    });

    try {
      // First save the generated outfit
      final saveResult =
          await widget.outfitPersistenceService.saveOutfit(suggestion);
      if (saveResult == null) {
        if (mounted) {
          setState(() {
            _error = "Failed to save generated outfit";
            _assigning = false;
          });
        }
        return;
      }

      final savedOutfitId = saveResult["outfit"]?["id"] as String? ??
          saveResult["id"] as String?;
      if (savedOutfitId == null) {
        if (mounted) {
          setState(() {
            _error = "Failed to save generated outfit";
            _assigning = false;
          });
        }
        return;
      }

      // Then assign it to the calendar
      final dateStr =
          "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

      CalendarOutfit? result;
      if (widget.existingCalendarOutfitId != null) {
        result = await widget.calendarOutfitService.updateCalendarOutfit(
          widget.existingCalendarOutfitId!,
          outfitId: savedOutfitId,
          calendarEventId: widget.forEvent?.id,
        );
      } else {
        result = await widget.calendarOutfitService.createCalendarOutfit(
          outfitId: savedOutfitId,
          calendarEventId: widget.forEvent?.id,
          scheduledDate: dateStr,
        );
      }

      if (result != null && mounted) {
        Navigator.of(context).pop(result);
      } else if (mounted) {
        setState(() {
          _error = "Failed to assign outfit";
          _assigning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to assign outfit";
          _assigning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.existingCalendarOutfitId != null
                      ? "Replace Outfit"
                      : "Assign Outfit",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              if (_assigning)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  ),
                ),
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: _accentColor,
                labelColor: _accentColor,
                unselectedLabelColor: const Color(0xFF6B7280),
                tabs: const [
                  Tab(text: "Saved Outfits"),
                  Tab(text: "Generate New"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSavedOutfitsTab(scrollController),
                    _buildGenerateTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedOutfitsTab(ScrollController scrollController) {
    if (_loadingSaved) {
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    if (_savedOutfits == null || _savedOutfits!.isEmpty) {
      return const Center(
        child: Text(
          "No saved outfits available",
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _savedOutfits!.length,
      itemBuilder: (context, index) {
        final outfit = _savedOutfits![index];
        return _buildSavedOutfitRow(outfit);
      },
    );
  }

  Widget _buildSavedOutfitRow(SavedOutfit outfit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            // Item thumbnails
            SizedBox(
              width: 80,
              height: 40,
              child: Row(
                children: outfit.items.take(2).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: item.photoUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFFE5E7EB)),
                              errorWidget: (_, __, ___) => Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFFE5E7EB)),
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              color: const Color(0xFFE5E7EB)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.name ?? "Untitled Outfit",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (outfit.occasion != null)
                    Text(
                      outfit.occasion!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _assigning ? null : () => _assignSavedOutfit(outfit),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text("Select", style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateTab(ScrollController scrollController) {
    if (_generating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _accentColor),
            SizedBox(height: 16),
            Text(
              "Generating outfit suggestions...",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    if (_generatedOutfits == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 48, color: _accentColor),
              const SizedBox(height: 16),
              const Text(
                "Generate AI outfit suggestions for this day",
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _generateOutfits,
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                ),
                child: const Text("Generate Outfits"),
              ),
            ],
          ),
        ),
      );
    }

    if (_generatedOutfits!.isEmpty) {
      return const Center(
        child: Text(
          "No outfit suggestions generated",
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _generatedOutfits!.length,
      itemBuilder: (context, index) {
        final suggestion = _generatedOutfits![index];
        return _buildGeneratedOutfitRow(suggestion);
      },
    );
  }

  Widget _buildGeneratedOutfitRow(OutfitSuggestion suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed:
                      _assigning ? null : () => _assignGeneratedOutfit(suggestion),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child:
                      const Text("Assign This", style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              suggestion.explanation,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Row(
                children: suggestion.items.take(5).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: item.photoUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFFE5E7EB)),
                              errorWidget: (_, __, ___) => Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFFE5E7EB)),
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              color: const Color(0xFFE5E7EB)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
