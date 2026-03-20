import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { createBackgroundRemovalService } from "../../../src/modules/ai/background-removal-service.js";

// Create a temporary test image file
const testImagePath = path.join(process.cwd(), "test-bg-removal-image.jpg");
fs.writeFileSync(testImagePath, Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]));

// Clean up after all tests
test.after(() => {
  try { fs.unlinkSync(testImagePath); } catch {}
  // Clean up any uploaded files
  try { fs.rmSync(path.join(process.cwd(), "uploads"), { recursive: true, force: true }); } catch {}
});

function createMockGeminiClient({ shouldFail = false, isAvailable = true } = {}) {
  const calls = [];

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
                        inlineData: {
                          mimeType: "image/png",
                          data: Buffer.from("fake-cleaned-image").toString("base64")
                        }
                      }
                    ]
                  }
                }
              ],
              usageMetadata: {
                promptTokenCount: 100,
                candidatesTokenCount: 50
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
      return {
        id: itemId,
        photoUrl: fields.photoUrl ?? "original-url",
        bgRemovalStatus: fields.bgRemovalStatus
      };
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

test("removeBackground calls gemini client and returns completed status on success", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createBackgroundRemovalService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo
  });

  const result = await service.removeBackground(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.equal(result.status, "completed");
  assert.ok(result.cleanedImageUrl);

  // Verify gemini was called
  assert.equal(geminiClient.calls.length, 2);
  assert.equal(geminiClient.calls[0].method, "getGenerativeModel");
  assert.equal(geminiClient.calls[0].modelName, "gemini-2.0-flash");

  // Verify item was updated
  assert.equal(itemRepo.calls.length, 1);
  assert.equal(itemRepo.calls[0].itemId, "item-1");
  assert.equal(itemRepo.calls[0].fields.bgRemovalStatus, "completed");

  // Verify AI usage was logged
  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "background_removal");
  assert.equal(aiUsageLogRepo.calls[0].params.model, "gemini-2.0-flash");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "success");
  assert.equal(aiUsageLogRepo.calls[0].params.inputTokens, 100);
  assert.equal(aiUsageLogRepo.calls[0].params.outputTokens, 50);
});

test("removeBackground logs error and returns failed status on gemini failure", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createBackgroundRemovalService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo
  });

  const result = await service.removeBackground(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.equal(result.status, "failed");
  assert.equal(result.cleanedImageUrl, null);

  // Verify item was updated to failed
  assert.equal(itemRepo.calls.length, 1);
  assert.equal(itemRepo.calls[0].fields.bgRemovalStatus, "failed");

  // Verify failure was logged
  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.status, "failure");
  assert.ok(aiUsageLogRepo.calls[0].params.errorMessage.includes("rate limit"));
});

test("removeBackground returns skipped when gemini client is not available", async () => {
  const geminiClient = createMockGeminiClient({ isAvailable: false });
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createBackgroundRemovalService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo
  });

  const result = await service.removeBackground(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.equal(result.status, "skipped");
  assert.equal(result.cleanedImageUrl, null);

  // No gemini calls, no item updates, no logs
  assert.equal(geminiClient.calls.length, 0);
  assert.equal(itemRepo.calls.length, 0);
  assert.equal(aiUsageLogRepo.calls.length, 0);
});

test("removeBackground logs latency in AI usage log", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createBackgroundRemovalService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo
  });

  await service.removeBackground(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  assert.ok(aiUsageLogRepo.calls[0].params.latencyMs >= 0);
  assert.equal(typeof aiUsageLogRepo.calls[0].params.latencyMs, "number");
});

test("removeBackground estimates cost based on token usage", async () => {
  const geminiClient = createMockGeminiClient();
  const itemRepo = createMockItemRepo();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createBackgroundRemovalService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo
  });

  await service.removeBackground(testAuthContext, {
    itemId: "item-1",
    imageUrl: testImagePath
  });

  const cost = aiUsageLogRepo.calls[0].params.estimatedCostUsd;
  assert.ok(cost >= 0);
  assert.equal(typeof cost, "number");
});
