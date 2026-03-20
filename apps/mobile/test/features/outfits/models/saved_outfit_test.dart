import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/outfits/models/saved_outfit.dart";

void main() {
  group("SavedOutfit.fromJson", () {
    test("correctly parses all fields", () {
      final json = {
        "id": "outfit-1",
        "name": "Spring Casual",
        "explanation": "Perfect for spring",
        "occasion": "everyday",
        "source": "ai",
        "isFavorite": true,
        "createdAt": "2026-03-15T10:00:00Z",
        "updatedAt": "2026-03-15T11:00:00Z",
        "items": [
          {
            "id": "item-1",
            "name": "Shirt",
            "category": "tops",
            "color": "blue",
            "photoUrl": "http://example.com/photo.jpg",
          }
        ],
      };

      final outfit = SavedOutfit.fromJson(json);

      expect(outfit.id, "outfit-1");
      expect(outfit.name, "Spring Casual");
      expect(outfit.explanation, "Perfect for spring");
      expect(outfit.occasion, "everyday");
      expect(outfit.source, "ai");
      expect(outfit.isFavorite, true);
      expect(outfit.createdAt, DateTime.parse("2026-03-15T10:00:00Z"));
      expect(outfit.updatedAt, DateTime.parse("2026-03-15T11:00:00Z"));
      expect(outfit.items.length, 1);
      expect(outfit.items[0].id, "item-1");
      expect(outfit.items[0].name, "Shirt");
    });

    test("handles null name, explanation, occasion", () {
      final json = {
        "id": "outfit-1",
        "name": null,
        "explanation": null,
        "occasion": null,
        "createdAt": "2026-03-15T10:00:00Z",
        "items": [],
      };

      final outfit = SavedOutfit.fromJson(json);

      expect(outfit.name, isNull);
      expect(outfit.explanation, isNull);
      expect(outfit.occasion, isNull);
    });

    test("defaults source to 'ai' when missing", () {
      final json = {
        "id": "outfit-1",
        "createdAt": "2026-03-15T10:00:00Z",
        "items": [],
      };

      final outfit = SavedOutfit.fromJson(json);

      expect(outfit.source, "ai");
    });

    test("defaults isFavorite to false when missing", () {
      final json = {
        "id": "outfit-1",
        "createdAt": "2026-03-15T10:00:00Z",
        "items": [],
      };

      final outfit = SavedOutfit.fromJson(json);

      expect(outfit.isFavorite, false);
    });

    test("handles empty items list", () {
      final json = {
        "id": "outfit-1",
        "createdAt": "2026-03-15T10:00:00Z",
        "items": [],
      };

      final outfit = SavedOutfit.fromJson(json);

      expect(outfit.items, isEmpty);
    });

    test("handles missing items key", () {
      final json = {
        "id": "outfit-1",
        "createdAt": "2026-03-15T10:00:00Z",
      };

      final outfit = SavedOutfit.fromJson(json);

      expect(outfit.items, isEmpty);
    });
  });

  group("SavedOutfit.copyWith", () {
    test("creates a copy with toggled isFavorite", () {
      final outfit = SavedOutfit(
        id: "outfit-1",
        name: "Test",
        isFavorite: false,
        createdAt: DateTime(2026, 3, 15),
      );

      final copy = outfit.copyWith(isFavorite: true);

      expect(copy.id, "outfit-1");
      expect(copy.name, "Test");
      expect(copy.isFavorite, true);
    });

    test("preserves all fields when no override provided", () {
      final outfit = SavedOutfit(
        id: "outfit-1",
        name: "Test",
        explanation: "Explanation",
        occasion: "work",
        source: "manual",
        isFavorite: true,
        createdAt: DateTime(2026, 3, 15),
      );

      final copy = outfit.copyWith();

      expect(copy.id, outfit.id);
      expect(copy.name, outfit.name);
      expect(copy.explanation, outfit.explanation);
      expect(copy.occasion, outfit.occasion);
      expect(copy.source, outfit.source);
      expect(copy.isFavorite, outfit.isFavorite);
    });
  });

  group("SavedOutfit.relativeDate", () {
    test("returns 'Today' for today's date", () {
      final outfit = SavedOutfit(
        id: "outfit-1",
        createdAt: DateTime.now(),
      );

      expect(outfit.relativeDate, "Today");
    });

    test("returns 'Yesterday' for yesterday", () {
      final outfit = SavedOutfit(
        id: "outfit-1",
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(outfit.relativeDate, "Yesterday");
    });

    test("returns 'N days ago' for dates within 7 days", () {
      final outfit = SavedOutfit(
        id: "outfit-1",
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(outfit.relativeDate, "3 days ago");
    });

    test("returns formatted date for older dates", () {
      final outfit = SavedOutfit(
        id: "outfit-1",
        createdAt: DateTime(2026, 3, 1),
      );

      expect(outfit.relativeDate, "Mar 1");
    });
  });
}
