const RESEND_URL = "https://api.resend.com/emails";

let sendImpl = sendViaResend;

export const setResendSender = (fn) => {
  sendImpl = fn;
};

export const resetResendSender = () => {
  sendImpl = sendViaResend;
};

async function sendViaResend({ from, to, subject, text, html }) {
  const apiKey = String(process.env.RESEND_API_KEY || "").trim();
  if (!apiKey) {
    return { ok: false, reason: "not_configured" };
  }

  const response = await fetch(RESEND_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject,
      text,
      html,
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
    return { delivered: true, channel: "resend" };
  } catch {
    return { delivered: false, reason: "provider" };
  }
};
