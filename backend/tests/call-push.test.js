import assert from "node:assert/strict";
import { test } from "node:test";
import { callPayload, fcmCallMessage, newCallId, newDeclineToken } from "../utils/callPush.js";

const call = { callId: "c1", from: "u123", fromName: "Sara", video: true, declineToken: "tok" };

test("call payload carries what the phone needs to ring and decline", () => {
  const p = callPayload(call);
  assert.equal(p.id, "c1");
  assert.equal(p.nameCaller, "Sara");
  assert.equal(p.isVideo, true);
  assert.equal(p.callerId, "u123");
  assert.equal(p.declineToken, "tok");
  assert.match(p.api, /\/api$/);
});

test("FCM call message is data-only, high priority, all strings", () => {
  const m = fcmCallMessage("device-token", "incoming_call", call).message;
  assert.equal(m.notification, undefined);
  assert.equal(m.android.priority, "HIGH");
  assert.equal(m.data.type, "incoming_call");
  assert.equal(m.data.isVideo, "true");
  for (const v of Object.values(m.data)) assert.equal(typeof v, "string");
});

test("ids and decline tokens are unique", () => {
  assert.notEqual(newCallId(), newCallId());
  assert.ok(newDeclineToken().length >= 20);
});
