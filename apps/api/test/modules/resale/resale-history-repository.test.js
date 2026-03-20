import assert from "node:assert/strict";
import test from "node:test";
import { createResaleHistoryRepository } from "../../../src/modules/resale/resale-history-repository.js";

const testAuthContext = { userId: "firebase-user-123" };
const testProfileId = "profile-uuid-1";
const testItemId = "item-uuid-1";
const testListingId = "listing-uuid-1";

function createMockPool({
  queryResponses = [],
  shouldFail = false,
  failMessage = "DB error",
} = {}) {
  let queryIndex = 0;
  const calls = [];
  const client = {
    query(sql, params) {
      calls.push({ sql, params });
      if (shouldFail) throw new Error(failMessage);
      if (sql.includes("set_config") || sql === "begin" || sql === "commit" || sql === "rollback") {
        return { rows: [] };
      }
      if (sql.includes("FROM app_public.profiles WHERE firebase_uid")) {
        return { rows: [{ id: testProfileId }] };
      }
      if (queryIndex < queryResponses.length) {
        return queryResponses[queryIndex++];
      }
      return { rows: [] };
    },
    release() {},
  };

  return {
    pool: {
      connect() {
        return Promise.resolve(client);
      },
    },
    calls,
    client,
  };
}

test("createResaleHistoryRepository requires pool", () => {
  assert.throws(() => createResaleHistoryRepository({}), TypeError);
});

test("createHistoryEntry inserts a row with correct fields", async () => {
  const insertedRow = {
    id: "history-uuid-1",
    profile_id: testProfileId,
    item_id: testItemId,
    resale_listing_id: testListingId,
    type: "sold",
    sale_price: "49.99",
    sale_currency: "GBP",
    sale_date: "2026-03-15",
    created_at: new Date("2026-03-15T10:00:00Z"),
  };

  const { pool, calls } = createMockPool({
    queryResponses: [{ rows: [insertedRow] }],
  });

  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.createHistoryEntry(testAuthContext, {
    itemId: testItemId,
    resaleListingId: testListingId,
    type: "sold",
    salePrice: 49.99,
    saleCurrency: "GBP",
    saleDate: "2026-03-15",
  });

  assert.equal(result.id, "history-uuid-1");
  assert.equal(result.profileId, testProfileId);
  assert.equal(result.itemId, testItemId);
  assert.equal(result.resaleListingId, testListingId);
  assert.equal(result.type, "sold");
  assert.equal(result.salePrice, 49.99);
  assert.equal(result.saleCurrency, "GBP");
});

test("createHistoryEntry links resale_listing_id when provided", async () => {
  const insertedRow = {
    id: "history-uuid-2",
    profile_id: testProfileId,
    item_id: testItemId,
    resale_listing_id: testListingId,
    type: "sold",
    sale_price: "25.00",
    sale_currency: "GBP",
    sale_date: "2026-03-15",
    created_at: new Date("2026-03-15T10:00:00Z"),
  };

  const { pool } = createMockPool({
    queryResponses: [{ rows: [insertedRow] }],
  });

  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.createHistoryEntry(testAuthContext, {
    itemId: testItemId,
    resaleListingId: testListingId,
    type: "sold",
    salePrice: 25.0,
  });

  assert.equal(result.resaleListingId, testListingId);
});

test("createHistoryEntry allows null resale_listing_id for donated items", async () => {
  const insertedRow = {
    id: "history-uuid-3",
    profile_id: testProfileId,
    item_id: testItemId,
    resale_listing_id: null,
    type: "donated",
    sale_price: "0",
    sale_currency: "GBP",
    sale_date: "2026-03-15",
    created_at: new Date("2026-03-15T10:00:00Z"),
  };

  const { pool } = createMockPool({
    queryResponses: [{ rows: [insertedRow] }],
  });

  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.createHistoryEntry(testAuthContext, {
    itemId: testItemId,
    type: "donated",
    salePrice: 0,
  });

  assert.equal(result.resaleListingId, null);
  assert.equal(result.type, "donated");
  assert.equal(result.salePrice, 0);
});

test("listHistory returns entries in reverse chronological order with item metadata", async () => {
  const rows = [
    {
      id: "h1", profile_id: testProfileId, item_id: "i1", resale_listing_id: null,
      type: "sold", sale_price: "100.00", sale_currency: "GBP", sale_date: "2026-03-15",
      created_at: new Date("2026-03-15T10:00:00Z"),
      item_name: "Blue Shirt", item_photo_url: "http://example.com/1.jpg", item_category: "tops", item_brand: "Nike",
    },
    {
      id: "h2", profile_id: testProfileId, item_id: "i2", resale_listing_id: null,
      type: "donated", sale_price: "0", sale_currency: "GBP", sale_date: "2026-03-10",
      created_at: new Date("2026-03-10T10:00:00Z"),
      item_name: "Red Dress", item_photo_url: "http://example.com/2.jpg", item_category: "dresses", item_brand: null,
    },
  ];

  const { pool } = createMockPool({ queryResponses: [{ rows }] });
  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.listHistory(testAuthContext, { limit: 50, offset: 0 });

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "h1");
  assert.equal(result[0].itemName, "Blue Shirt");
  assert.equal(result[0].itemPhotoUrl, "http://example.com/1.jpg");
  assert.equal(result[1].id, "h2");
  assert.equal(result[1].itemBrand, null);
});

test("listHistory respects limit and offset", async () => {
  const { pool, calls } = createMockPool({ queryResponses: [{ rows: [] }] });
  const repo = createResaleHistoryRepository({ pool });
  await repo.listHistory(testAuthContext, { limit: 10, offset: 5 });

  const listCall = calls.find((c) => c.sql.includes("LIMIT"));
  assert.ok(listCall);
  assert.deepEqual(listCall.params, [10, 5]);
});

test("listHistory only returns entries for the authenticated user (RLS)", async () => {
  const { pool, calls } = createMockPool({ queryResponses: [{ rows: [] }] });
  const repo = createResaleHistoryRepository({ pool });
  await repo.listHistory(testAuthContext);

  const configCall = calls.find((c) => c.sql.includes("set_config"));
  assert.ok(configCall);
  assert.equal(configCall.params[0], "firebase-user-123");
});

test("getEarningsSummary returns correct counts and total earnings", async () => {
  const { pool } = createMockPool({
    queryResponses: [{ rows: [{ items_sold: "5", items_donated: "3", total_earnings: "250.50" }] }],
  });

  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.getEarningsSummary(testAuthContext);

  assert.equal(result.itemsSold, 5);
  assert.equal(result.itemsDonated, 3);
  assert.equal(result.totalEarnings, 250.50);
});

test("getEarningsSummary returns zeros when no history exists", async () => {
  const { pool } = createMockPool({
    queryResponses: [{ rows: [{ items_sold: "0", items_donated: "0", total_earnings: "0" }] }],
  });

  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.getEarningsSummary(testAuthContext);

  assert.equal(result.itemsSold, 0);
  assert.equal(result.itemsDonated, 0);
  assert.equal(result.totalEarnings, 0);
});

test("getMonthlyEarnings returns monthly aggregations for the specified period", async () => {
  const rows = [
    { month: new Date("2026-01-01T00:00:00Z"), earnings: "150.00" },
    { month: new Date("2026-02-01T00:00:00Z"), earnings: "200.00" },
  ];

  const { pool } = createMockPool({ queryResponses: [{ rows }] });
  const repo = createResaleHistoryRepository({ pool });
  const result = await repo.getMonthlyEarnings(testAuthContext, { months: 6 });

  assert.equal(result.length, 2);
  assert.equal(result[0].earnings, 150);
  assert.equal(result[1].earnings, 200);
});

test("getMonthlyEarnings excludes donated items from earnings", async () => {
  const { pool, calls } = createMockPool({ queryResponses: [{ rows: [] }] });
  const repo = createResaleHistoryRepository({ pool });
  await repo.getMonthlyEarnings(testAuthContext);

  const earningsCall = calls.find((c) => c.sql.includes("type = 'sold'"));
  assert.ok(earningsCall, "Query should filter for type = 'sold'");
});
