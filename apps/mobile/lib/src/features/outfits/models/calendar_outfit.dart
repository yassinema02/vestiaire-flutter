import "saved_outfit.dart";

/// Model representing a scheduled outfit assignment on the calendar.
///
/// Links an [SavedOutfit] to a specific date, optionally associated with
/// a calendar event. Used by the Plan Week feature (Story 12.2).
class CalendarOutfit {
  const CalendarOutfit({
    required this.id,
    required this.outfitId,
    this.calendarEventId,
    required this.scheduledDate,
    this.notes,
    this.outfit,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String outfitId;
  final String? calendarEventId;
  final DateTime scheduledDate;
  final String? notes;
  final SavedOutfit? outfit;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory CalendarOutfit.fromJson(Map<String, dynamic> json) {
    SavedOutfit? outfit;
    if (json["outfit"] != null && json["outfit"] is Map<String, dynamic>) {
      final outfitJson = json["outfit"] as Map<String, dynamic>;
      // Build a SavedOutfit-compatible JSON
      outfit = SavedOutfit.fromJson(<String, dynamic>{
        "id": outfitJson["id"] as String,
        "name": outfitJson["name"],
        "occasion": outfitJson["occasion"],
        "source": outfitJson["source"] ?? "ai",
        "isFavorite": false,
        "createdAt": json["createdAt"] ?? DateTime.now().toIso8601String(),
        "items": outfitJson["items"] ?? [],
      });
    }

    return CalendarOutfit(
      id: json["id"] as String,
      outfitId: json["outfitId"] as String,
      calendarEventId: json["calendarEventId"] as String?,
      scheduledDate: _parseDate(json["scheduledDate"]),
      notes: json["notes"] as String?,
      outfit: outfit,
      createdAt: DateTime.parse(json["createdAt"] as String),
      updatedAt: json["updatedAt"] != null
          ? DateTime.parse(json["updatedAt"] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "outfitId": outfitId,
        "calendarEventId": calendarEventId,
        "scheduledDate": _formatDate(scheduledDate),
        "notes": notes,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt?.toIso8601String(),
      };

  /// Parse a date that might be YYYY-MM-DD or a full ISO string.
  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      // Handle YYYY-MM-DD format
      if (value.length == 10 && value.contains("-")) {
        return DateTime.parse("${value}T00:00:00.000");
      }
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  /// Format a DateTime to YYYY-MM-DD for API requests.
  static String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
