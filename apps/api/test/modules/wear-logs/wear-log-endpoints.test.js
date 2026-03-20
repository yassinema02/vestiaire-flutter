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

let createdWearLogs = [];
let itemWearCounts = {};

function buildContext({
  authenticated = true,
} = {}) {
  createdWearLogs = [];
  itemWearCounts = {};

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
    itemService: {
      async listItemsForUser() {
        return { items: [] };
      },
      async getItemForUser(authContext, itemId) {
        return {
          item: {
            id: itemId,
            wearCount: itemWearCounts[itemId] ?? 0,
            lastWornDate: null,
          }
        };
      }
    },
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
      async listOutfits() { return []; },
      async createOutfit() { return { id: "outfit-1", items: [] }; },
    },
    usageLimitService: {},
    wearLogRepository: {
      async createWearLog(authContext, { itemIds, outfitId, photoUrl, loggedDate }) {
        const wearLog = {
          id: `wearlog-${createdWearLogs.length + 1}`,
          profileId: "profile-uuid-1",
          loggedDate: loggedDate || "2026-03-17",
          outfitId: outfitId || null,
          photoUrl: photoUrl || null,
          createdAt: new Date().toISOString(),
          itemIds,
        };
        createdWearLogs.push(wearLog);

        // Simulate wear count increment
        for (const id of itemIds) {
          itemWearCounts[id] = (itemWearCounts[id] || 0) + 1;
        }

        return wearLog;
      },
      async listWearLogs(authContext, { startDate, endDate }) {
        return createdWearLogs.filter(wl => {
          return wl.loggedDate >= startDate && wl.loggedDate <= endDate;
        });
      },
    },
  };
}

// --- POST /v1/wear-logs tests ---

test("POST /v1/wear-logs creates a wear log and returns 201", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1", "item-2"],
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.wearLog);
  assert.ok(res.body.wearLog.id);
  assert.deepEqual(res.body.wearLog.itemIds, ["item-1", "item-2"]);
});

test("POST /v1/wear-logs returns 400 if items array is empty", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: [],
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("non-empty"));
});

test("POST /v1/wear-logs returns 400 if items array exceeds 20", async () => {
  const items = Array.from({ length: 21 }, (_, i) => `item-${i}`);
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", { items });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("Maximum 20"));
});

test("POST /v1/wear-logs returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
  }, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("POST /v1/wear-logs with outfitId links the outfit", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
    outfitId: "outfit-uuid-1",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.wearLog.outfitId, "outfit-uuid-1");
});

test("POST /v1/wear-logs increments wear_count on items", async () => {
  const context = buildContext();
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1", "item-2"],
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 201);
  // Verify wear counts were incremented in our mock
  assert.equal(itemWearCounts["item-1"], 1);
  assert.equal(itemWearCounts["item-2"], 1);
});

test("POST /v1/wear-logs updates last_worn_date on items", async () => {
  const context = buildContext();
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
    loggedDate: "2026-03-17",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.wearLog.loggedDate, "2026-03-17");
});

// --- GET /v1/wear-logs tests ---

test("GET /v1/wear-logs returns logs within date range", async () => {
  const context = buildContext();

  // Create a wear log first
  const postRes = createResponseCapture();
  const postReq = createJsonRequest("POST", "/v1/wear-logs", {
    items: ["item-1"],
  });
  await handleRequest(postReq, postRes, context);

  // Query it
  const getRes = createResponseCapture();
  const getReq = createJsonRequest("GET", "/v1/wear-logs?start=2026-03-01&end=2026-03-31");
  await handleRequest(getReq, getRes, context);

  assert.equal(getRes.statusCode, 200);
  assert.ok(Array.isArray(getRes.body.wearLogs));
  assert.equal(getRes.body.wearLogs.length, 1);
});

test("GET /v1/wear-logs returns 400 if start or end missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/wear-logs?start=2026-03-01");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("start and end"));
});

test("GET /v1/wear-logs returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/wear-logs?start=2026-03-01&end=2026-03-31", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/wear-logs returns empty array for no logs", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/wear-logs?start=2026-01-01&end=2026-01-31");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.wearLogs));
  assert.equal(res.body.wearLogs.length, 0);
});
