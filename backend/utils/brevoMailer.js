import { parseFromAddress } from "./fromAddress.js";

const BREVO_URL = "https://api.brevo.com/v3/smtp/email";

let sendImpl = sendViaBrevo;

export const setBrevoSender = (fn) => {
  sendImpl = fn;
};

export const resetBrevoSender = () => {
  sendImpl = sendViaBrevo;
};

async function sendViaBrevo({ from, to, subject, text, html }) {
  const apiKey = String(process.env.BREVO_API_KEY || "").trim();
  if (!apiKey) {
    return { ok: false, reason: "not_configured" };
  }

  const appName = String(process.env.APP_NAME || "GreenifyX").trim() || "GreenifyX";
  const sender = parseFromAddress(from, appName);
  if (!sender) {
    return { ok: false, reason: "not_configured" };
  }

  const response = await fetch(BREVO_URL, {
    method: "POST",
    headers: {
      accept: "application/json",
      "api-key": apiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      sender: { name: sender.name, email: sender.email },
      to: [{ email: to }],
      subject,
      textContent: text,
      htmlContent: html,
    }),
  });

  if (!response.ok) {
    return { ok: false, reason: "provider", status: response.status };
  }

  return { ok: true };
}

export const sendOtpEmail = async ({ to, otp }) => {
  const from = String(process.env.EMAIL_FROM || "").trim();
  const appName = String(process.env.APP_NAME || "GreenifyX").trim() || "GreenifyX";

  if (!from) {
    return { delivered: false, reason: "not_configured" };
  }

  if (!to || !otp) {
    return { delivered: false, reason: "invalid_payload" };
  }

  const subject = `${appName} verification code`;
  const text = `Your ${appName} verification code expires in 10 minutes.`;
  const html = `<p>Your ${appName} verification code is <strong>${otp}</strong>.</p><p>It expires in 10 minutes. If you did not request this, ignore this email.</p>`;

  try {
    const result = await sendImpl({ from, to, subject, text, html });
    if (!result.ok) {
      return { delivered: false, reason: result.reason || "provider" };
    }
    return { delivered: true, channel: "brevo" };
  } catch {
    return { delivered: false, reason: "provider" };
  }
};
