import http from "node:http";
import { fileURLToPath } from "node:url";
import { getConfig } from "./config/env.js";
import { createPool } from "./db/pool.js";
import { sendJson } from "./http/json.js";
import { requireAuth } from "./middleware/authenticate.js";
import { notFound } from "./middleware/notFound.js";
import { createFirebaseTokenVerifier } from "./modules/auth/firebaseTokenVerifier.js";
import {
  AuthenticationError,
  AuthorizationError,
  createAuthService
} from "./modules/auth/service.js";
import { createItemRepository } from "./modules/items/repository.js";
import { createItemService } from "./modules/items/service.js";
import { createProfileRepository } from "./modules/profiles/repository.js";
import { createProfileService } from "./modules/profiles/service.js";
import { createFirebaseAdminService } from "./modules/auth/firebaseAdmin.js";
import { createUploadService } from "./modules/uploads/service.js";
import { createGeminiClientSync } from "./modules/ai/gemini-client.js";
import { createBackgroundRemovalService } from "./modules/ai/background-removal-service.js";
import { createCategorizationService } from "./modules/ai/categorization-service.js";
import { createAiUsageLogRepository } from "./modules/ai/ai-usage-log-repository.js";
import { createCalendarEventRepository } from "./modules/calendar/calendar-event-repository.js";
import { createCalendarOutfitRepository } from "./modules/calendar/calendar-outfit-repository.js";
import { createEventClassificationService } from "./modules/calendar/event-classification-service.js";
import { createCalendarService } from "./modules/calendar/calendar-service.js";
import { createOutfitGenerationService } from "./modules/outfits/outfit-generation-service.js";
import { createOutfitRepository } from "./modules/outfits/outfit-repository.js";
import { createUsageLimitService } from "./modules/outfits/usage-limit-service.js";
import { createWearLogRepository } from "./modules/wear-logs/wear-log-repository.js";
import { createAnalyticsRepository } from "./modules/analytics/analytics-repository.js";
import { createAnalyticsSummaryService } from "./modules/analytics/analytics-summary-service.js";
import { createUserStatsRepository } from "./modules/gamification/user-stats-repository.js";
import { createStylePointsService } from "./modules/gamification/style-points-service.js";
import { createLevelService } from "./modules/gamification/level-service.js";
import { createStreakService } from "./modules/gamification/streak-service.js";
import { createBadgeRepository } from "./modules/badges/badge-repository.js";
import { createBadgeService } from "./modules/badges/badge-service.js";
import { createChallengeRepository } from "./modules/gamification/challenge-repository.js";
import { createChallengeService } from "./modules/gamification/challenge-service.js";
import { createSubscriptionSyncService } from "./modules/billing/subscription-sync-service.js";
import { createPremiumGuard, FREE_LIMITS } from "./modules/billing/premium-guard.js";
import { createResaleListingService } from "./modules/resale/resale-listing-service.js";
import { createResaleHistoryRepository } from "./modules/resale/resale-history-repository.js";
import { createResalePromptService, computeEstimatedPrice } from "./modules/resale/resale-prompt-service.js";
import { createDonationRepository } from "./modules/resale/donation-repository.js";
import { createUrlScraperService } from "./modules/shopping/url-scraper-service.js";
import { createShoppingScanService, validateScanUpdate } from "./modules/shopping/shopping-scan-service.js";
import { createShoppingScanRepository } from "./modules/shopping/shopping-scan-repository.js";
import { createSquadRepository } from "./modules/squads/squad-repository.js";
import { createSquadService } from "./modules/squads/squad-service.js";
import { createOotdRepository } from "./modules/squads/ootd-repository.js";
import { createOotdService } from "./modules/squads/ootd-service.js";
import { createNotificationService } from "./modules/notifications/notification-service.js";
import { createExtractionRepository } from "./modules/extraction/repository.js";
import { createExtractionService, ExtractionValidationError } from "./modules/extraction/service.js";
import { createExtractionProcessingService } from "./modules/extraction/processing-service.js";
import { createTripDetectionService } from "./modules/calendar/trip-detection-service.js";

function resolveContext(contextOrConfig = getConfig()) {
  if ("config" in contextOrConfig || "authService" in contextOrConfig) {
    return {
      config: getConfig(),
      ...contextOrConfig
    };
  }

  return { config: contextOrConfig };
}

export function createRuntime(config = getConfig()) {
  const pool = createPool(config);
  const authService = createAuthService({
    verifyToken: createFirebaseTokenVerifier({
      projectId: config.firebaseProjectId
    })
  });
  const itemRepo = createItemRepository({ pool });
  const uploadService = createUploadService({
    gcsBucket: config.gcsBucket || undefined,
    publicBaseUrl: `http://${config.host}:${config.port}`
  });
  const firebaseAdminService = createFirebaseAdminService({
    serviceAccountPath: config.firebaseServiceAccountPath
  });
  const profileService = createProfileService({
    repo: createProfileRepository({ pool }),
    uploadService,
    firebaseAdminService
  });

  // AI services
  const geminiClient = createGeminiClientSync({
    gcpProjectId: config.gcpProjectId,
    vertexAiLocation: config.vertexAiLocation
  });
  const aiUsageLogRepo = createAiUsageLogRepository({ pool });
  const backgroundRemovalService = createBackgroundRemovalService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
    uploadService
  });

  const categorizationService = createCategorizationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo
  });

  const itemService = createItemService({
    repo: itemRepo,
    backgroundRemovalService: {
      ...backgroundRemovalService,
      geminiClient
    },
    categorizationService
  });

  // Calendar services
  const calendarEventRepo = createCalendarEventRepository({ pool });
  const calendarOutfitRepo = createCalendarOutfitRepository({ pool });
  const classificationService = createEventClassificationService({
    geminiClient,
    aiUsageLogRepo
  });
  const calendarService = createCalendarService({
    calendarEventRepo,
    classificationService
  });

  // Trip detection service
  const tripDetectionService = createTripDetectionService({
    calendarEventRepo,
    pool,
  });

  // Outfit services
  const outfitRepository = createOutfitRepository({ pool });
  const outfitGenerationService = createOutfitGenerationService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
    outfitRepo: outfitRepository,
  });

  // Wear log services
  const wearLogRepository = createWearLogRepository({ pool });

  // Analytics services
  const analyticsRepository = createAnalyticsRepository({ pool });

  // Gamification services
  const userStatsRepo = createUserStatsRepository({ pool });
  const stylePointsService = createStylePointsService({ userStatsRepo });
  const levelService = createLevelService({ pool });
  const streakService = createStreakService({ pool });

  // Badge services
  const badgeRepo = createBadgeRepository({ pool });
  const badgeService = createBadgeService({ badgeRepo });

  // Challenge services
  const challengeRepo = createChallengeRepository({ pool });
  const challengeService = createChallengeService({ challengeRepo, pool });

  // Billing services
  const subscriptionSyncService = createSubscriptionSyncService({ pool, config });

  // Premium guard (centralized premium check utility)
  const premiumGuard = createPremiumGuard({ pool, subscriptionSyncService, challengeService });

  // Resale history repository
  const resaleHistoryRepo = createResaleHistoryRepository({ pool });

  // Resale listing service
  const resaleListingService = createResaleListingService({
    geminiClient,
    itemRepo,
    aiUsageLogRepo,
    pool
  });

  // Shopping services
  const urlScraperService = createUrlScraperService();
  const shoppingScanRepo = createShoppingScanRepository({ pool });
  const shoppingScanService = createShoppingScanService({
    urlScraperService,
    geminiClient,
    aiUsageLogRepo,
    shoppingScanRepo,
    itemRepo,
    pool
  });

  // Squad services
  const squadRepo = createSquadRepository({ pool });
  const squadService = createSquadService({ squadRepo });

  // Notification service
  const notificationService = createNotificationService({ pool });

  // Resale prompt service
  const resalePromptService = createResalePromptService({ pool, notificationService });

  // Donation repository
  const donationRepository = createDonationRepository({ pool });

  // Extraction services
  const extractionRepo = createExtractionRepository({ pool });
  const extractionService = createExtractionService({ extractionRepo, itemRepo, itemService });
  const extractionProcessingService = createExtractionProcessingService({
    extractionRepo,
    geminiClient,
    backgroundRemovalService,
    aiUsageLogRepo,
    uploadService
  });

  // OOTD post services
  const ootdRepo = createOotdRepository({ pool });
  const ootdService = createOotdService({ ootdRepo, squadRepo, pool, itemRepo, geminiClient, aiUsageLogRepo, notificationService });

  // Services that depend on premiumGuard
  const usageLimitService = createUsageLimitService({ pool, premiumGuard });
  const analyticsSummaryService = createAnalyticsSummaryService({
    geminiClient,
    analyticsRepository,
    aiUsageLogRepo,
    pool,
    premiumGuard,
  });

  return {
    config,
    pool,
    authService,
    profileService,
    itemService,
    uploadService,
    backgroundRemovalService,
    categorizationService,
    calendarEventRepo,
    calendarOutfitRepo,
    classificationService,
    calendarService,
    outfitGenerationService,
    outfitRepository,
    usageLimitService,
    wearLogRepository,
    analyticsRepository,
    analyticsSummaryService,
    userStatsRepo,
    stylePointsService,
    levelService,
    streakService,
    badgeRepo,
    badgeService,
    challengeRepo,
    challengeService,
    subscriptionSyncService,
    premiumGuard,
    resaleListingService,
    resaleHistoryRepo,
    urlScraperService,
    shoppingScanService,
    shoppingScanRepo,
    squadRepo,
    squadService,
    ootdRepo,
    ootdService,
    extractionRepo,
    extractionService,
    extractionProcessingService,
    tripDetectionService,
    itemRepo,
    resalePromptService,
    donationRepository
  };
}

function mapError(error) {
  if (error instanceof AuthenticationError || error?.statusCode === 401) {
    return {
      statusCode: 401,
      body: {
        error: "Unauthorized",
        code: error.code ?? "UNAUTHORIZED",
        message: error.message
      }
    };
  }

  if (error instanceof AuthorizationError || error?.statusCode === 403) {
    return {
      statusCode: 403,
      body: {
        error: "Forbidden",
        code: error.code ?? "FORBIDDEN",
        message: error.message
      }
    };
  }

  if (error?.statusCode === 400) {
    return {
      statusCode: 400,
      body: {
        error: "Bad Request",
        code: error.code ?? "BAD_REQUEST",
        message: error.message
      }
    };
  }

  if (error?.statusCode === 503) {
    return {
      statusCode: 503,
      body: {
        error: "Service Unavailable",
        code: error.code ?? "SERVICE_UNAVAILABLE",
        message: error.message
      }
    };
  }

  if (error?.statusCode === 429) {
    return {
      statusCode: 429,
      body: {
        error: "Rate Limit Exceeded",
        code: error.code ?? "RATE_LIMIT_EXCEEDED",
        message: error.message,
        dailyLimit: error.dailyLimit,
        used: error.used,
        remaining: error.remaining,
        resetsAt: error.resetsAt
      }
    };
  }

  if (error?.statusCode === 422) {
    return {
      statusCode: 422,
      body: {
        error: "Unprocessable Entity",
        code: error.code ?? "UNPROCESSABLE_ENTITY",
        message: error.message
      }
    };
  }

  if (error?.statusCode === 409) {
    return {
      statusCode: 409,
      body: {
        error: "Conflict",
        code: error.code ?? "CONFLICT",
        message: error.message
      }
    };
  }

  if (error?.statusCode === 404) {
    return {
      statusCode: 404,
      body: {
        error: "Not Found",
        code: error.code ?? "NOT_FOUND",
        message: error.message
      }
    };
  }

  if (error?.statusCode === 502) {
    return {
      statusCode: 502,
      body: {
        error: error.error || "Bad Gateway",
        code: error.code ?? "BAD_GATEWAY",
        message: error.message
      }
    };
  }

  return {
    statusCode: 500,
    body: {
      error: "Internal Server Error",
      code: "INTERNAL_SERVER_ERROR",
      message: "Unexpected server error"
    }
  };
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf-8");
  if (!raw) return {};
  return JSON.parse(raw);
}

export async function handleRequest(req, res, contextOrConfig = getConfig()) {
  const { config, pool, authService, profileService, itemService, uploadService, backgroundRemovalService, categorizationService, calendarEventRepo, calendarOutfitRepo, calendarService, outfitGenerationService, outfitRepository, usageLimitService, wearLogRepository, analyticsRepository, analyticsSummaryService, userStatsRepo, stylePointsService, levelService, streakService, badgeRepo, badgeService, challengeRepo, challengeService, subscriptionSyncService, premiumGuard, resaleListingService, resaleHistoryRepo, shoppingScanService, shoppingScanRepo, squadService, ootdService, extractionService, extractionRepo, extractionProcessingService, tripDetectionService, itemRepo, resalePromptService, donationRepository } =
    resolveContext(contextOrConfig);
  const url = new URL(req.url, "http://localhost");

  // --- Webhook routes (bypass Firebase auth, handle own authentication) ---
  if (req.method === "POST" && url.pathname === "/v1/webhooks/revenuecat") {
    try {
      const authorizationHeader = req.headers.authorization || "";
      const body = await readBody(req);
      const result = await subscriptionSyncService.handleWebhookEvent(body, authorizationHeader);
      sendJson(res, 200, { success: true, ...result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "GET" && url.pathname === "/healthz") {
    sendJson(res, 200, {
      service: config.appName,
      status: "ok",
      environment: config.nodeEnv
    });
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/profiles/me") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await profileService.getProfileForAuthenticatedUser(authContext);

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "PUT" && url.pathname === "/v1/profiles/me") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await profileService.updateProfileForAuthenticatedUser(
        authContext,
        body
      );

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "DELETE" && url.pathname === "/v1/profiles/me") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await profileService.deleteAccountForAuthenticatedUser(authContext);

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "DELETE" && url.pathname === "/v1/profiles/me/push-token") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await profileService.updateProfileForAuthenticatedUser(
        authContext,
        { push_token: null }
      );

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "POST" && url.pathname === "/v1/uploads/signed-url") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await uploadService.generateSignedUploadUrl(authContext, {
        purpose: body.purpose,
        contentType: body.contentType
      });

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "POST" && url.pathname === "/v1/items") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await itemService.createItemForUser(authContext, {
        photoUrl: body.photoUrl,
        name: body.name
      });

      // Award style points (best-effort, non-blocking)
      let pointsAwarded = null;
      try {
        if (stylePointsService) {
          pointsAwarded = await stylePointsService.awardItemUploadPoints(authContext);
        }
      } catch (pointsError) {
        console.error("[style-points] Failed to award item upload points:", pointsError.message ?? pointsError);
      }

      // Recalculate level (best-effort, non-blocking)
      let levelUp = null;
      try {
        if (levelService) {
          const levelResult = await levelService.recalculateLevel(authContext);
          if (levelResult.leveledUp) {
            levelUp = {
              newLevel: levelResult.currentLevel,
              newLevelName: levelResult.currentLevelName,
              previousLevel: levelResult.previousLevel,
              previousLevelName: levelResult.previousLevelName,
            };
          }
        }
      } catch (levelError) {
        console.error("[level] Failed to recalculate level:", levelError.message ?? levelError);
      }

      // Evaluate badges (best-effort, non-blocking)
      let badgesAwarded = null;
      try {
        if (badgeService) {
          const badgeResult = await badgeService.evaluateAndAward(authContext);
          badgesAwarded = badgeResult.badgesAwarded;
        }
      } catch (badgeError) {
        console.error("[badges] Failed to evaluate badges:", badgeError.message ?? badgeError);
      }

      // Update challenge progress (best-effort, non-blocking)
      let challengeUpdate = null;
      try {
        if (challengeService) {
          const challengeResult = await challengeService.updateProgressOnItemCreate(authContext);
          challengeUpdate = challengeResult.challengeUpdate;
        }
      } catch (challengeError) {
        console.error("[challenge] Failed to update challenge progress:", challengeError.message ?? challengeError);
      }

      sendJson(res, 201, { ...result, pointsAwarded, levelUp, badgesAwarded, challengeUpdate });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  if (req.method === "GET" && url.pathname === "/v1/items") {
    try {
      const authContext = await requireAuth(req, authService);
      const limit = url.searchParams.get("limit");
      const category = url.searchParams.get("category");
      const color = url.searchParams.get("color");
      const season = url.searchParams.get("season");
      const occasion = url.searchParams.get("occasion");
      const brand = url.searchParams.get("brand");
      const neglectStatus = url.searchParams.get("neglect_status");
      const result = await itemService.listItemsForUser(authContext, {
        limit: limit ?? undefined,
        category: category ?? undefined,
        color: color ?? undefined,
        season: season ?? undefined,
        occasion: occasion ?? undefined,
        brand: brand ?? undefined,
        neglectStatus: neglectStatus ?? undefined
      });

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PATCH /v1/items/:id - Update item metadata
  const itemIdMatch = url.pathname.match(/^\/v1\/items\/([^/]+)$/);
  if (req.method === "PATCH" && itemIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = itemIdMatch[1];
      const body = await readBody(req);
      const result = await itemService.updateItemForUser(authContext, itemId, body);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // DELETE /v1/items/:id - Delete item
  if (req.method === "DELETE" && itemIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = itemIdMatch[1];
      const result = await itemService.deleteItemForUser(authContext, itemId);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/items/:id - Get single item
  if (req.method === "GET" && itemIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = itemIdMatch[1];
      const result = await itemService.getItemForUser(authContext, itemId);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/items/:id/remove-background
  const bgRemovalMatch = url.pathname.match(/^\/v1\/items\/([^/]+)\/remove-background$/);
  if (req.method === "POST" && bgRemovalMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = bgRemovalMatch[1];

      // Look up the item (ensuring ownership via auth context)
      const { item } = await itemService.getItemForUser(authContext, itemId);

      // Trigger background removal asynchronously (fire-and-forget)
      if (backgroundRemovalService) {
        backgroundRemovalService
          .removeBackground(authContext, {
            itemId: item.id,
            imageUrl: item.originalPhotoUrl || item.photoUrl
          })
          .catch((err) => {
            console.error("[bg-removal] Retry failed:", err.message ?? err);
          });
      }

      sendJson(res, 202, { status: "processing" });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/items/:id/categorize
  const categorizeMatch = url.pathname.match(/^\/v1\/items\/([^/]+)\/categorize$/);
  if (req.method === "POST" && categorizeMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = categorizeMatch[1];

      // Look up the item (ensuring ownership via auth context)
      const { item } = await itemService.getItemForUser(authContext, itemId);

      // Trigger categorization asynchronously (fire-and-forget)
      if (categorizationService) {
        categorizationService
          .categorizeItem(authContext, {
            itemId: item.id,
            imageUrl: item.photoUrl
          })
          .catch((err) => {
            console.error("[categorization] Retry failed:", err.message ?? err);
          });
      }

      sendJson(res, 202, { status: "processing" });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/calendar/events/sync - Sync calendar events
  if (req.method === "POST" && url.pathname === "/v1/calendar/events/sync") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await calendarService.syncEvents(authContext, {
        events: body.events ?? []
      });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PATCH /v1/calendar/events/:id - Update event classification override
  const eventOverrideMatch = url.pathname.match(/^\/v1\/calendar\/events\/([^/]+)$/);
  if (req.method === "PATCH" && eventOverrideMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const eventId = eventOverrideMatch[1];
      const body = await readBody(req);
      const result = await calendarEventRepo.updateEventOverride(authContext, eventId, {
        eventType: body.eventType,
        formalityScore: body.formalityScore
      });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/calendar/events - Get calendar events for date range
  if (req.method === "GET" && url.pathname === "/v1/calendar/events") {
    try {
      const authContext = await requireAuth(req, authService);
      const startDate = url.searchParams.get("start");
      const endDate = url.searchParams.get("end");
      if (!startDate || !endDate) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "start and end query parameters are required"
        });
        return;
      }
      const events = await calendarEventRepo.getEventsForDateRange(authContext, {
        startDate,
        endDate
      });
      sendJson(res, 200, { events });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/calendar/outfits - Create a calendar outfit assignment
  if (req.method === "POST" && url.pathname === "/v1/calendar/outfits") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      if (!body.outfitId || !body.scheduledDate) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "outfitId and scheduledDate are required"
        });
        return;
      }
      const result = await calendarOutfitRepo.createCalendarOutfit(authContext, {
        outfitId: body.outfitId,
        calendarEventId: body.calendarEventId ?? null,
        scheduledDate: body.scheduledDate,
        notes: body.notes ?? null
      });
      sendJson(res, 201, { calendarOutfit: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/calendar/outfits - Get calendar outfits for date range
  if (req.method === "GET" && url.pathname === "/v1/calendar/outfits") {
    try {
      const authContext = await requireAuth(req, authService);
      const startDate = url.searchParams.get("startDate");
      const endDate = url.searchParams.get("endDate");
      if (!startDate || !endDate) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "startDate and endDate query parameters are required"
        });
        return;
      }
      const calendarOutfits = await calendarOutfitRepo.getCalendarOutfitsForDateRange(authContext, {
        startDate,
        endDate
      });
      sendJson(res, 200, { calendarOutfits });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PUT /v1/calendar/outfits/:id - Update a calendar outfit assignment
  const calendarOutfitMatch = url.pathname.match(/^\/v1\/calendar\/outfits\/([^/]+)$/);
  if (req.method === "PUT" && calendarOutfitMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const calendarOutfitId = calendarOutfitMatch[1];
      const body = await readBody(req);
      const result = await calendarOutfitRepo.updateCalendarOutfit(authContext, calendarOutfitId, {
        outfitId: body.outfitId,
        calendarEventId: body.calendarEventId,
        notes: body.notes
      });
      sendJson(res, 200, { calendarOutfit: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // DELETE /v1/calendar/outfits/:id - Delete a calendar outfit assignment
  if (req.method === "DELETE" && calendarOutfitMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const calendarOutfitId = calendarOutfitMatch[1];
      await calendarOutfitRepo.deleteCalendarOutfit(authContext, calendarOutfitId);
      sendJson(res, 204, {});
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/outfits - List all outfits for the authenticated user
  if (req.method === "GET" && url.pathname === "/v1/outfits") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await outfitRepository.listOutfits(authContext);
      sendJson(res, 200, { outfits: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/outfits - Save an outfit
  if (req.method === "POST" && url.pathname === "/v1/outfits") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      // Validate required fields
      if (!body.name || typeof body.name !== "string") {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "Name is required"
        });
        return;
      }

      if (!Array.isArray(body.items) || body.items.length === 0) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "At least one item is required"
        });
        return;
      }

      if (body.items.length > 7) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "Maximum 7 items per outfit"
        });
        return;
      }

      const result = await outfitRepository.createOutfit(authContext, {
        name: body.name,
        explanation: body.explanation,
        occasion: body.occasion,
        source: body.source || "ai",
        items: body.items
      });

      sendJson(res, 201, { outfit: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/outfits/generate - Generate AI outfit suggestions
  if (req.method === "POST" && url.pathname === "/v1/outfits/generate") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      // Check usage limits before calling Gemini (premiumGuard handles trial expiry)
      if (usageLimitService) {
        const usageCheck = await usageLimitService.checkUsageLimit(authContext);
        if (!usageCheck.allowed) {
          throw {
            statusCode: 429,
            code: "RATE_LIMIT_EXCEEDED",
            message: "Daily outfit generation limit reached",
            dailyLimit: usageCheck.dailyLimit,
            used: usageCheck.used,
            remaining: usageCheck.remaining,
            resetsAt: usageCheck.resetsAt,
          };
        }
      }

      const result = await outfitGenerationService.generateOutfits(authContext, {
        outfitContext: body.outfitContext
      });

      // Get updated usage metadata after generation
      let usage;
      if (usageLimitService) {
        usage = await usageLimitService.getUsageAfterGeneration(authContext);
      }

      sendJson(res, 200, { ...result, usage });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/outfits/generate-for-event - Generate event-specific AI outfit suggestions
  if (req.method === "POST" && url.pathname === "/v1/outfits/generate-for-event") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.event || typeof body.event !== "object") {
        sendJson(res, 400, { error: "Bad Request", message: "Event data is required" });
        return;
      }

      const requiredFields = ["title", "eventType", "formalityScore"];
      for (const field of requiredFields) {
        if (body.event[field] == null) {
          sendJson(res, 400, { error: "Bad Request", message: `Event ${field} is required` });
          return;
        }
      }

      const result = await outfitGenerationService.generateOutfitsForEvent(authContext, {
        outfitContext: body.outfitContext,
        event: body.event
      });

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/outfits/event-prep-tips - Generate AI preparation tip for a formal event
  if (req.method === "POST" && url.pathname === "/v1/outfits/event-prep-tips") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.event || typeof body.event !== "object") {
        sendJson(res, 400, { error: "Bad Request", message: "Event data is required" });
        return;
      }

      const result = await outfitGenerationService.generateEventPrepTip(authContext, {
        event: body.event,
        outfitItems: body.outfitItems || undefined,
      });

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PATCH /v1/outfits/:id - Update outfit (e.g., toggle favorite)
  const outfitIdMatch = url.pathname.match(/^\/v1\/outfits\/([^/]+)$/);
  if (req.method === "PATCH" && outfitIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (body.isFavorite === undefined) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "No valid fields to update"
        });
        return;
      }

      const result = await outfitRepository.updateOutfit(authContext, outfitIdMatch[1], {
        isFavorite: body.isFavorite,
      });
      sendJson(res, 200, { outfit: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // DELETE /v1/outfits/:id - Delete an outfit
  if (req.method === "DELETE" && outfitIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await outfitRepository.deleteOutfit(authContext, outfitIdMatch[1]);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/wear-logs - Create a wear log
  if (req.method === "POST" && url.pathname === "/v1/wear-logs") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      // Validate items array
      if (!Array.isArray(body.items) || body.items.length === 0) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "items must be a non-empty array of UUIDs"
        });
        return;
      }

      if (body.items.length > 20) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "Maximum 20 items per wear log"
        });
        return;
      }

      const result = await wearLogRepository.createWearLog(authContext, {
        itemIds: body.items,
        outfitId: body.outfitId ?? null,
        photoUrl: body.photoUrl ?? null,
        loggedDate: body.loggedDate ?? null,
      });

      // Evaluate streak (best-effort, non-blocking)
      let streakResult = null;
      try {
        if (streakService) {
          streakResult = await streakService.evaluateStreak(authContext, {
            loggedDate: body.loggedDate,
          });
        }
      } catch (streakError) {
        console.error("[streak] Failed to evaluate streak:", streakError.message ?? streakError);
      }

      // Award style points (best-effort, non-blocking)
      // Pass streak result to determine streak bonus instead of separate checkStreakDay()
      let pointsAwarded = null;
      try {
        if (stylePointsService) {
          pointsAwarded = await stylePointsService.awardWearLogPoints(authContext, {
            isStreakDay: streakResult?.streakExtended ?? false,
          });
        }
      } catch (pointsError) {
        console.error("[style-points] Failed to award wear log points:", pointsError.message ?? pointsError);
      }

      // Build streak update for response
      const streakUpdate = streakResult ? {
        currentStreak: streakResult.currentStreak,
        longestStreak: streakResult.longestStreak,
        isNewStreak: streakResult.isNewStreak,
        streakExtended: streakResult.streakExtended,
        streakFreezeAvailable: streakResult.streakFreezeAvailable,
      } : null;

      // Evaluate badges (best-effort, non-blocking)
      let badgesAwarded = null;
      try {
        if (badgeService) {
          const badgeResult = await badgeService.evaluateAndAward(authContext);
          badgesAwarded = badgeResult.badgesAwarded;
        }
      } catch (badgeError) {
        console.error("[badges] Failed to evaluate badges:", badgeError.message ?? badgeError);
      }

      sendJson(res, 201, { wearLog: result, pointsAwarded, streakUpdate, badgesAwarded });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/wear-logs - List wear logs for a date range
  if (req.method === "GET" && url.pathname === "/v1/wear-logs") {
    try {
      const authContext = await requireAuth(req, authService);
      const startDate = url.searchParams.get("start");
      const endDate = url.searchParams.get("end");

      if (!startDate || !endDate) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "start and end query parameters are required"
        });
        return;
      }

      const wearLogs = await wearLogRepository.listWearLogs(authContext, {
        startDate,
        endDate,
      });

      sendJson(res, 200, { wearLogs });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/wardrobe-summary - Get wardrobe analytics summary
  if (req.method === "GET" && url.pathname === "/v1/analytics/wardrobe-summary") {
    try {
      const authContext = await requireAuth(req, authService);
      const summary = await analyticsRepository.getWardrobeSummary(authContext);
      sendJson(res, 200, { summary });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/items-cpw - Get items with cost-per-wear
  if (req.method === "GET" && url.pathname === "/v1/analytics/items-cpw") {
    try {
      const authContext = await requireAuth(req, authService);
      const items = await analyticsRepository.getItemsWithCpw(authContext);
      sendJson(res, 200, { items });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/top-worn - Get top worn items with optional period filter
  if (req.method === "GET" && url.pathname === "/v1/analytics/top-worn") {
    try {
      const authContext = await requireAuth(req, authService);
      const period = url.searchParams.get("period") || "all";
      const items = await analyticsRepository.getTopWornItems(authContext, { period });
      sendJson(res, 200, { items });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/category-distribution - Get category distribution
  if (req.method === "GET" && url.pathname === "/v1/analytics/category-distribution") {
    try {
      const authContext = await requireAuth(req, authService);
      const categories = await analyticsRepository.getCategoryDistribution(authContext);
      sendJson(res, 200, { categories });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/wear-frequency - Get wear frequency by day of week
  if (req.method === "GET" && url.pathname === "/v1/analytics/wear-frequency") {
    try {
      const authContext = await requireAuth(req, authService);
      const days = await analyticsRepository.getWearFrequency(authContext);
      sendJson(res, 200, { days });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/neglected - Get neglected items
  if (req.method === "GET" && url.pathname === "/v1/analytics/neglected") {
    try {
      const authContext = await requireAuth(req, authService);
      const items = await analyticsRepository.getNeglectedItems(authContext);
      sendJson(res, 200, { items });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/brand-value - Get brand value analytics (premium only)
  if (req.method === "GET" && url.pathname === "/v1/analytics/brand-value") {
    try {
      const authContext = await requireAuth(req, authService);
      await premiumGuard.requirePremium(authContext);
      const category = url.searchParams.get("category") || null;
      const result = await analyticsRepository.getBrandValueAnalytics(authContext, { category });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      if (error?.statusCode === 403) {
        sendJson(res, 403, {
          error: "Premium Required",
          code: "PREMIUM_REQUIRED",
          message: "Premium subscription required",
        });
        return;
      }
      if (error?.statusCode === 400) {
        sendJson(res, 400, { error: error.message });
        return;
      }
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/sustainability - Get sustainability analytics (premium only)
  if (req.method === "GET" && url.pathname === "/v1/analytics/sustainability") {
    try {
      const authContext = await requireAuth(req, authService);
      await premiumGuard.requirePremium(authContext);
      const result = await analyticsRepository.getSustainabilityAnalytics(authContext);

      // Badge trigger: eco_warrior when score >= 80
      if (result.score >= 80) {
        try {
          if (badgeService) {
            const awarded = await badgeService.checkAndAward(authContext, "eco_warrior");
            if (awarded) {
              result.badgeAwarded = true;
            }
          }
        } catch (badgeError) {
          // Best-effort: badge failure must NOT fail the endpoint
          console.error("[badges] Failed to award eco_warrior badge:", badgeError.message ?? badgeError);
        }
      }

      sendJson(res, 200, result);
      return;
    } catch (error) {
      if (error?.statusCode === 403) {
        sendJson(res, 403, {
          error: "Premium Required",
          code: "PREMIUM_REQUIRED",
          message: "Premium subscription required",
        });
        return;
      }
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/ai-summary - Generate AI analytics summary (premium only)
  if (req.method === "GET" && url.pathname === "/v1/analytics/ai-summary") {
    try {
      const authContext = await requireAuth(req, authService);

      // premiumGuard inside analyticsSummaryService handles trial expiry
      const result = await analyticsSummaryService.generateSummary(authContext);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      if (error?.statusCode === 403) {
        sendJson(res, 403, {
          error: "Premium Required",
          code: "PREMIUM_REQUIRED",
          message: "Premium subscription required for AI insights",
        });
        return;
      }
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/seasonal-reports - Get seasonal reports (premium only)
  if (req.method === "GET" && url.pathname === "/v1/analytics/seasonal-reports") {
    try {
      const authContext = await requireAuth(req, authService);
      await premiumGuard.requirePremium(authContext);
      const result = await analyticsRepository.getSeasonalReports(authContext);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      if (error?.statusCode === 403) {
        sendJson(res, 403, {
          error: "Premium Required",
          code: "PREMIUM_REQUIRED",
          message: "Premium subscription required",
        });
        return;
      }
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/heatmap - Get wear heatmap data (premium only)
  if (req.method === "GET" && url.pathname === "/v1/analytics/heatmap") {
    try {
      const authContext = await requireAuth(req, authService);
      await premiumGuard.requirePremium(authContext);

      const start = url.searchParams.get("start");
      const end = url.searchParams.get("end");

      // Validate date params
      if (!start || !end) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "Both 'start' and 'end' query parameters are required",
        });
        return;
      }

      const startDate = new Date(start + "T00:00:00");
      const endDate = new Date(end + "T00:00:00");

      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "Invalid date format. Use YYYY-MM-DD",
        });
        return;
      }

      if (endDate < startDate) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "'end' must be >= 'start'",
        });
        return;
      }

      const diffDays = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24));
      if (diffDays > 366) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "Date range must not exceed 366 days",
        });
        return;
      }

      const result = await analyticsRepository.getHeatmapData(authContext, {
        startDate: start,
        endDate: end,
      });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      if (error?.statusCode === 403) {
        sendJson(res, 403, {
          error: "Premium Required",
          code: "PREMIUM_REQUIRED",
          message: "Premium subscription required",
        });
        return;
      }
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/analytics/wardrobe-health - Get wardrobe health score (FREE tier)
  if (req.method === "GET" && url.pathname === "/v1/analytics/wardrobe-health") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await analyticsRepository.getWardrobeHealthScore(authContext);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/user-stats - Get user gamification stats
  if (req.method === "GET" && url.pathname === "/v1/user-stats") {
    try {
      const authContext = await requireAuth(req, authService);
      const stats = await userStatsRepo.getUserStats(authContext);

      // Add badge data (best-effort)
      let badges = [];
      let badgeCount = 0;
      try {
        if (badgeService) {
          const badgeCollection = await badgeService.getUserBadgeCollection(authContext);
          badges = badgeCollection.badges;
          badgeCount = badgeCollection.badgeCount;
        }
      } catch (badgeError) {
        console.error("[badges] Failed to load user badges:", badgeError.message ?? badgeError);
      }

      // Add challenge data (best-effort)
      let challenge = null;
      try {
        if (challengeService) {
          challenge = await challengeService.getChallengeStatus(authContext);
        }
      } catch (challengeError) {
        console.error("[challenge] Failed to load challenge status:", challengeError.message ?? challengeError);
      }

      sendJson(res, 200, { stats: { ...stats, badges, badgeCount, challenge } });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/badges - Get badge catalog
  if (req.method === "GET" && url.pathname === "/v1/badges") {
    try {
      const authContext = await requireAuth(req, authService);
      const badges = await badgeService.getBadgeCatalog();
      sendJson(res, 200, { badges });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/challenges/:key/accept - Accept a challenge
  const challengeAcceptMatch = url.pathname.match(/^\/v1\/challenges\/([^/]+)\/accept$/);
  if (req.method === "POST" && challengeAcceptMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const challengeKey = challengeAcceptMatch[1];
      const result = await challengeService.acceptChallenge(authContext, challengeKey);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/subscription/sync - Sync subscription from client
  if (req.method === "POST" && url.pathname === "/v1/subscription/sync") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await subscriptionSyncService.syncFromClient(authContext, {
        appUserId: body.appUserId,
      });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/resale/generate - Generate AI resale listing (premium gated)
  if (req.method === "POST" && url.pathname === "/v1/resale/generate") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.itemId) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "itemId is required"
        });
        return;
      }

      // Check usage quota (premium gating)
      const quota = await premiumGuard.checkUsageQuota(authContext, {
        feature: "resale_listing",
        freeLimit: FREE_LIMITS.RESALE_LISTING_MONTHLY,
        period: "month"
      });

      if (!quota.allowed) {
        sendJson(res, 429, {
          error: "Rate Limit Exceeded",
          code: "RATE_LIMIT_EXCEEDED",
          message: `Free tier limit: ${FREE_LIMITS.RESALE_LISTING_MONTHLY} resale listings per month`,
          monthlyLimit: FREE_LIMITS.RESALE_LISTING_MONTHLY,
          used: quota.used,
          remaining: quota.remaining,
          resetsAt: quota.resetsAt
        });
        return;
      }

      const result = await resaleListingService.generateListing(authContext, {
        itemId: body.itemId
      });

      // Best-effort badge check: "circular_seller" badge for listing items
      try {
        if (badgeService) {
          await badgeService.checkAndAward(authContext, "circular_seller");
        }
      } catch (badgeError) {
        console.error("[resale] Failed to check badge eligibility:", badgeError.message ?? badgeError);
      }

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PATCH /v1/items/:id/resale-status - Update resale status (sold/donated)
  const resaleStatusMatch = url.pathname.match(/^\/v1\/items\/([^/]+)\/resale-status$/);
  if (req.method === "PATCH" && resaleStatusMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const itemId = resaleStatusMatch[1];
      const body = await readBody(req);
      const { status, salePrice, saleCurrency, saleDate } = body;

      // Validate status
      if (!["sold", "donated"].includes(status)) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "status must be 'sold' or 'donated'"
        });
        return;
      }

      // For sold, validate salePrice
      if (status === "sold") {
        if (salePrice == null || typeof salePrice !== "number" || salePrice <= 0) {
          sendJson(res, 400, {
            error: "Bad Request",
            code: "BAD_REQUEST",
            message: "salePrice must be a positive number for sold status"
          });
          return;
        }
      }

      // Fetch the item (throws 404 if not found)
      const existingItem = await itemService.getItemForUser(authContext, itemId);
      const currentStatus = existingItem.item.resaleStatus;

      // Validate status transition
      const validTransitions = {
        null: ["donated"],
        "listed": ["sold", "donated"],
      };
      const allowed = validTransitions[currentStatus] || [];
      if (!allowed.includes(status)) {
        throw {
          statusCode: 409,
          code: "INVALID_TRANSITION",
          message: `Cannot transition from '${currentStatus}' to '${status}'`
        };
      }

      // Update item resale_status
      const updatedItemResult = await itemService.updateItemForUser(authContext, itemId, { resaleStatus: status });

      // Create history entry (resaleListingId is null; linked at DB level if needed)
      const historyEntry = await resaleHistoryRepo.createHistoryEntry(authContext, {
        itemId,
        resaleListingId: null,
        type: status,
        salePrice: status === "sold" ? salePrice : 0,
        saleCurrency: saleCurrency || "GBP",
        saleDate: saleDate || null,
      });

      // Best-effort: check circular_champion badge on sold
      if (status === "sold") {
        try {
          if (badgeService) {
            await badgeService.checkAndAward(authContext, "circular_champion");
          }
        } catch (badgeError) {
          console.error("[resale-status] Failed to check badge eligibility:", badgeError.message ?? badgeError);
        }
      }

      sendJson(res, 200, { item: updatedItemResult.item, historyEntry });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/resale/history - Get resale history with summary and monthly earnings
  if (req.method === "GET" && url.pathname === "/v1/resale/history") {
    try {
      const authContext = await requireAuth(req, authService);
      const limit = parseInt(url.searchParams.get("limit") || "50", 10);
      const offset = parseInt(url.searchParams.get("offset") || "0", 10);

      const [history, summary, monthlyEarnings] = await Promise.all([
        resaleHistoryRepo.listHistory(authContext, { limit, offset }),
        resaleHistoryRepo.getEarningsSummary(authContext),
        resaleHistoryRepo.getMonthlyEarnings(authContext),
      ]);

      sendJson(res, 200, { history, summary, monthlyEarnings });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/resale/prompts/evaluate - Trigger monthly resale evaluation
  if (req.method === "POST" && url.pathname === "/v1/resale/prompts/evaluate") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await resalePromptService.evaluateAndNotify(authContext);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/resale/prompts/count - Get pending resale prompt count
  if (req.method === "GET" && url.pathname === "/v1/resale/prompts/count") {
    try {
      const authContext = await requireAuth(req, authService);
      const count = await resalePromptService.getPendingCount(authContext);
      sendJson(res, 200, { count });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/resale/prompts - Get pending resale prompts
  if (req.method === "GET" && url.pathname === "/v1/resale/prompts") {
    try {
      const authContext = await requireAuth(req, authService);
      const prompts = await resalePromptService.getPendingPrompts(authContext);
      sendJson(res, 200, { prompts });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PATCH /v1/resale/prompts/:id - Update resale prompt action
  const resalePromptMatch = url.pathname.match(/^\/v1\/resale\/prompts\/([^/]+)$/);
  if (req.method === "PATCH" && resalePromptMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const promptId = resalePromptMatch[1];
      const body = await readBody(req);

      if (!body.action || (body.action !== "accepted" && body.action !== "dismissed")) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "action must be 'accepted' or 'dismissed'"
        });
        return;
      }

      const result = await resalePromptService.updatePromptAction(authContext, promptId, { action: body.action });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/shopping/scan-screenshot - Scan a product screenshot for shopping assistant
  if (req.method === "POST" && url.pathname === "/v1/shopping/scan-screenshot") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.imageUrl || typeof body.imageUrl !== "string") {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "imageUrl is required"
        });
        return;
      }

      // Check usage quota (premium gating) - shared with URL scans
      const quota = await premiumGuard.checkUsageQuota(authContext, {
        feature: "shopping_scan",
        freeLimit: FREE_LIMITS.SHOPPING_SCAN_DAILY,
        period: "day"
      });

      if (!quota.allowed) {
        sendJson(res, 429, {
          error: "Rate Limit Exceeded",
          code: "RATE_LIMIT_EXCEEDED",
          message: `Free tier limit: ${FREE_LIMITS.SHOPPING_SCAN_DAILY} shopping scans per day`,
          dailyLimit: FREE_LIMITS.SHOPPING_SCAN_DAILY,
          used: quota.used,
          remaining: quota.remaining,
          resetsAt: quota.resetsAt
        });
        return;
      }

      const result = await shoppingScanService.scanScreenshot(authContext, {
        imageUrl: body.imageUrl
      });

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/shopping/scan-url - Scan a product URL for shopping assistant
  if (req.method === "POST" && url.pathname === "/v1/shopping/scan-url") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.url || typeof body.url !== "string") {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "url is required"
        });
        return;
      }

      // Check usage quota (premium gating)
      const quota = await premiumGuard.checkUsageQuota(authContext, {
        feature: "shopping_scan",
        freeLimit: FREE_LIMITS.SHOPPING_SCAN_DAILY,
        period: "day"
      });

      if (!quota.allowed) {
        sendJson(res, 429, {
          error: "Rate Limit Exceeded",
          code: "RATE_LIMIT_EXCEEDED",
          message: `Free tier limit: ${FREE_LIMITS.SHOPPING_SCAN_DAILY} shopping scans per day`,
          dailyLimit: FREE_LIMITS.SHOPPING_SCAN_DAILY,
          used: quota.used,
          remaining: quota.remaining,
          resetsAt: quota.resetsAt
        });
        return;
      }

      const result = await shoppingScanService.scanUrl(authContext, {
        url: body.url
      });

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/shopping/scans/:id/insights - Generate match & insight analysis
  const insightsMatch = url.pathname.match(/^\/v1\/shopping\/scans\/([^/]+)\/insights$/);
  if (req.method === "POST" && insightsMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const scanId = insightsMatch[1];

      const result = await shoppingScanService.generateInsights(authContext, { scanId });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/shopping/scans/:id/score - Score purchase compatibility against wardrobe
  const scoreMatch = url.pathname.match(/^\/v1\/shopping\/scans\/([^/]+)\/score$/);
  if (req.method === "POST" && scoreMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const scanId = scoreMatch[1];

      const result = await shoppingScanService.scoreCompatibility(authContext, { scanId });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // PATCH /v1/shopping/scans/:id - Update a shopping scan's metadata
  const scanIdMatch = url.pathname.match(/^\/v1\/shopping\/scans\/([^/]+)$/);
  if (req.method === "PATCH" && scanIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const scanId = scanIdMatch[1];
      const body = await readBody(req);

      const validationResult = validateScanUpdate(body);
      if (!validationResult.valid) {
        sendJson(res, 400, {
          error: "Validation Error",
          code: "VALIDATION_ERROR",
          errors: validationResult.errors
        });
        return;
      }

      const updatedScan = await shoppingScanRepo.updateScan(authContext, scanId, validationResult.data);
      if (!updatedScan) {
        sendJson(res, 404, { error: "Not Found", code: "NOT_FOUND", message: "Scan not found" });
        return;
      }

      sendJson(res, 200, { scan: updatedScan });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // --- OOTD Post routes (MUST come before squad :id routes to prevent "posts" being parsed as squad ID) ---

  // POST /v1/squads/posts - Create OOTD post
  if (req.method === "POST" && url.pathname === "/v1/squads/posts") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await ootdService.createPost(authContext, {
        photoUrl: body.photoUrl,
        caption: body.caption,
        squadIds: body.squadIds,
        taggedItemIds: body.taggedItemIds,
      });
      sendJson(res, 201, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/squads/posts/feed - List feed across all squads
  if (req.method === "GET" && url.pathname === "/v1/squads/posts/feed") {
    try {
      const authContext = await requireAuth(req, authService);
      const limit = url.searchParams.get("limit") ? parseInt(url.searchParams.get("limit"), 10) : undefined;
      const cursor = url.searchParams.get("cursor") || undefined;
      const result = await ootdService.listFeedPosts(authContext, { limit, cursor });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // --- Steal This Look route (MUST come BEFORE ootdPostIdMatch) ---

  const ootdStealLookMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/steal-look$/);

  // POST /v1/squads/posts/:postId/steal-look - Steal This Look AI matching
  if (req.method === "POST" && ootdStealLookMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await ootdService.stealThisLook(authContext, { postId: ootdStealLookMatch[1] });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // --- Reaction & Comment routes (MUST come BEFORE ootdPostIdMatch) ---

  const ootdReactionMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/reactions$/);
  const ootdCommentMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/comments$/);
  const ootdCommentIdMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/comments\/([^/]+)$/);

  // DELETE /v1/squads/posts/:postId/comments/:commentId - Delete comment (specific before general)
  if (req.method === "DELETE" && ootdCommentIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      await ootdService.deleteComment(authContext, { postId: ootdCommentIdMatch[1], commentId: ootdCommentIdMatch[2] });
      sendJson(res, 204, {});
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/squads/posts/:postId/reactions - Toggle reaction
  if (req.method === "POST" && ootdReactionMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await ootdService.toggleReaction(authContext, { postId: ootdReactionMatch[1] });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/squads/posts/:postId/comments - Create comment
  if (req.method === "POST" && ootdCommentMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await ootdService.createComment(authContext, { postId: ootdCommentMatch[1], text: body.text });
      sendJson(res, 201, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/squads/posts/:postId/comments - List comments
  if (req.method === "GET" && ootdCommentMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const limit = url.searchParams.get("limit") ? parseInt(url.searchParams.get("limit"), 10) : undefined;
      const cursor = url.searchParams.get("cursor") || undefined;
      const result = await ootdService.listComments(authContext, { postId: ootdCommentMatch[1], limit, cursor });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // OOTD post ID routes (regex matching)
  const ootdPostIdMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)$/);

  // GET /v1/squads/posts/:postId - Get post detail
  if (req.method === "GET" && ootdPostIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await ootdService.getPost(authContext, { postId: ootdPostIdMatch[1] });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // DELETE /v1/squads/posts/:postId - Delete own post (soft delete)
  if (req.method === "DELETE" && ootdPostIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      await ootdService.deletePost(authContext, { postId: ootdPostIdMatch[1] });
      sendJson(res, 204, {});
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/squads/:id/posts - List posts for a specific squad
  const squadPostsMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/posts$/);
  if (req.method === "GET" && squadPostsMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const limit = url.searchParams.get("limit") ? parseInt(url.searchParams.get("limit"), 10) : undefined;
      const cursor = url.searchParams.get("cursor") || undefined;
      const result = await ootdService.listSquadPosts(authContext, {
        squadId: squadPostsMatch[1],
        limit,
        cursor,
      });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // --- Squads routes (order matters!) ---

  // POST /v1/squads/join - Join a squad via invite code (MUST be before GET /v1/squads/:id)
  if (req.method === "POST" && url.pathname === "/v1/squads/join") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await squadService.joinSquad(authContext, { inviteCode: body.inviteCode });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/squads - Create a squad
  if (req.method === "POST" && url.pathname === "/v1/squads") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);
      const result = await squadService.createSquad(authContext, { name: body.name, description: body.description });
      sendJson(res, 201, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/squads - List my squads
  if (req.method === "GET" && url.pathname === "/v1/squads") {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await squadService.listMySquads(authContext);
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // Squad ID routes (regex matching)
  const squadIdMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)$/);
  const squadMembersMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/members$/);
  const squadMembersMeMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/members\/me$/);
  const squadMemberIdMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/members\/([^/]+)$/);

  // GET /v1/squads/:id - Get squad detail
  if (req.method === "GET" && squadIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await squadService.getSquad(authContext, { squadId: squadIdMatch[1] });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/squads/:id/members - List squad members
  if (req.method === "GET" && squadMembersMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await squadService.listMembers(authContext, { squadId: squadMembersMatch[1] });
      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // DELETE /v1/squads/:id/members/me - Leave squad (MUST be before DELETE /v1/squads/:id/members/:memberId)
  if (req.method === "DELETE" && squadMembersMeMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await squadService.leaveSquad(authContext, { squadId: squadMembersMeMatch[1] });
      sendJson(res, 204, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // DELETE /v1/squads/:id/members/:memberId - Remove member (admin only)
  if (req.method === "DELETE" && squadMemberIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const result = await squadService.removeMember(authContext, {
        squadId: squadMemberIdMatch[1],
        memberId: squadMemberIdMatch[2],
      });
      sendJson(res, 204, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // === Extraction Job Routes (Story 10.1) ===

  // POST /v1/uploads/signed-urls - Bulk signed URL generation
  if (req.method === "POST" && url.pathname === "/v1/uploads/signed-urls") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      const count = body.count;
      if (!count || count < 1 || count > 50) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "VALIDATION_ERROR",
          message: "count must be between 1 and 50"
        });
        return;
      }

      const purposes = body.purposes;
      if (!Array.isArray(purposes) || purposes.length !== count) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "VALIDATION_ERROR",
          message: "purposes array must match count"
        });
        return;
      }

      const urls = [];
      for (let i = 0; i < count; i++) {
        const result = await uploadService.generateSignedUploadUrl(authContext, {
          purpose: purposes[i].purpose,
          contentType: "image/jpeg"
        });
        urls.push({ index: purposes[i].index, uploadUrl: result.uploadUrl, publicUrl: result.publicUrl });
      }

      sendJson(res, 200, { urls });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/extraction-jobs - Create extraction job
  if (req.method === "POST" && url.pathname === "/v1/extraction-jobs") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      const result = await extractionService.createExtractionJob(authContext, {
        totalPhotos: body.totalPhotos,
        photos: body.photos
      });

      // Auto-trigger processing (fire-and-forget)
      if (extractionProcessingService) {
        extractionProcessingService.processExtractionJob(authContext, result.id)
          .catch(err => console.error("[extraction-processing] Failed:", err));
      }

      sendJson(res, 201, { job: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/extraction-jobs/:id/process - Trigger extraction processing
  const extractionProcessMatch = url.pathname.match(/^\/v1\/extraction-jobs\/([^/]+)\/process$/);
  if (req.method === "POST" && extractionProcessMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const jobId = extractionProcessMatch[1];

      // Verify job exists and belongs to user
      const job = await extractionRepo.getJob(authContext, jobId);
      if (!job) {
        sendJson(res, 404, {
          error: "Not Found",
          code: "NOT_FOUND",
          message: "Extraction job not found"
        });
        return;
      }

      if (job.status !== "processing") {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "INVALID_JOB_STATUS",
          message: `Job status must be 'processing' to trigger processing (current: '${job.status}')`
        });
        return;
      }

      // Fire-and-forget processing
      if (extractionProcessingService) {
        extractionProcessingService.processExtractionJob(authContext, jobId)
          .catch(err => console.error("[extraction-processing] Failed:", err));
      }

      sendJson(res, 202, { status: "processing" });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/extraction-jobs/:id/confirm - Confirm extraction results
  const extractionConfirmMatch = url.pathname.match(/^\/v1\/extraction-jobs\/([^/]+)\/confirm$/);
  if (req.method === "POST" && extractionConfirmMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const jobId = extractionConfirmMatch[1];
      const body = await readBody(req);

      const result = await extractionService.confirmExtractionJob(
        authContext, jobId, {
          keptItemIds: body.keptItemIds || [],
          metadataEdits: body.metadataEdits || {}
        }
      );

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/extraction-jobs/:id/duplicates - Check for duplicate items
  const extractionDuplicatesMatch = url.pathname.match(/^\/v1\/extraction-jobs\/([^/]+)\/duplicates$/);
  if (req.method === "GET" && extractionDuplicatesMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const jobId = extractionDuplicatesMatch[1];

      const result = await extractionService.checkDuplicates(authContext, jobId);

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/extraction-jobs/:id - Get extraction job
  const extractionJobIdMatch = url.pathname.match(/^\/v1\/extraction-jobs\/([^/]+)$/);
  if (req.method === "GET" && extractionJobIdMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const jobId = extractionJobIdMatch[1];
      const result = await extractionRepo.getJob(authContext, jobId);

      if (!result) {
        sendJson(res, 404, {
          error: "Not Found",
          code: "NOT_FOUND",
          message: "Extraction job not found"
        });
        return;
      }

      sendJson(res, 200, { job: result });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/calendar/trips/detect - Detect upcoming trips from calendar events
  if (req.method === "POST" && url.pathname === "/v1/calendar/trips/detect") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      const lookaheadDays = Math.min(Math.max(body.lookaheadDays || 14, 1), 30);
      const trips = await tripDetectionService.detectTrips(authContext, { lookaheadDays });

      sendJson(res, 200, { trips });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/calendar/trips/:tripId/packing-list - Generate packing list for a trip
  const packingListMatch = url.pathname.match(/^\/v1\/calendar\/trips\/([^/]+)\/packing-list$/);
  if (req.method === "POST" && packingListMatch) {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.trip || typeof body.trip !== "object") {
        sendJson(res, 400, { error: "Bad Request", code: "BAD_REQUEST", message: "Trip data is required" });
        return;
      }
      if (!body.trip.destination || !body.trip.startDate || !body.trip.endDate) {
        sendJson(res, 400, { error: "Bad Request", code: "BAD_REQUEST", message: "Trip destination, startDate, and endDate are required" });
        return;
      }

      // Fetch destination weather if coordinates available
      let destinationWeather = null;
      if (body.trip.destinationCoordinates) {
        try {
          destinationWeather = await tripDetectionService.fetchDestinationWeather(
            body.trip.destinationCoordinates.latitude,
            body.trip.destinationCoordinates.longitude,
            body.trip.startDate,
            body.trip.endDate
          );
        } catch (_) {
          // Weather fetch failure is non-fatal
        }
      }

      // Fetch events for the trip date range
      let events = [];
      try {
        events = await calendarEventRepo.getEventsForDateRange(authContext, {
          startDate: body.trip.startDate,
          endDate: body.trip.endDate,
        });
      } catch (_) {
        // Event fetch failure is non-fatal
      }

      // Fetch user's categorized wardrobe items
      const allItems = await itemRepo.listItems(authContext, {});
      const categorizedItems = allItems.filter(
        (item) => item.categorizationStatus === "completed"
      );

      const result = await outfitGenerationService.generatePackingList(authContext, {
        trip: body.trip,
        destinationWeather,
        events,
        items: categorizedItems,
      });

      // Mark weather unavailable if no weather data
      if (!destinationWeather && result.packingList) {
        result.packingList.weatherUnavailable = true;
      }

      sendJson(res, 200, result);
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // POST /v1/donations - Create a donation log entry (FREE tier)
  if (req.method === "POST" && url.pathname === "/v1/donations") {
    try {
      const authContext = await requireAuth(req, authService);
      const body = await readBody(req);

      if (!body.itemId) {
        sendJson(res, 400, {
          error: "Bad Request",
          code: "BAD_REQUEST",
          message: "itemId is required"
        });
        return;
      }

      // Fetch item to validate it exists and is eligible
      const existingItem = await itemService.getItemForUser(authContext, body.itemId);
      const currentStatus = existingItem.item.resaleStatus;

      // Only allow donation for items with resale_status NULL or 'listed'
      if (currentStatus === "sold" || currentStatus === "donated") {
        throw {
          statusCode: 409,
          code: "INVALID_TRANSITION",
          message: `Cannot donate item with resale_status '${currentStatus}'`
        };
      }

      // Create donation log entry
      const donation = await donationRepository.createDonation(authContext, {
        itemId: body.itemId,
        charityName: body.charityName || null,
        estimatedValue: body.estimatedValue || 0,
        donationDate: body.donationDate || null,
      });

      // Update item resale_status to 'donated'
      const updatedItemResult = await itemService.updateItemForUser(authContext, body.itemId, { resaleStatus: "donated" });

      // Best-effort: check generous_giver badge
      try {
        if (badgeService) {
          await badgeService.checkAndAward(authContext, "generous_giver");
        }
      } catch (badgeError) {
        console.error("[donations] Failed to check badge eligibility:", badgeError.message ?? badgeError);
      }

      sendJson(res, 201, { donation, item: updatedItemResult.item });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/donations - Get donation history with summary (FREE tier)
  if (req.method === "GET" && url.pathname === "/v1/donations") {
    try {
      const authContext = await requireAuth(req, authService);
      const limit = parseInt(url.searchParams.get("limit") || "50", 10);
      const offset = parseInt(url.searchParams.get("offset") || "0", 10);

      const [donations, summary] = await Promise.all([
        donationRepository.listDonations(authContext, { limit, offset }),
        donationRepository.getDonationSummary(authContext),
      ]);

      sendJson(res, 200, { donations, summary });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  // GET /v1/spring-clean/items - Get neglected items eligible for Spring Clean (FREE tier)
  if (req.method === "GET" && url.pathname === "/v1/spring-clean/items") {
    try {
      const authContext = await requireAuth(req, authService);

      const client = await pool.connect();

      let items;
      try {
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId]);

        const result = await client.query(
          `SELECT i.*,
                  (CURRENT_DATE - COALESCE(i.last_worn_date, i.created_at::date)) as days_unworn
           FROM app_public.items i
           WHERE i.neglect_status = 'neglected'
             AND i.resale_status IS NULL
           ORDER BY days_unworn DESC`
        );

        items = result.rows.map((row) => ({
          id: row.id,
          profileId: row.profile_id,
          photoUrl: row.photo_url,
          name: row.name,
          category: row.category,
          brand: row.brand,
          purchasePrice: row.purchase_price != null ? parseFloat(row.purchase_price) : null,
          currency: row.currency,
          wearCount: row.wear_count != null ? parseInt(row.wear_count, 10) : 0,
          lastWornDate: row.last_worn_date,
          neglectStatus: row.neglect_status,
          resaleStatus: row.resale_status,
          daysUnworn: parseInt(row.days_unworn, 10) || 0,
          estimatedValue: computeEstimatedPrice(
            row.purchase_price != null ? parseFloat(row.purchase_price) : null,
            row.wear_count != null ? parseInt(row.wear_count, 10) : 0
          ),
          createdAt: row.created_at?.toISOString?.() ?? row.created_at,
        }));
      } finally {
        client.release();
      }

      sendJson(res, 200, { items });
      return;
    } catch (error) {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
      return;
    }
  }

  notFound(req, res);
}

export function createServer(contextOrConfig = getConfig()) {
  return http.createServer((req, res) => {
    void handleRequest(req, res, contextOrConfig).catch((error) => {
      const mapped = mapError(error);
      sendJson(res, mapped.statusCode, mapped.body);
    });
  });
}

const isEntrypoint =
  process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];

if (isEntrypoint) {
  try {
    const config = getConfig();
    const runtime = createRuntime(config);
    const server = createServer(runtime);

    server.on("error", (error) => {
      console.error(`Failed to start ${config.appName}:`, error);
      process.exitCode = 1;
    });

    server.listen(config.port, config.host, () => {
      console.log(`${config.appName} listening on ${config.host}:${config.port}`);
    });
  } catch (error) {
    console.error("Invalid API configuration:", error);
    process.exitCode = 1;
  }
}
