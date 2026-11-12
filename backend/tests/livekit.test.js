import test from "node:test";
import assert from "node:assert/strict";
import crypto from "crypto";
import { liveToken } from "../utils/livekit.js";

test("LiveKit token is a valid HS256 JWT with room grants", () => {
  const t = liveToken({ room: "r1", identity: "u1", name: "Sara", canPublish: true, key: "APIkey", secret: "s3cret", now: 1000 });
  const [h, b, s] = t.split(".");
  assert.equal(crypto.createHmac("sha256", "s3cret").update(`${h}.${b}`).digest("base64url"), s);
  const body = JSON.parse(Buffer.from(b, "base64url").toString());
  assert.equal(body.iss, "APIkey");
  assert.equal(body.video.room, "r1");
  assert.equal(body.video.canPublish, true);
  assert.equal(body.exp, 1000 + 4 * 3600);
});
