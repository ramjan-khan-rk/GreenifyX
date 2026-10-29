import { isProduction } from "./jwtConfig.js";
import { sendOtpEmail as sendOtpEmailBrevo } from "./brevoMailer.js";
import { sendOtpEmail as sendOtpEmailResend } from "./resendMailer.js";

export const allowDevOtpShortcut = () =>
  !isProduction() && process.env.ALLOW_DEV_OTP === "true";

const hasBrevoKey = () => Boolean(String(process.env.BREVO_API_KEY || "").trim());

export const deliverOtp = async ({ email, otp }) => {
  if (hasBrevoKey()) {
    return sendOtpEmailBrevo({ to: email, otp });
  }
  return sendOtpEmailResend({ to: email, otp });
};
