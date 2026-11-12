import Post from "../models/Post.js";
import User from "../models/User.js";
import Event from "../models/Event.js";
import Campaign from "../models/Campaign.js";
import EcoActivity from "../models/EcoActivity.js";
import { pointsByUser } from "./battleController.js";
import { aiEnabled, callClaude, textOf, parseJsonReply } from "../utils/ai.js";
import { buildInterestProfile, topInterests } from "../utils/recommend.js";
import { weekWindow } from "../utils/week.js";
import { sendServerError } from "../utils/httpError.js";

const DAY = 864e5;

const IDEAS = {
  Planet: ["Show a before/after of the spot you cleaned", "Film a 15-second tip your friends can copy today", "Share your reusable kit: bottle, cup, bag"],
  Humanity: ["Tell the story of someone you helped (with permission)", "Share a photo of a shared iftar or meal", "Thank a volunteer who inspires you"],
  Wildlife: ["Capture the birds visiting your water bowl", "Share a fact about the Arabian oryx or turtles", "Show a safe, respectful wildlife moment"],
  Stories: ["How did your first eco habit start?", "One small win from this week", "What would you tell your younger self about waste?"],
};

/** Simple seeded pick so suggestions stay stable for the whole day. */
const pick = (list, seed) => (list.length ? list[Math.abs(seed) % list.length] : null);
const hash = (s) => [...s].reduce((h, c) => (h * 31 + c.charCodeAt(0)) | 0, 7);

// GET /api/companion/today
export const today = async (req, res) => {
  try {
    const me = await User.findById(req.user._id).select("name friends interests weeklyGoal streak ecoPoints level emirate");
    const now = new Date();
    const week = weekWindow(now);
    const seed = hash(`${me._id}:${now.toISOString().slice(0, 10)}`);

    const [posted, liked, activities, weekPts, fourWeeks, weekPosts] = await Promise.all([
      Post.find({ user: me._id }).sort({ createdAt: -1 }).limit(60).select("activity cause createdAt").lean(),
      Post.find({ likes: me._id }).sort({ createdAt: -1 }).limit(100).select("activity cause createdAt").lean(),
      EcoActivity.find({ isActive: true }).lean(),
      pointsByUser(week, [me._id]),
      pointsByUser({ start: new Date(week.start - 28 * DAY), end: week.start }, [me._id]),
      Post.countDocuments({ user: me._id, createdAt: { $gte: week.start } }),
    ]);
    const profile = buildInterestProfile({ posted, liked, picked: me.interests || [] });
    const favourites = topInterests(profile, 3);
    const recent = new Set(posted.filter((p) => now - new Date(p.createdAt) < 3 * DAY).map((p) => p.activity));

    // Daily activity: something you like that you haven't done for 3 days, else something new.
    const liked1 = activities.filter((a) => favourites.includes(a.name) && !recent.has(a.name));
    const fresh = activities.filter((a) => !profile.activity.has(a.name) && a.lane === "Planet");
    const daily = pick(liked1.length ? liked1 : fresh.length ? fresh : activities, seed);

    // Challenge idea: the friend closest to your points.
    const friends = await User.find({ _id: { $in: me.friends || [] } }).select("name profileImage ecoPoints").lean();
    const rival = friends.sort((a, b) => Math.abs(a.ecoPoints - me.ecoPoints) - Math.abs(b.ecoPoints - me.ecoPoints))[0];
    const challengeActivity = pick(activities.filter((a) => a.lane === "Planet" && a.points >= 15), seed + 3);

    // Goal: a bit more than your recent weekly average.
    const avg = (fourWeeks.get(String(me._id)) || 0) / 4;
    const suggestedPoints = Math.max(50, Math.round((avg * 1.2) / 10) * 10);
    const goal = me.weeklyGoal?.points > 0 && me.weeklyGoal.setAt >= week.start ? me.weeklyGoal : null;
    const thisWeek = weekPts.get(String(me._id)) || 0;

    const lane = daily?.lane || "Planet";
    const idea = pick(IDEAS[lane] || IDEAS.Planet, seed + 7);

    const [event, campaign] = await Promise.all([
      Event.findOne({ isPublished: true, startsAt: { $gte: now }, ...(me.emirate ? { emirate: me.emirate } : {}) }).sort({ startsAt: 1 }).select("title startsAt venue emirate").lean(),
      Campaign.findOne({ status: "active", endDate: { $gte: now }, ...(me.emirate ? { emirate: me.emirate } : {}) }).sort({ startDate: 1 }).select("title startDate locationName emirate").lean(),
    ]);

    const first = (me.name || "").split(" ")[0] || "there";
    let message = `Hi ${first}! ${thisWeek > 0 ? `You've earned ${thisWeek} points this week — keep it going.` : "A fresh week — let's start with one small action today."}`;

    if (aiEnabled()) {
      try {
        const r = await callClaude({
          system:
            "You are GreenifyX's friendly eco companion for UAE residents. Reply with JSON {\"message\": string} only. The message is 1-2 short, warm, specific sentences (max 220 characters) that motivate the user today. No hashtags.",
          messages: [
            {
              role: "user",
              content: JSON.stringify({
                name: first,
                emirate: me.emirate,
                streakDays: me.streak,
                pointsThisWeek: thisWeek,
                weeklyGoal: goal?.points || suggestedPoints,
                favouriteActivities: favourites,
                suggestedToday: daily?.name,
                upcomingEvent: event?.title,
              }),
            },
          ],
          maxTokens: 200,
          timeoutMs: 8000,
        });
        const j = parseJsonReply(textOf(r));
        if (j?.message) message = String(j.message).slice(0, 280);
      } catch {
        /* keep the template */
      }
    }

    res.json({
      success: true,
      message,
      stats: { pointsThisWeek: thisWeek, postsThisWeek: weekPosts, streak: me.streak || 0, level: me.level, favourites },
      goal: goal
        ? { points: goal.points, actions: goal.actions, progressPoints: thisWeek, progressActions: weekPosts }
        : null,
      suggestedGoal: { points: suggestedPoints, actions: Math.max(3, Math.round(suggestedPoints / 25)) },
      daily: daily ? { name: daily.name, nameAr: daily.nameAr, line: daily.line, icon: daily.icon, points: daily.points, lane: daily.lane } : null,
      challenge: rival && challengeActivity
        ? { friendId: rival._id, friendName: rival.name, friendImage: rival.profileImage, activity: challengeActivity.name, text: `Challenge ${rival.name.split(" ")[0]} to 3× "${challengeActivity.name}" this week` }
        : null,
      contentIdea: idea,
      nearby: event
        ? { kind: "event", id: event._id, title: event.title, when: event.startsAt, where: event.venue || event.emirate }
        : campaign
          ? { kind: "campaign", id: campaign._id, title: campaign.title, when: campaign.startDate, where: campaign.locationName }
          : null,
      ai: aiEnabled(),
    });
  } catch (e) {
    return sendServerError(res, "Your companion is taking a break. Try again.");
  }
};

// POST /api/companion/goal { points, actions }
export const setGoal = async (req, res) => {
  try {
    const points = Math.max(10, Math.min(5000, Math.round(Number(req.body?.points) || 0)));
    const actions = Math.max(1, Math.min(100, Math.round(Number(req.body?.actions) || 0)));
    await User.updateOne({ _id: req.user._id }, { weeklyGoal: { points, actions, setAt: new Date() } });
    res.json({ success: true, goal: { points, actions } });
  } catch (e) {
    return sendServerError(res, "Unable to save your goal");
  }
};
