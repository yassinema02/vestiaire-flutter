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
  const json = JSON.stringify(body);
  const stream = Readable.from([Buffer.from(json)]);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    authorization: "Bearer signed.jwt.token",
    "content-type": "application/json"
  };
  return stream;
}

function buildContext({ authFn, profileService }) {
  return {
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate() {
        if (authFn) return authFn();
        return {
          userId: "firebase-user-123",
          email: "user@example.com",
          emailVerified: true,
          provider: "google.com"
        };
      }
    },
    profileService,
    itemService: {
      async createItemForUser() { return { item: {} }; },
      async listItemsForUser() { return { items: [] }; }
    },
    uploadService: {
      async generateSignedUploadUrl() { return { uploadUrl: "", publicUrl: "" }; }
    }
  };
}

test("PUT /v1/profiles/me updates display_name and style_preferences", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    display_name: "Alice",
    style_preferences: ["casual", "minimalist"]
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(authContext, updates) {
        capturedUpdates = updates;
        return {
          profile: {
            id: "profile-1",
            firebaseUid: authContext.userId,
            displayName: "Alice",
            stylePreferences: ["casual", "minimalist"],
            onboardingCompletedAt: null
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.displayName, "Alice");
  assert.deepEqual(body.profile.stylePreferences, ["casual", "minimalist"]);
  assert.deepEqual(capturedUpdates, {
    display_name: "Alice",
    style_preferences: ["casual", "minimalist"]
  });
});

test("PUT /v1/profiles/me updates onboarding_completed_at", async () => {
  const response = createResponseCapture();
  const timestamp = "2026-03-10T12:00:00.000Z";

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    onboarding_completed_at: timestamp
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        return {
          profile: {
            id: "profile-1",
            onboardingCompletedAt: updates.onboarding_completed_at
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.onboardingCompletedAt, timestamp);
});

test("PUT /v1/profiles/me rejects too-long display_name", async () => {
  const response = createResponseCapture();
  const longName = "a".repeat(101);

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    display_name: longName
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        // Simulate validation in the service
        if (updates.display_name && updates.display_name.length > 100) {
          const error = new Error("display_name must be a string of at most 100 characters");
          error.statusCode = 400;
          error.code = "VALIDATION_ERROR";
          throw error;
        }
        return { profile: {} };
      }
    }
  }));

  assert.equal(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.equal(body.code, "VALIDATION_ERROR");
  assert.match(body.message, /display_name/);
});

test("PUT /v1/profiles/me rejects invalid style_preferences", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    style_preferences: ["casual", "invalid_style"]
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        if (updates.style_preferences) {
          const allowed = ["casual", "streetwear", "minimalist", "classic", "bohemian", "sporty", "vintage", "glamorous"];
          for (const pref of updates.style_preferences) {
            if (!allowed.includes(pref)) {
              const error = new Error(`Invalid style preference: ${pref}`);
              error.statusCode = 400;
              error.code = "VALIDATION_ERROR";
              throw error;
            }
          }
        }
        return { profile: {} };
      }
    }
  }));

  assert.equal(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.equal(body.code, "VALIDATION_ERROR");
  assert.match(body.message, /invalid_style/i);
});

test("PUT /v1/profiles/me partial update only sends display_name", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    display_name: "Bob"
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        capturedUpdates = updates;
        return { profile: { id: "profile-1", displayName: "Bob" } };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  assert.deepEqual(Object.keys(capturedUpdates), ["display_name"]);
});

test("PUT /v1/profiles/me rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    display_name: "Alice"
  });
  // Remove auth header
  req.headers = { "content-type": "application/json" };

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser() { throw new Error("not called"); }
    }
  }));

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});
