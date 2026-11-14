import RecyclingStation, { Dropoff } from "../models/RecyclingStation.js";
import { creditPoints } from "../utils/ledger.js";
import { distanceMeters, isValidCoord } from "../utils/geo.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { sendServerError } from "../utils/httpError.js";
import {
  MATERIALS,
  NEAR_STATION_M,
  STATION_KINDS,
  STATION_STATUSES,
  dropoffPoints,
  estimateKg,
  isStationCode,
  makeStationCode,
} from "../utils/recycling.js";

const publicStation = (s, from) => ({
  _id: s._id,
  name: s.name,
  code: s.code,
  kind: s.kind,
  materials: s.materials,
  emirate: s.emirate,
  address: s.address,
  location: s.location,
  operator: s.operator,
  status: s.status,
  statusAt: s.statusAt,
  distanceM: from && s.location?.lat != null ? Math.round(distanceMeters(from, s.location)) : null,
});

// GET /api/stations?lat&lng — nearest first.
export const listStations = async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const from = isValidCoord(lat, lng) ? { lat, lng } : null;
    const stations = await RecyclingStation.find({ status: { $ne: "retired" } }).limit(500).lean();
    const list = stations.map((s) => publicStation(s, from));
    if (from) list.sort((a, b) => (a.distanceM ?? 1e12) - (b.distanceM ?? 1e12));
    res.json({ success: true, materials: MATERIALS, stations: list.slice(0, 100) });
  } catch (error) {
    return sendServerError(res, "Unable to load recycling stations");
  }
};

// POST /api/stations/dropoff { code, material, quantity, unit, lat, lng }
export const logDropoff = async (req, res) => {
  try {
    if (hitRateLimit({ key: `dropoff:${req.user._id}`, max: 30, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "Too many drop-offs this hour. Try again later." });
    }
    const code = String(req.body?.code || "").trim().toUpperCase();
    if (!isStationCode(code)) return res.status(400).json({ success: false, message: "That isn't a GreenifyX recycling station code" });
    const station = await RecyclingStation.findOne({ code });
    if (!station || station.status === "retired") return res.status(404).json({ success: false, message: "Station not found" });
    if (station.status === "out_of_service") return res.status(400).json({ success: false, message: "This station is out of service. Try another one nearby." });

    const material = MATERIALS[req.body?.material] ? req.body.material : "mixed";
    const unit = req.body?.unit === "bags" ? "bags" : "items";
    const kg = estimateKg(material, req.body?.quantity, unit);
    if (kg <= 0) return res.status(400).json({ success: false, message: "Tell us how much you dropped off" });

    const lat = Number(req.body?.lat);
    const lng = Number(req.body?.lng);
    const here = isValidCoord(lat, lng) ? { lat, lng } : null;
    const distanceM = here && station.location?.lat != null ? Math.round(distanceMeters(here, station.location)) : null;
    // Stations without a location can't be checked, so they count as near.
    const near = station.location?.lat == null ? true : distanceM !== null && distanceM <= NEAR_STATION_M;

    const day = calendarDayStamp(new Date());
    const today = await Dropoff.find({ user: req.user._id, day }).select("station points").lean();
    const points = dropoffPoints({
      kg,
      near,
      earnedToday: today.reduce((s, d) => s + (d.points || 0), 0),
      todayAtStation: today.filter((d) => String(d.station) === String(station._id)).length,
    });
    const drop = await Dropoff.create({ user: req.user._id, station: station._id, material, quantity: Number(req.body?.quantity) || 0, unit, estimatedKg: kg, points, distanceM, day });
    if (points > 0) await creditPoints({ userId: req.user._id, amount: points, type: "checkin", reason: `Recycled at ${station.name}` });
    res.status(201).json({
      success: true,
      dropoff: drop,
      points,
      station: publicStation(station.toObject(), here),
      note: points > 0 ? "" : !near ? "Logged. Points need you to be at the station (turn on location)." : "Logged. You've reached today's points for this station.",
    });
  } catch (error) {
    return sendServerError(res, "Unable to log the drop-off");
  }
};

// GET /api/stations/mine — my recent drop-offs and totals.
export const myDropoffs = async (req, res) => {
  try {
    const list = await Dropoff.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(50).populate("station", "name emirate").lean();
    const all = await Dropoff.aggregate([{ $match: { user: req.user._id } }, { $group: { _id: null, kg: { $sum: "$estimatedKg" }, n: { $sum: 1 }, points: { $sum: "$points" } } }]);
    res.json({ success: true, dropoffs: list, totals: { dropoffs: all[0]?.n || 0, kg: Math.round((all[0]?.kg || 0) * 10) / 10, points: all[0]?.points || 0 } });
  } catch (error) {
    return sendServerError(res, "Unable to load your drop-offs");
  }
};

// POST /api/stations/:id/report { issue: "full" | "broken" | "dirty" }
export const reportStation = async (req, res) => {
  try {
    const issue = ["full", "broken", "dirty"].includes(req.body?.issue) ? req.body.issue : null;
    if (!issue) return res.status(400).json({ success: false, message: "Choose what's wrong" });
    if (hitRateLimit({ key: `station-report:${req.user._id}:${req.params.id}`, max: 1, windowMs: 6 * 60 * 60 * 1000 })) {
      return res.json({ success: true, message: "Thanks, we already have your report." });
    }
    const s = await RecyclingStation.findByIdAndUpdate(req.params.id, { $inc: { [`reports.${issue}`]: 1 } }, { new: true });
    if (!s) return res.status(404).json({ success: false, message: "Station not found" });
    // Three "full" reports mark it full until an admin clears it.
    if (issue === "full" && s.reports.full >= 3 && s.status === "active") {
      s.status = "full";
      s.statusNote = "Reported full by members";
      s.statusAt = new Date();
      await s.save();
    }
    res.json({ success: true, message: "Thanks, the operator will be told." });
  } catch (error) {
    return sendServerError(res, "Unable to send the report");
  }
};

// ---------- admin ----------

const STATION_FIELDS = ["name", "kind", "materials", "address", "operator", "organization", "status", "statusNote"];

// GET /api/admin/stations?days=30 — every station with volumes.
export const adminStations = async (req, res) => {
  try {
    const days = Math.min(365, Math.max(1, Number(req.query.days) || 30));
    const since = new Date(Date.now() - days * 864e5);
    const [stations, volumes, byEmirate] = await Promise.all([
      RecyclingStation.find().sort({ createdAt: -1 }).lean(),
      Dropoff.aggregate([{ $match: { createdAt: { $gte: since } } }, { $group: { _id: "$station", kg: { $sum: "$estimatedKg" }, n: { $sum: 1 }, people: { $addToSet: "$user" } } }]),
      Dropoff.aggregate([
        { $match: { createdAt: { $gte: since } } },
        { $lookup: { from: "recyclingstations", localField: "station", foreignField: "_id", as: "s" } },
        { $unwind: "$s" },
        { $group: { _id: "$s.emirate", kg: { $sum: "$estimatedKg" }, n: { $sum: 1 } } },
      ]),
    ]);
    const v = Object.fromEntries(volumes.map((x) => [String(x._id), x]));
    res.json({
      success: true,
      days,
      stations: stations.map((s) => ({
        ...s,
        dropoffs: v[String(s._id)]?.n || 0,
        kg: Math.round((v[String(s._id)]?.kg || 0) * 10) / 10,
        people: v[String(s._id)]?.people?.length || 0,
      })),
      byEmirate: byEmirate.map((e) => ({ emirate: e._id || "Unknown", kg: Math.round(e.kg * 10) / 10, dropoffs: e.n })),
      materials: MATERIALS,
      kinds: STATION_KINDS,
      statuses: STATION_STATUSES,
    });
  } catch (error) {
    return sendServerError(res, "Unable to load stations");
  }
};

const applyFields = (s, b) => {
  for (const k of STATION_FIELDS) if (b[k] !== undefined) s[k] = b[k];
  if (b.materials !== undefined) s.materials = (Array.isArray(b.materials) ? b.materials : []).filter((m) => MATERIALS[m]);
  if (b.emirate !== undefined) s.emirate = normalizeEmirate(b.emirate) || "";
  const lat = Number(b.lat);
  const lng = Number(b.lng);
  if (b.lat !== undefined && isValidCoord(lat, lng)) s.location = { lat, lng };
};

// POST /api/admin/stations
export const adminCreateStation = async (req, res) => {
  try {
    const s = new RecyclingStation({ code: makeStationCode() });
    applyFields(s, req.body || {});
    if (!s.name) return res.status(400).json({ success: false, message: "Name the station" });
    for (let i = 0; i < 5; i++) {
      try {
        await s.save();
        break;
      } catch (e) {
        if (e?.code !== 11000 || i === 4) throw e;
        s.code = makeStationCode();
      }
    }
    res.status(201).json({ success: true, station: s });
  } catch (error) {
    return sendServerError(res, "Unable to add the station");
  }
};

// PATCH /api/admin/stations/:id — clearing reports when the status changes.
export const adminUpdateStation = async (req, res) => {
  try {
    const s = await RecyclingStation.findById(req.params.id);
    if (!s) return res.status(404).json({ success: false, message: "Station not found" });
    const statusBefore = s.status;
    applyFields(s, req.body || {});
    if (s.status !== statusBefore || req.body?.clearReports) {
      s.statusAt = new Date();
      s.reports = { full: 0, broken: 0, dirty: 0 };
    }
    await s.save();
    res.json({ success: true, station: s });
  } catch (error) {
    return sendServerError(res, "Unable to update the station");
  }
};
