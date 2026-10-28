export const parseFromAddress = (from, fallbackName = "GreenifyX") => {
  const raw = String(from ?? "").trim();
  if (!raw) return null;

  const angled = raw.match(/^(.*)<([^>]+)>$/);
  if (angled) {
    const name =
      angled[1]
        .trim()
        .replace(/^["']|["']$/g, "")
        .trim() || fallbackName;
    const email = angled[2].trim();
    if (!email.includes("@")) return null;
    return { name, email };
  }

  if (!raw.includes("@") || raw.includes(" ")) return null;
  return { name: fallbackName, email: raw };
};
