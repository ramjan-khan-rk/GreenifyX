import assert from "node:assert/strict";
import { test } from "node:test";
import { appRedirect, authorizeUrl, profileFromUserInfo, uaePassConfig } from "../utils/uaepass.js";

test("off until all three settings are present; staging by default", () => {
  assert.equal(uaePassConfig({}).enabled, false);
  const cfg = uaePassConfig({ UAEPASS_CLIENT_ID: "id", UAEPASS_CLIENT_SECRET: "s", UAEPASS_REDIRECT_URI: "https://api.example/cb" });
  assert.equal(cfg.enabled, true);
  assert.equal(cfg.mode, "staging");
  assert.match(cfg.base, /stg-id\.uaepass\.ae/);
  assert.match(uaePassConfig({ UAEPASS_ENV: "production" }).base, /^https:\/\/id\.uaepass\.ae/);
});

test("authorize address carries client, state and redirect", () => {
  const cfg = uaePassConfig({ UAEPASS_CLIENT_ID: "id", UAEPASS_CLIENT_SECRET: "s", UAEPASS_REDIRECT_URI: "https://api.example/cb" });
  const u = new URL(authorizeUrl(cfg, "st8"));
  assert.equal(u.searchParams.get("client_id"), "id");
  assert.equal(u.searchParams.get("state"), "st8");
  assert.equal(u.searchParams.get("redirect_uri"), "https://api.example/cb");
  assert.equal(u.searchParams.get("response_type"), "code");
});

test("profile keeps only what GreenifyX needs and flags verified residents", () => {
  const p = profileFromUserInfo({ uuid: "u-1", userType: "SOP3", fullnameEN: "Aisha Khan", email: "A@X.AE", mobile: "971 50 123 4567", idn: "784-0000-0000000-0" });
  assert.deepEqual(p, { uuid: "u-1", userType: "SOP3", verifiedResident: true, name: "Aisha Khan", email: "a@x.ae", mobile: "971501234567" });
  assert.equal(JSON.stringify(p).includes("784"), false);
  assert.equal(profileFromUserInfo({ sub: "v", userType: "SOP1" }).verifiedResident, false);
});

test("returns to the app through its own link", () => {
  assert.equal(appRedirect(uaePassConfig({}), { code: "c1" }), "greenifyx://uaepass?code=c1");
});
