import assert from "node:assert/strict";
import { Readable } from "node:stream";
import test from "node:test";
import { handleRequest } from "../../../src/main.js";

function createResponseCapture() {
  return {
    statusCode: undefined,
    body: undefined,
    writeHead(statusCode) {
      this.statusCode = statusCode;
    },
    end(body) {
      if (body) this.body = JSON.parse(body);
    },
  };
}

function createJsonRequest(method, url, body, headers = {}) {
  const json = body ? JSON.stringify(body) : "";
  const stream = Readable.from(json ? [Buffer.from(json)] : []);
  stream.method = method;
  stream.url = url;
  stream.headers = {
    "content-type": "application/json",
    ...headers,
  };
  return stream;
}

function buildContext({
  authenticated = true,
  createResult = null,
  joinResult = null,
  listResult = null,
  getResult = null,
  membersResult = null,
  leaveResult = null,
  removeResult = null,
  shouldFail = false,
  failError = null,
} = {}) {
  const defaultSquad = {
    id: "squad-1",
    name: "Test Squad",
    description: null,
    inviteCode: "ABCD1234",
    createdBy: "profile-1",
    createdAt: "2026-03-19T00:00:00.000Z",
    memberCount: 1,
  };

  return {
    config: { appName: "vestiaire-api", nodeEnv: "test" },
    authService: {
      async authenticate(req) {
        if (!authenticated) {
          const { AuthenticationError } = await import(
            "../../../src/modules/auth/service.js"
          );
          throw new AuthenticationError("Unauthorized");
        }
        return {
          userId: "firebase-user-123",
          email: "user@example.com",
          emailVerified: true,
          provider: "google.com",
        };
      },
    },
    profileService: {},
    itemService: {
      async createItemForUser() { return { item: { id: "item-1" } }; },
      async listItemsForUser() { return { items: [] }; },
      async getItemForUser(_, id) { return { item: { id } }; },
      async updateItemForUser() { return { item: {} }; },
    },
    uploadService: {},
    backgroundRemovalService: {},
    categorizationService: {},
    calendarEventRepo: {},
    calendarService: {},
    outfitGenerationService: {},
    outfitRepository: { async listOutfits() { return []; } },
    usageLimitService: {},
    wearLogRepository: {},
    analyticsRepository: {},
    analyticsSummaryService: {},
    userStatsRepo: { async getUserStats() { return {}; } },
    stylePointsService: {},
    levelService: {},
    streakService: {},
    badgeRepo: {},
    badgeService: {},
    challengeRepo: {},
    challengeService: {},
    subscriptionSyncService: {},
    premiumGuard: {},
    resaleListingService: {},
    resaleHistoryRepo: {},
    shoppingScanService: {},
    shoppingScanRepo: {},
    squadService: {
      async createSquad(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 400, code: "BAD_REQUEST", message: "Bad input" };
        return createResult ?? { squad: { ...defaultSquad, name: data.name, description: data.description } };
      },
      async joinSquad(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 404, code: "INVALID_INVITE_CODE", message: "Not Found" };
        return joinResult ?? { squad: defaultSquad };
      },
      async listMySquads(authContext) {
        return listResult ?? { squads: [] };
      },
      async getSquad(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 404, code: "NOT_FOUND", message: "Squad not found" };
        return getResult ?? { squad: defaultSquad };
      },
      async listMembers(authContext, data) {
        return membersResult ?? { members: [] };
      },
      async leaveSquad(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 404, code: "NOT_FOUND", message: "Not a member" };
        return leaveResult ?? { success: true };
      },
      async removeMember(authContext, data) {
        if (shouldFail) throw failError || { statusCode: 403, code: "FORBIDDEN", message: "Not admin" };
        return removeResult ?? { success: true };
      },
    },
  };
}

// POST /v1/squads
test("POST /v1/squads returns 201 with created squad and invite code", async () => {
  const req = createJsonRequest("POST", "/v1/squads", {
    name: "My Squad",
    description: "Test desc",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 201);
  assert.ok(res.body.squad);
  assert.equal(res.body.squad.name, "My Squad");
  assert.ok(res.body.squad.inviteCode);
});

test("POST /v1/squads returns 400 for missing name", async () => {
  const req = createJsonRequest("POST", "/v1/squads", { name: "" }, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(
    req,
    res,
    buildContext({ shouldFail: true, failError: { statusCode: 400, code: "BAD_REQUEST", message: "Name is required" } })
  );

  assert.equal(res.statusCode, 400);
});

test("POST /v1/squads returns 401 without auth", async () => {
  const req = createJsonRequest("POST", "/v1/squads", { name: "Squad" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});

// GET /v1/squads
test("GET /v1/squads returns 200 with user squads list", async () => {
  const squads = [
    { id: "s1", name: "Squad 1", memberCount: 3 },
    { id: "s2", name: "Squad 2", memberCount: 5 },
  ];
  const req = createJsonRequest("GET", "/v1/squads", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ listResult: { squads } }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.squads.length, 2);
});

test("GET /v1/squads returns empty array for user with no squads", async () => {
  const req = createJsonRequest("GET", "/v1/squads", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.squads.length, 0);
});

// POST /v1/squads/join
test("POST /v1/squads/join returns 200 with squad on valid code", async () => {
  const req = createJsonRequest("POST", "/v1/squads/join", {
    inviteCode: "ABCD1234",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.squad);
});

test("POST /v1/squads/join returns 404 for invalid code", async () => {
  const req = createJsonRequest("POST", "/v1/squads/join", {
    inviteCode: "INVALID1",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 404, code: "INVALID_INVITE_CODE", message: "Not Found" },
  }));

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.code, "INVALID_INVITE_CODE");
});

test("POST /v1/squads/join returns 422 for full squad", async () => {
  const req = createJsonRequest("POST", "/v1/squads/join", {
    inviteCode: "FULL1234",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 422, code: "SQUAD_FULL", message: "Squad Full" },
  }));

  assert.equal(res.statusCode, 422);
  assert.equal(res.body.code, "SQUAD_FULL");
});

test("POST /v1/squads/join returns 409 for already-member", async () => {
  const req = createJsonRequest("POST", "/v1/squads/join", {
    inviteCode: "DUPE1234",
  }, { authorization: "Bearer test-token" });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 409, code: "ALREADY_MEMBER", message: "Already a member" },
  }));

  assert.equal(res.statusCode, 409);
});

// GET /v1/squads/:id
test("GET /v1/squads/:id returns 200 for member", async () => {
  const req = createJsonRequest("GET", "/v1/squads/squad-1", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.squad);
});

test("GET /v1/squads/:id returns 404 for non-member", async () => {
  const req = createJsonRequest("GET", "/v1/squads/nonexistent", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 404, code: "NOT_FOUND", message: "Squad not found" },
  }));

  assert.equal(res.statusCode, 404);
});

// GET /v1/squads/:id/members
test("GET /v1/squads/:id/members returns 200 with member list", async () => {
  const members = [
    { id: "m1", userId: "p1", role: "admin", displayName: "Alice" },
    { id: "m2", userId: "p2", role: "member", displayName: "Bob" },
  ];
  const req = createJsonRequest("GET", "/v1/squads/squad-1/members", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ membersResult: { members } }));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.members.length, 2);
});

// DELETE /v1/squads/:id/members/me
test("DELETE /v1/squads/:id/members/me returns 204 on leave", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/squad-1/members/me", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 204);
});

// DELETE /v1/squads/:id/members/:memberId
test("DELETE /v1/squads/:id/members/:memberId returns 204 on admin remove", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/squad-1/members/profile-2", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext());

  assert.equal(res.statusCode, 204);
});

test("DELETE /v1/squads/:id/members/:memberId returns 403 for non-admin", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/squad-1/members/profile-2", null, {
    authorization: "Bearer test-token",
  });
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({
    shouldFail: true,
    failError: { statusCode: 403, code: "FORBIDDEN", message: "Only squad admins can remove members" },
  }));

  assert.equal(res.statusCode, 403);
});

test("DELETE /v1/squads/:id/members/:memberId returns 401 without auth", async () => {
  const req = createJsonRequest("DELETE", "/v1/squads/squad-1/members/profile-2");
  const res = createResponseCapture();

  await handleRequest(req, res, buildContext({ authenticated: false }));

  assert.equal(res.statusCode, 401);
});
