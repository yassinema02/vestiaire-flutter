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
  updateResult = null,
  failWith404 = false,
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
      async listOutfits() { return []; },
      async updateOutfit(authContext, outfitId, { isFavorite }) {
        if (failWith404) {
          const err = new Error("Outfit not found");
          err.statusCode = 404;
          err.code = "NOT_FOUND";
          throw err;
        }
        return updateResult || {
          id: outfitId,
          name: "Test Outfit",
          isFavorite,
          source: "ai",
          createdAt: "2026-03-15T00:00:00Z",
          updatedAt: "2026-03-15T01:00:00Z",
          items: [],
        };
      },
      async deleteOutfit() { return { deleted: true }; },
    }
  };
}

test("PATCH /v1/outfits/:id requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/outfits/outfit-uuid-1", { isFavorite: true }, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("PATCH /v1/outfits/:id toggles isFavorite to true and returns 200", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/outfits/outfit-uuid-1", { isFavorite: true });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.outfit);
  assert.equal(res.body.outfit.isFavorite, true);
});

test("PATCH /v1/outfits/:id toggles isFavorite to false and returns 200", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/outfits/outfit-uuid-1", { isFavorite: false });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.outfit);
  assert.equal(res.body.outfit.isFavorite, false);
});

test("PATCH /v1/outfits/:id returns 404 for non-existent outfit", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/outfits/nonexistent-id", { isFavorite: true });

  await handleRequest(req, res, buildContext({ failWith404: true }));

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.code, "NOT_FOUND");
});

test("PATCH /v1/outfits/:id returns 400 when no valid fields provided", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/outfits/outfit-uuid-1", { invalid: "field" });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("No valid fields to update"));
});

test("PATCH /v1/outfits/:id cannot update another user's outfit (RLS)", async () => {
  let capturedUserId;
  const ctx = buildContext();
  ctx.outfitRepository.updateOutfit = async (authContext, outfitId, fields) => {
    capturedUserId = authContext.userId;
    return { id: outfitId, ...fields, items: [] };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/outfits/outfit-uuid-1", { isFavorite: true });

  await handleRequest(req, res, ctx);

  assert.equal(capturedUserId, "firebase-user-123");
});
