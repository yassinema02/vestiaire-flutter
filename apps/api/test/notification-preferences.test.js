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

function createDeleteRequest(url) {
  const stream = Readable.from([Buffer.from("")]);
  stream.method = "DELETE";
  stream.url = url;
  stream.headers = {
    authorization: "Bearer signed.jwt.token",
    "content-type": "application/json"
  };
  return stream;
}

function buildContext({ authFn, profileService } = {}) {
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

test("PUT /v1/profiles/me with push_token saves and returns the token", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    push_token: "fcm-token-abc123"
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
            pushToken: "fcm-token-abc123",
            notificationPreferences: {
              outfit_reminders: true,
              wear_logging: true,
              analytics: true,
              social: true
            }
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.pushToken, "fcm-token-abc123");
  assert.deepEqual(capturedUpdates, { push_token: "fcm-token-abc123" });
});

test("PUT /v1/profiles/me with push_token: null clears the token", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    push_token: null
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(authContext, updates) {
        capturedUpdates = updates;
        return {
          profile: {
            id: "profile-1",
            pushToken: null,
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.pushToken, null);
  assert.deepEqual(capturedUpdates, { push_token: null });
});

test("PUT /v1/profiles/me with valid notification_preferences saves and returns preferences", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: {
      outfit_reminders: false,
      social: true
    }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(authContext, updates) {
        capturedUpdates = updates;
        return {
          profile: {
            id: "profile-1",
            notificationPreferences: {
              outfit_reminders: false,
              wear_logging: true,
              analytics: true,
              social: true
            }
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.notificationPreferences.outfit_reminders, false);
  assert.equal(body.profile.notificationPreferences.social, true);
  assert.deepEqual(capturedUpdates, {
    notification_preferences: { outfit_reminders: false, social: true }
  });
});

test("PUT /v1/profiles/me with invalid notification_preferences (unknown key) returns 400", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: {
      outfit_reminders: true,
      unknown_key: true
    }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        // Use the real service validation
        const { createProfileService } = await import("../src/modules/profiles/service.js");
        const service = createProfileService({
          repo: {
            getOrCreateProfile: async () => ({}),
            updateProfile: async () => ({})
          }
        });
        return service.updateProfileForAuthenticatedUser(_authContext, updates);
      }
    }
  }));

  assert.equal(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.match(body.message, /unknown_key/i);
});

test("PUT /v1/profiles/me with invalid notification_preferences (non-boolean value for non-social key) returns 400", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: {
      outfit_reminders: "yes"
    }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        const { createProfileService } = await import("../src/modules/profiles/service.js");
        const service = createProfileService({
          repo: {
            getOrCreateProfile: async () => ({}),
            updateProfile: async () => ({})
          }
        });
        return service.updateProfileForAuthenticatedUser(_authContext, updates);
      }
    }
  }));

  assert.equal(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.match(body.message, /boolean/i);
});

test("GET /v1/profiles/me returns notificationPreferences with defaults for a new profile", async () => {
  const response = createResponseCapture();

  await handleRequest(
    {
      method: "GET",
      url: "/v1/profiles/me",
      headers: { authorization: "Bearer signed.jwt.token" }
    },
    response,
    buildContext({
      profileService: {
        async getProfileForAuthenticatedUser() {
          return {
            provisioned: true,
            profile: {
              id: "profile-1",
              firebaseUid: "firebase-user-123",
              email: "user@example.com",
              pushToken: null,
              notificationPreferences: {
                outfit_reminders: true,
                wear_logging: true,
                analytics: true,
                social: true
              }
            }
          };
        },
        async updateProfileForAuthenticatedUser() { throw new Error("not called"); }
      }
    })
  );

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.deepEqual(body.profile.notificationPreferences, {
    outfit_reminders: true,
    wear_logging: true,
    analytics: true,
    social: true
  });
  assert.equal(body.profile.pushToken, null);
});

test("PUT /v1/profiles/me with notification fields rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    push_token: "fcm-token-abc123"
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

test("DELETE /v1/profiles/me/push-token clears the push token", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createDeleteRequest("/v1/profiles/me/push-token");

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(authContext, updates) {
        capturedUpdates = updates;
        return {
          profile: {
            id: "profile-1",
            pushToken: null,
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.pushToken, null);
  assert.deepEqual(capturedUpdates, { push_token: null });
});

test("DELETE /v1/profiles/me/push-token rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  const req = createDeleteRequest("/v1/profiles/me/push-token");
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

// --- Story 9.6: Social notification mode string tests ---

function buildRealValidationContext() {
  return buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        const { createProfileService } = await import("../src/modules/profiles/service.js");
        const service = createProfileService({
          repo: {
            getOrCreateProfile: async () => ({}),
            updateProfile: async (_ctx, u) => ({ id: "profile-1", ...u })
          }
        });
        return service.updateProfileForAuthenticatedUser(_authContext, updates);
      }
    }
  });
}

test('PUT /v1/profiles/me with notification_preferences.social = "all" saves string', async () => {
  const response = createResponseCapture();
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { social: "all" }
  });

  await handleRequest(req, response, buildRealValidationContext());

  assert.equal(response.statusCode, 200);
});

test('PUT /v1/profiles/me with notification_preferences.social = "morning" saves string', async () => {
  const response = createResponseCapture();
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { social: "morning" }
  });

  await handleRequest(req, response, buildRealValidationContext());

  assert.equal(response.statusCode, 200);
});

test('PUT /v1/profiles/me with notification_preferences.social = "off" saves string', async () => {
  const response = createResponseCapture();
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { social: "off" }
  });

  await handleRequest(req, response, buildRealValidationContext());

  assert.equal(response.statusCode, 200);
});

test("PUT /v1/profiles/me with notification_preferences.social = true normalizes to 'all'", async () => {
  const response = createResponseCapture();
  let capturedUpdates;
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { social: true }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        const { createProfileService } = await import("../src/modules/profiles/service.js");
        const service = createProfileService({
          repo: {
            getOrCreateProfile: async () => ({}),
            updateProfile: async (_ctx, u) => {
              capturedUpdates = u;
              return { id: "profile-1" };
            }
          }
        });
        return service.updateProfileForAuthenticatedUser(_authContext, updates);
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  assert.equal(capturedUpdates.notification_preferences.social, "all");
});

test("PUT /v1/profiles/me with notification_preferences.social = false normalizes to 'off'", async () => {
  const response = createResponseCapture();
  let capturedUpdates;
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { social: false }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        const { createProfileService } = await import("../src/modules/profiles/service.js");
        const service = createProfileService({
          repo: {
            getOrCreateProfile: async () => ({}),
            updateProfile: async (_ctx, u) => {
              capturedUpdates = u;
              return { id: "profile-1" };
            }
          }
        });
        return service.updateProfileForAuthenticatedUser(_authContext, updates);
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  assert.equal(capturedUpdates.notification_preferences.social, "off");
});

test('PUT /v1/profiles/me with notification_preferences.social = "invalid" returns 400', async () => {
  const response = createResponseCapture();
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { social: "invalid" }
  });

  await handleRequest(req, response, buildRealValidationContext());

  assert.equal(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.match(body.message, /social/i);
});

// --- Story 12.3: event_reminders notification preference key tests ---

test("PUT /v1/profiles/me with notification_preferences.event_reminders = true saves and returns", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { event_reminders: true }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        capturedUpdates = updates;
        return {
          profile: {
            id: "profile-1",
            notificationPreferences: {
              outfit_reminders: true,
              wear_logging: true,
              analytics: true,
              social: "all",
              event_reminders: true
            }
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.notificationPreferences.event_reminders, true);
  assert.deepEqual(capturedUpdates, {
    notification_preferences: { event_reminders: true }
  });
});

test("PUT /v1/profiles/me with notification_preferences.event_reminders = false saves and returns", async () => {
  const response = createResponseCapture();
  let capturedUpdates;

  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { event_reminders: false }
  });

  await handleRequest(req, response, buildContext({
    profileService: {
      async getProfileForAuthenticatedUser() { throw new Error("not called"); },
      async updateProfileForAuthenticatedUser(_authContext, updates) {
        capturedUpdates = updates;
        return {
          profile: {
            id: "profile-1",
            notificationPreferences: {
              outfit_reminders: true,
              wear_logging: true,
              analytics: true,
              social: "all",
              event_reminders: false
            }
          }
        };
      }
    }
  }));

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.profile.notificationPreferences.event_reminders, false);
  assert.deepEqual(capturedUpdates, {
    notification_preferences: { event_reminders: false }
  });
});

test('PUT /v1/profiles/me with notification_preferences.event_reminders = "invalid" returns 400', async () => {
  const response = createResponseCapture();
  const req = createJsonRequest("PUT", "/v1/profiles/me", {
    notification_preferences: { event_reminders: "invalid" }
  });

  await handleRequest(req, response, buildRealValidationContext());

  assert.equal(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.match(body.message, /boolean/i);
});
