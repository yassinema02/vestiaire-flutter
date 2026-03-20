import assert from "node:assert/strict";
import test from "node:test";
import {
  createSquadService,
  generateInviteCode,
  validateSquadInput,
} from "../../../src/modules/squads/squad-service.js";

const testAuthContext = { userId: "firebase-user-123" };

function createMockSquadRepo({
  squads = [],
  memberCount = 0,
  membership = null,
  members = [],
  profileId = "profile-1",
} = {}) {
  const calls = [];
  return {
    calls,
    async createSquad(authContext, data) {
      calls.push({ method: "createSquad", authContext, data });
      return {
        id: "squad-1",
        name: data.name,
        description: data.description,
        inviteCode: data.inviteCode,
        createdBy: profileId,
        createdAt: "2026-03-19T00:00:00.000Z",
        updatedAt: "2026-03-19T00:00:00.000Z",
        memberCount: 1,
      };
    },
    async getSquadByInviteCode(inviteCode) {
      calls.push({ method: "getSquadByInviteCode", inviteCode });
      const found = squads.find((s) => s.inviteCode === inviteCode);
      return found ?? null;
    },
    async getSquadById(authContext, squadId) {
      calls.push({ method: "getSquadById", authContext, squadId });
      const found = squads.find((s) => s.id === squadId);
      return found ?? null;
    },
    async listSquadsForUser(authContext) {
      calls.push({ method: "listSquadsForUser", authContext });
      return squads;
    },
    async getSquadMemberCount(squadId) {
      calls.push({ method: "getSquadMemberCount", squadId });
      return memberCount;
    },
    async addMember(squadId, userId, role) {
      calls.push({ method: "addMember", squadId, userId, role });
    },
    async removeMember(squadId, memberId) {
      calls.push({ method: "removeMember", squadId, memberId });
    },
    async getMembership(squadId, userId) {
      calls.push({ method: "getMembership", squadId, userId });
      if (membership && membership.squadId === squadId && membership.userId === userId) {
        return membership;
      }
      return null;
    },
    async listMembers(authContext, squadId) {
      calls.push({ method: "listMembers", authContext, squadId });
      return members;
    },
    async softDeleteSquad(squadId) {
      calls.push({ method: "softDeleteSquad", squadId });
    },
    async transferOwnership(squadId, newOwnerId) {
      calls.push({ method: "transferOwnership", squadId, newOwnerId });
    },
    async getProfileIdForUser(userId) {
      calls.push({ method: "getProfileIdForUser", userId });
      return profileId;
    },
  };
}

test("generateInviteCode produces 8-char alphanumeric strings", () => {
  for (let i = 0; i < 10; i++) {
    const code = generateInviteCode();
    assert.equal(code.length, 8);
    assert.match(code, /^[A-Z0-9_-]{8}$/i);
  }
});

test("validateSquadInput rejects empty name", () => {
  assert.throws(
    () => validateSquadInput({ name: "" }),
    (err) => err.statusCode === 400
  );
});

test("validateSquadInput rejects null name", () => {
  assert.throws(
    () => validateSquadInput({ name: null }),
    (err) => err.statusCode === 400
  );
});

test("validateSquadInput rejects name > 50 chars", () => {
  assert.throws(
    () => validateSquadInput({ name: "A".repeat(51) }),
    (err) => err.statusCode === 400
  );
});

test("validateSquadInput rejects description > 200 chars", () => {
  assert.throws(
    () => validateSquadInput({ name: "Valid", description: "X".repeat(201) }),
    (err) => err.statusCode === 400
  );
});

test("validateSquadInput accepts valid input", () => {
  assert.doesNotThrow(() =>
    validateSquadInput({ name: "My Squad", description: "A description" })
  );
});

test("validateSquadInput accepts name with only whitespace as invalid", () => {
  assert.throws(
    () => validateSquadInput({ name: "   " }),
    (err) => err.statusCode === 400
  );
});

test("validateSquadInput rejects non-string description", () => {
  assert.throws(
    () => validateSquadInput({ name: "Valid", description: 123 }),
    (err) => err.statusCode === 400
  );
});

test("createSquad validates name and creates squad + admin membership", async () => {
  const repo = createMockSquadRepo();
  const service = createSquadService({ squadRepo: repo });

  const result = await service.createSquad(testAuthContext, {
    name: "Test Squad",
    description: "A test squad",
  });

  assert.equal(result.squad.name, "Test Squad");
  assert.equal(result.squad.memberCount, 1);
  assert.ok(repo.calls.some((c) => c.method === "createSquad"));
});

test("createSquad generates 8-char invite code", async () => {
  const repo = createMockSquadRepo();
  const service = createSquadService({ squadRepo: repo });

  await service.createSquad(testAuthContext, { name: "Squad" });

  const createCall = repo.calls.find((c) => c.method === "createSquad");
  assert.ok(createCall);
  assert.equal(createCall.data.inviteCode.length, 8);
});

test("createSquad rejects empty name with 400", async () => {
  const repo = createMockSquadRepo();
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.createSquad(testAuthContext, { name: "" }),
    (err) => err.statusCode === 400
  );
});

test("createSquad rejects name > 50 chars with 400", async () => {
  const repo = createMockSquadRepo();
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.createSquad(testAuthContext, { name: "A".repeat(51) }),
    (err) => err.statusCode === 400
  );
});

test("joinSquad finds squad by invite code and adds member", async () => {
  const squad = {
    id: "squad-1",
    name: "Test Squad",
    inviteCode: "ABCD1234",
    createdBy: "other-profile",
  };
  const repo = createMockSquadRepo({ squads: [squad], memberCount: 5 });
  const service = createSquadService({ squadRepo: repo });

  const result = await service.joinSquad(testAuthContext, {
    inviteCode: "ABCD1234",
  });

  assert.equal(result.squad.id, "squad-1");
  assert.ok(repo.calls.some((c) => c.method === "addMember"));
});

test("joinSquad returns 404 for invalid invite code", async () => {
  const repo = createMockSquadRepo({ squads: [] });
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.joinSquad(testAuthContext, { inviteCode: "INVALID1" }),
    (err) => err.statusCode === 404 && err.code === "INVALID_INVITE_CODE"
  );
});

test("joinSquad returns 422 when squad has 20 members (SQUAD_FULL)", async () => {
  const squad = {
    id: "squad-1",
    name: "Full Squad",
    inviteCode: "FULL1234",
    createdBy: "other-profile",
  };
  const repo = createMockSquadRepo({ squads: [squad], memberCount: 20 });
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.joinSquad(testAuthContext, { inviteCode: "FULL1234" }),
    (err) => err.statusCode === 422 && err.code === "SQUAD_FULL"
  );
});

test("joinSquad returns 409 when user is already a member", async () => {
  const squad = {
    id: "squad-1",
    name: "Test Squad",
    inviteCode: "DUPE1234",
    createdBy: "other-profile",
  };
  const membership = { squadId: "squad-1", userId: "profile-1", role: "member" };
  const repo = createMockSquadRepo({
    squads: [squad],
    memberCount: 5,
    membership,
  });
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.joinSquad(testAuthContext, { inviteCode: "DUPE1234" }),
    (err) => err.statusCode === 409 && err.code === "ALREADY_MEMBER"
  );
});

test("listMySquads returns all squads for user", async () => {
  const squads = [
    { id: "s1", name: "Squad 1", memberCount: 3 },
    { id: "s2", name: "Squad 2", memberCount: 5 },
  ];
  const repo = createMockSquadRepo({ squads });
  const service = createSquadService({ squadRepo: repo });

  const result = await service.listMySquads(testAuthContext);

  assert.equal(result.squads.length, 2);
});

test("getSquad returns squad details for member", async () => {
  const squads = [{ id: "squad-1", name: "My Squad", memberCount: 4 }];
  const repo = createMockSquadRepo({ squads });
  const service = createSquadService({ squadRepo: repo });

  const result = await service.getSquad(testAuthContext, { squadId: "squad-1" });

  assert.equal(result.squad.name, "My Squad");
});

test("getSquad returns 404 for non-member", async () => {
  const repo = createMockSquadRepo({ squads: [] });
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.getSquad(testAuthContext, { squadId: "nonexistent" }),
    (err) => err.statusCode === 404
  );
});

test("removeMember removes member when caller is admin", async () => {
  const membership = { squadId: "squad-1", userId: "profile-1", role: "admin" };
  const repo = createMockSquadRepo({ membership });
  const service = createSquadService({ squadRepo: repo });

  const result = await service.removeMember(testAuthContext, {
    squadId: "squad-1",
    memberId: "other-profile",
  });

  assert.equal(result.success, true);
  assert.ok(repo.calls.some((c) => c.method === "removeMember" && c.memberId === "other-profile"));
});

test("removeMember returns 403 when caller is not admin", async () => {
  const membership = { squadId: "squad-1", userId: "profile-1", role: "member" };
  const repo = createMockSquadRepo({ membership });
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.removeMember(testAuthContext, { squadId: "squad-1", memberId: "other-profile" }),
    (err) => err.statusCode === 403
  );
});

test("removeMember returns 403 when trying to remove the admin", async () => {
  const membership = { squadId: "squad-1", userId: "profile-1", role: "admin" };
  const repo = createMockSquadRepo({ membership, profileId: "profile-1" });
  const service = createSquadService({ squadRepo: repo });

  await assert.rejects(
    () => service.removeMember(testAuthContext, { squadId: "squad-1", memberId: "profile-1" }),
    (err) => err.statusCode === 403
  );
});

test("leaveSquad removes caller membership", async () => {
  const membership = { squadId: "squad-1", userId: "profile-1", role: "member" };
  const squads = [{ id: "squad-1", name: "Squad" }];
  const repo = createMockSquadRepo({ membership, squads });
  const service = createSquadService({ squadRepo: repo });

  const result = await service.leaveSquad(testAuthContext, { squadId: "squad-1" });

  assert.equal(result.success, true);
  assert.ok(repo.calls.some((c) => c.method === "removeMember" && c.memberId === "profile-1"));
});

test("leaveSquad transfers ownership when admin leaves with remaining members", async () => {
  const membership = { squadId: "squad-1", userId: "profile-1", role: "admin" };
  const members = [
    { userId: "profile-1", role: "admin" },
    { userId: "profile-2", role: "member" },
  ];
  const squads = [{ id: "squad-1", name: "Squad" }];
  const repo = createMockSquadRepo({ membership, members, squads });
  const service = createSquadService({ squadRepo: repo });

  await service.leaveSquad(testAuthContext, { squadId: "squad-1" });

  assert.ok(repo.calls.some((c) => c.method === "transferOwnership" && c.newOwnerId === "profile-2"));
  assert.ok(repo.calls.some((c) => c.method === "removeMember" && c.memberId === "profile-1"));
  assert.ok(!repo.calls.some((c) => c.method === "softDeleteSquad"));
});

test("leaveSquad soft-deletes squad when last member leaves", async () => {
  const membership = { squadId: "squad-1", userId: "profile-1", role: "admin" };
  const members = [{ userId: "profile-1", role: "admin" }];
  const squads = [{ id: "squad-1", name: "Squad" }];
  const repo = createMockSquadRepo({ membership, members, squads });
  const service = createSquadService({ squadRepo: repo });

  await service.leaveSquad(testAuthContext, { squadId: "squad-1" });

  assert.ok(repo.calls.some((c) => c.method === "softDeleteSquad" && c.squadId === "squad-1"));
  assert.ok(repo.calls.some((c) => c.method === "removeMember" && c.memberId === "profile-1"));
});
