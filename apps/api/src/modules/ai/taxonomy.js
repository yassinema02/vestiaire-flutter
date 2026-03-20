/**
 * Shared taxonomy constants for clothing item categorization.
 *
 * These constants define the valid values for all taxonomy fields.
 * Used by both the AI categorization service and the manual editing
 * validation in the items service.
 */

export const VALID_CATEGORIES = [
  "tops", "bottoms", "dresses", "outerwear", "shoes", "bags", "accessories",
  "activewear", "swimwear", "underwear", "sleepwear", "suits", "other"
];

export const VALID_COLORS = [
  "black", "white", "gray", "navy", "blue", "light-blue", "red", "burgundy",
  "pink", "orange", "yellow", "green", "olive", "teal", "purple", "beige",
  "brown", "tan", "cream", "gold", "silver", "multicolor", "unknown"
];

export const VALID_PATTERNS = [
  "solid", "striped", "plaid", "floral", "polka-dot", "geometric", "abstract",
  "animal-print", "camouflage", "paisley", "tie-dye", "color-block", "other"
];

export const VALID_MATERIALS = [
  "cotton", "polyester", "silk", "wool", "linen", "denim", "leather", "suede",
  "cashmere", "nylon", "velvet", "chiffon", "satin", "fleece", "knit", "mesh",
  "tweed", "corduroy", "synthetic-blend", "unknown"
];

export const VALID_STYLES = [
  "casual", "formal", "smart-casual", "business", "sporty", "bohemian",
  "streetwear", "minimalist", "vintage", "classic", "trendy", "preppy", "other"
];

export const VALID_SEASONS = ["spring", "summer", "fall", "winter", "all"];

export const VALID_OCCASIONS = [
  "everyday", "work", "formal", "party", "date-night", "outdoor", "sport",
  "beach", "travel", "lounge"
];

export const VALID_CURRENCIES = ["GBP", "EUR", "USD"];
