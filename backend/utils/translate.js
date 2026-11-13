/**
 * Auto-translate for posts and comments. Pure helpers; tested.
 * Languages cover the UAE's biggest communities.
 */
export const LANGUAGES = {
  en: "English",
  ar: "Arabic",
  hi: "Hindi",
  ur: "Urdu",
  tl: "Tagalog (Filipino)",
  ml: "Malayalam",
};

export const MAX_CHARS = 2000;

export const validTarget = (code) => Object.prototype.hasOwnProperty.call(LANGUAGES, String(code || ""));

/** Rough script of a text: arabic, devanagari, malayalam, latin or other. */
export const scriptOf = (text) => {
  const s = String(text || "");
  const counts = { arabic: 0, devanagari: 0, malayalam: 0, latin: 0 };
  for (const ch of s) {
    const c = ch.codePointAt(0);
    if (c >= 0x0600 && c <= 0x06ff) counts.arabic++;
    else if (c >= 0x0900 && c <= 0x097f) counts.devanagari++;
    else if (c >= 0x0d00 && c <= 0x0d7f) counts.malayalam++;
    else if ((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a)) counts.latin++;
  }
  const [best, n] = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  return n === 0 ? "other" : best;
};

/** Text worth translating: strip hashtags/mentions/urls and check there are real words left. */
export const translatable = (text) => {
  const core = String(text || "")
    .replace(/https?:\/\/\S+/g, "")
    .replace(/[#@][\p{L}\p{N}_.]+/gu, "")
    .replace(/[\p{P}\p{S}\s\d]+/gu, "");
  return core.length >= 2;
};

export const translationPrompt = (text, to) =>
  `Translate this social media post into ${LANGUAGES[to]}. Keep hashtags, @mentions, emoji and links exactly as they are. ` +
  `Reply with only the translation, nothing else.\n\n${text}`;
