import User from "../models/User.js";
import { parseCommand, resolvePerson } from "../utils/voice.js";
import { aiEnabled, callClaude, textOf, parseJsonReply } from "../utils/ai.js";
import { availablePoints } from "../utils/rewards.js";
import { sendServerError } from "../utils/httpError.js";

const SCREEN_NAMES = ["rewards", "events", "battles", "map", "carbon", "impact", "market", "scan", "communities", "reels", "chats", "notifications", "settings", "profile", "pickup", "campaigns", "companion", "live", "trending", "invite", "create_post"];

const say = (ar, en, arText) => (ar ? arText : en);

/** Ask Claude to map free speech to an intent when the rules can't. */
const aiParse = async (text) => {
  const r = await callClaude({
    system: `You turn a spoken request to "Greeny" (the GreenifyX app assistant) into JSON only: {"intent": "open_chat"|"call"|"send_message"|"open_screen"|"points"|"streak"|"go_live"|"answer", "person"?: string, "message"?: string, "video"?: boolean, "screen"?: one of ${SCREEN_NAMES.join(", ")}, "answer"?: short helpful reply (max 200 chars) for general eco questions}.`,
    messages: [{ role: "user", content: text }],
    maxTokens: 200,
    timeoutMs: 8000,
  });
  return parseJsonReply(textOf(r)) || { intent: "unknown" };
};

// POST /api/assistant/command { text, lang? }
export const voiceCommand = async (req, res) => {
  try {
    const text = String(req.body?.text || "").slice(0, 400);
    const ar = req.body?.lang === "ar";
    let cmd = parseCommand(text);
    if (cmd.intent === "unknown" && aiEnabled()) cmd = await aiParse(text).catch(() => cmd);

    const me = await User.findById(req.user._id).select("name friends ecoPoints pointsSpent streak level");
    if (["open_chat", "call", "send_message"].includes(cmd.intent)) {
      const friends = await User.find({ _id: { $in: me.friends || [] } }).select("name profileImage").lean();
      const spoken = String(cmd.person || "").replace(/\s+a (message|text)$/, "");
      const p = resolvePerson(spoken, friends);
      if (!p) {
        return res.json({
          success: true,
          action: "say",
          reply: say(ar, `I couldn't find "${spoken}" in your friends.`, `لم أجد "${spoken}" بين أصدقائك.`),
        });
      }
      const person = { _id: p._id, name: p.name, profileImage: p.profileImage || "" };
      if (cmd.intent === "call") {
        return res.json({ success: true, action: "call", person, video: Boolean(cmd.video), reply: say(ar, `${cmd.video ? "Video calling" : "Calling"} ${p.name}…`, `جارٍ الاتصال بـ ${p.name}…`) });
      }
      if (cmd.intent === "send_message" && cmd.message) {
        return res.json({ success: true, action: "send_message", person, message: cmd.message, confirm: true, reply: say(ar, `Send "${cmd.message}" to ${p.name}?`, `هل أرسل "${cmd.message}" إلى ${p.name}؟`) });
      }
      return res.json({ success: true, action: "open_chat", person, reply: say(ar, `Opening your chat with ${p.name}.`, `أفتح محادثتك مع ${p.name}.`) });
    }
    if (cmd.intent === "points") {
      const bal = availablePoints(me);
      return res.json({ success: true, action: "say", reply: say(ar, `You have ${bal} Eco Points to spend and you're level ${me.level}.`, `لديك ${bal} نقطة بيئية وأنت في المستوى ${me.level}.`) });
    }
    if (cmd.intent === "streak") {
      return res.json({ success: true, action: "say", reply: say(ar, `Your streak is ${me.streak || 0} days. One verified action today keeps it going!`, `سلسلتك ${me.streak || 0} أيام. عمل واحد اليوم يحافظ عليها!`) });
    }
    if (cmd.intent === "go_live") return res.json({ success: true, action: "open_screen", screen: "live", reply: say(ar, "Let's go live!", "لنبدأ البث!") });
    if (cmd.intent === "open_screen" && SCREEN_NAMES.includes(cmd.screen)) {
      return res.json({ success: true, action: "open_screen", screen: cmd.screen, reply: say(ar, "Here you go.", "تفضل.") });
    }
    if (cmd.intent === "answer" && cmd.answer) return res.json({ success: true, action: "say", reply: String(cmd.answer).slice(0, 280) });
    res.json({
      success: true,
      action: "say",
      reply: say(ar, 'Try "call Sara", "chat with Omar", "open my rewards" or "how many points do I have".', 'جرّب: "اتصل بسارة" أو "افتح المكافآت" أو "كم نقاطي".'),
    });
  } catch (e) {
    return sendServerError(res, "Greeny didn't catch that");
  }
};
