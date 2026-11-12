import { isProduction } from "./jwtConfig.js";

export const corsOriginList = () =>
  String(process.env.CORS_ORIGIN || "")
    .split(",")
    // Browsers send origins without a trailing slash; tolerate one in the setting.
    .map((origin) => origin.trim().replace(/\/+$/, "").toLowerCase())
    .filter(Boolean);

export const corsOriginDelegate = (origin, callback) => {
  if (!origin) {
    callback(null, true);
    return;
  }

  const allowed = corsOriginList();

  // Local development: allow any localhost port (Flutter web picks a random one).
  if (!isProduction() && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
    callback(null, true);
    return;
  }

  if (allowed.includes(String(origin).toLowerCase())) {
    callback(null, true);
    return;
  }

  if (!isProduction() && allowed.length === 0) {
    callback(null, true);
    return;
  }

  callback(new Error("Not allowed by CORS"));
};
