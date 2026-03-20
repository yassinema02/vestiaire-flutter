/**
 * Gap analysis service using rule-based detection + Gemini 2.0 Flash enrichment.
 *
 * Analyzes wardrobe composition to detect missing items by category, formality,
 * color range, and weather coverage. Gemini provides personalized recommendations
 * for each detected gap. Rule-based gaps are always returned even if Gemini fails.
 */

import {
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_SEASONS,
  VALID_OCCASIONS,
} from "../ai/taxonomy.js";

const GAP_MODEL = "gemini-2.0-flash";

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

// Core categories that should be present in a wardrobe
const CORE_CATEGORIES = ["tops", "bottoms", "outerwear", "dresses", "shoes", "accessories"];

// Accessory-type categories skipped for critical checks
const ACCESSORY_CATEGORIES = ["accessories", "bags"];

// Primary color groups for color range analysis
const COLOR_GROUPS = {
  neutrals: ["black", "white", "gray", "beige", "cream", "navy"],
  warm: ["red", "orange", "yellow", "pink", "coral"],
  cool: ["blue", "green", "teal", "mint", "turquoise"],
  earth: ["brown", "tan", "khaki", "olive", "burgundy", "maroon"],
  bright: ["purple", "magenta", "fuchsia", "lime", "gold", "silver"],
  pastels: ["light-blue", "light-pink", "lavender", "peach", "light-green"],
};

// Core occasions to check for formality spectrum gaps
const CORE_OCCASIONS = ["everyday", "work", "formal", "casual", "party", "sport", "outdoor", "date-night"];

/**
 * Detect category balance gaps.
 */
function detectCategoryGaps(categoryDistribution, totalItems) {
  const gaps = [];
  const catMap = new Map(categoryDistribution.map((c) => [c.category, c.count]));

  for (const category of CORE_CATEGORIES) {
    if (ACCESSORY_CATEGORIES.includes(category)) continue;

    const count = catMap.get(category) || 0;
    if (count === 0) {
      gaps.push({
        id: `gap-category-missing-${category}`,
        dimension: "category",
        title: `Missing ${category}`,
        description: `Your wardrobe has no ${category}. This is a core category for a versatile wardrobe.`,
        severity: "critical",
        recommendation: null,
      });
    } else if (totalItems > 0 && count / totalItems < 0.10 && 0.15 <= 0.15) {
      // Category underrepresented: less than 10% when expected at least 15%
      gaps.push({
        id: `gap-category-underrepresented-${category}`,
        dimension: "category",
        title: `${category.charAt(0).toUpperCase() + category.slice(1)} underrepresented`,
        description: `${category.charAt(0).toUpperCase() + category.slice(1)} make up only ${Math.round((count / totalItems) * 100)}% of your wardrobe.`,
        severity: "important",
        recommendation: null,
      });
    }
  }

  return gaps;
}

/**
 * Detect weather coverage gaps.
 */
function detectWeatherGaps(seasonCoverage, totalItems) {
  const gaps = [];
  const seasonMap = new Map(seasonCoverage.map((s) => [s.season, s.count]));
  const seasons = ["spring", "summer", "fall", "winter"];

  for (const season of seasons) {
    const count = seasonMap.get(season) || 0;
    if (count === 0 && totalItems >= 10) {
      gaps.push({
        id: `gap-weather-no-${season}`,
        dimension: "weather",
        title: `No ${season}-appropriate items`,
        description: `You have no items tagged for ${season} weather. Consider adding seasonal pieces.`,
        severity: "critical",
        recommendation: null,
      });
    } else if (totalItems >= 15 && totalItems > 0 && count / totalItems < 0.10) {
      gaps.push({
        id: `gap-weather-limited-${season}`,
        dimension: "weather",
        title: `Limited ${season} coverage`,
        description: `Only ${Math.round((count / totalItems) * 100)}% of your wardrobe is suitable for ${season}.`,
        severity: "important",
        recommendation: null,
      });
    }
  }

  return gaps;
}

/**
 * Detect formality spectrum gaps.
 */
function detectFormalityGaps(occasionCoverage, totalItems) {
  const gaps = [];
  const occMap = new Map(occasionCoverage.map((o) => [o.occasion, o.count]));

  if (totalItems >= 10) {
    if ((occMap.get("formal") || 0) === 0) {
      gaps.push({
        id: "gap-formality-no-formal",
        dimension: "formality",
        title: "No formal wear",
        description: "Your wardrobe lacks formal attire. Consider adding pieces for formal occasions.",
        severity: "important",
        recommendation: null,
      });
    }

    if ((occMap.get("work") || 0) === 0) {
      gaps.push({
        id: "gap-formality-no-work",
        dimension: "formality",
        title: "No work-appropriate items",
        description: "You have no items tagged for work. Consider adding professional attire.",
        severity: "important",
        recommendation: null,
      });
    }
  }

  // Check occasion diversity
  const presentOccasions = occasionCoverage.filter((o) => o.count > 0);
  if (presentOccasions.length === 1) {
    gaps.push({
      id: "gap-formality-limited-diversity",
      dimension: "formality",
      title: "Limited occasion diversity",
      description: `All your items are tagged for "${presentOccasions[0].occasion}" only. A versatile wardrobe covers multiple occasions.`,
      severity: "important",
      recommendation: null,
    });
  }

  return gaps;
}

/**
 * Detect color range gaps.
 */
function detectColorGaps(colorDistribution, totalItems) {
  const gaps = [];

  // Map item colors to color groups
  const groupCounts = {};
  for (const group of Object.keys(COLOR_GROUPS)) {
    groupCounts[group] = 0;
  }

  for (const item of colorDistribution) {
    for (const [group, colors] of Object.entries(COLOR_GROUPS)) {
      if (colors.includes(item.color)) {
        groupCounts[group] += item.count;
        break;
      }
    }
  }

  const groupsWithItems = Object.values(groupCounts).filter((c) => c > 0).length;
  const emptyGroups = Object.keys(COLOR_GROUPS).length - groupsWithItems;

  if (groupsWithItems === 1) {
    gaps.push({
      id: "gap-color-limited-variety",
      dimension: "color",
      title: "Limited color variety",
      description: "Your wardrobe items come from only one color family. Consider diversifying your palette.",
      severity: "important",
      recommendation: null,
    });
  }

  if (emptyGroups >= 4 && totalItems >= 15) {
    gaps.push({
      id: "gap-color-palette-limited",
      dimension: "color",
      title: "Color palette could be more diverse",
      description: `${emptyGroups} of 6 color groups are missing from your wardrobe.`,
      severity: "optional",
      recommendation: null,
    });
  }

  return gaps;
}

const SEVERITY_ORDER = { critical: 0, important: 1, optional: 2 };

/**
 * Build the Gemini prompt for gap recommendations.
 */
function buildGapPrompt(wardrobeData, gaps) {
  const categoryList = wardrobeData.categoryDistribution
    .map((c) => `${c.category}: ${c.count}`)
    .join(", ");
  const seasonList = wardrobeData.seasonCoverage
    .map((s) => `${s.season}: ${s.count}`)
    .join(", ");
  const colorList = wardrobeData.colorDistribution
    .map((c) => `${c.color}: ${c.count}`)
    .join(", ");
  const occasionList = wardrobeData.occasionCoverage
    .map((o) => `${o.occasion}: ${o.count}`)
    .join(", ");

  const gapData = gaps.map((g) => ({
    id: g.id,
    dimension: g.dimension,
    title: g.title,
    severity: g.severity,
  }));

  return `You are a personal wardrobe advisor. Based on the user's wardrobe composition and detected gaps, provide specific, actionable item recommendations.

WARDROBE SUMMARY:
- Total items: ${wardrobeData.totalItems}
- Categories: ${categoryList}
- Seasons: ${seasonList}
- Colors: ${colorList}
- Occasions: ${occasionList}

DETECTED GAPS:
${JSON.stringify(gapData, null, 2)}

RULES:
1. For each gap, provide ONE specific item recommendation (e.g., "Consider adding a navy blazer for work events").
2. Recommendations should be practical and specific (include color, item type, and use case).
3. Prioritize recommendations for Critical gaps over Optional ones.
4. Do NOT recommend items the user already has in abundance.
5. Keep each recommendation under 100 characters.

Return ONLY valid JSON:
{
  "recommendations": [
    { "gapId": "gap-id-here", "recommendation": "Consider adding a ..." }
  ]
}`;
}

/**
 * @param {object} options
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.analyticsRepository - Analytics repository with getGapAnalysisData.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 */
export function createGapAnalysisService({
  geminiClient,
  analyticsRepository,
  aiUsageLogRepo,
}) {
  return {
    /**
     * Analyze wardrobe gaps for the authenticated user.
     *
     * @param {object} authContext - Auth context with userId.
     * @returns {Promise<{ gaps: Array, totalItems: number }>}
     */
    async analyzeGaps(authContext) {
      // Step 1: Get wardrobe composition data
      const wardrobeData = await analyticsRepository.getGapAnalysisData(authContext);

      // Step 2: Early return for small wardrobes
      if (wardrobeData.totalItems < 5) {
        return { gaps: [], totalItems: wardrobeData.totalItems };
      }

      // Step 3: Run rule-based gap detection
      const allGaps = [
        ...detectCategoryGaps(wardrobeData.categoryDistribution, wardrobeData.totalItems),
        ...detectWeatherGaps(wardrobeData.seasonCoverage, wardrobeData.totalItems),
        ...detectFormalityGaps(wardrobeData.occasionCoverage, wardrobeData.totalItems),
        ...detectColorGaps(wardrobeData.colorDistribution, wardrobeData.totalItems),
      ];

      // Step 4: Sort by severity priority and limit to 10
      allGaps.sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity]);
      const gaps = allGaps.slice(0, 10);

      // Step 5: Enrich with Gemini recommendations (best-effort)
      if (gaps.length > 0) {
        await enrichWithGemini(authContext, wardrobeData, gaps);
      }

      return { gaps, totalItems: wardrobeData.totalItems };
    },
  };

  async function enrichWithGemini(authContext, wardrobeData, gaps) {
    const startTime = Date.now();

    try {
      if (!geminiClient.isAvailable()) {
        throw new Error("Gemini client not available");
      }

      const prompt = buildGapPrompt(wardrobeData, gaps);
      const model = await geminiClient.getGenerativeModel(GAP_MODEL);
      const result = await model.generateContent({
        contents: [
          {
            role: "user",
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: { responseMimeType: "application/json" },
      });

      const response = result.response;
      const latencyMs = Date.now() - startTime;

      const rawText = response.candidates[0].content.parts[0].text;
      const parsed = JSON.parse(rawText);

      // Match recommendations to gaps by gapId
      if (parsed.recommendations && Array.isArray(parsed.recommendations)) {
        for (const rec of parsed.recommendations) {
          const gap = gaps.find((g) => g.id === rec.gapId);
          if (gap && rec.recommendation) {
            gap.recommendation = rec.recommendation;
          }
        }
      }

      // Log AI usage
      const usageMetadata = response?.usageMetadata ?? {};
      try {
        await aiUsageLogRepo.logUsage(authContext, {
          feature: "gap_analysis",
          model: GAP_MODEL,
          inputTokens: usageMetadata.promptTokenCount ?? null,
          outputTokens: usageMetadata.candidatesTokenCount ?? null,
          latencyMs,
          estimatedCostUsd: estimateCost(usageMetadata),
          status: "success",
        });
      } catch (logError) {
        console.error("[gap-analysis] Failed to log AI usage:", logError.message);
      }
    } catch (error) {
      const latencyMs = Date.now() - startTime;
      console.error("[gap-analysis] Gemini enrichment failed:", error.message);

      // Log the failure
      try {
        await aiUsageLogRepo.logUsage(authContext, {
          feature: "gap_analysis",
          model: GAP_MODEL,
          latencyMs,
          status: "failure",
          errorMessage: error.message,
        });
      } catch (logError) {
        console.error("[gap-analysis] Failed to log AI usage:", logError.message);
      }

      // Gaps are returned without recommendations -- this is intentional
    }
  }
}

// Export for testing
export {
  detectCategoryGaps,
  detectWeatherGaps,
  detectFormalityGaps,
  detectColorGaps,
  buildGapPrompt,
  estimateCost,
  CORE_CATEGORIES,
  COLOR_GROUPS,
  SEVERITY_ORDER,
};
