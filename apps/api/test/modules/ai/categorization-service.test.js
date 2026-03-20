import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import {
  createCategorizationService,
  validateTaxonomy,
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_PATTERNS,
  VALID_MATERIALS,
  VALID_STYLES,
  VALID_SEASONS,
  VALID_OCCASIONS
} from "../../../src/modules/ai/categorization-service.js";

// Create a temporary test image file
const testImagePath = path.join(process.cwd(), "test-categorization-image.jpg");
fs.writeFileSync(testImagePath, Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]));

// Clean up after all tests
test.after(() => {
  try { fs.unlinkSync(testImagePath); } catch {}
});

function createMockGeminiClient({ shouldFail = false, isAvailable = true, responseJson = null } = {}) {
  const calls = [];
  const defaultResponse = {
    category: "tops",
    color: "blue",
    secondary_colors: ["white"],
    pattern: "solid",
    material: "cotton",
    style: "casual",
    season: ["spring", "summer"],
    occasion: ["everyday", "work"]
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
                promptTokenCount: 200,
                candidatesTokenCount: 80
              }
            }
          };
        }
      };
    }
  };
}

function createMockItemRepo() {
  const calls = [];
  return {
    calls,
    async updateItem(authContext, itemId, fields) {
      calls.push({ method: "updateItem", authContext, itemId, fields });
      return { id: itemId, ...fields };
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

test("categorizeItem calls Gemini with image data and structured prompt", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.categorizeItem(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.equal(result.status, "completed");

  // Verify Gemini was called with correct model
  assert.equal(geminiClient.calls.length, 2);
  assert.equal(geminiClient.calls[0].method, "getGenerativeModel");
  assert.equal(geminiClient.calls[0].modelName, "gemini-2.0-flash");

  // Verify the request included JSON mode
  const genContentCall = geminiClient.calls[1];
  assert.equal(genContentCall.request.generationConfig.responseMimeType, "application/json");

  // Verify item was updated with categorization data
  assert.equal(itemRepo.calls.length, 1);
  assert.equal(itemRepo.calls[0].itemId, "item-1");
  assert.equal(itemRepo.calls[0].fields.category, "tops");
  assert.equal(itemRepo.calls[0].fields.color, "blue");
  assert.deepEqual(itemRepo.calls[0].fields.secondary_colors, ["white"]);
  assert.equal(itemRepo.calls[0].fields.pattern, "solid");
  assert.equal(itemRepo.calls[0].fields.material, "cotton");
  assert.equal(itemRepo.calls[0].fields.style, "casual");
  assert.deepEqual(itemRepo.calls[0].fields.season, ["spring", "summer"]);
  assert.deepEqual(itemRepo.calls[0].fields.occasion, ["everyday", "work"]);
  assert.equal(itemRepo.calls[0].fields.categorizationStatus, "completed");

  // Verify AI usage was logged
  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "categorization");
  assert.equal(aiUsageLogRepo.calls[0].params.model, "gemini-2.0-flash");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "success");
  assert.equal(aiUsageLogRepo.calls[0].params.inputTokens, 200);
  assert.equal(aiUsageLogRepo.calls[0].params.outputTokens, 80);
});

test("categorizeItem validates taxonomy: invalid category falls back to 'other'", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: {
      category: "invalid-category",
      color: "blue",
      secondary_colors: [],
      pattern: "solid",
      material: "cotton",
      style: "casual",
      season: ["summer"],
      occasion: ["everyday"]
    }
  });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.categorizeItem(testAuthContext, { itemId: "item-1", imageUrl: testImagePath });

  assert.equal(itemRepo.calls[0].fields.category, "other");
});

test("categorizeItem validates taxonomy: invalid color falls back to 'unknown'", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: {
      category: "tops",
      color: "rainbow",
      secondary_colors: [],
      pattern: "solid",
      material: "cotton",
      style: "casual",
      season: ["summer"],
      occasion: ["everyday"]
    }
  });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.categorizeItem(testAuthContext, { itemId: "item-1", imageUrl: testImagePath });

  assert.equal(itemRepo.calls[0].fields.color, "unknown");
});

test("categorizeItem validates array fields: invalid season values are filtered out", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: {
      category: "tops",
      color: "blue",
      secondary_colors: ["invalid-color", "red"],
      pattern: "solid",
      material: "cotton",
      style: "casual",
      season: ["summer", "invalid-season", "winter"],
      occasion: ["everyday", "invalid-occasion"]
    }
  });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.categorizeItem(testAuthContext, { itemId: "item-1", imageUrl: testImagePath });

  assert.deepEqual(itemRepo.calls[0].fields.season, ["summer", "winter"]);
  assert.deepEqual(itemRepo.calls[0].fields.occasion, ["everyday"]);
  assert.deepEqual(itemRepo.calls[0].fields.secondary_colors, ["red"]);
});

test("categorizeItem failure path: Gemini call fails, logs error, sets categorization_status to failed", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.categorizeItem(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.equal(result.status, "failed");

  // Verify item was updated to failed
  assert.equal(itemRepo.calls.length, 1);
  assert.equal(itemRepo.calls[0].fields.categorizationStatus, "failed");

  // Verify failure was logged
  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.status, "failure");
  assert.ok(aiUsageLogRepo.calls[0].params.errorMessage.includes("rate limit"));
});

test("categorizeItem skipped path: when Gemini is not available, returns 'skipped'", async () => {
  const geminiClient = createMockGeminiClient({ isAvailable: false });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  const result = await service.categorizeItem(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.equal(result.status, "skipped");

  // No Gemini calls, no item updates, no logs
  assert.equal(geminiClient.calls.length, 0);
  assert.equal(itemRepo.calls.length, 0);
  assert.equal(aiUsageLogRepo.calls.length, 0);
});

test("categorizeItem logs latency in AI usage log", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.categorizeItem(testAuthContext, { itemId: "item-1", imageUrl: testImagePath });

  assert.ok(aiUsageLogRepo.calls[0].params.latencyMs >= 0);
  assert.equal(typeof aiUsageLogRepo.calls[0].params.latencyMs, "number");
});

test("categorizeItem estimates cost based on token usage", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo });

  await service.categorizeItem(testAuthContext, { itemId: "item-1", imageUrl: testImagePath });

  const cost = aiUsageLogRepo.calls[0].params.estimatedCostUsd;
  assert.ok(cost >= 0);
  assert.equal(typeof cost, "number");
});

// Taxonomy validation unit tests

test("validateTaxonomy: valid values pass through unchanged", () => {
  const result = validateTaxonomy({
    category: "dresses",
    color: "red",
    secondary_colors: ["black", "white"],
    pattern: "floral",
    material: "silk",
    style: "formal",
    season: ["spring", "fall"],
    occasion: ["party", "date-night"]
  });

  assert.equal(result.category, "dresses");
  assert.equal(result.color, "red");
  assert.deepEqual(result.secondaryColors, ["black", "white"]);
  assert.equal(result.pattern, "floral");
  assert.equal(result.material, "silk");
  assert.equal(result.style, "formal");
  assert.deepEqual(result.season, ["spring", "fall"]);
  assert.deepEqual(result.occasion, ["party", "date-night"]);
});

test("validateTaxonomy: missing fields get safe defaults", () => {
  const result = validateTaxonomy({});

  assert.equal(result.category, "other");
  assert.equal(result.color, "unknown");
  assert.equal(result.pattern, "solid");
  assert.equal(result.material, "unknown");
  assert.equal(result.style, "casual");
  assert.deepEqual(result.season, ["all"]);
  assert.deepEqual(result.occasion, ["everyday"]);
  assert.deepEqual(result.secondaryColors, []);
});

test("validateTaxonomy: all invalid array values result in defaults", () => {
  const result = validateTaxonomy({
    category: "tops",
    color: "blue",
    secondary_colors: ["not-a-color"],
    pattern: "solid",
    material: "cotton",
    style: "casual",
    season: ["not-a-season"],
    occasion: ["not-an-occasion"]
  });

  assert.deepEqual(result.secondaryColors, []);
  assert.deepEqual(result.season, ["all"]);
  assert.deepEqual(result.occasion, ["everyday"]);
});

test("validateTaxonomy: non-string values are rejected", () => {
  const result = validateTaxonomy({
    category: 123,
    color: null,
    secondary_colors: [123, true],
    pattern: undefined,
    material: {},
    style: [],
    season: "summer",
    occasion: null
  });

  assert.equal(result.category, "other");
  assert.equal(result.color, "unknown");
  assert.deepEqual(result.secondaryColors, []);
  assert.equal(result.pattern, "solid");
  assert.equal(result.material, "unknown");
  assert.equal(result.style, "casual");
  assert.deepEqual(result.season, ["all"]);
  assert.deepEqual(result.occasion, ["everyday"]);
});

test("VALID_CATEGORIES contains all expected values", () => {
  assert.ok(VALID_CATEGORIES.includes("tops"));
  assert.ok(VALID_CATEGORIES.includes("bottoms"));
  assert.ok(VALID_CATEGORIES.includes("dresses"));
  assert.ok(VALID_CATEGORIES.includes("outerwear"));
  assert.ok(VALID_CATEGORIES.includes("shoes"));
  assert.ok(VALID_CATEGORIES.includes("bags"));
  assert.ok(VALID_CATEGORIES.includes("accessories"));
  assert.ok(VALID_CATEGORIES.includes("other"));
  assert.equal(VALID_CATEGORIES.length, 13);
});

test("VALID_COLORS contains all expected values", () => {
  assert.ok(VALID_COLORS.includes("black"));
  assert.ok(VALID_COLORS.includes("white"));
  assert.ok(VALID_COLORS.includes("light-blue"));
  assert.ok(VALID_COLORS.includes("multicolor"));
  assert.ok(VALID_COLORS.includes("unknown"));
  assert.equal(VALID_COLORS.length, 23);
});
