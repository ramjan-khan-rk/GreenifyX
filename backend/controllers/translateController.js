import crypto from "crypto";
import Translation from "../models/Translation.js";
import { aiEnabled, callClaude, textOf } from "../utils/ai.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { sendServerError } from "../utils/httpError.js";
import { LANGUAGES, MAX_CHARS, translatable, translationPrompt, validTarget } from "../utils/translate.js";

// GET /api/translate/languages
export const languages = (req, res) => res.json({ success: true, languages: LANGUAGES, available: aiEnabled() });

// POST /api/translate { text, to }
export const translate = async (req, res) => {
  try {
    const text = String(req.body?.text || "").trim().slice(0, MAX_CHARS);
    const to = String(req.body?.to || "");
    if (!validTarget(to)) return res.status(400).json({ success: false, message: "Choose a language" });
    if (!translatable(text)) return res.json({ success: true, text });

    const hash = crypto.createHash("sha256").update(text).digest("hex");
    const cached = await Translation.findOne({ hash, to }).lean();
    if (cached) return res.json({ success: true, text: cached.text, cached: true });

    if (!aiEnabled()) return res.status(503).json({ success: false, message: "Translation isn't switched on yet" });
    if (hitRateLimit({ key: `translate:${req.user._id}`, max: 120, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "Too many translations this hour. Try again later." });
    }
    const reply = await callClaude({
      maxTokens: 1200,
      system: "You are a precise translator for a friendly eco social app. Output only the translated text.",
      messages: [{ role: "user", content: translationPrompt(text, to) }],
    });
    const out = textOf(reply).slice(0, MAX_CHARS * 2);
    if (!out) return res.status(502).json({ success: false, message: "Couldn't translate that right now" });
    await Translation.updateOne({ hash, to }, { $setOnInsert: { text: out, createdAt: new Date() } }, { upsert: true }).catch(() => {});
    res.json({ success: true, text: out });
  } catch (error) {
    return sendServerError(res, "Couldn't translate that right now");
  }
};
