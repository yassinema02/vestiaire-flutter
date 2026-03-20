import assert from "node:assert/strict";
import test from "node:test";
import { createDonationRepository } from "../../../src/modules/resale/donation-repository.js";

const testAuthContext = { userId: "firebase-user-123" };
const testProfileId = "profile-uuid-1";
const testItemId = "item-uuid-1";

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
      if (sql.includes("set_config")) {
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

test("createDonationRepository requires pool", () => {
  assert.throws(() => createDonationRepository({}), TypeError);
});

test("createDonation inserts a row with correct fields", async () => {
  const insertedRow = {
    id: "donation-uuid-1",
    profile_id: testProfileId,
    item_id: testItemId,
    charity_name: "Red Cross",
    estimated_value: "15.00",
    donation_date: "2026-03-15",
    created_at: new Date("2026-03-15T10:00:00Z"),
  };

  const { pool, calls } = createMockPool({
    queryResponses: [{ rows: [insertedRow] }],
  });

  const repo = createDonationRepository({ pool });
  const result = await repo.createDonation(testAuthContext, {
    itemId: testItemId,
    charityName: "Red Cross",
    estimatedValue: 15,
    donationDate: "2026-03-15",
  });

  assert.equal(result.id, "donation-uuid-1");
  assert.equal(result.profileId, testProfileId);
  assert.equal(result.itemId, testItemId);
  assert.equal(result.charityName, "Red Cross");
  assert.equal(result.estimatedValue, 15);
  assert.equal(result.donationDate, "2026-03-15");

  // Verify INSERT was called
  const insertCall = calls.find((c) => c.sql.includes("INSERT INTO app_public.donation_log"));
  assert.ok(insertCall, "INSERT query was executed");
});

test("createDonation allows null charity_name", async () => {
  const insertedRow = {
    id: "donation-uuid-2",
    profile_id: testProfileId,
    item_id: testItemId,
    charity_name: null,
    estimated_value: "10.00",
    donation_date: "2026-03-15",
    created_at: new Date("2026-03-15T10:00:00Z"),
  };

  const { pool } = createMockPool({
    queryResponses: [{ rows: [insertedRow] }],
  });

  const repo = createDonationRepository({ pool });
  const result = await repo.createDonation(testAuthContext, {
    itemId: testItemId,
  });

  assert.equal(result.charityName, null);
  assert.equal(result.estimatedValue, 10);
});

test("createDonation defaults donation_date to today", async () => {
  const today = new Date().toISOString().split("T")[0];
  const insertedRow = {
    id: "donation-uuid-3",
    profile_id: testProfileId,
    item_id: testItemId,
    charity_name: null,
    estimated_value: "0.00",
    donation_date: today,
    created_at: new Date(),
  };

  const { pool, calls } = createMockPool({
    queryResponses: [{ rows: [insertedRow] }],
  });

  const repo = createDonationRepository({ pool });
  await repo.createDonation(testAuthContext, {
    itemId: testItemId,
  });

  // Find the INSERT call and check the date param (index 4)
  const insertCall = calls.find((c) => c.sql.includes("INSERT INTO app_public.donation_log"));
  assert.ok(insertCall);
  assert.equal(insertCall.params[4], today);
});

test("listDonations returns entries in reverse chronological order with item metadata", async () => {
  const rows = [
    {
      id: "d1",
      profile_id: testProfileId,
      item_id: "item-1",
      charity_name: "Oxfam",
      estimated_value: "20.00",
      donation_date: "2026-03-15",
      created_at: new Date("2026-03-15T10:00:00Z"),
      item_name: "Blue Shirt",
      item_photo_url: "http://example.com/photo.jpg",
      item_category: "tops",
      item_brand: "Nike",
    },
    {
      id: "d2",
      profile_id: testProfileId,
      item_id: "item-2",
      charity_name: null,
      estimated_value: "10.00",
      donation_date: "2026-03-10",
      created_at: new Date("2026-03-10T10:00:00Z"),
      item_name: "Red Dress",
      item_photo_url: null,
      item_category: "dresses",
      item_brand: null,
    },
  ];

  const { pool } = createMockPool({
    queryResponses: [{ rows }],
  });

  const repo = createDonationRepository({ pool });
  const result = await repo.listDonations(testAuthContext);

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "d1");
  assert.equal(result[0].itemName, "Blue Shirt");
  assert.equal(result[0].itemPhotoUrl, "http://example.com/photo.jpg");
  assert.equal(result[0].charityName, "Oxfam");
  assert.equal(result[1].id, "d2");
  assert.equal(result[1].charityName, null);
  assert.equal(result[1].itemBrand, null);
});

test("listDonations respects limit and offset", async () => {
  const { pool, calls } = createMockPool({
    queryResponses: [{ rows: [] }],
  });

  const repo = createDonationRepository({ pool });
  await repo.listDonations(testAuthContext, { limit: 10, offset: 5 });

  const selectCall = calls.find((c) => c.sql.includes("LIMIT"));
  assert.ok(selectCall);
  assert.deepEqual(selectCall.params, [10, 5]);
});

test("listDonations only returns entries for authenticated user (RLS)", async () => {
  const { pool, calls } = createMockPool({
    queryResponses: [{ rows: [] }],
  });

  const repo = createDonationRepository({ pool });
  await repo.listDonations(testAuthContext);

  const setConfigCall = calls.find((c) => c.sql.includes("set_config"));
  assert.ok(setConfigCall);
  assert.deepEqual(setConfigCall.params, ["firebase-user-123"]);
});

test("getDonationSummary returns correct count and total value", async () => {
  const { pool } = createMockPool({
    queryResponses: [{ rows: [{ total_donated: "5", total_value: "75.50" }] }],
  });

  const repo = createDonationRepository({ pool });
  const result = await repo.getDonationSummary(testAuthContext);

  assert.equal(result.totalDonated, 5);
  assert.equal(result.totalValue, 75.5);
});

test("getDonationSummary returns zeros when no donations exist", async () => {
  const { pool } = createMockPool({
    queryResponses: [{ rows: [{ total_donated: "0", total_value: "0" }] }],
  });

  const repo = createDonationRepository({ pool });
  const result = await repo.getDonationSummary(testAuthContext);

  assert.equal(result.totalDonated, 0);
  assert.equal(result.totalValue, 0);
});
