import assert from "node:assert/strict";
import { test } from "node:test";
import { describeIce, parseIceConfig } from "../utils/iceServers.js";

const pasted = `const iceServers = [
  { urls: "stun:stun.relay.example.com:80" },
  { urls: "turn:global.relay.example.com:80", username: "user123", credential: "pa/ss" },
  { urls: "turn:global.relay.example.com:80?transport=tcp", username: "user123", credential: "pa/ss" },
  { urls: "turns:global.relay.example.com:443?transport=tcp", username: "user123", credential: "pa/ss" },
];`;

test("a provider snippet pasted into TURN_URLS is read correctly", () => {
  const cfg = parseIceConfig({ TURN_URLS: pasted });
  assert.equal(cfg.relay, true);
  assert.deepEqual(cfg.turnUrls, [
    "turn:global.relay.example.com:80",
    "turn:global.relay.example.com:80?transport=tcp",
    "turns:global.relay.example.com:443?transport=tcp",
  ]);
  assert.equal(cfg.servers[1].username, "user123");
  assert.equal(cfg.servers[1].credential, "pa/ss");
  assert.ok(cfg.stunUrls.includes("stun:stun.relay.example.com:80"));
  assert.ok(cfg.problems.some((p) => p.includes("pasted code")));
});

test("plain comma list with separate username and password", () => {
  const cfg = parseIceConfig({ TURN_URLS: "turn:a.example:80, turn:a.example:443", TURN_USERNAME: "u", TURN_CREDENTIAL: "p" });
  assert.equal(cfg.relay, true);
  assert.deepEqual(cfg.turnUrls, ["turn:a.example:80", "turn:a.example:443"]);
  assert.deepEqual(cfg.problems, []);
});

test("missing password turns the relay off and says why", () => {
  const cfg = parseIceConfig({ TURN_URLS: "turn:a.example:80", TURN_USERNAME: "u" });
  assert.equal(cfg.relay, false);
  assert.equal(cfg.servers.length, 1);
  assert.match(describeIce(cfg), /password missing/);
});

test("nothing set means STUN only, and the summary never leaks the password", () => {
  assert.equal(parseIceConfig({}).relay, false);
  const s = describeIce(parseIceConfig({ TURN_URLS: pasted }));
  assert.equal(s.includes("pa/ss"), false);
  assert.equal(s.includes("user123"), false);
});
