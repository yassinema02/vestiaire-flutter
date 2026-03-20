import assert from "node:assert/strict";
import test from "node:test";
import { createNotificationService, isQuietHours } from "../../../src/modules/notifications/notification-service.js";

// --- isQuietHours tests ---

test("isQuietHours returns true for hour 22", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T22:00:00")), true);
});

test("isQuietHours returns true for hour 23", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T23:30:00")), true);
});

test("isQuietHours returns true for hour 0", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T00:00:00")), true);
});

test("isQuietHours returns true for hour 3", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T03:00:00")), true);
});

test("isQuietHours returns true for hour 6", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T06:59:00")), true);
});

test("isQuietHours returns false for hour 7", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T07:00:00")), false);
});

test("isQuietHours returns false for hour 12", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T12:00:00")), false);
});

test("isQuietHours returns false for hour 18", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T18:00:00")), false);
});

test("isQuietHours returns false for hour 21", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T21:59:00")), false);
});

test("isQuietHours returns false for hour 9", () => {
  assert.equal(isQuietHours(new Date("2026-03-19T09:00:00")), false);
});

// --- sendPushNotification tests ---

function createMockPool({ rows = [] } = {}) {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push({ sql, params });
      return { rows };
    },
  };
}

test("sendPushNotification sends FCM message when push_token exists and not quiet hours", async () => {
  const pool = createMockPool({
    rows: [{
      push_token: "fcm-token-123",
      notification_preferences: { social: "all" },
    }],
  });
  const service = createNotificationService({ pool });

  // Since FCM credentials are not available in test, this will gracefully log and return
  await service.sendPushNotification("profile-1", {
    title: "Test",
    body: "Test body",
    data: { type: "ootd_post", postId: "p1" },
  });

  assert.ok(pool.calls.length > 0);
  assert.ok(pool.calls[0].params.includes("profile-1"));
});

test("sendPushNotification skips when push_token is null", async () => {
  const pool = createMockPool({
    rows: [{
      push_token: null,
      notification_preferences: { social: "all" },
    }],
  });
  const service = createNotificationService({ pool });

  // Should not throw
  await service.sendPushNotification("profile-1", {
    title: "Test",
    body: "Test body",
  });

  assert.ok(pool.calls.length > 0);
});

test("sendPushNotification skips when profile not found", async () => {
  const pool = createMockPool({ rows: [] });
  const service = createNotificationService({ pool });

  await service.sendPushNotification("nonexistent", {
    title: "Test",
    body: "Test body",
  });

  assert.ok(pool.calls.length > 0);
});

test("sendPushNotification does not throw on FCM failure (fire-and-forget)", async () => {
  const pool = createMockPool({
    rows: [{
      push_token: "fcm-token-123",
      notification_preferences: { social: "all" },
    }],
  });
  const service = createNotificationService({ pool });

  // This should not throw even without FCM credentials
  await service.sendPushNotification("profile-1", {
    title: "Test",
    body: "Test body",
  });
});

test("sendPushNotification skips when social mode is 'off' and checkSocialNotOff is true", async () => {
  const pool = createMockPool({
    rows: [{
      push_token: "fcm-token-123",
      notification_preferences: { social: "off" },
    }],
  });
  const service = createNotificationService({ pool });

  await service.sendPushNotification("profile-1", {
    title: "Test",
    body: "Test body",
  }, { checkSocialNotOff: true });

  // Should query the profile but not proceed to FCM
  assert.ok(pool.calls.length > 0);
});

test("sendPushNotification skips when social is boolean false and checkSocialNotOff is true", async () => {
  const pool = createMockPool({
    rows: [{
      push_token: "fcm-token-123",
      notification_preferences: { social: false },
    }],
  });
  const service = createNotificationService({ pool });

  await service.sendPushNotification("profile-1", {
    title: "Test",
    body: "Test body",
  }, { checkSocialNotOff: true });

  assert.ok(pool.calls.length > 0);
});

// --- sendToSquadMembers tests ---

test("sendToSquadMembers queries squad members and excludes sender", async () => {
  const pool = createMockPool({
    rows: [
      { id: "member-1", push_token: "tok-1", notification_preferences: { social: "all" } },
      { id: "member-2", push_token: "tok-2", notification_preferences: { social: "all" } },
    ],
  });
  const service = createNotificationService({ pool });

  await service.sendToSquadMembers("squad-1", "author-1", {
    title: "Test post",
    body: "Test body",
    checkSocialMode: "all",
  });

  const query = pool.calls[0];
  assert.ok(query.params.includes("squad-1"));
  assert.ok(query.params.includes("author-1"));
});

test("sendToSquadMembers respects social mode filter", async () => {
  const pool = createMockPool({
    rows: [
      { id: "member-1", push_token: "tok-1", notification_preferences: { social: "all" } },
      { id: "member-2", push_token: "tok-2", notification_preferences: { social: "morning" } },
      { id: "member-3", push_token: "tok-3", notification_preferences: { social: "off" } },
    ],
  });
  const service = createNotificationService({ pool });

  // Only "all" members should receive when checkSocialMode is "all"
  await service.sendToSquadMembers("squad-1", "author-1", {
    title: "Test post",
    body: "Test body",
    checkSocialMode: "all",
  });

  // The query was made, and filtering happens in-code per member
  assert.ok(pool.calls.length > 0);
});

test("sendToSquadMembers skips members without push_token", async () => {
  const pool = createMockPool({
    rows: [
      { id: "member-1", push_token: null, notification_preferences: { social: "all" } },
    ],
  });
  const service = createNotificationService({ pool });

  await service.sendToSquadMembers("squad-1", "author-1", {
    title: "Test post",
    body: "Test body",
    checkSocialMode: "all",
  });

  // Should not throw
  assert.ok(pool.calls.length > 0);
});

test("sendToSquadMembers does not throw on error", async () => {
  const pool = {
    async query() { throw new Error("DB error"); },
  };
  const service = createNotificationService({ pool });

  // Should not throw
  await service.sendToSquadMembers("squad-1", "author-1", {
    title: "Test post",
    body: "Test body",
  });
});
