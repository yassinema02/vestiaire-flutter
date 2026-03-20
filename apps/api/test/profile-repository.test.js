import assert from "node:assert/strict";
import test from "node:test";
import { createProfileRepository } from "../src/modules/profiles/repository.js";

function createClientStub(responses) {
  const queries = [];
  let released = false;

  return {
    client: {
      async query(sql, params = []) {
        queries.push({
          sql: String(sql).replace(/\s+/gu, " ").trim(),
          params
        });

        if (responses.length === 0) {
          return { rows: [] };
        }

        return responses.shift();
      },
      release() {
        released = true;
      }
    },
    getQueries() {
      return queries;
    },
    wasReleased() {
      return released;
    }
  };
}

test("profile repository sets app.current_user_id before provisioning", async () => {
  const stub = createClientStub([
    { rows: [] },
    { rows: [] },
    {
      rows: [
        {
          id: "profile-1",
          firebase_uid: "firebase-user-123",
          email: "user@example.com",
          auth_provider: "google.com",
          email_verified: true,
          created_at: "2026-03-10T10:00:00.000Z",
          updated_at: "2026-03-10T10:00:00.000Z"
        }
      ]
    },
    { rows: [] }
  ]);

  const repo = createProfileRepository({
    pool: {
      async connect() {
        return stub.client;
      }
    }
  });

  const result = await repo.getOrCreateProfile({
    userId: "firebase-user-123",
    email: "user@example.com",
    emailVerified: true,
    provider: "google.com"
  });

  assert.equal(result.created, true);
  assert.equal(stub.getQueries()[1].sql, "select set_config('app.current_user_id', $1, true)");
  assert.deepEqual(stub.getQueries()[1].params, ["firebase-user-123"]);
  assert.equal(stub.wasReleased(), true);
});

test("profile repository returns the existing row when provisioning repeats", async () => {
  const stub = createClientStub([
    { rows: [] },
    { rows: [] },
    { rows: [] },
    {
      rows: [
        {
          id: "profile-1",
          firebase_uid: "firebase-user-123",
          email: "user@example.com",
          auth_provider: "password",
          email_verified: true,
          created_at: "2026-03-10T10:00:00.000Z",
          updated_at: "2026-03-10T10:00:00.000Z"
        }
      ]
    },
    { rows: [] }
  ]);

  const repo = createProfileRepository({
    pool: {
      async connect() {
        return stub.client;
      }
    }
  });

  const result = await repo.getOrCreateProfile({
    userId: "firebase-user-123",
    email: "user@example.com",
    emailVerified: true,
    provider: "password"
  });

  assert.equal(result.created, false);
  assert.equal(result.profile.firebaseUid, "firebase-user-123");
  assert.match(stub.getQueries()[2].sql, /insert into app_public\.profiles/i);
  assert.match(stub.getQueries()[3].sql, /select \* from app_public\.profiles/i);
});
