import assert from "node:assert/strict";
import { Readable } from "node:stream";
import test from "node:test";
import { handleRequest } from "../../../src/main.js";

function createResponseCapture() {
  return {
    statusCode: undefined,
    body: undefined,
    writeHead(statusCode) {
      this.statusCode = statusCode;
    },
    end(body) {
      if (body) this.body = JSON.parse(body);
    },
  };
}

function createJsonRequest(method, url, body, includeAuth = true) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json",
  };
  if (includeAuth) {
    stream.headers.authorization = "Bearer signed.jwt.token";
  }
  return stream;
}

function buildContext({
  authenticated = true,
  summaryResult = null,
  geminiUnavailable = false,
  geminiError = false,
  isPremium = true,
  emptyWardrobe = false,
} = {}) {
  return {
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate() {
        if (!authenticated) {
          const { AuthenticationError } = await import(
            "../../../src/modules/auth/service.js"
          );
          throw new AuthenticationError("Unauthorized");
        }
        return {
          userId: "firebase-user-123",
          email: "user@example.com",
          emailVerified: true,
          provider: "google.com",
        };
      },
    },
    profileService: {},
    itemService: {
      async listItemsForUser() {
        return { items: [] };
      },
      async getItemForUser(authContext, itemId) {
        return { item: { id: itemId } };
      },
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {
      async generateOutfits() {
        return { suggestions: [] };
      },
    },
    outfitRepository: {
      async listOutfits() {
        return [];
      },
      async createOutfit() {
        return { id: "outfit-1", items: [] };
      },
    },
    usageLimitService: {},
    wearLogRepository: {
      async createWearLog() {
        return { id: "wl-1", itemIds: [] };
      },
      async listWearLogs() {
        return [];
      },
    },
    analyticsRepository: {
      async getWardrobeSummary() {
        return emptyWardrobe
          ? {
              totalItems: 0,
              pricedItems: 0,
              totalValue: 0,
              totalWears: 0,
              averageCpw: null,
              dominantCurrency: null,
            }
          : {
              totalItems: 10,
              pricedItems: 7,
              totalValue: 1500.0,
              totalWears: 120,
              averageCpw: 12.5,
              dominantCurrency: "GBP",
            };
      },
      async getItemsWithCpw() {
        return [];
      },
      async getTopWornItems() {
        return [];
      },
      async getNeglectedItems() {
        return [];
      },
      async getCategoryDistribution() {
        return [];
      },
      async getWearFrequency() {
        return [];
      },
    },
    analyticsSummaryService: {
      async generateSummary() {
        if (geminiUnavailable) {
          throw { statusCode: 503, message: "AI service unavailable" };
        }
        if (!isPremium) {
          throw { statusCode: 403, message: "Premium subscription required" };
        }
        if (geminiError) {
          throw {
            statusCode: 500,
            message: "Analytics summary generation failed",
          };
        }
        if (emptyWardrobe) {
          return {
            summary:
              "Start adding items to your wardrobe to get personalized AI insights about your style and spending habits!",
            isGeneric: true,
          };
        }
        return summaryResult || {
          summary:
            "Your wardrobe of 10 items shows great value with a £12.50 average cost-per-wear.",
          isGeneric: false,
        };
      },
    },
  };
}

// --- GET /v1/analytics/ai-summary integration tests ---

test("GET /v1/analytics/ai-summary returns 200 with summary for premium user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/ai-summary");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.summary);
  assert.equal(typeof res.body.summary, "string");
  assert.equal(res.body.isGeneric, false);
});

test("GET /v1/analytics/ai-summary returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest(
    "GET",
    "/v1/analytics/ai-summary",
    null,
    false
  );

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/ai-summary returns 403 for non-premium user with correct error body", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/ai-summary");

  await handleRequest(req, res, buildContext({ isPremium: false }));

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.error, "Premium Required");
  assert.equal(res.body.code, "PREMIUM_REQUIRED");
  assert.ok(res.body.message.includes("Premium"));
});

test("GET /v1/analytics/ai-summary returns 200 with generic message for premium user with empty wardrobe", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/ai-summary");

  await handleRequest(req, res, buildContext({ emptyWardrobe: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.summary.includes("Start adding items"));
  assert.equal(res.body.isGeneric, true);
});

test("GET /v1/analytics/ai-summary returns 500 when Gemini call fails", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/ai-summary");

  await handleRequest(req, res, buildContext({ geminiError: true }));

  assert.equal(res.statusCode, 500);
  assert.equal(res.body.error, "Internal Server Error");
});

test("GET /v1/analytics/ai-summary returns 503 when Gemini is unavailable", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/ai-summary");

  await handleRequest(
    req,
    res,
    buildContext({ geminiUnavailable: true })
  );

  assert.equal(res.statusCode, 503);
  assert.equal(res.body.error, "Service Unavailable");
});

test("GET /v1/analytics/ai-summary response contains summary string and isGeneric boolean", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/ai-summary");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(typeof res.body.summary, "string");
  assert.equal(typeof res.body.isGeneric, "boolean");
});
