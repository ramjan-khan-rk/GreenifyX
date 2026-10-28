import crypto from "crypto";
import { getJwtSecret } from "./jwtConfig.js";

export const generateOtpCode = () =>
  crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");

export const hashOtp = (target, purpose, code) =>
  crypto
    .createHmac("sha256", getJwtSecret())
    .update(`${target}:${purpose}:${code}`)
    .digest("hex");

export const hashesMatch = (a, b) => {
  if (!a || !b) return false;
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
};
