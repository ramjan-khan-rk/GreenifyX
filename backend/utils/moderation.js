import { aiEnabled, callClaude, textOf, parseJsonReply } from "./ai.js";

/**
 * Automatic review of a new post photo. Returns { status, reasons }.
 * - duplicate: the exact same file was posted before (by anyone)
 * - AI (when configured): unsafe content, not eco-related, or looks like a stock/internet photo
 */
export const reviewPost = async ({ buffer, mimetype, activity, description, duplicate }) => {
  const reasons = [];
  if (duplicate) reasons.push("duplicate_media");
  if (!aiEnabled() || !String(mimetype).startsWith("image/") || buffer.length > 4.5 * 1024 * 1024) {
    return { status: reasons.length ? "flagged" : "skipped", reasons };
  }
  try {
    const r = await callClaude({
      system:
        'You review photos for a UAE environmental action app. Reply with JSON only: {"unsafe": bool, "ecoRelated": bool, "looksStock": bool, "reason": string}. unsafe = nudity, violence, hate, personal data or illegal acts. ecoRelated = the photo plausibly shows the claimed action. looksStock = watermark, studio/stock look, screenshot or photo of a screen.',
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: mimetype === "image/png" ? "image/png" : mimetype === "image/webp" ? "image/webp" : "image/jpeg", data: buffer.toString("base64") } },
            { type: "text", text: `Claimed action: ${activity}. Caption: ${String(description || "").slice(0, 300)}` },
          ],
        },
      ],
      maxTokens: 200,
      timeoutMs: 20000,
    });
    const j = parseJsonReply(textOf(r)) || {};
    if (j.unsafe) reasons.push("unsafe_content");
    if (j.ecoRelated === false) reasons.push("not_eco_related");
    if (j.looksStock) reasons.push("looks_like_stock_or_screenshot");
  } catch (e) {
    console.error("AI review failed:", e.message);
  }
  return { status: reasons.length ? "flagged" : "clear", reasons };
};

export const REASON_TEXT = {
  duplicate_media: "AI check: this exact photo/video was already posted",
  unsafe_content: "AI check: possibly unsafe content",
  not_eco_related: "AI check: photo doesn't seem to match the action",
  looks_like_stock_or_screenshot: "AI check: looks like a stock image or screenshot",
};
