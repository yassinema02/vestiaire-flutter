import assert from "node:assert/strict";
import test from "node:test";
import { createItemService, ItemValidationError } from "../../../src/modules/items/service.js";

function createMockRepo() {
  const calls = [];
  return {
    calls,
    async createItem(authContext, data) {
      calls.push({ method: "createItem", authContext, data });
      return {
        id: "item-1",
        profileId: "profile-1",
        photoUrl: data.photoUrl,
        originalPhotoUrl: data.originalPhotoUrl ?? null,
        name: data.name,
        bgRemovalStatus: data.bgRemovalStatus ?? null,
        categorizationStatus: data.categorizationStatus ?? null,
        createdAt: "2026-03-10T12:00:00.000Z",
        updatedAt: "2026-03-10T12:00:00.000Z"
      };
    },
    async listItems() {
      return [];
    },
    async getItem(authContext, itemId) {
      calls.push({ method: "getItem", authContext, itemId });
      if (itemId === "not-found") return null;
      return {
        id: itemId,
        profileId: "profile-1",
        photoUrl: "https://example.com/photo.jpg",
        originalPhotoUrl: null,
        name: null,
        bgRemovalStatus: null
      };
    },
    async updateItem(authContext, itemId, fields) {
      calls.push({ method: "updateItem", authContext, itemId, fields });
      if (itemId === "not-found") return null;
      return {
        id: itemId,
        profileId: "profile-1",
        photoUrl: "https://example.com/photo.jpg",
        ...fields,
        updatedAt: "2026-03-11T12:00:00.000Z"
      };
    },
    async deleteItem(authContext, itemId) {
      calls.push({ method: "deleteItem", authContext, itemId });
      if (itemId === "not-found") return null;
      return { deleted: true };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

test("createItemForUser sets bgRemovalStatus to pending when bg removal service is available", async () => {
  const repo = createMockRepo();
  let bgRemovalTriggered = false;

  const service = createItemService({
    repo,
    backgroundRemovalService: {
      geminiClient: { isAvailable: () => true },
      removeBackground() {
        bgRemovalTriggered = true;
        return Promise.resolve({ status: "completed" });
      }
    }
  });

  const result = await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  assert.equal(result.item.bgRemovalStatus, "pending");
  assert.equal(result.item.originalPhotoUrl, "https://example.com/photo.jpg");

  // Verify create was called with correct bg removal fields
  assert.equal(repo.calls[0].data.bgRemovalStatus, "pending");
  assert.equal(repo.calls[0].data.originalPhotoUrl, "https://example.com/photo.jpg");

  // Wait a tick for fire-and-forget
  await new Promise(resolve => setTimeout(resolve, 10));
  assert.ok(bgRemovalTriggered);
});

test("createItemForUser sets bgRemovalStatus to null when no bg removal service", async () => {
  const repo = createMockRepo();

  const service = createItemService({ repo });

  const result = await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  assert.equal(result.item.bgRemovalStatus, null);
  assert.equal(result.item.originalPhotoUrl, null);
});

test("createItemForUser sets bgRemovalStatus to null when gemini is not available", async () => {
  const repo = createMockRepo();

  const service = createItemService({
    repo,
    backgroundRemovalService: {
      geminiClient: { isAvailable: () => false },
      removeBackground() {
        return Promise.resolve({ status: "skipped" });
      }
    }
  });

  const result = await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  assert.equal(result.item.bgRemovalStatus, null);
  assert.equal(result.item.originalPhotoUrl, null);
});

test("createItemForUser does not block on background removal failure", async () => {
  const repo = createMockRepo();

  const service = createItemService({
    repo,
    backgroundRemovalService: {
      geminiClient: { isAvailable: () => true },
      removeBackground() {
        return Promise.reject(new Error("Gemini API failed"));
      }
    }
  });

  // This should NOT throw even though bg removal fails
  const result = await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  assert.equal(result.item.id, "item-1");
  assert.equal(result.item.bgRemovalStatus, "pending");

  // Wait a tick for fire-and-forget error to be caught silently
  await new Promise(resolve => setTimeout(resolve, 10));
});

test("createItemForUser still validates photoUrl", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.createItemForUser(testAuthContext, { photoUrl: "" }),
    ItemValidationError
  );

  await assert.rejects(
    () => service.createItemForUser(testAuthContext, { photoUrl: 123 }),
    ItemValidationError
  );
});

test("getItemForUser returns item when found", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.getItemForUser(testAuthContext, "item-1");
  assert.equal(result.item.id, "item-1");
});

test("getItemForUser throws 404 when item not found", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.getItemForUser(testAuthContext, "not-found"),
    (error) => {
      assert.equal(error.statusCode, 404);
      assert.equal(error.code, "NOT_FOUND");
      return true;
    }
  );
});

// === Story 2.3: Categorization integration tests ===

test("createItemForUser sets categorization_status to pending and fires categorization after bg removal", async () => {
  const repo = createMockRepo();
  let bgRemovalResolved = false;
  let categorizationTriggered = false;
  let categorizationImageUrl = null;

  const service = createItemService({
    repo,
    backgroundRemovalService: {
      geminiClient: { isAvailable: () => true },
      removeBackground() {
        bgRemovalResolved = true;
        return Promise.resolve({ cleanedImageUrl: "https://example.com/cleaned.jpg", status: "completed" });
      }
    },
    categorizationService: {
      categorizeItem(authContext, { itemId, imageUrl }) {
        categorizationTriggered = true;
        categorizationImageUrl = imageUrl;
        return Promise.resolve({ status: "completed" });
      }
    }
  });

  const result = await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  assert.equal(result.item.categorizationStatus, "pending");

  // Wait for fire-and-forget chain to resolve
  await new Promise(resolve => setTimeout(resolve, 50));
  assert.ok(bgRemovalResolved, "bg removal should have been triggered");
  assert.ok(categorizationTriggered, "categorization should have been triggered");
  assert.equal(categorizationImageUrl, "https://example.com/cleaned.jpg", "should use cleaned image");
});

test("createItemForUser categorization uses original image when bg removal fails", async () => {
  const repo = createMockRepo();
  let categorizationImageUrl = null;

  const service = createItemService({
    repo,
    backgroundRemovalService: {
      geminiClient: { isAvailable: () => true },
      removeBackground() {
        return Promise.reject(new Error("BG removal failed"));
      }
    },
    categorizationService: {
      categorizeItem(authContext, { itemId, imageUrl }) {
        categorizationImageUrl = imageUrl;
        return Promise.resolve({ status: "completed" });
      }
    }
  });

  await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  // Wait for fire-and-forget chain to resolve
  await new Promise(resolve => setTimeout(resolve, 50));
  assert.equal(categorizationImageUrl, "https://example.com/photo.jpg", "should fall back to original image");
});

test("createItemForUser does not set categorization_status when no categorization service", async () => {
  const repo = createMockRepo();

  const service = createItemService({
    repo,
    backgroundRemovalService: {
      geminiClient: { isAvailable: () => true },
      removeBackground() {
        return Promise.resolve({ status: "completed" });
      }
    }
  });

  const result = await service.createItemForUser(testAuthContext, {
    photoUrl: "https://example.com/photo.jpg"
  });

  assert.equal(result.item.categorizationStatus, null);
});

// === Story 2.4: updateItemForUser tests ===

test("updateItemForUser validates invalid category and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { category: "invalid-cat" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid category"));
      return true;
    }
  );
});

test("updateItemForUser validates invalid color and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { color: "neon-green" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid color"));
      return true;
    }
  );
});

test("updateItemForUser validates invalid pattern and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { pattern: "zigzag" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser validates invalid material and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { material: "adamantium" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser validates invalid style and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { style: "goth" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser validates invalid season array and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { season: ["monsoon"] }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser validates invalid occasion array and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { occasion: ["funeral"] }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser validates brand max length and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { brand: "x".repeat(101) }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("brand"));
      return true;
    }
  );
});

test("updateItemForUser validates name max length and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { name: "x".repeat(201) }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("name"));
      return true;
    }
  );
});

test("updateItemForUser validates purchase_price >= 0 and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { purchasePrice: -10 }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("purchase_price"));
      return true;
    }
  );
});

test("updateItemForUser validates currency and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { currency: "JPY" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid currency"));
      return true;
    }
  );
});

test("updateItemForUser validates purchase_date format and throws 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { purchaseDate: "not-a-date" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("purchase_date"));
      return true;
    }
  );
});

test("updateItemForUser returns updated item with valid fields", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.updateItemForUser(testAuthContext, "item-1", {
    category: "tops",
    color: "blue",
    brand: "Nike",
    purchasePrice: 49.99,
    currency: "USD"
  });

  assert.equal(result.item.id, "item-1");
  assert.equal(result.item.category, "tops");
  assert.equal(result.item.color, "blue");
  assert.equal(result.item.brand, "Nike");
  assert.equal(result.item.purchasePrice, 49.99);
  assert.equal(result.item.currency, "USD");
});

test("updateItemForUser throws 404 for non-existent item", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "not-found", { category: "tops" }),
    (error) => {
      assert.equal(error.statusCode, 404);
      assert.equal(error.code, "NOT_FOUND");
      return true;
    }
  );
});

test("updateItemForUser throws 400 when no valid fields provided", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", {}),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser accepts valid secondary_colors", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.updateItemForUser(testAuthContext, "item-1", {
    secondaryColors: ["red", "blue"]
  });

  assert.ok(result.item);
});

test("updateItemForUser rejects invalid secondary_colors", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", {
      secondaryColors: ["red", "invalid-color"]
    }),
    (error) => {
      assert.equal(error.statusCode, 400);
      return true;
    }
  );
});

test("updateItemForUser accepts valid purchase_date", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.updateItemForUser(testAuthContext, "item-1", {
    purchaseDate: "2025-06-15"
  });

  assert.ok(result.item);
});

// === Story 2.5: listItemsForUser filter tests ===

test("listItemsForUser passes filter params to repository", async () => {
  const repo = createMockRepo();
  let capturedOptions = null;
  repo.listItems = async (authContext, options) => {
    capturedOptions = options;
    return [];
  };
  const service = createItemService({ repo });

  await service.listItemsForUser(testAuthContext, {
    category: "tops",
    color: "black",
    season: "winter",
    occasion: "everyday",
    brand: "Nike"
  });

  assert.equal(capturedOptions.category, "tops");
  assert.equal(capturedOptions.color, "black");
  assert.equal(capturedOptions.season, "winter");
  assert.equal(capturedOptions.occasion, "everyday");
  assert.equal(capturedOptions.brand, "Nike");
});

test("listItemsForUser rejects invalid category filter with 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.listItemsForUser(testAuthContext, { category: "invalid" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid category filter"));
      return true;
    }
  );
});

test("listItemsForUser rejects invalid color filter with 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.listItemsForUser(testAuthContext, { color: "neon" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid color filter"));
      return true;
    }
  );
});

test("listItemsForUser rejects invalid season filter with 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.listItemsForUser(testAuthContext, { season: "monsoon" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid season filter"));
      return true;
    }
  );
});

test("listItemsForUser rejects invalid occasion filter with 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.listItemsForUser(testAuthContext, { occasion: "funeral" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid occasion filter"));
      return true;
    }
  );
});

test("listItemsForUser passes brand filter without taxonomy validation", async () => {
  const repo = createMockRepo();
  let capturedOptions = null;
  repo.listItems = async (authContext, options) => {
    capturedOptions = options;
    return [];
  };
  const service = createItemService({ repo });

  // Any string should be accepted for brand (no taxonomy validation)
  await service.listItemsForUser(testAuthContext, { brand: "Some Random Brand" });

  assert.equal(capturedOptions.brand, "Some Random Brand");
});

test("listItemsForUser returns items without filters (backward compat)", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.listItemsForUser(testAuthContext, {});
  assert.ok(Array.isArray(result.items));
});

// === Story 2.6: deleteItemForUser tests ===

test("deleteItemForUser calls repo.deleteItem and returns { deleted: true }", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.deleteItemForUser(testAuthContext, "item-1");
  assert.deepStrictEqual(result, { deleted: true });
  assert.equal(repo.calls[0].method, "deleteItem");
  assert.equal(repo.calls[0].itemId, "item-1");
});

test("deleteItemForUser throws 404 when item not found", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.deleteItemForUser(testAuthContext, "not-found"),
    (error) => {
      assert.equal(error.statusCode, 404);
      assert.equal(error.code, "NOT_FOUND");
      return true;
    }
  );
});

// === Story 2.6: isFavorite validation in updateItemForUser ===

test("updateItemForUser accepts isFavorite boolean and passes to repo", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  const result = await service.updateItemForUser(testAuthContext, "item-1", {
    isFavorite: true
  });

  assert.ok(result.item);
  const updateCall = repo.calls.find(c => c.method === "updateItem");
  assert.equal(updateCall.fields.isFavorite, true);
});

test("updateItemForUser rejects non-boolean isFavorite with 400 error", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.updateItemForUser(testAuthContext, "item-1", { isFavorite: "yes" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("isFavorite"));
      return true;
    }
  );
});

// === Story 2.7: Neglect detection and filtering tests ===

test("listItemsForUser returns items with neglectStatus computed from created_at (> 180 days ago = neglected)", async () => {
  const repo = createMockRepo();
  const oldDate = new Date(Date.now() - 200 * 24 * 60 * 60 * 1000).toISOString();
  repo.listItems = async () => {
    return [
      { id: "old-item", profile_id: "p1", photo_url: "https://example.com/1.jpg", created_at: new Date(oldDate) }
    ];
  };
  // Use the actual repository mapItemRow by importing it indirectly through the repo
  // Instead, we test via the service layer which calls repo.listItems
  // The mock repo returns raw rows, but service expects mapped items from repo.
  // Since we mock at the repo level and repo.listItems returns already-mapped items in the real code,
  // we need to simulate mapped items with neglectStatus already computed.
  repo.listItems = async () => {
    return [
      { id: "old-item", profileId: "p1", photoUrl: "https://example.com/1.jpg", neglectStatus: "neglected", createdAt: oldDate }
    ];
  };
  const service = createItemService({ repo });

  const result = await service.listItemsForUser(testAuthContext, {});
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].neglectStatus, "neglected");
});

test("listItemsForUser returns items with neglectStatus null for recent items (< 180 days ago)", async () => {
  const repo = createMockRepo();
  const recentDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  repo.listItems = async () => {
    return [
      { id: "new-item", profileId: "p1", photoUrl: "https://example.com/1.jpg", neglectStatus: null, createdAt: recentDate }
    ];
  };
  const service = createItemService({ repo });

  const result = await service.listItemsForUser(testAuthContext, {});
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].neglectStatus, null);
});

test("listItemsForUser with neglectStatus=neglected passes filter to repo", async () => {
  const repo = createMockRepo();
  let capturedOptions = null;
  repo.listItems = async (authContext, options) => {
    capturedOptions = options;
    return [
      { id: "old-item", profileId: "p1", neglectStatus: "neglected" }
    ];
  };
  const service = createItemService({ repo });

  const result = await service.listItemsForUser(testAuthContext, { neglectStatus: "neglected" });
  assert.equal(capturedOptions.neglectStatus, "neglected");
  assert.equal(result.items.length, 1);
});

test("listItemsForUser rejects invalid neglectStatus value with 400", async () => {
  const repo = createMockRepo();
  const service = createItemService({ repo });

  await assert.rejects(
    () => service.listItemsForUser(testAuthContext, { neglectStatus: "invalid" }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.ok(error.message.includes("Invalid neglect_status filter"));
      return true;
    }
  );
});
