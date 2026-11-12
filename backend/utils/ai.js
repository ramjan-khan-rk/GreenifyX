/**
 * Minimal Anthropic Messages API client (no SDK dependency).
 * The assistant runs in "live data" mode when ANTHROPIC_API_KEY is not set.
 */
const API_URL = "https://api.anthropic.com/v1/messages";

export const aiEnabled = () => Boolean(String(process.env.ANTHROPIC_API_KEY || "").trim());

export const aiModel = () => process.env.ANTHROPIC_MODEL || "claude-haiku-5-5";

export const callClaude = async ({ system, messages, tools, maxTokens = 1024, timeoutMs = 30000 }) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(API_URL, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "content-type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({ model: aiModel(), max_tokens: maxTokens, system, messages, ...(tools ? { tools } : {}) }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`AI request failed (${res.status}) ${body.slice(0, 200)}`);
    }
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
};

export const textOf = (response) =>
  (response?.content || [])
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("\n")
    .trim();

/** Pulls the first JSON object out of a model reply. */
export const parseJsonReply = (text) => {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
};
