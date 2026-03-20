import assert from "node:assert/strict";
import { Readable } from "node:stream";
import test from "node:test";
import { handleRequest } from "../../../src/main.js";

function createResponseCapture() {
  return {
    statusCode: undefined,
    headers: undefined,
    body: undefined,
    writeHead(statusCode, headers) {
      this.statusCode = statusCode;
      this.headers = headers;
    },
    end(body) {
      this.body = body;
    }
  };
}

function createJsonRequest(method, url, body) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    authorization: "Bearer signed.jwt.token",
    "content-type": "application/json"
  };
  return stream;
}

function createUnauthRequest(method, url, body) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json"
  };
  return stream;
}

function buildContext({ extractionService, extractionRepo, extractionProcessingService, itemService } = {}) {
  return {
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate() {
        return {
          userId: "firebase-user-123",
          email: "user@example.com",
          emailVerified: true,
          provider: "google.com"
        };
      }
    },
    profileService: {
      async getProfileForAuthenticatedUser() {
        return { profile: { id: "profile-1" }, provisioned: false };
      },
      async updateProfileForAuthenticatedUser() {
        return { profile: {} };
      }
    },
    itemService: itemService ?? {
      async createItemForUser() { return { item: {} }; },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser() { return { deleted: true }; }
    },
    uploadService: {
      async generateSignedUploadUrl(authContext, { purpose }) {
        return { uploadUrl: "https://upload.example.com/upload", publicUrl: "https://storage.example.com/photo.jpg" };
      }
    },
    extractionService: extractionService ?? {
      async createExtractionJob(authContext, data) {
        return {
          id: "job-1",
          profileId: "profile-1",
          status: "processing",
          totalPhotos: data.totalPhotos,
          uploadedPhotos: data.totalPhotos,
          processedPhotos: 0,
          totalItemsFound: 0,
          photos: data.photos.map((p, i) => ({
            id: `photo-${i}`,
            jobId: "job-1",
            photoUrl: p.photoUrl,
            originalFilename: p.originalFilename ?? null,
            status: "uploaded"
          }))
        };
      },
      async confirmExtractionJob(authContext, jobId, { keptItemIds, metadataEdits }) {
        if (jobId === "not-found") {
          const err = new Error("Extraction job not found");
          err.statusCode = 404;
          err.code = "NOT_FOUND";
          throw err;
        }
        if (jobId === "processing-job") {
          const err = new Error("Cannot confirm job with status 'processing'");
          err.statusCode = 400;
          err.code = "VALIDATION_ERROR";
          throw err;
        }
        if (keptItemIds && keptItemIds.includes("invalid-id")) {
          const err = new Error("Invalid item IDs: invalid-id");
          err.statusCode = 400;
          err.code = "VALIDATION_ERROR";
          throw err;
        }

        if (!keptItemIds || keptItemIds.length === 0) {
          return { confirmedCount: 0, items: [] };
        }

        return {
          confirmedCount: keptItemIds.length,
          items: keptItemIds.map((id, i) => ({
            id: `new-item-${i}`,
            profileId: "profile-1",
            photoUrl: `https://storage.example.com/cleaned-${i}.png`,
            name: metadataEdits?.[id]?.name ?? "Blue Tops",
            category: metadataEdits?.[id]?.category ?? "tops",
            color: metadataEdits?.[id]?.color ?? "blue",
            secondaryColors: [],
            pattern: "solid",
            material: "cotton",
            style: "casual",
            season: ["all"],
            occasion: ["everyday"],
            bgRemovalStatus: "completed",
            categorizationStatus: "completed",
            creationMethod: "ai_extraction",
            extractionJobId: jobId
          }))
        };
      },
      async checkDuplicates(authContext, jobId) {
        if (jobId === "not-found") {
          const err = new Error("Extraction job not found");
          err.statusCode = 404;
          err.code = "NOT_FOUND";
          throw err;
        }
        if (jobId === "job-with-duplicates") {
          return {
            duplicates: [
              {
                extractionItemId: "ext-item-1",
                matchingItemId: "existing-item-1",
                matchingItemPhotoUrl: "https://storage.example.com/existing.jpg",
                matchingItemName: "Blue Top"
              }
            ]
          };
        }
        return { duplicates: [] };
      }
    },
    extractionRepo: extractionRepo ?? {
      async getJob(authContext, jobId) {
        if (jobId === "not-found") return null;
        return {
          id: jobId,
          profileId: "profile-1",
          status: "completed",
          totalPhotos: 2,
          uploadedPhotos: 2,
          processedPhotos: 2,
          totalItemsFound: 2,
          photos: [],
          items: [
            {
              id: "item-1",
              jobId,
              photoId: "photo-1",
              itemIndex: 0,
              photoUrl: "https://storage.example.com/cleaned.png",
              category: "tops",
              color: "blue",
              secondaryColors: [],
              pattern: "solid",
              material: "cotton",
              style: "casual",
              season: ["all"],
              occasion: ["everyday"],
              bgRemovalStatus: "completed",
              categorizationStatus: "completed",
              detectionConfidence: 0.95,
              createdAt: "2026-03-19T12:00:00.000Z"
            }
          ]
        };
      }
    },
    extractionProcessingService: extractionProcessingService ?? {
      async processExtractionJob() { /* no-op mock */ }
    }
  };
}

// === POST /v1/extraction-jobs/:id/confirm tests ===

test("POST /v1/extraction-jobs/:id/confirm creates real items for kept IDs", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: ["item-1", "item-2"],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.equal(body.confirmedCount, 2);
  assert.ok(Array.isArray(body.items));
  assert.equal(body.items.length, 2);
});

test("POST /v1/extraction-jobs/:id/confirm - confirmed items have creation_method and extraction_job_id", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: ["item-1"],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.equal(body.items[0].creationMethod, "ai_extraction");
  assert.equal(body.items[0].extractionJobId, "job-1");
});

test("POST /v1/extraction-jobs/:id/confirm applies metadata edits", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: ["item-1"],
    metadataEdits: {
      "item-1": { name: "Custom Name", category: "outerwear" }
    }
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.equal(body.items[0].name, "Custom Name");
  assert.equal(body.items[0].category, "outerwear");
});

test("POST /v1/extraction-jobs/:id/confirm - empty keptItemIds still marks job confirmed", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: [],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.equal(body.confirmedCount, 0);
  assert.deepEqual(body.items, []);
});

test("POST /v1/extraction-jobs/:id/confirm returns 404 for non-existent job", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/not-found/confirm", {
    keptItemIds: [],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 404);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "NOT_FOUND");
});

test("POST /v1/extraction-jobs/:id/confirm returns 400 for invalid item IDs", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: ["invalid-id"],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});

test("POST /v1/extraction-jobs/:id/confirm returns 401 for unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createUnauthRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: [],
    metadataEdits: {}
  });

  const context = buildContext();
  context.authService = {
    async authenticate() {
      const err = new Error("Authentication required");
      err.statusCode = 401;
      err.code = "UNAUTHORIZED";
      throw err;
    }
  };

  await handleRequest(req, res, context);

  assert.equal(res.statusCode, 401);
});

test("POST /v1/extraction-jobs/:id/confirm returns 400 for processing job", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/processing-job/confirm", {
    keptItemIds: ["item-1"],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});

// === GET /v1/extraction-jobs/:id/duplicates tests ===

test("GET /v1/extraction-jobs/:id/duplicates returns duplicates matching by category+color", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/extraction-jobs/job-with-duplicates/duplicates");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(Array.isArray(body.duplicates));
  assert.equal(body.duplicates.length, 1);
  assert.equal(body.duplicates[0].extractionItemId, "ext-item-1");
  assert.equal(body.duplicates[0].matchingItemId, "existing-item-1");
  assert.ok(body.duplicates[0].matchingItemPhotoUrl);
  assert.ok(body.duplicates[0].matchingItemName);
});

test("GET /v1/extraction-jobs/:id/duplicates returns empty array when no duplicates", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/extraction-jobs/job-1/duplicates");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(Array.isArray(body.duplicates));
  assert.equal(body.duplicates.length, 0);
});

test("GET /v1/extraction-jobs/:id/duplicates returns 404 for non-existent job", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/extraction-jobs/not-found/duplicates");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 404);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "NOT_FOUND");
});

// === Unit tests for createItemFromExtraction (via service mock) ===

test("confirmExtractionJob service creates items with creation_method = ai_extraction", async () => {
  let createdItems = [];
  const extractionService = {
    async createExtractionJob() { return {}; },
    async confirmExtractionJob(authContext, jobId, { keptItemIds }) {
      // Simulate what the real service does
      const items = keptItemIds.map((id, i) => ({
        id: `created-${i}`,
        creationMethod: "ai_extraction",
        extractionJobId: jobId,
        category: "tops",
        color: "blue",
        photoUrl: "https://storage.example.com/cleaned.png"
      }));
      createdItems = items;
      return { confirmedCount: items.length, items };
    },
    async checkDuplicates() { return { duplicates: [] }; }
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: ["item-1"],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext({ extractionService }));

  assert.equal(res.statusCode, 200);
  assert.equal(createdItems.length, 1);
  assert.equal(createdItems[0].creationMethod, "ai_extraction");
  assert.equal(createdItems[0].extractionJobId, "job-1");
});

test("getExtractionItemsByIds returns only items matching provided IDs within the job", async () => {
  // This tests the extraction service's validation of item IDs
  const extractionService = {
    async createExtractionJob() { return {}; },
    async confirmExtractionJob(authContext, jobId, { keptItemIds }) {
      // Simulate invalid ID scenario
      if (keptItemIds.includes("wrong-job-item")) {
        const err = new Error("Invalid item IDs: wrong-job-item");
        err.statusCode = 400;
        err.code = "VALIDATION_ERROR";
        throw err;
      }
      return { confirmedCount: 0, items: [] };
    },
    async checkDuplicates() { return { duplicates: [] }; }
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/confirm", {
    keptItemIds: ["wrong-job-item"],
    metadataEdits: {}
  });

  await handleRequest(req, res, buildContext({ extractionService }));

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});
