import assert from "node:assert/strict";
import test from "node:test";
import {
  createAnalyticsSummaryService,
  buildAnalyticsPrompt,
  estimateCost,
} from "../../../src/modules/analytics/analytics-summary-service.js";

// --- Test helpers ---

function createMockPremiumGuard({ isPremium = true, profileId = "profile-1" } = {}) {
  return {
    async requirePremium() {
      if (!isPremium) {
        throw { statusCode: 403, code: "PREMIUM_REQUIRED", message: "Premium subscription required" };
      }
      return { isPremium: true, profileId, premiumSource: "revenuecat" };
    },
  };
}

function createMockPool() {
  // Pool is still passed for backward compat but no longer used for premium check
  return {
    connect: async () => ({
      query: async () => ({ rows: [] }),
      release: () => {},
    }),
  };
}

function createMockGeminiClient({
  available = true,
  response = null,
  throwError = null,
} = {}) {
  return {
    isAvailable: () => available,
    getGenerativeModel: async () => ({
      generateContent: async () => {
        if (throwError) {
          throw throwError;
        }
        return {
          response: response || {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        summary:
                          "Your wardrobe of 10 items shows great value with a £12.50 average cost-per-wear. Consider wearing your neglected items more often.",
                      }),
                    },
                  ],
                },
              },
            ],
            usageMetadata: {
              promptTokenCount: 500,
              candidatesTokenCount: 100,
            },
          },
        };
      },
    }),
  };
}

function createMockAnalyticsRepository({
  totalItems = 10,
  empty = false,
} = {}) {
  return {
    getWardrobeSummary: async () => ({
      totalItems: empty ? 0 : totalItems,
      pricedItems: empty ? 0 : 7,
      totalValue: empty ? 0 : 1500.0,
      totalWears: empty ? 0 : 120,
      averageCpw: empty ? null : 12.5,
      dominantCurrency: empty ? null : "GBP",
    }),
    getItemsWithCpw: async () =>
      empty
        ? []
        : [
            {
              id: "item-1",
              name: "Blue Shirt",
              category: "tops",
              purchasePrice: 50.0,
              currency: "GBP",
              wearCount: 10,
              cpw: 5.0,
            },
          ],
    getTopWornItems: async () =>
      empty
        ? []
        : [
            {
              id: "item-1",
              name: "Fave Jacket",
              category: "outerwear",
              wearCount: 25,
            },
            {
              id: "item-2",
              name: "Daily Shirt",
              category: "tops",
              wearCount: 18,
            },
          ],
    getNeglectedItems: async () =>
      empty
        ? []
        : [
            {
              id: "item-3",
              name: "Old Dress",
              category: "dresses",
              daysSinceWorn: 168,
            },
          ],
    getCategoryDistribution: async () =>
      empty
        ? []
        : [
            { category: "tops", itemCount: 14, percentage: 56.0 },
            { category: "bottoms", itemCount: 8, percentage: 32.0 },
            { category: "shoes", itemCount: 3, percentage: 12.0 },
          ],
    getWearFrequency: async () =>
      empty
        ? []
        : [
            { day: "Mon", dayIndex: 0, logCount: 5 },
            { day: "Tue", dayIndex: 1, logCount: 3 },
            { day: "Wed", dayIndex: 2, logCount: 7 },
            { day: "Thu", dayIndex: 3, logCount: 2 },
            { day: "Fri", dayIndex: 4, logCount: 6 },
            { day: "Sat", dayIndex: 5, logCount: 8 },
            { day: "Sun", dayIndex: 6, logCount: 4 },
          ],
  };
}

function createMockAiUsageLogRepo() {
  const logs = [];
  return {
    logs,
    logUsage: async (authContext, params) => {
      logs.push(params);
      return { id: "log-1", ...params };
    },
  };
}

const authContext = {
  userId: "firebase-user-123",
  email: "user@example.com",
};

// --- Unit tests ---

test("generateSummary calls Gemini with correct prompt containing analytics data", async () => {
  let capturedPrompt = null;
  const geminiClient = {
    isAvailable: () => true,
    getGenerativeModel: async () => ({
      generateContent: async (request) => {
        capturedPrompt = request.contents[0].parts[0].text;
        return {
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        summary: "Your wardrobe is great!",
                      }),
                    },
                  ],
                },
              },
            ],
            usageMetadata: {
              promptTokenCount: 500,
              candidatesTokenCount: 100,
            },
          },
        };
      },
    }),
  };

  const service = createAnalyticsSummaryService({
    geminiClient,
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await service.generateSummary(authContext);

  assert.ok(capturedPrompt);
  assert.ok(capturedPrompt.includes("Total items: 10"));
  assert.ok(capturedPrompt.includes("Wardrobe value: GBP1500"));
  assert.ok(capturedPrompt.includes("Average cost-per-wear: GBP12.50"));
  assert.ok(capturedPrompt.includes("Fave Jacket (outerwear): 25 wears"));
  assert.ok(capturedPrompt.includes("tops: 14 items (56%)"));
  assert.ok(capturedPrompt.includes("Neglected items count: 1"));
});

test("generateSummary returns valid summary text from Gemini response", async () => {
  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  const result = await service.generateSummary(authContext);

  assert.ok(result.summary);
  assert.ok(typeof result.summary === "string");
  assert.equal(result.isGeneric, false);
  assert.ok(result.summary.includes("wardrobe"));
});

test("generateSummary throws 403 when user is not premium", async () => {
  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard({ isPremium: false }),
  });

  await assert.rejects(
    () => service.generateSummary(authContext),
    (error) => {
      assert.equal(error.statusCode, 403);
      assert.ok(error.message.includes("Premium"));
      return true;
    }
  );
});

test("generateSummary throws 503 when Gemini is unavailable", async () => {
  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await assert.rejects(
    () => service.generateSummary(authContext),
    (error) => {
      assert.equal(error.statusCode, 503);
      return true;
    }
  );
});

test("generateSummary returns generic message when wardrobe is empty (totalItems === 0)", async () => {
  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository: createMockAnalyticsRepository({ empty: true }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  const result = await service.generateSummary(authContext);

  assert.equal(result.isGeneric, true);
  assert.ok(result.summary.includes("Start adding items"));
});

test("generateSummary does NOT call Gemini when wardrobe is empty", async () => {
  let geminiCalled = false;
  const geminiClient = {
    isAvailable: () => true,
    getGenerativeModel: async () => {
      geminiCalled = true;
      return {
        generateContent: async () => ({
          response: {
            candidates: [
              {
                content: { parts: [{ text: '{"summary":"test"}' }] },
              },
            ],
            usageMetadata: {},
          },
        }),
      };
    },
  };

  const service = createAnalyticsSummaryService({
    geminiClient,
    analyticsRepository: createMockAnalyticsRepository({ empty: true }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await service.generateSummary(authContext);
  assert.equal(geminiCalled, false);
});

test("generateSummary logs successful usage to ai_usage_log with feature analytics_summary", async () => {
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo,
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await service.generateSummary(authContext);

  assert.equal(aiUsageLogRepo.logs.length, 1);
  assert.equal(aiUsageLogRepo.logs[0].feature, "analytics_summary");
  assert.equal(aiUsageLogRepo.logs[0].model, "gemini-2.0-flash");
  assert.equal(aiUsageLogRepo.logs[0].status, "success");
  assert.equal(aiUsageLogRepo.logs[0].inputTokens, 500);
  assert.equal(aiUsageLogRepo.logs[0].outputTokens, 100);
  assert.ok(aiUsageLogRepo.logs[0].latencyMs >= 0);
  assert.ok(typeof aiUsageLogRepo.logs[0].estimatedCostUsd === "number");
});

test("generateSummary logs failure to ai_usage_log when Gemini fails", async () => {
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient({
      throwError: new Error("Gemini network timeout"),
    }),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo,
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await assert.rejects(() => service.generateSummary(authContext));

  assert.equal(aiUsageLogRepo.logs.length, 1);
  assert.equal(aiUsageLogRepo.logs[0].feature, "analytics_summary");
  assert.equal(aiUsageLogRepo.logs[0].status, "failure");
  assert.ok(aiUsageLogRepo.logs[0].errorMessage.includes("Gemini network timeout"));
});

test("generateSummary handles unparseable Gemini JSON gracefully", async () => {
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient({
      response: {
        candidates: [
          {
            content: {
              parts: [{ text: "not valid json at all" }],
            },
          },
        ],
        usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 },
      },
    }),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo,
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await assert.rejects(
    () => service.generateSummary(authContext),
    (error) => {
      assert.equal(error.statusCode, 500);
      assert.ok(error.message.includes("Analytics summary generation failed"));
      return true;
    }
  );

  assert.equal(aiUsageLogRepo.logs[0].status, "failure");
});

test("generateSummary truncates summary to 500 characters", async () => {
  const longSummary = "A".repeat(600);

  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient({
      response: {
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({ summary: longSummary }),
                },
              ],
            },
          },
        ],
        usageMetadata: { promptTokenCount: 500, candidatesTokenCount: 200 },
      },
    }),
    analyticsRepository: createMockAnalyticsRepository(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  const result = await service.generateSummary(authContext);
  assert.equal(result.summary.length, 500);
});

test("generateSummary fetches all 6 analytics datasets in parallel", async () => {
  const callOrder = [];

  const analyticsRepository = {
    getWardrobeSummary: async () => {
      callOrder.push("summary");
      return {
        totalItems: 10,
        pricedItems: 7,
        totalValue: 1500,
        totalWears: 120,
        averageCpw: 12.5,
        dominantCurrency: "GBP",
      };
    },
    getItemsWithCpw: async () => {
      callOrder.push("cpw");
      return [];
    },
    getTopWornItems: async () => {
      callOrder.push("topWorn");
      return [];
    },
    getNeglectedItems: async () => {
      callOrder.push("neglected");
      return [];
    },
    getCategoryDistribution: async () => {
      callOrder.push("categoryDist");
      return [];
    },
    getWearFrequency: async () => {
      callOrder.push("wearFreq");
      return [];
    },
  };

  const service = createAnalyticsSummaryService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository,
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  await service.generateSummary(authContext);

  // All 6 should have been called
  assert.equal(callOrder.length, 6);
  assert.ok(callOrder.includes("summary"));
  assert.ok(callOrder.includes("cpw"));
  assert.ok(callOrder.includes("topWorn"));
  assert.ok(callOrder.includes("neglected"));
  assert.ok(callOrder.includes("categoryDist"));
  assert.ok(callOrder.includes("wearFreq"));
});

test("generateSummary handles empty neglected/top-worn arrays gracefully in prompt", async () => {
  let capturedPrompt = null;
  const geminiClient = {
    isAvailable: () => true,
    getGenerativeModel: async () => ({
      generateContent: async (request) => {
        capturedPrompt = request.contents[0].parts[0].text;
        return {
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        summary: "Your wardrobe is on track!",
                      }),
                    },
                  ],
                },
              },
            ],
            usageMetadata: { promptTokenCount: 300, candidatesTokenCount: 50 },
          },
        };
      },
    }),
  };

  const analyticsRepository = {
    ...createMockAnalyticsRepository(),
    getTopWornItems: async () => [],
    getNeglectedItems: async () => [],
  };

  const service = createAnalyticsSummaryService({
    geminiClient,
    analyticsRepository,
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    pool: createMockPool(),
    premiumGuard: createMockPremiumGuard(),
  });

  const result = await service.generateSummary(authContext);

  assert.ok(capturedPrompt.includes("Top 3 most worn items: None"));
  assert.ok(capturedPrompt.includes("Neglected items count: 0"));
  assert.ok(result.summary);
});

// --- buildAnalyticsPrompt tests ---

test("buildAnalyticsPrompt includes all analytics data in the prompt", () => {
  const prompt = buildAnalyticsPrompt({
    totalItems: 15,
    totalValue: 2000,
    averageCpw: 8.5,
    pricedItems: 12,
    totalWears: 200,
    currency: "GBP",
    topWornItems: [
      { name: "Jacket", category: "outerwear", wearCount: 30 },
    ],
    neglectedCount: 3,
    categoryDistribution: [
      { category: "tops", itemCount: 8, percentage: 53.3 },
    ],
    wearFrequency: [
      { day: "Mon", logCount: 5 },
      { day: "Tue", logCount: 2 },
    ],
  });

  assert.ok(prompt.includes("Total items: 15"));
  assert.ok(prompt.includes("GBP2000"));
  assert.ok(prompt.includes("GBP8.50"));
  assert.ok(prompt.includes("Jacket (outerwear): 30 wears"));
  assert.ok(prompt.includes("Neglected items count: 3"));
  assert.ok(prompt.includes("tops: 8 items (53.3%)"));
});

// --- estimateCost tests ---

test("estimateCost calculates cost based on token counts", () => {
  const cost = estimateCost({
    promptTokenCount: 1000,
    candidatesTokenCount: 500,
  });

  // (1000/1M)*0.075 + (500/1M)*0.30 = 0.000075 + 0.00015 = 0.000225
  assert.ok(Math.abs(cost - 0.000225) < 0.0001);
});

test("estimateCost returns 0 when no usage metadata", () => {
  assert.equal(estimateCost(null), 0);
  assert.equal(estimateCost({}), 0);
});
