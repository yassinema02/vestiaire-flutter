import assert from "node:assert/strict";
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

test("GET /v1/profiles/me rejects unauthenticated requests", async () => {
  const response = createResponseCapture();

  await handleRequest(
    { method: "GET", url: "/v1/profiles/me", headers: {} },
    response,
    {
      config: { appName: "vestiaire-api", nodeEnv: "test" },
      authService: {
        async authenticate() {
          throw new Error("should not be called");
        }
      },
      profileService: {
        async getProfileForAuthenticatedUser() {
          throw new Error("should not be called");
        }
      }
    }
  );

  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "Unauthorized");
});

test("GET /v1/profiles/me provisions and returns the authenticated profile", async () => {
  const response = createResponseCapture();

  await handleRequest(
    {
      method: "GET",
      url: "/v1/profiles/me",
      headers: {
        authorization: "Bearer signed.jwt.token",
        "x-user-id": "attacker-controlled"
      }
    },
    response,
    {
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
        async getProfileForAuthenticatedUser(authContext) {
          return {
            provisioned: true,
            profile: {
              id: "profile-1",
              firebaseUid: authContext.userId,
              email: authContext.email,
              authProvider: authContext.provider,
              emailVerified: authContext.emailVerified
            }
          };
        }
      }
    }
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(JSON.parse(response.body), {
    profile: {
      id: "profile-1",
      firebaseUid: "firebase-user-123",
      email: "user@example.com",
      authProvider: "google.com",
      emailVerified: true
    },
    provisioned: true
  });
});

test("GET /v1/profiles/me rejects unverified email identities", async () => {
  const response = createResponseCapture();

  await handleRequest(
    {
      method: "GET",
      url: "/v1/profiles/me",
      headers: {
        authorization: "Bearer signed.jwt.token"
      }
    },
    response,
    {
      config: { appName: "vestiaire-api", nodeEnv: "test" },
      authService: {
        async authenticate() {
          const error = new Error("Email verification required");
          error.statusCode = 403;
          error.code = "EMAIL_VERIFICATION_REQUIRED";
          throw error;
        }
      },
      profileService: {
        async getProfileForAuthenticatedUser() {
          throw new Error("should not be called");
        }
      }
    }
  );

  assert.equal(response.statusCode, 403);
  assert.equal(JSON.parse(response.body).error, "Forbidden");
});
