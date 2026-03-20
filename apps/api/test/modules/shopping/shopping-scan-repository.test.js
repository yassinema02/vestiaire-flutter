import assert from "node:assert/strict";
import test from "node:test";
import {
  createShoppingScanRepository,
  mapScanRow
} from "../../../src/modules/shopping/shopping-scan-repository.js";

// --- mapScanRow tests ---

test("mapScanRow: correctly maps snake_case to camelCase", () => {
  const row = {
    id: "scan-1",
    profile_id: "profile-1",
    url: "https://example.com/product",
    scan_type: "url",
    product_name: "Blue Shirt",
    brand: "Zara",
    price: "29.99",
    currency: "GBP",
    image_url: "https://example.com/img.jpg",
    category: "tops",
    color: "blue",
    secondary_colors: ["white", "navy"],
    pattern: "solid",
    material: "cotton",
    style: "casual",
    season: ["spring", "summer"],
    occasion: ["everyday", "work"],
    formality_score: 3,
    extraction_method: "og_tags+json_ld",
    compatibility_score: null,
    insights: null,
    wishlisted: false,
    created_at: new Date("2026-03-19T10:00:00Z"),
  };

  const mapped = mapScanRow(row);

  assert.equal(mapped.id, "scan-1");
  assert.equal(mapped.profileId, "profile-1");
  assert.equal(mapped.url, "https://example.com/product");
  assert.equal(mapped.scanType, "url");
  assert.equal(mapped.productName, "Blue Shirt");
  assert.equal(mapped.brand, "Zara");
  assert.equal(mapped.price, 29.99);
  assert.equal(mapped.currency, "GBP");
  assert.equal(mapped.imageUrl, "https://example.com/img.jpg");
  assert.equal(mapped.category, "tops");
  assert.equal(mapped.color, "blue");
  assert.deepEqual(mapped.secondaryColors, ["white", "navy"]);
  assert.equal(mapped.pattern, "solid");
  assert.equal(mapped.material, "cotton");
  assert.equal(mapped.style, "casual");
  assert.deepEqual(mapped.season, ["spring", "summer"]);
  assert.deepEqual(mapped.occasion, ["everyday", "work"]);
  assert.equal(mapped.formalityScore, 3);
  assert.equal(mapped.extractionMethod, "og_tags+json_ld");
  assert.equal(mapped.compatibilityScore, null);
  assert.equal(mapped.insights, null);
  assert.equal(mapped.wishlisted, false);
  assert.equal(mapped.createdAt, "2026-03-19T10:00:00.000Z");
});

test("mapScanRow: handles null optional fields", () => {
  const row = {
    id: "scan-2",
    profile_id: "profile-1",
    url: null,
    scan_type: "screenshot",
    product_name: null,
    brand: null,
    price: null,
    currency: null,
    image_url: null,
    category: null,
    color: null,
    secondary_colors: null,
    pattern: null,
    material: null,
    style: null,
    season: null,
    occasion: null,
    formality_score: null,
    extraction_method: null,
    compatibility_score: null,
    insights: null,
    wishlisted: false,
    created_at: "2026-03-19T10:00:00Z",
  };

  const mapped = mapScanRow(row);
  assert.equal(mapped.url, null);
  assert.equal(mapped.productName, null);
  assert.equal(mapped.price, null);
  assert.equal(mapped.formalityScore, null);
});

test("mapScanRow: parses price as float", () => {
  const row = {
    id: "scan-3",
    profile_id: "p-1",
    scan_type: "url",
    price: "149.50",
    created_at: "2026-03-19T10:00:00Z",
  };

  const mapped = mapScanRow(row);
  assert.equal(mapped.price, 149.5);
  assert.equal(typeof mapped.price, "number");
});

// --- createShoppingScanRepository constructor tests ---

test("createShoppingScanRepository: throws TypeError when pool is missing", () => {
  assert.throws(
    () => createShoppingScanRepository({}),
    (err) => err instanceof TypeError && err.message === "pool is required"
  );
});

// --- Repository method tests with mock pool ---

function createMockPool({ scanRows = [], profileExists = true } = {}) {
  const queries = [];
  return {
    queries,
    async connect() {
      return {
        async query(sql, params) {
          queries.push({ sql, params });

          if (sql.includes("set_config")) return { rows: [] };
          if (sql === "begin" || sql === "commit" || sql === "rollback") return { rows: [] };
          if (sql.includes("FROM app_public.profiles WHERE firebase_uid")) {
            return { rows: profileExists ? [{ id: "profile-1" }] : [] };
          }
          if (sql.includes("INSERT INTO app_public.shopping_scans")) {
            return {
              rows: [{
                id: "scan-new",
                profile_id: "profile-1",
                url: params?.[1] ?? null,
                scan_type: params?.[2] ?? "url",
                product_name: params?.[3] ?? null,
                brand: params?.[4] ?? null,
                price: params?.[5] ?? null,
                currency: params?.[6] ?? "GBP",
                image_url: params?.[7] ?? null,
                category: params?.[8] ?? null,
                color: params?.[9] ?? null,
                secondary_colors: params?.[10] ?? null,
                pattern: params?.[11] ?? null,
                material: params?.[12] ?? null,
                style: params?.[13] ?? null,
                season: params?.[14] ?? null,
                occasion: params?.[15] ?? null,
                formality_score: params?.[16] ?? null,
                extraction_method: params?.[17] ?? null,
                compatibility_score: null,
                insights: null,
                wishlisted: false,
                created_at: new Date().toISOString(),
              }]
            };
          }
          if (sql.includes("FROM app_public.shopping_scans WHERE id")) {
            return { rows: scanRows };
          }
          if (sql.includes("FROM app_public.shopping_scans ORDER BY")) {
            return { rows: scanRows };
          }
          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

const testAuth = { userId: "firebase-user-123" };

test("createScan: inserts and returns a scan with all fields", async () => {
  const pool = createMockPool();
  const repo = createShoppingScanRepository({ pool });

  const scanData = {
    url: "https://www.zara.com/shirt",
    scanType: "url",
    productName: "Blue Shirt",
    brand: "Zara",
    price: 29.99,
    currency: "GBP",
    imageUrl: "https://example.com/img.jpg",
    category: "tops",
    color: "blue",
    secondaryColors: ["white"],
    pattern: "solid",
    material: "cotton",
    style: "casual",
    season: ["spring"],
    occasion: ["everyday"],
    formalityScore: 3,
    extractionMethod: "og_tags"
  };

  const result = await repo.createScan(testAuth, scanData);

  assert.ok(result.id);
  assert.equal(result.profileId, "profile-1");
  assert.equal(result.url, "https://www.zara.com/shirt");
  assert.equal(result.scanType, "url");

  // Verify INSERT query was called
  const insertQuery = pool.queries.find(q => q.sql.includes("INSERT INTO app_public.shopping_scans"));
  assert.ok(insertQuery);
});

test("getScanById: returns scan for the authenticated user", async () => {
  const scanRow = {
    id: "scan-1",
    profile_id: "profile-1",
    url: "https://example.com",
    scan_type: "url",
    product_name: "Test Product",
    brand: null,
    price: null,
    currency: "GBP",
    image_url: null,
    category: null,
    color: null,
    secondary_colors: null,
    pattern: null,
    material: null,
    style: null,
    season: null,
    occasion: null,
    formality_score: null,
    extraction_method: "og_tags",
    compatibility_score: null,
    insights: null,
    wishlisted: false,
    created_at: "2026-03-19T10:00:00Z",
  };

  const pool = createMockPool({ scanRows: [scanRow] });
  const repo = createShoppingScanRepository({ pool });
  const result = await repo.getScanById(testAuth, "scan-1");

  assert.ok(result);
  assert.equal(result.id, "scan-1");
  assert.equal(result.productName, "Test Product");
});

test("getScanById: returns null for another user's scan (RLS)", async () => {
  const pool = createMockPool({ scanRows: [] }); // RLS would filter it out
  const repo = createShoppingScanRepository({ pool });
  const result = await repo.getScanById(testAuth, "scan-other");

  assert.equal(result, null);
});

// --- Story 8.3: updateScan tests ---

function createMockPoolForUpdate({ scanRows = [], shouldReturnEmpty = false } = {}) {
  const queries = [];
  const defaultScanRow = {
    id: "scan-1",
    profile_id: "profile-1",
    url: "https://example.com",
    scan_type: "url",
    product_name: "Updated Product",
    brand: "Updated Brand",
    price: "49.99",
    currency: "GBP",
    image_url: "https://example.com/img.jpg",
    category: "tops",
    color: "blue",
    secondary_colors: ["white", "navy"],
    pattern: "solid",
    material: "cotton",
    style: "casual",
    season: ["spring", "summer"],
    occasion: ["everyday"],
    formality_score: 5,
    extraction_method: "og_tags",
    compatibility_score: null,
    insights: null,
    wishlisted: false,
    created_at: "2026-03-19T10:00:00Z",
  };

  return {
    queries,
    async connect() {
      return {
        async query(sql, params) {
          queries.push({ sql, params });
          if (sql.includes("set_config")) return { rows: [] };
          if (sql === "begin" || sql === "commit" || sql === "rollback") return { rows: [] };
          if (sql.includes("UPDATE app_public.shopping_scans SET")) {
            return { rows: shouldReturnEmpty ? [] : (scanRows.length > 0 ? scanRows : [defaultScanRow]) };
          }
          if (sql.includes("FROM app_public.shopping_scans WHERE id")) {
            return { rows: shouldReturnEmpty ? [] : (scanRows.length > 0 ? scanRows : [defaultScanRow]) };
          }
          return { rows: [] };
        },
        release() {}
      };
    }
  };
}

test("updateScan: updates specified fields and returns updated scan", async () => {
  const pool = createMockPoolForUpdate();
  const repo = createShoppingScanRepository({ pool });

  const result = await repo.updateScan(testAuth, "scan-1", { category: "bottoms", color: "red" });

  assert.ok(result);
  assert.equal(result.id, "scan-1");
  // Verify UPDATE query was executed
  const updateQuery = pool.queries.find(q => q.sql.includes("UPDATE app_public.shopping_scans SET"));
  assert.ok(updateQuery);
  assert.ok(updateQuery.sql.includes("category"));
  assert.ok(updateQuery.sql.includes("color"));
});

test("updateScan: returns null for non-existent scan ID", async () => {
  const pool = createMockPoolForUpdate({ shouldReturnEmpty: true });
  const repo = createShoppingScanRepository({ pool });

  const result = await repo.updateScan(testAuth, "non-existent-id", { category: "tops" });

  assert.equal(result, null);
});

test("updateScan: returns null for another user's scan (RLS)", async () => {
  const pool = createMockPoolForUpdate({ shouldReturnEmpty: true });
  const repo = createShoppingScanRepository({ pool });

  const result = await repo.updateScan(testAuth, "other-users-scan", { category: "tops" });

  assert.equal(result, null);
});

test("updateScan: updates only provided fields, leaving others unchanged", async () => {
  const pool = createMockPoolForUpdate();
  const repo = createShoppingScanRepository({ pool });

  await repo.updateScan(testAuth, "scan-1", { brand: "New Brand" });

  const updateQuery = pool.queries.find(q => q.sql.includes("UPDATE app_public.shopping_scans SET"));
  assert.ok(updateQuery);
  // Should only have brand in the SET clause
  assert.ok(updateQuery.sql.includes("brand"));
  assert.ok(!updateQuery.sql.includes("category ="));
});

test("updateScan: handles array fields (secondaryColors, season, occasion)", async () => {
  const pool = createMockPoolForUpdate();
  const repo = createShoppingScanRepository({ pool });

  await repo.updateScan(testAuth, "scan-1", {
    secondaryColors: ["red", "green"],
    season: ["fall", "winter"],
    occasion: ["formal", "party"],
  });

  const updateQuery = pool.queries.find(q => q.sql.includes("UPDATE app_public.shopping_scans SET"));
  assert.ok(updateQuery);
  assert.ok(updateQuery.sql.includes("secondary_colors"));
  assert.ok(updateQuery.sql.includes("::text[]"));
  assert.ok(updateQuery.sql.includes("season"));
  assert.ok(updateQuery.sql.includes("occasion"));
});

test("updateScan: updates formalityScore as integer", async () => {
  const pool = createMockPoolForUpdate();
  const repo = createShoppingScanRepository({ pool });

  await repo.updateScan(testAuth, "scan-1", { formalityScore: 8 });

  const updateQuery = pool.queries.find(q => q.sql.includes("UPDATE app_public.shopping_scans SET"));
  assert.ok(updateQuery);
  assert.ok(updateQuery.sql.includes("formality_score"));
  assert.ok(updateQuery.params.includes(8));
});

test("updateScan: returns existing scan when no fields to update", async () => {
  const pool = createMockPoolForUpdate();
  const repo = createShoppingScanRepository({ pool });

  const result = await repo.updateScan(testAuth, "scan-1", {});

  assert.ok(result);
  assert.equal(result.id, "scan-1");
  // Should NOT have executed an UPDATE
  const updateQuery = pool.queries.find(q => q.sql.includes("UPDATE app_public.shopping_scans SET"));
  assert.ok(!updateQuery);
  // Should have executed a SELECT
  const selectQuery = pool.queries.find(q => q.sql.includes("SELECT * FROM app_public.shopping_scans WHERE id"));
  assert.ok(selectQuery);
});

test("listScans: returns scans ordered by created_at DESC", async () => {
  const rows = [
    {
      id: "scan-2", profile_id: "p-1", scan_type: "url", product_name: "Second",
      brand: null, price: null, currency: "GBP", image_url: null, url: null,
      category: null, color: null, secondary_colors: null, pattern: null,
      material: null, style: null, season: null, occasion: null,
      formality_score: null, extraction_method: null, compatibility_score: null,
      insights: null, wishlisted: false, created_at: "2026-03-19T12:00:00Z",
    },
    {
      id: "scan-1", profile_id: "p-1", scan_type: "url", product_name: "First",
      brand: null, price: null, currency: "GBP", image_url: null, url: null,
      category: null, color: null, secondary_colors: null, pattern: null,
      material: null, style: null, season: null, occasion: null,
      formality_score: null, extraction_method: null, compatibility_score: null,
      insights: null, wishlisted: false, created_at: "2026-03-19T10:00:00Z",
    },
  ];

  const pool = createMockPool({ scanRows: rows });
  const repo = createShoppingScanRepository({ pool });
  const result = await repo.listScans(testAuth);

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "scan-2");
  assert.equal(result[1].id, "scan-1");

  // Verify ORDER BY
  const listQuery = pool.queries.find(q => q.sql.includes("ORDER BY created_at DESC"));
  assert.ok(listQuery);
});
