import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";

void main() {
  group("OutfitSuggestionItem", () {
    test("fromJson correctly parses all fields", () {
      final json = {
        "id": "item-1",
        "name": "Blue T-Shirt",
        "category": "tops",
        "color": "blue",
        "photoUrl": "https://example.com/photo.jpg",
      };

      final item = OutfitSuggestionItem.fromJson(json);

      expect(item.id, "item-1");
      expect(item.name, "Blue T-Shirt");
      expect(item.category, "tops");
      expect(item.color, "blue");
      expect(item.photoUrl, "https://example.com/photo.jpg");
    });

    test("fromJson handles null name and photoUrl", () {
      final json = {
        "id": "item-2",
        "name": null,
        "category": "bottoms",
        "color": "black",
        "photoUrl": null,
      };

      final item = OutfitSuggestionItem.fromJson(json);

      expect(item.id, "item-2");
      expect(item.name, isNull);
      expect(item.category, "bottoms");
      expect(item.color, "black");
      expect(item.photoUrl, isNull);
    });

    test("toJson serializes all fields", () {
      const item = OutfitSuggestionItem(
        id: "item-1",
        name: "Blue T-Shirt",
        category: "tops",
        color: "blue",
        photoUrl: "https://example.com/photo.jpg",
      );

      final json = item.toJson();

      expect(json["id"], "item-1");
      expect(json["name"], "Blue T-Shirt");
      expect(json["category"], "tops");
      expect(json["color"], "blue");
      expect(json["photoUrl"], "https://example.com/photo.jpg");
    });
  });

  group("OutfitSuggestion", () {
    test("fromJson correctly parses all fields", () {
      final json = {
        "id": "suggestion-1",
        "name": "Casual Blue Look",
        "items": [
          {
            "id": "item-1",
            "name": "Blue T-Shirt",
            "category": "tops",
            "color": "blue",
            "photoUrl": "https://example.com/photo1.jpg",
          },
          {
            "id": "item-2",
            "name": "Dark Jeans",
            "category": "bottoms",
            "color": "navy",
            "photoUrl": "https://example.com/photo2.jpg",
          },
        ],
        "explanation": "A comfortable outfit for a mild spring day.",
        "occasion": "everyday",
      };

      final suggestion = OutfitSuggestion.fromJson(json);

      expect(suggestion.id, "suggestion-1");
      expect(suggestion.name, "Casual Blue Look");
      expect(suggestion.items.length, 2);
      expect(suggestion.items[0].id, "item-1");
      expect(suggestion.items[1].id, "item-2");
      expect(suggestion.explanation,
          "A comfortable outfit for a mild spring day.");
      expect(suggestion.occasion, "everyday");
    });

    test("toJson serializes all fields", () {
      const suggestion = OutfitSuggestion(
        id: "suggestion-1",
        name: "Casual Blue Look",
        items: [
          OutfitSuggestionItem(
            id: "item-1",
            name: "Blue T-Shirt",
            category: "tops",
            color: "blue",
            photoUrl: "https://example.com/photo1.jpg",
          ),
        ],
        explanation: "A comfortable outfit.",
        occasion: "everyday",
      );

      final json = suggestion.toJson();

      expect(json["id"], "suggestion-1");
      expect(json["name"], "Casual Blue Look");
      expect(json["items"], isA<List>());
      expect((json["items"] as List).length, 1);
      expect(json["explanation"], "A comfortable outfit.");
      expect(json["occasion"], "everyday");
    });

    test("round-trip: toJson then fromJson returns equivalent object", () {
      const original = OutfitSuggestion(
        id: "suggestion-1",
        name: "Smart Spring",
        items: [
          OutfitSuggestionItem(
            id: "item-1",
            name: "White Shirt",
            category: "tops",
            color: "white",
            photoUrl: "https://example.com/photo.jpg",
          ),
          OutfitSuggestionItem(
            id: "item-2",
            name: "Chinos",
            category: "bottoms",
            color: "beige",
            photoUrl: null,
          ),
        ],
        explanation: "Perfect for the office.",
        occasion: "work",
      );

      final json = original.toJson();
      final restored = OutfitSuggestion.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.items.length, original.items.length);
      expect(restored.items[0].id, original.items[0].id);
      expect(restored.items[1].photoUrl, isNull);
      expect(restored.explanation, original.explanation);
      expect(restored.occasion, original.occasion);
    });
  });

  group("OutfitGenerationResult", () {
    test("fromJson parses suggestions array and generatedAt", () {
      final json = {
        "suggestions": [
          {
            "id": "s1",
            "name": "Outfit 1",
            "items": [
              {"id": "i1", "name": "Item 1", "category": "tops", "color": "blue", "photoUrl": null},
            ],
            "explanation": "Good outfit.",
            "occasion": "everyday",
          },
          {
            "id": "s2",
            "name": "Outfit 2",
            "items": [
              {"id": "i2", "name": "Item 2", "category": "bottoms", "color": "black", "photoUrl": null},
            ],
            "explanation": "Another good outfit.",
            "occasion": "work",
          },
        ],
        "generatedAt": "2026-03-14T10:30:00.000Z",
      };

      final result = OutfitGenerationResult.fromJson(json);

      expect(result.suggestions.length, 2);
      expect(result.suggestions[0].name, "Outfit 1");
      expect(result.suggestions[1].name, "Outfit 2");
      expect(result.generatedAt.year, 2026);
      expect(result.generatedAt.month, 3);
      expect(result.generatedAt.day, 14);
    });
  });
}
