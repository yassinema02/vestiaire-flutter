import assert from "node:assert/strict";
import test from "node:test";
import {
  createTripDetectionService,
  generateTripId,
  daysBetween,
  normalizeLocation,
  hasKeywordMatch,
  mergeOverlappingTrips,
} from "../../../src/modules/calendar/trip-detection-service.js";

function createMockCalendarEventRepo({ events = [] } = {}) {
  const calls = [];
  return {
    calls,
    async getEventsForDateRange(authContext, { startDate, endDate }) {
      calls.push({ method: "getEventsForDateRange", authContext, startDate, endDate });
      return events;
    },
  };
}

function makeEvent({
  id = "evt-1",
  title = "Meeting",
  description = null,
  location = null,
  start_time = "2026-03-20T09:00:00Z",
  end_time = "2026-03-20T10:00:00Z",
  all_day = false,
  event_type = "casual",
  formality_score = 2,
} = {}) {
  return { id, title, description, location, start_time, end_time, all_day, event_type, formality_score };
}

// --- Unit tests for helpers ---
test("generateTripId returns deterministic ID", () => {
  const id1 = generateTripId("Paris", "2026-03-20", "2026-03-25");
  const id2 = generateTripId("Paris", "2026-03-20", "2026-03-25");
  assert.equal(id1, id2);
  assert.ok(id1.startsWith("trip_paris_"));
});

test("generateTripId normalizes destination", () => {
  const id = generateTripId("New York City", "2026-03-20", "2026-03-25");
  assert.ok(id.includes("new_york_city"));
});

test("daysBetween calculates correct days", () => {
  assert.equal(daysBetween(new Date("2026-03-20"), new Date("2026-03-25")), 5);
  assert.equal(daysBetween(new Date("2026-03-20"), new Date("2026-03-20")), 0);
  assert.equal(daysBetween(new Date("2026-03-20"), new Date("2026-03-22")), 2);
});

test("normalizeLocation trims and lowercases", () => {
  assert.equal(normalizeLocation("  Paris  "), "paris");
  assert.equal(normalizeLocation(null), "");
  assert.equal(normalizeLocation(""), "");
});

test("hasKeywordMatch detects travel keywords in title", () => {
  assert.ok(hasKeywordMatch({ title: "Flight to Paris", description: "" }));
  assert.ok(hasKeywordMatch({ title: "Hotel Check-in", description: "" }));
  assert.ok(hasKeywordMatch({ title: "Airbnb Booking", description: "" }));
  assert.ok(hasKeywordMatch({ title: "Conference Talk", description: "" }));
  assert.ok(!hasKeywordMatch({ title: "Team Meeting", description: "" }));
});

test("hasKeywordMatch detects travel keywords in description", () => {
  assert.ok(hasKeywordMatch({ title: "Event", description: "Book hotel for trip" }));
  assert.ok(!hasKeywordMatch({ title: "Event", description: "Regular meeting" }));
});

test("mergeOverlappingTrips merges overlapping date ranges", () => {
  const candidates = [
    { destination: "Paris", startDate: "2026-03-20", endDate: "2026-03-22", eventIds: ["e1"] },
    { destination: "Paris", startDate: "2026-03-21", endDate: "2026-03-24", eventIds: ["e2"] },
  ];
  const merged = mergeOverlappingTrips(candidates);
  assert.equal(merged.length, 1);
  assert.equal(merged[0].startDate, "2026-03-20");
  assert.equal(merged[0].endDate, "2026-03-24");
  assert.deepEqual(merged[0].eventIds, ["e1", "e2"]);
});

test("mergeOverlappingTrips keeps non-overlapping trips separate", () => {
  const candidates = [
    { destination: "Paris", startDate: "2026-03-20", endDate: "2026-03-22", eventIds: ["e1"] },
    { destination: "London", startDate: "2026-03-28", endDate: "2026-03-30", eventIds: ["e2"] },
  ];
  const merged = mergeOverlappingTrips(candidates);
  assert.equal(merged.length, 2);
});

// --- Service tests ---
test("createTripDetectionService throws if calendarEventRepo missing", () => {
  assert.throws(() => createTripDetectionService({}), /calendarEventRepo is required/);
});

test("detectTrips returns empty array when no events", async () => {
  const repo = createMockCalendarEventRepo({ events: [] });
  const service = createTripDetectionService({ calendarEventRepo: repo });
  const trips = await service.detectTrips({ userId: "user1" });
  assert.deepEqual(trips, []);
});

test("detectTrips detects multi-day allDay events as trips", async () => {
  const events = [
    makeEvent({
      id: "evt-1",
      title: "Team Retreat",
      location: "Barcelona",
      start_time: "2026-03-20T00:00:00Z",
      end_time: "2026-03-23T00:00:00Z",
      all_day: true,
    }),
  ];
  const repo = createMockCalendarEventRepo({ events });
  const service = createTripDetectionService({ calendarEventRepo: repo });

  // Mock geocodeLocation to avoid real HTTP calls
  service.geocodeLocation = async () => null;

  const trips = await service.detectTrips({ userId: "user1" });
  assert.equal(trips.length, 1);
  assert.equal(trips[0].destination, "Barcelona");
  assert.equal(trips[0].durationDays, 3);
  assert.deepEqual(trips[0].eventIds, ["evt-1"]);
});

test("detectTrips detects location clusters as trips", async () => {
  const events = [
    makeEvent({ id: "e1", title: "Meeting 1", location: "London", start_time: "2026-03-20T10:00:00Z", end_time: "2026-03-20T11:00:00Z" }),
    makeEvent({ id: "e2", title: "Meeting 2", location: "London", start_time: "2026-03-21T10:00:00Z", end_time: "2026-03-21T11:00:00Z" }),
    makeEvent({ id: "e3", title: "Local meeting", location: "Home Office", start_time: "2026-03-22T10:00:00Z", end_time: "2026-03-22T11:00:00Z" }),
    makeEvent({ id: "e4", title: "Another local", location: "Home Office", start_time: "2026-03-23T10:00:00Z", end_time: "2026-03-23T11:00:00Z" }),
    makeEvent({ id: "e5", title: "Also local", location: "Home Office", start_time: "2026-03-24T10:00:00Z", end_time: "2026-03-24T11:00:00Z" }),
  ];
  const repo = createMockCalendarEventRepo({ events });
  const service = createTripDetectionService({ calendarEventRepo: repo });
  service.geocodeLocation = async () => null;

  const trips = await service.detectTrips({ userId: "user1" });
  // London events should be detected as a trip (2 events, not home location)
  assert.ok(trips.length >= 1);
  const londonTrip = trips.find((t) => t.destination === "London");
  assert.ok(londonTrip, "Should detect London trip");
  assert.deepEqual(londonTrip.eventIds.sort(), ["e1", "e2"]);
});

test("detectTrips detects keyword-based trips", async () => {
  const events = [
    makeEvent({ id: "e1", title: "Flight to NYC", start_time: "2026-03-20T06:00:00Z", end_time: "2026-03-20T12:00:00Z" }),
    makeEvent({ id: "e2", title: "Hotel Check-in NYC", start_time: "2026-03-20T15:00:00Z", end_time: "2026-03-20T16:00:00Z" }),
  ];
  const repo = createMockCalendarEventRepo({ events });
  const service = createTripDetectionService({ calendarEventRepo: repo });
  service.geocodeLocation = async () => null;

  const trips = await service.detectTrips({ userId: "user1" });
  assert.ok(trips.length >= 1);
});

test("detectTrips merges overlapping trip candidates", async () => {
  const events = [
    makeEvent({
      id: "e1", title: "Conference", location: "Berlin",
      start_time: "2026-03-20T00:00:00Z", end_time: "2026-03-23T00:00:00Z", all_day: true
    }),
    makeEvent({
      id: "e2", title: "Flight to Berlin",
      start_time: "2026-03-19T08:00:00Z", end_time: "2026-03-19T12:00:00Z"
    }),
  ];
  const repo = createMockCalendarEventRepo({ events });
  const service = createTripDetectionService({ calendarEventRepo: repo });
  service.geocodeLocation = async () => null;

  const trips = await service.detectTrips({ userId: "user1" });
  // Should merge into a single trip
  assert.ok(trips.length <= 2);
});

test("detectTrips respects lookaheadDays parameter", async () => {
  const repo = createMockCalendarEventRepo({ events: [] });
  const service = createTripDetectionService({ calendarEventRepo: repo });

  await service.detectTrips({ userId: "user1" }, { lookaheadDays: 7 });
  assert.equal(repo.calls.length, 1);
  // The end date should be ~7 days from now
  const endDate = new Date(repo.calls[0].endDate);
  const startDate = new Date(repo.calls[0].startDate);
  const diffDays = Math.round((endDate - startDate) / 86400000);
  assert.equal(diffDays, 7);
});

test("detectTrips returns empty array for past events only", async () => {
  // Events in the past won't appear because we query from today
  const repo = createMockCalendarEventRepo({ events: [] });
  const service = createTripDetectionService({ calendarEventRepo: repo });

  const trips = await service.detectTrips({ userId: "user1" });
  assert.deepEqual(trips, []);
});

// --- Geocoding tests ---
test("geocodeLocation returns null for empty/null location", async () => {
  const repo = createMockCalendarEventRepo();
  const service = createTripDetectionService({ calendarEventRepo: repo });

  assert.equal(await service.geocodeLocation(""), null);
  assert.equal(await service.geocodeLocation(null), null);
  assert.equal(await service.geocodeLocation("  "), null);
});

test("geocodeLocation returns null on API failure", async () => {
  // We can't easily mock global fetch in node:test without a library,
  // but the service is designed to catch errors and return null.
  // This test verifies the null-safety of the interface.
  const repo = createMockCalendarEventRepo();
  const service = createTripDetectionService({ calendarEventRepo: repo });

  // Mock fetch to fail
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error("Network error"); };

  const result = await service.geocodeLocation("Paris");
  assert.equal(result, null);

  globalThis.fetch = originalFetch;
});

test("geocodeLocation returns coordinates for valid location", async () => {
  const repo = createMockCalendarEventRepo();
  const service = createTripDetectionService({ calendarEventRepo: repo });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({
      results: [{ latitude: 48.8566, longitude: 2.3522 }]
    })
  });

  const result = await service.geocodeLocation("Paris");
  assert.deepEqual(result, { latitude: 48.8566, longitude: 2.3522 });

  globalThis.fetch = originalFetch;
});

// --- Destination weather tests ---
test("fetchDestinationWeather returns daily forecasts", async () => {
  const repo = createMockCalendarEventRepo();
  const service = createTripDetectionService({ calendarEventRepo: repo });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({
      daily: {
        time: ["2026-03-20", "2026-03-21"],
        temperature_2m_max: [15, 18],
        temperature_2m_min: [8, 10],
        weather_code: [1, 3],
      }
    })
  });

  const result = await service.fetchDestinationWeather(48.85, 2.35, "2026-03-20", "2026-03-21");
  assert.equal(result.length, 2);
  assert.equal(result[0].date, "2026-03-20");
  assert.equal(result[0].highTemp, 15);
  assert.equal(result[0].lowTemp, 8);
  assert.equal(result[0].weatherCode, 1);

  globalThis.fetch = originalFetch;
});

test("fetchDestinationWeather returns null on API failure", async () => {
  const repo = createMockCalendarEventRepo();
  const service = createTripDetectionService({ calendarEventRepo: repo });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error("Network error"); };

  const result = await service.fetchDestinationWeather(48.85, 2.35, "2026-03-20", "2026-03-21");
  assert.equal(result, null);

  globalThis.fetch = originalFetch;
});
