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

function buildContext({ extractionService, extractionRepo, extractionProcessingService, uploadService } = {}) {
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
    itemService: {
      async createItemForUser() { return { item: {} }; },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser() { return { deleted: true }; }
    },
    uploadService: uploadService ?? {
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
      }
    },
    extractionRepo: extractionRepo ?? {
      async getJob(authContext, jobId) {
        if (jobId === "not-found") return null;
        return {
          id: jobId,
          profileId: "profile-1",
          status: "processing",
          totalPhotos: 2,
          uploadedPhotos: 2,
          processedPhotos: 0,
          totalItemsFound: 0,
          photos: [
            { id: "photo-1", jobId, photoUrl: "https://example.com/1.jpg", status: "uploaded" }
          ],
          items: [
            {
              id: "item-1",
              jobId,
              photoId: "photo-1",
              itemIndex: 0,
              photoUrl: "https://storage.example.com/cleaned.png",
              originalCropUrl: null,
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

// === POST /v1/extraction-jobs tests ===

test("POST /v1/extraction-jobs creates a job and returns 201", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs", {
    totalPhotos: 2,
    photos: [
      { photoUrl: "https://example.com/1.jpg", originalFilename: "1.jpg" },
      { photoUrl: "https://example.com/2.jpg", originalFilename: "2.jpg" }
    ]
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  const body = JSON.parse(res.body);
  assert.ok(body.job);
  assert.equal(body.job.id, "job-1");
  assert.equal(body.job.status, "processing");
  assert.equal(body.job.totalPhotos, 2);
  assert.ok(Array.isArray(body.job.photos));
  assert.equal(body.job.photos.length, 2);
});

test("POST /v1/extraction-jobs returns 400 for validation errors", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs", {
    totalPhotos: 0,
    photos: []
  });

  const extractionService = {
    async createExtractionJob() {
      const err = new Error("totalPhotos must be between 1 and 50");
      err.statusCode = 400;
      err.code = "VALIDATION_ERROR";
      throw err;
    }
  };

  await handleRequest(req, res, buildContext({ extractionService }));

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});

test("POST /v1/extraction-jobs returns 401 for unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createUnauthRequest("POST", "/v1/extraction-jobs", {
    totalPhotos: 1,
    photos: [{ photoUrl: "https://example.com/1.jpg" }]
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

test("POST /v1/extraction-jobs auto-triggers processing", async () => {
  let processingTriggered = false;
  let triggeredJobId = null;

  const extractionProcessingService = {
    async processExtractionJob(authContext, jobId) {
      processingTriggered = true;
      triggeredJobId = jobId;
    }
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs", {
    totalPhotos: 1,
    photos: [{ photoUrl: "https://example.com/1.jpg" }]
  });

  await handleRequest(req, res, buildContext({ extractionProcessingService }));

  assert.equal(res.statusCode, 201);
  // Give the fire-and-forget promise a tick to resolve
  await new Promise(r => setTimeout(r, 10));
  assert.ok(processingTriggered, "Processing should be triggered after job creation");
  assert.equal(triggeredJobId, "job-1");
});

// === GET /v1/extraction-jobs/:id tests ===

test("GET /v1/extraction-jobs/:id returns job with photos", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/extraction-jobs/job-1");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(body.job);
  assert.equal(body.job.id, "job-1");
  assert.ok(Array.isArray(body.job.photos));
});

test("GET /v1/extraction-jobs/:id includes items array with all metadata", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/extraction-jobs/job-1");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(body.job);
  assert.ok(Array.isArray(body.job.items), "Response should include items array");
  assert.equal(body.job.items.length, 1);

  const item = body.job.items[0];
  assert.equal(item.id, "item-1");
  assert.equal(item.photoId, "photo-1");
  assert.equal(item.itemIndex, 0);
  assert.equal(item.category, "tops");
  assert.equal(item.color, "blue");
  assert.deepEqual(item.secondaryColors, []);
  assert.equal(item.pattern, "solid");
  assert.equal(item.material, "cotton");
  assert.equal(item.style, "casual");
  assert.deepEqual(item.season, ["all"]);
  assert.deepEqual(item.occasion, ["everyday"]);
  assert.equal(item.bgRemovalStatus, "completed");
  assert.equal(item.categorizationStatus, "completed");
  assert.equal(item.detectionConfidence, 0.95);
  assert.ok(item.photoUrl);
});

test("GET /v1/extraction-jobs/:id returns 404 for non-existent job", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("GET", "/v1/extraction-jobs/not-found");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 404);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "NOT_FOUND");
});

test("GET /v1/extraction-jobs/:id returns 401 for unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createUnauthRequest("GET", "/v1/extraction-jobs/job-1");

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

// === POST /v1/extraction-jobs/:id/process tests ===

test("POST /v1/extraction-jobs/:id/process returns 202 and triggers processing", async () => {
  let processingTriggered = false;

  const extractionProcessingService = {
    async processExtractionJob() {
      processingTriggered = true;
    }
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/process");

  await handleRequest(req, res, buildContext({ extractionProcessingService }));

  assert.equal(res.statusCode, 202);
  const body = JSON.parse(res.body);
  assert.equal(body.status, "processing");

  await new Promise(r => setTimeout(r, 10));
  assert.ok(processingTriggered);
});

test("POST /v1/extraction-jobs/:id/process returns 404 for non-existent job", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/not-found/process");

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 404);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "NOT_FOUND");
});

test("POST /v1/extraction-jobs/:id/process returns 400 for non-processing job", async () => {
  const extractionRepo = {
    async getJob(authContext, jobId) {
      return {
        id: jobId,
        status: "completed",
        photos: [],
        items: []
      };
    }
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/extraction-jobs/job-1/process");

  await handleRequest(req, res, buildContext({ extractionRepo }));

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "INVALID_JOB_STATUS");
});

test("POST /v1/extraction-jobs/:id/process returns 401 for unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createUnauthRequest("POST", "/v1/extraction-jobs/job-1/process");

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

// === POST /v1/uploads/signed-urls tests ===

test("POST /v1/uploads/signed-urls returns correct number of URLs", async () => {
  let callCount = 0;
  const uploadService = {
    async generateSignedUploadUrl(authContext, { purpose }) {
      callCount++;
      return {
        uploadUrl: `https://upload.example.com/upload-${callCount}`,
        publicUrl: `https://storage.example.com/photo-${callCount}.jpg`
      };
    }
  };

  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/uploads/signed-urls", {
    purposes: [
      { purpose: "extraction_photo", index: 0 },
      { purpose: "extraction_photo", index: 1 },
      { purpose: "extraction_photo", index: 2 }
    ],
    count: 3
  });

  await handleRequest(req, res, buildContext({ uploadService }));

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(Array.isArray(body.urls));
  assert.equal(body.urls.length, 3);
  assert.equal(body.urls[0].index, 0);
  assert.ok(body.urls[0].uploadUrl);
  assert.ok(body.urls[0].publicUrl);
});

test("POST /v1/uploads/signed-urls validates count (too low)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/uploads/signed-urls", {
    purposes: [],
    count: 0
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});

test("POST /v1/uploads/signed-urls validates count (too high)", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/uploads/signed-urls", {
    purposes: Array.from({ length: 51 }, (_, i) => ({ purpose: "extraction_photo", index: i })),
    count: 51
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});

test("POST /v1/uploads/signed-urls validates purposes array length matches count", async () => {
  const res = createResponseCapture();
  const req = createJsonRequest("POST", "/v1/uploads/signed-urls", {
    purposes: [{ purpose: "extraction_photo", index: 0 }],
    count: 3
  });

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 400);
  const body = JSON.parse(res.body);
  assert.equal(body.code, "VALIDATION_ERROR");
});

test("POST /v1/uploads/signed-urls returns 401 for unauthenticated", async () => {
  const res = createResponseCapture();
  const req = createUnauthRequest("POST", "/v1/uploads/signed-urls", {
    purposes: [{ purpose: "extraction_photo", index: 0 }],
    count: 1
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
