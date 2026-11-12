import Campaign from "../models/Campaign.js";
import EcoPlace from "../models/EcoPlace.js";
import EnvironmentalReport from "../models/EnvironmentalReport.js";
import PointsTransaction from "../models/PointsTransaction.js";
import { sendServerError } from "../utils/httpError.js";
import { resolveEcoPoints } from "../utils/ecoPoints.js";
import { EMIRATES, normalizeEmirate } from "../utils/emirates.js";
import { distanceMeters, isValidCoord } from "../utils/geo.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { aiEnabled, callClaude, parseJsonReply, textOf } from "../utils/ai.js";
import { GUIDE, findGuide, guideByKey } from "../utils/recyclingGuide.js";
import { STATUS_LABELS } from "./envReportController.js";

/* ---------------- Tools over live GreenifyX data ---------------- */

const CATEGORY_HINTS = [
  ["mangrove", "Mangrove Restoration"],
  ["tree", "Tree Plantation"],
  ["plant", "Tree Plantation"],
  ["ghaf", "Tree Plantation"],
  ["beach", "Beach Cleaning"],
  ["clean", "Beach Cleaning"],
  ["recycl", "Recycling"],
  ["garden", "Community Gardening"],
  ["water", "Water Conservation"],
];

const detectEmirate = (text) => {
  const q = String(text || "").toLowerCase();
  if (/(marina|jbr|jumeirah|deira|business bay|al quoz)/.test(q)) return "Dubai";
  return EMIRATES.find((e) => q.includes(e.toLowerCase())) || null;
};

const guideCard = (g) => ({
  type: "guide",
  key: g.key,
  title: g.name,
  material: g.material,
  bin: g.bin,
  binColor: g.binColor,
  prep: g.prep,
  tip: g.tip,
  placeTypes: g.placeTypes,
});

const tools = {
  async find_campaigns({ emirate, category }, ctx) {
    const filter = { status: "active", endDate: { $gte: new Date() } };
    const e = normalizeEmirate(emirate);
    if (e) filter.emirate = e;
    if (category) filter.category = category;
    let items = await Campaign.find(filter).sort({ startDate: 1 }).limit(20);
    if (isValidCoord(ctx.lat, ctx.lng)) {
      items = items.sort((a, b) => distanceMeters(a.location, ctx) - distanceMeters(b.location, ctx));
    }
    const cards = items.slice(0, 4).map((c) => ({
      type: "campaign",
      id: String(c._id),
      title: c.title,
      subtitle: `${c.locationName} · ${new Date(c.startDate).toDateString().slice(4, 10)}`,
      category: c.category,
      points: c.pointsPerParticipant,
      spotsLeft: Math.max(0, c.targetParticipants - c.participants.length),
      joined: c.participants.some((p) => String(p.user) === String(ctx.user._id)),
    }));
    return { cards, summary: cards.map((c) => `${c.title} (${c.subtitle}, +${c.points} pts, ${c.spotsLeft} spots)`) };
  },

  async find_places({ type, material }, ctx) {
    const filter = { active: true };
    if (type) filter.type = type;
    let items = await EcoPlace.find(filter).limit(200);
    if (material) {
      const m = String(material).toLowerCase();
      const matched = items.filter((p) => p.acceptedMaterials.some((a) => a.toLowerCase().includes(m) || m.includes(a.toLowerCase())));
      if (matched.length) items = matched;
    }
    if (isValidCoord(ctx.lat, ctx.lng)) {
      items = items.sort((a, b) => distanceMeters(a.location, ctx) - distanceMeters(b.location, ctx));
    } else {
      items = items.sort((a, b) => Number(b.verified) - Number(a.verified));
    }
    const cards = items.slice(0, 4).map((p) => ({
      type: "place",
      id: String(p._id),
      title: p.name,
      subtitle: [p.type, p.emirate, p.hours].filter(Boolean).join(" · "),
      lat: p.location.lat,
      lng: p.location.lng,
      official: p.verified,
      distanceKm: isValidCoord(ctx.lat, ctx.lng) ? Math.round(distanceMeters(p.location, ctx) / 100) / 10 : null,
    }));
    return { cards, summary: cards.map((c) => `${c.title} (${c.subtitle}${c.official ? ", official partner" : ""})`) };
  },

  async my_points(_, ctx) {
    const recent = await PointsTransaction.find({ user: ctx.user._id }).sort({ createdAt: -1 }).limit(5);
    const balance = resolveEcoPoints(ctx.user);
    return {
      cards: [{ type: "points", balance, recent: recent.map((t) => ({ amount: t.amount, reason: t.reason })) }],
      summary: [`Balance ${balance} Eco Points`, ...recent.map((t) => `${t.amount > 0 ? "+" : ""}${t.amount}: ${t.reason}`)],
    };
  },

  async my_reports(_, ctx) {
    const items = await EnvironmentalReport.find({ reporter: ctx.user._id }).sort({ createdAt: -1 }).limit(4);
    const cards = items.map((r) => ({
      type: "report",
      id: String(r._id),
      title: r.category,
      subtitle: r.landmark || r.emirate,
      status: r.status,
      statusLabel: STATUS_LABELS[r.status],
    }));
    return { cards, summary: cards.length ? cards.map((c) => `${c.title} at ${c.subtitle}: ${c.statusLabel}`) : ["No reports yet"] };
  },

  async recycling_guide({ item }) {
    const g = findGuide(item);
    if (!g) return { cards: [], summary: ["No guide entry for that item"] };
    return { cards: [guideCard(g)], summary: [`${g.name}: ${g.bin}. Prep: ${g.prep.join("; ")}`] };
  },
};

const TOOL_SPECS = [
  {
    name: "find_campaigns",
    description: "Find open, approved environmental campaigns users can join (tree planting, mangroves, beach clean-ups, recycling drives).",
    input_schema: {
      type: "object",
      properties: {
        emirate: { type: "string", enum: EMIRATES },
        category: {
          type: "string",
          enum: ["Tree Plantation", "Mangrove Restoration", "Beach Cleaning", "Public Area Cleaning", "Recycling", "Water Conservation", "Community Gardening", "Awareness Programme"],
        },
      },
    },
  },
  {
    name: "find_places",
    description: "Find recycling centres, recycling bins, e-waste drop-offs and water refill points, nearest first when location is known.",
    input_schema: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["Recycling Centre", "Recycling Bin", "E-waste Drop-off", "Water Refill"] },
        material: { type: "string", description: "e.g. Batteries, Plastic, Phones" },
      },
    },
  },
  { name: "my_points", description: "The user's Eco Points balance and recent ledger entries.", input_schema: { type: "object", properties: {} } },
  { name: "my_reports", description: "Status of environmental problems the user reported.", input_schema: { type: "object", properties: {} } },
  {
    name: "recycling_guide",
    description: "Curated guidance on how to sort or dispose of an item.",
    input_schema: { type: "object", properties: { item: { type: "string" } }, required: ["item"] },
  },
];

const SYSTEM = `You are the GreenifyX assistant inside a UAE environmental action app.
Be warm, practical and brief: at most 3 short sentences, plain text, no markdown lists.
Use the tools for anything about campaigns, places, points, reports or sorting items. Matching results are shown to the user as cards under your reply, so refer to them instead of repeating every detail.
Never invent campaigns, places, dates, point balances or report statuses.
For questions about UAE laws, fines, permits or official regulations, say you can't confirm official rules and suggest checking the relevant emirate's municipality.
If something is outside environmental topics, gently steer back to what GreenifyX can help with.`;

/* ---------------- Offline ("live data") mode ---------------- */

const offlineAnswer = async (text, ctx) => {
  const q = text.toLowerCase();
  if (/\b(point|points|balance|score)\b/.test(q)) {
    const r = await tools.my_points({}, ctx);
    return { reply: `You have ${r.cards[0].balance} Eco Points. Here's your latest activity.`, cards: r.cards };
  }
  if (/(my report|status|dumping report|reported)/.test(q)) {
    const r = await tools.my_reports({}, ctx);
    return {
      reply: r.cards.length ? "Here's where your reports stand." : "You haven't reported anything yet. Use Report & Restore to snap a problem.",
      cards: r.cards,
    };
  }
  const g = findGuide(q);
  const wantsWhere = /(where|near|drop|dispose|throw|recycle|bin)/.test(q);
  if (g) {
    const places = g.placeTypes.length ? await tools.find_places({ type: g.placeTypes[0] }, ctx) : { cards: [] };
    return { reply: `${g.name}: ${g.bin}.`, cards: [guideCard(g), ...places.cards.slice(0, 2)] };
  }
  if (/(refill|water station|drinking water)/.test(q)) {
    const r = await tools.find_places({ type: "Water Refill" }, ctx);
    return { reply: "Here are water refill points to keep your bottle topped up.", cards: r.cards };
  }
  if (/(e-?waste|electronic)/.test(q) || (wantsWhere && /recycl/.test(q))) {
    const r = await tools.find_places({ type: /(e-?waste|electronic)/.test(q) ? "E-waste Drop-off" : undefined }, ctx);
    return { reply: "These drop-off points are closest.", cards: r.cards };
  }
  const hint = CATEGORY_HINTS.find(([k]) => q.includes(k));
  if (hint || /(campaign|volunteer|weekend|join|event|help out|do something)/.test(q)) {
    const emirate = detectEmirate(q);
    let r = await tools.find_campaigns({ emirate, category: hint?.[1] }, ctx);
    if (!r.cards.length) r = await tools.find_campaigns({ emirate }, ctx);
    if (!r.cards.length) r = await tools.find_campaigns({}, ctx);
    return {
      reply: r.cards.length ? "These campaigns are open right now. Points are credited once a field verifier confirms you took part." : "No open campaigns match yet. New ones are added every week.",
      cards: r.cards,
    };
  }
  return {
    reply: "I can find campaigns to join, tell you how to sort an item, show recycling and refill points, or check your points and reports. Try one of the suggestions below.",
    cards: [],
  };
};

/* ---------------- Endpoints ---------------- */

// POST /api/assistant/chat  { messages: [{ role: "user"|"assistant", text }], lat?, lng? }
export const chat = async (req, res) => {
  try {
    if (hitRateLimit({ key: `assistant:${req.user._id}`, max: 40, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "You've asked a lot this hour. Try again a little later." });
    }
    const history = (Array.isArray(req.body.messages) ? req.body.messages : [])
      .filter((m) => m && typeof m.text === "string" && m.text.trim())
      .slice(-10)
      .map((m) => ({ role: m.role === "assistant" ? "assistant" : "user", content: m.text.trim().slice(0, 1000) }));
    if (!history.length || history[history.length - 1].role !== "user") {
      return res.status(400).json({ success: false, message: "Ask a question" });
    }
    const lat = Number(req.body.lat);
    const lng = Number(req.body.lng);
    const ctx = { user: req.user, ...(isValidCoord(lat, lng) ? { lat, lng } : {}) };
    const question = history[history.length - 1].content;

    if (!aiEnabled()) {
      const answer = await offlineAnswer(question, ctx);
      return res.json({ success: true, mode: "live-data", ...answer });
    }

    // Conversation must start with a user turn.
    while (history.length && history[0].role !== "user") history.shift();
    const messages = [...history];
    const cards = [];
    try {
      for (let step = 0; step < 4; step += 1) {
        const response = await callClaude({ system: SYSTEM, messages, tools: TOOL_SPECS, maxTokens: 600 });
        const uses = (response.content || []).filter((b) => b.type === "tool_use");
        if (response.stop_reason !== "tool_use" || uses.length === 0) {
          return res.json({ success: true, mode: "ai", reply: textOf(response) || "Here's what I found.", cards: cards.slice(0, 6) });
        }
        messages.push({ role: "assistant", content: response.content });
        const results = [];
        for (const use of uses) {
          const fn = tools[use.name];
          const out = fn ? await fn(use.input || {}, ctx) : { cards: [], summary: ["Unknown tool"] };
          cards.push(...out.cards);
          results.push({ type: "tool_result", tool_use_id: use.id, content: out.summary.join("\n") || "No results" });
        }
        messages.push({ role: "user", content: results });
      }
      return res.json({ success: true, mode: "ai", reply: "Here's what I found.", cards: cards.slice(0, 6) });
    } catch (aiError) {
      // AI service down or misconfigured: still answer from live data.
      const answer = await offlineAnswer(question, ctx);
      return res.json({ success: true, mode: "live-data", ...answer });
    }
  } catch (error) {
    return sendServerError(res, "The assistant is unavailable right now");
  }
};

const nearbyPlacesFor = async (g, ctx) =>
  g && g.placeTypes.length ? (await tools.find_places({ type: g.placeTypes[0] }, ctx)).cards.slice(0, 3) : [];

// GET /api/assistant/guide?key=&lat=&lng=   (also lists all guide items when key is empty)
export const guide = async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const ctx = { user: req.user, ...(isValidCoord(lat, lng) ? { lat, lng } : {}) };
    if (!req.query.key) {
      return res.json({ success: true, items: GUIDE.map((g) => ({ key: g.key, name: g.name, material: g.material, binColor: g.binColor })) });
    }
    const g = guideByKey(String(req.query.key));
    if (!g) return res.status(404).json({ success: false, message: "Unknown item" });
    res.json({ success: true, result: { ...guideCard(g), confidence: null, item: g.name }, places: await nearbyPlacesFor(g, ctx) });
  } catch (error) {
    return sendServerError(res, "Unable to load guidance");
  }
};

// POST /api/assistant/snap  (multipart: photos[0], lat, lng)
export const snap = async (req, res) => {
  try {
    const file = (req.files || [])[0];
    if (!file) return res.status(400).json({ success: false, message: "Take a photo of the item" });
    if (!aiEnabled()) return res.json({ success: true, aiAvailable: false });
    if (hitRateLimit({ key: `snap:${req.user._id}`, max: 30, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "Too many scans this hour. Try again later." });
    }

    const lat = Number(req.body.lat);
    const lng = Number(req.body.lng);
    const ctx = { user: req.user, ...(isValidCoord(lat, lng) ? { lat, lng } : {}) };
    const keys = GUIDE.map((g) => `${g.key} (${g.name})`).join(", ");

    let parsed = null;
    try {
      const response = await callClaude({
        maxTokens: 400,
        system: "You identify household items for recycling. Reply with JSON only.",
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: file.mimetype === "image/png" ? "image/png" : "image/jpeg", data: file.buffer.toString("base64") } },
              {
                type: "text",
                text:
                  `Identify the main item. Reply as JSON: {"item": short name, "material": string, "guideKey": one of [${keys}] or null, ` +
                  `"bin": where it goes, "prep": [up to 3 short steps], "tip": one short tip, "confidence": 0 to 1}. ` +
                  `Use general best practice, not specific municipal rules.`,
              },
            ],
          },
        ],
      });
      parsed = parseJsonReply(textOf(response));
    } catch {
      parsed = null;
    }
    if (!parsed) return res.json({ success: true, aiAvailable: false });

    const g = guideByKey(parsed.guideKey) || findGuide(`${parsed.item} ${parsed.material}`);
    const result = {
      ...(g ? guideCard(g) : { type: "guide", key: null, binColor: "#6E6578", placeTypes: [] }),
      item: String(parsed.item || g?.name || "Item").slice(0, 60),
      title: String(parsed.item || g?.name || "Item").slice(0, 60),
      material: String(parsed.material || g?.material || "").slice(0, 60),
      bin: String(parsed.bin || g?.bin || "Check local guidance").slice(0, 160),
      prep: (Array.isArray(parsed.prep) && parsed.prep.length ? parsed.prep : g?.prep || []).slice(0, 3).map((s) => String(s).slice(0, 100)),
      tip: String(parsed.tip || g?.tip || "").slice(0, 200),
      confidence: Math.max(0, Math.min(1, Number(parsed.confidence) || 0)),
    };
    res.json({ success: true, aiAvailable: true, result, places: await nearbyPlacesFor(g, ctx) });
  } catch (error) {
    return sendServerError(res, "Unable to analyse the photo");
  }
};
