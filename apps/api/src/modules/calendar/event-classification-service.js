/**
 * Event classification service using keyword matching and Gemini AI fallback.
 *
 * Classifies calendar events by type (work, social, active, formal, casual)
 * and computes a formality score (1-10). Keywords are tried first; Gemini 2.0
 * Flash is used only when keyword confidence is low.
 */

const CLASSIFICATION_MODEL = "gemini-2.0-flash";

const VALID_EVENT_TYPES = ["work", "social", "active", "formal", "casual"];

const KEYWORD_MAP = {
  work: {
    keywords: [
      "meeting", "standup", "review", "sprint", "presentation", "interview",
      "conference", "workshop", "training", "office", "call", "sync", "1:1",
      "demo", "deadline", "client"
    ],
    formalityScore: 5
  },
  social: {
    keywords: [
      "dinner", "lunch", "birthday", "party", "drinks", "brunch", "bbq",
      "hangout", "catch up", "reunion", "anniversary", "shower", "celebration"
    ],
    formalityScore: 3
  },
  active: {
    keywords: [
      "gym", "yoga", "run", "hike", "swim", "tennis", "football", "cycling",
      "pilates", "crossfit", "workout", "class", "match", "game", "practice"
    ],
    formalityScore: 1
  },
  formal: {
    keywords: [
      "wedding", "gala", "ceremony", "award", "fundraiser", "opera", "ballet",
      "black tie", "reception", "inauguration", "graduation", "funeral"
    ],
    formalityScore: 8
  }
};

/**
 * Classify an event by keyword matching on title and description.
 *
 * @param {string} title - Event title.
 * @param {string} [description] - Event description.
 * @returns {{ eventType: string, formalityScore: number, confidence: string }}
 */
export function classifyByKeywords(title, description) {
  const text = `${title ?? ""} ${description ?? ""}`.toLowerCase();

  for (const [eventType, config] of Object.entries(KEYWORD_MAP)) {
    for (const keyword of config.keywords) {
      if (text.includes(keyword)) {
        return {
          eventType,
          formalityScore: config.formalityScore,
          confidence: "high"
        };
      }
    }
  }

  return {
    eventType: "casual",
    formalityScore: 2,
    confidence: "low"
  };
}

/**
 * Estimate the cost of a Gemini API call.
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
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 */
export function createEventClassificationService({ geminiClient, aiUsageLogRepo }) {
  return {
    classifyByKeywords,

    /**
     * Classify an event using Gemini AI.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params - Event details.
     * @returns {Promise<{ eventType: string, formalityScore: number, classificationSource: string }>}
     */
    async classifyWithAI(authContext, { title, description, location, startTime }) {
      const startMs = Date.now();

      try {
        if (!geminiClient.isAvailable()) {
          throw new Error("Gemini client not available");
        }

        const prompt = `Classify this calendar event. Return JSON: { "eventType": "work"|"social"|"active"|"formal"|"casual", "formalityScore": 1-10 }. Event: title="${title}", description="${description ?? ""}", location="${location ?? ""}", time="${startTime}"`;

        const model = await geminiClient.getGenerativeModel(CLASSIFICATION_MODEL);
        const result = await model.generateContent({
          contents: [
            {
              role: "user",
              parts: [{ text: prompt }]
            }
          ],
          generationConfig: { responseMimeType: "application/json" }
        });

        const response = result.response;
        const latencyMs = Date.now() - startMs;

        const rawText = response.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText);

        // Validate response
        const eventType = VALID_EVENT_TYPES.includes(parsed.eventType)
          ? parsed.eventType
          : "casual";
        const formalityScore =
          typeof parsed.formalityScore === "number" &&
          parsed.formalityScore >= 1 &&
          parsed.formalityScore <= 10
            ? parsed.formalityScore
            : 2;

        // Log usage
        const usageMetadata = response?.usageMetadata ?? {};
        await aiUsageLogRepo.logUsage(authContext, {
          feature: "event_classification",
          model: CLASSIFICATION_MODEL,
          inputTokens: usageMetadata.promptTokenCount ?? null,
          outputTokens: usageMetadata.candidatesTokenCount ?? null,
          latencyMs,
          estimatedCostUsd: estimateCost(usageMetadata),
          status: "success"
        });

        return { eventType, formalityScore, classificationSource: "ai" };
      } catch (error) {
        const latencyMs = Date.now() - startMs;
        console.error("[event-classification] AI classification failed:", error.message);

        // Log failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "event_classification",
            model: CLASSIFICATION_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message
          });
        } catch (logError) {
          console.error("[event-classification] Failed to log AI usage:", logError.message);
        }

        // Fall back to keyword classification
        const keywordResult = classifyByKeywords(title, description);
        return {
          eventType: keywordResult.eventType,
          formalityScore: keywordResult.formalityScore,
          classificationSource: "keyword"
        };
      }
    },

    /**
     * Classify an event using keyword-first strategy with AI fallback.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params - Event details.
     * @returns {Promise<{ eventType: string, formalityScore: number, classificationSource: string }>}
     */
    async classifyEvent(authContext, { title, description, location, startTime }) {
      const keywordResult = classifyByKeywords(title, description);

      if (keywordResult.confidence === "high") {
        return {
          eventType: keywordResult.eventType,
          formalityScore: keywordResult.formalityScore,
          classificationSource: "keyword"
        };
      }

      // Low confidence -- try AI if available
      if (geminiClient && geminiClient.isAvailable()) {
        return this.classifyWithAI(authContext, { title, description, location, startTime });
      }

      // AI not available -- use keyword result
      return {
        eventType: keywordResult.eventType,
        formalityScore: keywordResult.formalityScore,
        classificationSource: "keyword"
      };
    }
  };
}
