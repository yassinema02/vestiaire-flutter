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

let savedOutfits = [];
let savedOutfitItems = [];

function buildContext({
  authenticated = true,
  validItemIds = ["item-1", "item-2", "item-3"],
  failValidation = false,
} = {}) {
  savedOutfits = [];
  savedOutfitItems = [];

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
      async generateOutfits() {
        return { suggestions: [], generatedAt: new Date().toISOString() };
      }
    },
    outfitRepository: {
      async createOutfit(authContext, { name, explanation, occasion, source, items }) {
        if (failValidation) {
          const err = new Error("One or more items not found");
          err.statusCode = 400;
          err.code = "INVALID_ITEM";
          throw err;
        }

        const outfit = {
          id: "outfit-uuid-generated",
          profileId: "profile-uuid-1",
          name,
          explanation: explanation ?? null,
          occasion: occasion ?? null,
          source: source ?? "ai",
          isFavorite: false,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          items: items.map(i => ({ id: i.itemId, position: i.position })),
        };
        savedOutfits.push(outfit);
        return outfit;
      },
      async getOutfit(authContext, outfitId) {
        return savedOutfits.find(o => o.id === outfitId) || null;
      }
    }
  };
}

test("POST /v1/outfits requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Test Outfit",
    items: [{ itemId: "item-1", position: 0 }]
  }, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("POST /v1/outfits returns 201 with created outfit on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Spring Casual",
    explanation: "Perfect for spring",
    occasion: "everyday",
    source: "ai",
    items: [
      { itemId: "item-1", position: 0 },
      { itemId: "item-2", position: 1 },
    ]
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.outfit);
  assert.ok(res.body.outfit.id);
});

test("POST /v1/outfits returns outfit with correct structure", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Test Outfit",
    explanation: "Test explanation",
    occasion: "work",
    source: "ai",
    items: [
      { itemId: "item-1", position: 0 },
      { itemId: "item-2", position: 1 },
    ]
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  const outfit = res.body.outfit;
  assert.ok(outfit.id);
  assert.equal(outfit.name, "Test Outfit");
  assert.equal(outfit.explanation, "Test explanation");
  assert.equal(outfit.occasion, "work");
  assert.equal(outfit.source, "ai");
  assert.ok(Array.isArray(outfit.items));
  assert.equal(outfit.items.length, 2);
});

test("POST /v1/outfits returns 400 when name is missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    items: [{ itemId: "item-1", position: 0 }]
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("Name is required"));
});

test("POST /v1/outfits returns 400 when items array is empty", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Test",
    items: []
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("At least one item is required"));
});

test("POST /v1/outfits returns 400 when items array has more than 7 items", async () => {
  const items = Array.from({ length: 8 }, (_, i) => ({ itemId: `item-${i}`, position: i }));
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Test",
    items
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("Maximum 7 items per outfit"));
});

test("POST /v1/outfits returns 400 when itemId doesn't belong to user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Test",
    items: [{ itemId: "foreign-item", position: 0 }]
  });

  await handleRequest(req, res, buildContext({ failValidation: true }));

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, "INVALID_ITEM");
  assert.ok(res.body.message.includes("items not found"));
});

test("POST /v1/outfits defaults source to 'ai' when not provided", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Test Outfit",
    items: [{ itemId: "item-1", position: 0 }]
  });

  const ctx = buildContext();
  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.outfit.source, "ai");
});

test("POST /v1/outfits persists outfit and items to database (verify with context)", async () => {
  const ctx = buildContext();
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/outfits", {
    name: "Persisted Outfit",
    explanation: "Should be saved",
    occasion: "casual",
    items: [
      { itemId: "item-1", position: 0 },
      { itemId: "item-2", position: 1 },
    ]
  });

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 201);
  assert.equal(savedOutfits.length, 1);
  assert.equal(savedOutfits[0].name, "Persisted Outfit");
  assert.equal(savedOutfits[0].items.length, 2);
});
