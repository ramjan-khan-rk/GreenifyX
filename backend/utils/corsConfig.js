import { isProduction } from "./jwtConfig.js";

export const corsOriginList = () =>
  String(process.env.CORS_ORIGIN || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

export const corsOriginDelegate = (origin, callback) => {
  if (!origin) {
    callback(null, true);
    return;
  }

  const allowed = corsOriginList();
  if (allowed.includes(origin)) {
    callback(null, true);
    return;
  }

  if (!isProduction() && allowed.length === 0) {
    callback(null, true);
    return;
  }

  callback(new Error("Not allowed by CORS"));
};
