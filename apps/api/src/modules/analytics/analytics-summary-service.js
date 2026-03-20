/**
 * Analytics summary service using Gemini 2.0 Flash via Vertex AI.
 *
 * Generates a short, AI-powered summary of the user's wardrobe analytics
 * by aggregating all 6 analytics datasets and prompting Gemini for insights.
 * Follows the same factory pattern as outfit-generation-service.js.
 */

const SUMMARY_MODEL = "gemini-2.0-flash";

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
 * Build the Gemini prompt for analytics summary generation.
 *
 * @param {object} params - Aggregated analytics data.
 * @returns {string} The prompt text.
 */
function buildAnalyticsPrompt({
  totalItems,
  totalValue,
  averageCpw,
  pricedItems,
  totalWears,
  currency,
  topWornItems,
  neglectedCount,
  categoryDistribution,
  wearFrequency,
}) {
  const currencySymbol = currency || "£";

  // Format top 3 worn items
  const top3Items = (topWornItems || [])
    .slice(0, 3)
    .map((item) => `${item.name} (${item.category}): ${item.wearCount} wears`)
    .join(", ") || "None";

  // Format top 3 categories
  const top3Categories = (categoryDistribution || [])
    .slice(0, 3)
    .map((cat) => `${cat.category}: ${cat.itemCount} items (${cat.percentage}%)`)
    .join(", ") || "None";

  // Find most/least active days
  const sortedDays = [...(wearFrequency || [])].sort(
    (a, b) => b.logCount - a.logCount
  );
  const mostActiveDay =
    sortedDays.length > 0
      ? `${sortedDays[0].day} with ${sortedDays[0].logCount} logs`
      : "N/A";
  const leastActiveDay =
    sortedDays.length > 0
      ? `${sortedDays[sortedDays.length - 1].day} with ${sortedDays[sortedDays.length - 1].logCount} logs`
      : "N/A";

  return `You are a friendly wardrobe analytics advisor. Generate a short, encouraging summary (2-4 sentences) of this user's wardrobe analytics.

ANALYTICS DATA:
- Total items: ${totalItems}
- Wardrobe value: ${currencySymbol}${totalValue}
- Average cost-per-wear: ${currencySymbol}${averageCpw != null ? averageCpw.toFixed(2) : "N/A"} (green < 5, yellow 5-20, red > 20)
- Items with price set: ${pricedItems} of ${totalItems}
- Total wears across priced items: ${totalWears}
- Top 3 most worn items: ${top3Items}
- Neglected items count: ${neglectedCount} items not worn in 60+ days
- Category distribution: ${top3Categories}
- Most active day: ${mostActiveDay}
- Least active day: ${leastActiveDay}

RULES:
1. Highlight ONE specific positive habit (e.g., great CPW, consistent wearing, balanced wardrobe).
2. Suggest ONE constructive improvement (e.g., wear neglected items, diversify categories).
3. Reference specific numbers from the data (e.g., "Your ${currencySymbol}4.20 average cost-per-wear shows great value").
4. Keep tone encouraging, not judgmental. Use "you" voice.
5. Do NOT mention premium status, app features, or technical details.
6. Maximum 4 sentences.

Return ONLY valid JSON:
{ "summary": "Your wardrobe summary text here..." }`;
}

/**
 * @param {object} options
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.analyticsRepository - Analytics repository with 6 query methods.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool (kept for backward compat).
 * @param {object} options.premiumGuard - Premium guard utility for premium checks.
 */
export function createAnalyticsSummaryService({
  geminiClient,
  analyticsRepository,
  aiUsageLogRepo,
  pool,
  premiumGuard,
}) {
  return {
    /**
     * Generate an AI-powered analytics summary for the authenticated user.
     *
     * @param {object} authContext - Auth context with userId.
     * @returns {Promise<{ summary: string, isGeneric: boolean }>}
     */
    async generateSummary(authContext) {
      // Step 1: Check Gemini availability
      if (!geminiClient.isAvailable()) {
        throw { statusCode: 503, message: "AI service unavailable" };
      }

      // Step 2: Require premium status via premiumGuard
      await premiumGuard.requirePremium(authContext);

      const startTime = Date.now();

      try {
        // Step 3: Fetch all 6 analytics datasets in parallel
        const [
          wardrobeSummary,
          itemsCpw,
          topWornItems,
          neglectedItems,
          categoryDistribution,
          wearFrequency,
        ] = await Promise.all([
          analyticsRepository.getWardrobeSummary(authContext),
          analyticsRepository.getItemsWithCpw(authContext),
          analyticsRepository.getTopWornItems(authContext),
          analyticsRepository.getNeglectedItems(authContext),
          analyticsRepository.getCategoryDistribution(authContext),
          analyticsRepository.getWearFrequency(authContext),
        ]);

        // Step 4: Check if wardrobe is empty
        if (wardrobeSummary.totalItems === 0) {
          return {
            summary:
              "Start adding items to your wardrobe to get personalized AI insights about your style and spending habits!",
            isGeneric: true,
          };
        }

        // Step 5: Build the Gemini prompt
        const prompt = buildAnalyticsPrompt({
          totalItems: wardrobeSummary.totalItems,
          totalValue: wardrobeSummary.totalValue,
          averageCpw: wardrobeSummary.averageCpw,
          pricedItems: wardrobeSummary.pricedItems,
          totalWears: wardrobeSummary.totalWears,
          currency: wardrobeSummary.dominantCurrency,
          topWornItems,
          neglectedCount: neglectedItems.length,
          categoryDistribution,
          wearFrequency,
        });

        // Step 6: Call Gemini
        const model = await geminiClient.getGenerativeModel(SUMMARY_MODEL);
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

        // Step 7: Parse and validate the JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        if (!parsed.summary || typeof parsed.summary !== "string") {
          throw new Error("Invalid response: missing or empty summary");
        }

        // Truncate to 500 characters if longer
        let summaryText = parsed.summary;
        if (summaryText.length > 500) {
          summaryText = summaryText.substring(0, 500);
        }

        // Step 8: Log AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "analytics_summary",
            model: SUMMARY_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success",
          });
        } catch (logError) {
          console.error(
            "[analytics-summary] Failed to log AI usage:",
            logError.message
          );
        }

        return {
          summary: summaryText,
          isGeneric: false,
        };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        // If the error has a statusCode, it's a known validation error -- re-throw as-is
        if (error.statusCode) {
          throw error;
        }

        console.error("[analytics-summary] Failed:", error.message);

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "analytics_summary",
            model: SUMMARY_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message,
          });
        } catch (logError) {
          console.error(
            "[analytics-summary] Failed to log AI usage:",
            logError.message
          );
        }

        throw {
          statusCode: 500,
          message: "Analytics summary generation failed",
        };
      }
    },
  };
}

// Export for testing
export { buildAnalyticsPrompt, estimateCost };
