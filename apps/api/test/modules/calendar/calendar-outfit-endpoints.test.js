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

let storedCalendarOutfits = [];

function buildContext({ authenticated = true, shouldFailCreate = false, shouldReturn404 = false } = {}) {
  storedCalendarOutfits = [];

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
    calendarOutfitRepo: {
      async createCalendarOutfit(authContext, { outfitId, calendarEventId, scheduledDate, notes }) {
        if (shouldFailCreate) {
          const err = new Error("Foreign key violation");
          err.statusCode = 400;
          throw err;
        }
        const record = {
          id: "co-uuid-1",
          profileId: "profile-uuid-1",
          outfitId,
          calendarEventId: calendarEventId || null,
          scheduledDate,
          notes: notes || null,
          createdAt: "2026-03-19T00:00:00Z",
          updatedAt: "2026-03-19T00:00:00Z",
          outfit: { id: outfitId, name: "Test Outfit", occasion: "casual", source: "ai", items: [] },
        };
        storedCalendarOutfits.push(record);
        return record;
      },
      async getCalendarOutfitsForDateRange(authContext, { startDate, endDate }) {
        return storedCalendarOutfits;
      },
      async updateCalendarOutfit(authContext, calendarOutfitId, { outfitId, calendarEventId, notes }) {
        if (shouldReturn404) {
          const err = new Error("Calendar outfit not found");
          err.statusCode = 404;
          throw err;
        }
        return {
          id: calendarOutfitId,
          profileId: "profile-uuid-1",
          outfitId: outfitId || "outfit-uuid-1",
          calendarEventId: calendarEventId || null,
          scheduledDate: "2026-03-20",
          notes: notes || null,
          createdAt: "2026-03-19T00:00:00Z",
          updatedAt: "2026-03-19T01:00:00Z",
          outfit: { id: outfitId || "outfit-uuid-1", name: "Test Outfit", occasion: "casual", source: "ai", items: [] },
        };
      },
      async deleteCalendarOutfit(authContext, calendarOutfitId) {
        if (shouldReturn404) {
          const err = new Error("Calendar outfit not found");
          err.statusCode = 404;
          throw err;
        }
        return { deleted: true, id: calendarOutfitId };
      },
    },
    calendarService: {},
    outfitGenerationService: {},
    outfitRepository: {},
    usageLimitService: {},
    wearLogRepository: {},
    analyticsRepository: {},
    analyticsSummaryService: {},
    userStatsRepo: {},
    stylePointsService: {},
    levelService: {},
    streakService: {},
    badgeRepo: {},
    badgeService: {},
    challengeRepo: {},
    challengeService: {},
    subscriptionSyncService: {},
    premiumGuard: {},
    resaleListingService: {},
    resaleHistoryRepo: {},
    shoppingScanService: {},
    shoppingScanRepo: {},
    squadService: {},
    ootdService: {},
    extractionService: {},
    extractionRepo: {},
    extractionProcessingService: {},
  };
}

// --- POST /v1/calendar/outfits ---

test("POST /v1/calendar/outfits requires authentication (401)", async () => {
  const req = createJsonRequest("POST", "/v1/calendar/outfits", { outfitId: "o1", scheduledDate: "2026-03-20" }, false);
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext({ authenticated: false }));
  assert.equal(res.statusCode, 401);
});

test("POST /v1/calendar/outfits creates calendar outfit on success (201)", async () => {
  const req = createJsonRequest("POST", "/v1/calendar/outfits", {
    outfitId: "outfit-uuid-1",
    scheduledDate: "2026-03-20",
    notes: "Morning outfit",
  });
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 201);
  assert.ok(res.body.calendarOutfit);
  assert.equal(res.body.calendarOutfit.outfitId, "outfit-uuid-1");
  assert.equal(res.body.calendarOutfit.scheduledDate, "2026-03-20");
});

test("POST /v1/calendar/outfits returns 400 for missing outfitId", async () => {
  const req = createJsonRequest("POST", "/v1/calendar/outfits", {
    scheduledDate: "2026-03-20",
  });
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 400);
});

test("POST /v1/calendar/outfits returns 400 for missing scheduledDate", async () => {
  const req = createJsonRequest("POST", "/v1/calendar/outfits", {
    outfitId: "outfit-uuid-1",
  });
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 400);
});

// --- GET /v1/calendar/outfits ---

test("GET /v1/calendar/outfits requires authentication (401)", async () => {
  const req = createJsonRequest("GET", "/v1/calendar/outfits?startDate=2026-03-19&endDate=2026-03-25", null, false);
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext({ authenticated: false }));
  assert.equal(res.statusCode, 401);
});

test("GET /v1/calendar/outfits returns outfits for date range (200)", async () => {
  const ctx = buildContext();
  // First create one
  const createReq = createJsonRequest("POST", "/v1/calendar/outfits", {
    outfitId: "outfit-uuid-1",
    scheduledDate: "2026-03-20",
  });
  const createRes = createResponseCapture();
  await handleRequest(createReq, createRes, ctx);

  const req = createJsonRequest("GET", "/v1/calendar/outfits?startDate=2026-03-19&endDate=2026-03-25", null);
  const res = createResponseCapture();
  await handleRequest(req, res, ctx);
  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.calendarOutfits));
  assert.equal(res.body.calendarOutfits.length, 1);
});

test("GET /v1/calendar/outfits returns 400 for missing date parameters", async () => {
  const req = createJsonRequest("GET", "/v1/calendar/outfits", null);
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 400);
});

// --- PUT /v1/calendar/outfits/:id ---

test("PUT /v1/calendar/outfits/:id updates the record (200)", async () => {
  const req = createJsonRequest("PUT", "/v1/calendar/outfits/co-uuid-1", {
    outfitId: "new-outfit-uuid",
  });
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 200);
  assert.ok(res.body.calendarOutfit);
});

test("PUT /v1/calendar/outfits/:id returns 404 for non-existent ID", async () => {
  const req = createJsonRequest("PUT", "/v1/calendar/outfits/nonexistent-id", {
    outfitId: "outfit-uuid-1",
  });
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext({ shouldReturn404: true }));
  assert.equal(res.statusCode, 404);
});

// --- DELETE /v1/calendar/outfits/:id ---

test("DELETE /v1/calendar/outfits/:id deletes the record (204)", async () => {
  const req = createJsonRequest("DELETE", "/v1/calendar/outfits/co-uuid-1", null);
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 204);
});

test("DELETE /v1/calendar/outfits/:id returns 404 for non-existent ID", async () => {
  const req = createJsonRequest("DELETE", "/v1/calendar/outfits/nonexistent-id", null);
  const res = createResponseCapture();
  await handleRequest(req, res, buildContext({ shouldReturn404: true }));
  assert.equal(res.statusCode, 404);
});
