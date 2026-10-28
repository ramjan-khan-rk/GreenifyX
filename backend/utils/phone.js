export const DEFAULT_COUNTRY_DIGITS = "971";
export const LEGACY_COUNTRY_DIGITS = "91";

const digitsOnly = (phone) => String(phone ?? "").replace(/\D/g, "");

export const phoneCandidates = (phone) => {
  const raw = String(phone ?? "").trim();
  if (!raw) return [];

  const digits = digitsOnly(raw);
  if (!digits) return [raw];

  let local = digits;
  if (digits.startsWith(DEFAULT_COUNTRY_DIGITS) && digits.length > 9) {
    local = digits.slice(DEFAULT_COUNTRY_DIGITS.length);
  } else if (digits.startsWith(LEGACY_COUNTRY_DIGITS) && digits.length > 10) {
    local = digits.slice(-10);
  }

  return [
    ...new Set([
      raw,
      digits,
      local,
      `${DEFAULT_COUNTRY_DIGITS}${local}`,
      `+${DEFAULT_COUNTRY_DIGITS}${local}`,
      `${LEGACY_COUNTRY_DIGITS}${local}`,
      `+${LEGACY_COUNTRY_DIGITS}${local}`,
    ]),
  ].filter(Boolean);
};

/** New stored numbers default to +971. Login lookup still matches +91 via candidates. */
export const normalizePhone = (phone) => {
  const raw = String(phone ?? "").trim();
  const digits = digitsOnly(raw);
  if (!digits) return raw;

  if (digits.startsWith(DEFAULT_COUNTRY_DIGITS) && digits.length > 9) {
    return `+${digits}`;
  }
  if (digits.startsWith(LEGACY_COUNTRY_DIGITS) && digits.length > 10) {
    return `+${digits}`;
  }
  return `+${DEFAULT_COUNTRY_DIGITS}${digits}`;
};
