/**
 * Categorization service using Gemini 2.0 Flash via Vertex AI.
 *
 * Analyzes clothing images to extract structured metadata: category, color,
 * secondary_colors, pattern, material, style, season, and occasion.
 * Validates all AI output against a fixed taxonomy with safe defaults.
 */

import fs from "node:fs";
import {
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_PATTERNS,
  VALID_MATERIALS,
  VALID_STYLES,
  VALID_SEASONS,
  VALID_OCCASIONS
} from "./taxonomy.js";

// Re-export for backward compatibility
export {
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_PATTERNS,
  VALID_MATERIALS,
  VALID_STYLES,
  VALID_SEASONS,
  VALID_OCCASIONS
};

const CATEGORIZATION_MODEL = "gemini-2.0-flash";

const CATEGORIZATION_PROMPT = `Analyze this clothing item image and extract the following metadata as JSON.
Return ONLY valid JSON with these exact keys:
{
  "category": "one of: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other",
  "color": "primary color, one of: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown",
  "secondary_colors": ["array of additional colors from the same color list, empty if solid color"],
  "pattern": "one of: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other",
  "material": "best guess, one of: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown",
  "style": "one of: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other",
  "season": ["array of suitable seasons: spring, summer, fall, winter, all"],
  "occasion": ["array of suitable occasions: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge"]
}`;

// Safe defaults for invalid/missing AI output
const DEFAULTS = {
  category: "other",
  color: "unknown",
  pattern: "solid",
  material: "unknown",
  style: "casual",
  season: ["all"],
  occasion: ["everyday"]
};

/**
 * Validate a single value against a valid set. Returns the value if valid, default otherwise.
 */
function validateSingle(value, validSet, defaultValue) {
  if (typeof value === "string" && validSet.includes(value)) {
    return value;
  }
  return defaultValue;
}

/**
 * Validate an array of values against a valid set. Filters to only valid values.
 * Returns default array if no valid values remain.
 */
function validateArray(values, validSet, defaultValues) {
  if (!Array.isArray(values)) {
    return defaultValues;
  }
  const filtered = values.filter((v) => typeof v === "string" && validSet.includes(v));
  return filtered.length > 0 ? filtered : defaultValues;
}

/**
 * Validate all taxonomy fields from the AI response against the fixed taxonomy.
 */
export function validateTaxonomy(parsed) {
  return {
    category: validateSingle(parsed.category, VALID_CATEGORIES, DEFAULTS.category),
    color: validateSingle(parsed.color, VALID_COLORS, DEFAULTS.color),
    secondaryColors: validateArray(parsed.secondary_colors, VALID_COLORS, []),
    pattern: validateSingle(parsed.pattern, VALID_PATTERNS, DEFAULTS.pattern),
    material: validateSingle(parsed.material, VALID_MATERIALS, DEFAULTS.material),
    style: validateSingle(parsed.style, VALID_STYLES, DEFAULTS.style),
    season: validateArray(parsed.season, VALID_SEASONS, DEFAULTS.season),
    occasion: validateArray(parsed.occasion, VALID_OCCASIONS, DEFAULTS.occasion)
  };
}

/**
 * Read image data from a URL or local file path.
 */
async function readImageData(imageUrl) {
  if (imageUrl.startsWith("/") || imageUrl.startsWith("file://")) {
    const filePath = imageUrl.replace("file://", "");
    return fs.readFileSync(filePath);
  }

  if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://")) {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Failed to download image: ${response.status} ${response.statusText}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  throw new Error(`Unsupported image URL format: ${imageUrl}`);
}

/**
 * Estimate the cost of a Gemini API call based on token usage.
 * Gemini 2.0 Flash pricing: ~$0.075 per 1M input tokens, ~$0.30 per 1M output tokens.
 */
function estimateCost(usageMetadata) {
  const inputTokens = usageMetadata?.promptTokenCount ?? 0;
  const outputTokens = usageMetadata?.candidatesTokenCount ?? 0;

  const inputCost = (inputTokens / 1_000_000) * 0.075;
  const outputCost = (outputTokens / 1_000_000) * 0.30;

  return inputCost + outputCost;
}

/**
 * @param {object} options
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.itemRepo - Item repository with updateItem method.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 */
export function createCategorizationService({
  geminiClient,
  itemRepo,
  aiUsageLogRepo
}) {
  return {
    /**
     * Categorize a clothing item using Gemini vision analysis.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.itemId - The item's UUID.
     * @param {string} params.imageUrl - URL or path of the image to analyze.
     * @returns {Promise<{ status: string }>}
     */
    async categorizeItem(authContext, { itemId, imageUrl }) {
      if (!geminiClient.isAvailable()) {
        console.warn("[categorization] Gemini client not available. Skipping categorization.");
        return { status: "skipped" };
      }

      const startTime = Date.now();

      try {
        // Step 1: Read the image data
        const imageData = await readImageData(imageUrl);

        // Step 2: Call Gemini with JSON mode for structured output
        const model = await geminiClient.getGenerativeModel(CATEGORIZATION_MODEL);
        const result = await model.generateContent({
          contents: [
            {
              role: "user",
              parts: [
                {
                  inlineData: {
                    mimeType: "image/jpeg",
                    data: imageData.toString("base64")
                  }
                },
                { text: CATEGORIZATION_PROMPT }
              ]
            }
          ],
          generationConfig: { responseMimeType: "application/json" }
        });

        const response = result.response;
        const latencyMs = Date.now() - startTime;

        // Step 3: Parse the JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        // Step 4: Validate against taxonomy with safe defaults
        const validated = validateTaxonomy(parsed);

        // Step 5: Update the item record with categorization data
        await itemRepo.updateItem(authContext, itemId, {
          category: validated.category,
          color: validated.color,
          secondary_colors: validated.secondaryColors,
          pattern: validated.pattern,
          material: validated.material,
          style: validated.style,
          season: validated.season,
          occasion: validated.occasion,
          categorizationStatus: "completed"
        });

        // Step 6: Log the AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        await aiUsageLogRepo.logUsage(authContext, {
          feature: "categorization",
          model: CATEGORIZATION_MODEL,
          inputTokens: usageMetadata.promptTokenCount ?? null,
          outputTokens: usageMetadata.candidatesTokenCount ?? null,
          latencyMs,
          estimatedCostUsd: estimateCost(usageMetadata),
          status: "success"
        });

        return { status: "completed" };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        console.error("[categorization] Failed:", error.message);

        // Update item status to failed
        try {
          await itemRepo.updateItem(authContext, itemId, {
            categorizationStatus: "failed"
          });
        } catch (updateError) {
          console.error("[categorization] Failed to update item status:", updateError.message);
        }

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "categorization",
            model: CATEGORIZATION_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message
          });
        } catch (logError) {
          console.error("[categorization] Failed to log AI usage:", logError.message);
        }

        return { status: "failed" };
      }
    }
  };
}
