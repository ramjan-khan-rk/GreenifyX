import crypto from "crypto";

/**
 * UAE PASS (national digital identity) sign-in, OAuth 2.0 authorization-code flow.
 * Switched on by UAEPASS_CLIENT_ID + UAEPASS_CLIENT_SECRET + UAEPASS_REDIRECT_URI
 * (the server callback, e.g. https://greenifyx.onrender.com/api/auth/uaepass/callback),
 * issued by TDRA when GreenifyX is onboarded. UAEPASS_ENV=production switches from staging.
 * Pure helpers; tested.
 */
const BASES = {
  staging: "https://stg-id.uaepass.ae/idshub",
  production: "https://id.uaepass.ae/idshub",
};

export const uaePassConfig = (env = process.env) => {
  const mode = env.UAEPASS_ENV === "production" ? "production" : "staging";
  return {
    enabled: Boolean(env.UAEPASS_CLIENT_ID && env.UAEPASS_CLIENT_SECRET && env.UAEPASS_REDIRECT_URI),
    mode,
    base: (env.UAEPASS_BASE_URL || BASES[mode]).replace(/\/$/, ""),
    clientId: env.UAEPASS_CLIENT_ID || "",
    clientSecret: env.UAEPASS_CLIENT_SECRET || "",
    redirectUri: env.UAEPASS_REDIRECT_URI || "",
    scope: env.UAEPASS_SCOPE || "urn:uae:digitalid:profile:general",
    acr: env.UAEPASS_ACR || "urn:safelayer:tws:policies:authentication:level:low",
    appScheme: env.UAEPASS_APP_SCHEME || "greenifyx",
  };
};

export const authorizeUrl = (cfg, state) => {
  const q = new URLSearchParams({
    response_type: "code",
    client_id: cfg.clientId,
    scope: cfg.scope,
    state,
    redirect_uri: cfg.redirectUri,
    acr_values: cfg.acr,
    ui_locales: "en",
  });
  return `${cfg.base}/authorize?${q}`;
};

export const randomToken = (bytes = 24) => crypto.randomBytes(bytes).toString("base64url");

/**
 * A UAE PASS profile, reduced to what GreenifyX keeps. The Emirates ID number is
 * never stored: only whether the account is a verified (SOP2/SOP3) resident.
 */
export const profileFromUserInfo = (info = {}) => {
  const userType = String(info.userType || "").toUpperCase();
  const name =
    String(info.fullnameEN || "").trim() ||
    [info.firstnameEN, info.lastnameEN].filter(Boolean).join(" ").trim() ||
    String(info.fullnameAR || "").trim();
  return {
    uuid: String(info.uuid || info.sub || ""),
    userType,
    verifiedResident: userType === "SOP2" || userType === "SOP3",
    name,
    email: String(info.email || "").trim().toLowerCase(),
    mobile: String(info.mobile || "").replace(/[^\d+]/g, ""),
  };
};

/** Where the server sends the browser back to the app after sign-in. */
export const appRedirect = (cfg, params) => `${cfg.appScheme}://uaepass?${new URLSearchParams(params)}`;
