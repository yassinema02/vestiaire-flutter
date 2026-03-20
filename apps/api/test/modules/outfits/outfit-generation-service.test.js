import assert from "node:assert/strict";
import test from "node:test";
import {
  createOutfitGenerationService,
  buildPrompt,
  buildEventPrompt,
  validateAndEnrichResponse,
  serializeItemsForPrompt,
  buildEventPrepTipPrompt,
  getFallbackPrepTip
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
      createdAt: new Date(2026, 0, i + 1).toISOString()
    });
  }
  return items;
}

function createMockGeminiClient({ shouldFail = false, isAvailable = true, responseJson = null } = {}) {
  const calls = [];
  const defaultResponse = {
    suggestions: [
      {
        name: "Casual Blue Look",
        itemIds: ["item-1", "item-2", "item-3"],
        explanation: "A comfortable outfit for a mild spring day.",
        occasion: "everyday"
      },
      {
        name: "Smart Spring",
        itemIds: ["item-2", "item-4", "item-5"],
        explanation: "Smart casual look for your afternoon meeting.",
        occasion: "work"
      },
      {
        name: "Weekend Vibes",
        itemIds: ["item-1", "item-4"],
        explanation: "Relaxed outfit for the weekend.",
        occasion: "casual"
      }
    ]
  };

  return {
    calls,
    isAvailable() {
      return isAvailable;
    },
    async getGenerativeModel(modelName) {
      calls.push({ method: "getGenerativeModel", modelName });
      return {
        async generateContent(request) {
          calls.push({ method: "generateContent", request });
          if (shouldFail) {
            throw new Error("Gemini API error: rate limit exceeded");
          }
          return {
            response: {
              candidates: [
                {
                  content: {
                    parts: [
                      {
                        text: JSON.stringify(responseJson ?? defaultResponse)
                      }
                    ]
                  }
                }
              ],
              usageMetadata: {
                promptTokenCount: 1500,
                candidatesTokenCount: 400
              }
            }
          };
        }
      };
    }
  };
}

function createMockItemRepo(items = null) {
  const calls = [];
  return {
    calls,
    async listItems(authContext, filters) {
      calls.push({ method: "listItems", authContext, filters });
      return items ?? createTestItems();
    }
  };
}

function createMockAiUsageLogRepo() {
  const calls = [];
  return {
    calls,
    async logUsage(authContext, params) {
      calls.push({ method: "logUsage", authContext, params });
      return { id: "log-1", ...params };
    }
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
    temperatureCategory: "mild"
  },
  locationName: "Paris, France",
  date: "2026-03-14",
  dayOfWeek: "Saturday",
  season: "spring",
  temperatureCategory: "mild",
  calendarEvents: []
};

test("generateOutfits calls Gemini with correct prompt structure containing weather context and item inventory", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  // Verify Gemini was called with correct model
  assert.equal(geminiClient.calls[0].method, "getGenerativeModel");
  assert.equal(geminiClient.calls[0].modelName, "gemini-2.0-flash");

  // Verify JSON mode was used
  const genContentCall = geminiClient.calls[1];
  assert.equal(genContentCall.request.generationConfig.responseMimeType, "application/json");

  // Verify prompt contains weather context
  const promptText = genContentCall.request.contents[0].parts[0].text;
  assert.ok(promptText.includes("Clear sky"));
  assert.ok(promptText.includes("18.5"));
  assert.ok(promptText.includes("Paris, France"));
  assert.ok(promptText.includes("Saturday"));
  assert.ok(promptText.includes("spring"));

  // Verify prompt contains item data
  assert.ok(promptText.includes("item-1"));
  assert.ok(promptText.includes("Test Item 1"));
});

test("generateOutfits returns validated suggestions with enriched item data", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  assert.ok(result.suggestions.length >= 1);
  assert.ok(result.generatedAt);

  const first = result.suggestions[0];
  assert.ok(first.id); // UUID assigned
  assert.equal(first.name, "Casual Blue Look");
  assert.equal(first.explanation, "A comfortable outfit for a mild spring day.");
  assert.equal(first.occasion, "everyday");

  // Items should be enriched with full data
  assert.equal(first.items.length, 3);
  assert.equal(first.items[0].id, "item-1");
  assert.equal(first.items[0].name, "Test Item 1");
  assert.equal(first.items[0].category, "tops");
  assert.equal(first.items[0].color, "blue");
  assert.ok(first.items[0].photoUrl);
});

test("generateOutfits discards suggestions with invalid item IDs", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: {
      suggestions: [
        {
          name: "Valid Outfit",
          itemIds: ["item-1", "item-2"],
          explanation: "Works well together.",
          occasion: "everyday"
        },
        {
          name: "Invalid Outfit",
          itemIds: ["item-1", "nonexistent-id"],
          explanation: "Has bad IDs.",
          occasion: "casual"
        }
      ]
    }
  });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  assert.equal(result.suggestions.length, 1);
  assert.equal(result.suggestions[0].name, "Valid Outfit");
});

test("generateOutfits throws error when fewer than 3 categorized items", async () => {
  const twoItems = [
    { id: "item-1", name: "Item 1", categorizationStatus: "completed", createdAt: new Date().toISOString() },
    { id: "item-2", name: "Item 2", categorizationStatus: "completed", createdAt: new Date().toISOString() }
  ];
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo(twoItems);
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.equal(error.message, "At least 3 categorized items required");
      return true;
    }
  );
});

test("generateOutfits throws 503 when Gemini is unavailable", async () => {
  const geminiClient = createMockGeminiClient({ isAvailable: false });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext }),
    (error) => {
      assert.equal(error.statusCode, 503);
      assert.equal(error.message, "AI service unavailable");
      return true;
    }
  );
});

test("generateOutfits logs successful usage to ai_usage_log", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "outfit_generation");
  assert.equal(aiUsageLogRepo.calls[0].params.model, "gemini-2.0-flash");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "success");
  assert.equal(aiUsageLogRepo.calls[0].params.inputTokens, 1500);
  assert.equal(aiUsageLogRepo.calls[0].params.outputTokens, 400);
  assert.ok(aiUsageLogRepo.calls[0].params.latencyMs >= 0);
  assert.ok(aiUsageLogRepo.calls[0].params.estimatedCostUsd >= 0);
});

test("generateOutfits logs failure to ai_usage_log when Gemini call fails", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext }),
    (error) => {
      assert.equal(error.statusCode, 500);
      assert.equal(error.message, "Outfit generation failed");
      return true;
    }
  );

  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.status, "failure");
  assert.ok(aiUsageLogRepo.calls[0].params.errorMessage.includes("rate limit"));
});

test("generateOutfits handles Gemini returning unparseable JSON gracefully", async () => {
  const calls = [];
  const geminiClient = {
    isAvailable() { return true; },
    async getGenerativeModel(modelName) {
      calls.push({ method: "getGenerativeModel", modelName });
      return {
        async generateContent() {
          return {
            response: {
              candidates: [{
                content: {
                  parts: [{ text: "This is not JSON at all!" }]
                }
              }],
              usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 10 }
            }
          };
        }
      };
    }
  };
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext }),
    (error) => {
      assert.equal(error.statusCode, 500);
      return true;
    }
  );

  assert.equal(aiUsageLogRepo.calls[0].params.status, "failure");
});

test("generateOutfits handles Gemini returning empty suggestions array", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { suggestions: [] }
  });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext }),
    (error) => {
      assert.equal(error.statusCode, 500);
      return true;
    }
  );
});

test("generateOutfits works with empty calendarEvents array", async () => {
  const contextWithNoEvents = { ...testOutfitContext, calendarEvents: [] };
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: contextWithNoEvents });

  assert.ok(result.suggestions.length >= 1);

  // Verify prompt contains "No events scheduled"
  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(promptText.includes("No events scheduled"));
});

test("generateOutfits limits items to 200 in the prompt", async () => {
  // Create 210 items
  const manyItems = [];
  for (let i = 0; i < 210; i++) {
    manyItems.push({
      id: `item-${i + 1}`,
      name: `Item ${i + 1}`,
      category: "tops",
      color: "blue",
      categorizationStatus: "completed",
      createdAt: new Date(2026, 0, i + 1).toISOString()
    });
  }

  // Also need at least the IDs in the mock response to exist in the first 200
  const geminiClient = createMockGeminiClient({
    responseJson: {
      suggestions: [
        {
          name: "Outfit",
          itemIds: ["item-210", "item-209"],
          explanation: "Nice combo.",
          occasion: "everyday"
        }
      ]
    }
  });
  const itemRepo = createMockItemRepo(manyItems);
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  // The prompt should contain at most 200 items
  // Items sorted by createdAt desc: item-210 (newest) through item-11 (200th)
  const promptText = geminiClient.calls?.[1]?.request?.contents?.[0]?.parts?.[0]?.text;

  // We can verify via serializeItemsForPrompt directly
  const serialized = serializeItemsForPrompt(manyItems);
  assert.equal(serialized.length, 200);
});

test("suggestion validation: filters out suggestions with < 2 or > 7 items", () => {
  const itemsMap = new Map([
    ["item-1", { id: "item-1", name: "Item 1", category: "tops", color: "blue", photoUrl: "url1" }],
    ["item-2", { id: "item-2", name: "Item 2", category: "bottoms", color: "black", photoUrl: "url2" }],
    ["item-3", { id: "item-3", name: "Item 3", category: "shoes", color: "brown", photoUrl: "url3" }],
    ["item-4", { id: "item-4", name: "Item 4", category: "accessories", color: "gold", photoUrl: "url4" }],
    ["item-5", { id: "item-5", name: "Item 5", category: "outerwear", color: "navy", photoUrl: "url5" }],
    ["item-6", { id: "item-6", name: "Item 6", category: "tops", color: "white", photoUrl: "url6" }],
    ["item-7", { id: "item-7", name: "Item 7", category: "bottoms", color: "gray", photoUrl: "url7" }],
    ["item-8", { id: "item-8", name: "Item 8", category: "bags", color: "brown", photoUrl: "url8" }],
  ]);

  const parsed = {
    suggestions: [
      { name: "Too few", itemIds: ["item-1"], explanation: "Only one item.", occasion: "everyday" },
      { name: "Just right", itemIds: ["item-1", "item-2"], explanation: "Perfect pair.", occasion: "everyday" },
      { name: "Too many", itemIds: ["item-1", "item-2", "item-3", "item-4", "item-5", "item-6", "item-7", "item-8"], explanation: "Eight items.", occasion: "everyday" }
    ]
  };

  const result = validateAndEnrichResponse(parsed, itemsMap);

  assert.equal(result.length, 1);
  assert.equal(result[0].name, "Just right");
});

test("each suggestion gets a UUID id assigned", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  for (const suggestion of result.suggestions) {
    assert.ok(suggestion.id);
    // UUID format check
    assert.ok(suggestion.id.length >= 36);
    assert.ok(suggestion.id.includes("-"));
  }
});

// --- Recency bias mitigation: buildPrompt tests ---

const sampleRecentItems = [
  { id: "item-1", name: "Navy Blazer", category: "blazer", color: "navy" },
  { id: "item-2", name: "White Shirt", category: "tops", color: "white" },
];

test("buildPrompt includes RECENTLY WORN ITEMS section when recentItems is non-empty", () => {
  const prompt = buildPrompt(testOutfitContext, [], { recentItems: sampleRecentItems, wardrobeSize: 15 });

  assert.ok(prompt.includes("RECENTLY WORN ITEMS"));
  assert.ok(prompt.includes("Navy Blazer"));
  assert.ok(prompt.includes("White Shirt"));
});

test("buildPrompt does NOT include RECENTLY WORN ITEMS section when recentItems is empty", () => {
  const prompt = buildPrompt(testOutfitContext, [], { recentItems: [], wardrobeSize: 15 });

  assert.ok(!prompt.includes("RECENTLY WORN ITEMS"));
});

test("buildPrompt does NOT include RECENTLY WORN ITEMS section when options omitted (backward compatible)", () => {
  const prompt = buildPrompt(testOutfitContext, []);

  assert.ok(!prompt.includes("RECENTLY WORN ITEMS"));
  assert.ok(!prompt.includes("rule 8"));
});

test("buildPrompt includes avoid-recency rule when wardrobeSize >= 10 and recentItems non-empty", () => {
  const prompt = buildPrompt(testOutfitContext, [], { recentItems: sampleRecentItems, wardrobeSize: 10 });

  assert.ok(prompt.includes("Avoid using items from the RECENTLY WORN list"));
  assert.ok(!prompt.includes("wardrobe is small"));
});

test("buildPrompt includes small-wardrobe instruction when wardrobeSize < 10 and recentItems non-empty", () => {
  const prompt = buildPrompt(testOutfitContext, [], { recentItems: sampleRecentItems, wardrobeSize: 5 });

  assert.ok(prompt.includes("wardrobe is small"));
  assert.ok(prompt.includes("re-using recently worn items is acceptable"));
  assert.ok(!prompt.includes("Avoid using items from the RECENTLY WORN list"));
});

test("buildPrompt does NOT include rule 8 when recentItems is empty (backward compatible)", () => {
  const prompt = buildPrompt(testOutfitContext, [], { recentItems: [], wardrobeSize: 15 });

  assert.ok(!prompt.includes("8. Avoid using items from the RECENTLY WORN list"));
  assert.ok(!prompt.includes("8. The wardrobe is small"));
});

// --- Recency bias mitigation: generateOutfits integration tests ---

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

test("generateOutfits calls outfitRepo.getRecentOutfitItems when outfitRepo is provided", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const outfitRepo = createMockOutfitRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo, outfitRepo });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  assert.equal(outfitRepo.calls.length, 1);
  assert.equal(outfitRepo.calls[0].method, "getRecentOutfitItems");
  assert.equal(outfitRepo.calls[0].authContext.userId, "firebase-user-123");
  assert.equal(outfitRepo.calls[0].options.days, 7);
});

test("generateOutfits works correctly when outfitRepo is null (backward compatibility)", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  assert.ok(result.suggestions.length >= 1);
  // Verify prompt does not include recency section
  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(!promptText.includes("RECENTLY WORN ITEMS"));
});

test("generateOutfits passes recentItems and wardrobeSize to buildPrompt", async () => {
  const recentItems = [{ id: "item-1", name: "Navy Blazer", category: "blazer", color: "navy" }];
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const outfitRepo = createMockOutfitRepo(recentItems);

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo, outfitRepo });

  await service.generateOutfits(testAuthContext, { outfitContext: testOutfitContext });

  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(promptText.includes("RECENTLY WORN ITEMS"));
  assert.ok(promptText.includes("Navy Blazer"));
});

// --- Event-specific generation tests (Story 12.1) ---

const testEvent = {
  title: "Sprint Planning",
  eventType: "work",
  formalityScore: 5,
  startTime: "2026-03-15T10:00:00.000Z",
  endTime: "2026-03-15T11:00:00.000Z",
  location: "Conference Room B",
};

test("generateOutfitsForEvent calls Gemini with event-specific prompt containing event title, type, formality", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: testEvent });

  // Verify Gemini was called
  assert.equal(geminiClient.calls[0].method, "getGenerativeModel");
  assert.equal(geminiClient.calls[0].modelName, "gemini-2.0-flash");

  // Verify event-specific prompt content
  const promptText = geminiClient.calls[1].request.contents[0].parts[0].text;
  assert.ok(promptText.includes("Sprint Planning"));
  assert.ok(promptText.includes("work"));
  assert.ok(promptText.includes("5/10"));
  assert.ok(promptText.includes("Conference Room B"));
  assert.ok(promptText.includes("specifically for the following event"));
});

test("generateOutfitsForEvent returns validated suggestions with enriched item data", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: testEvent });

  assert.ok(result.suggestions.length >= 1);
  assert.ok(result.generatedAt);

  const first = result.suggestions[0];
  assert.ok(first.id);
  assert.equal(first.name, "Casual Blue Look");
  assert.equal(first.items.length, 3);
  assert.equal(first.items[0].id, "item-1");
  assert.equal(first.items[0].name, "Test Item 1");
});

test("generateOutfitsForEvent logs usage with feature 'event_outfit_generation'", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: testEvent });

  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "event_outfit_generation");
  assert.equal(aiUsageLogRepo.calls[0].params.model, "gemini-2.0-flash");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "success");
});

test("generateOutfitsForEvent throws error when fewer than 3 categorized items", async () => {
  const twoItems = [
    { id: "item-1", name: "Item 1", categorizationStatus: "completed", createdAt: new Date().toISOString() },
    { id: "item-2", name: "Item 2", categorizationStatus: "completed", createdAt: new Date().toISOString() }
  ];
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo(twoItems);
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: testEvent }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.equal(error.message, "At least 3 categorized items required");
      return true;
    }
  );
});

test("generateOutfitsForEvent throws 503 when Gemini is unavailable", async () => {
  const geminiClient = createMockGeminiClient({ isAvailable: false });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: testEvent }),
    (error) => {
      assert.equal(error.statusCode, 503);
      assert.equal(error.message, "AI service unavailable");
      return true;
    }
  );
});

test("generateOutfitsForEvent handles Gemini failure gracefully", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: testEvent }),
    (error) => {
      assert.equal(error.statusCode, 500);
      assert.equal(error.message, "Event outfit generation failed");
      return true;
    }
  );

  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "event_outfit_generation");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "failure");
});

test("generateOutfitsForEvent validates event input - requires title", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: { eventType: "work", formalityScore: 5 } }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("title"));
      return true;
    }
  );
});

test("generateOutfitsForEvent validates event input - requires eventType", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: { title: "Test", formalityScore: 5 } }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("eventType"));
      return true;
    }
  );
});

test("generateOutfitsForEvent validates event input - requires formalityScore", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: { title: "Test", eventType: "work" } }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("formalityScore"));
      return true;
    }
  );
});

test("generateOutfitsForEvent throws 400 when event is null", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generateOutfitsForEvent(testAuthContext, { outfitContext: testOutfitContext, event: null }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("buildEventPrompt includes event context and wardrobe items", () => {
  const items = [{ id: "item-1", name: "Shirt", category: "tops" }];
  const prompt = buildEventPrompt(testEvent, testOutfitContext, items);

  assert.ok(prompt.includes("Sprint Planning"));
  assert.ok(prompt.includes("work"));
  assert.ok(prompt.includes("5/10"));
  assert.ok(prompt.includes("Conference Room B"));
  assert.ok(prompt.includes("item-1"));
  assert.ok(prompt.includes("Clear sky"));
  assert.ok(prompt.includes("spring"));
});

// --- Story 12.3: Event Prep Tip Generation Tests ---

test("generateEventPrepTip calls Gemini with event-specific prompt containing event title, type, formality", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { tip: "Iron your cotton blazer and steam the trousers" }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Annual Gala",
      eventType: "formal",
      formalityScore: 9,
      startTime: "2026-03-20T19:00:00Z"
    }
  });

  // Verify Gemini was called with a prompt containing event details
  const generateCall = geminiClient.calls.find(c => c.method === "generateContent");
  assert.ok(generateCall, "generateContent should have been called");
  const promptText = generateCall.request.contents[0].parts[0].text;
  assert.ok(promptText.includes("Annual Gala"), "prompt should include event title");
  assert.ok(promptText.includes("formal"), "prompt should include event type");
  assert.ok(promptText.includes("9/10"), "prompt should include formality score");
});

test("generateEventPrepTip returns parsed tip string", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { tip: "Iron your cotton blazer and steam the trousers" }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  const result = await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Annual Gala",
      eventType: "formal",
      formalityScore: 9,
      startTime: "2026-03-20T19:00:00Z"
    }
  });

  assert.equal(result.tip, "Iron your cotton blazer and steam the trousers");
});

test("generateEventPrepTip logs AI usage with feature 'event_prep_tip'", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { tip: "Check your shoes" }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Meeting",
      eventType: "work",
      formalityScore: 7,
      startTime: "2026-03-20T09:00:00Z"
    }
  });

  const logCall = aiUsageLogRepo.calls.find(c => c.method === "logUsage");
  assert.ok(logCall, "logUsage should have been called");
  assert.equal(logCall.params.feature, "event_prep_tip");
  assert.equal(logCall.params.status, "success");
});

test("generateEventPrepTip returns fallback tip when Gemini fails (formality 7-8)", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  const result = await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Meeting",
      eventType: "work",
      formalityScore: 7,
      startTime: "2026-03-20T09:00:00Z"
    }
  });

  assert.equal(result.tip, "Check that your outfit is clean and pressed.");
});

test("generateEventPrepTip returns fallback tip when Gemini fails (formality 9-10)", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  const result = await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Black Tie Dinner",
      eventType: "formal",
      formalityScore: 10,
      startTime: "2026-03-20T19:00:00Z"
    }
  });

  assert.equal(result.tip, "Consider dry cleaning and shoe polishing tonight.");
});

test("generateEventPrepTip includes outfit items in prompt when provided", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { tip: "Iron your linen shirt" }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Gala",
      eventType: "formal",
      formalityScore: 9,
      startTime: "2026-03-20T19:00:00Z"
    },
    outfitItems: [
      { name: "Linen Shirt", category: "tops", material: "linen", color: "white" }
    ]
  });

  const generateCall = geminiClient.calls.find(c => c.method === "generateContent");
  const promptText = generateCall.request.contents[0].parts[0].text;
  assert.ok(promptText.includes("Linen Shirt"), "prompt should include outfit item name");
  assert.ok(promptText.includes("linen"), "prompt should include outfit item material");
});

test("generateEventPrepTip works without outfit items", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { tip: "Prepare your formal attire" }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const itemRepo = createMockItemRepo();

  const service = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
  });

  const result = await service.generateEventPrepTip(testAuthContext, {
    event: {
      title: "Conference",
      eventType: "work",
      formalityScore: 8,
      startTime: "2026-03-20T09:00:00Z"
    }
  });

  assert.equal(result.tip, "Prepare your formal attire");

  const generateCall = geminiClient.calls.find(c => c.method === "generateContent");
  const promptText = generateCall.request.contents[0].parts[0].text;
  assert.ok(promptText.includes("No outfit items scheduled"), "prompt should indicate no outfit items");
});

// --- buildEventPrepTipPrompt tests ---

test("buildEventPrepTipPrompt includes event details in prompt", () => {
  const prompt = buildEventPrepTipPrompt(
    { title: "Test Event", eventType: "formal", formalityScore: 9, startTime: "2026-03-20T19:00:00Z" },
    null
  );
  assert.ok(prompt.includes("Test Event"));
  assert.ok(prompt.includes("formal"));
  assert.ok(prompt.includes("9/10"));
});

test("buildEventPrepTipPrompt includes outfit items when provided", () => {
  const prompt = buildEventPrepTipPrompt(
    { title: "Gala", eventType: "formal", formalityScore: 9, startTime: "2026-03-20T19:00:00Z" },
    [{ name: "Silk Dress", category: "dresses", material: "silk", color: "red" }]
  );
  assert.ok(prompt.includes("Silk Dress"));
  assert.ok(prompt.includes("silk"));
});

// --- getFallbackPrepTip tests ---

test("getFallbackPrepTip returns correct text for formality 7-8", () => {
  assert.equal(getFallbackPrepTip(7), "Check that your outfit is clean and pressed.");
  assert.equal(getFallbackPrepTip(8), "Check that your outfit is clean and pressed.");
});

test("getFallbackPrepTip returns correct text for formality 9-10", () => {
  assert.equal(getFallbackPrepTip(9), "Consider dry cleaning and shoe polishing tonight.");
  assert.equal(getFallbackPrepTip(10), "Consider dry cleaning and shoe polishing tonight.");
});

// --- Packing List Generation Tests ---
import { buildPackingListPrompt, validateAndEnrichPackingList, buildFallbackPackingList, getCurrentSeason } from "../../../src/modules/outfits/outfit-generation-service.js";

const testTrip = {
  destination: "Barcelona",
  startDate: "2026-03-20",
  endDate: "2026-03-24",
  durationDays: 4,
};

const testWeather = [
  { date: "2026-03-20", highTemp: 18, lowTemp: 12, weatherCode: 1 },
  { date: "2026-03-21", highTemp: 20, lowTemp: 14, weatherCode: 0 },
];

const testTripEvents = [
  { title: "Conference Day 1", event_type: "work", formality_score: 6, start_time: "2026-03-20T09:00:00Z" },
  { title: "Dinner", event_type: "social", formality_score: 7, start_time: "2026-03-21T19:00:00Z" },
];

test("generatePackingList calls Gemini with trip context, weather, events, and wardrobe items", async () => {
  const packingListResponse = {
    packingList: {
      categories: [
        { name: "Tops", items: [{ itemId: "item-1", name: "Test Item 1", reason: "Versatile top" }] },
        { name: "Bottoms", items: [{ itemId: "item-2", name: "Test Item 2", reason: "Classic bottom" }] },
      ],
      dailyOutfits: [
        { day: 1, date: "2026-03-20", outfitItemIds: ["item-1", "item-2"], occasion: "Conference" },
      ],
      tips: ["Roll clothes to save space"],
    }
  };

  const geminiClient = createMockGeminiClient({ responseJson: packingListResponse });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });
  const items = createTestItems();

  const result = await service.generatePackingList(testAuthContext, {
    trip: testTrip,
    destinationWeather: testWeather,
    events: testTripEvents,
    items,
  });

  assert.ok(result.packingList);
  assert.ok(result.generatedAt);
  assert.ok(result.packingList.categories.length >= 1);

  // Verify Gemini was called
  assert.ok(geminiClient.calls.some((c) => c.method === "generateContent"));
});

test("generatePackingList returns validated packing list with enriched item data", async () => {
  const packingListResponse = {
    packingList: {
      categories: [
        { name: "Tops", items: [{ itemId: "item-1", name: "Blue Top", reason: "Versatile" }] },
      ],
      dailyOutfits: [],
      tips: [],
    }
  };

  const geminiClient = createMockGeminiClient({ responseJson: packingListResponse });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });
  const items = createTestItems();

  const result = await service.generatePackingList(testAuthContext, {
    trip: testTrip,
    destinationWeather: testWeather,
    events: testTripEvents,
    items,
  });

  // Enriched item should have thumbnailUrl from wardrobe
  const topItem = result.packingList.categories[0].items[0];
  assert.ok(topItem.thumbnailUrl);
  assert.equal(topItem.itemId, "item-1");
});

test("generatePackingList logs AI usage with feature packing_list_generation", async () => {
  const packingListResponse = {
    packingList: {
      categories: [{ name: "Tops", items: [{ itemId: "item-1", name: "Top", reason: "Why" }] }],
      dailyOutfits: [],
      tips: [],
    }
  };

  const geminiClient = createMockGeminiClient({ responseJson: packingListResponse });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });
  const items = createTestItems();

  await service.generatePackingList(testAuthContext, {
    trip: testTrip,
    destinationWeather: testWeather,
    events: testTripEvents,
    items,
  });

  const usageLog = aiUsageLogRepo.calls.find((c) => c.params.feature === "packing_list_generation");
  assert.ok(usageLog, "Should log AI usage with packing_list_generation feature");
  assert.equal(usageLog.params.status, "success");
});

test("generatePackingList returns fallback list when Gemini fails", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });
  const items = createTestItems();

  const result = await service.generatePackingList(testAuthContext, {
    trip: testTrip,
    destinationWeather: testWeather,
    events: testTripEvents,
    items,
  });

  assert.ok(result.packingList);
  assert.equal(result.packingList.fallback, true);
  assert.ok(result.packingList.categories.length > 0);
});

test("generatePackingList handles missing destination weather gracefully", async () => {
  const packingListResponse = {
    packingList: {
      categories: [{ name: "Tops", items: [{ itemId: "item-1", name: "Top", reason: "Why" }] }],
      dailyOutfits: [],
      tips: [],
    }
  };

  const geminiClient = createMockGeminiClient({ responseJson: packingListResponse });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });
  const items = createTestItems();

  const result = await service.generatePackingList(testAuthContext, {
    trip: testTrip,
    destinationWeather: null,
    events: testTripEvents,
    items,
  });

  assert.ok(result.packingList);
  assert.ok(result.generatedAt);
});

test("generatePackingList validates item IDs against wardrobe", async () => {
  const packingListResponse = {
    packingList: {
      categories: [
        { name: "Tops", items: [
          { itemId: "item-1", name: "Valid", reason: "Exists" },
          { itemId: "nonexistent-id", name: "Invalid", reason: "Does not exist" },
        ] },
      ],
      dailyOutfits: [],
      tips: [],
    }
  };

  const geminiClient = createMockGeminiClient({ responseJson: packingListResponse });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });
  const items = createTestItems();

  const result = await service.generatePackingList(testAuthContext, {
    trip: testTrip,
    destinationWeather: testWeather,
    events: [],
    items,
  });

  // Both items should be present (invalid IDs are kept but not enriched)
  const topItems = result.packingList.categories[0].items;
  assert.equal(topItems.length, 2);
  // Valid item has enriched thumbnailUrl
  assert.ok(topItems[0].thumbnailUrl);
  // Invalid item has null thumbnailUrl
  assert.equal(topItems[1].thumbnailUrl, null);
});

test("generatePackingList throws error when no categorized items available", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await assert.rejects(
    () => service.generatePackingList(testAuthContext, {
      trip: testTrip,
      destinationWeather: testWeather,
      events: [],
      items: [],
    }),
    (err) => err.statusCode === 400
  );
});

// --- buildPackingListPrompt tests ---

test("buildPackingListPrompt includes trip, weather, events, and wardrobe items", () => {
  const items = createTestItems();
  const prompt = buildPackingListPrompt(testTrip, testWeather, testTripEvents, items);

  assert.ok(prompt.includes("Barcelona"));
  assert.ok(prompt.includes("4 days"));
  assert.ok(prompt.includes("temperature_2m_max") === false); // weather is serialized as JSON
  assert.ok(prompt.includes("Conference Day 1") || prompt.includes("Conference"));
  assert.ok(prompt.includes("item-1"));
});

test("buildPackingListPrompt handles missing weather", () => {
  const items = createTestItems();
  const prompt = buildPackingListPrompt(testTrip, null, testTripEvents, items);

  assert.ok(prompt.includes("Weather data unavailable"));
  assert.ok(prompt.includes("variable conditions"));
});

// --- validateAndEnrichPackingList tests ---

test("validateAndEnrichPackingList enriches valid items from wardrobe", () => {
  const items = createTestItems();
  const itemsMap = new Map(items.map((item) => [item.id, item]));

  const parsed = {
    packingList: {
      categories: [
        { name: "Tops", items: [{ itemId: "item-1", name: "Top", reason: "Good" }] },
      ],
      dailyOutfits: [{ day: 1, date: "2026-03-20", outfitItemIds: ["item-1"], occasion: "Work" }],
      tips: ["Pack light"],
    }
  };

  const result = validateAndEnrichPackingList(parsed, itemsMap);
  assert.equal(result.categories.length, 1);
  assert.equal(result.categories[0].items[0].thumbnailUrl, "https://example.com/photo-1.jpg");
  assert.equal(result.dailyOutfits.length, 1);
  assert.deepEqual(result.tips, ["Pack light"]);
  assert.equal(result.fallback, false);
});

// --- buildFallbackPackingList tests ---

test("buildFallbackPackingList returns list with fallback flag", () => {
  const result = buildFallbackPackingList(testTrip, testTripEvents);
  assert.equal(result.fallback, true);
  assert.ok(result.categories.length > 0);
  assert.ok(result.tips.length > 0);
  // Tops should have durationDays + 1 items
  const tops = result.categories.find((c) => c.name === "Tops");
  assert.equal(tops.items.length, testTrip.durationDays + 1);
});

// --- getCurrentSeason tests ---

test("getCurrentSeason returns a valid season string", () => {
  const season = getCurrentSeason();
  assert.ok(["spring", "summer", "autumn", "winter"].includes(season));
});
