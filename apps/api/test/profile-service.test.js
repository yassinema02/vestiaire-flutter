import assert from "node:assert/strict";
import test from "node:test";
import { createProfileService } from "../src/modules/profiles/service.js";

test("profile service provisions a missing profile on first access", async () => {
  const calls = [];
  const profileService = createProfileService({
    repo: {
      async getOrCreateProfile(authContext) {
        calls.push(authContext);
        return {
          profile: {
            id: "profile-1",
            firebaseUid: authContext.userId,
            email: authContext.email,
            authProvider: authContext.provider,
            emailVerified: authContext.emailVerified
          },
          created: true
        };
      }
    }
  });

  const result = await profileService.getProfileForAuthenticatedUser({
    userId: "firebase-user-123",
    email: "user@example.com",
    emailVerified: true,
    provider: "google.com"
  });

  assert.equal(calls.length, 1);
  assert.equal(result.provisioned, true);
  assert.equal(result.profile.firebaseUid, "firebase-user-123");
});

test("profile service returns existing profiles idempotently", async () => {
  const profileService = createProfileService({
    repo: {
      async getOrCreateProfile(authContext) {
        return {
          profile: {
            id: "profile-1",
            firebaseUid: authContext.userId,
            email: authContext.email,
            authProvider: authContext.provider,
            emailVerified: authContext.emailVerified
          },
          created: false
        };
      }
    }
  });

  const result = await profileService.getProfileForAuthenticatedUser({
    userId: "firebase-user-123",
    email: "user@example.com",
    emailVerified: true,
    provider: "password"
  });

  assert.equal(result.provisioned, false);
  assert.equal(result.profile.firebaseUid, "firebase-user-123");
});
