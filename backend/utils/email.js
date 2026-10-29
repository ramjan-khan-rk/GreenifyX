const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const normalizeEmail = (value) => {
  const email = String(value ?? "")
    .trim()
    .toLowerCase();
  if (!email || !EMAIL_PATTERN.test(email)) return "";
  return email;
};

export const looksLikeEmail = (value) => Boolean(normalizeEmail(value));

/** OTP signup is email-only. Phone is never required and is ignored unless it is an email. */
export const resolveOtpEmail = (body = {}) => {
  const fromEmail = normalizeEmail(body.email);
  if (fromEmail) return fromEmail;
  if (looksLikeEmail(body.phone)) {
    return normalizeEmail(body.phone);
  }
  return "";
};
