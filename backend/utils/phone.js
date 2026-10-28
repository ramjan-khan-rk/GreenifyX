export const phoneCandidates = (phone) => {
  const raw = String(phone ?? "").trim();
  if (!raw) return [];

  const digits = raw.replace(/\D/g, "");
  const local =
    digits.startsWith("91") && digits.length > 10
      ? digits.slice(-10)
      : digits;

  return [...new Set([raw, digits, local, `91${local}`, `+91${local}`])].filter(
    Boolean
  );
};

export const normalizePhone = (phone) => {
  const candidates = phoneCandidates(phone);
  const local = candidates.find((c) => /^\d{10}$/.test(c));
  if (local) return `+91${local}`;
  return String(phone ?? "").trim();
};
