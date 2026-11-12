import crypto from "crypto";

/**
 * Firebase Cloud Messaging (HTTP v1) without extra dependencies.
 * Enabled only when FIREBASE_SERVICE_ACCOUNT holds the service-account JSON
 * (paste it into the Render environment — never commit it).
 */

const PREF_FOR_TYPE = {
  message: "messages",
  call: "calls",
  friend_request: "social",
  friend_accept: "social",
  like: "social",
  comment: "social",
  tag: "social",
  challenge: "social",
  challenge_accept: "social",
  challenge_reject: "social",
  challenge_complete: "social",
  campaign: "campaigns",
  event: "campaigns",
  verification: "points",
  points: "points",
  reward: "points",
  pickup: "points",
};

export const prefKeyFor = (type) => PREF_FOR_TYPE[type] || "social";

/** Should this user get a push for a notification of this type? */
export const wantsPush = (user, type) => user?.notificationPrefs?.[prefKeyFor(type)] !== false;

/** FCM v1 message body for one device token. */
export const buildMessage = (token, n) => ({
  message: {
    token,
    notification: { title: String(n.title || "GreenifyX").slice(0, 120), body: String(n.message || "").slice(0, 240) },
    data: {
      type: String(n.type || ""),
      notificationId: String(n._id || ""),
      referenceId: n.referenceId ? String(n.referenceId) : "",
      senderId: n.sender ? String(n.sender) : "",
    },
    android: {
      priority: n.type === "call" || n.type === "message" ? "HIGH" : "NORMAL",
      notification: { channel_id: n.type === "message" || n.type === "call" ? "messages" : "general", sound: "default" },
    },
    apns: { payload: { aps: { sound: "default" } } },
  },
});

let account;
let cachedToken = { value: null, exp: 0 };

const loadAccount = () => {
  if (account !== undefined) return account;
  try {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
    account = raw ? JSON.parse(raw) : null;
    if (account?.private_key) account.private_key = account.private_key.replace(/\\n/g, "\n");
  } catch {
    console.error("FIREBASE_SERVICE_ACCOUNT is not valid JSON; push disabled");
    account = null;
  }
  return account;
};

export const pushEnabled = () => Boolean(loadAccount()?.client_email);

const b64url = (v) => Buffer.from(typeof v === "string" ? v : JSON.stringify(v)).toString("base64url");

const accessToken = async () => {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken.value && cachedToken.exp - 60 > now) return cachedToken.value;
  const acc = loadAccount();
  const unsigned = `${b64url({ alg: "RS256", typ: "JWT" })}.${b64url({
    iss: acc.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = crypto.createSign("RSA-SHA256").update(unsigned).sign(acc.private_key).toString("base64url");
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${signature}` }),
  });
  if (!res.ok) throw new Error(`FCM auth failed (${res.status})`);
  const data = await res.json();
  cachedToken = { value: data.access_token, exp: now + (Number(data.expires_in) || 3600) };
  return cachedToken.value;
};

/** Send a stored Notification to all of the receiver's devices. Never throws. */
export const pushNotification = async (n) => {
  if (!pushEnabled() || !n?.receiver) return;
  try {
    const { default: User } = await import("../models/User.js");
    const user = await User.findById(n.receiver).select("pushTokens notificationPrefs");
    if (!user || !wantsPush(user, n.type) || !user.pushTokens?.length) return;
    const token = await accessToken();
    const project = loadAccount().project_id;
    const dead = [];
    await Promise.all(
      user.pushTokens.map(async (t) => {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
          body: JSON.stringify(buildMessage(t.token, n)),
        });
        if (res.status === 404 || res.status === 400) dead.push(t.token);
      })
    );
    if (dead.length) await User.updateOne({ _id: user._id }, { $pull: { pushTokens: { token: { $in: dead } } } });
  } catch (e) {
    console.error("Push send failed:", e.message);
  }
};
