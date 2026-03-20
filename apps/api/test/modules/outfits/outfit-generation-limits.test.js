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
    }
  };
}

function createJsonRequest(method, url, body, includeAuth = true) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json"
  };
  if (includeAuth) {
    stream.headers.authorization = "Bearer signed.jwt.token";
  }
  return stream;
}

function buildContext({
  authenticated = true,
  geminiAvailable = true,
  usageCount = 0,
  isPremium = false,
  geminiCalled = { count: 0 },
} = {}) {
  return {
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate(req) {
        if (!authenticated) {
          const { AuthenticationError } = await import("../../../src/modules/auth/service.js");
          throw new AuthenticationError("Unauthorized");
        }
        return {
          userId: "firebase-user-123",
          email: "user@example.com",
          emailVerified: true,
          provider: "google.com"
        };
      }
    },
    profileService: {},
    itemService: {},
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {
      async generateOutfits(authContext, { outfitContext }) {
        geminiCalled.count++;
        if (!geminiAvailable) {
          throw { statusCode: 503, message: "AI service unavailable" };
        }
        return {
          suggestions: [
            {
              id: "suggestion-abc123",
              name: "Casual Blue Look",
              items: [
                { id: "item-1", name: "Test Item 1", category: "tops", color: "blue", photoUrl: "https://example.com/photo-1.jpg" },
                { id: "item-2", name: "Test Item 2", category: "bottoms", color: "blue", photoUrl: "https://example.com/photo-2.jpg" },
              ],
              explanation: "A comfortable outfit for a mild spring day.",
              occasion: "everyday"
            }
          ],
          generatedAt: new Date().toISOString()
        };
      }
    },
    outfitRepository: {},
    usageLimitService: {
      async checkUsageLimit(authContext) {
        if (isPremium) {
          return {
            allowed: true,
            isPremium: true,
            dailyLimit: null,
            used: 0,
            remaining: null,
            resetsAt: null,
          };
        }
        const remaining = Math.max(0, 3 - usageCount);
        const todayStart = new Date().toISOString().split("T")[0] + "T00:00:00Z";
        const resetsAt = new Date(new Date(todayStart).getTime() + 86400000).toISOString();
        return {
          allowed: usageCount < 3,
          isPremium: false,
          dailyLimit: 3,
          used: usageCount,
          remaining,
          resetsAt,
        };
      },
      async getUsageAfterGeneration(authContext) {
        const count = usageCount + 1;
        if (isPremium) {
          return {
            isPremium: true,
            dailyLimit: null,
            used: count,
            remaining: null,
            resetsAt: null,
          };
        }
        const remaining = Math.max(0, 3 - count);
        const todayStart = new Date().toISOString().split("T")[0] + "T00:00:00Z";
        const resetsAt = new Date(new Date(todayStart).getTime() + 86400000).toISOString();
        return {
          isPremium: false,
          dailyLimit: 3,
          used: count,
          remaining,
          resetsAt,
        };
      }
    }
  };
}

test("POST /v1/outfits/generate returns 200 with usage metadata on first generation (free user)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 0 }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.suggestions);
  assert.ok(res.body.usage);
  assert.equal(res.body.usage.isPremium, false);
  assert.equal(res.body.usage.dailyLimit, 3);
});

test("POST /v1/outfits/generate returns 200 with usage.remaining = 2 on first generation", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 0 }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.usage.used, 1);
  assert.equal(res.body.usage.remaining, 2);
});

test("POST /v1/outfits/generate returns 429 with correct error body when free user has 3 generations today", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 3 }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.error, "Rate Limit Exceeded");
  assert.equal(res.body.code, "RATE_LIMIT_EXCEEDED");
  assert.equal(res.body.message, "Daily outfit generation limit reached");
});

test("POST /v1/outfits/generate 429 response includes dailyLimit, used, remaining, and resetsAt fields", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 3 }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.dailyLimit, 3);
  assert.equal(res.body.used, 3);
  assert.equal(res.body.remaining, 0);
  assert.ok(res.body.resetsAt);
});

test("POST /v1/outfits/generate does NOT call Gemini when the limit is reached", async () => {
  const geminiCalled = { count: 0 };
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 3, geminiCalled }));

  assert.equal(res.statusCode, 429);
  assert.equal(geminiCalled.count, 0);
});

test("POST /v1/outfits/generate returns 200 for premium user even with 3+ generations today", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 10, isPremium: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.suggestions);
});

test("POST /v1/outfits/generate premium user response includes usage.isPremium: true", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 10, isPremium: true }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.usage.isPremium, true);
  assert.equal(res.body.usage.dailyLimit, null);
  assert.equal(res.body.usage.remaining, null);
});

test("mapError correctly handles 429 status code", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ usageCount: 5 }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.error, "Rate Limit Exceeded");
  assert.equal(res.body.code, "RATE_LIMIT_EXCEEDED");
});
