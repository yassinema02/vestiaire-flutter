import assert from "node:assert/strict";
import test from "node:test";
import {
  AuthenticationError,
  AuthorizationError,
  createAuthService
} from "../src/modules/auth/service.js";

test("auth service derives identity from a verified Firebase token", async () => {
  const calls = [];
  const authService = createAuthService({
    verifyToken: async (token) => {
      calls.push(token);
      return {
        sub: "firebase-user-123",
        email: "user@example.com",
        email_verified: true,
        firebase: { sign_in_provider: "password" }
      };
    }
  });

  const authContext = await authService.authenticate({
    headers: {
      authorization: "Bearer signed.jwt.token",
      "x-user-id": "attacker-controlled"
    }
  });

  assert.deepEqual(calls, ["signed.jwt.token"]);
  assert.deepEqual(authContext, {
    userId: "firebase-user-123",
    email: "user@example.com",
    emailVerified: true,
    provider: "password"
  });
});

test("auth service rejects requests without a bearer token", async () => {
  const authService = createAuthService({
    verifyToken: async () => {
      throw new Error("should not run");
    }
  });

  await assert.rejects(
    authService.authenticate({ headers: {} }),
    AuthenticationError
  );
});

test("auth service rejects unverified password identities", async () => {
  const authService = createAuthService({
    verifyToken: async () => ({
      sub: "firebase-user-123",
      email: "user@example.com",
      email_verified: false,
      firebase: { sign_in_provider: "password" }
    })
  });

  await assert.rejects(
    authService.authenticate({
      headers: { authorization: "Bearer signed.jwt.token" }
    }),
    AuthorizationError
  );
});
