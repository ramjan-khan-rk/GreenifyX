import test from "node:test";
import assert from "node:assert/strict";
import { buildMessage, prefKeyFor, wantsPush, pushEnabled } from "../utils/push.js";

test("notification types map to the right preference", () => {
  assert.equal(prefKeyFor("message"), "messages");
  assert.equal(prefKeyFor("call"), "calls");
  assert.equal(prefKeyFor("reward"), "points");
  assert.equal(prefKeyFor("event"), "campaigns");
  assert.equal(prefKeyFor("like"), "social");
});

test("muted categories are not pushed", () => {
  assert.equal(wantsPush({ notificationPrefs: { messages: false } }, "message"), false);
  assert.equal(wantsPush({ notificationPrefs: { messages: false } }, "call"), true);
  assert.equal(wantsPush({}, "like"), true);
});

test("FCM message carries routing data and high priority for chats", () => {
  const m = buildMessage("tok", { _id: "n1", type: "message", title: "Sara", message: "Hi!", sender: "u2", referenceId: "u2" });
  assert.equal(m.message.token, "tok");
  assert.equal(m.message.notification.title, "Sara");
  assert.equal(m.message.data.type, "message");
  assert.equal(m.message.data.senderId, "u2");
  assert.equal(m.message.android.priority, "HIGH");
});

test("push stays off without a service account", () => {
  assert.equal(pushEnabled(), Boolean(process.env.FIREBASE_SERVICE_ACCOUNT));
});
