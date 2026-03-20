import assert from "node:assert/strict";
import test from "node:test";
import { createExtractionRepository } from "../../../src/modules/extraction/repository.js";

// === Mock pool helper ===

function createMockPool({
  profileRows = [{ id: "profile-1" }],
  insertJobRows = [{ id: "job-1", profile_id: "profile-1", status: "uploading", total_photos: 5, uploaded_photos: 0, processed_photos: 0, total_items_found: 0, error_message: null, created_at: new Date("2026-03-19T12:00:00Z"), updated_at: new Date("2026-03-19T12:00:00Z") }],
  selectJobRows = null,
  updateJobRows = null,
  insertPhotoRows = [{ id: "photo-1", job_id: "job-1", photo_url: "https://example.com/photo.jpg", original_filename: "img.jpg", status: "uploaded", items_found: 0, error_message: null, created_at: new Date("2026-03-19T12:00:00Z") }],
  selectPhotosRows = [],
  selectItemsRows = [],
  insertItemRows = [{ id: "item-1", job_id: "job-1", photo_id: "photo-1", item_index: 0, photo_url: "https://storage.example.com/cleaned.png", original_crop_url: null, category: "tops", color: "blue", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"], bg_removal_status: "completed", categorization_status: "completed", detection_confidence: 0.95, created_at: new Date("2026-03-19T12:00:00Z") }],
  updatePhotoRows = [{ id: "photo-1", job_id: "job-1", photo_url: "https://example.com/photo.jpg", original_filename: "img.jpg", status: "completed", items_found: 1, error_message: null, created_at: new Date("2026-03-19T12:00:00Z") }],
} = {}) {
  const queries = [];
  const mockClient = {
    query(sql, params) {
      queries.push({ sql, params });

      if (sql === "begin" || sql === "commit" || sql === "rollback") {
        return { rows: [] };
      }
      if (sql.includes("set_config")) {
        return { rows: [] };
      }
      // Order matters: more specific matches first
      if (sql.includes("update app_public.extraction_job_photos")) {
        return { rows: updatePhotoRows };
      }
      if (sql.includes("update app_public.wardrobe_extraction_jobs")) {
        return { rows: updateJobRows ?? insertJobRows.map(r => ({ ...r, status: "processing" })) };
      }
      if (sql.includes("insert into app_public.wardrobe_extraction_jobs")) {
        return { rows: insertJobRows };
      }
      if (sql.includes("insert into app_public.extraction_job_photos")) {
        return { rows: insertPhotoRows };
      }
      if (sql.includes("insert into app_public.extraction_job_items")) {
        return { rows: insertItemRows };
      }
      if (sql.includes("select * from app_public.extraction_job_items")) {
        return { rows: selectItemsRows };
      }
      if (sql.includes("select * from app_public.extraction_job_photos")) {
        return { rows: selectPhotosRows };
      }
      if (sql.includes("select wej.*")) {
        return { rows: selectJobRows ?? insertJobRows };
      }
      if (sql.includes("select id from app_public.profiles")) {
        return { rows: profileRows };
      }
      return { rows: [] };
    },
    release() {}
  };

  return {
    queries,
    mockClient,
    pool: {
      connect() {
        return Promise.resolve(mockClient);
      }
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// === createJob tests ===

test("createJob creates a job and returns mapped result", async () => {
  const { pool } = createMockPool();
  const repo = createExtractionRepository({ pool });

  const result = await repo.createJob(testAuthContext, { totalPhotos: 5 });

  assert.equal(result.id, "job-1");
  assert.equal(result.profileId, "profile-1");
  assert.equal(result.status, "uploading");
  assert.equal(result.totalPhotos, 5);
  assert.equal(result.uploadedPhotos, 0);
});

test("createJob throws when profile not found", async () => {
  const { pool } = createMockPool({ profileRows: [] });
  const repo = createExtractionRepository({ pool });

  await assert.rejects(
    () => repo.createJob(testAuthContext, { totalPhotos: 5 }),
    { message: "Profile not found for authenticated user" }
  );
});

test("createJob sets RLS context", async () => {
  const { pool, queries } = createMockPool();
  const repo = createExtractionRepository({ pool });

  await repo.createJob(testAuthContext, { totalPhotos: 5 });

  const setConfigQuery = queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.deepEqual(setConfigQuery.params, ["firebase-user-123"]);
});

// === getJob tests ===

test("getJob returns job with photos and items when found", async () => {
  const selectPhotosRows = [
    { id: "photo-1", job_id: "job-1", photo_url: "https://example.com/1.jpg", original_filename: "1.jpg", status: "uploaded", items_found: 0, error_message: null, created_at: new Date("2026-03-19T12:00:00Z") },
  ];
  const selectItemsRows = [
    { id: "item-1", job_id: "job-1", photo_id: "photo-1", item_index: 0, photo_url: "https://storage.example.com/cleaned.png", original_crop_url: null, category: "tops", color: "blue", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"], bg_removal_status: "completed", categorization_status: "completed", detection_confidence: 0.95, created_at: new Date("2026-03-19T12:00:00Z") },
  ];
  const { pool } = createMockPool({ selectPhotosRows, selectItemsRows });
  const repo = createExtractionRepository({ pool });

  const result = await repo.getJob(testAuthContext, "job-1");

  assert.ok(result);
  assert.equal(result.id, "job-1");
  assert.ok(Array.isArray(result.photos));
  assert.equal(result.photos.length, 1);
  assert.equal(result.photos[0].photoUrl, "https://example.com/1.jpg");
  assert.ok(Array.isArray(result.items));
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].category, "tops");
  assert.equal(result.items[0].detectionConfidence, 0.95);
});

test("getJob returns null when job not found", async () => {
  const { pool } = createMockPool({ selectJobRows: [] });
  const repo = createExtractionRepository({ pool });

  const result = await repo.getJob(testAuthContext, "nonexistent");

  assert.equal(result, null);
});

// === updateJobStatus tests ===

test("updateJobStatus updates specified fields", async () => {
  const updatedRow = {
    id: "job-1", profile_id: "profile-1", status: "processing",
    total_photos: 5, uploaded_photos: 5, processed_photos: 0,
    total_items_found: 0, error_message: null,
    created_at: new Date("2026-03-19T12:00:00Z"),
    updated_at: new Date("2026-03-19T12:00:00Z")
  };
  const { pool, queries } = createMockPool({ updateJobRows: [updatedRow] });
  const repo = createExtractionRepository({ pool });

  const result = await repo.updateJobStatus(testAuthContext, "job-1", {
    status: "processing",
    uploadedPhotos: 5
  });

  assert.equal(result.status, "processing");
  assert.equal(result.uploadedPhotos, 5);

  // Verify the update query was called
  const updateQuery = queries.find(q => q.sql.includes("update app_public.wardrobe_extraction_jobs"));
  assert.ok(updateQuery);
});

test("updateJobStatus returns null when job not found (RLS blocked)", async () => {
  const { pool } = createMockPool({ updateJobRows: [] });
  const repo = createExtractionRepository({ pool });

  const result = await repo.updateJobStatus(testAuthContext, "nonexistent", {
    status: "failed"
  });

  assert.equal(result, null);
});

// === addJobPhoto tests ===

test("addJobPhoto inserts a photo record", async () => {
  const { pool } = createMockPool();
  const repo = createExtractionRepository({ pool });

  const result = await repo.addJobPhoto(testAuthContext, {
    jobId: "job-1",
    photoUrl: "https://example.com/photo.jpg",
    originalFilename: "img.jpg"
  });

  assert.equal(result.id, "photo-1");
  assert.equal(result.jobId, "job-1");
  assert.equal(result.photoUrl, "https://example.com/photo.jpg");
  assert.equal(result.originalFilename, "img.jpg");
  assert.equal(result.status, "uploaded");
});

test("addJobPhoto handles null originalFilename", async () => {
  const photoRow = { id: "photo-2", job_id: "job-1", photo_url: "https://example.com/photo2.jpg", original_filename: null, status: "uploaded", items_found: 0, error_message: null, created_at: new Date("2026-03-19T12:00:00Z") };
  const { pool } = createMockPool({ insertPhotoRows: [photoRow] });
  const repo = createExtractionRepository({ pool });

  const result = await repo.addJobPhoto(testAuthContext, {
    jobId: "job-1",
    photoUrl: "https://example.com/photo2.jpg"
  });

  assert.equal(result.originalFilename, null);
});

// === addJobItem tests ===

test("addJobItem inserts an item record and returns mapped result", async () => {
  const { pool, queries } = createMockPool();
  const repo = createExtractionRepository({ pool });

  const result = await repo.addJobItem(testAuthContext, {
    jobId: "job-1",
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
    detectionConfidence: 0.95
  });

  assert.equal(result.id, "item-1");
  assert.equal(result.jobId, "job-1");
  assert.equal(result.photoId, "photo-1");
  assert.equal(result.itemIndex, 0);
  assert.equal(result.category, "tops");
  assert.equal(result.color, "blue");
  assert.equal(result.bgRemovalStatus, "completed");
  assert.equal(result.categorizationStatus, "completed");
  assert.equal(result.detectionConfidence, 0.95);

  // Verify the insert query was called
  const insertQuery = queries.find(q => q.sql.includes("insert into app_public.extraction_job_items"));
  assert.ok(insertQuery);
});

// === getJobItems tests ===

test("getJobItems returns items for a job ordered by photo_id and item_index", async () => {
  const selectItemsRows = [
    { id: "item-1", job_id: "job-1", photo_id: "photo-1", item_index: 0, photo_url: "https://storage.example.com/cleaned1.png", original_crop_url: null, category: "tops", color: "blue", secondary_colors: [], pattern: "solid", material: "cotton", style: "casual", season: ["all"], occasion: ["everyday"], bg_removal_status: "completed", categorization_status: "completed", detection_confidence: 0.95, created_at: new Date("2026-03-19T12:00:00Z") },
    { id: "item-2", job_id: "job-1", photo_id: "photo-1", item_index: 1, photo_url: "https://storage.example.com/cleaned2.png", original_crop_url: null, category: "bottoms", color: "black", secondary_colors: [], pattern: "solid", material: "denim", style: "casual", season: ["all"], occasion: ["everyday"], bg_removal_status: "completed", categorization_status: "completed", detection_confidence: 0.88, created_at: new Date("2026-03-19T12:00:00Z") },
  ];
  const { pool } = createMockPool({ selectItemsRows });
  const repo = createExtractionRepository({ pool });

  const result = await repo.getJobItems(testAuthContext, "job-1");

  assert.ok(Array.isArray(result));
  assert.equal(result.length, 2);
  assert.equal(result[0].category, "tops");
  assert.equal(result[1].category, "bottoms");
});

test("getJobItems returns empty array when no items", async () => {
  const { pool } = createMockPool({ selectItemsRows: [] });
  const repo = createExtractionRepository({ pool });

  const result = await repo.getJobItems(testAuthContext, "job-1");

  assert.ok(Array.isArray(result));
  assert.equal(result.length, 0);
});

// === updatePhotoStatus tests ===

test("updatePhotoStatus updates photo status and returns mapped result", async () => {
  const { pool, queries } = createMockPool();
  const repo = createExtractionRepository({ pool });

  const result = await repo.updatePhotoStatus(testAuthContext, "photo-1", {
    status: "completed",
    itemsFound: 3
  });

  assert.equal(result.id, "photo-1");
  assert.equal(result.status, "completed");
  assert.equal(result.itemsFound, 1); // From mock data

  // Verify the update query was called
  const updateQuery = queries.find(q => q.sql.includes("update app_public.extraction_job_photos"));
  assert.ok(updateQuery);
});

test("updatePhotoStatus updates photo with error message on failure", async () => {
  const failedPhotoRow = { id: "photo-1", job_id: "job-1", photo_url: "https://example.com/photo.jpg", original_filename: null, status: "failed", items_found: 0, error_message: "Gemini timeout", created_at: new Date("2026-03-19T12:00:00Z") };
  const { pool } = createMockPool({ updatePhotoRows: [failedPhotoRow] });
  const repo = createExtractionRepository({ pool });

  const result = await repo.updatePhotoStatus(testAuthContext, "photo-1", {
    status: "failed",
    errorMessage: "Gemini timeout"
  });

  assert.equal(result.status, "failed");
  assert.equal(result.errorMessage, "Gemini timeout");
});

test("updatePhotoStatus returns null when no fields to update", async () => {
  const { pool } = createMockPool();
  const repo = createExtractionRepository({ pool });

  const result = await repo.updatePhotoStatus(testAuthContext, "photo-1", {});

  assert.equal(result, null);
});

// === Constructor validation ===

test("createExtractionRepository throws when pool is missing", () => {
  assert.throws(
    () => createExtractionRepository({}),
    { message: "pool is required" }
  );
});
