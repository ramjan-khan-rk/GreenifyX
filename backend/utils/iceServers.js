/**
 * ICE servers for calls, read forgivingly from the environment.
 *
 * Accepts the plain form:
 *   TURN_URLS=turn:a.example:80,turn:a.example:443   TURN_USERNAME=...   TURN_CREDENTIAL=...
 * and also a provider snippet pasted as-is into TURN_URLS or ICE_SERVERS (for example
 * Metered's `const iceServers = [{ urls: "...", username: "...", credential: "..." }]`).
 * Only real stun:/turn:/turns: addresses are kept, so a pasted block can never
 * hand the phone a broken address (which made calls fail before ringing).
 */
const DEFAULT_STUN = ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"];
const URL_RE = /\b(stuns?|turns?):[A-Za-z0-9.\-_]+(?::\d{1,5})?(?:\?transport=(?:udp|tcp))?/g;

const firstMatch = (text, key) => {
  const m = new RegExp(`${key}\\s*["']?\\s*[:=]\\s*["']([^"']+)["']`).exec(text);
  return m ? m[1] : "";
};

export const parseIceConfig = (env = process.env) => {
  const raw = [env.ICE_SERVERS, env.TURN_URLS].filter(Boolean).join("\n");
  const found = [...new Set(raw.match(URL_RE) || [])];
  const stun = found.filter((u) => u.startsWith("stun"));
  const turn = found.filter((u) => u.startsWith("turn"));
  const username = String(env.TURN_USERNAME || "").trim() || firstMatch(raw, "username");
  const credential = String(env.TURN_CREDENTIAL || "").trim() || firstMatch(raw, "credential");

  const servers = [{ urls: [...new Set([...DEFAULT_STUN, ...stun])] }];
  const relay = turn.length > 0 && Boolean(username) && Boolean(credential);
  if (relay) servers.push({ urls: turn, username, credential });

  const problems = [];
  if (raw && !found.length) problems.push("TURN_URLS is set but has no stun:/turn: addresses in it");
  if (turn.length && !username) problems.push("TURN username missing (TURN_USERNAME)");
  if (turn.length && !credential) problems.push("TURN password missing (TURN_CREDENTIAL)");
  if (/const |iceServers|\[|\{/.test(String(env.TURN_URLS || ""))) {
    problems.push("TURN_URLS contains pasted code; it was read anyway, but a plain comma list is cleaner");
  }
  return { servers, relay, turnUrls: turn, stunUrls: servers[0].urls, problems };
};

/** Safe one-line summary for logs (never includes the username or password). */
export const describeIce = (cfg) =>
  `relay ${cfg.relay ? "ON" : "OFF"} · turn: ${cfg.turnUrls.join(", ") || "none"}` + (cfg.problems.length ? ` · problems: ${cfg.problems.join("; ")}` : "");
