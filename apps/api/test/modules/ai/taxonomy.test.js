import assert from "node:assert/strict";
import test from "node:test";
import {
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_PATTERNS,
  VALID_MATERIALS,
  VALID_STYLES,
  VALID_SEASONS,
  VALID_OCCASIONS,
  VALID_CURRENCIES
} from "../../../src/modules/ai/taxonomy.js";

test("taxonomy exports VALID_CATEGORIES with all expected values", () => {
  assert.ok(Array.isArray(VALID_CATEGORIES));
  assert.equal(VALID_CATEGORIES.length, 13);
  assert.ok(VALID_CATEGORIES.includes("tops"));
  assert.ok(VALID_CATEGORIES.includes("bottoms"));
  assert.ok(VALID_CATEGORIES.includes("dresses"));
  assert.ok(VALID_CATEGORIES.includes("outerwear"));
  assert.ok(VALID_CATEGORIES.includes("shoes"));
  assert.ok(VALID_CATEGORIES.includes("bags"));
  assert.ok(VALID_CATEGORIES.includes("accessories"));
  assert.ok(VALID_CATEGORIES.includes("activewear"));
  assert.ok(VALID_CATEGORIES.includes("swimwear"));
  assert.ok(VALID_CATEGORIES.includes("underwear"));
  assert.ok(VALID_CATEGORIES.includes("sleepwear"));
  assert.ok(VALID_CATEGORIES.includes("suits"));
  assert.ok(VALID_CATEGORIES.includes("other"));
});

test("taxonomy exports VALID_COLORS with all expected values", () => {
  assert.ok(Array.isArray(VALID_COLORS));
  assert.equal(VALID_COLORS.length, 23);
  assert.ok(VALID_COLORS.includes("black"));
  assert.ok(VALID_COLORS.includes("white"));
  assert.ok(VALID_COLORS.includes("light-blue"));
  assert.ok(VALID_COLORS.includes("multicolor"));
  assert.ok(VALID_COLORS.includes("unknown"));
});

test("taxonomy exports VALID_PATTERNS with all expected values", () => {
  assert.ok(Array.isArray(VALID_PATTERNS));
  assert.equal(VALID_PATTERNS.length, 13);
  assert.ok(VALID_PATTERNS.includes("solid"));
  assert.ok(VALID_PATTERNS.includes("polka-dot"));
  assert.ok(VALID_PATTERNS.includes("animal-print"));
  assert.ok(VALID_PATTERNS.includes("color-block"));
  assert.ok(VALID_PATTERNS.includes("other"));
});

test("taxonomy exports VALID_MATERIALS with all expected values", () => {
  assert.ok(Array.isArray(VALID_MATERIALS));
  assert.equal(VALID_MATERIALS.length, 20);
  assert.ok(VALID_MATERIALS.includes("cotton"));
  assert.ok(VALID_MATERIALS.includes("cashmere"));
  assert.ok(VALID_MATERIALS.includes("synthetic-blend"));
  assert.ok(VALID_MATERIALS.includes("unknown"));
});

test("taxonomy exports VALID_STYLES with all expected values", () => {
  assert.ok(Array.isArray(VALID_STYLES));
  assert.equal(VALID_STYLES.length, 13);
  assert.ok(VALID_STYLES.includes("casual"));
  assert.ok(VALID_STYLES.includes("smart-casual"));
  assert.ok(VALID_STYLES.includes("other"));
});

test("taxonomy exports VALID_SEASONS with all expected values", () => {
  assert.ok(Array.isArray(VALID_SEASONS));
  assert.equal(VALID_SEASONS.length, 5);
  assert.ok(VALID_SEASONS.includes("spring"));
  assert.ok(VALID_SEASONS.includes("summer"));
  assert.ok(VALID_SEASONS.includes("fall"));
  assert.ok(VALID_SEASONS.includes("winter"));
  assert.ok(VALID_SEASONS.includes("all"));
});

test("taxonomy exports VALID_OCCASIONS with all expected values", () => {
  assert.ok(Array.isArray(VALID_OCCASIONS));
  assert.equal(VALID_OCCASIONS.length, 10);
  assert.ok(VALID_OCCASIONS.includes("everyday"));
  assert.ok(VALID_OCCASIONS.includes("work"));
  assert.ok(VALID_OCCASIONS.includes("date-night"));
  assert.ok(VALID_OCCASIONS.includes("lounge"));
});

test("taxonomy exports VALID_CURRENCIES with GBP, EUR, USD", () => {
  assert.ok(Array.isArray(VALID_CURRENCIES));
  assert.equal(VALID_CURRENCIES.length, 3);
  assert.ok(VALID_CURRENCIES.includes("GBP"));
  assert.ok(VALID_CURRENCIES.includes("EUR"));
  assert.ok(VALID_CURRENCIES.includes("USD"));
});
