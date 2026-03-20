import assert from "node:assert/strict";
import test from "node:test";
import {
  createOutfitGenerationService,
  buildPrompt,
  serializeItemsForPrompt,
} from "../../../src/modules/outfits/outfit-generation-service.js";

function createTestItems(count = 5) {
  const items = [];
  for (let i = 0; i < count; i++) {
    items.push({
      id: `item-${i + 1}`,
      name: `Test Item ${i + 1}`,
      category: i % 2 === 0 ? "tops" : "bottoms",
      color: "blue",
      secondaryColors: [],
      pattern: "solid",
      material: "cotton",
      style: "casual",
      season: ["spring", "summer"],
      occasion: ["everyday"],
      photoUrl: `https://example.com/photo-${i + 1}.jpg`,
      categorizationStatus: "completed",
      createdAt: new Date(2026, 0, i + 1).toISOString(),
    });
  }
  return items;
}

function createMockGeminiClient() {
  const calls = [];
  const defaultResponse = {
    suggestions: [
      {
        name: "Casual Blue Look",
        itemIds: ["item-1", "item-2", "item-3"],
        explanation: "A comfortable outfit for a mild spring day.",
        occasion: "everyday",
      },
    ],
  };

  return {
    calls,
    isAvailable() { return true; },
    async getGenerativeModel(modelName) {
      calls.push({ method: "getGenerativeModel", modelName });
      return {
        async generateContent(request) {
          calls.push({ method: "generateContent", request });
          return {
            response: {
              candidates: [
                {
                  content: {
                    parts: [{ text: JSON.stringify(defaultResponse) }],
                  },
                },
              ],
              usageMetadata: {
                promptTokenCount: 1500,
                candidatesTokenCount: 400,
              },
            },
          };
        },
      };
    },
  };
}

function createMockItemRepo(items = null) {
  return {
    async listItems() { return items ?? createTestItems(); },
  };
}

function createMockAiUsageLogRepo() {
  return {
    async logUsage() { return { id: "log-1" }; },
  };
}

function createMockOutfitRepo(recentItems = []) {
  const calls = [];
  return {
    calls,
    async getRecentOutfitItems(authContext, options) {
      calls.push({ method: "getRecentOutfitItems", authContext, options });
      return recentItems;
    },
  };
}

const testAuthContext = { userId: "firebase-user-123" };
const testOutfitContext = {
  temperature: 18.5,
  feelsLike: 16.2,
  weatherCode: 0,
  weatherDescription: "Clear sky",
  clothingConstraints: {
    requiredCategories: [],
    preferredMaterials: [],
    avoidMaterials: [],
    temperatureCategory: "mild",
  },
  locationName: "Paris, France",
  date: "2026-03-14",
  dayOfWeek: "Saturday",
  season: "spring",
  temperatureCategory: "mild",
  calendarEvents: [],
};

// --- Integration: recency data flows through to the Gemini prompt ---

test("POST /v1/outfits/generate includes recently worn items in Gemini prompt when user has recent outfits", async () => {
  const recentItems = [
    { id: "item-1", name: "Test Item 1", category: "tops", color: "blue" },
  ];
  const geminiClient = createMockGeminiClient();
  const outfitRepo = createMockOutfitRepo(recentItems);

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo: createMockItemRepo(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    outfitRepo,
  });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(promptText.includes("RECENTLY WORN ITEMS"));
  assert.ok(promptText.includes("Test Item 1"));
});

test("POST /v1/outfits/generate does NOT include recency section when user has no recent outfits", async () => {
  const geminiClient = createMockGeminiClient();
  const outfitRepo = createMockOutfitRepo([]);

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo: createMockItemRepo(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    outfitRepo,
  });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(!promptText.includes("RECENTLY WORN ITEMS"));
});

test("POST /v1/outfits/generate still succeeds when recency query returns empty results", async () => {
  const geminiClient = createMockGeminiClient();
  const outfitRepo = createMockOutfitRepo([]);

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo: createMockItemRepo(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    outfitRepo,
  });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  assert.ok(result.suggestions.length >= 1);
  assert.ok(result.generatedAt);
});

test("POST /v1/outfits/generate includes small-wardrobe instruction when user has < 10 items", async () => {
  const recentItems = [
    { id: "item-1", name: "Test Item 1", category: "tops", color: "blue" },
  ];
  // Only 5 items in the wardrobe
  const geminiClient = createMockGeminiClient();
  const outfitRepo = createMockOutfitRepo(recentItems);

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo: createMockItemRepo(createTestItems(5)),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    outfitRepo,
  });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(promptText.includes("wardrobe is small"));
  assert.ok(promptText.includes("re-using recently worn items is acceptable"));
});

test("POST /v1/outfits/generate includes avoid-recency rule when user has >= 10 items", async () => {
  const recentItems = [
    { id: "item-1", name: "Test Item 1", category: "tops", color: "blue" },
  ];
  const geminiClient = createMockGeminiClient();
  const outfitRepo = createMockOutfitRepo(recentItems);

  // Create 12 items
  const items = createTestItems(12);
  // Update the mock Gemini response to use valid item IDs from the 12-item set
  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo: createMockItemRepo(items),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    outfitRepo,
  });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(promptText.includes("Avoid using items from the RECENTLY WORN list"));
});

test("POST /v1/outfits/generate response structure is unchanged (no new fields in response body)", async () => {
  const geminiClient = createMockGeminiClient();
  const outfitRepo = createMockOutfitRepo([
    { id: "item-1", name: "Test Item 1", category: "tops", color: "blue" },
  ]);

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo: createMockItemRepo(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
    outfitRepo,
  });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  // Response should only have suggestions and generatedAt
  const keys = Object.keys(result);
  assert.ok(keys.includes("suggestions"));
  assert.ok(keys.includes("generatedAt"));
  assert.equal(keys.length, 2);
});
