import mongoose from "mongoose";
import PointsTransaction from "../models/PointsTransaction.js";
import VerificationReport from "../models/VerificationReport.js";
import Campaign from "../models/Campaign.js";
import { kgForActivity } from "./impact.js";

const DAY = 24 * 60 * 60 * 1000;
const CATEGORY_TO_ACTIVITY = {
  "Tree Plantation": "Tree Plantation",
  "Mangrove Restoration": "Tree Plantation",
  "Beach Cleaning": "Cleanliness Drive",
  "Public Area Cleaning": "Cleanliness Drive",
  Recycling: "Recycling",
  "Water Conservation": "Water Conservation",
};

/**
 * Verified impact of an organisation's members over the last `days` days.
 * Everything comes from approved reports and the points ledger, never self-reported numbers.
 */
export const orgImpact = async (org, days = 90) => {
  const since = new Date(Date.now() - days * DAY);
  const memberIds = org.members.map((m) => new mongoose.Types.ObjectId(String(m.user)));

  const [pointsByMember, reports, sponsored] = await Promise.all([
    PointsTransaction.aggregate([
      { $match: { user: { $in: memberIds }, createdAt: { $gte: since } } },
      { $group: { _id: "$user", points: { $sum: "$amount" }, actions: { $sum: { $cond: [{ $gt: ["$amount", 0] }, 1, 0] } } } },
    ]),
    VerificationReport.find({
      status: "approved",
      kind: { $ne: "survival_check" },
      reviewedAt: { $gte: since },
      attendees: { $in: memberIds },
    }).populate("campaign", "title category outputUnit"),
    Campaign.find({ organization: org._id }).select("title status verifiedOutput outputUnit participants startDate endDate category"),
  ]);

  const memberSet = new Set(memberIds.map(String));
  let participations = 0;
  let trees = 0;
  let wasteKg = 0;
  let co2Kg = 0;
  const campaignsJoined = new Set();
  for (const r of reports) {
    const ours = r.attendees.filter((a) => memberSet.has(String(a))).length;
    if (!ours || !r.attendees.length) continue;
    participations += ours;
    campaignsJoined.add(String(r.campaign?._id));
    // Credit the organisation with its members' share of the verified output.
    const share = (r.outputCount || 0) * (ours / r.attendees.length);
    if (r.campaign?.outputUnit === "trees") trees += share;
    if (r.campaign?.outputUnit === "kg") wasteKg += share;
    const activity = CATEGORY_TO_ACTIVITY[r.campaign?.category];
    co2Kg += r.campaign?.outputUnit === "trees" ? share * kgForActivity(activity) : ours * kgForActivity(activity);
  }

  const points = pointsByMember.reduce((a, p) => a + p.points, 0);
  return {
    days,
    members: org.members.length,
    activeMembers: pointsByMember.filter((p) => p.actions > 0).length,
    points,
    participations,
    campaignsJoined: campaignsJoined.size,
    trees: Math.round(trees),
    wasteKg: Math.round(wasteKg),
    co2Kg: Math.round(co2Kg * 10) / 10,
    pointsByMember: new Map(pointsByMember.map((p) => [String(p._id), p.points])),
    sponsored: sponsored.map((c) => ({
      _id: c._id,
      title: c.title,
      status: c.status,
      category: c.category,
      verifiedOutput: c.verifiedOutput,
      outputUnit: c.outputUnit,
      participants: c.participants.length,
      startDate: c.startDate,
    })),
  };
};
