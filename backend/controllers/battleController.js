import mongoose from "mongoose";
import PointsTransaction from "../models/PointsTransaction.js";
import User from "../models/User.js";
import Community from "../models/Community.js";
import Organization from "../models/Organization.js";
import BattleResult from "../models/BattleResult.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { creditPoints } from "../utils/ledger.js";
import { sendServerError } from "../utils/httpError.js";
import { weekWindow, previousWeekWindow } from "../utils/week.js";

const EARN_TYPES = ["campaign_verified", "post_verified", "challenge_won", "report_resolved", "pickup_collected", "community_challenge", "adjustment"];
const ORG_LEAGUES = { schools: "School", companies: "Company", universities: "University" };
const PRIZES = [50, 30, 15]; // bonus Eco Points per member for 1st/2nd/3rd

/** Map userId -> points earned in the window. */
export const pointsByUser = async ({ start, end }, userIds) => {
  const match = { createdAt: { $gte: start, $lt: end }, amount: { $gt: 0 }, status: "credited", type: { $in: EARN_TYPES } };
  if (userIds) match.user = { $in: userIds.map((u) => new mongoose.Types.ObjectId(String(u))) };
  const rows = await PointsTransaction.aggregate([{ $match: match }, { $group: { _id: "$user", points: { $sum: "$amount" } } }]);
  return new Map(rows.map((r) => [String(r._id), r.points]));
};

const rankRows = (rows) =>
  rows
    .sort((a, b) => b.points - a.points || (b.members || 0) - (a.members || 0))
    .map((r, i) => ({ ...r, rank: i + 1 }));

const groupStandings = async (window, groups) => {
  const all = [...new Set(groups.flatMap((g) => g.memberIds.map(String)))];
  const pts = await pointsByUser(window, all);
  return rankRows(
    groups.map((g) => {
      const total = g.memberIds.reduce((s, m) => s + (pts.get(String(m)) || 0), 0);
      return { refId: g._id, name: g.name, image: g.image || "", members: g.memberIds.length, points: total, perMember: g.memberIds.length ? Math.round(total / g.memberIds.length) : 0 };
    })
  );
};

const leagueStandings = async (league, window) => {
  if (league === "communities") {
    const cs = await Community.find({ isHidden: { $ne: true } }).select("name coverImage members").lean();
    return groupStandings(window, cs.map((c) => ({ _id: c._id, name: c.name, image: c.coverImage, memberIds: c.members || [] })));
  }
  if (ORG_LEAGUES[league]) {
    const os = await Organization.find({ status: "verified", type: ORG_LEAGUES[league] }).select("name logo members").lean();
    const st = await groupStandings(window, os.map((o) => ({ _id: o._id, name: o.name, image: o.logo || "", memberIds: (o.members || []).map((m) => m.user) })));
    // Organisations compete per member so size doesn't decide the winner.
    return rankRows(st.map((s) => ({ ...s, points: s.perMember, totalPoints: s.points })));
  }
  if (league === "members") {
    const pts = await pointsByUser(window);
    const top = [...pts].sort((a, b) => b[1] - a[1]).slice(0, 50);
    const users = await User.find({ _id: { $in: top.map(([id]) => id) } }).select("name profileImage").lean();
    const u = Object.fromEntries(users.map((x) => [String(x._id), x]));
    return rankRows(top.map(([id, p]) => ({ refId: id, name: u[id]?.name || "Member", image: u[id]?.profileImage || "", points: p, members: 1 })));
  }
  return [];
};

/** Close last week's leagues once: store standings and pay the podium. */
const finalizeLastWeek = async (league) => {
  const prev = previousWeekWindow();
  if (await BattleResult.exists({ week: prev.key, league })) return;
  const standings = (await leagueStandings(league, prev)).slice(0, 20);
  let doc;
  try {
    doc = await BattleResult.create({ week: prev.key, league, standings });
  } catch (e) {
    if (e?.code === 11000) return; // another request finalised it
    throw e;
  }
  const podium = standings.filter((s) => s.points > 0).slice(0, 3);
  for (const [i, s] of podium.entries()) {
    let memberIds = [];
    if (league === "communities") memberIds = (await Community.findById(s.refId).select("members").lean())?.members || [];
    else if (ORG_LEAGUES[league]) memberIds = ((await Organization.findById(s.refId).select("members").lean())?.members || []).map((m) => m.user);
    else if (league === "members") memberIds = [s.refId];
    for (const uid of memberIds) {
      await creditPoints({ userId: uid, amount: PRIZES[i], type: "battle_won", reason: `Weekly battle ${prev.key}: #${i + 1} in ${league} (${s.name})` });
      await User.updateOne({ _id: uid }, { $addToSet: { badges: i === 0 ? "battle_champion" : "battle_podium" } });
      try {
        const n = await Notification.create({
          receiver: uid,
          sender: uid,
          type: "points",
          title: i === 0 ? "🏆 Weekly champions!" : "🥈 On the podium!",
          message: `${s.name} finished #${i + 1} in the ${league} battle. +${PRIZES[i]} Eco Points.`,
        });
        emitToUser(uid, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }
  }
  doc.rewardedAt = new Date();
  await doc.save();
};

// GET /api/battles?league=friends|communities|schools|companies|universities|members
export const getBattle = async (req, res) => {
  try {
    const league = String(req.query.league || "friends");
    const window = weekWindow();
    const me = String(req.user._id);
    let standings;
    if (league === "friends") {
      const user = await User.findById(me).select("friends");
      const ids = [me, ...(user?.friends || []).map(String)];
      const [pts, users] = await Promise.all([pointsByUser(window, ids), User.find({ _id: { $in: ids } }).select("name profileImage level").lean()]);
      standings = rankRows(users.map((u) => ({ refId: u._id, name: u.name, image: u.profileImage || "", level: u.level, points: pts.get(String(u._id)) || 0, isMe: String(u._id) === me })));
    } else {
      await finalizeLastWeek(league).catch((e) => console.error("Battle finalize failed:", e.message));
      standings = await leagueStandings(league, window);
      // Mark the member's own team.
      let mine = new Set();
      if (league === "communities") mine = new Set((await Community.find({ members: me }).select("_id").lean()).map((c) => String(c._id)));
      else if (ORG_LEAGUES[league]) mine = new Set((await Organization.find({ "members.user": me }).select("_id").lean()).map((o) => String(o._id)));
      else if (league === "members") mine = new Set([me]);
      standings = standings.map((s) => ({ ...s, isMe: mine.has(String(s.refId)) }));
    }
    const last = league === "friends" ? null : await BattleResult.findOne({ league, week: previousWeekWindow().key }).lean();
    const user = await User.findById(me).select("badges").lean();
    res.json({
      success: true,
      league,
      week: window.key,
      startsAt: window.start,
      endsAt: window.end,
      prizes: PRIZES,
      standings: standings.slice(0, 50),
      mine: standings.find((s) => s.isMe) || null,
      lastWeek: last ? last.standings.slice(0, 3) : [],
      achievements: (user?.badges || []).filter(Boolean),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load battle");
  }
};
