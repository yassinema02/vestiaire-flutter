/// Fixed taxonomy constants for clothing item categorization.
///
/// These values mirror the API taxonomy defined in
/// `apps/api/src/modules/ai/taxonomy.js`. They are used by the
/// TagCloud widget and ReviewItemScreen for constrained selection.

const List<String> validCategories = [
  "tops", "bottoms", "dresses", "outerwear", "shoes", "bags", "accessories",
  "activewear", "swimwear", "underwear", "sleepwear", "suits", "other",
];

const List<String> validColors = [
  "black", "white", "gray", "navy", "blue", "light-blue", "red", "burgundy",
  "pink", "orange", "yellow", "green", "olive", "teal", "purple", "beige",
  "brown", "tan", "cream", "gold", "silver", "multicolor", "unknown",
];

const List<String> validPatterns = [
  "solid", "striped", "plaid", "floral", "polka-dot", "geometric", "abstract",
  "animal-print", "camouflage", "paisley", "tie-dye", "color-block", "other",
];

const List<String> validMaterials = [
  "cotton", "polyester", "silk", "wool", "linen", "denim", "leather", "suede",
  "cashmere", "nylon", "velvet", "chiffon", "satin", "fleece", "knit", "mesh",
  "tweed", "corduroy", "synthetic-blend", "unknown",
];

const List<String> validStyles = [
  "casual", "formal", "smart-casual", "business", "sporty", "bohemian",
  "streetwear", "minimalist", "vintage", "classic", "trendy", "preppy", "other",
];

const List<String> validSeasons = [
  "spring", "summer", "fall", "winter", "all",
];

const List<String> validOccasions = [
  "everyday", "work", "formal", "party", "date-night", "outdoor", "sport",
  "beach", "travel", "lounge",
];

const List<String> validCurrencies = ["GBP", "EUR", "USD"];

/// Display-friendly labels for taxonomy values.
///
/// Converts hyphenated lowercase values to title case.
/// E.g., 'light-blue' -> 'Light Blue', 'smart-casual' -> 'Smart Casual'.
String taxonomyDisplayLabel(String value) {
  return value
      .split("-")
      .map((word) => word.isEmpty
          ? word
          : "${word[0].toUpperCase()}${word.substring(1)}")
      .join(" ");
}
