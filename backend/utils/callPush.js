import crypto from "crypto";
import http2 from "http2";
import { pushEnabled, sendFcm } from "./push.js";

/**
 * Ringing a phone whose app is closed.
 *  - Android: a high-priority, data-only FCM message wakes the app, which shows the
 *    native full-screen incoming call with the ringtone (flutter_callkit_incoming).
 *  - iPhone: Apple only lets a closed app ring through a PushKit VoIP push, sent to APNs
 *    directly. Needs APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID (and optionally APNS_BUNDLE_ID,
 *    APNS_PRODUCTION=true for App Store / TestFlight builds).
 */

export const CALL_RING_SECONDS = 45;

/** Payload both platforms understand; field names match flutter_callkit_incoming. */
export const callPayload = (call) => ({
  id: call.callId,
  nameCaller: String(call.fromName || "Friend").slice(0, 60),
  handle: "GreenifyX",
  isVideo: call.video === true,
  callerId: String(call.from),
  declineToken: call.declineToken,
  api: process.env.PUBLIC_API_URL || "https://greenifyx.onrender.com/api",
});

/** FCM v1 data-only message (no notification block, so the app's handler always runs). */
export const fcmCallMessage = (token, kind, call) => {
  const p = callPayload(call);
  return {
    message: {
      token,
      data: Object.fromEntries(Object.entries({ type: kind, ...p }).map(([k, v]) => [k, String(v)])),
      android: { priority: "HIGH", ttl: `${CALL_RING_SECONDS}s` },
    },
  };
};

// ---------- APNs (iPhone VoIP) ----------

export const apnsConfigured = () => Boolean(process.env.APNS_KEY_P8 && process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID);

let apnsJwt = { value: null, at: 0 };
const apnsToken = () => {
  const now = Math.floor(Date.now() / 1000);
  if (apnsJwt.value && now - apnsJwt.at < 50 * 60) return apnsJwt.value;
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const unsigned = `${b64({ alg: "ES256", kid: process.env.APNS_KEY_ID })}.${b64({ iss: process.env.APNS_TEAM_ID, iat: now })}`;
  const key = String(process.env.APNS_KEY_P8).replace(/\\n/g, "\n");
  const sig = crypto.sign("sha256", Buffer.from(unsigned), { key, dsaEncoding: "ieee-p1363" }).toString("base64url");
  apnsJwt = { value: `${unsigned}.${sig}`, at: now };
  return apnsJwt.value;
};

export const sendVoipPush = (deviceToken, call) =>
  new Promise((resolve) => {
    if (!apnsConfigured()) return resolve(0);
    const host = process.env.APNS_PRODUCTION === "true" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
    let client;
    try {
      client = http2.connect(host);
    } catch {
      return resolve(0);
    }
    client.on("error", () => resolve(0));
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${apnsToken()}`,
      "apns-topic": `${process.env.APNS_BUNDLE_ID || "com.ramjankhan.greenifyx"}.voip`,
      "apns-push-type": "voip",
      "apns-priority": "10",
      "apns-expiration": "0",
    });
    let status = 0;
    req.on("response", (h) => (status = h[":status"]));
    req.on("end", () => {
      client.close();
      resolve(status);
    });
    req.on("error", () => {
      client.close();
      resolve(0);
    });
    req.end(JSON.stringify(callPayload(call)));
  });

/**
 * Ring all of a user's phones. Returns how many devices the ring was sent to.
 * kind: "incoming_call" to ring, "call_cancel" to stop ringing (Android only).
 */
export const ringDevices = async (user, kind, call) => {
  const tokens = user?.pushTokens || [];
  let sent = 0;
  for (const t of tokens) {
    try {
      if (t.platform === "ios_voip") {
        if (kind !== "incoming_call") continue; // CallKit times out by itself on iPhone
        const s = await sendVoipPush(t.token, call);
        if (s === 200) sent++;
        else console.log(`[call] VoIP push to …${String(t.token).slice(-6)} returned ${s || "no connection"}`);
      } else if (t.platform === "android" && pushEnabled()) {
        const s = await sendFcm(fcmCallMessage(t.token, kind, call));
        if (s === 200) sent++;
        else console.log(`[call] FCM ${kind} to …${String(t.token).slice(-6)} returned ${s}`);
      }
    } catch (e) {
      console.log(`[call] ring push failed: ${e.message}`);
    }
  }
  return sent;
};

export const newCallId = () => crypto.randomUUID();
export const newDeclineToken = () => crypto.randomBytes(18).toString("base64url");
