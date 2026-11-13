/** #hashtags and @mentions in captions and comments. */
export const extractHashtags = (text) => {
  const out = new Set();
  for (const m of String(text || "").matchAll(/(^|[^\p{L}\p{N}_])#([\p{L}\p{N}_]{2,40})/gu)) out.add(m[2].toLowerCase());
  return [...out].slice(0, 20);
};

/** "@Sara" or "@Sara_Haddad" tokens (underscores stand for spaces). */
export const extractMentionTokens = (text) => {
  const out = new Set();
  for (const m of String(text || "").matchAll(/(^|[^\p{L}\p{N}_])@([\p{L}\p{N}_.]{2,40})/gu)) out.add(m[2].replace(/_/g, " ").toLowerCase());
  return [...out].slice(0, 10);
};

/**
 * Match tokens to people the author knows. Full name wins, then first name
 * (only when exactly one person matches, so nobody is tagged by mistake).
 */
export const resolveMentions = (tokens, people) => {
  const ids = new Set();
  for (const t of tokens) {
    const full = people.filter((p) => String(p.name || "").toLowerCase() === t);
    if (full.length === 1) {
      ids.add(String(full[0]._id));
      continue;
    }
    const first = people.filter((p) => String(p.name || "").toLowerCase().split(" ")[0] === t);
    if (first.length === 1) ids.add(String(first[0]._id));
  }
  return [...ids];
};
