/**
 * "Hey Greeny" voice commands → app actions. Pure functions; tested.
 */
const SCREENS = {
  rewards: ["reward", "rewards", "voucher", "redeem", "مكافآت", "المكافآت"],
  events: ["event", "events", "calendar", "فعاليات", "الفعاليات"],
  battles: ["battle", "battles", "leaderboard", "ranking", "competition", "منافسات"],
  map: ["map", "eco map", "recycling point", "خريطة", "الخريطة"],
  carbon: ["carbon", "footprint", "co2", "البصمة", "الكربون"],
  impact: ["impact", "certificate", "أثري", "شهادة"],
  market: ["swap", "market", "marketplace", "second hand", "بادل"],
  scan: ["scan", "qr", "check in", "check-in", "امسح"],
  communities: ["community", "communities", "group", "مجتمع", "المجتمعات"],
  reels: ["reel", "reels", "videos", "مقاطع"],
  chats: ["chats", "messages", "inbox", "الرسائل", "الدردشة"],
  notifications: ["notification", "notifications", "updates", "الإشعارات"],
  settings: ["setting", "settings", "الإعدادات"],
  profile: ["profile", "my profile", "الملف"],
  pickup: ["pickup", "pick up", "collection", "استلام"],
  campaigns: ["campaign", "campaigns", "حملات", "الحملات"],
  companion: ["companion", "plan", "my day", "رفيق"],
  live: ["live", "streams", "مباشر"],
  trending: ["trending", "hashtag", "hashtags", "الترند"],
  invite: ["invite", "referral", "دعوة"],
  create_post: ["post", "new post", "share a moment", "منشور"],
};

const clean = (t) =>
  String(t || "")
    .toLowerCase()
    .replace(/[“”"!?.,]/g, " ")
    .replace(/^\s*(hey|hi|ok|okay|hello)?\s*(greeny|greenie|greenee|green e|غريني|جريني)\s*/i, "")
    .replace(/\s+/g, " ")
    .trim();

const screenFor = (phrase) => {
  const p = ` ${phrase} `;
  let best = null;
  for (const [screen, words] of Object.entries(SCREENS)) {
    for (const w of words) if (p.includes(` ${w} `) || phrase === w) if (!best || w.length > best.len) best = { screen, len: w.length };
  }
  return best?.screen || null;
};

/** → { intent, person?, message?, video?, screen? } */
export const parseCommand = (raw) => {
  const t = clean(raw);
  if (!t) return { intent: "empty" };
  let m;
  if ((m = t.match(/^(?:make a |start a |do a )?video call (?:with |to )?(.+)$/)) || (m = t.match(/^(?:اتصل|مكالمة)\s+فيديو\s+(?:مع\s+|ب)?(.+)$/))) {
    return { intent: "call", person: m[1].trim(), video: true };
  }
  if ((m = t.match(/^(?:call|ring|phone|dial)\s+(.+?)(?:\s+on video)?$/)) || (m = t.match(/^(?:اتصل\s+(?:ب|على)?\s*)(.+)$/))) {
    return { intent: "call", person: m[1].trim(), video: /on video$/.test(t) };
  }
  if (
    (m = t.match(/^(?:send|text|message|tell)\s+(?:a message to\s+|a text to\s+)?(.+?)\s+(?:saying|that|to say)\s+(.+)$/)) ||
    (m = t.match(/^(?:send a message to|text)\s+(.+?)\s*:\s*(.+)$/)) ||
    (m = t.match(/^(?:أرسل|ارسل)\s+(?:رسالة\s+)?(?:إلى|الى|ل)\s*(.+?)\s+(?:قل|يقول|تقول)\s+(.+)$/))
  ) {
    return { intent: "send_message", person: m[1].trim(), message: m[2].trim() };
  }
  if ((m = t.match(/^(?:open |start )?(?:a )?chat (?:with|to)\s+(.+)$/)) || (m = t.match(/^(?:talk to|message|text|open chat with)\s+(.+)$/)) || (m = t.match(/^(?:راسل|دردش مع|محادثة مع)\s+(.+)$/))) {
    return { intent: "open_chat", person: m[1].trim() };
  }
  if (/\b(points|balance|eco points)\b|نقاط|نقاطي/.test(t) && /\b(how many|my|what|show)\b|كم|نقاطي/.test(t)) return { intent: "points" };
  if (/\bstreak\b|سلسلة/.test(t)) return { intent: "streak" };
  if (/^(?:go live|start (?:a )?live|start streaming)/.test(t) || /بث مباشر/.test(t)) return { intent: "go_live" };
  if ((m = t.match(/^(?:open|show|go to|take me to|launch|افتح|اعرض)\s+(?:me\s+)?(?:my\s+|the\s+)?(.+)$/))) {
    const s = screenFor(m[1]);
    if (s) return { intent: "open_screen", screen: s };
  }
  const s = screenFor(t);
  if (s) return { intent: "open_screen", screen: s };
  return { intent: "unknown", text: t };
};

const norm = (s) => String(s || "").toLowerCase().normalize("NFKD").replace(/[^\p{L}\p{N} ]/gu, "").trim();

const lev = (a, b) => {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...new Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++) d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return d[a.length][b.length];
};

/** Best friend match for a spoken name (handles first names and small speech errors). */
export const resolvePerson = (spoken, people) => {
  const q = norm(spoken).replace(/^(my friend|mr|mrs|ms|brother|bro)\s+/, "");
  if (!q) return null;
  let best = null;
  for (const p of people) {
    const n = norm(p.name);
    const parts = n.split(" ");
    let score = 0;
    if (n === q) score = 100;
    else if (n.startsWith(q) || q.startsWith(n)) score = 90;
    else if (parts[0] === q.split(" ")[0]) score = q.split(" ").length > 1 && parts.includes(q.split(" ").at(-1)) ? 95 : 80;
    else {
      const dist = Math.min(lev(q, n), lev(q.split(" ")[0], parts[0]));
      if (dist <= Math.max(1, Math.floor(q.length / 5))) score = 70 - dist * 5;
    }
    if (score > (best?.score || 0)) best = { person: p, score };
  }
  return best && best.score >= 60 ? best.person : null;
};
