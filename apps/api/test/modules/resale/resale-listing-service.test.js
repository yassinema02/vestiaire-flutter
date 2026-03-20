import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import {
  createResaleListingService,
  validateListingResponse
} from "../../../src/modules/resale/resale-listing-service.js";

// Create a temporary test image file
const testImagePath = path.join(process.cwd(), "test-resale-image.jpg");
fs.writeFileSync(testImagePath, Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]));

test.after(() => {
  try { fs.unlinkSync(testImagePath); } catch {}
});

const testAuthContext = { userId: "firebase-user-123" };

function createMockGeminiClient({ shouldFail = false, isAvailable = true, responseJson = null } = {}) {
  const calls = [];
  const defaultResponse = {
    title: "Gorgeous Blue Cotton Shirt - Casual Summer Essential",
    description: "Beautiful blue cotton shirt in excellent condition. Perfect for casual outings and summer days. Versatile piece that pairs well with jeans or chinos.",
    conditionEstimate: "Like New",
    hashtags: ["blueshirt", "cotton", "casual", "summer", "mensfashion"],
    platform: "general"
  };

  return {
    calls,
    isAvailable() { return isAvailable; },
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
              candidates: [{
                content: {
                  parts: [{ text: JSON.stringify(responseJson ?? defaultResponse) }]
                }
              }],
              usageMetadata: {
                promptTokenCount: 300,
                candidatesTokenCount: 120
              }
            }
          };
        }
      };
    }
  };
}

function createMockItemRepo({ item, returnNull = false } = {}) {
  const calls = [];
  const defaultItem = {
    id: "item-1",
    profileId: "profile-1",
    photoUrl: testImagePath,
    originalPhotoUrl: null,
    name: "Blue Shirt",
    category: "tops",
    color: "blue",
    secondaryColors: ["white"],
    pattern: "solid",
    material: "cotton",
    style: "casual",
    season: ["spring", "summer"],
    occasion: ["everyday"],
    brand: "Nike",
    purchasePrice: 49.99,
    currency: "USD"
  };

  return {
    calls,
    async getItem(authContext, itemId) {
      calls.push({ method: "getItem", authContext, itemId });
      if (returnNull) return null;
      return item ?? defaultItem;
    },
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

function createMockPool({ resaleStatus = null } = {}) {
  const queries = [];
  return {
    queries,
    async connect() {
      return {
        async query(sql, params) {
          queries.push({ sql, params });

          // Handle set_config
          if (sql.includes("set_config")) {
            return { rows: [] };
          }
          // Handle profile lookup
          if (sql.includes("FROM app_public.profiles WHERE firebase_uid")) {
            return { rows: [{ id: "profile-1" }] };
          }
          // Handle extra item data query
          if (sql.includes("wear_count, last_worn_date")) {
            return { rows: [{ wear_count: 3, last_worn_date: "2026-01-15", purchase_price: 49.99, currency: "USD" }] };
          }
          // Handle begin/commit/rollback
          if (sql === "begin" || sql === "commit" || sql === "rollback") {
            return { rows: [] };
          }
          // Handle INSERT into resale_listings
          if (sql.includes("INSERT INTO app_public.resale_listings")) {
            return { rows: [{ id: "listing-1", created_at: new Date().toISOString() }] };
          }
          // Handle UPDATE items resale_status
          if (sql.includes("UPDATE app_public.items SET resale_status")) {
            return { rows: [{ id: "item-1" }] };
          }
          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

test("generateListing calls Gemini with correct prompt containing item metadata and image", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  const result = await service.generateListing(testAuthContext, { itemId: "item-1" });

  // Verify Gemini was called with correct model
  assert.equal(geminiClient.calls[0].method, "getGenerativeModel");
  assert.equal(geminiClient.calls[0].modelName, "gemini-2.0-flash");

  // Verify JSON mode
  const genCall = geminiClient.calls[1];
  assert.equal(genCall.request.generationConfig.responseMimeType, "application/json");

  // Verify the prompt contains item metadata
  const promptText = genCall.request.contents[0].parts[1].text;
  assert.ok(promptText.includes("tops"));
  assert.ok(promptText.includes("blue"));
  assert.ok(promptText.includes("cotton"));
  assert.ok(promptText.includes("Nike"));

  // Verify image was included
  assert.ok(genCall.request.contents[0].parts[0].inlineData);
  assert.equal(genCall.request.contents[0].parts[0].inlineData.mimeType, "image/jpeg");
});

test("generateListing returns validated listing with title, description, conditionEstimate, hashtags", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  const result = await service.generateListing(testAuthContext, { itemId: "item-1" });

  assert.ok(result.listing);
  assert.ok(result.listing.title);
  assert.ok(result.listing.description);
  assert.ok(result.listing.conditionEstimate);
  assert.ok(Array.isArray(result.listing.hashtags));
  assert.ok(result.item);
  assert.equal(result.item.id, "item-1");
  assert.ok(result.generatedAt);
});

test("generateListing persists listing to resale_listings table", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await service.generateListing(testAuthContext, { itemId: "item-1" });

  const insertQuery = pool.queries.find((q) => q.sql.includes("INSERT INTO app_public.resale_listings"));
  assert.ok(insertQuery, "Should have inserted into resale_listings");
  assert.ok(insertQuery.params.includes("profile-1"), "Should include profile ID");
  assert.ok(insertQuery.params.includes("item-1"), "Should include item ID");
});

test("generateListing updates item resale_status to 'listed' when NULL", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await service.generateListing(testAuthContext, { itemId: "item-1" });

  const updateQuery = pool.queries.find((q) =>
    q.sql.includes("UPDATE app_public.items SET resale_status") &&
    q.sql.includes("resale_status IS NULL")
  );
  assert.ok(updateQuery, "Should have updated resale_status only when NULL");
});

test("generateListing does NOT overwrite resale_status when already 'sold' or 'donated'", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool({ resaleStatus: "sold" });

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await service.generateListing(testAuthContext, { itemId: "item-1" });

  // The UPDATE query has "WHERE ... resale_status IS NULL" which means
  // it won't overwrite 'sold' or 'donated' since they are not NULL
  const updateQuery = pool.queries.find((q) =>
    q.sql.includes("UPDATE app_public.items SET resale_status")
  );
  assert.ok(updateQuery.sql.includes("resale_status IS NULL"), "Should only update when NULL");
});

test("generateListing throws 503 when Gemini is unavailable", async () => {
  const geminiClient = createMockGeminiClient({ isAvailable: false });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await assert.rejects(
    () => service.generateListing(testAuthContext, { itemId: "item-1" }),
    (err) => {
      assert.equal(err.statusCode, 503);
      assert.ok(err.message.includes("unavailable"));
      return true;
    }
  );
});

test("generateListing logs successful usage to ai_usage_log with feature 'resale_listing'", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await service.generateListing(testAuthContext, { itemId: "item-1" });

  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "resale_listing");
  assert.equal(aiUsageLogRepo.calls[0].params.model, "gemini-2.0-flash");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "success");
  assert.equal(aiUsageLogRepo.calls[0].params.inputTokens, 300);
  assert.equal(aiUsageLogRepo.calls[0].params.outputTokens, 120);
  assert.ok(aiUsageLogRepo.calls[0].params.latencyMs >= 0);
  assert.ok(typeof aiUsageLogRepo.calls[0].params.estimatedCostUsd === "number");
});

test("generateListing logs failure to ai_usage_log when Gemini call fails", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await assert.rejects(() => service.generateListing(testAuthContext, { itemId: "item-1" }));

  const failLog = aiUsageLogRepo.calls.find((c) => c.params.status === "failure");
  assert.ok(failLog, "Should have logged failure");
  assert.equal(failLog.params.feature, "resale_listing");
});

test("generateListing handles unparseable Gemini JSON gracefully", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: "not valid json object"
  });
  // Override to return raw non-JSON text
  geminiClient.getGenerativeModel = async () => ({
    async generateContent() {
      return {
        response: {
          candidates: [{ content: { parts: [{ text: "not json at all {{{" }] } }],
          usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 }
        }
      };
    }
  });

  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await assert.rejects(
    () => service.generateListing(testAuthContext, { itemId: "item-1" }),
    (err) => {
      assert.equal(err.statusCode, 500);
      return true;
    }
  );
});

test("generateListing throws 404 when item not found or not owned", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo({ returnNull: true });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const pool = createMockPool();

  const service = createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool });

  await assert.rejects(
    () => service.generateListing(testAuthContext, { itemId: "nonexistent" }),
    (err) => {
      assert.equal(err.statusCode, 404);
      return true;
    }
  );
});

// --- validateListingResponse unit tests ---

test("validateListingResponse: valid values pass through unchanged", () => {
  const result = validateListingResponse({
    title: "Beautiful Shirt",
    description: "A lovely shirt for sale.",
    conditionEstimate: "Like New",
    hashtags: ["fashion", "shirt"],
    platform: "general"
  });

  assert.equal(result.title, "Beautiful Shirt");
  assert.equal(result.description, "A lovely shirt for sale.");
  assert.equal(result.conditionEstimate, "Like New");
  assert.deepEqual(result.hashtags, ["fashion", "shirt"]);
  assert.equal(result.platform, "general");
});

test("validateListingResponse: validates conditionEstimate against allowed values, defaults to 'Good'", () => {
  const result = validateListingResponse({
    title: "Shirt",
    description: "Desc",
    conditionEstimate: "Excellent",
    hashtags: [],
    platform: "general"
  });

  assert.equal(result.conditionEstimate, "Good");
});

test("validateListingResponse: truncates title to 80 chars if too long", () => {
  const longTitle = "A".repeat(100);
  const result = validateListingResponse({
    title: longTitle,
    description: "Desc",
    conditionEstimate: "New",
    hashtags: [],
    platform: "general"
  });

  assert.equal(result.title.length, 80);
});

test("validateListingResponse: caps hashtags at 10", () => {
  const hashtags = Array.from({ length: 15 }, (_, i) => `tag${i}`);
  const result = validateListingResponse({
    title: "Shirt",
    description: "Desc",
    conditionEstimate: "New",
    hashtags,
    platform: "general"
  });

  assert.equal(result.hashtags.length, 10);
});

test("validateListingResponse: handles missing/empty title", () => {
  const result = validateListingResponse({
    title: "",
    description: "Desc",
    conditionEstimate: "New",
    hashtags: [],
    platform: "general"
  });

  assert.equal(result.title, "Untitled Listing");
});

test("validateListingResponse: handles missing/invalid hashtags", () => {
  const result = validateListingResponse({
    title: "Shirt",
    description: "Desc",
    conditionEstimate: "New",
    hashtags: null,
    platform: "general"
  });

  assert.deepEqual(result.hashtags, []);
});

test("validateListingResponse: filters non-string hashtags", () => {
  const result = validateListingResponse({
    title: "Shirt",
    description: "Desc",
    conditionEstimate: "New",
    hashtags: ["valid", 123, null, "also-valid", ""],
    platform: "general"
  });

  assert.deepEqual(result.hashtags, ["valid", "also-valid"]);
});
