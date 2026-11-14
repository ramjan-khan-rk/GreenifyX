import jwt from "jsonwebtoken";
import User from "../models/User.js";
import UaePassSession from "../models/UaePassSession.js";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { appRedirect, authorizeUrl, profileFromUserInfo, randomToken, uaePassConfig } from "../utils/uaepass.js";
import { normalizePhone } from "../utils/phone.js";
import { sendServerError } from "../utils/httpError.js";

const tokenFor = (id) => jwt.sign({ id }, getJwtSecret(), { expiresIn: "7d" });

const log = (msg) => console.log(`[uaepass] ${msg}`);

// GET /api/auth/uaepass/status
export const uaePassStatus = (req, res) => {
  const cfg = uaePassConfig();
  res.json({ success: true, enabled: cfg.enabled, mode: cfg.mode });
};

// GET /api/auth/uaepass/start — opens the UAE PASS sign-in page.
export const uaePassStart = async (req, res) => {
  const cfg = uaePassConfig();
  if (!cfg.enabled) return res.status(503).send("UAE PASS sign-in isn't switched on yet.");
  const state = randomToken();
  await UaePassSession.create({ kind: "state", key: state });
  res.redirect(authorizeUrl(cfg, state));
};

// POST /api/auth/uaepass/link (signed in) — returns the sign-in address that links UAE PASS to this account.
export const uaePassLinkStart = async (req, res) => {
  const cfg = uaePassConfig();
  if (!cfg.enabled) return res.status(503).json({ success: false, message: "UAE PASS isn't switched on yet" });
  const state = randomToken();
  await UaePassSession.create({ kind: "state", key: state, linkUser: req.user._id });
  res.json({ success: true, url: authorizeUrl(cfg, state) });
};

const fetchJson = async (url, init) => {
  const r = await fetch(url, init);
  const body = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${r.status} ${body.error_description || body.error || ""}`.trim());
  return body;
};

// GET /api/auth/uaepass/callback?code&state — UAE PASS sends the browser here.
export const uaePassCallback = async (req, res) => {
  const cfg = uaePassConfig();
  const back = (params) => res.redirect(appRedirect(cfg, params));
  try {
    const state = String(req.query.state || "");
    const code = String(req.query.code || "");
    const started = state ? await UaePassSession.findOneAndDelete({ kind: "state", key: state }) : null;
    if (!started) return back({ error: "expired" });
    if (!code) return back({ error: String(req.query.error || "cancelled").slice(0, 40) });

    const basic = Buffer.from(`${cfg.clientId}:${cfg.clientSecret}`).toString("base64");
    const tokens = await fetchJson(`${cfg.base}/token`, {
      method: "POST",
      headers: { Authorization: `Basic ${basic}`, "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: cfg.redirectUri }),
    });
    const info = await fetchJson(`${cfg.base}/userinfo`, { headers: { Authorization: `Bearer ${tokens.access_token}` } });
    const p = profileFromUserInfo(info);
    if (!p.uuid) return back({ error: "no_profile" });

    let user = await User.findOne({ "uaePass.uuid": p.uuid });
    let isNewUser = false;
    if (!user && started.linkUser) {
      user = await User.findById(started.linkUser);
    }
    if (!user && p.email) {
      // UAE PASS emails are verified by UAE PASS, so an existing account with the same email is linked.
      user = await User.findOne({ email: p.email });
    }
    if (!user) {
      isNewUser = true;
      const phone = normalizePhone(p.mobile) || undefined;
      user = new User({
        name: p.name,
        email: p.email || undefined,
        emailVerified: Boolean(p.email),
        // Phone numbers are unique; skip it if another account already uses it.
        phone: phone && !(await User.exists({ phone })) ? phone : undefined,
      });
    }
    if (user.isSuspended) return back({ error: "suspended" });
    user.uaePass = { uuid: p.uuid, userType: p.userType, linkedAt: new Date() };
    user.isVerifiedResident = p.verifiedResident;
    if (!user.name && p.name) user.name = p.name;
    await user.save();

    const oneTime = randomToken();
    await UaePassSession.create({ kind: "code", key: oneTime, user: user._id, isNewUser: isNewUser || !user.isProfileCompleted });
    log(`signed in ${String(user._id).slice(-6)} (${p.userType || "unknown type"}${started.linkUser ? ", linked" : ""})`);
    return back({ code: oneTime });
  } catch (e) {
    log(`callback failed: ${e.message}`);
    return back({ error: "failed" });
  }
};

// POST /api/auth/uaepass/exchange { code } — the app swaps the one-time code for a session.
export const uaePassExchange = async (req, res) => {
  try {
    const s = await UaePassSession.findOneAndDelete({ kind: "code", key: String(req.body?.code || "") });
    if (!s) return res.status(400).json({ success: false, message: "This sign-in has expired. Try again." });
    const user = await User.findById(s.user);
    if (!user || user.isSuspended) return res.status(403).json({ success: false, message: "This account can't sign in" });
    const obj = user.toObject();
    delete obj.password;
    res.json({ success: true, token: tokenFor(user._id), isNewUser: s.isNewUser, user: obj });
  } catch (error) {
    return sendServerError(res, "Unable to sign in with UAE PASS");
  }
};
