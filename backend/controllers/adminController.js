import mongoose from "mongoose";
import User from "../models/User.js";
import Post from "../models/Post.js";
import Challenge from "../models/Challenge.js";
import Comment from "../models/Comment.js";
import Campaign from "../models/Campaign.js";
import VerificationReport from "../models/VerificationReport.js";
import EnvironmentalReport from "../models/EnvironmentalReport.js";
import Redemption from "../models/Redemption.js";
import PickupRequest from "../models/PickupRequest.js";
import Event from "../models/Event.js";
import { resolveEcoPoints } from "../utils/ecoPoints.js";
import { escapeRegex } from "../utils/escapeRegex.js";
import { parsePagination } from "../utils/pagination.js";
import { sendServerError } from "../utils/httpError.js";
import { estimateCo2Kg, kgForActivity } from "../utils/impact.js";
import { EMIRATES, normalizeEmirate } from "../utils/emirates.js";

const TZ = "Asia/Dubai";
const DAY = 24 * 60 * 60 * 1000;
const isId = (id) => mongoose.Types.ObjectId.isValid(id);

const adminUserView = (u) => ({
  _id: u._id,
  name: u.name || "",
  email: u.email || "",
  phone: u.phone || "",
  profileImage: u.profileImage || "",
  emirate: u.emirate || "",
  role: u.role || "user",
  isVerifiedResident: u.isVerifiedResident === true,
  isSuspended: u.isSuspended === true,
  suspendedReason: u.suspendedReason || "",
  ecoPoints: resolveEcoPoints(u),
  level: u.level || 1,
  streak: u.streak || 0,
  friendsCount: Array.isArray(u.friends) ? u.friends.length : 0,
  createdAt: u.createdAt,
});

/** Fill missing days so charts get a continuous 30-day line. */
const fillDays = (rows, days) => {
  const byDay = new Map(rows.map((r) => [r._id, r.count]));
  const out = [];
  const fmt = new Intl.DateTimeFormat("en-CA", { timeZone: TZ });
  for (let i = days - 1; i >= 0; i -= 1) {
    const key = fmt.format(new Date(Date.now() - i * DAY));
    out.push({ date: key, count: byDay.get(key) || 0 });
  }
  return out;
};

const perDay = (Model, since) =>
  Model.aggregate([
    { $match: { createdAt: { $gte: since } } },
    {
      $group: {
        _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt", timezone: TZ } },
        count: { $sum: 1 },
      },
    },
  ]);

// GET /api/admin/me
export const getAdminMe = (req, res) => {
  res.json({ success: true, admin: adminUserView(req.user) });
};

// GET /api/admin/stats
export const getStats = async (req, res) => {
  try {
    const days = 30;
    const since = new Date(Date.now() - days * DAY);
    const weekAgo = new Date(Date.now() - 7 * DAY);
    const prevWeek = new Date(Date.now() - 14 * DAY);

    const [
      totalUsers,
      suspendedUsers,
      newUsersWeek,
      newUsersPrevWeek,
      totalPosts,
      verifiedPosts,
      reportedPosts,
      hiddenPosts,
      totalComments,
      activeAuthors,
      challengeStatus,
      pointsAgg,
      verifiedByActivity,
      postsByActivity,
      usersByEmirate,
      signupsDaily,
      postsDaily,
      topUsers,
      recentPosts,
      campaignStatus,
      reportStatus,
      campaignOutput,
      participantsAgg,
      issueStatus,
      survivalCampaigns,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ isSuspended: true }),
      User.countDocuments({ createdAt: { $gte: weekAgo } }),
      User.countDocuments({ createdAt: { $gte: prevWeek, $lt: weekAgo } }),
      Post.countDocuments(),
      Post.countDocuments({ isVerified: true }),
      Post.countDocuments({ "reports.0": { $exists: true }, isHidden: { $ne: true } }),
      Post.countDocuments({ isHidden: true }),
      Comment.countDocuments(),
      Post.distinct("user", { createdAt: { $gte: weekAgo } }),
      Challenge.aggregate([{ $group: { _id: "$status", count: { $sum: 1 } } }]),
      User.aggregate([
        { $group: { _id: null, total: { $sum: { $ifNull: ["$ecoPoints", 0] } } } },
      ]),
      Post.aggregate([
        { $match: { isVerified: true } },
        { $group: { _id: "$activity", count: { $sum: 1 } } },
      ]),
      Post.aggregate([
        { $group: { _id: "$activity", count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 8 },
      ]),
      User.aggregate([{ $group: { _id: "$emirate", count: { $sum: 1 } } }]),
      perDay(User, since),
      perDay(Post, since),
      User.find({ isSuspended: { $ne: true } })
        .sort({ ecoPoints: -1 })
        .limit(5)
        .select("name profileImage emirate ecoPoints level streak"),
      Post.find()
        .sort({ createdAt: -1 })
        .limit(8)
        .populate("user", "name profileImage emirate")
        .select("user activity isVerified ecoPoints createdAt image mediaType"),
      Campaign.aggregate([{ $group: { _id: "$status", count: { $sum: 1 } } }]),
      VerificationReport.aggregate([{ $group: { _id: "$status", count: { $sum: 1 } } }]),
      Campaign.aggregate([{ $group: { _id: "$outputUnit", total: { $sum: "$verifiedOutput" } } }]),
      Campaign.aggregate([
        { $unwind: "$participants" },
        { $group: { _id: "$participants.status", count: { $sum: 1 } } },
      ]),
      EnvironmentalReport.aggregate([{ $group: { _id: "$status", count: { $sum: 1 } } }]),
      Campaign.find({ "survivalChecks.0": { $exists: true } }).select("title emirate verifiedOutput survivalChecks"),
    ]);
    // Latest checkpoint per planting campaign: planted (verified) vs still alive.
    const survival = survivalCampaigns
      .map((c) => {
        const latest = [...c.survivalChecks].sort((a, b) => b.checkpointDays - a.checkpointDays)[0];
        return {
          _id: c._id,
          title: c.title,
          emirate: c.emirate,
          planted: c.verifiedOutput || 0,
          surviving: latest?.surviving || 0,
          checkpointDays: latest?.checkpointDays || 0,
          checks: [...c.survivalChecks]
            .sort((a, b) => a.checkpointDays - b.checkpointDays)
            .map((s) => ({ checkpointDays: s.checkpointDays, surviving: s.surviving })),
        };
      })
      .filter((s) => s.planted > 0);
    const survivalPlanted = survival.reduce((a, s) => a + s.planted, 0);
    const survivalSurviving = survival.reduce((a, s) => a + Math.min(s.surviving, s.planted), 0);
    const issuesBy = Object.fromEntries(issueStatus.map((c) => [c._id, c.count]));
    const campaignsBy = Object.fromEntries(campaignStatus.map((c) => [c._id, c.count]));
    const reportsBy = Object.fromEntries(reportStatus.map((c) => [c._id, c.count]));
    const outputBy = Object.fromEntries(campaignOutput.map((c) => [c._id, c.total]));
    const participantsBy = Object.fromEntries(participantsAgg.map((c) => [c._id, c.count]));

    const challenges = Object.fromEntries(challengeStatus.map((c) => [c._id, c.count]));
    const emirateCounts = new Map(usersByEmirate.map((e) => [e._id || null, e.count]));

    const [redemptionsIssued, pickupAgg, upcomingEvents, rsvpAgg] = await Promise.all([
      Redemption.countDocuments({ status: { $ne: "cancelled" } }),
      PickupRequest.aggregate([{ $group: { _id: "$status", n: { $sum: 1 }, kg: { $sum: { $ifNull: ["$collectedKg", 0] } } } }]),
      Event.countDocuments({ isPublished: true, startsAt: { $gte: new Date() } }),
      Event.aggregate([{ $match: { isPublished: true, startsAt: { $gte: new Date() } } }, { $group: { _id: null, n: { $sum: { $size: "$attendees" } } } }]),
    ]);
    const pickupsBy = Object.fromEntries(pickupAgg.map((p) => [p._id, p]));

    res.json({
      success: true,
      generatedAt: new Date().toISOString(),
      timezone: TZ,
      kpis: {
        totalUsers,
        activeUsers7d: activeAuthors.length,
        newUsers7d: newUsersWeek,
        newUsersPrev7d: newUsersPrevWeek,
        suspendedUsers,
        verifiedResidents: await User.countDocuments({ isVerifiedResident: true }),
        totalPosts,
        verifiedPosts,
        verificationRate: totalPosts ? Math.round((verifiedPosts / totalPosts) * 100) : 0,
        reportedPosts,
        hiddenPosts,
        totalComments,
        ecoPointsIssued: pointsAgg[0]?.total || 0,
        co2SavedKg: estimateCo2Kg(
          verifiedByActivity.map((r) => ({ activity: r._id, count: r.count }))
        ),
        challengesActive: (challenges.ongoing || 0) + (challenges.pending || 0),
        challengesCompleted: challenges.completed || 0,
        campaignsTotal: Object.values(campaignsBy).reduce((a, b) => a + b, 0),
        campaignsActive: campaignsBy.active || 0,
        reportsPending: reportsBy.pending || 0,
        reportsApproved: reportsBy.approved || 0,
        reportsRejected: reportsBy.rejected || 0,
        treesVerified: outputBy.trees || 0,
        wasteKgVerified: outputBy.kg || 0,
        campaignParticipants: Object.values(participantsBy).reduce((a, b) => a + b, 0),
        campaignParticipantsVerified: participantsBy.verified || 0,
        issuesOpen: (issuesBy.submitted || 0) + (issuesBy.under_review || 0) + (issuesBy.forwarded || 0),
        issuesNew: issuesBy.submitted || 0,
        issuesResolved: issuesBy.resolved || 0,
        survivalPlanted,
        survivalSurviving,
        survivalRate: survivalPlanted ? Math.round((survivalSurviving / survivalPlanted) * 100) : null,
        rewardsRedeemed: redemptionsIssued,
        pickupsOpen: (pickupsBy.requested?.n || 0) + (pickupsBy.scheduled?.n || 0),
        pickupKgCollected: pickupsBy.collected?.kg || 0,
        eventsUpcoming: upcomingEvents,
        eventRsvps: rsvpAgg[0]?.n || 0,
      },
      series: {
        signups: fillDays(signupsDaily, days),
        posts: fillDays(postsDaily, days),
      },
      impactByActivity: verifiedByActivity
        .map((r) => {
          const activity = r._id || "Other";
          const perAction = kgForActivity(activity);
          return {
            activity,
            verifiedActions: r.count,
            kgPerAction: perAction,
            co2Kg: Math.round(perAction * r.count * 10) / 10,
          };
        })
        .sort((a, b) => b.co2Kg - a.co2Kg),
      survival,
      byActivity: postsByActivity.map((r) => ({ activity: r._id || "Other", count: r.count })),
      byEmirate: [
        ...EMIRATES.map((name) => ({ emirate: name, count: emirateCounts.get(name) || 0 })),
        { emirate: "Not set", count: emirateCounts.get(null) || 0 },
      ],
      topUsers: topUsers.map(adminUserView),
      recentPosts: recentPosts.map((p) => ({
        _id: p._id,
        activity: p.activity,
        isVerified: p.isVerified,
        ecoPoints: p.ecoPoints,
        image: p.image,
        mediaType: p.mediaType,
        createdAt: p.createdAt,
        user: p.user
          ? { _id: p.user._id, name: p.user.name, profileImage: p.user.profileImage, emirate: p.user.emirate || "" }
          : null,
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load dashboard stats");
  }
};

// GET /api/admin/users?q=&status=all|active|suspended|admins&emirate=&page=&limit=
export const listUsers = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const filter = {};
    const q = String(req.query.q || "").trim();
    if (q) {
      const rx = new RegExp(escapeRegex(q), "i");
      filter.$or = [{ name: rx }, { email: rx }, { phone: rx }];
    }
    const status = String(req.query.status || "all");
    if (status === "suspended") filter.isSuspended = true;
    if (status === "active") filter.isSuspended = { $ne: true };
    if (status === "admins") filter.role = "admin";
    if (status === "verifiers") filter.role = "verifier";
    if (status === "residents") filter.isVerifiedResident = true;
    const emirate = normalizeEmirate(req.query.emirate);
    if (emirate) filter.emirate = emirate;

    const sortKey = req.query.sort === "points" ? { ecoPoints: -1 } : { createdAt: -1 };

    const [users, total] = await Promise.all([
      User.find(filter).sort(sortKey).skip(skip).limit(limit),
      User.countDocuments(filter),
    ]);

    res.json({ success: true, page, limit, total, users: users.map(adminUserView) });
  } catch (error) {
    return sendServerError(res, "Unable to load users");
  }
};

// GET /api/admin/users/:id
export const getUser = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const [posts, verified, challenges] = await Promise.all([
      Post.countDocuments({ user: user._id }),
      Post.countDocuments({ user: user._id, isVerified: true }),
      Challenge.countDocuments({ $or: [{ creator: user._id }, { friend: user._id }] }),
    ]);

    res.json({
      success: true,
      user: { ...adminUserView(user), bio: user.bio || "", stats: { posts, verified, challenges } },
    });
  } catch (error) {
    return sendServerError(res, "Unable to load user");
  }
};

// PATCH /api/admin/users/:id/status  { suspended: boolean, reason?: string }
export const setUserStatus = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    if (typeof req.body.suspended !== "boolean") {
      return res.status(400).json({ success: false, message: "suspended must be true or false" });
    }
    if (String(req.params.id) === String(req.user._id)) {
      return res.status(400).json({ success: false, message: "You cannot change your own status" });
    }

    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: "User not found" });
    if (user.role === "admin") {
      return res.status(400).json({ success: false, message: "Admins cannot be suspended here" });
    }

    user.isSuspended = req.body.suspended;
    user.suspendedReason = req.body.suspended
      ? String(req.body.reason || "").trim().slice(0, 200)
      : "";
    await user.save();

    res.json({ success: true, user: adminUserView(user) });
  } catch (error) {
    return sendServerError(res, "Unable to update user");
  }
};

const adminPostView = (p) => ({
  _id: p._id,
  image: p.image,
  mediaType: p.mediaType,
  description: p.description || "",
  activity: p.activity,
  cause: p.cause,
  ecoPoints: p.ecoPoints,
  isVerified: p.isVerified,
  isHidden: p.isHidden === true,
  likesCount: Array.isArray(p.likes) ? p.likes.length : 0,
  reports: (p.reports || []).map((r) => ({ reason: r.reason, createdAt: r.createdAt })),
  reportsCount: (p.reports || []).length,
  createdAt: p.createdAt,
  user: p.user
    ? { _id: p.user._id, name: p.user.name, profileImage: p.user.profileImage, emirate: p.user.emirate || "" }
    : null,
});

// GET /api/admin/posts?filter=all|reported|hidden|unverified|verified&q=&page=&limit=
export const listPosts = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const filter = {};
    switch (String(req.query.filter || "all")) {
      case "reported":
        filter["reports.0"] = { $exists: true };
        filter.isHidden = { $ne: true };
        break;
      case "hidden":
        filter.isHidden = true;
        break;
      case "unverified":
        filter.isVerified = { $ne: true };
        break;
      case "verified":
        filter.isVerified = true;
        break;
      default:
        break;
    }
    const q = String(req.query.q || "").trim();
    if (q) {
      const rx = new RegExp(escapeRegex(q), "i");
      filter.$or = [{ activity: rx }, { description: rx }];
    }

    const [posts, total] = await Promise.all([
      Post.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("user", "name profileImage emirate"),
      Post.countDocuments(filter),
    ]);

    res.json({ success: true, page, limit, total, posts: posts.map(adminPostView) });
  } catch (error) {
    return sendServerError(res, "Unable to load posts");
  }
};

// PATCH /api/admin/posts/:id/moderate  { action: "hide" | "restore" | "dismiss" }
export const moderatePost = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const action = String(req.body.action || "");
    if (!["hide", "restore", "dismiss"].includes(action)) {
      return res.status(400).json({ success: false, message: "action must be hide, restore or dismiss" });
    }

    const post = await Post.findById(req.params.id).populate("user", "name profileImage emirate");
    if (!post) return res.status(404).json({ success: false, message: "Post not found" });

    if (action === "hide") post.isHidden = true;
    if (action === "restore") post.isHidden = false;
    if (action === "dismiss") post.reports = [];
    post.moderatedBy = req.user._id;
    post.moderatedAt = new Date();
    await post.save();

    res.json({ success: true, post: adminPostView(post) });
  } catch (error) {
    return sendServerError(res, "Unable to moderate post");
  }
};

// GET /api/admin/challenges?status=&page=&limit=
export const listChallenges = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const filter = {};
    const status = String(req.query.status || "");
    if (["pending", "ongoing", "completed", "rejected", "expired"].includes(status)) {
      filter.status = status;
    }

    const [items, total] = await Promise.all([
      Challenge.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("creator", "name profileImage")
        .populate("friend", "name profileImage")
        .populate("winner", "name"),
      Challenge.countDocuments(filter),
    ]);

    res.json({
      success: true,
      page,
      limit,
      total,
      challenges: items.map((c) => ({
        _id: c._id,
        title: c.title,
        activity: c.activity,
        difficulty: c.difficulty,
        target: c.target,
        creatorProgress: c.creatorProgress,
        friendProgress: c.friendProgress,
        ecoReward: c.ecoReward,
        deadline: c.deadline,
        status: c.status,
        createdAt: c.createdAt,
        creator: c.creator ? { _id: c.creator._id, name: c.creator.name } : null,
        friend: c.friend ? { _id: c.friend._id, name: c.friend.name } : null,
        winner: c.winner ? { _id: c.winner._id, name: c.winner.name } : null,
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load challenges");
  }
};
