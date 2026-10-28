import { isProduction } from "./jwtConfig.js";
import { sendOtpEmail } from "./resendMailer.js";

export const allowDevOtpShortcut = () =>
  !isProduction() && process.env.ALLOW_DEV_OTP === "true";

export const deliverOtp = async ({ email, otp }) => {
  return sendOtpEmail({ to: email, otp });
};
