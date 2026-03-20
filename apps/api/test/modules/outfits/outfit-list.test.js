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
  outfits = [],
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
      async generateOutfits() {
        return { suggestions: [], generatedAt: new Date().toISOString() };
      }
    },
    outfitRepository: {
      async createOutfit() { return {}; },
      async getOutfit() { return null; },
      async listOutfits() { return outfits; },
      async updateOutfit() { return {}; },
      async deleteOutfit() { return { deleted: true }; },
    }
  };
}

test("GET /v1/outfits requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/outfits", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/outfits returns 200 with outfits array", async () => {
  const outfits = [
    {
      id: "outfit-1", name: "Spring Casual", explanation: "Perfect",
      occasion: "everyday", source: "ai", isFavorite: false,
      createdAt: "2026-03-15T00:00:00Z", updatedAt: "2026-03-15T00:00:00Z",
      items: [{ id: "item-1", position: 0, name: "Shirt", category: "tops", color: "blue", photoUrl: null }]
    }
  ];

  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/outfits", null);

  await handleRequest(req, res, buildContext({ outfits }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.outfits);
  assert.ok(Array.isArray(res.body.outfits));
  assert.equal(res.body.outfits.length, 1);
  assert.equal(res.body.outfits[0].id, "outfit-1");
});

test("GET /v1/outfits returns outfits ordered by created_at DESC", async () => {
  const outfits = [
    { id: "newer", name: "Newer", createdAt: "2026-03-15T00:00:00Z", items: [] },
    { id: "older", name: "Older", createdAt: "2026-03-14T00:00:00Z", items: [] },
  ];

  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/outfits", null);

  await handleRequest(req, res, buildContext({ outfits }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.outfits[0].id, "newer");
  assert.equal(res.body.outfits[1].id, "older");
});

test("GET /v1/outfits includes items with full metadata for each outfit", async () => {
  const outfits = [
    {
      id: "outfit-1", name: "Test",
      items: [
        { id: "item-1", position: 0, name: "Shirt", category: "tops", color: "blue", photoUrl: "http://example.com/photo.jpg" }
      ]
    }
  ];

  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/outfits", null);

  await handleRequest(req, res, buildContext({ outfits }));

  assert.equal(res.statusCode, 200);
  const item = res.body.outfits[0].items[0];
  assert.equal(item.id, "item-1");
  assert.equal(item.name, "Shirt");
  assert.equal(item.category, "tops");
  assert.equal(item.color, "blue");
  assert.equal(item.photoUrl, "http://example.com/photo.jpg");
});

test("GET /v1/outfits returns empty array when no outfits exist", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/outfits", null);

  await handleRequest(req, res, buildContext({ outfits: [] }));

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.outfits, []);
});

test("GET /v1/outfits does not return other users' outfits (RLS)", async () => {
  let capturedUserId;
  const ctx = buildContext();
  ctx.outfitRepository.listOutfits = async (authContext) => {
    capturedUserId = authContext.userId;
    return [];
  };

  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/outfits", null);

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.equal(capturedUserId, "firebase-user-123");
});
