const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const normalizeEmail = (value) => {
  const email = String(value ?? "")
    .trim()
    .toLowerCase();
  if (!email || !EMAIL_PATTERN.test(email)) return "";
  return email;
};

export const looksLikeEmail = (value) => Boolean(normalizeEmail(value));
