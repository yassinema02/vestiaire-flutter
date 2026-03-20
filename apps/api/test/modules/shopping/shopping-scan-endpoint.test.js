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
    },
  };
}

function createJsonRequest(method, url, body, headers = {}) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json",
    ...headers,
  };
  return stream;
}

function buildContext({
  authenticated = true,
  scanResult = null,
  scanShouldFail = false,
  scanFailError = null,
  quotaAllowed = true,
  quotaUsed = 0,
  isPremium = false,
} = {}) {
  const defaultScanResult = {
    scan: {
      id: "scan-1",
      url: "https://www.zara.com/shirt",
      scanType: "url",
      productName: "Blue Cotton Shirt",
      brand: "Zara",
      price: 29.99,
      currency: "GBP",
      imageUrl: "https://example.com/shirt.jpg",
      category: "tops",
      color: "blue",
      extractionMethod: "og_tags+json_ld",
      createdAt: "2026-03-19T00:00:00.000Z"
    },
    status: "completed"
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
          provider: "google.com",
        };
      },
    },
    profileService: {},
    itemService: {
      async createItemForUser() { return { item: { id: "item-1" } }; },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(_, id) { return { item: { id } }; },
      async updateItemForUser() { return { item: {} }; },
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {},
    outfitRepository: { async listOutfits() { return []; } },
    usageLimitService: {},
    wearLogRepository: {},
    analyticsRepository: {},
    analyticsSummaryService: {},
    userStatsRepo: {
      async getUserStats() {
        return { totalPoints: 0, currentStreak: 0, longestStreak: 0, currentLevel: 1, currentLevelName: "Closet Rookie", nextLevelThreshold: 10, itemCount: 0 };
      },
    },
    stylePointsService: {
      async awardItemUploadPoints() { return { pointsAwarded: 10 }; },
      async awardWearLogPoints() { return { pointsAwarded: 5 }; },
    },
    levelService: {
      async recalculateLevel() { return { currentLevel: 1, currentLevelName: "Closet Rookie", previousLevel: 1, previousLevelName: "Closet Rookie", leveledUp: false }; },
    },
    streakService: {
      async evaluateStreak() { return { currentStreak: 1, longestStreak: 1, lastStreakDate: "2026-03-19", streakExtended: false, isNewStreak: true, streakFreezeAvailable: true }; },
    },
    badgeRepo: {},
    badgeService: {
      async getBadgeCatalog() { return []; },
      async getUserBadgeCollection() { return { badges: [], badgeCount: 0 }; },
      async evaluateAndAward() { return { badgesAwarded: [] }; },
      async checkAndAward() { return { awarded: false }; },
    },
    challengeRepo: {},
    challengeService: {
      async acceptChallenge() { return { challenge: { key: "closet_safari" } }; },
      async updateProgressOnItemCreate() { return { challengeUpdate: null }; },
      async getChallengeStatus() { return null; },
      async checkTrialExpiry() { return { isPremium: false, trialExpired: false }; },
    },
    subscriptionSyncService: {
      async syncFromClient() { return { isPremium: false }; },
      async handleWebhookEvent() { return { handled: true }; },
    },
    premiumGuard: {
      async checkPremium() { return { isPremium, profileId: "profile-1", premiumSource: null }; },
      async requirePremium(authContext) {
        if (!isPremium) throw { statusCode: 403, code: "PREMIUM_REQUIRED", message: "Premium required" };
        return { isPremium: true, profileId: "profile-1" };
      },
      async checkUsageQuota(authContext, opts) {
        const remaining = Math.max(0, 3 - quotaUsed);
        return {
          allowed: quotaAllowed,
          isPremium,
          limit: 3,
          used: quotaUsed,
          remaining,
          resetsAt: "2026-03-20T00:00:00.000Z",
        };
      },
    },
    resaleListingService: {
      async generateListing() { return { listing: {}, item: {}, generatedAt: "2026-03-19T00:00:00.000Z" }; },
    },
    resaleHistoryRepo: {
      async listHistory() { return []; },
      async getEarningsSummary() { return { itemsSold: 0, itemsDonated: 0, totalEarnings: 0 }; },
      async getMonthlyEarnings() { return []; },
    },
    shoppingScanService: {
      async scanUrl(authContext, params) {
        if (scanShouldFail) {
          throw scanFailError || { statusCode: 422, code: "EXTRACTION_FAILED", message: "Unable to extract product information from this URL." };
        }
        return scanResult || defaultScanResult;
      },
    },
    shoppingScanRepo: {},
  };
}

test("POST /v1/shopping/scan-url returns 200 with scan data on success", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-url", { url: "https://www.zara.com/shirt" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
  assert.equal(res.body.scan.productName, "Blue Cotton Shirt");
  assert.equal(res.body.status, "completed");
});

test("POST /v1/shopping/scan-url returns 422 on extraction failure", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-url", { url: "https://www.empty.com/page" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({ scanShouldFail: true }));

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "EXTRACTION_FAILED");
});

test("POST /v1/shopping/scan-url returns 429 when free daily limit reached", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-url", { url: "https://www.zara.com/shirt" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({ quotaAllowed: false, quotaUsed: 3 }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.code, "RATE_LIMIT_EXCEEDED");
  assert.equal(res.body.dailyLimit, 3);
  assert.equal(res.body.used, 3);
  assert.equal(res.body.remaining, 0);
});

test("POST /v1/shopping/scan-url returns 401 without authentication", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-url", { url: "https://www.zara.com/shirt" });

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/shopping/scan-url returns 400 when URL is missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-url", {}, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("url"));
});

test("Premium user bypasses daily limit on POST /v1/shopping/scan-url", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-url", { url: "https://www.zara.com/shirt" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({ isPremium: true, quotaUsed: 100, quotaAllowed: true }));

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
});

// === Story 8.2: POST /v1/shopping/scan-screenshot ===

test("POST /v1/shopping/scan-screenshot returns 200 with scan data on success", async () => {
  const screenshotScanResult = {
    scan: {
      id: "scan-2",
      url: null,
      scanType: "screenshot",
      productName: "Red Dress",
      brand: "H&M",
      price: 49.99,
      currency: "EUR",
      imageUrl: "https://storage.example.com/screenshot.jpg",
      category: "dresses",
      color: "red",
      extractionMethod: "screenshot_vision",
      createdAt: "2026-03-19T00:00:00.000Z"
    },
    status: "completed"
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", { imageUrl: "https://storage.example.com/screenshot.jpg" }, {
    authorization: "Bearer signed.jwt.token",
  });

  const context = buildContext({ scanResult: screenshotScanResult });
  context.shoppingScanService.scanScreenshot = async (authContext, params) => {
    return screenshotScanResult;
  };

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
  assert.equal(res.body.scan.scanType, "screenshot");
  assert.equal(res.body.scan.productName, "Red Dress");
  assert.equal(res.body.status, "completed");
});

test("POST /v1/shopping/scan-screenshot returns 422 on extraction failure", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", { imageUrl: "https://storage.example.com/blank.jpg" }, {
    authorization: "Bearer signed.jwt.token",
  });

  const context = buildContext();
  context.shoppingScanService.scanScreenshot = async () => {
    throw { statusCode: 422, code: "EXTRACTION_FAILED", message: "Unable to identify clothing in this image." };
  };

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "EXTRACTION_FAILED");
});

test("POST /v1/shopping/scan-screenshot returns 429 when free daily limit reached", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", { imageUrl: "https://storage.example.com/screenshot.jpg" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({ quotaAllowed: false, quotaUsed: 3 }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.code, "RATE_LIMIT_EXCEEDED");
  assert.equal(res.body.dailyLimit, 3);
  assert.equal(res.body.used, 3);
  assert.equal(res.body.remaining, 0);
});

test("POST /v1/shopping/scan-screenshot returns 401 without authentication", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", { imageUrl: "https://storage.example.com/screenshot.jpg" });

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/shopping/scan-screenshot returns 400 when imageUrl is missing", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", {}, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  assert.ok(res.body.message.includes("imageUrl"));
});

test("Premium user bypasses daily limit for screenshot scans", async () => {
  const screenshotScanResult = {
    scan: {
      id: "scan-3",
      url: null,
      scanType: "screenshot",
      productName: "Premium Scan",
      extractionMethod: "screenshot_vision",
      createdAt: "2026-03-19T00:00:00.000Z"
    },
    status: "completed"
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", { imageUrl: "https://storage.example.com/screenshot.jpg" }, {
    authorization: "Bearer signed.jwt.token",
  });

  const context = buildContext({ isPremium: true, quotaUsed: 100, quotaAllowed: true });
  context.shoppingScanService.scanScreenshot = async () => screenshotScanResult;

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
});

// === Story 8.3: PATCH /v1/shopping/scans/:id ===

test("PATCH /v1/shopping/scans/:id returns 200 with updated scan data", async () => {
  const updatedScan = {
    id: "scan-1",
    productName: "Updated Shirt",
    brand: "Updated Brand",
    category: "tops",
    color: "red",
    price: 39.99,
    currency: "EUR",
    createdAt: "2026-03-19T00:00:00.000Z"
  };

  const context = buildContext();
  context.shoppingScanRepo.updateScan = async (authContext, scanId, data) => {
    return updatedScan;
  };

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/scan-1", {
    category: "tops",
    color: "red",
    price: 39.99,
    currency: "EUR",
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
  assert.equal(res.body.scan.productName, "Updated Shirt");
  assert.equal(res.body.scan.category, "tops");
});

test("PATCH /v1/shopping/scans/:id returns 400 on validation failure with field errors", async () => {
  const context = buildContext();

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/scan-1", {
    category: "invalid-category",
    formalityScore: 15,
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, "VALIDATION_ERROR");
  assert.ok(Array.isArray(res.body.errors));
  assert.ok(res.body.errors.some(e => e.field === "category"));
  assert.ok(res.body.errors.some(e => e.field === "formalityScore"));
});

test("PATCH /v1/shopping/scans/:id returns 404 for non-existent scan", async () => {
  const context = buildContext();
  context.shoppingScanRepo.updateScan = async () => null;

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/non-existent-id", {
    category: "tops",
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.code, "NOT_FOUND");
});

test("PATCH /v1/shopping/scans/:id returns 404 for another user's scan (RLS)", async () => {
  const context = buildContext();
  context.shoppingScanRepo.updateScan = async () => null; // RLS filters it out

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/other-users-scan", {
    color: "red",
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 404);
});

test("PATCH /v1/shopping/scans/:id returns 401 without authentication", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/scan-1", { category: "tops" });

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("PATCH /v1/shopping/scans/:id partial update only modifies specified fields", async () => {
  let capturedData;
  const context = buildContext();
  context.shoppingScanRepo.updateScan = async (authContext, scanId, data) => {
    capturedData = data;
    return {
      id: scanId,
      productName: "Original",
      brand: "Original Brand",
      category: data.category || "tops",
      color: "blue",
      createdAt: "2026-03-19T00:00:00.000Z"
    };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/scan-1", {
    category: "shoes",
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.equal(capturedData.category, "shoes");
  assert.equal(capturedData.color, undefined);
  assert.equal(capturedData.brand, undefined);
});

// === Story 8.4: POST /v1/shopping/scans/:id/score ===

test("POST /v1/shopping/scans/:id/score returns 200 with score data on success", async () => {
  const scoreResult = {
    scan: {
      id: "scan-1",
      productName: "Blue Shirt",
      brand: "Zara",
      compatibilityScore: 75,
      createdAt: "2026-03-19T00:00:00.000Z"
    },
    score: {
      total: 75,
      breakdown: {
        colorHarmony: 80,
        styleConsistency: 70,
        gapFilling: 75,
        versatility: 65,
        formalityMatch: 80
      },
      tier: "great_choice",
      tierLabel: "Great Choice",
      tierColor: "#3B82F6",
      tierIcon: "thumb_up",
      reasoning: "Good match."
    },
    status: "scored"
  };

  const context = buildContext();
  context.shoppingScanService.scoreCompatibility = async (authContext, { scanId }) => {
    return scoreResult;
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/score", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
  assert.ok(res.body.score);
  assert.equal(res.body.status, "scored");
  assert.equal(res.body.score.total, 75);
  assert.equal(res.body.score.tier, "great_choice");
});

test("POST /v1/shopping/scans/:id/score returns 404 for non-existent scan", async () => {
  const context = buildContext();
  context.shoppingScanService.scoreCompatibility = async () => {
    throw { statusCode: 404, code: "NOT_FOUND", message: "Scan not found" };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/non-existent/score", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.code, "NOT_FOUND");
});

test("POST /v1/shopping/scans/:id/score returns 404 for another user's scan (RLS)", async () => {
  const context = buildContext();
  context.shoppingScanService.scoreCompatibility = async () => {
    throw { statusCode: 404, code: "NOT_FOUND", message: "Scan not found" };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/other-users-scan/score", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 404);
});

test("POST /v1/shopping/scans/:id/score returns 422 when wardrobe is empty", async () => {
  const context = buildContext();
  context.shoppingScanService.scoreCompatibility = async () => {
    throw { statusCode: 422, code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first to get compatibility scores." };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/score", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "WARDROBE_EMPTY");
});

test("POST /v1/shopping/scans/:id/score returns 502 when Gemini fails", async () => {
  const context = buildContext();
  context.shoppingScanService.scoreCompatibility = async () => {
    throw { statusCode: 502, code: "SCORING_FAILED", message: "Unable to calculate compatibility score. Please try again." };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/score", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 502);
  assert.equal(res.body.code, "SCORING_FAILED");
});

test("POST /v1/shopping/scans/:id/score returns 401 without authentication", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/score", null);

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("POST /v1/shopping/scans/:id/score does NOT consume usage quota", async () => {
  let quotaChecked = false;
  const scoreResult = {
    scan: { id: "scan-1", createdAt: "2026-03-19T00:00:00.000Z" },
    score: { total: 75, breakdown: { colorHarmony: 80, styleConsistency: 70, gapFilling: 75, versatility: 65, formalityMatch: 80 }, tier: "great_choice", tierLabel: "Great Choice", tierColor: "#3B82F6", tierIcon: "thumb_up" },
    status: "scored"
  };

  const context = buildContext();
  context.shoppingScanService.scoreCompatibility = async () => scoreResult;
  const originalCheckUsageQuota = context.premiumGuard.checkUsageQuota;
  context.premiumGuard.checkUsageQuota = async (authContext, opts) => {
    quotaChecked = true;
    return originalCheckUsageQuota(authContext, opts);
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/score", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  // The scoring endpoint should NOT call premiumGuard.checkUsageQuota
  assert.equal(quotaChecked, false, "Scoring endpoint should not check usage quota");
});

// === Story 8.5: POST /v1/shopping/scans/:id/insights ===

test("POST /v1/shopping/scans/:id/insights returns 200 with matches and insights on success", async () => {
  const insightResult = {
    scan: {
      id: "scan-1",
      productName: "Blue Shirt",
      compatibilityScore: 75,
      createdAt: "2026-03-19T00:00:00.000Z"
    },
    matches: [
      { itemId: "item-1", itemName: "Navy Blazer", itemImageUrl: "https://example.com/blazer.jpg", category: "outerwear", matchReasons: ["Complementary colors"] }
    ],
    insights: [
      { type: "style_feedback", title: "Style Match", body: "Fits your casual style." },
      { type: "gap_assessment", title: "Fills Gap", body: "New color for your wardrobe." },
      { type: "value_proposition", title: "Good Value", body: "Versatile piece." }
    ],
    status: "analyzed"
  };

  const context = buildContext();
  context.shoppingScanService.generateInsights = async (authContext, { scanId }) => {
    return insightResult;
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.scan);
  assert.ok(Array.isArray(res.body.matches));
  assert.ok(Array.isArray(res.body.insights));
  assert.equal(res.body.status, "analyzed");
  assert.equal(res.body.matches.length, 1);
  assert.equal(res.body.insights.length, 3);
});

test("POST /v1/shopping/scans/:id/insights returns 200 with cached data when insights already exist", async () => {
  const cachedResult = {
    scan: { id: "scan-1", insights: { matches: [], insights: [] }, createdAt: "2026-03-19T00:00:00.000Z" },
    matches: [],
    insights: [
      { type: "style_feedback", title: "Cached", body: "From cache" },
      { type: "gap_assessment", title: "Cached", body: "From cache" },
      { type: "value_proposition", title: "Cached", body: "From cache" }
    ],
    status: "analyzed"
  };

  const context = buildContext();
  context.shoppingScanService.generateInsights = async () => cachedResult;

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.status, "analyzed");
});

test("POST /v1/shopping/scans/:id/insights returns 404 for non-existent scan", async () => {
  const context = buildContext();
  context.shoppingScanService.generateInsights = async () => {
    throw { statusCode: 404, code: "NOT_FOUND", message: "Scan not found" };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/non-existent/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.code, "NOT_FOUND");
});

test("POST /v1/shopping/scans/:id/insights returns 404 for another user's scan (RLS)", async () => {
  const context = buildContext();
  context.shoppingScanService.generateInsights = async () => {
    throw { statusCode: 404, code: "NOT_FOUND", message: "Scan not found" };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/other-users-scan/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 404);
});

test("POST /v1/shopping/scans/:id/insights returns 422 when wardrobe is empty", async () => {
  const context = buildContext();
  context.shoppingScanService.generateInsights = async () => {
    throw { statusCode: 422, code: "WARDROBE_EMPTY", message: "Add items to your wardrobe first to see matches and insights." };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "WARDROBE_EMPTY");
});

test("POST /v1/shopping/scans/:id/insights returns 422 when scan is not scored", async () => {
  const context = buildContext();
  context.shoppingScanService.generateInsights = async () => {
    throw { statusCode: 422, code: "NOT_SCORED", message: "Score the product first before viewing matches and insights." };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "NOT_SCORED");
});

test("POST /v1/shopping/scans/:id/insights returns 502 when Gemini fails", async () => {
  const context = buildContext();
  context.shoppingScanService.generateInsights = async () => {
    throw { statusCode: 502, code: "INSIGHT_FAILED", message: "Unable to generate insights. Please try again." };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/insights", null, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 502);
  assert.equal(res.body.code, "INSIGHT_FAILED");
});

test("POST /v1/shopping/scans/:id/insights returns 401 without authentication", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scans/scan-1/insights", null);

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

test("PATCH /v1/shopping/scans/:id with wishlisted: true updates the wishlisted column", async () => {
  let capturedData;
  const context = buildContext();
  context.shoppingScanRepo.updateScan = async (authContext, scanId, data) => {
    capturedData = data;
    return {
      id: scanId,
      productName: "Blue Shirt",
      wishlisted: true,
      createdAt: "2026-03-19T00:00:00.000Z"
    };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/scan-1", {
    wishlisted: true,
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.equal(capturedData.wishlisted, true);
  assert.equal(res.body.scan.wishlisted, true);
});

test("PATCH /v1/shopping/scans/:id with wishlisted: false un-wishlists", async () => {
  let capturedData;
  const context = buildContext();
  context.shoppingScanRepo.updateScan = async (authContext, scanId, data) => {
    capturedData = data;
    return {
      id: scanId,
      productName: "Blue Shirt",
      wishlisted: false,
      createdAt: "2026-03-19T00:00:00.000Z"
    };
  };

  const res = createResponseCapture();
  const req = createJsonRequest("PATCH", "/v1/shopping/scans/scan-1", {
    wishlisted: false,
  }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 200);
  assert.equal(capturedData.wishlisted, false);
  assert.equal(res.body.scan.wishlisted, false);
});

test("URL scan + screenshot scan share the same daily quota (429 after combined limit)", async () => {
  // Simulate 3 scans already used (2 URL + 1 screenshot = limit reached)
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/shopping/scan-screenshot", { imageUrl: "https://storage.example.com/screenshot.jpg" }, {
    authorization: "Bearer signed.jwt.token",
  });

  await handleRequest(req, res, buildContext({ quotaAllowed: false, quotaUsed: 3 }));

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.code, "RATE_LIMIT_EXCEEDED");
});
