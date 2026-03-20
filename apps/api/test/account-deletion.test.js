import assert from "node:assert/strict";
import test from "node:test";
import { handleRequest } from "../src/main.js";
import { createProfileService } from "../src/modules/profiles/service.js";

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

function buildContext({ authFn, profileService, uploadService, itemService }) {
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
    profileService: profileService ?? {
      async getProfileForAuthenticatedUser() { return { profile: {}, provisioned: false }; },
      async updateProfileForAuthenticatedUser() { return { profile: {} }; },
      async deleteAccountForAuthenticatedUser() { return { deleted: true }; }
    },
    itemService: itemService ?? {
      async createItemForUser() { return { item: {} }; },
      async listItemsForUser() { return { items: [] }; }
    },
    uploadService: uploadService ?? {
      async generateSignedUploadUrl() { return { uploadUrl: "", publicUrl: "" }; },
      async deleteUserFiles() { return { filesDeleted: 0 }; }
    }
  };
}

// === Route-level tests ===

test("DELETE /v1/profiles/me with valid auth returns { deleted: true } with status 200", async () => {
  const response = createResponseCapture();
  let capturedAuthContext;

  await handleRequest(
    { method: "DELETE", url: "/v1/profiles/me", headers: { authorization: "Bearer signed.jwt.token" } },
    response,
    buildContext({
      profileService: {
        async getProfileForAuthenticatedUser() { return { profile: {}, provisioned: false }; },
        async updateProfileForAuthenticatedUser() { return { profile: {} }; },
        async deleteAccountForAuthenticatedUser(authContext) {
          capturedAuthContext = authContext;
          return { deleted: true };
        }
      }
    })
  );

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.deepEqual(body, { deleted: true });
  assert.equal(capturedAuthContext.userId, "firebase-user-123");
});

test("DELETE /v1/profiles/me without auth returns 401", async () => {
  const response = createResponseCapture();

  await handleRequest(
    { method: "DELETE", url: "/v1/profiles/me", headers: {} },
    response,
    buildContext({})
  );

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

test("DELETE /v1/profiles/me returns 500 when service throws", async () => {
  const response = createResponseCapture();

  await handleRequest(
    { method: "DELETE", url: "/v1/profiles/me", headers: { authorization: "Bearer signed.jwt.token" } },
    response,
    buildContext({
      profileService: {
        async getProfileForAuthenticatedUser() { return { profile: {}, provisioned: false }; },
        async updateProfileForAuthenticatedUser() { return { profile: {} }; },
        async deleteAccountForAuthenticatedUser() {
          throw new Error("Profile not found");
        }
      }
    })
  );

  assert.equal(response.statusCode, 500);
});

// === Service-level tests ===

test("deleteAccountForAuthenticatedUser calls repo, uploadService, and firebaseAdmin", async () => {
  let repoDeleteCalled = false;
  let storageCalled = false;
  let firebaseCalled = false;

  const service = createProfileService({
    repo: {
      getOrCreateProfile: async () => ({ profile: {}, created: false }),
      updateProfile: async () => ({}),
      deleteProfile: async (authContext) => {
        repoDeleteCalled = true;
        assert.equal(authContext.userId, "user-abc");
        return { firebaseUid: "user-abc" };
      }
    },
    uploadService: {
      deleteUserFiles: async (uid) => {
        storageCalled = true;
        assert.equal(uid, "user-abc");
        return { filesDeleted: 3 };
      }
    },
    firebaseAdminService: {
      deleteUser: async (uid) => {
        firebaseCalled = true;
        assert.equal(uid, "user-abc");
        return { deleted: true };
      }
    }
  });

  const result = await service.deleteAccountForAuthenticatedUser({
    userId: "user-abc",
    email: "test@example.com",
    emailVerified: true,
    provider: "google.com"
  });

  assert.deepEqual(result, { deleted: true });
  assert.equal(repoDeleteCalled, true);
  assert.equal(storageCalled, true);
  assert.equal(firebaseCalled, true);
});

test("deleteAccountForAuthenticatedUser handles storage cleanup failure gracefully", async () => {
  const service = createProfileService({
    repo: {
      getOrCreateProfile: async () => ({ profile: {}, created: false }),
      updateProfile: async () => ({}),
      deleteProfile: async () => ({ firebaseUid: "user-abc" })
    },
    uploadService: {
      deleteUserFiles: async () => {
        throw new Error("Storage unavailable");
      }
    },
    firebaseAdminService: {
      deleteUser: async () => ({ deleted: true })
    }
  });

  // Should not throw even though storage failed
  const result = await service.deleteAccountForAuthenticatedUser({
    userId: "user-abc",
    email: "test@example.com",
    emailVerified: true,
    provider: "google.com"
  });

  assert.deepEqual(result, { deleted: true });
});

test("deleteAccountForAuthenticatedUser handles Firebase Admin deletion failure gracefully", async () => {
  const service = createProfileService({
    repo: {
      getOrCreateProfile: async () => ({ profile: {}, created: false }),
      updateProfile: async () => ({}),
      deleteProfile: async () => ({ firebaseUid: "user-abc" })
    },
    uploadService: {
      deleteUserFiles: async () => ({ filesDeleted: 0 })
    },
    firebaseAdminService: {
      deleteUser: async () => {
        throw new Error("Firebase Admin error");
      }
    }
  });

  // Should not throw even though Firebase Admin failed
  const result = await service.deleteAccountForAuthenticatedUser({
    userId: "user-abc",
    email: "test@example.com",
    emailVerified: true,
    provider: "google.com"
  });

  assert.deepEqual(result, { deleted: true });
});

test("deleteAccountForAuthenticatedUser works without optional services", async () => {
  const service = createProfileService({
    repo: {
      getOrCreateProfile: async () => ({ profile: {}, created: false }),
      updateProfile: async () => ({}),
      deleteProfile: async () => ({ firebaseUid: "user-abc" })
    }
    // No uploadService or firebaseAdminService
  });

  const result = await service.deleteAccountForAuthenticatedUser({
    userId: "user-abc",
    email: "test@example.com",
    emailVerified: true,
    provider: "google.com"
  });

  assert.deepEqual(result, { deleted: true });
});

test("deleteAccountForAuthenticatedUser propagates repo.deleteProfile error", async () => {
  const service = createProfileService({
    repo: {
      getOrCreateProfile: async () => ({ profile: {}, created: false }),
      updateProfile: async () => ({}),
      deleteProfile: async () => {
        throw new Error("Profile not found");
      }
    }
  });

  await assert.rejects(
    () => service.deleteAccountForAuthenticatedUser({
      userId: "nonexistent",
      email: "test@example.com",
      emailVerified: true,
      provider: "google.com"
    }),
    { message: "Profile not found" }
  );
});

// === Upload service deleteUserFiles tests ===

test("deleteUserFiles returns filesDeleted: 0 when no local directory exists", async () => {
  const { createUploadService } = await import("../src/modules/uploads/service.js");
  const uploadService = createUploadService({
    localUploadDir: "/tmp/vestiaire-test-nonexistent-" + Date.now()
  });

  const result = await uploadService.deleteUserFiles("nonexistent-user");
  assert.equal(result.filesDeleted, 0);
});
