import { isProduction } from "./jwtConfig.js";

export const allowDevOtpShortcut = () =>
  !isProduction() && process.env.ALLOW_DEV_OTP === "true";

export const deliverOtp = async ({ phone, otp }) => {
  void phone;
  void otp;

  const provider = String(process.env.SMS_PROVIDER || "")
    .trim()
    .toLowerCase();

  if (!provider || provider === "none") {
    return { delivered: false, channel: "none" };
  }

  console.error(
    `SMS_PROVIDER is set but no delivery adapter is implemented for it.`
  );
  return { delivered: false, channel: "unimplemented" };
};
