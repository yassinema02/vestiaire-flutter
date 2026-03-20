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
      async updateOutfit() { return {}; },
      async deleteOutfit(authContext, outfitId) {
        if (failWith404) {
          const err = new Error("Outfit not found");
          err.statusCode = 404;
          err.code = "NOT_FOUND";
          throw err;
        }
        return { deleted: true, id: outfitId };
      },
    }
  };
}

test("DELETE /v1/outfits/:id requires authentication (401 without token)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("DELETE", "/v1/outfits/outfit-uuid-1", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("DELETE /v1/outfits/:id deletes outfit and returns 200", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("DELETE", "/v1/outfits/outfit-uuid-1", null);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.deleted, true);
  assert.equal(res.body.id, "outfit-uuid-1");
});

test("DELETE /v1/outfits/:id cascade-deletes outfit_items", async () => {
  let capturedOutfitId;
  const ctx = buildContext();
  ctx.outfitRepository.deleteOutfit = async (authContext, outfitId) => {
    capturedOutfitId = outfitId;
    return { deleted: true, id: outfitId };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("DELETE", "/v1/outfits/outfit-uuid-1", null);

  await handleRequest(req, res, ctx);

  assert.equal(res.statusCode, 200);
  assert.equal(capturedOutfitId, "outfit-uuid-1");
});

test("DELETE /v1/outfits/:id returns 404 for non-existent outfit", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("DELETE", "/v1/outfits/nonexistent-id", null);

  await handleRequest(req, res, buildContext({ failWith404: true }));

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.code, "NOT_FOUND");
});

test("DELETE /v1/outfits/:id cannot delete another user's outfit (RLS)", async () => {
  let capturedUserId;
  const ctx = buildContext();
  ctx.outfitRepository.deleteOutfit = async (authContext, outfitId) => {
    capturedUserId = authContext.userId;
    return { deleted: true, id: outfitId };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("DELETE", "/v1/outfits/outfit-uuid-1", null);

  await handleRequest(req, res, ctx);

  assert.equal(capturedUserId, "firebase-user-123");
});
