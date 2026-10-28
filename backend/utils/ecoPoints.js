/**
 * Resolve a user's Eco Points from the canonical field,
 * falling back to legacy ecoScore / karamCount stored in older documents.
 */
export function resolveEcoPoints(user) {
  if (!user) return 0;
  const doc = typeof user.toObject === "function" ? user.toObject() : user;
  const value = doc.ecoPoints ?? doc.ecoScore ?? doc.karamCount ?? 0;
  return Number(value) || 0;
}

export function publicUserPoints(user) {
  return {
    ecoPoints: resolveEcoPoints(user),
  };
}
