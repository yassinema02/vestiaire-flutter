/**
 * Shopping scan service for orchestrating URL scraping and AI analysis.
 *
 * Coordinates:
 * 1. URL scraping via urlScraperService
 * 2. Merging OG tags + JSON-LD into unified product data
 * 3. Gemini vision analysis on product image (taxonomy extraction)
 * 4. AI fallback extraction when OG/JSON-LD both fail
 * 5. Persistence to shopping_scans table
 * 6. AI usage logging
 *
 * Story 8.1: Product URL Scraping (FR-SHP-02, FR-SHP-03, FR-SHP-04)
 */

import {
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_PATTERNS,
  VALID_MATERIALS,
  VALID_STYLES,
  VALID_SEASONS,
  VALID_OCCASIONS,
  VALID_CURRENCIES
} from "../ai/taxonomy.js";
import { validateTaxonomy } from "../ai/categorization-service.js";

const SHOPPING_SCAN_MODEL = "gemini-2.0-flash";
const IMAGE_DOWNLOAD_TIMEOUT_MS = 5000;

const MATCH_INSIGHT_PROMPT = `You are a wardrobe style analyst. Analyze how a potential purchase fits into a user's existing wardrobe.

POTENTIAL PURCHASE:
{productJson}

COMPATIBILITY SCORE BREAKDOWN:
{scoreBreakdown}

USER'S WARDROBE ITEMS:
{wardrobeItems}

Provide two things:

1. TOP MATCHES: Identify up to 10 wardrobe items that would pair best with this purchase. For each, explain briefly why they match well (color coordination, style compatibility, occasion pairing, etc.).

2. THREE INSIGHTS:
   a) style_feedback: How does this item fit the user's overall style? Is it consistent or a new direction?
   b) gap_assessment: Does this item fill a wardrobe gap, or does it duplicate something they already own?
   c) value_proposition: Given the price and how much use they'd likely get, is this a good investment?

Return ONLY valid JSON:
{
  "matches": [
    { "item_id": "<uuid from wardrobe list>", "reason": "<1 sentence>" }
  ],
  "insights": [
    { "type": "style_feedback", "title": "<short title>", "body": "<2-3 sentence analysis>" },
    { "type": "gap_assessment", "title": "<short title>", "body": "<2-3 sentence analysis>" },
    { "type": "value_proposition", "title": "<short title>", "body": "<2-3 sentence analysis>" }
  ]
}`;

const COMPATIBILITY_SCORING_PROMPT = `You are a wardrobe compatibility analyst. Score how well a potential purchase matches a user's existing wardrobe.

POTENTIAL PURCHASE:
{productJson}

USER'S WARDROBE:
{wardrobeSummary}

Score the purchase on these 5 factors (each 0-100):
1. color_harmony (30% weight): How well does the item's color coordinate with existing wardrobe colors? Consider complementary colors, neutral compatibility, and color palette diversity.
2. style_consistency (25% weight): How well does the item's style match the user's existing style profile? Consider style variety vs. cohesion.
3. gap_filling (20% weight): Does this item fill a gap in the wardrobe? Consider missing categories, underrepresented colors, or missing formality levels.
4. versatility (15% weight): How many existing items could this be paired with? Consider cross-category matching potential.
5. formality_match (10% weight): Does the item's formality level complement the wardrobe's formality range?

Calculate the weighted total: total = round(color_harmony * 0.30 + style_consistency * 0.25 + gap_filling * 0.20 + versatility * 0.15 + formality_match * 0.10)

Return ONLY valid JSON:
{
  "total": <integer 0-100>,
  "color_harmony": <integer 0-100>,
  "style_consistency": <integer 0-100>,
  "gap_filling": <integer 0-100>,
  "versatility": <integer 0-100>,
  "formality_match": <integer 0-100>,
  "reasoning": "<1-2 sentence explanation of the overall score>"
}`;

const PRODUCT_IMAGE_PROMPT = `Analyze this clothing product image and extract the following metadata as JSON.
Return ONLY valid JSON with these exact keys:
{
  "category": "one of: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other",
  "color": "primary color, one of: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown",
  "secondary_colors": ["array of additional colors from the same color list, empty if solid color"],
  "pattern": "one of: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other",
  "material": "best guess, one of: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown",
  "style": "one of: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other",
  "season": ["array of suitable seasons: spring, summer, fall, winter, all"],
  "occasion": ["array of suitable occasions: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge"],
  "formality_score": "integer 1-10 where 1 is very casual and 10 is black-tie formal"
}`;

const SCREENSHOT_TEXT_PROMPT = `Analyze this product screenshot and extract any visible text information as JSON.
This may be a screenshot from Instagram, a shopping app, or a website.
Return ONLY valid JSON with these keys (use null for missing/not visible values):
{
  "name": "product name if visible",
  "brand": "brand name if visible",
  "price": numeric price value if visible (just the number),
  "currency": "3-letter currency code if visible (GBP, USD, EUR, etc.)"
}`;

const AI_FALLBACK_PROMPT = `Extract product information from this HTML page content.
Return ONLY valid JSON with these keys (use null for missing values):
{
  "name": "product name",
  "brand": "brand name",
  "price": numeric price value,
  "currency": "3-letter currency code (GBP, USD, EUR, etc.)",
  "description": "brief product description"
}`;

/**
 * Estimate the cost of a Gemini API call based on token usage.
 */
function estimateCost(usageMetadata) {
  const inputTokens = usageMetadata?.promptTokenCount ?? 0;
  const outputTokens = usageMetadata?.candidatesTokenCount ?? 0;
  const inputCost = (inputTokens / 1_000_000) * 0.075;
  const outputCost = (outputTokens / 1_000_000) * 0.30;
  return inputCost + outputCost;
}

/**
 * Download an image and convert to base64.
 *
 * @param {string} imageUrl - URL of the image to download.
 * @returns {Promise<{ base64: string, mimeType: string }>}
 */
async function downloadImage(imageUrl) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), IMAGE_DOWNLOAD_TIMEOUT_MS);

  try {
    const response = await fetch(imageUrl, {
      signal: controller.signal,
      headers: { "User-Agent": "Mozilla/5.0 (compatible; Vestiaire/1.0)" },
    });

    clearTimeout(timeout);

    if (!response.ok) {
      throw new Error(`Image download failed: ${response.status}`);
    }

    const contentType = response.headers.get("content-type") || "image/jpeg";
    const mimeType = contentType.split(";")[0].trim();
    const arrayBuffer = await response.arrayBuffer();
    const base64 = Buffer.from(arrayBuffer).toString("base64");

    return { base64, mimeType };
  } catch (err) {
    clearTimeout(timeout);
    throw err;
  }
}

/**
 * Validate formality score as integer 1-10.
 */
function validateFormalityScore(value) {
  const num = parseInt(value, 10);
  if (Number.isInteger(num) && num >= 1 && num <= 10) return num;
  return null;
}

/**
 * Merge OG tags and JSON-LD into a unified product object.
 * JSON-LD fields take priority where both exist.
 */
function mergeProductData(ogTags, jsonLd) {
  return {
    productName: jsonLd.name || ogTags.title || null,
    brand: jsonLd.brand || ogTags.brand || null,
    price: jsonLd.price != null ? parseFloat(jsonLd.price) : (ogTags.price != null ? parseFloat(ogTags.price) : null),
    currency: jsonLd.priceCurrency || ogTags.currency || null,
    imageUrl: jsonLd.image || ogTags.image || null,
  };
}

/**
 * Compute the tier for a compatibility score (0-100).
 */
export function computeTier(score) {
  if (score >= 90) return { tier: "perfect_match", label: "Perfect Match", color: "#22C55E", icon: "stars" };
  if (score >= 75) return { tier: "great_choice", label: "Great Choice", color: "#3B82F6", icon: "thumb_up" };
  if (score >= 60) return { tier: "good_fit", label: "Good Fit", color: "#F59E0B", icon: "check_circle" };
  if (score >= 40) return { tier: "might_work", label: "Might Work", color: "#F97316", icon: "help_outline" };
  return { tier: "careful", label: "Careful", color: "#EF4444", icon: "warning" };
}

/**
 * Build a wardrobe summary for the Gemini scoring prompt.
 *
 * For <= 50 items, returns per-item compact JSON.
 * For > 50 items, returns aggregated distribution counts.
 */
export function buildWardrobeSummary(items) {
  if (items.length <= 50) {
    return JSON.stringify(items.map(item => {
      const entry = {};
      if (item.category) entry.category = item.category;
      if (item.color) entry.color = item.color;
      if (item.style) entry.style = item.style;
      if (item.formalityScore != null) entry.formality = item.formalityScore;
      if (item.season) entry.season = item.season;
      if (item.occasion) entry.occasion = item.occasion;
      return entry;
    }));
  }

  // Aggregate into distributions
  const categories = {};
  const colors = {};
  const styles = {};
  const formalityRange = { casual_1_3: 0, mid_4_6: 0, formal_7_10: 0 };
  const seasonCoverage = {};
  const occasionCoverage = {};

  for (const item of items) {
    if (item.category) categories[item.category] = (categories[item.category] || 0) + 1;
    if (item.color) colors[item.color] = (colors[item.color] || 0) + 1;
    if (item.style) styles[item.style] = (styles[item.style] || 0) + 1;
    if (item.formalityScore != null) {
      if (item.formalityScore <= 3) formalityRange.casual_1_3++;
      else if (item.formalityScore <= 6) formalityRange.mid_4_6++;
      else formalityRange.formal_7_10++;
    }
    if (Array.isArray(item.season)) {
      for (const s of item.season) seasonCoverage[s] = (seasonCoverage[s] || 0) + 1;
    }
    if (Array.isArray(item.occasion)) {
      for (const o of item.occasion) occasionCoverage[o] = (occasionCoverage[o] || 0) + 1;
    }
  }

  return JSON.stringify({
    totalItems: items.length,
    categories,
    colors,
    styles,
    formalityRange,
    seasonCoverage,
    occasionCoverage
  });
}

/**
 * Build a wardrobe item list for the insight prompt.
 *
 * Unlike buildWardrobeSummary (used for scoring), this includes item IDs
 * for match references. For <= 50 items, returns per-item details.
 * For > 50 items, returns the top 50 with a distribution summary of the rest.
 */
export function buildInsightWardrobeList(items) {
  const mapItem = (item) => {
    const entry = { id: item.id };
    if (item.productName || item.name) entry.name = item.productName || item.name;
    if (item.imageUrl) entry.imageUrl = item.imageUrl;
    if (item.category) entry.category = item.category;
    if (item.color) entry.color = item.color;
    if (item.style) entry.style = item.style;
    if (item.formalityScore != null) entry.formalityScore = item.formalityScore;
    return entry;
  };

  if (items.length <= 50) {
    return JSON.stringify(items.map(mapItem));
  }

  // For > 50 items, take the top 50 and summarize the rest
  const top50 = items.slice(0, 50);
  const rest = items.slice(50);

  const categories = {};
  const colors = {};
  for (const item of rest) {
    if (item.category) categories[item.category] = (categories[item.category] || 0) + 1;
    if (item.color) colors[item.color] = (colors[item.color] || 0) + 1;
  }

  return JSON.stringify({
    items: top50.map(mapItem),
    remainingItemsSummary: {
      count: rest.length,
      categories,
      colors
    }
  });
}

/**
 * Clamp a value to [0, 100] integer.
 */
function clampScore(value) {
  const num = parseInt(value, 10);
  if (!Number.isFinite(num)) return 0;
  return Math.max(0, Math.min(100, num));
}

/**
 * @param {object} options
 * @param {object} options.urlScraperService - URL scraper service.
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 * @param {object} options.shoppingScanRepo - Shopping scan repository.
 * @param {object} options.itemRepo - Item repository for wardrobe fetching.
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createShoppingScanService({
  urlScraperService,
  geminiClient,
  aiUsageLogRepo,
  shoppingScanRepo,
  itemRepo,
  pool
}) {
  return {
    /**
     * Generate match & insight analysis for a shopping scan.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.scanId - Shopping scan UUID.
     * @returns {Promise<object>} The insight result.
     *
     * Story 8.5: Shopping Match & Insight Display (FR-SHP-08, FR-SHP-09)
     */
    async generateInsights(authContext, { scanId }) {
      const startTime = Date.now();

      // (a) Fetch the scan
      const scan = await shoppingScanRepo.getScanById(authContext, scanId);
      if (!scan) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Scan not found" };
      }

      // (c) Check if scan has been scored
      if (scan.compatibilityScore === null || scan.compatibilityScore === undefined) {
        throw {
          statusCode: 422,
          code: "NOT_SCORED",
          message: "Score the product first before viewing matches and insights."
        };
      }

      // (d) Return cached insights if already generated
      if (scan.insights !== null && scan.insights !== undefined) {
        return {
          scan,
          matches: scan.insights.matches || [],
          insights: scan.insights.insights || [],
          status: "analyzed"
        };
      }

      // (e) Fetch all user wardrobe items
      const items = await itemRepo.listItems(authContext, { limit: 1000 });
      if (!items || items.length === 0) {
        throw {
          statusCode: 422,
          code: "WARDROBE_EMPTY",
          message: "Add items to your wardrobe first to see matches and insights."
        };
      }

      // (g) Build the insight prompt
      const productJson = JSON.stringify({
        productName: scan.productName,
        brand: scan.brand,
        category: scan.category,
        color: scan.color,
        secondaryColors: scan.secondaryColors,
        pattern: scan.pattern,
        material: scan.material,
        style: scan.style,
        season: scan.season,
        occasion: scan.occasion,
        formalityScore: scan.formalityScore,
        price: scan.price,
        currency: scan.currency
      });

      const scoreBreakdown = JSON.stringify({
        compatibilityScore: scan.compatibilityScore
      });

      const wardrobeItems = buildInsightWardrobeList(items);

      const prompt = MATCH_INSIGHT_PROMPT
        .replace("{productJson}", productJson)
        .replace("{scoreBreakdown}", scoreBreakdown)
        .replace("{wardrobeItems}", wardrobeItems);

      // (h) Call Gemini
      let geminiResponse;
      let usageMetadata = {};
      try {
        const model = await geminiClient.getGenerativeModel(SHOPPING_SCAN_MODEL);
        const result = await model.generateContent({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: "application/json" }
        });

        geminiResponse = result.response;
        usageMetadata = geminiResponse?.usageMetadata ?? {};
        const latencyMs = Date.now() - startTime;

        // Log AI usage (success)
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "shopping_insight",
            model: SHOPPING_SCAN_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success"
          });
        } catch (logErr) {
          console.error("[shopping-scan] Failed to log insight usage:", logErr.message);
        }
      } catch (geminiErr) {
        const latencyMs = Date.now() - startTime;

        // Log AI usage (failure)
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "shopping_insight",
            model: SHOPPING_SCAN_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: geminiErr.message
          });
        } catch (logErr) {
          console.error("[shopping-scan] Failed to log insight failure:", logErr.message);
        }

        throw {
          statusCode: 502,
          code: "INSIGHT_FAILED",
          message: "Unable to generate insights. Please try again."
        };
      }

      // (i) Parse the structured response
      let parsed;
      try {
        const rawText = geminiResponse.candidates[0].content.parts[0].text;
        parsed = JSON.parse(rawText);
      } catch (parseErr) {
        throw {
          statusCode: 502,
          code: "INSIGHT_FAILED",
          message: "Unable to generate insights. Please try again."
        };
      }

      // (j) Validate matches reference real item IDs
      const itemIdSet = new Set(items.map(i => i.id));
      const itemMap = new Map(items.map(i => [i.id, i]));
      const rawMatches = Array.isArray(parsed.matches) ? parsed.matches : [];
      const validMatches = rawMatches
        .filter(m => m.item_id && itemIdSet.has(m.item_id))
        .slice(0, 10)
        .map(m => {
          const item = itemMap.get(m.item_id);
          return {
            itemId: m.item_id,
            itemName: item?.productName || item?.name || null,
            itemImageUrl: item?.imageUrl || null,
            category: item?.category || null,
            matchReasons: [m.reason || "Compatible with this item"]
          };
        });

      // (k) Validate insights - ensure exactly 3 with correct types
      const REQUIRED_INSIGHT_TYPES = ["style_feedback", "gap_assessment", "value_proposition"];
      const rawInsights = Array.isArray(parsed.insights) ? parsed.insights : [];
      const insightMap = new Map();
      for (const insight of rawInsights) {
        if (insight.type && REQUIRED_INSIGHT_TYPES.includes(insight.type) && !insightMap.has(insight.type)) {
          insightMap.set(insight.type, {
            type: insight.type,
            title: insight.title || "Analysis",
            body: insight.body || "Analysis for this product.",
            icon: insight.type === "style_feedback" ? "palette" :
                  insight.type === "gap_assessment" ? "space_dashboard" : "trending_up"
          });
        }
      }

      // Fill in missing insight types with generic fallback
      for (const type of REQUIRED_INSIGHT_TYPES) {
        if (!insightMap.has(type)) {
          insightMap.set(type, {
            type,
            title: "Analysis Unavailable",
            body: "We couldn't generate this insight for this product.",
            icon: type === "style_feedback" ? "palette" :
                  type === "gap_assessment" ? "space_dashboard" : "trending_up"
          });
        }
      }

      const validInsights = REQUIRED_INSIGHT_TYPES.map(t => insightMap.get(t));

      // (l) Store the result in the insights JSONB column
      const insightsData = { matches: validMatches, insights: validInsights };
      const updatedScan = await shoppingScanRepo.updateScan(authContext, scanId, {
        insights: insightsData
      });

      // (m) Return result
      return {
        scan: updatedScan || scan,
        matches: validMatches,
        insights: validInsights,
        status: "analyzed"
      };
    },

    /**
     * Score the compatibility of a shopping scan against the user's wardrobe.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.scanId - Shopping scan UUID.
     * @returns {Promise<object>} The score result.
     *
     * Story 8.4: Purchase Compatibility Scoring (FR-SHP-06, FR-SHP-07)
     */
    async scoreCompatibility(authContext, { scanId }) {
      const startTime = Date.now();

      // (a) Fetch the scan
      const scan = await shoppingScanRepo.getScanById(authContext, scanId);
      if (!scan) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Scan not found" };
      }

      // (b) Fetch all wardrobe items
      const items = await itemRepo.listItems(authContext, { limit: 1000 });
      if (!items || items.length === 0) {
        throw {
          statusCode: 422,
          code: "WARDROBE_EMPTY",
          message: "Add items to your wardrobe first to get compatibility scores."
        };
      }

      // (c) Build wardrobe summary
      const wardrobeSummary = buildWardrobeSummary(items);

      // (d) Build product JSON for prompt
      const productJson = JSON.stringify({
        productName: scan.productName,
        brand: scan.brand,
        category: scan.category,
        color: scan.color,
        secondaryColors: scan.secondaryColors,
        pattern: scan.pattern,
        material: scan.material,
        style: scan.style,
        season: scan.season,
        occasion: scan.occasion,
        formalityScore: scan.formalityScore,
        price: scan.price,
        currency: scan.currency
      });

      // (e) Construct prompt
      const prompt = COMPATIBILITY_SCORING_PROMPT
        .replace("{productJson}", productJson)
        .replace("{wardrobeSummary}", wardrobeSummary);

      // (f) Call Gemini
      let geminiResponse;
      let usageMetadata = {};
      try {
        const model = await geminiClient.getGenerativeModel(SHOPPING_SCAN_MODEL);
        const result = await model.generateContent({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: "application/json" }
        });

        geminiResponse = result.response;
        usageMetadata = geminiResponse?.usageMetadata ?? {};
        const latencyMs = Date.now() - startTime;

        // Log AI usage (success)
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "shopping_score",
            model: SHOPPING_SCAN_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success"
          });
        } catch (logErr) {
          console.error("[shopping-scan] Failed to log scoring usage:", logErr.message);
        }
      } catch (geminiErr) {
        const latencyMs = Date.now() - startTime;

        // Log AI usage (failure)
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "shopping_score",
            model: SHOPPING_SCAN_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: geminiErr.message
          });
        } catch (logErr) {
          console.error("[shopping-scan] Failed to log scoring failure:", logErr.message);
        }

        throw {
          statusCode: 502,
          code: "SCORING_FAILED",
          message: "Unable to calculate compatibility score. Please try again."
        };
      }

      // (g) Parse and validate response
      let parsed;
      try {
        const rawText = geminiResponse.candidates[0].content.parts[0].text;
        parsed = JSON.parse(rawText);
      } catch (parseErr) {
        throw {
          statusCode: 502,
          code: "SCORING_FAILED",
          message: "Unable to calculate compatibility score. Please try again."
        };
      }

      // Validate and clamp scores
      const colorHarmony = clampScore(parsed.color_harmony);
      const styleConsistency = clampScore(parsed.style_consistency);
      const gapFilling = clampScore(parsed.gap_filling);
      const versatility = clampScore(parsed.versatility);
      const formalityMatch = clampScore(parsed.formality_match);

      // Server-side weighted total computation (don't trust Gemini's total)
      const total = Math.round(
        colorHarmony * 0.30 +
        styleConsistency * 0.25 +
        gapFilling * 0.20 +
        versatility * 0.15 +
        formalityMatch * 0.10
      );

      const reasoning = typeof parsed.reasoning === "string" ? parsed.reasoning : null;

      // (h) Compute tier
      const tier = computeTier(total);

      // (i) Update compatibility_score on the scan
      const updatedScan = await shoppingScanRepo.updateScan(authContext, scanId, {
        compatibilityScore: total
      });

      return {
        scan: updatedScan || scan,
        score: {
          total,
          breakdown: {
            colorHarmony,
            styleConsistency,
            gapFilling,
            versatility,
            formalityMatch
          },
          tier: tier.tier,
          tierLabel: tier.label,
          tierColor: tier.color,
          tierIcon: tier.icon,
          reasoning
        },
        status: "scored"
      };
    },

    /**
     * Scan a product URL: scrape, analyze with AI, persist, and return result.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.url - Product URL to scan.
     * @returns {Promise<object>} The scan result.
     */
    /**
     * Scan a product screenshot: download image, analyze with AI (taxonomy + text), persist, and return result.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.imageUrl - Public URL of the uploaded screenshot.
     * @returns {Promise<object>} The scan result.
     */
    async scanScreenshot(authContext, { imageUrl }) {
      const startTime = Date.now();

      // (a) Download the image
      let imageData;
      try {
        imageData = await downloadImage(imageUrl);
      } catch (downloadErr) {
        // Log failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "shopping_scan",
            model: SHOPPING_SCAN_MODEL,
            latencyMs: Date.now() - startTime,
            status: "failure",
            errorMessage: downloadErr.message
          });
        } catch (logErr) {
          console.error("[shopping-scan] Failed to log download failure:", logErr.message);
        }

        throw {
          statusCode: 422,
          code: "EXTRACTION_FAILED",
          message: "Unable to identify clothing in this image. Try a clearer photo or paste a product URL instead."
        };
      }

      // (b+c) Run both Gemini calls in parallel: taxonomy + text extraction
      const visionRequest = {
        contents: [{
          role: "user",
          parts: [
            {
              inlineData: {
                mimeType: imageData.mimeType,
                data: imageData.base64
              }
            },
            { text: PRODUCT_IMAGE_PROMPT }
          ]
        }],
        generationConfig: { responseMimeType: "application/json" }
      };

      const textRequest = {
        contents: [{
          role: "user",
          parts: [
            {
              inlineData: {
                mimeType: imageData.mimeType,
                data: imageData.base64
              }
            },
            { text: SCREENSHOT_TEXT_PROMPT }
          ]
        }],
        generationConfig: { responseMimeType: "application/json" }
      };

      let taxonomy = {};
      let textMetadata = {};
      let taxonomySuccess = false;
      let textSuccess = false;

      const model = await geminiClient.getGenerativeModel(SHOPPING_SCAN_MODEL);

      const [taxonomyResult, textResult] = await Promise.all([
        // Taxonomy extraction
        (async () => {
          const callStart = Date.now();
          try {
            const result = await model.generateContent(visionRequest);
            const response = result.response;
            const latencyMs = Date.now() - callStart;
            const usageMetadata = response?.usageMetadata ?? {};

            // Log AI usage - taxonomy
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                inputTokens: usageMetadata.promptTokenCount ?? null,
                outputTokens: usageMetadata.candidatesTokenCount ?? null,
                latencyMs,
                estimatedCostUsd: estimateCost(usageMetadata),
                status: "success"
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log taxonomy usage:", logErr.message);
            }

            const rawText = response.candidates[0].content.parts[0].text;
            const parsed = JSON.parse(rawText);
            return { success: true, data: parsed };
          } catch (err) {
            const latencyMs = Date.now() - callStart;
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                latencyMs,
                status: "failure",
                errorMessage: err.message
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log taxonomy failure:", logErr.message);
            }
            return { success: false, data: null };
          }
        })(),
        // Text extraction
        (async () => {
          const callStart = Date.now();
          try {
            const result = await model.generateContent(textRequest);
            const response = result.response;
            const latencyMs = Date.now() - callStart;
            const usageMetadata = response?.usageMetadata ?? {};

            // Log AI usage - text
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                inputTokens: usageMetadata.promptTokenCount ?? null,
                outputTokens: usageMetadata.candidatesTokenCount ?? null,
                latencyMs,
                estimatedCostUsd: estimateCost(usageMetadata),
                status: "success"
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log text usage:", logErr.message);
            }

            const rawText = response.candidates[0].content.parts[0].text;
            const parsed = JSON.parse(rawText);
            return { success: true, data: parsed };
          } catch (err) {
            const latencyMs = Date.now() - callStart;
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                latencyMs,
                status: "failure",
                errorMessage: err.message
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log text failure:", logErr.message);
            }
            return { success: false, data: null };
          }
        })()
      ]);

      taxonomySuccess = taxonomyResult.success;
      textSuccess = textResult.success;

      // If both calls returned no useful data, throw 422
      if (!taxonomySuccess && !textSuccess) {
        throw {
          statusCode: 422,
          code: "EXTRACTION_FAILED",
          message: "Unable to identify clothing in this image. Try a clearer photo or paste a product URL instead."
        };
      }

      // Process taxonomy
      if (taxonomySuccess && taxonomyResult.data) {
        taxonomy = validateTaxonomy(taxonomyResult.data);
        taxonomy.formalityScore = validateFormalityScore(taxonomyResult.data.formality_score);
      }

      // Process text metadata
      if (textSuccess && textResult.data) {
        textMetadata = {
          productName: textResult.data.name || null,
          brand: textResult.data.brand || null,
          price: textResult.data.price != null ? parseFloat(textResult.data.price) : null,
          currency: textResult.data.currency || null,
        };
      }

      // Build final scan data
      const scanData = {
        url: null,
        scanType: "screenshot",
        imageUrl,
        productName: textMetadata.productName || null,
        brand: textMetadata.brand || null,
        price: textMetadata.price || null,
        currency: textMetadata.currency || null,
        category: taxonomy.category || null,
        color: taxonomy.color || null,
        secondaryColors: taxonomy.secondaryColors || null,
        pattern: taxonomy.pattern || null,
        material: taxonomy.material || null,
        style: taxonomy.style || null,
        season: taxonomy.season || null,
        occasion: taxonomy.occasion || null,
        formalityScore: taxonomy.formalityScore || null,
        extractionMethod: "screenshot_vision",
      };

      // Persist to shopping_scans
      const scan = await shoppingScanRepo.createScan(authContext, scanData);

      return {
        scan,
        status: "completed"
      };
    },

    async scanUrl(authContext, { url }) {
      const startTime = Date.now();
      let aiCalled = false;

      try {
        // (a) Scrape the URL
        const scrapeResult = await urlScraperService.scrapeUrl(url);

        if (scrapeResult.error) {
          throw {
            statusCode: 422,
            code: "EXTRACTION_FAILED",
            message: "Unable to extract product information from this URL. Try uploading a screenshot instead."
          };
        }

        // (b) Merge OG tags and JSON-LD
        const merged = mergeProductData(scrapeResult.ogTags, scrapeResult.jsonLd);
        let extractionMethod = scrapeResult.extractionMethod;

        // (d) AI fallback if both OG and JSON-LD are empty
        const hasData = merged.productName || merged.brand || merged.price;
        if (!hasData && geminiClient.isAvailable()) {
          aiCalled = true;
          try {
            const model = await geminiClient.getGenerativeModel(SHOPPING_SCAN_MODEL);
            const aiResult = await model.generateContent({
              contents: [{
                role: "user",
                parts: [{ text: `${AI_FALLBACK_PROMPT}\n\n${scrapeResult.rawHtml}` }]
              }],
              generationConfig: { responseMimeType: "application/json" }
            });

            const aiResponse = aiResult.response;
            const latencyMs = Date.now() - startTime;
            const usageMetadata = aiResponse?.usageMetadata ?? {};

            // Log AI usage for fallback
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                inputTokens: usageMetadata.promptTokenCount ?? null,
                outputTokens: usageMetadata.candidatesTokenCount ?? null,
                latencyMs,
                estimatedCostUsd: estimateCost(usageMetadata),
                status: "success"
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log AI fallback usage:", logErr.message);
            }

            const rawText = aiResponse.candidates[0].content.parts[0].text;
            const parsed = JSON.parse(rawText);

            if (parsed.name) merged.productName = parsed.name;
            if (parsed.brand) merged.brand = parsed.brand;
            if (parsed.price != null) merged.price = parseFloat(parsed.price);
            if (parsed.currency) merged.currency = parsed.currency;

            extractionMethod = extractionMethod === "none" ? "ai_fallback" : `${extractionMethod}+ai_fallback`;
          } catch (aiErr) {
            console.error("[shopping-scan] AI fallback failed:", aiErr.message);

            // Log AI failure
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                latencyMs: Date.now() - startTime,
                status: "failure",
                errorMessage: aiErr.message
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log AI failure:", logErr.message);
            }
          }
        }

        // Check if we have any data at all
        const hasAnyData = merged.productName || merged.brand || merged.price || merged.imageUrl;
        if (!hasAnyData) {
          throw {
            statusCode: 422,
            code: "EXTRACTION_FAILED",
            message: "Unable to extract product information from this URL. Try uploading a screenshot instead."
          };
        }

        // (c) Gemini vision analysis on product image
        let taxonomy = {};
        if (merged.imageUrl && geminiClient.isAvailable()) {
          aiCalled = true;
          const visionStartTime = Date.now();
          try {
            const imageData = await downloadImage(merged.imageUrl);
            const model = await geminiClient.getGenerativeModel(SHOPPING_SCAN_MODEL);
            const visionResult = await model.generateContent({
              contents: [{
                role: "user",
                parts: [
                  {
                    inlineData: {
                      mimeType: imageData.mimeType,
                      data: imageData.base64
                    }
                  },
                  { text: PRODUCT_IMAGE_PROMPT }
                ]
              }],
              generationConfig: { responseMimeType: "application/json" }
            });

            const visionResponse = visionResult.response;
            const visionLatencyMs = Date.now() - visionStartTime;
            const visionUsage = visionResponse?.usageMetadata ?? {};

            // Log vision AI usage
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                inputTokens: visionUsage.promptTokenCount ?? null,
                outputTokens: visionUsage.candidatesTokenCount ?? null,
                latencyMs: visionLatencyMs,
                estimatedCostUsd: estimateCost(visionUsage),
                status: "success"
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log vision usage:", logErr.message);
            }

            const rawVision = visionResponse.candidates[0].content.parts[0].text;
            const parsedVision = JSON.parse(rawVision);

            // Validate taxonomy fields
            taxonomy = validateTaxonomy(parsedVision);
            taxonomy.formalityScore = validateFormalityScore(parsedVision.formality_score);
          } catch (visionErr) {
            console.error("[shopping-scan] Vision analysis failed:", visionErr.message);

            // Log vision failure
            try {
              await aiUsageLogRepo.logUsage(authContext, {
                feature: "shopping_scan",
                model: SHOPPING_SCAN_MODEL,
                latencyMs: Date.now() - visionStartTime,
                status: "failure",
                errorMessage: visionErr.message
              });
            } catch (logErr) {
              console.error("[shopping-scan] Failed to log vision failure:", logErr.message);
            }
          }
        }

        // (e) Build final scan data
        const scanData = {
          url,
          scanType: "url",
          productName: merged.productName,
          brand: merged.brand,
          price: merged.price,
          currency: merged.currency || "GBP",
          imageUrl: merged.imageUrl,
          category: taxonomy.category || null,
          color: taxonomy.color || null,
          secondaryColors: taxonomy.secondaryColors || null,
          pattern: taxonomy.pattern || null,
          material: taxonomy.material || null,
          style: taxonomy.style || null,
          season: taxonomy.season || null,
          occasion: taxonomy.occasion || null,
          formalityScore: taxonomy.formalityScore || null,
          extractionMethod,
        };

        // (f) Persist to shopping_scans
        const scan = await shoppingScanRepo.createScan(authContext, scanData);

        return {
          scan,
          status: "completed"
        };
      } catch (error) {
        // Log AI failure if we haven't already and AI was involved
        if (!aiCalled) {
          // Non-AI errors, just rethrow
        }

        if (error.statusCode) {
          throw error;
        }

        console.error("[shopping-scan] Unexpected error:", error.message);
        throw {
          statusCode: 500,
          message: "Shopping scan failed"
        };
      }
    }
  };
}

/**
 * Validate fields for a scan update request.
 *
 * Only validates fields that are present in the body.
 * Returns { valid: true, data: sanitizedData } or { valid: false, errors: [...] }.
 *
 * Story 8.3: Review Extracted Product Data (FR-SHP-05)
 */
export function validateScanUpdate(body) {
  const errors = [];
  const data = {};

  if (body.category !== undefined) {
    if (!VALID_CATEGORIES.includes(body.category)) {
      errors.push({ field: "category", message: `Invalid category: ${body.category}` });
    } else {
      data.category = body.category;
    }
  }

  if (body.color !== undefined) {
    if (!VALID_COLORS.includes(body.color)) {
      errors.push({ field: "color", message: `Invalid color: ${body.color}` });
    } else {
      data.color = body.color;
    }
  }

  if (body.secondaryColors !== undefined) {
    if (!Array.isArray(body.secondaryColors) || !body.secondaryColors.every(c => VALID_COLORS.includes(c))) {
      errors.push({ field: "secondaryColors", message: "Invalid secondaryColors: each value must be a valid color" });
    } else {
      data.secondaryColors = body.secondaryColors;
    }
  }

  if (body.pattern !== undefined) {
    if (!VALID_PATTERNS.includes(body.pattern)) {
      errors.push({ field: "pattern", message: `Invalid pattern: ${body.pattern}` });
    } else {
      data.pattern = body.pattern;
    }
  }

  if (body.material !== undefined) {
    if (!VALID_MATERIALS.includes(body.material)) {
      errors.push({ field: "material", message: `Invalid material: ${body.material}` });
    } else {
      data.material = body.material;
    }
  }

  if (body.style !== undefined) {
    if (!VALID_STYLES.includes(body.style)) {
      errors.push({ field: "style", message: `Invalid style: ${body.style}` });
    } else {
      data.style = body.style;
    }
  }

  if (body.season !== undefined) {
    if (!Array.isArray(body.season) || !body.season.every(s => VALID_SEASONS.includes(s))) {
      errors.push({ field: "season", message: "Invalid season: each value must be a valid season" });
    } else {
      data.season = body.season;
    }
  }

  if (body.occasion !== undefined) {
    if (!Array.isArray(body.occasion) || !body.occasion.every(o => VALID_OCCASIONS.includes(o))) {
      errors.push({ field: "occasion", message: "Invalid occasion: each value must be a valid occasion" });
    } else {
      data.occasion = body.occasion;
    }
  }

  if (body.formalityScore !== undefined) {
    const score = body.formalityScore;
    if (!Number.isInteger(score) || score < 1 || score > 10) {
      errors.push({ field: "formalityScore", message: "formalityScore must be an integer between 1 and 10" });
    } else {
      data.formalityScore = score;
    }
  }

  if (body.price !== undefined) {
    if (body.price !== null && (typeof body.price !== "number" || body.price <= 0)) {
      errors.push({ field: "price", message: "price must be a positive number or null" });
    } else {
      data.price = body.price;
    }
  }

  if (body.currency !== undefined) {
    if (!VALID_CURRENCIES.includes(body.currency)) {
      errors.push({ field: "currency", message: `Invalid currency: ${body.currency}` });
    } else {
      data.currency = body.currency;
    }
  }

  if (body.productName !== undefined) {
    data.productName = body.productName;
  }

  if (body.brand !== undefined) {
    data.brand = body.brand;
  }

  if (body.wishlisted !== undefined) {
    if (typeof body.wishlisted !== "boolean") {
      errors.push({ field: "wishlisted", message: "wishlisted must be a boolean" });
    } else {
      data.wishlisted = body.wishlisted;
    }
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return { valid: true, data };
}

// Export for testing
export { mergeProductData, downloadImage, validateFormalityScore, COMPATIBILITY_SCORING_PROMPT, MATCH_INSIGHT_PROMPT };
