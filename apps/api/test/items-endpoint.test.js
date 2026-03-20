import assert from "node:assert/strict";
import { Readable } from "node:stream";
import test from "node:test";
import { handleRequest } from "../src/main.js";

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

function buildContext({ itemService, uploadService, backgroundRemovalService } = {}) {
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
    uploadService: uploadService ?? {
      async generateSignedUploadUrl() { return { uploadUrl: "", publicUrl: "" }; }
    },
    backgroundRemovalService: backgroundRemovalService ?? {
      async removeBackground() { return { status: "completed" }; }
    }
  };
}

test("POST /v1/items creates an item and returns it", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://storage.example.com/photo.jpg",
    name: "My Jacket"
  });

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser(authContext, data) {
        assert.equal(authContext.userId, "firebase-user-123");
        assert.equal(data.photoUrl, "https://storage.example.com/photo.jpg");
        assert.equal(data.name, "My Jacket");
        return {
          item: {
            id: "item-1",
            profileId: "profile-1",
            photoUrl: "https://storage.example.com/photo.jpg",
            name: "My Jacket",
            originalPhotoUrl: "https://storage.example.com/photo.jpg",
            bgRemovalStatus: "pending",
            createdAt: "2026-03-10T12:00:00.000Z",
            updatedAt: "2026-03-10T12:00:00.000Z"
          }
        };
      },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 201);
  const body = JSON.parse(response.body);
  assert.equal(body.item.id, "item-1");
  assert.equal(body.item.photoUrl, "https://storage.example.com/photo.jpg");
  assert.equal(body.item.name, "My Jacket");
  assert.equal(body.item.bgRemovalStatus, "pending");
  assert.equal(body.item.originalPhotoUrl, "https://storage.example.com/photo.jpg");
});

test("GET /v1/items returns the user's items with bg removal fields", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        assert.equal(authContext.userId, "firebase-user-123");
        return {
          items: [
            {
              id: "item-1",
              profileId: "profile-1",
              photoUrl: "https://storage.example.com/photo1_cleaned.jpg",
              originalPhotoUrl: "https://storage.example.com/photo1.jpg",
              name: "Jacket",
              bgRemovalStatus: "completed",
              createdAt: "2026-03-10T12:00:00.000Z",
              updatedAt: "2026-03-10T12:00:00.000Z"
            },
            {
              id: "item-2",
              profileId: "profile-1",
              photoUrl: "https://storage.example.com/photo2.jpg",
              originalPhotoUrl: null,
              name: null,
              bgRemovalStatus: null,
              createdAt: "2026-03-10T11:00:00.000Z",
              updatedAt: "2026-03-10T11:00:00.000Z"
            }
          ]
        };
      },
      async getItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.items.length, 2);
  assert.equal(body.items[0].id, "item-1");
  assert.equal(body.items[0].bgRemovalStatus, "completed");
  assert.equal(body.items[0].originalPhotoUrl, "https://storage.example.com/photo1.jpg");
  assert.equal(body.items[1].id, "item-2");
  assert.equal(body.items[1].bgRemovalStatus, null);
  assert.equal(body.items[1].originalPhotoUrl, null);
});

test("POST /v1/items rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("POST", "/v1/items", {
    photoUrl: "https://storage.example.com/photo.jpg"
  });
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

test("GET /v1/items rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items");
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

test("POST /v1/uploads/signed-url returns upload and public URLs", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("POST", "/v1/uploads/signed-url", {
    purpose: "profile_photo",
    contentType: "image/jpeg"
  });

  await handleRequest(req, response, buildContext({
    uploadService: {
      async generateSignedUploadUrl(authContext, { purpose, contentType }) {
        assert.equal(purpose, "profile_photo");
        assert.equal(contentType, "image/jpeg");
        return {
          uploadUrl: "https://storage.googleapis.com/upload/test",
          publicUrl: "https://storage.googleapis.com/bucket/test.jpg"
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.uploadUrl, "https://storage.googleapis.com/upload/test");
  assert.equal(body.publicUrl, "https://storage.googleapis.com/bucket/test.jpg");
});

test("POST /v1/uploads/signed-url rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("POST", "/v1/uploads/signed-url", {
    purpose: "profile_photo",
    contentType: "image/jpeg"
  });
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

// === Story 8.2: Upload purpose for shopping_screenshot ===

test("POST /v1/uploads/signed-url accepts shopping_screenshot purpose with correct path", async () => {
  const response = createResponseCapture();
  let capturedPurpose;

  const req = createJsonRequest("POST", "/v1/uploads/signed-url", {
    purpose: "shopping_screenshot",
    contentType: "image/jpeg"
  });

  await handleRequest(req, response, buildContext({
    uploadService: {
      async generateSignedUploadUrl(authContext, { purpose, contentType }) {
        capturedPurpose = purpose;
        assert.equal(purpose, "shopping_screenshot");
        assert.equal(contentType, "image/jpeg");
        return {
          uploadUrl: "https://storage.googleapis.com/upload/shopping",
          publicUrl: "https://storage.googleapis.com/bucket/users/uid/shopping/uuid.jpg"
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  assert.equal(capturedPurpose, "shopping_screenshot");
  const body = JSON.parse(response.body);
  assert.ok(body.publicUrl.includes("shopping"));
});

// === Story 2.2: POST /v1/items/:id/remove-background ===

test("POST /v1/items/:id/remove-background returns 202 and triggers bg removal", async () => {
  const response = createResponseCapture();
  let bgRemovalCalled = false;

  const req = createJsonRequest("POST", "/v1/items/item-123/remove-background");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(authContext, itemId) {
        assert.equal(itemId, "item-123");
        return {
          item: {
            id: "item-123",
            profileId: "profile-1",
            photoUrl: "https://storage.example.com/photo.jpg",
            originalPhotoUrl: "https://storage.example.com/photo.jpg",
            bgRemovalStatus: "failed"
          }
        };
      }
    },
    backgroundRemovalService: {
      removeBackground(authContext, params) {
        bgRemovalCalled = true;
        assert.equal(params.itemId, "item-123");
        assert.equal(params.imageUrl, "https://storage.example.com/photo.jpg");
        return Promise.resolve({ status: "completed" });
      }
    }
  }));

  assert.equal(response.statusCode, 202);
  const body = JSON.parse(response.body);
  assert.equal(body.status, "processing");
  assert.ok(bgRemovalCalled);
});

test("POST /v1/items/:id/remove-background rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("POST", "/v1/items/item-123/remove-background");
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

test("POST /v1/items/:id/remove-background returns 404 for non-existent item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("POST", "/v1/items/non-existent/remove-background");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }
    }
  }));

  assert.equal(response.statusCode, 404);
  assert.equal(JSON.parse(response.body).error, "Not Found");
});

// === Story 2.4: PATCH /v1/items/:id ===

test("PATCH /v1/items/:id returns 200 with valid update", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PATCH", "/v1/items/item-1", {
    category: "tops",
    color: "blue",
    brand: "Nike"
  });

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser(authContext, itemId, body) {
        assert.equal(authContext.userId, "firebase-user-123");
        assert.equal(itemId, "item-1");
        assert.equal(body.category, "tops");
        assert.equal(body.color, "blue");
        assert.equal(body.brand, "Nike");
        return {
          item: {
            id: "item-1",
            category: "tops",
            color: "blue",
            brand: "Nike"
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.item.id, "item-1");
  assert.equal(body.item.category, "tops");
  assert.equal(body.item.brand, "Nike");
});

test("PATCH /v1/items/:id returns 400 with invalid taxonomy", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PATCH", "/v1/items/item-1", {
    category: "invalid"
  });

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() {
        const error = new Error("Invalid category: invalid");
        error.statusCode = 400;
        error.code = "VALIDATION_ERROR";
        throw error;
      }
    }
  }));

  assert.equal(response.statusCode, 400);
  assert.equal(JSON.parse(response.body).error, "Bad Request");
});

test("PATCH /v1/items/:id returns 404 for non-existent item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PATCH", "/v1/items/non-existent", {
    category: "tops"
  });

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }
    }
  }));

  assert.equal(response.statusCode, 404);
  assert.equal(JSON.parse(response.body).error, "Not Found");
});

test("PATCH /v1/items/:id returns 401 without auth", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PATCH", "/v1/items/item-1", {
    category: "tops"
  });
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

// === Story 2.4: GET /v1/items/:id ===

test("GET /v1/items/:id returns 200 with owned item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items/item-1");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(authContext, itemId) {
        assert.equal(authContext.userId, "firebase-user-123");
        assert.equal(itemId, "item-1");
        return {
          item: {
            id: "item-1",
            profileId: "profile-1",
            photoUrl: "https://example.com/photo.jpg",
            category: "tops",
            brand: "Nike"
          }
        };
      },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.item.id, "item-1");
  assert.equal(body.item.category, "tops");
  assert.equal(body.item.brand, "Nike");
});

test("GET /v1/items/:id returns 404 for non-existent item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items/non-existent");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 404);
  assert.equal(JSON.parse(response.body).error, "Not Found");
});

test("GET /v1/items/:id returns 401 without auth", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items/item-1");
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

// === Story 2.5: GET /v1/items with filter params ===

test("GET /v1/items?category=tops passes category filter to service", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?category=tops");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        assert.equal(options.category, "tops");
        assert.equal(options.color, undefined);
        return {
          items: [
            { id: "item-1", category: "tops", photoUrl: "https://example.com/1.jpg" }
          ]
        };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.items.length, 1);
  assert.equal(body.items[0].category, "tops");
});

test("GET /v1/items?category=tops&color=black passes multiple filters to service", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?category=tops&color=black");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        assert.equal(options.category, "tops");
        assert.equal(options.color, "black");
        return { items: [] };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
});

test("GET /v1/items?season=winter passes season filter to service", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?season=winter");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        assert.equal(options.season, "winter");
        return { items: [] };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
});

test("GET /v1/items?brand=Nike passes brand filter to service", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?brand=Nike");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        assert.equal(options.brand, "Nike");
        return { items: [] };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
});

test("GET /v1/items?category=invalid returns 400 error", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?category=invalid");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() {
        const error = new Error("Invalid category filter: invalid");
        error.statusCode = 400;
        error.code = "VALIDATION_ERROR";
        throw error;
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 400);
  assert.equal(JSON.parse(response.body).error, "Bad Request");
});

// === Story 2.6: DELETE /v1/items/:id ===

test("DELETE /v1/items/:id returns 200 with { deleted: true } for owned item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("DELETE", "/v1/items/item-1");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser(authContext, itemId) {
        assert.equal(authContext.userId, "firebase-user-123");
        assert.equal(itemId, "item-1");
        return { deleted: true };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.deleted, true);
});

test("DELETE /v1/items/:id returns 404 for non-existent item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("DELETE", "/v1/items/non-existent");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser() {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }
    }
  }));

  assert.equal(response.statusCode, 404);
  assert.equal(JSON.parse(response.body).error, "Not Found");
});

test("DELETE /v1/items/:id returns 404 for item owned by another user", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("DELETE", "/v1/items/other-user-item");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser() {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }
    }
  }));

  assert.equal(response.statusCode, 404);
});

test("DELETE /v1/items/:id returns 401 without auth token", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("DELETE", "/v1/items/item-1");
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext());

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

// === Story 2.6: PATCH /v1/items/:id with isFavorite ===

test("PATCH /v1/items/:id with { isFavorite: true } returns updated item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PATCH", "/v1/items/item-1", {
    isFavorite: true
  });

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser(authContext, itemId, body) {
        assert.equal(body.isFavorite, true);
        return {
          item: {
            id: "item-1",
            isFavorite: true
          }
        };
      },
      async deleteItemForUser() { return { deleted: true }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.item.isFavorite, true);
});

test("GET /v1/items/:id returns isFavorite field in response", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items/item-1");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(authContext, itemId) {
        return {
          item: {
            id: "item-1",
            isFavorite: false
          }
        };
      },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser() { return { deleted: true }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.item.isFavorite, false);
});

test("GET /v1/items list endpoint returns isFavorite field on each item", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() {
        return {
          items: [
            { id: "item-1", isFavorite: true },
            { id: "item-2", isFavorite: false }
          ]
        };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; },
      async deleteItemForUser() { return { deleted: true }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.items[0].isFavorite, true);
  assert.equal(body.items[1].isFavorite, false);
});

// === Story 2.7: Neglect status endpoint tests ===

test("GET /v1/items returns items with neglectStatus field computed correctly", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        return {
          items: [
            { id: "item-1", neglectStatus: "neglected" },
            { id: "item-2", neglectStatus: null }
          ]
        };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.items[0].neglectStatus, "neglected");
  assert.equal(body.items[1].neglectStatus, null);
});

test("GET /v1/items?neglect_status=neglected passes neglectStatus filter to service", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?neglect_status=neglected");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        assert.equal(options.neglectStatus, "neglected");
        return {
          items: [
            { id: "item-1", neglectStatus: "neglected" }
          ]
        };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.items.length, 1);
  assert.equal(body.items[0].neglectStatus, "neglected");
});

test("GET /v1/items?neglect_status=invalid returns 400 error", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items?neglect_status=invalid");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() {
        const error = new Error('Invalid neglect_status filter: invalid. Only "neglected" is supported.');
        error.statusCode = 400;
        error.code = "VALIDATION_ERROR";
        throw error;
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 400);
  assert.equal(JSON.parse(response.body).error, "Bad Request");
});

test("GET /v1/items/:id returns item with neglectStatus field", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items/item-1");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(authContext, itemId) {
        return {
          item: {
            id: "item-1",
            neglectStatus: "neglected"
          }
        };
      },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.item.neglectStatus, "neglected");
});

test("GET /v1/items without neglect_status filter returns all items (backward compat)", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("GET", "/v1/items");

  await handleRequest(req, response, buildContext({
    itemService: {
      async createItemForUser() { throw new Error("not called"); },
      async listItemsForUser(authContext, options) {
        // All filter params should be undefined
        assert.equal(options.category, undefined);
        assert.equal(options.color, undefined);
        assert.equal(options.season, undefined);
        assert.equal(options.occasion, undefined);
        assert.equal(options.brand, undefined);
        return { items: [{ id: "item-1" }, { id: "item-2" }] };
      },
      async getItemForUser() { return { item: {} }; },
      async updateItemForUser() { return { item: {} }; }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.items.length, 2);
});
