import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { createExtractionProcessingService } from "../../../src/modules/extraction/processing-service.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_PHOTO_PATH = path.resolve(__dirname, "../../fixtures/test-photo.jpg");

// === Helpers ===

function createMockGeminiClient({ detectionResponse, bgRemovalResponse, shouldThrow } = {}) {
  const calls = [];

  const defaultDetectionResponse = {
    response: {
      candidates: [{
        content: {
          parts: [{
            text: JSON.stringify({
              items: [
                {
                  description: "blue denim jacket",
                  confidence: 0.95,
                  category: "outerwear",
                  color: "blue",
                  secondary_colors: [],
                  pattern: "solid",
                  material: "denim",
                  style: "casual",
                  season: ["fall", "spring"],
                  occasion: ["everyday"]
                }
              ]
            })
          }]
        }
      }],
      usageMetadata: {
        promptTokenCount: 100,
        candidatesTokenCount: 50
      }
    }
  };

  const defaultBgRemovalResponse = {
    response: {
      candidates: [{
        content: {
          parts: [{
            inlineData: {
              data: Buffer.from("fake-image-data").toString("base64"),
              mimeType: "image/png"
            }
          }]
        }
      }],
      usageMetadata: {
        promptTokenCount: 80,
        candidatesTokenCount: 200
      }
    }
  };

  let callCount = 0;

  return {
    calls,
    isAvailable() { return true; },
    async getGenerativeModel(modelName) {
      return {
        async generateContent(request) {
          calls.push({ modelName, request });
          callCount++;

          if (shouldThrow && shouldThrow.onCallNumber === callCount) {
            throw new Error(shouldThrow.message || "Gemini error");
          }

          // Determine if this is a detection call or bg removal call based on the prompt
          const textPart = request.contents[0].parts.find(p => p.text);
          const isDetection = textPart?.text?.includes("identify all individual clothing items");

          if (isDetection) {
            return detectionResponse ?? defaultDetectionResponse;
          } else {
            return bgRemovalResponse ?? defaultBgRemovalResponse;
          }
        }
      };
    }
  };
}

function createMockExtractionRepo({
  job,
  updateJobStatusCalls = [],
  updatePhotoStatusCalls = [],
  addJobItemCalls = [],
  getJobCallCount = { count: 0 }
} = {}) {
  const defaultJob = {
    id: "job-1",
    profileId: "profile-1",
    status: "processing",
    totalPhotos: 1,
    uploadedPhotos: 1,
    processedPhotos: 0,
    totalItemsFound: 0,
    photos: [
      { id: "photo-1", jobId: "job-1", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 }
    ],
    items: []
  };

  const theJob = job ?? defaultJob;

  return {
    updateJobStatusCalls,
    updatePhotoStatusCalls,
    addJobItemCalls,
    async getJob(authContext, jobId) {
      getJobCallCount.count++;
      // On subsequent calls (after processing), return updated photos with completed status
      if (getJobCallCount.count > 1) {
        return {
          ...theJob,
          photos: theJob.photos.map(p => ({
            ...p,
            status: p._finalStatus || "completed"
          }))
        };
      }
      return theJob;
    },
    async updateJobStatus(authContext, jobId, updates) {
      updateJobStatusCalls.push({ jobId, updates });
      return { ...theJob, ...updates };
    },
    async updatePhotoStatus(authContext, photoId, updates) {
      updatePhotoStatusCalls.push({ photoId, updates });
      return { id: photoId, ...updates };
    },
    async addJobItem(authContext, item) {
      addJobItemCalls.push(item);
      return { id: "item-" + addJobItemCalls.length, ...item };
    }
  };
}

function createMockAiUsageLogRepo() {
  const calls = [];
  return {
    calls,
    async logUsage(authContext, params) {
      calls.push(params);
    }
  };
}

function createMockUploadService() {
  return {
    publicBaseUrl: "http://localhost:8080"
  };
}

const authContext = { userId: "firebase-user-123" };

// === processExtractionJob tests ===

test("processExtractionJob processes all photos and updates job status to completed", async () => {
  const updateJobStatusCalls = [];
  const updatePhotoStatusCalls = [];
  const addJobItemCalls = [];
  const getJobCallCount = { count: 0 };

  const repo = createMockExtractionRepo({
    updateJobStatusCalls,
    updatePhotoStatusCalls,
    addJobItemCalls,
    getJobCallCount
  });

  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  // Photo should be marked completed
  assert.equal(updatePhotoStatusCalls.length, 1);
  assert.equal(updatePhotoStatusCalls[0].photoId, "photo-1");
  assert.equal(updatePhotoStatusCalls[0].updates.status, "completed");
  assert.equal(updatePhotoStatusCalls[0].updates.itemsFound, 1);

  // Should have inserted 1 item
  assert.equal(addJobItemCalls.length, 1);
  assert.equal(addJobItemCalls[0].jobId, "job-1");
  assert.equal(addJobItemCalls[0].photoId, "photo-1");
  assert.equal(addJobItemCalls[0].itemIndex, 0);
  assert.equal(addJobItemCalls[0].category, "outerwear");
  assert.equal(addJobItemCalls[0].color, "blue");

  // Final job status should be completed
  const finalUpdate = updateJobStatusCalls[updateJobStatusCalls.length - 1];
  assert.equal(finalUpdate.updates.status, "completed");
});

test("multi-item detection: 3 items creates 3 extraction_job_items records", async () => {
  const addJobItemCalls = [];
  const repo = createMockExtractionRepo({ addJobItemCalls, getJobCallCount: { count: 0 } });

  const threeItemsResponse = {
    response: {
      candidates: [{
        content: {
          parts: [{
            text: JSON.stringify({
              items: [
                { description: "blue shirt", confidence: 0.9, category: "tops", color: "blue", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"] },
                { description: "black pants", confidence: 0.85, category: "bottoms", color: "black", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"] },
                { description: "white sneakers", confidence: 0.8, category: "shoes", color: "white", secondary_colors: [], pattern: "solid", material: "synthetic-blend", style: "sporty", season: ["all"], occasion: ["everyday", "sport"] }
              ]
            })
          }]
        }
      }],
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 }
    }
  };

  const geminiClient = createMockGeminiClient({ detectionResponse: threeItemsResponse });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  assert.equal(addJobItemCalls.length, 3);
  assert.equal(addJobItemCalls[0].itemIndex, 0);
  assert.equal(addJobItemCalls[0].category, "tops");
  assert.equal(addJobItemCalls[1].itemIndex, 1);
  assert.equal(addJobItemCalls[1].category, "bottoms");
  assert.equal(addJobItemCalls[2].itemIndex, 2);
  assert.equal(addJobItemCalls[2].category, "shoes");
});

test("single-item detection: 1 item creates 1 record", async () => {
  const addJobItemCalls = [];
  const repo = createMockExtractionRepo({ addJobItemCalls, getJobCallCount: { count: 0 } });

  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  assert.equal(addJobItemCalls.length, 1);
});

test("zero-item detection: photo marked completed with items_found = 0", async () => {
  const updatePhotoStatusCalls = [];
  const addJobItemCalls = [];
  const repo = createMockExtractionRepo({ updatePhotoStatusCalls, addJobItemCalls, getJobCallCount: { count: 0 } });

  const emptyResponse = {
    response: {
      candidates: [{
        content: {
          parts: [{
            text: JSON.stringify({ items: [] })
          }]
        }
      }],
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 10 }
    }
  };

  const geminiClient = createMockGeminiClient({ detectionResponse: emptyResponse });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  assert.equal(addJobItemCalls.length, 0);
  assert.equal(updatePhotoStatusCalls.length, 1);
  assert.equal(updatePhotoStatusCalls[0].updates.status, "completed");
  assert.equal(updatePhotoStatusCalls[0].updates.itemsFound, 0);
});

test("photo failure: one photo fails, remaining photos still process", async () => {
  const updatePhotoStatusCalls = [];
  const addJobItemCalls = [];
  const updateJobStatusCalls = [];
  const getJobCallCount = { count: 0 };

  const twoPhotoJob = {
    id: "job-2",
    profileId: "profile-1",
    status: "processing",
    totalPhotos: 2,
    uploadedPhotos: 2,
    processedPhotos: 0,
    totalItemsFound: 0,
    photos: [
      { id: "photo-1", jobId: "job-2", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 },
      { id: "photo-2", jobId: "job-2", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 }
    ],
    items: []
  };

  const repo = createMockExtractionRepo({
    job: twoPhotoJob,
    updateJobStatusCalls,
    updatePhotoStatusCalls,
    addJobItemCalls,
    getJobCallCount
  });

  // Override getJob for the re-fetch to show partial status
  const origGetJob = repo.getJob;
  repo.getJob = async function(ac, jid) {
    getJobCallCount.count++;
    if (getJobCallCount.count > 1) {
      return {
        ...twoPhotoJob,
        photos: [
          { ...twoPhotoJob.photos[0], status: "failed" },
          { ...twoPhotoJob.photos[1], status: "completed" }
        ]
      };
    }
    return twoPhotoJob;
  };

  // First call (detection for photo-1) will throw
  const geminiClient = createMockGeminiClient({ shouldThrow: { onCallNumber: 1, message: "Gemini timeout" } });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-2");

  // First photo should be marked as failed
  const failedPhoto = updatePhotoStatusCalls.find(c => c.photoId === "photo-1");
  assert.ok(failedPhoto);
  assert.equal(failedPhoto.updates.status, "failed");
  assert.ok(failedPhoto.updates.errorMessage);

  // Second photo should be marked as completed
  const completedPhoto = updatePhotoStatusCalls.find(c => c.photoId === "photo-2");
  assert.ok(completedPhoto);
  assert.equal(completedPhoto.updates.status, "completed");

  // Final status should be partial
  const finalUpdate = updateJobStatusCalls[updateJobStatusCalls.length - 1];
  assert.equal(finalUpdate.updates.status, "partial");
});

test("all photos fail: job status is failed", async () => {
  const updateJobStatusCalls = [];
  const updatePhotoStatusCalls = [];
  const getJobCallCount = { count: 0 };

  const job = {
    id: "job-3",
    profileId: "profile-1",
    status: "processing",
    totalPhotos: 1,
    uploadedPhotos: 1,
    processedPhotos: 0,
    totalItemsFound: 0,
    photos: [
      { id: "photo-1", jobId: "job-3", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 }
    ],
    items: []
  };

  const repo = createMockExtractionRepo({
    job,
    updateJobStatusCalls,
    updatePhotoStatusCalls,
    getJobCallCount
  });

  // Override getJob for re-fetch
  repo.getJob = async function(ac, jid) {
    getJobCallCount.count++;
    if (getJobCallCount.count > 1) {
      return {
        ...job,
        photos: [{ ...job.photos[0], status: "failed" }]
      };
    }
    return job;
  };

  const geminiClient = createMockGeminiClient({ shouldThrow: { onCallNumber: 1, message: "Gemini error" } });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-3");

  const finalUpdate = updateJobStatusCalls[updateJobStatusCalls.length - 1];
  assert.equal(finalUpdate.updates.status, "failed");
});

test("partial failure: some photos succeed, some fail -> status partial", async () => {
  const updateJobStatusCalls = [];
  const updatePhotoStatusCalls = [];
  const getJobCallCount = { count: 0 };

  const job = {
    id: "job-4",
    profileId: "profile-1",
    status: "processing",
    totalPhotos: 2,
    uploadedPhotos: 2,
    processedPhotos: 0,
    totalItemsFound: 0,
    photos: [
      { id: "photo-1", jobId: "job-4", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 },
      { id: "photo-2", jobId: "job-4", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 }
    ],
    items: []
  };

  const repo = createMockExtractionRepo({
    job,
    updateJobStatusCalls,
    updatePhotoStatusCalls,
    getJobCallCount
  });

  repo.getJob = async function(ac, jid) {
    getJobCallCount.count++;
    if (getJobCallCount.count > 1) {
      return {
        ...job,
        photos: [
          { ...job.photos[0], status: "failed" },
          { ...job.photos[1], status: "completed" }
        ]
      };
    }
    return job;
  };

  // First detection call fails
  const geminiClient = createMockGeminiClient({ shouldThrow: { onCallNumber: 1, message: "Network error" } });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-4");

  const finalUpdate = updateJobStatusCalls[updateJobStatusCalls.length - 1];
  assert.equal(finalUpdate.updates.status, "partial");
});

test("taxonomy validation: extracted item metadata is validated with safe defaults", async () => {
  const addJobItemCalls = [];
  const repo = createMockExtractionRepo({ addJobItemCalls, getJobCallCount: { count: 0 } });

  // Response with invalid taxonomy values
  const invalidTaxonomyResponse = {
    response: {
      candidates: [{
        content: {
          parts: [{
            text: JSON.stringify({
              items: [
                {
                  description: "some clothing",
                  confidence: 0.7,
                  category: "INVALID_CATEGORY",
                  color: "rainbow",
                  secondary_colors: ["invalid-color"],
                  pattern: "zigzag",
                  material: "unobtanium",
                  style: "nonexistent",
                  season: ["decade"],
                  occasion: ["apocalypse"]
                }
              ]
            })
          }]
        }
      }],
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 }
    }
  };

  const geminiClient = createMockGeminiClient({ detectionResponse: invalidTaxonomyResponse });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  assert.equal(addJobItemCalls.length, 1);
  // Should use safe defaults for invalid values
  assert.equal(addJobItemCalls[0].category, "other");
  assert.equal(addJobItemCalls[0].color, "unknown");
  assert.equal(addJobItemCalls[0].pattern, "solid");
  assert.equal(addJobItemCalls[0].material, "unknown");
  assert.equal(addJobItemCalls[0].style, "casual");
  assert.deepEqual(addJobItemCalls[0].season, ["all"]);
  assert.deepEqual(addJobItemCalls[0].occasion, ["everyday"]);
});

test("AI usage logging: correct feature names logged", async () => {
  const repo = createMockExtractionRepo({ getJobCallCount: { count: 0 } });
  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  // Should have logged: detection, bg_removal, categorization
  const features = aiUsageLogRepo.calls.map(c => c.feature);
  assert.ok(features.includes("extraction_detection"), "Should log extraction_detection");
  assert.ok(features.includes("extraction_bg_removal"), "Should log extraction_bg_removal");
  assert.ok(features.includes("extraction_categorization"), "Should log extraction_categorization");
});

test("background removal is called for each detected item", async () => {
  const repo = createMockExtractionRepo({ getJobCallCount: { count: 0 } });

  const twoItemsResponse = {
    response: {
      candidates: [{
        content: {
          parts: [{
            text: JSON.stringify({
              items: [
                { description: "shirt", confidence: 0.9, category: "tops", color: "blue", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"] },
                { description: "pants", confidence: 0.85, category: "bottoms", color: "black", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"] }
              ]
            })
          }]
        }
      }],
      usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 }
    }
  };

  const geminiClient = createMockGeminiClient({ detectionResponse: twoItemsResponse });
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-1");

  // Total Gemini calls: 1 detection + 2 bg removals = 3
  assert.equal(geminiClient.calls.length, 3);

  // Verify bg removal calls contain isolation prompts
  const bgCalls = geminiClient.calls.filter(c => {
    const textPart = c.request.contents[0].parts.find(p => p.text);
    return textPart && !textPart.text.includes("identify all individual clothing items");
  });
  assert.equal(bgCalls.length, 2);
});

test("processedPhotos and totalItemsFound counters update correctly", async () => {
  const updateJobStatusCalls = [];
  const getJobCallCount = { count: 0 };

  const job = {
    id: "job-5",
    profileId: "profile-1",
    status: "processing",
    totalPhotos: 2,
    uploadedPhotos: 2,
    processedPhotos: 0,
    totalItemsFound: 0,
    photos: [
      { id: "photo-1", jobId: "job-5", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 },
      { id: "photo-2", jobId: "job-5", photoUrl: TEST_PHOTO_PATH, status: "uploaded", itemsFound: 0 }
    ],
    items: []
  };

  const repo = createMockExtractionRepo({ job, updateJobStatusCalls, getJobCallCount });
  repo.getJob = async function(ac, jid) {
    getJobCallCount.count++;
    if (getJobCallCount.count > 1) {
      return { ...job, photos: job.photos.map(p => ({ ...p, status: "completed" })) };
    }
    return job;
  };

  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await service.processExtractionJob(authContext, "job-5");

  // After first photo: processedPhotos=1, totalItemsFound=1
  assert.equal(updateJobStatusCalls[0].updates.processedPhotos, 1);
  assert.equal(updateJobStatusCalls[0].updates.totalItemsFound, 1);

  // After second photo: processedPhotos=2, totalItemsFound=2
  assert.equal(updateJobStatusCalls[1].updates.processedPhotos, 2);
  assert.equal(updateJobStatusCalls[1].updates.totalItemsFound, 2);
});

test("throws when job not found", async () => {
  const repo = createMockExtractionRepo({ getJobCallCount: { count: 0 } });
  repo.getJob = async () => null;

  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await assert.rejects(
    () => service.processExtractionJob(authContext, "nonexistent"),
    { message: /not found/ }
  );
});

test("throws when job status is not processing", async () => {
  const repo = createMockExtractionRepo({
    job: { id: "job-1", status: "completed", photos: [], items: [] },
    getJobCallCount: { count: 0 }
  });

  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();

  const service = createExtractionProcessingService({
    extractionRepo: repo,
    geminiClient,
    backgroundRemovalService: {},
    aiUsageLogRepo,
    uploadService: createMockUploadService()
  });

  await assert.rejects(
    () => service.processExtractionJob(authContext, "job-1"),
    { message: /not in 'processing' status/ }
  );
});

// === Constructor validation ===

test("createExtractionProcessingService throws when extractionRepo is missing", () => {
  assert.throws(
    () => createExtractionProcessingService({ geminiClient: {}, aiUsageLogRepo: {} }),
    { message: "extractionRepo is required" }
  );
});

test("createExtractionProcessingService throws when geminiClient is missing", () => {
  assert.throws(
    () => createExtractionProcessingService({ extractionRepo: {}, aiUsageLogRepo: {} }),
    { message: "geminiClient is required" }
  );
});

test("createExtractionProcessingService throws when aiUsageLogRepo is missing", () => {
  assert.throws(
    () => createExtractionProcessingService({ extractionRepo: {}, geminiClient: {} }),
    { message: "aiUsageLogRepo is required" }
  );
});
