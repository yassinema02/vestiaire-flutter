import assert from "node:assert/strict";
import test from "node:test";
import { createExtractionService, ExtractionValidationError } from "../../../src/modules/extraction/service.js";

function createMockRepo() {
  const calls = [];
  let jobCounter = 0;
  let photoCounter = 0;

  return {
    calls,
    async createJob(authContext, { totalPhotos }) {
      calls.push({ method: "createJob", authContext, totalPhotos });
      jobCounter++;
      return {
        id: `job-${jobCounter}`,
        profileId: "profile-1",
        status: "uploading",
        totalPhotos,
        uploadedPhotos: 0,
        processedPhotos: 0,
        totalItemsFound: 0,
        errorMessage: null,
        createdAt: "2026-03-19T12:00:00.000Z",
        updatedAt: "2026-03-19T12:00:00.000Z"
      };
    },
    async getJob(authContext, jobId) {
      calls.push({ method: "getJob", authContext, jobId });
      if (jobId === "not-found") return null;
      return {
        id: jobId,
        profileId: "profile-1",
        status: "processing",
        totalPhotos: 3,
        uploadedPhotos: 3,
        processedPhotos: 0,
        totalItemsFound: 0,
        photos: []
      };
    },
    async updateJobStatus(authContext, jobId, updates) {
      calls.push({ method: "updateJobStatus", authContext, jobId, updates });
      return {
        id: jobId,
        profileId: "profile-1",
        status: updates.status ?? "uploading",
        totalPhotos: 3,
        uploadedPhotos: updates.uploadedPhotos ?? 0,
        processedPhotos: updates.processedPhotos ?? 0,
        totalItemsFound: updates.totalItemsFound ?? 0,
        errorMessage: updates.errorMessage ?? null,
        createdAt: "2026-03-19T12:00:00.000Z",
        updatedAt: "2026-03-19T12:00:00.000Z"
      };
    },
    async addJobPhoto(authContext, { jobId, photoUrl, originalFilename }) {
      calls.push({ method: "addJobPhoto", authContext, jobId, photoUrl, originalFilename });
      photoCounter++;
      return {
        id: `photo-${photoCounter}`,
        jobId,
        photoUrl,
        originalFilename: originalFilename ?? null,
        status: "uploaded",
        itemsFound: 0,
        errorMessage: null,
        createdAt: "2026-03-19T12:00:00.000Z"
      };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// === createExtractionJob tests ===

test("createExtractionJob creates job and inserts photos", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  const result = await service.createExtractionJob(testAuthContext, {
    totalPhotos: 2,
    photos: [
      { photoUrl: "https://example.com/1.jpg", originalFilename: "1.jpg" },
      { photoUrl: "https://example.com/2.jpg", originalFilename: "2.jpg" }
    ]
  });

  // Job should be created
  const createJobCalls = repo.calls.filter(c => c.method === "createJob");
  assert.equal(createJobCalls.length, 1);
  assert.equal(createJobCalls[0].totalPhotos, 2);

  // Photos should be inserted
  const addPhotoCalls = repo.calls.filter(c => c.method === "addJobPhoto");
  assert.equal(addPhotoCalls.length, 2);
  assert.equal(addPhotoCalls[0].photoUrl, "https://example.com/1.jpg");
  assert.equal(addPhotoCalls[1].photoUrl, "https://example.com/2.jpg");

  // Job status should be updated to processing
  const updateCalls = repo.calls.filter(c => c.method === "updateJobStatus");
  assert.equal(updateCalls.length, 1);
  assert.equal(updateCalls[0].updates.status, "processing");
  assert.equal(updateCalls[0].updates.uploadedPhotos, 2);

  // Result should include photos
  assert.ok(Array.isArray(result.photos));
  assert.equal(result.photos.length, 2);
  assert.equal(result.status, "processing");
});

test("createExtractionJob returns correct structure", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  const result = await service.createExtractionJob(testAuthContext, {
    totalPhotos: 1,
    photos: [{ photoUrl: "https://example.com/1.jpg" }]
  });

  assert.ok(result.id);
  assert.ok(result.status);
  assert.ok(result.photos);
  assert.equal(result.photos[0].photoUrl, "https://example.com/1.jpg");
});

// === Validation tests ===

test("createExtractionJob rejects totalPhotos < 1", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  await assert.rejects(
    () => service.createExtractionJob(testAuthContext, {
      totalPhotos: 0,
      photos: []
    }),
    (err) => {
      assert.ok(err instanceof ExtractionValidationError);
      assert.equal(err.statusCode, 400);
      return true;
    }
  );
});

test("createExtractionJob rejects totalPhotos > 50", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  const photos = Array.from({ length: 51 }, (_, i) => ({
    photoUrl: `https://example.com/${i}.jpg`
  }));

  await assert.rejects(
    () => service.createExtractionJob(testAuthContext, {
      totalPhotos: 51,
      photos
    }),
    (err) => {
      assert.ok(err instanceof ExtractionValidationError);
      return true;
    }
  );
});

test("createExtractionJob rejects when totalPhotos does not match photos length", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  await assert.rejects(
    () => service.createExtractionJob(testAuthContext, {
      totalPhotos: 3,
      photos: [
        { photoUrl: "https://example.com/1.jpg" },
        { photoUrl: "https://example.com/2.jpg" }
      ]
    }),
    (err) => {
      assert.ok(err instanceof ExtractionValidationError);
      assert.ok(err.message.includes("must match"));
      return true;
    }
  );
});

test("createExtractionJob rejects empty photos array", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  await assert.rejects(
    () => service.createExtractionJob(testAuthContext, {
      totalPhotos: 1,
      photos: []
    }),
    (err) => {
      assert.ok(err instanceof ExtractionValidationError);
      return true;
    }
  );
});

test("createExtractionJob rejects photo without photoUrl", async () => {
  const repo = createMockRepo();
  const service = createExtractionService({ extractionRepo: repo });

  await assert.rejects(
    () => service.createExtractionJob(testAuthContext, {
      totalPhotos: 1,
      photos: [{ originalFilename: "test.jpg" }]
    }),
    (err) => {
      assert.ok(err instanceof ExtractionValidationError);
      assert.ok(err.message.includes("photoUrl"));
      return true;
    }
  );
});

// === Constructor validation ===

test("createExtractionService throws when extractionRepo is missing", () => {
  assert.throws(
    () => createExtractionService({}),
    { message: "extractionRepo is required" }
  );
});
