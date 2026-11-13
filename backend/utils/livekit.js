import crypto from "crypto";

/**
 * LiveKit access tokens (HS256 JWT) without the SDK.
 * Set LIVEKIT_URL (wss://…livekit.cloud), LIVEKIT_API_KEY and LIVEKIT_API_SECRET on the server.
 */
export const liveEnabled = () => Boolean(process.env.LIVEKIT_URL && process.env.LIVEKIT_API_KEY && process.env.LIVEKIT_API_SECRET);
export const liveUrl = () => process.env.LIVEKIT_URL;

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");

export const liveToken = ({ room, identity, name, canPublish, ttlSec = 4 * 3600, now = Math.floor(Date.now() / 1000), key = process.env.LIVEKIT_API_KEY, secret = process.env.LIVEKIT_API_SECRET }) => {
  const head = b64({ alg: "HS256", typ: "JWT" });
  const body = b64({
    iss: key,
    sub: String(identity),
    name: String(name || "").slice(0, 60),
    nbf: now - 10,
    exp: now + ttlSec,
    video: { room, roomJoin: true, canPublish: Boolean(canPublish), canSubscribe: true, canPublishData: true },
  });
  const sig = crypto.createHmac("sha256", secret).update(`${head}.${body}`).digest("base64url");
  return `${head}.${body}.${sig}`;
};
