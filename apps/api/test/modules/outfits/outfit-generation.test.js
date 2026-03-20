import assert from "node:assert/strict";
import { Readable } from "node:stream";
import test from "node:test";
import { handleRequest } from "../../../src/main.js";

function createTestItems(count = 5) {
  const items = [];
  for (let i = 0; i < count; i++) {
    items.push({
      id: `item-${i + 1}`,
      name: `Test Item ${i + 1}`,
      category: i % 2 === 0 ? "tops" : "bottoms",
      color: "blue",
      photoUrl: `https://example.com/photo-${i + 1}.jpg`,
      categorizationStatus: "completed",
    });
  }
  return items;
}

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
  geminiFails = false,
  items = null,
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
        if (!geminiAvailable) {
          throw { statusCode: 503, message: "AI service unavailable" };
        }
        if (geminiFails) {
          throw { statusCode: 500, message: "Outfit generation failed" };
        }

        const testItems = items ?? createTestItems();
        const categorized = testItems.filter(i => i.categorizationStatus === "completed");
        if (categorized.length < 3) {
          throw { statusCode: 400, message: "At least 3 categorized items required" };
        }

        return {
          suggestions: [
            {
              id: "suggestion-abc123",
              name: "Casual Blue Look",
              items: [
                { id: "item-1", name: "Test Item 1", category: "tops", color: "blue", photoUrl: "https://example.com/photo-1.jpg" },
                { id: "item-2", name: "Test Item 2", category: "bottoms", color: "blue", photoUrl: "https://example.com/photo-2.jpg" },
                { id: "item-3", name: "Test Item 3", category: "tops", color: "blue", photoUrl: "https://example.com/photo-3.jpg" },
              ],
              explanation: "A comfortable outfit for a mild spring day.",
              occasion: "everyday"
            }
          ],
          generatedAt: new Date().toISOString()
        };
      }
    }
  };
}

test("POST /v1/outfits/generate requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", { outfitContext: {} }, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("POST /v1/outfits/generate returns 200 with suggestions on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: {
      temperature: 18.5,
      feelsLike: 16.2,
      weatherDescription: "Clear sky",
      calendarEvents: []
    }
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.suggestions);
  assert.ok(res.body.generatedAt);
});

test("POST /v1/outfits/generate returns suggestions with correct structure", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const suggestion = res.body.suggestions[0];
  assert.ok(suggestion.id);
  assert.ok(suggestion.name);
  assert.ok(Array.isArray(suggestion.items));
  assert.ok(suggestion.explanation);
  assert.ok(suggestion.occasion);

  // Each item should have enriched data
  const item = suggestion.items[0];
  assert.ok(item.id);
  assert.ok("name" in item);
  assert.ok("category" in item);
  assert.ok("color" in item);
  assert.ok("photoUrl" in item);
});

test("POST /v1/outfits/generate returns error when user has fewer than 3 categorized items", async () => {
  const twoItems = [
    { id: "i1", name: "I1", categorizationStatus: "completed" },
    { id: "i2", name: "I2", categorizationStatus: "completed" }
  ];
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ items: twoItems }));

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("3 categorized items"));
});

test("POST /v1/outfits/generate returns 503 when Gemini is unavailable", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ geminiAvailable: false }));

  assert.equal(res.statusCode, 503);
  assert.equal(res.body.error, "Service Unavailable");
});

test("POST /v1/outfits/generate works with empty calendarEvents", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: {
      temperature: 18.5,
      feelsLike: 16.2,
      weatherDescription: "Clear sky",
      calendarEvents: []
    }
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.suggestions.length >= 1);
});

test("POST /v1/outfits/generate returns 500 when Gemini call fails", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate", {
    outfitContext: { temperature: 18.5, calendarEvents: [] }
  });

  await handleRequest(req, res, buildContext({ geminiFails: true }));

  assert.equal(res.statusCode, 500);
});

// --- Event-specific generation endpoint tests (Story 12.1) ---

function buildEventContext({
  authenticated = true,
  geminiAvailable = true,
  geminiFails = false,
  items = null,
} = {}) {
  const base = buildContext({ authenticated, geminiAvailable, geminiFails, items });
  base.outfitGenerationService = {
    ...base.outfitGenerationService,
    async generateOutfitsForEvent(authContext, { outfitContext, event }) {
      if (!geminiAvailable) {
        throw { statusCode: 503, message: "AI service unavailable" };
      }
      if (geminiFails) {
        throw { statusCode: 500, message: "Event outfit generation failed" };
      }
      if (!event || !event.title) {
        throw { statusCode: 400, message: "Event title is required" };
      }

      const testItems = items ?? createTestItems();
      const categorized = testItems.filter(i => i.categorizationStatus === "completed");
      if (categorized.length < 3) {
        throw { statusCode: 400, message: "At least 3 categorized items required" };
      }

      return {
        suggestions: [
          {
            id: "suggestion-event-123",
            name: "Event Smart Look",
            items: [
              { id: "item-1", name: "Test Item 1", category: "tops", color: "blue", photoUrl: "https://example.com/photo-1.jpg" },
              { id: "item-2", name: "Test Item 2", category: "bottoms", color: "blue", photoUrl: "https://example.com/photo-2.jpg" },
            ],
            explanation: "Perfect for Sprint Planning.",
            occasion: "work"
          }
        ],
        generatedAt: new Date().toISOString()
      };
    }
  };
  return base;
}

test("POST /v1/outfits/generate-for-event requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate-for-event", {
    outfitContext: {},
    event: { title: "Sprint Planning", eventType: "work", formalityScore: 5 }
  }, false);

  await handleRequest(req, res, buildEventContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("POST /v1/outfits/generate-for-event returns 200 with suggestions on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate-for-event", {
    outfitContext: { temperature: 18.5, calendarEvents: [] },
    event: { title: "Sprint Planning", eventType: "work", formalityScore: 5, startTime: "2026-03-15T10:00:00Z", endTime: "2026-03-15T11:00:00Z" }
  });

  await handleRequest(req, res, buildEventContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.suggestions);
  assert.ok(res.body.generatedAt);
  assert.equal(res.body.suggestions[0].name, "Event Smart Look");
});

test("POST /v1/outfits/generate-for-event returns 400 when event data is missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate-for-event", {
    outfitContext: {}
  });

  await handleRequest(req, res, buildEventContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("Event data is required"));
});

test("POST /v1/outfits/generate-for-event returns 400 when event fields are incomplete", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate-for-event", {
    outfitContext: {},
    event: { title: "Sprint Planning" }
  });

  await handleRequest(req, res, buildEventContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("eventType"));
});

test("POST /v1/outfits/generate-for-event returns 503 when Gemini is unavailable", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate-for-event", {
    outfitContext: {},
    event: { title: "Sprint Planning", eventType: "work", formalityScore: 5 }
  });

  await handleRequest(req, res, buildEventContext({ geminiAvailable: false }));

  assert.equal(res.statusCode, 503);
});

test("POST /v1/outfits/generate-for-event returns 500 when Gemini call fails", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/generate-for-event", {
    outfitContext: {},
    event: { title: "Sprint Planning", eventType: "work", formalityScore: 5 }
  });

  await handleRequest(req, res, buildEventContext({ geminiFails: true }));

  assert.equal(res.statusCode, 500);
});

// --- Event Prep Tip endpoint tests (Story 12.3) ---

function buildPrepTipContext({
  authenticated = true,
  geminiAvailable = true,
  geminiFails = false,
} = {}) {
  const base = buildContext({ authenticated, geminiAvailable, geminiFails });
  base.outfitGenerationService = {
    ...base.outfitGenerationService,
    async generateEventPrepTip(authContext, { event, outfitItems }) {
      if (!geminiAvailable) {
        throw { statusCode: 503, message: "AI service unavailable" };
      }
      if (!event || typeof event !== "object") {
        throw { statusCode: 400, message: "Event data is required" };
      }
      if (geminiFails) {
        // Return fallback tip on Gemini failure (not 500)
        const score = event.formalityScore ?? 7;
        return {
          tip: score >= 9
            ? "Consider dry cleaning and shoe polishing tonight."
            : "Check that your outfit is clean and pressed."
        };
      }
      return { tip: "Iron your cotton blazer and steam the trousers" };
    }
  };
  return base;
}

test("POST /v1/outfits/event-prep-tips requires authentication (401)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/event-prep-tips", {
    event: { title: "Gala", eventType: "formal", formalityScore: 9, startTime: "2026-03-20T19:00:00Z" }
  }, false);

  await handleRequest(req, res, buildPrepTipContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("POST /v1/outfits/event-prep-tips returns 200 with tip on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/event-prep-tips", {
    event: { title: "Gala", eventType: "formal", formalityScore: 9, startTime: "2026-03-20T19:00:00Z" }
  });

  await handleRequest(req, res, buildPrepTipContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.tip);
  assert.equal(res.body.tip, "Iron your cotton blazer and steam the trousers");
});

test("POST /v1/outfits/event-prep-tips returns 400 when event data is missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/event-prep-tips", {});

  await handleRequest(req, res, buildPrepTipContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("Event data is required"));
});

test("POST /v1/outfits/event-prep-tips returns fallback tip on Gemini failure (not 500)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/event-prep-tips", {
    event: { title: "Meeting", eventType: "work", formalityScore: 7, startTime: "2026-03-20T09:00:00Z" }
  });

  await handleRequest(req, res, buildPrepTipContext({ geminiFails: true }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.tip, "Check that your outfit is clean and pressed.");
});

test("POST /v1/outfits/event-prep-tips returns 503 when Gemini is unavailable", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits/event-prep-tips", {
    event: { title: "Gala", eventType: "formal", formalityScore: 9, startTime: "2026-03-20T19:00:00Z" }
  });

  await handleRequest(req, res, buildPrepTipContext({ geminiAvailable: false }));

  assert.equal(res.statusCode, 503);
});
