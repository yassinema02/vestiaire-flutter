import "package:intl/intl.dart";

import "outfit_suggestion.dart";

/// Model representing a persisted outfit from the database.
///
/// Unlike [OutfitSuggestion] which represents ephemeral AI-generated suggestions,
/// [SavedOutfit] represents outfits that have been saved (both AI and manual).
/// Reuses [OutfitSuggestionItem] for item metadata since the shape is identical.
class SavedOutfit {
  const SavedOutfit({
    required this.id,
    this.name,
    this.explanation,
    this.occasion,
    this.source = "ai",
    this.isFavorite = false,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String? name;
  final String? explanation;
  final String? occasion;
  final String source;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OutfitSuggestionItem> items;

  factory SavedOutfit.fromJson(Map<String, dynamic> json) {
    return SavedOutfit(
      id: json["id"] as String,
      name: json["name"] as String?,
      explanation: json["explanation"] as String?,
      occasion: json["occasion"] as String?,
      source: (json["source"] as String?) ?? "ai",
      isFavorite: (json["isFavorite"] as bool?) ?? false,
      createdAt: DateTime.parse(json["createdAt"] as String),
      updatedAt: json["updatedAt"] != null
          ? DateTime.parse(json["updatedAt"] as String)
          : null,
      items: (json["items"] as List<dynamic>? ?? [])
          .map((e) => OutfitSuggestionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Create a copy with optional field overrides.
  SavedOutfit copyWith({bool? isFavorite}) {
    return SavedOutfit(
      id: id,
      name: name,
      explanation: explanation,
      occasion: occasion,
      source: source,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items,
    );
  }

  /// Returns a human-readable relative date string.
  ///
  /// "Today" if created today, "Yesterday" if yesterday,
  /// "N days ago" if within 7 days, or "MMM d" format otherwise.
  String get relativeDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final difference = today.difference(created).inDays;

    if (difference == 0) return "Today";
    if (difference == 1) return "Yesterday";
    if (difference < 7) return "$difference days ago";
    return DateFormat("MMM d").format(createdAt);
  }
}
