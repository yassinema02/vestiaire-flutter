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
  summaryResult = null,
  itemsCpwResult = null,
  topWornResult = null,
  neglectedResult = null,
  topWornError = null,
  categoryDistributionResult = null,
  wearFrequencyResult = null,
  brandValueResult = null,
  brandValueError = null,
  sustainabilityResult = null,
  sustainabilityError = null,
  premiumUser = true,
  badgeCheckAndAwardResult = false,
  seasonalReportsResult = null,
  seasonalReportsError = null,
  heatmapResult = null,
  heatmapError = null,
  wardrobeHealthResult = null,
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
    premiumGuard: {
      async requirePremium(authContext) {
        if (!premiumUser) {
          throw { statusCode: 403, code: "PREMIUM_REQUIRED", message: "Premium subscription required" };
        }
        return { isPremium: true, profileId: "profile-123", premiumSource: "revenuecat" };
      },
      async checkPremium(authContext) {
        return { isPremium: premiumUser, profileId: "profile-123", premiumSource: premiumUser ? "revenuecat" : null };
      },
    },
    profileService: {},
    itemService: {
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(authContext, itemId) { return { item: { id: itemId } }; }
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {
      async generateOutfits() { return { suggestions: [] }; }
    },
    outfitRepository: {
      async listOutfits() { return []; },
      async createOutfit() { return { id: "outfit-1", items: [] }; },
    },
    usageLimitService: {},
    wearLogRepository: {
      async createWearLog() { return { id: "wl-1", itemIds: [] }; },
      async listWearLogs() { return []; },
    },
    analyticsRepository: {
      async getWardrobeSummary() {
        return summaryResult || {
          totalItems: 10,
          pricedItems: 7,
          totalValue: 1500.00,
          totalWears: 120,
          averageCpw: 12.50,
          dominantCurrency: "GBP",
        };
      },
      async getItemsWithCpw() {
        return itemsCpwResult || [
          {
            id: "item-1",
            name: "Blue Shirt",
            category: "tops",
            photoUrl: "https://example.com/photo.jpg",
            purchasePrice: 50.00,
            currency: "GBP",
            wearCount: 10,
            cpw: 5.00,
          },
        ];
      },
      async getTopWornItems(authContext, { period } = {}) {
        if (topWornError) throw topWornError;
        return topWornResult || [
          {
            id: "item-1",
            name: "Fave Jacket",
            category: "outerwear",
            photoUrl: null,
            wearCount: 25,
            lastWornDate: "2026-03-10",
          },
        ];
      },
      async getNeglectedItems() {
        return neglectedResult || [
          {
            id: "item-2",
            name: "Old Dress",
            category: "dresses",
            photoUrl: null,
            purchasePrice: 100.00,
            currency: "GBP",
            wearCount: 2,
            lastWornDate: "2025-10-01",
            daysSinceWorn: 168,
            cpw: 50.00,
          },
        ];
      },
      async getCategoryDistribution() {
        return categoryDistributionResult || [
          { category: "tops", itemCount: 14, percentage: 56.0 },
          { category: "bottoms", itemCount: 8, percentage: 32.0 },
          { category: "shoes", itemCount: 3, percentage: 12.0 },
        ];
      },
      async getWearFrequency() {
        return wearFrequencyResult || [
          { day: "Mon", dayIndex: 0, logCount: 5 },
          { day: "Tue", dayIndex: 1, logCount: 3 },
          { day: "Wed", dayIndex: 2, logCount: 7 },
          { day: "Thu", dayIndex: 3, logCount: 2 },
          { day: "Fri", dayIndex: 4, logCount: 6 },
          { day: "Sat", dayIndex: 5, logCount: 8 },
          { day: "Sun", dayIndex: 6, logCount: 4 },
        ];
      },
      async getBrandValueAnalytics(authContext, { category } = {}) {
        if (brandValueError) throw brandValueError;
        return brandValueResult || {
          brands: [
            { brand: "Uniqlo", itemCount: 5, totalSpent: 250.00, totalWears: 100, avgCpw: 2.50, pricedItems: 5, dominantCurrency: "GBP" },
            { brand: "Zara", itemCount: 4, totalSpent: 400.00, totalWears: 60, avgCpw: 6.67, pricedItems: 4, dominantCurrency: "GBP" },
          ],
          availableCategories: ["bottoms", "tops"],
          bestValueBrand: { brand: "Uniqlo", avgCpw: 2.50, currency: "GBP" },
          mostInvestedBrand: { brand: "Zara", totalSpent: 400.00, currency: "GBP" },
        };
      },
      async getSustainabilityAnalytics(authContext) {
        if (sustainabilityError) throw sustainabilityError;
        return sustainabilityResult || {
          score: 65,
          factors: {
            avgWearScore: 50,
            utilizationScore: 60,
            cpwScore: 62.5,
            resaleScore: 100,
            newPurchaseScore: 100,
          },
          co2SavedKg: 10.0,
          co2CarKmEquivalent: 47.6,
          percentile: 35,
          totalRewears: 20,
          totalItems: 10,
          badgeAwarded: false,
        };
      },
      async getSeasonalReports(authContext) {
        if (seasonalReportsError) throw seasonalReportsError;
        return seasonalReportsResult || {
          seasons: [
            { season: "spring", itemCount: 8, totalWears: 24, mostWorn: [], neglected: [], readinessScore: 6, historicalComparison: { percentChange: 10, comparisonText: "+10% more items worn vs last spring" } },
            { season: "summer", itemCount: 12, totalWears: 40, mostWorn: [], neglected: [], readinessScore: 8, historicalComparison: { percentChange: null, comparisonText: "First summer tracked -- keep logging to see trends!" } },
            { season: "fall", itemCount: 10, totalWears: 30, mostWorn: [], neglected: [], readinessScore: 7, historicalComparison: { percentChange: -5, comparisonText: "-5% fewer items worn vs last fall" } },
            { season: "winter", itemCount: 6, totalWears: 15, mostWorn: [], neglected: [], readinessScore: 4, historicalComparison: { percentChange: null, comparisonText: "First winter tracked -- keep logging to see trends!" } },
          ],
          currentSeason: "spring",
          transitionAlert: null,
          totalItems: 36,
        };
      },
      async getWardrobeHealthScore(authContext) {
        return wardrobeHealthResult || {
          score: 65,
          factors: {
            utilizationScore: 50,
            cpwScore: 60,
            sizeUtilizationScore: 50,
          },
          percentile: 35,
          recommendation: "Wear 6 more items this month to reach Green status",
          totalItems: 20,
          itemsWorn90d: 10,
          colorTier: "yellow",
        };
      },
      async getHeatmapData(authContext, { startDate, endDate }) {
        if (heatmapError) throw heatmapError;
        return heatmapResult || {
          dailyActivity: [
            { date: "2026-03-01", itemsCount: 3 },
            { date: "2026-03-02", itemsCount: 1 },
          ],
          streakStats: {
            currentStreak: 5,
            longestStreak: 12,
            totalDaysLogged: 45,
            avgItemsPerDay: 2.8,
          },
        };
      },
    },
    badgeService: {
      async checkAndAward(authContext, badgeKey) {
        return badgeCheckAndAwardResult;
      },
      async evaluateAndAward() { return { awarded: [] }; },
      async getUserBadgeCollection() { return { badges: [], badgeCount: 0 }; },
      async getBadgeCatalog() { return []; },
    },
  };
}

// --- GET /v1/analytics/wardrobe-summary tests ---

test("GET /v1/analytics/wardrobe-summary returns 200 with summary object", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-summary");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.summary);
  assert.equal(res.body.summary.totalItems, 10);
  assert.equal(res.body.summary.pricedItems, 7);
  assert.equal(res.body.summary.totalValue, 1500.00);
  assert.equal(res.body.summary.totalWears, 120);
  assert.equal(res.body.summary.averageCpw, 12.50);
  assert.equal(res.body.summary.dominantCurrency, "GBP");
});

test("GET /v1/analytics/wardrobe-summary returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-summary", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/wardrobe-summary returns zeros for user with no items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-summary");

  await handleRequest(req, res, buildContext({
    summaryResult: {
      totalItems: 0,
      pricedItems: 0,
      totalValue: 0,
      totalWears: 0,
      averageCpw: null,
      dominantCurrency: null,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.summary.totalItems, 0);
  assert.equal(res.body.summary.totalValue, 0);
  assert.equal(res.body.summary.averageCpw, null);
  assert.equal(res.body.summary.dominantCurrency, null);
});

// --- GET /v1/analytics/items-cpw tests ---

test("GET /v1/analytics/items-cpw returns 200 with items array", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/items-cpw");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 1);
  assert.equal(res.body.items[0].id, "item-1");
  assert.equal(res.body.items[0].name, "Blue Shirt");
  assert.equal(res.body.items[0].cpw, 5.00);
});

test("GET /v1/analytics/items-cpw returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/items-cpw", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/items-cpw returns empty array for user with no priced items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/items-cpw");

  await handleRequest(req, res, buildContext({ itemsCpwResult: [] }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 0);
});

test("GET /v1/analytics/items-cpw correctly calculates CPW for items with wears", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/items-cpw");

  await handleRequest(req, res, buildContext({
    itemsCpwResult: [
      { id: "item-a", name: "Jacket", category: "outerwear", photoUrl: null, purchasePrice: 200.00, currency: "GBP", wearCount: 20, cpw: 10.00 },
      { id: "item-b", name: "Scarf", category: "accessories", photoUrl: null, purchasePrice: 25.00, currency: "GBP", wearCount: 50, cpw: 0.50 },
    ],
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.items[0].cpw, 10.00);
  assert.equal(res.body.items[1].cpw, 0.50);
});

test("GET /v1/analytics/items-cpw returns null CPW for items with zero wears", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/items-cpw");

  await handleRequest(req, res, buildContext({
    itemsCpwResult: [
      { id: "item-new", name: "New Dress", category: "dresses", photoUrl: null, purchasePrice: 150.00, currency: "GBP", wearCount: 0, cpw: null },
    ],
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.items[0].cpw, null);
  assert.equal(res.body.items[0].wearCount, 0);
});

// --- GET /v1/analytics/top-worn tests ---

test("GET /v1/analytics/top-worn returns 200 with items array (default period=all)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/top-worn");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 1);
  assert.equal(res.body.items[0].id, "item-1");
  assert.equal(res.body.items[0].name, "Fave Jacket");
  assert.equal(res.body.items[0].wearCount, 25);
});

test("GET /v1/analytics/top-worn?period=30 returns 200 with period-filtered items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/top-worn?period=30");

  await handleRequest(req, res, buildContext({
    topWornResult: [
      { id: "item-1", name: "Recent Fave", category: "tops", photoUrl: null, wearCount: 50, lastWornDate: "2026-03-15", periodWearCount: 8 },
    ],
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items[0].periodWearCount, 8);
});

test("GET /v1/analytics/top-worn?period=90 returns 200 with period-filtered items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/top-worn?period=90");

  await handleRequest(req, res, buildContext({
    topWornResult: [
      { id: "item-1", name: "Seasonal Pick", category: "outerwear", photoUrl: null, wearCount: 30, lastWornDate: "2026-03-10", periodWearCount: 12 },
    ],
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.items[0].periodWearCount, 12);
});

test("GET /v1/analytics/top-worn?period=invalid returns 400", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/top-worn?period=invalid");

  const error = new Error("Invalid period. Must be 'all', '30', or '90'");
  error.statusCode = 400;

  await handleRequest(req, res, buildContext({ topWornError: error }));

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("Invalid period"));
});

test("GET /v1/analytics/top-worn returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/top-worn", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/top-worn returns empty array for user with no worn items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/top-worn");

  await handleRequest(req, res, buildContext({ topWornResult: [] }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 0);
});

// --- GET /v1/analytics/neglected tests ---

test("GET /v1/analytics/neglected returns 200 with items array", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/neglected");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 1);
  assert.equal(res.body.items[0].id, "item-2");
  assert.equal(res.body.items[0].name, "Old Dress");
  assert.equal(res.body.items[0].daysSinceWorn, 168);
});

test("GET /v1/analytics/neglected returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/neglected", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/neglected returns empty array when no items are neglected", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/neglected");

  await handleRequest(req, res, buildContext({ neglectedResult: [] }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.items));
  assert.equal(res.body.items.length, 0);
});

// --- GET /v1/analytics/category-distribution tests ---

test("GET /v1/analytics/category-distribution returns 200 with categories array", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/category-distribution");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.categories));
  assert.equal(res.body.categories.length, 3);
  assert.equal(res.body.categories[0].category, "tops");
  assert.equal(res.body.categories[0].itemCount, 14);
  assert.equal(res.body.categories[0].percentage, 56.0);
});

test("GET /v1/analytics/category-distribution returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/category-distribution", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/category-distribution returns empty array for user with no items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/category-distribution");

  await handleRequest(req, res, buildContext({ categoryDistributionResult: [] }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.categories));
  assert.equal(res.body.categories.length, 0);
});

// --- GET /v1/analytics/wear-frequency tests ---

test("GET /v1/analytics/wear-frequency returns 200 with 7-element days array", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wear-frequency");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.days));
  assert.equal(res.body.days.length, 7);
  assert.equal(res.body.days[0].day, "Mon");
  assert.equal(res.body.days[0].logCount, 5);
  assert.equal(res.body.days[6].day, "Sun");
  assert.equal(res.body.days[6].logCount, 4);
});

test("GET /v1/analytics/wear-frequency returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wear-frequency", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/wear-frequency returns all-zero counts for user with no wear logs", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wear-frequency");

  await handleRequest(req, res, buildContext({
    wearFrequencyResult: [
      { day: "Mon", dayIndex: 0, logCount: 0 },
      { day: "Tue", dayIndex: 1, logCount: 0 },
      { day: "Wed", dayIndex: 2, logCount: 0 },
      { day: "Thu", dayIndex: 3, logCount: 0 },
      { day: "Fri", dayIndex: 4, logCount: 0 },
      { day: "Sat", dayIndex: 5, logCount: 0 },
      { day: "Sun", dayIndex: 6, logCount: 0 },
    ],
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.days.length, 7);
  for (const day of res.body.days) {
    assert.equal(day.logCount, 0);
  }
});

// --- GET /v1/analytics/brand-value tests ---

test("GET /v1/analytics/brand-value returns 200 with brands array for premium user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.brands));
  assert.equal(res.body.brands.length, 2);
  assert.equal(res.body.brands[0].brand, "Uniqlo");
  assert.equal(res.body.brands[0].avgCpw, 2.50);
});

test("GET /v1/analytics/brand-value returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/brand-value returns 403 with PREMIUM_REQUIRED for free user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value");

  await handleRequest(req, res, buildContext({ premiumUser: false }));

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.code, "PREMIUM_REQUIRED");
});

test("GET /v1/analytics/brand-value?category=tops returns filtered brand data", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value?category=tops");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.brands));
});

test("GET /v1/analytics/brand-value?category=invalid returns 400", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value?category=invalid");

  const error = new Error("Invalid category");
  error.statusCode = 400;

  await handleRequest(req, res, buildContext({ premiumUser: true, brandValueError: error }));

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.error.includes("Invalid category"));
});

test("GET /v1/analytics/brand-value returns empty brands array for user with no qualifying brands", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value");

  await handleRequest(req, res, buildContext({
    premiumUser: true,
    brandValueResult: {
      brands: [],
      availableCategories: [],
      bestValueBrand: null,
      mostInvestedBrand: null,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.brands));
  assert.equal(res.body.brands.length, 0);
});

test("GET /v1/analytics/brand-value response includes availableCategories, bestValueBrand, mostInvestedBrand fields", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/brand-value");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.availableCategories));
  assert.ok(res.body.bestValueBrand);
  assert.equal(res.body.bestValueBrand.brand, "Uniqlo");
  assert.ok(res.body.mostInvestedBrand);
  assert.equal(res.body.mostInvestedBrand.brand, "Zara");
});

// --- GET /v1/analytics/sustainability tests ---

test("GET /v1/analytics/sustainability returns 200 with sustainability object for premium user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.score, 65);
  assert.ok(res.body.factors);
  assert.equal(typeof res.body.co2SavedKg, "number");
  assert.equal(typeof res.body.co2CarKmEquivalent, "number");
  assert.equal(typeof res.body.percentile, "number");
});

test("GET /v1/analytics/sustainability returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/sustainability returns 403 with PREMIUM_REQUIRED for free user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability");

  await handleRequest(req, res, buildContext({ premiumUser: false }));

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.code, "PREMIUM_REQUIRED");
});

test("GET /v1/analytics/sustainability response includes all expected fields", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.equal(typeof res.body.score, "number");
  assert.ok(res.body.factors);
  assert.equal(typeof res.body.factors.avgWearScore, "number");
  assert.equal(typeof res.body.factors.utilizationScore, "number");
  assert.equal(typeof res.body.factors.cpwScore, "number");
  assert.equal(typeof res.body.factors.resaleScore, "number");
  assert.equal(typeof res.body.factors.newPurchaseScore, "number");
  assert.equal(typeof res.body.co2SavedKg, "number");
  assert.equal(typeof res.body.co2CarKmEquivalent, "number");
  assert.equal(typeof res.body.percentile, "number");
  assert.equal(typeof res.body.badgeAwarded, "boolean");
});

test("GET /v1/analytics/sustainability returns zero score for user with no items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability");

  await handleRequest(req, res, buildContext({
    premiumUser: true,
    sustainabilityResult: {
      score: 10,
      factors: { avgWearScore: 0, utilizationScore: 0, cpwScore: 0, resaleScore: 0, newPurchaseScore: 100 },
      co2SavedKg: 0,
      co2CarKmEquivalent: 0,
      percentile: 90,
      totalRewears: 0,
      totalItems: 0,
      badgeAwarded: false,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.totalItems, 0);
  assert.equal(res.body.co2SavedKg, 0);
});

test("GET /v1/analytics/sustainability badge trigger: badgeAwarded true when score >= 80 and badge newly awarded", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability");

  await handleRequest(req, res, buildContext({
    premiumUser: true,
    sustainabilityResult: {
      score: 85,
      factors: { avgWearScore: 100, utilizationScore: 80, cpwScore: 100, resaleScore: 50, newPurchaseScore: 100 },
      co2SavedKg: 25.0,
      co2CarKmEquivalent: 119.0,
      percentile: 15,
      totalRewears: 50,
      totalItems: 10,
      badgeAwarded: false,
    },
    badgeCheckAndAwardResult: true,
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.badgeAwarded, true);
});

test("GET /v1/analytics/sustainability badge NOT triggered when score < 80", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/sustainability");

  await handleRequest(req, res, buildContext({
    premiumUser: true,
    sustainabilityResult: {
      score: 50,
      factors: { avgWearScore: 50, utilizationScore: 50, cpwScore: 50, resaleScore: 50, newPurchaseScore: 50 },
      co2SavedKg: 5.0,
      co2CarKmEquivalent: 23.8,
      percentile: 50,
      totalRewears: 10,
      totalItems: 5,
      badgeAwarded: false,
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.badgeAwarded, false);
});

// --- GET /v1/analytics/seasonal-reports tests ---

test("GET /v1/analytics/seasonal-reports returns 200 with seasons array for premium user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/seasonal-reports");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.seasons));
  assert.equal(res.body.seasons.length, 4);
});

test("GET /v1/analytics/seasonal-reports returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/seasonal-reports", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/seasonal-reports returns 403 with PREMIUM_REQUIRED for free user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/seasonal-reports");

  await handleRequest(req, res, buildContext({ premiumUser: false }));

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.code, "PREMIUM_REQUIRED");
});

test("GET /v1/analytics/seasonal-reports response includes seasons, currentSeason, transitionAlert, totalItems", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/seasonal-reports");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.seasons);
  assert.ok(typeof res.body.currentSeason === "string");
  assert.ok("transitionAlert" in res.body);
  assert.ok(typeof res.body.totalItems === "number");
});

// --- GET /v1/analytics/heatmap tests ---

test("GET /v1/analytics/heatmap returns 200 for premium user with valid dates", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/heatmap?start=2026-03-01&end=2026-03-31");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(Array.isArray(res.body.dailyActivity));
  assert.ok(res.body.streakStats);
});

test("GET /v1/analytics/heatmap returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/heatmap?start=2026-03-01&end=2026-03-31", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, "Unauthorized");
});

test("GET /v1/analytics/heatmap returns 403 for free user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/heatmap?start=2026-03-01&end=2026-03-31");

  await handleRequest(req, res, buildContext({ premiumUser: false }));

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.code, "PREMIUM_REQUIRED");
});

test("GET /v1/analytics/heatmap returns 400 for missing date params", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/heatmap");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, "BAD_REQUEST");
});

test("GET /v1/analytics/heatmap returns 400 for range exceeding 366 days", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/heatmap?start=2024-01-01&end=2026-03-31");

  await handleRequest(req, res, buildContext({ premiumUser: true }));

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("366"));
});

// --- GET /v1/analytics/wardrobe-health tests ---

test("GET /v1/analytics/wardrobe-health returns 200 with health score object for authenticated user", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-health");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.score, 65);
  assert.equal(res.body.colorTier, "yellow");
});

test("GET /v1/analytics/wardrobe-health returns 401 if unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-health", null, false);

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 401);
});

test("GET /v1/analytics/wardrobe-health response includes all expected fields", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-health");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok("score" in res.body);
  assert.ok("factors" in res.body);
  assert.ok("percentile" in res.body);
  assert.ok("recommendation" in res.body);
  assert.ok("totalItems" in res.body);
  assert.ok("itemsWorn90d" in res.body);
  assert.ok("colorTier" in res.body);
  assert.ok("utilizationScore" in res.body.factors);
  assert.ok("cpwScore" in res.body.factors);
  assert.ok("sizeUtilizationScore" in res.body.factors);
});

test("GET /v1/analytics/wardrobe-health returns zero score for user with no items", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-health");

  await handleRequest(req, res, buildContext({
    wardrobeHealthResult: {
      score: 0,
      factors: { utilizationScore: 0, cpwScore: 0, sizeUtilizationScore: 0 },
      percentile: 100,
      recommendation: "Add items to your wardrobe to start tracking your health score!",
      totalItems: 0,
      itemsWorn90d: 0,
      colorTier: "red",
    },
  }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.score, 0);
  assert.equal(res.body.totalItems, 0);
});

test("GET /v1/analytics/wardrobe-health has no premium gating - free users get 200", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/analytics/wardrobe-health");

  await handleRequest(req, res, buildContext({ premiumUser: false }));

  assert.equal(res.statusCode, 200);
  assert.ok("score" in res.body);
});
