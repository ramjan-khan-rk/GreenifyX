import HealthDay from "../models/HealthDay.js";
import UtilityBill from "../models/UtilityBill.js";
import Household from "../models/Household.js";
import LessonProgress from "../models/LessonProgress.js";
import { weekWindow } from "../utils/week.js";
import { co2ForKwh } from "../utils/bills.js";
import { sendServerError } from "../utils/httpError.js";

/**
 * GET /api/admin/insights/home?days=30 — Health sync, utility bills, households
 * and Eco Academy in one place, plus recent photo bills to spot-check.
 */
export const homeInsights = async (req, res) => {
  try {
    const days = Math.min(365, Math.max(1, Number(req.query.days) || 30));
    const since = new Date(Date.now() - days * 864e5);
    const sinceDay = since.toISOString().slice(0, 10);
    const { key: week } = weekWindow();
    const [health, healthPeople, bills, recentBills, households, goalsThisWeek, academy, lessonsTop] = await Promise.all([
      HealthDay.aggregate([{ $match: { day: { $gte: sinceDay } } }, { $group: { _id: null, steps: { $sum: "$steps" }, km: { $sum: "$cycleKm" }, points: { $sum: "$points" } } }]),
      HealthDay.distinct("user", { day: { $gte: sinceDay } }),
      UtilityBill.aggregate([
        { $match: { createdAt: { $gte: since } } },
        { $group: { _id: "$source", n: { $sum: 1 }, kwh: { $sum: "$electricityKwh" }, litres: { $sum: "$waterLitres" }, points: { $sum: "$points" } } },
      ]),
      UtilityBill.find({ source: "ai" }).sort({ createdAt: -1 }).limit(12).populate("user", "name emirate").lean(),
      Household.aggregate([{ $group: { _id: null, n: { $sum: 1 }, members: { $sum: { $size: "$members" } } } }]),
      Household.countDocuments({ rewardedWeeks: week }),
      LessonProgress.aggregate([{ $match: { createdAt: { $gte: since } } }, { $group: { _id: null, attempts: { $sum: 1 }, passed: { $sum: { $cond: ["$passed", 1, 0] } }, people: { $addToSet: "$user" } } }]),
      LessonProgress.aggregate([{ $match: { passed: true } }, { $group: { _id: "$lessonId", n: { $sum: 1 } } }, { $sort: { n: -1 } }, { $limit: 5 }]),
    ]);
    const b = Object.fromEntries(bills.map((x) => [x._id, x]));
    res.json({
      success: true,
      days,
      health: { people: healthPeople.length, steps: health[0]?.steps || 0, cycleKm: Math.round((health[0]?.km || 0) * 10) / 10, points: health[0]?.points || 0 },
      bills: {
        photo: b.ai?.n || 0,
        typed: b.manual?.n || 0,
        kwh: Math.round((b.ai?.kwh || 0) + (b.manual?.kwh || 0)),
        co2Kg: co2ForKwh((b.ai?.kwh || 0) + (b.manual?.kwh || 0)),
        points: b.ai?.points || 0,
        recent: recentBills.map((x) => ({ _id: x._id, user: x.user, provider: x.provider, month: x.month, electricityKwh: x.electricityKwh, waterLitres: x.waterLitres, points: x.points, photoUrl: x.photoUrl })),
      },
      households: { count: households[0]?.n || 0, members: households[0]?.members || 0, goalsReachedThisWeek: goalsThisWeek },
      academy: { attempts: academy[0]?.attempts || 0, passed: academy[0]?.passed || 0, people: academy[0]?.people?.length || 0, topLessons: lessonsTop.map((l) => ({ lessonId: l._id, passed: l.n })) },
    });
  } catch (error) {
    return sendServerError(res, "Unable to load these insights");
  }
};
