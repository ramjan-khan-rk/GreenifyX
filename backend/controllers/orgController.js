import crypto from "crypto";
import mongoose from "mongoose";
import Organization, { ORG_TYPES } from "../models/Organization.js";
import Campaign from "../models/Campaign.js";
import { sendServerError } from "../utils/httpError.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { resolveEcoPoints } from "../utils/ecoPoints.js";
import { orgImpact } from "../utils/orgImpact.js";
import { parsePagination } from "../utils/pagination.js";

const isId = (id) => mongoose.Types.ObjectId.isValid(id);
const bad = (res, message, code = 400) => res.status(code).json({ success: false, message });

// Unambiguous characters only (no 0/O, 1/I).
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const makeJoinCode = () =>
  Array.from(crypto.randomBytes(6), (b) => CODE_CHARS[b % CODE_CHARS.length]).join("");

const uniqueJoinCode = async () => {
  for (let i = 0; i < 8; i += 1) {
    const code = makeJoinCode();
    if (!(await Organization.exists({ joinCode: code }))) return code;
  }
  throw new Error("Could not allocate a join code");
};

const myRole = (org, userId) => org.members.find((m) => String(m.user?._id ?? m.user) === String(userId))?.role || null;

const publicOrg = (org, me) => {
  const role = me ? myRole(org, me) : null;
  return {
    _id: org._id,
    name: org.name,
    type: org.type,
    emirate: org.emirate,
    description: org.description,
    website: org.website,
    logo: org.logo,
    status: org.status,
    verified: org.status === "verified",
    memberCount: org.members.length,
    myRole: role,
    // Only managers see the code they share with colleagues.
    joinCode: role === "owner" || role === "manager" ? org.joinCode : undefined,
    createdAt: org.createdAt,
  };
};

// GET /api/orgs/mine
export const myOrgs = async (req, res) => {
  try {
    const orgs = await Organization.find({ "members.user": req.user._id, status: { $ne: "rejected" } }).sort({ createdAt: 1 });
    res.json({ success: true, organizations: orgs.map((o) => publicOrg(o, req.user._id)) });
  } catch (error) {
    return sendServerError(res, "Unable to load your organisations");
  }
};

// POST /api/orgs  { name, type, emirate, description, website, registrationRef, contactEmail }
export const registerOrg = async (req, res) => {
  try {
    const name = String(req.body.name || "").trim().slice(0, 120);
    if (name.length < 3) return bad(res, "Enter the organisation's name");
    if (!ORG_TYPES.includes(req.body.type)) return bad(res, "Choose an organisation type");
    const owned = await Organization.countDocuments({ createdBy: req.user._id, status: { $in: ["pending", "verified"] } });
    if (owned >= 3) return bad(res, "You can register up to 3 organisations");
    if (await Organization.exists({ name: new RegExp(`^${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "i"), status: { $ne: "rejected" } })) {
      return bad(res, "An organisation with this name is already registered. Ask its manager for the join code.");
    }

    const org = await Organization.create({
      name,
      type: req.body.type,
      emirate: normalizeEmirate(req.body.emirate) || "",
      description: String(req.body.description || "").trim().slice(0, 600),
      website: String(req.body.website || "").trim().slice(0, 200),
      registrationRef: String(req.body.registrationRef || "").trim().slice(0, 80),
      contactEmail: String(req.body.contactEmail || req.user.email || "").trim().slice(0, 120),
      joinCode: await uniqueJoinCode(),
      members: [{ user: req.user._id, role: "owner" }],
      createdBy: req.user._id,
    });
    res.status(201).json({
      success: true,
      message: "Submitted. Our team verifies organisations before they get the trusted badge.",
      organization: publicOrg(org, req.user._id),
    });
  } catch (error) {
    return sendServerError(res, "Unable to register organisation");
  }
};

// POST /api/orgs/join  { code }
export const joinOrg = async (req, res) => {
  try {
    const code = String(req.body.code || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (code.length !== 6) return bad(res, "Enter the 6-character join code");
    const org = await Organization.findOne({ joinCode: code });
    if (!org || org.status === "rejected" || org.status === "suspended") return bad(res, "That code didn't match an active organisation", 404);
    if (!myRole(org, req.user._id)) {
      org.members.push({ user: req.user._id, role: "member" });
      await org.save();
    }
    res.json({ success: true, organization: publicOrg(org, req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to join organisation");
  }
};

// POST /api/orgs/:id/leave
export const leaveOrg = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const org = await Organization.findById(req.params.id);
    if (!org) return bad(res, "Organisation not found", 404);
    const role = myRole(org, req.user._id);
    if (!role) return res.json({ success: true });
    if (role === "owner" && org.members.filter((m) => m.role === "owner").length === 1 && org.members.length > 1) {
      return bad(res, "Make someone else an owner before you leave");
    }
    org.members = org.members.filter((m) => String(m.user) !== String(req.user._id));
    await org.save();
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Unable to leave organisation");
  }
};

// GET /api/orgs/:id/dashboard?days=90   (members only)
export const orgDashboard = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const org = await Organization.findById(req.params.id).populate("members.user", "name profileImage ecoPoints emirate");
    if (!org) return bad(res, "Organisation not found", 404);
    const role = myRole(org, req.user._id);
    if (!role && req.user.role !== "admin") return bad(res, "Join this organisation to see its dashboard", 403);

    const days = [30, 90, 365].includes(Number(req.query.days)) ? Number(req.query.days) : 90;
    const impact = await orgImpact(org, days);
    const members = org.members
      .filter((m) => m.user)
      .map((m) => ({
        _id: m.user._id,
        name: m.user.name,
        profileImage: m.user.profileImage,
        role: m.role,
        periodPoints: impact.pointsByMember.get(String(m.user._id)) || 0,
        totalPoints: resolveEcoPoints(m.user),
      }))
      .sort((a, b) => b.periodPoints - a.periodPoints);

    const { pointsByMember, ...summary } = impact;
    res.json({
      success: true,
      organization: publicOrg(org, req.user._id),
      impact: summary,
      members: role === "owner" || role === "manager" || req.user.role === "admin" ? members : members.slice(0, 10),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load dashboard");
  }
};

// GET /api/orgs/leaderboard?days=90   (verified organisations only)
export const orgLeaderboard = async (req, res) => {
  try {
    const days = [30, 90, 365].includes(Number(req.query.days)) ? Number(req.query.days) : 90;
    const orgs = await Organization.find({ status: "verified" }).limit(100);
    const rows = [];
    for (const o of orgs) {
      const impact = await orgImpact(o, days);
      rows.push({
        _id: o._id,
        name: o.name,
        type: o.type,
        emirate: o.emirate,
        logo: o.logo,
        members: impact.members,
        points: impact.points,
        participations: impact.participations,
        trees: impact.trees,
        // Per-member score so large and small teams compete fairly.
        pointsPerMember: impact.members ? Math.round(impact.points / impact.members) : 0,
        isMine: o.members.some((m) => String(m.user) === String(req.user._id)),
      });
    }
    rows.sort((a, b) => b.pointsPerMember - a.pointsPerMember || b.points - a.points);
    res.json({ success: true, days, organizations: rows.slice(0, 30) });
  } catch (error) {
    return sendServerError(res, "Unable to load leaderboard");
  }
};

/* ---------------- Admin ---------------- */

const adminOrg = (o) => ({
  ...publicOrg(o),
  joinCode: o.joinCode,
  registrationRef: o.registrationRef,
  contactEmail: o.contactEmail,
  statusNote: o.statusNote,
  verifiedAt: o.verifiedAt,
  owner: (() => {
    const m = o.members.find((x) => x.role === "owner");
    return m?.user?.name !== undefined ? { _id: m.user._id, name: m.user.name, email: m.user.email } : null;
  })(),
});

// GET /api/admin/orgs?status=
export const adminListOrgs = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const filter = {};
    if (["pending", "verified", "rejected", "suspended"].includes(req.query.status)) filter.status = req.query.status;
    const [items, total, counts] = await Promise.all([
      Organization.find(filter).sort({ status: 1, createdAt: -1 }).skip(skip).limit(limit).populate("members.user", "name email"),
      Organization.countDocuments(filter),
      Organization.aggregate([{ $group: { _id: "$status", n: { $sum: 1 } } }]),
    ]);
    const rows = [];
    for (const o of items) {
      const impact = o.status === "verified" ? await orgImpact(o, 90) : null;
      rows.push({
        ...adminOrg(o),
        impact: impact ? { points: impact.points, participations: impact.participations, trees: impact.trees, co2Kg: impact.co2Kg } : null,
      });
    }
    res.json({ success: true, page, limit, total, counts: Object.fromEntries(counts.map((c) => [c._id, c.n])), organizations: rows });
  } catch (error) {
    return sendServerError(res, "Unable to load organisations");
  }
};

// PATCH /api/admin/orgs/:id/status  { status, note }
export const adminSetOrgStatus = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const status = req.body.status;
    if (!["verified", "rejected", "suspended", "pending"].includes(status)) return bad(res, "Invalid status");
    const note = String(req.body.note || "").trim().slice(0, 300);
    if ((status === "rejected" || status === "suspended") && note.length < 3) return bad(res, "Add a short reason");
    const o = await Organization.findById(req.params.id).populate("members.user", "name email");
    if (!o) return bad(res, "Organisation not found", 404);
    o.status = status;
    o.statusNote = note;
    if (status === "verified") o.verifiedAt = new Date();
    await o.save();
    if (status !== "verified") await Campaign.updateMany({ organization: o._id, status: "draft" }, { $set: { organization: null } });
    res.json({ success: true, organization: adminOrg(o) });
  } catch (error) {
    return sendServerError(res, "Unable to update organisation");
  }
};

// GET /api/admin/orgs/options  — verified orgs for the campaign editor
export const adminOrgOptions = async (req, res) => {
  try {
    const orgs = await Organization.find({ status: "verified" }).sort({ name: 1 }).select("name type");
    res.json({ success: true, organizations: orgs.map((o) => ({ _id: o._id, name: o.name, type: o.type })) });
  } catch (error) {
    return sendServerError(res, "Unable to load organisations");
  }
};
