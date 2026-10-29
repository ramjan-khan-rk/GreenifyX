export const escapeRegex = (value) =>
  String(value ?? "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
