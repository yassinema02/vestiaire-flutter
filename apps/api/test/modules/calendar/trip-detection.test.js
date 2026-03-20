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

function buildContext({ authenticated = true, events = [], shouldFailGemini = false, geminiAvailable = true, items = [] } = {}) {
  const packingListResponse = {
    packingList: {
      categories: [
        { name: "Tops", items: [{ itemId: items[0]?.id ?? "item-1", name: "Top 1", reason: "Versatile" }] },
      ],
      dailyOutfits: [],
      tips: ["Pack light"],
    }
  };

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
    calendarEventRepo: {
      async getEventsForDateRange(authContext, params) {
        return events;
      }
    },
    calendarOutfitRepo: {},
    calendarService: {},
    outfitGenerationService: {
      async generatePackingList(authContext, params) {
        if (shouldFailGemini) {
          throw { statusCode: 503, message: "AI service unavailable" };
        }
        return {
          packingList: {
            categories: packingListResponse.packingList.categories,
            dailyOutfits: [],
            tips: ["Pack light"],
            fallback: false,
            weatherUnavailable: false,
          },
          generatedAt: new Date().toISOString(),
        };
      }
    },
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
    tripDetectionService: {
      async detectTrips(authContext, opts) {
        if (events.length === 0) return [];
        return [
          {
            id: "trip_barcelona_2026-03-20_2026-03-24",
            destination: "Barcelona",
            startDate: "2026-03-20",
            endDate: "2026-03-24",
            durationDays: 4,
            eventIds: events.map((e) => e.id),
            destinationCoordinates: { latitude: 41.39, longitude: 2.17 },
          }
        ];
      },
      async fetchDestinationWeather(lat, lon, start, end) {
        return [
          { date: "2026-03-20", highTemp: 18, lowTemp: 12, weatherCode: 1 },
        ];
      },
    },
    itemRepo: {
      async listItems(authContext, filters) {
        return items.length > 0 ? items : [
          { id: "item-1", name: "Top", category: "tops", categorizationStatus: "completed", photoUrl: "https://example.com/1.jpg" },
          { id: "item-2", name: "Bottom", category: "bottoms", categorizationStatus: "completed", photoUrl: "https://example.com/2.jpg" },
          { id: "item-3", name: "Shoes", category: "shoes", categorizationStatus: "completed", photoUrl: "https://example.com/3.jpg" },
        ];
      }
    },
  };
}

// --- POST /v1/calendar/trips/detect ---

test("POST /v1/calendar/trips/detect requires authentication (401)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/detect", {}, false);
  await handleRequest(req, res, buildContext({ authenticated: false }));
  assert.equal(res.statusCode, 401);
});

test("POST /v1/calendar/trips/detect returns 200 with trips on success", async () => {
  const events = [
    { id: "e1", title: "Conference", location: "Barcelona", start_time: "2026-03-20T09:00:00Z", end_time: "2026-03-24T17:00:00Z", all_day: true }
  ];

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/detect", { lookaheadDays: 14 });
  await handleRequest(req, res, buildContext({ events }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.trips);
  assert.ok(Array.isArray(res.body.trips));
  assert.ok(res.body.trips.length > 0);
  assert.equal(res.body.trips[0].destination, "Barcelona");
});

test("POST /v1/calendar/trips/detect returns 200 with empty array when no trips", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/detect", {});
  await handleRequest(req, res, buildContext({ events: [] }));

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.trips, []);
});

test("POST /v1/calendar/trips/detect respects lookaheadDays parameter", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/detect", { lookaheadDays: 7 });
  await handleRequest(req, res, buildContext({ events: [] }));

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.trips, []);
});

// --- POST /v1/calendar/trips/:tripId/packing-list ---

test("POST /v1/calendar/trips/:tripId/packing-list requires authentication (401)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/trip-1/packing-list", {
    trip: { destination: "Barcelona", startDate: "2026-03-20", endDate: "2026-03-24", durationDays: 4 }
  }, false);
  await handleRequest(req, res, buildContext({ authenticated: false }));
  assert.equal(res.statusCode, 401);
});

test("POST /v1/calendar/trips/:tripId/packing-list returns 200 with packing list on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/trip-1/packing-list", {
    trip: {
      destination: "Barcelona",
      startDate: "2026-03-20",
      endDate: "2026-03-24",
      durationDays: 4,
      destinationCoordinates: { latitude: 41.39, longitude: 2.17 },
    }
  });
  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.packingList);
  assert.ok(res.body.generatedAt);
});

test("POST /v1/calendar/trips/:tripId/packing-list returns 400 for missing trip data", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/trip-1/packing-list", {});
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 400);
});

test("POST /v1/calendar/trips/:tripId/packing-list returns 400 for incomplete trip data", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/trip-1/packing-list", {
    trip: { destination: "Barcelona" }
  });
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 400);
});

test("POST /v1/calendar/trips/:tripId/packing-list returns 503 when Gemini unavailable", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/trip-1/packing-list", {
    trip: {
      destination: "Barcelona",
      startDate: "2026-03-20",
      endDate: "2026-03-24",
      durationDays: 4,
    }
  });
  await handleRequest(req, res, buildContext({ shouldFailGemini: true }));
  assert.equal(res.statusCode, 503);
});

test("POST /v1/calendar/trips/:tripId/packing-list marks weather unavailable when no coordinates", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/calendar/trips/trip-1/packing-list", {
    trip: {
      destination: "Barcelona",
      startDate: "2026-03-20",
      endDate: "2026-03-24",
      durationDays: 4,
      // No destinationCoordinates
    }
  });
  await handleRequest(req, res, buildContext());
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.packingList.weatherUnavailable, true);
});
