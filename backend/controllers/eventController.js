import mongoose from "mongoose";
import Event, { EVENT_CATEGORIES } from "../models/Event.js";
import Campaign from "../models/Campaign.js";
import { sendServerError } from "../utils/httpError.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

const shape = (e, me) => ({
  _id: e._id,
  kind: "event",
  title: e.title,
  description: e.description,
  category: e.category,
  startsAt: e.startsAt,
  endsAt: e.endsAt,
  venue: e.venue,
  emirate: e.emirate,
  location: e.location,
  coverImage: e.coverImage,
  organizer: e.organizer,
  capacity: e.capacity,
  attendeeCount: e.attendees?.length || 0,
  going: (e.attendees || []).some((a) => String(a) === String(me)),
});

// GET /api/events?from=&to=  — events merged with active campaigns, sorted by start.
export const listEvents = async (req, res) => {
  try {
    const from = req.query.from ? new Date(req.query.from) : new Date(Date.now() - 24 * 3600 * 1000);
    const to = req.query.to ? new Date(req.query.to) : new Date(Date.now() + 120 * 24 * 3600 * 1000);
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) return res.status(400).json({ success: false, message: "Invalid date range" });

    const [events, campaigns] = await Promise.all([
      Event.find({ isPublished: true, endsAt: { $gte: from }, startsAt: { $lte: to } }).sort({ startsAt: 1 }).limit(200),
      Campaign.find({ status: "active", endDate: { $gte: from }, startDate: { $lte: to } })
        .select("title description category emirate locationName location startDate endDate coverImage participants pointsPerParticipant")
        .sort({ startDate: 1 })
        .limit(100),
    ]);

    const items = [
      ...events.map((e) => shape(e, req.user._id)),
      ...campaigns.map((c) => ({
        _id: c._id,
        kind: "campaign",
        title: c.title,
        description: c.description,
        category: c.category || "campaign",
        startsAt: c.startDate,
        endsAt: c.endDate,
        venue: c.locationName,
        emirate: c.emirate,
        location: c.location?.lat !== undefined ? { lat: c.location.lat, lng: c.location.lng } : undefined,
        coverImage: c.coverImage,
        organizer: "GreenifyX campaign",
        attendeeCount: c.participants?.length || 0,
        going: (c.participants || []).some((p) => String(p.user) === String(req.user._id)),
      })),
    ].sort((a, b) => new Date(a.startsAt) - new Date(b.startsAt));

    res.json({ success: true, items });
  } catch (e) {
    return sendServerError(res, "Unable to load events");
  }
};

// POST /api/events/:id/rsvp  — toggle going.
export const toggleRsvp = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid event" });
    const e = await Event.findOne({ _id: req.params.id, isPublished: true });
    if (!e) return res.status(404).json({ success: false, message: "Event not found" });
    const me = String(req.user._id);
    const going = e.attendees.some((a) => String(a) === me);
    if (going) {
      await Event.updateOne({ _id: e._id }, { $pull: { attendees: req.user._id } });
    } else {
      const filter = { _id: e._id };
      if (e.capacity > 0) filter[`attendees.${e.capacity - 1}`] = { $exists: false };
      const r = await Event.updateOne(filter, { $addToSet: { attendees: req.user._id } });
      if (r.modifiedCount === 0) return res.status(400).json({ success: false, message: "This event is full" });
    }
    const fresh = await Event.findById(e._id);
    res.json({ success: true, event: shape(fresh, req.user._id) });
  } catch (err) {
    return sendServerError(res, "Unable to update RSVP");
  }
};

/* ---------------- Admin ---------------- */

const pickEventFields = (b) => {
  const out = {};
  for (const k of ["title", "description", "venue", "emirate", "coverImage", "organizer"]) if (typeof b[k] === "string") out[k] = b[k].trim();
  if (EVENT_CATEGORIES.includes(b.category)) out.category = b.category;
  for (const k of ["startsAt", "endsAt"]) {
    if (b[k]) {
      const d = new Date(b[k]);
      if (!Number.isNaN(d.getTime())) out[k] = d;
    }
  }
  if (b.capacity !== undefined) out.capacity = Math.max(0, Math.round(Number(b.capacity) || 0));
  if (typeof b.isPublished === "boolean") out.isPublished = b.isPublished;
  const lat = Number(b.location?.lat);
  const lng = Number(b.location?.lng);
  if (Number.isFinite(lat) && Number.isFinite(lng)) out.location = { lat, lng };
  if (b.organization === null || b.organization === "") out.organization = null;
  else if (isId(b.organization)) out.organization = b.organization;
  return out;
};

export const adminListEvents = async (req, res) => {
  try {
    const events = await Event.find().sort({ startsAt: -1 }).limit(300);
    res.json({ success: true, events: events.map((e) => ({ ...e.toObject(), attendeeCount: e.attendees.length, attendees: undefined })) });
  } catch (e) {
    return sendServerError(res, "Unable to load events");
  }
};

export const adminCreateEvent = async (req, res) => {
  try {
    const data = pickEventFields(req.body || {});
    if (!data.title || !data.startsAt || !data.endsAt) return res.status(400).json({ success: false, message: "Title, start and end are required" });
    if (data.endsAt < data.startsAt) return res.status(400).json({ success: false, message: "End must be after start" });
    const event = await Event.create(data);
    res.status(201).json({ success: true, event });
  } catch (e) {
    return sendServerError(res, "Unable to create event");
  }
};

export const adminUpdateEvent = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid event" });
    const event = await Event.findByIdAndUpdate(req.params.id, pickEventFields(req.body || {}), { new: true, runValidators: true });
    if (!event) return res.status(404).json({ success: false, message: "Event not found" });
    res.json({ success: true, event });
  } catch (e) {
    return sendServerError(res, "Unable to update event");
  }
};
