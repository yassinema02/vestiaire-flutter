import "usage_info.dart";
import "usage_limit_result.dart";

/// Model representing a single item within an outfit suggestion.
class OutfitSuggestionItem {
  const OutfitSuggestionItem({
    required this.id,
    this.name,
    this.category,
    this.color,
    this.photoUrl,
  });

  final String id;
  final String? name;
  final String? category;
  final String? color;
  final String? photoUrl;

  factory OutfitSuggestionItem.fromJson(Map<String, dynamic> json) {
    return OutfitSuggestionItem(
      id: json["id"] as String,
      name: json["name"] as String?,
      category: json["category"] as String?,
      color: json["color"] as String?,
      photoUrl: json["photoUrl"] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "category": category,
        "color": color,
        "photoUrl": photoUrl,
      };
}

/// Model representing an AI-generated outfit suggestion.
class OutfitSuggestion {
  const OutfitSuggestion({
    required this.id,
    required this.name,
    required this.items,
    required this.explanation,
    required this.occasion,
  });

  final String id;
  final String name;
  final List<OutfitSuggestionItem> items;
  final String explanation;
  final String occasion;

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) {
    final itemsList = (json["items"] as List<dynamic>)
        .map((e) => OutfitSuggestionItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return OutfitSuggestion(
      id: json["id"] as String,
      name: json["name"] as String,
      items: itemsList,
      explanation: json["explanation"] as String,
      occasion: json["occasion"] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "items": items.map((e) => e.toJson()).toList(),
        "explanation": explanation,
        "occasion": occasion,
      };
}

/// Model representing the full result of an outfit generation API call.
class OutfitGenerationResult {
  const OutfitGenerationResult({
    required this.suggestions,
    required this.generatedAt,
    this.usage,
  });

  final List<OutfitSuggestion> suggestions;
  final DateTime generatedAt;
  final UsageInfo? usage;

  factory OutfitGenerationResult.fromJson(Map<String, dynamic> json) {
    final suggestionsList = (json["suggestions"] as List<dynamic>)
        .map((e) => OutfitSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
    UsageInfo? usage;
    if (json["usage"] != null) {
      usage = UsageInfo.fromJson(json["usage"] as Map<String, dynamic>);
    }
    return OutfitGenerationResult(
      suggestions: suggestionsList,
      generatedAt: DateTime.parse(json["generatedAt"] as String),
      usage: usage,
    );
  }
}

/// Response wrapper for outfit generation that distinguishes between
/// success, rate-limit reached, and generic error states.
class OutfitGenerationResponse {
  const OutfitGenerationResponse({
    this.result,
    this.limitReached,
    this.isError = false,
  });

  /// Non-null on successful generation.
  final OutfitGenerationResult? result;

  /// Non-null when the daily limit has been reached (429 response).
  final UsageLimitReachedResult? limitReached;

  /// True when a generic (non-429) error occurred.
  final bool isError;
}
