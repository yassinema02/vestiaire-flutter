/**
 * Outfit generation service using Gemini 2.0 Flash via Vertex AI.
 *
 * Generates 3 outfit suggestions based on the user's wardrobe items,
 * weather context, and calendar events. Follows the same factory pattern
 * as categorization-service.js.
 */

import crypto from "node:crypto";

const OUTFIT_MODEL = "gemini-2.0-flash";

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
 * Serialize items for the Gemini prompt.
 * Strips null fields and limits to 200 items.
 */
function serializeItemsForPrompt(items) {
  // Sort by created_at desc and limit to 200
  const sorted = [...items].sort((a, b) => {
    const dateA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const dateB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return dateB - dateA;
  });
  const limited = sorted.slice(0, 200);

  return limited.map((item) => {
    const serialized = { id: item.id };
    if (item.name != null) serialized.name = item.name;
    if (item.category != null) serialized.category = item.category;
    if (item.color != null) serialized.color = item.color;
    if (item.secondaryColors != null && item.secondaryColors.length > 0) {
      serialized.secondaryColors = item.secondaryColors;
    }
    if (item.pattern != null) serialized.pattern = item.pattern;
    if (item.material != null) serialized.material = item.material;
    if (item.style != null) serialized.style = item.style;
    if (item.season != null) serialized.season = item.season;
    if (item.occasion != null) serialized.occasion = item.occasion;
    if (item.photoUrl != null) serialized.photoUrl = item.photoUrl;
    return serialized;
  });
}

/**
 * Build the Gemini prompt for outfit generation.
 * @param {object} outfitContext - Context about today (weather, calendar, etc.).
 * @param {Array} serializedItems - Serialized wardrobe items.
 * @param {object} [options]
 * @param {Array} [options.recentItems=[]] - Recently worn items to avoid.
 * @param {number} [options.wardrobeSize=0] - Total number of categorized items.
 */
function buildPrompt(outfitContext, serializedItems, { recentItems = [], wardrobeSize = 0 } = {}) {
  const calendarEventsStr =
    outfitContext.calendarEvents && outfitContext.calendarEvents.length > 0
      ? JSON.stringify(outfitContext.calendarEvents)
      : "No events scheduled";

  const recencySection = recentItems.length > 0
    ? `\nRECENTLY WORN ITEMS (avoid these unless the wardrobe is too small):\n${JSON.stringify(recentItems)}\n`
    : "";

  let recencyRule = "";
  if (recentItems.length > 0) {
    recencyRule = wardrobeSize >= 10
      ? "\n8. Avoid using items from the RECENTLY WORN list unless absolutely necessary for a complete outfit. Prefer items that haven't been worn recently to keep the wardrobe rotation varied."
      : "\n8. The wardrobe is small (fewer than 10 items), so re-using recently worn items is acceptable. Still try to vary selections where possible.";
  }

  return `You are a personal stylist AI. Generate 3 outfit suggestions for today based on the user's wardrobe and context.

TODAY'S CONTEXT:
- Date: ${outfitContext.date} (${outfitContext.dayOfWeek})
- Season: ${outfitContext.season}
- Weather: ${outfitContext.weatherDescription}, ${outfitContext.temperature}\u00B0C (feels like ${outfitContext.feelsLike}\u00B0C)
- Location: ${outfitContext.locationName}
- Clothing constraints: ${JSON.stringify(outfitContext.clothingConstraints)}
- Calendar events: ${calendarEventsStr}

WARDROBE ITEMS (pick from these ONLY \u2014 use exact item IDs):
${JSON.stringify(serializedItems)}
${recencySection}
RULES:
1. Each outfit must contain 2-7 items from the wardrobe list above.
2. Use ONLY item IDs that exist in the wardrobe list. Do NOT invent IDs.
3. Create complete, wearable outfits (at minimum: a top + bottom, or a dress).
4. Respect the weather constraints: avoid materials in the "avoidMaterials" list, prefer materials in "preferredMaterials", include required categories.
5. If calendar events exist, make at least one outfit appropriate for the most formal event.
6. Vary the suggestions \u2014 do not repeat the same items across all 3 outfits.
7. For each outfit, provide a 1-2 sentence explanation of WHY this outfit works for today.${recencyRule}

Return ONLY valid JSON with this exact structure:
{
  "suggestions": [
    {
      "name": "Short descriptive outfit name",
      "itemIds": ["uuid-1", "uuid-2", "uuid-3"],
      "explanation": "Why this outfit works for today...",
      "occasion": "one of: everyday, work, formal, party, date-night, outdoor, sport, casual"
    }
  ]
}`;
}

/**
 * Validate and enrich the Gemini response.
 */
function validateAndEnrichResponse(parsed, itemsMap) {
  if (!parsed || !Array.isArray(parsed.suggestions)) {
    throw new Error("Invalid response: missing suggestions array");
  }

  const validSuggestions = [];

  for (const suggestion of parsed.suggestions.slice(0, 3)) {
    // Validate itemIds
    if (!Array.isArray(suggestion.itemIds)) continue;
    if (suggestion.itemIds.length < 2 || suggestion.itemIds.length > 7) continue;

    // Validate all item IDs exist
    const allValid = suggestion.itemIds.every((id) => itemsMap.has(id));
    if (!allValid) continue;

    // Validate name and explanation
    if (typeof suggestion.name !== "string" || !suggestion.name.trim()) continue;
    if (typeof suggestion.explanation !== "string" || !suggestion.explanation.trim()) continue;

    // Default occasion
    const occasion =
      typeof suggestion.occasion === "string" && suggestion.occasion.trim()
        ? suggestion.occasion
        : "everyday";

    // Enrich with full item data
    const enrichedItems = suggestion.itemIds.map((id) => {
      const item = itemsMap.get(id);
      return {
        id: item.id,
        name: item.name ?? null,
        category: item.category ?? null,
        color: item.color ?? null,
        photoUrl: item.photoUrl ?? null,
      };
    });

    validSuggestions.push({
      id: crypto.randomUUID(),
      name: suggestion.name,
      items: enrichedItems,
      explanation: suggestion.explanation,
      occasion,
    });
  }

  return validSuggestions;
}

/**
 * Build the Gemini prompt for event-specific outfit generation.
 * @param {object} event - Event data (title, eventType, formalityScore, startTime, endTime, location).
 * @param {object} outfitContext - Context about today (weather, calendar, etc.).
 * @param {Array} serializedItems - Serialized wardrobe items.
 */
function buildEventPrompt(event, outfitContext, serializedItems) {
  return `You are a personal stylist AI. Generate 3 outfit suggestions specifically for the following event.

EVENT:
- Title: ${event.title}
- Type: ${event.eventType} (work/social/active/formal/casual)
- Formality Score: ${event.formalityScore}/10
- Time: ${event.startTime} to ${event.endTime}
- Location: ${event.location || "Not specified"}

TODAY'S CONTEXT:
- Date: ${outfitContext.date} (${outfitContext.dayOfWeek})
- Season: ${outfitContext.season}
- Weather: ${outfitContext.weatherDescription}, ${outfitContext.temperature}\u00B0C (feels like ${outfitContext.feelsLike}\u00B0C)
- Clothing constraints: ${JSON.stringify(outfitContext.clothingConstraints)}

WARDROBE ITEMS (pick from these ONLY \u2014 use exact item IDs):
${JSON.stringify(serializedItems)}

RULES:
1. Each outfit must contain 2-7 items from the wardrobe list above.
2. Use ONLY item IDs that exist in the wardrobe list. Do NOT invent IDs.
3. ALL 3 outfits must be appropriate for the event's formality level (${event.formalityScore}/10).
4. For "formal" events (formality >= 7): prioritize blazers, dress shirts, tailored trousers, heels, structured bags.
5. For "active" events (formality <= 2): prioritize sportswear, trainers, breathable fabrics.
6. For "work" events (formality 4-6): smart-casual to business casual depending on score.
7. Respect the weather constraints: avoid avoidMaterials, prefer preferredMaterials.
8. Vary the 3 suggestions -- offer different style interpretations of the same formality level.
9. For each outfit, explain WHY it suits this specific event.

Return ONLY valid JSON with this exact structure:
{
  "suggestions": [
    {
      "name": "Short descriptive outfit name",
      "itemIds": ["uuid-1", "uuid-2", "uuid-3"],
      "explanation": "Why this outfit works for [event title]...",
      "occasion": "one of: everyday, work, formal, party, date-night, outdoor, sport, casual"
    }
  ]
}`;
}

/**
 * @param {object} options
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.itemRepo - Item repository with listItems method.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 * @param {object} [options.outfitRepo] - Outfit repository for recency queries (optional for backward compat).
 */
export function createOutfitGenerationService({
  geminiClient,
  itemRepo,
  aiUsageLogRepo,
  outfitRepo,
}) {
  return {
    /**
     * Generate outfit suggestions using Gemini AI.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {object} params.outfitContext - The outfit context from the mobile client.
     * @returns {Promise<{ suggestions: Array, generatedAt: string }>}
     */
    async generateOutfits(authContext, { outfitContext }) {
      if (!geminiClient.isAvailable()) {
        throw { statusCode: 503, message: "AI service unavailable" };
      }

      const startTime = Date.now();

      try {
        // Step 1: Fetch all user items
        const allItems = await itemRepo.listItems(authContext, {});

        // Step 2: Filter to only completed categorization
        const categorizedItems = allItems.filter(
          (item) => item.categorizationStatus === "completed"
        );

        // Step 3: Check minimum count
        if (categorizedItems.length < 3) {
          throw {
            statusCode: 400,
            message: "At least 3 categorized items required",
          };
        }

        // Step 4: Serialize items for prompt
        const serializedItems = serializeItemsForPrompt(categorizedItems);

        // Step 4b: Fetch recently worn items for recency bias mitigation
        let recentItems = [];
        if (outfitRepo) {
          recentItems = await outfitRepo.getRecentOutfitItems(authContext, { days: 7 });
        }

        // Step 5: Build prompt
        const prompt = buildPrompt(outfitContext, serializedItems, {
          recentItems,
          wardrobeSize: categorizedItems.length,
        });

        // Step 6: Call Gemini
        const model = await geminiClient.getGenerativeModel(OUTFIT_MODEL);
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

        // Step 7: Parse the JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        // Step 8: Build items map for validation
        const itemsMap = new Map(
          categorizedItems.map((item) => [item.id, item])
        );

        // Step 9: Validate and enrich
        const suggestions = validateAndEnrichResponse(parsed, itemsMap);

        if (suggestions.length === 0) {
          throw new Error(
            "No valid suggestions after validation"
          );
        }

        // Step 10: Log AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "outfit_generation",
            model: OUTFIT_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success",
          });
        } catch (logError) {
          console.error(
            "[outfit-generation] Failed to log AI usage:",
            logError.message
          );
        }

        return {
          suggestions,
          generatedAt: new Date().toISOString(),
        };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        // If the error has a statusCode, it's a known validation error -- re-throw as-is
        if (error.statusCode) {
          throw error;
        }

        console.error("[outfit-generation] Failed:", error.message);

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "outfit_generation",
            model: OUTFIT_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message,
          });
        } catch (logError) {
          console.error(
            "[outfit-generation] Failed to log AI usage:",
            logError.message
          );
        }

        throw {
          statusCode: 500,
          message: "Outfit generation failed",
        };
      }
    },

    /**
     * Generate outfit suggestions for a specific calendar event using Gemini AI.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {object} params.outfitContext - The outfit context from the mobile client.
     * @param {object} params.event - Event data (title, eventType, formalityScore, startTime, endTime, location).
     * @returns {Promise<{ suggestions: Array, generatedAt: string }>}
     */
    async generateOutfitsForEvent(authContext, { outfitContext, event }) {
      // Validate event input
      if (!event || typeof event !== "object") {
        throw { statusCode: 400, message: "Event data is required" };
      }
      if (!event.title || typeof event.title !== "string") {
        throw { statusCode: 400, message: "Event title is required" };
      }
      if (!event.eventType || typeof event.eventType !== "string") {
        throw { statusCode: 400, message: "Event eventType is required" };
      }
      if (event.formalityScore == null || typeof event.formalityScore !== "number") {
        throw { statusCode: 400, message: "Event formalityScore is required" };
      }

      if (!geminiClient.isAvailable()) {
        throw { statusCode: 503, message: "AI service unavailable" };
      }

      const startTime = Date.now();

      try {
        // Step 1: Fetch all user items
        const allItems = await itemRepo.listItems(authContext, {});

        // Step 2: Filter to only completed categorization
        const categorizedItems = allItems.filter(
          (item) => item.categorizationStatus === "completed"
        );

        // Step 3: Check minimum count
        if (categorizedItems.length < 3) {
          throw {
            statusCode: 400,
            message: "At least 3 categorized items required",
          };
        }

        // Step 4: Serialize items for prompt
        const serializedItems = serializeItemsForPrompt(categorizedItems);

        // Step 5: Build event-specific prompt
        const prompt = buildEventPrompt(event, outfitContext, serializedItems);

        // Step 6: Call Gemini
        const model = await geminiClient.getGenerativeModel(OUTFIT_MODEL);
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

        // Step 7: Parse the JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        // Step 8: Build items map for validation
        const itemsMap = new Map(
          categorizedItems.map((item) => [item.id, item])
        );

        // Step 9: Validate and enrich (reuse shared helper)
        const suggestions = validateAndEnrichResponse(parsed, itemsMap);

        if (suggestions.length === 0) {
          throw new Error(
            "No valid suggestions after validation"
          );
        }

        // Step 10: Log AI usage with event-specific feature name
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "event_outfit_generation",
            model: OUTFIT_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success",
          });
        } catch (logError) {
          console.error(
            "[outfit-generation] Failed to log AI usage:",
            logError.message
          );
        }

        return {
          suggestions,
          generatedAt: new Date().toISOString(),
        };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        // If the error has a statusCode, it's a known validation error -- re-throw as-is
        if (error.statusCode) {
          throw error;
        }

        console.error("[outfit-generation] Event generation failed:", error.message);

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "event_outfit_generation",
            model: OUTFIT_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message,
          });
        } catch (logError) {
          console.error(
            "[outfit-generation] Failed to log AI usage:",
            logError.message
          );
        }

        throw {
          statusCode: 500,
          message: "Event outfit generation failed",
        };
      }
    },

    /**
     * Generate a concise event preparation tip using Gemini AI.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {object} params.event - Event data (title, eventType, formalityScore, startTime).
     * @param {Array} [params.outfitItems] - Optional outfit items with name, category, material, color.
     * @returns {Promise<{ tip: string }>}
     */
    async generateEventPrepTip(authContext, { event, outfitItems }) {
      // Validate event input
      if (!event || typeof event !== "object") {
        throw { statusCode: 400, message: "Event data is required" };
      }
      if (!event.title || typeof event.title !== "string") {
        throw { statusCode: 400, message: "Event title is required" };
      }
      if (event.formalityScore == null || typeof event.formalityScore !== "number") {
        throw { statusCode: 400, message: "Event formalityScore is required" };
      }

      if (!geminiClient.isAvailable()) {
        throw { statusCode: 503, message: "AI service unavailable" };
      }

      const startTime = Date.now();

      try {
        // Build prompt
        const prompt = buildEventPrepTipPrompt(event, outfitItems);

        // Call Gemini
        const model = await geminiClient.getGenerativeModel(OUTFIT_MODEL);
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

        // Parse the JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        if (!parsed || typeof parsed.tip !== "string") {
          throw new Error("Invalid response: missing tip field");
        }

        // Truncate tip to 100 characters
        const tip = parsed.tip.substring(0, 100);

        // Log AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "event_prep_tip",
            model: OUTFIT_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success",
          });
        } catch (logError) {
          console.error(
            "[outfit-generation] Failed to log AI usage:",
            logError.message
          );
        }

        return { tip };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        // If the error has a statusCode, it's a known validation error -- re-throw as-is
        if (error.statusCode) {
          throw error;
        }

        console.error("[outfit-generation] Event prep tip generation failed:", error.message);

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "event_prep_tip",
            model: OUTFIT_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message,
          });
        } catch (logError) {
          console.error(
            "[outfit-generation] Failed to log AI usage:",
            logError.message
          );
        }

        // Return fallback tip instead of throwing 500
        return { tip: getFallbackPrepTip(event.formalityScore) };
      }
    },

    /**
     * Generate a smart packing list for an upcoming trip using Gemini AI.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {object} params.trip - Trip data (destination, startDate, endDate, durationDays).
     * @param {Array|null} params.destinationWeather - Daily forecasts or null.
     * @param {Array} params.events - Events during the trip.
     * @param {Array} params.items - Categorized wardrobe items.
     * @returns {Promise<{ packingList: object, generatedAt: string }>}
     */
    async generatePackingList(authContext, { trip, destinationWeather, events, items }) {
      if (!items || items.length === 0) {
        throw { statusCode: 400, message: "No categorized items available for packing list" };
      }

      const startTime = Date.now();

      // Build the packing list prompt
      const prompt = buildPackingListPrompt(trip, destinationWeather, events, items);

      // Attempt Gemini generation
      if (!geminiClient.isAvailable()) {
        // Return fallback
        const fallbackList = buildFallbackPackingList(trip, events);
        return { packingList: fallbackList, generatedAt: new Date().toISOString() };
      }

      try {
        const model = await geminiClient.getGenerativeModel(OUTFIT_MODEL);
        const result = await model.generateContent({
          contents: [
            {
              role: "user",
              parts: [{ text: prompt }],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            maxOutputTokens: 4096,
          },
        });

        const response = result.response;
        const latencyMs = Date.now() - startTime;

        // Parse the JSON response
        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        // Validate and enrich the packing list
        const itemsMap = new Map(items.map((item) => [item.id, item]));
        const packingList = validateAndEnrichPackingList(parsed, itemsMap);

        // Log AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "packing_list_generation",
            model: OUTFIT_MODEL,
            inputTokens: usageMetadata.promptTokenCount ?? null,
            outputTokens: usageMetadata.candidatesTokenCount ?? null,
            latencyMs,
            estimatedCostUsd: estimateCost(usageMetadata),
            status: "success",
          });
        } catch (logError) {
          console.error("[outfit-generation] Failed to log AI usage:", logError.message);
        }

        return {
          packingList,
          generatedAt: new Date().toISOString(),
        };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        if (error.statusCode) {
          throw error;
        }

        console.error("[outfit-generation] Packing list generation failed:", error.message);

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "packing_list_generation",
            model: OUTFIT_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message,
          });
        } catch (logError) {
          console.error("[outfit-generation] Failed to log AI usage:", logError.message);
        }

        // Return fallback list instead of throwing
        const fallbackList = buildFallbackPackingList(trip, events);
        return { packingList: fallbackList, generatedAt: new Date().toISOString() };
      }
    },
  };
}

/**
 * Build a Gemini prompt for event preparation tip generation.
 * @param {object} event - Event data (title, eventType, formalityScore, startTime).
 * @param {Array} [outfitItems] - Optional array of outfit items with name, category, material, color.
 */
function buildEventPrepTipPrompt(event, outfitItems) {
  const itemsStr = outfitItems && outfitItems.length > 0
    ? JSON.stringify(outfitItems)
    : "No outfit items scheduled";

  return `You are a personal stylist AI. Generate a brief preparation tip for tomorrow's event.

EVENT:
- Title: ${event.title}
- Type: ${event.eventType}
- Formality Score: ${event.formalityScore}/10
- Time: ${event.startTime}

OUTFIT ITEMS (if scheduled):
${itemsStr}

Generate ONE concise preparation tip (max 100 characters) that is actionable and specific.
Focus on: ironing, steaming, dry cleaning, shoe care, accessory prep, or garment inspection.
If outfit items are provided, reference specific items by name/material.
If no outfit items, give a general formal event prep tip.

Return ONLY valid JSON: { "tip": "your tip here" }`;
}

/**
 * Get a fallback preparation tip based on formality level.
 * @param {number} formalityScore - Formality score (1-10).
 * @returns {string} Fallback tip.
 */
function getFallbackPrepTip(formalityScore) {
  if (formalityScore >= 9) {
    return "Consider dry cleaning and shoe polishing tonight.";
  }
  return "Check that your outfit is clean and pressed.";
}

/**
 * Build the Gemini prompt for packing list generation.
 */
function buildPackingListPrompt(trip, destinationWeather, events, items) {
  const serializedItems = serializeItemsForPrompt(items);

  const weatherStr = destinationWeather
    ? JSON.stringify(destinationWeather)
    : `Weather data unavailable - pack for variable conditions based on season: ${getCurrentSeason()}`;

  const eventsStr = events && events.length > 0
    ? JSON.stringify(events.map((e) => ({
        title: e.title,
        eventType: e.event_type || e.eventType || "casual",
        formalityScore: e.formality_score || e.formalityScore || 2,
        date: e.start_time || e.startTime,
      })))
    : "No specific events planned";

  return `You are a personal stylist AI. Generate a smart packing list for an upcoming trip.

TRIP:
- Destination: ${trip.destination}
- Duration: ${trip.durationDays} days (${trip.startDate} to ${trip.endDate})

DESTINATION WEATHER (daily forecast):
${weatherStr}

PLANNED EVENTS DURING TRIP:
${eventsStr}

WARDROBE ITEMS (select from these ONLY - use exact item IDs):
${JSON.stringify(serializedItems)}

RULES:
1. Select items from the wardrobe list above. Use ONLY item IDs that exist in the list.
2. Pack enough for ${trip.durationDays} days. Aim for versatile items that mix and match.
3. Account for ALL planned events - ensure appropriate formality for each.
4. Consider weather: if cold, include outerwear and warm layers. If rain expected, include waterproof items.
5. Minimize quantity: suggest outfit combinations that reuse items across days.
6. Group items by category: Tops, Bottoms, Outerwear, Shoes, Accessories, Essentials.
7. For "Essentials" category: suggest general travel essentials (toiletries bag, charger, etc.) as text-only items (no wardrobe ID).
8. For each wardrobe item, explain briefly why it's included.
9. Suggest day-by-day outfit combinations using the packed items.

Return ONLY valid JSON:
{
  "packingList": {
    "categories": [
      {
        "name": "Tops",
        "items": [
          { "itemId": "uuid-or-null", "name": "Item name", "reason": "Why packed" }
        ]
      }
    ],
    "dailyOutfits": [
      { "day": 1, "date": "YYYY-MM-DD", "outfitItemIds": ["uuid-1", "uuid-2"], "occasion": "description" }
    ],
    "tips": ["General packing tip 1", "Tip 2"]
  }
}`;
}

/**
 * Get the current season based on the date.
 */
function getCurrentSeason() {
  const month = new Date().getMonth();
  if (month >= 2 && month <= 4) return "spring";
  if (month >= 5 && month <= 7) return "summer";
  if (month >= 8 && month <= 10) return "autumn";
  return "winter";
}

/**
 * Validate and enrich a packing list response from Gemini.
 */
function validateAndEnrichPackingList(parsed, itemsMap) {
  const packingListData = parsed.packingList || parsed;

  const categories = [];
  if (Array.isArray(packingListData.categories)) {
    for (const category of packingListData.categories) {
      if (!category.name || !Array.isArray(category.items)) continue;

      const validItems = [];
      for (const item of category.items) {
        if (!item.name) continue;

        const enriched = {
          itemId: item.itemId || null,
          name: item.name,
          reason: item.reason || "",
          thumbnailUrl: null,
          category: category.name,
          color: null,
        };

        // Enrich with wardrobe data if item ID is valid
        if (item.itemId && itemsMap.has(item.itemId)) {
          const wardrobeItem = itemsMap.get(item.itemId);
          enriched.thumbnailUrl = wardrobeItem.photoUrl || null;
          enriched.color = wardrobeItem.color || null;
          enriched.name = item.name || wardrobeItem.name || "Item";
        }

        validItems.push(enriched);
      }

      if (validItems.length > 0) {
        categories.push({
          name: category.name,
          items: validItems,
        });
      }
    }
  }

  const dailyOutfits = [];
  if (Array.isArray(packingListData.dailyOutfits)) {
    for (const outfit of packingListData.dailyOutfits) {
      dailyOutfits.push({
        day: outfit.day || 1,
        date: outfit.date || "",
        outfitItemIds: Array.isArray(outfit.outfitItemIds) ? outfit.outfitItemIds : [],
        occasion: outfit.occasion || "",
      });
    }
  }

  const tips = Array.isArray(packingListData.tips) ? packingListData.tips : [];

  return {
    categories,
    dailyOutfits,
    tips,
    fallback: false,
    weatherUnavailable: false,
  };
}

/**
 * Build a fallback packing list when Gemini is unavailable.
 */
function buildFallbackPackingList(trip, events) {
  const days = trip.durationDays || 3;

  const categories = [
    {
      name: "Tops",
      items: Array.from({ length: days + 1 }, (_, i) => ({
        itemId: null,
        name: `Top ${i + 1}`,
        reason: "General packing recommendation",
        thumbnailUrl: null,
        category: "Tops",
        color: null,
      })),
    },
    {
      name: "Bottoms",
      items: Array.from({ length: Math.ceil(days / 2) }, (_, i) => ({
        itemId: null,
        name: `Bottom ${i + 1}`,
        reason: "General packing recommendation",
        thumbnailUrl: null,
        category: "Bottoms",
        color: null,
      })),
    },
    {
      name: "Outerwear",
      items: [
        {
          itemId: null,
          name: "Jacket or Coat",
          reason: "Versatile outer layer",
          thumbnailUrl: null,
          category: "Outerwear",
          color: null,
        },
      ],
    },
    {
      name: "Shoes",
      items: [
        {
          itemId: null,
          name: "Walking Shoes",
          reason: "Comfortable for travel",
          thumbnailUrl: null,
          category: "Shoes",
          color: null,
        },
        {
          itemId: null,
          name: "Dress Shoes",
          reason: "For formal occasions",
          thumbnailUrl: null,
          category: "Shoes",
          color: null,
        },
      ],
    },
    {
      name: "Essentials",
      items: [
        { itemId: null, name: "Toiletries bag", reason: "Travel essential", thumbnailUrl: null, category: "Essentials", color: null },
        { itemId: null, name: "Phone charger", reason: "Travel essential", thumbnailUrl: null, category: "Essentials", color: null },
        { itemId: null, name: "Travel documents", reason: "Travel essential", thumbnailUrl: null, category: "Essentials", color: null },
      ],
    },
  ];

  return {
    categories,
    dailyOutfits: [],
    tips: [
      "Roll clothes to save space and reduce wrinkles.",
      "Pack versatile items that mix and match.",
      "Wear your heaviest items while traveling.",
    ],
    fallback: true,
    weatherUnavailable: true,
  };
}

// Export for testing
export { buildPrompt, buildEventPrompt, validateAndEnrichResponse, serializeItemsForPrompt, buildEventPrepTipPrompt, getFallbackPrepTip, buildPackingListPrompt, validateAndEnrichPackingList, buildFallbackPackingList, getCurrentSeason };
