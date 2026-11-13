import UtilityBill from "../models/UtilityBill.js";
import { aiEnabled, callClaude, parseJsonReply, textOf } from "../utils/ai.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { creditPoints } from "../utils/ledger.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { sendServerError } from "../utils/httpError.js";
import { billPoints, co2ForKwh, normalizeBill, percentChange, previousMonth } from "../utils/bills.js";

/**
 * Scans hold the photo and the AI reading for a short time, so a member can
 * only earn points for numbers that really came from a photo.
 */
const scans = new Map();
const SCAN_TTL_MS = 30 * 60 * 1000;
const keepScan = (userId, data) => {
  const id = `${userId}:${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
  scans.set(id, { ...data, at: Date.now() });
  for (const [k, v] of scans) if (Date.now() - v.at > SCAN_TTL_MS) scans.delete(k);
  return id;
};

// POST /api/bills/scan  (multipart: photo)
export const scanBill = async (req, res) => {
  try {
    const file = req.file;
    if (!file) return res.status(400).json({ success: false, message: "Take a photo of your bill" });
    if (hitRateLimit({ key: `bill:${req.user._id}`, max: 20, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "Too many scans this hour. Try again later." });
    }
    if (!aiEnabled()) return res.json({ success: true, aiAvailable: false });

    let parsed = null;
    try {
      const response = await callClaude({
        maxTokens: 300,
        system: "You read UAE utility bills (DEWA, ADDC, AADC, SEWA, Etihad WE). Reply with JSON only.",
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: file.mimetype === "image/png" ? "image/png" : "image/jpeg", data: file.buffer.toString("base64") } },
              {
                type: "text",
                text:
                  'Read this bill. Reply as JSON: {"isBill": true/false, "provider": string, "month": "YYYY-MM" of the billing period end, ' +
                  '"electricityKwh": number, "waterLitres": number or null, "waterM3": number or null, "waterIG": number or null (imperial gallons), ' +
                  '"amountAed": total due as a number}. Use null for anything you cannot read.',
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
    if (parsed.isBill === false) return res.status(400).json({ success: false, message: "That doesn't look like a utility bill. Try a clearer photo." });

    const bill = normalizeBill(parsed);
    const photoUrl = await uploadBufferToCloudinary(file.buffer, "GreenifyX/bills").catch(() => "");
    const scanId = keepScan(req.user._id, { bill, photoUrl });
    res.json({ success: true, aiAvailable: true, scanId, bill });
  } catch (error) {
    return sendServerError(res, "Unable to read the bill");
  }
};

// POST /api/bills  { scanId?, provider, month, electricityKwh, waterLitres, amountAed }
export const saveBill = async (req, res) => {
  try {
    const bill = normalizeBill(req.body || {});
    if (!bill.month) return res.status(400).json({ success: false, message: "Choose the bill month" });
    if (!bill.electricityKwh && !bill.waterLitres) return res.status(400).json({ success: false, message: "Add electricity or water use" });

    // Points only when the saved numbers match what was read from the photo.
    const scan = req.body?.scanId && String(req.body.scanId).startsWith(`${req.user._id}:`) ? scans.get(req.body.scanId) : null;
    const fromPhoto =
      scan &&
      scan.bill.month === bill.month &&
      scan.bill.provider === bill.provider &&
      scan.bill.electricityKwh === bill.electricityKwh &&
      scan.bill.waterLitres === bill.waterLitres;
    if (scan) scans.delete(req.body.scanId);

    const exists = await UtilityBill.findOne({ user: req.user._id, provider: bill.provider, month: bill.month });
    if (exists) return res.status(409).json({ success: false, message: "You already added this month's bill" });

    const prev = await UtilityBill.findOne({ user: req.user._id, provider: bill.provider, month: previousMonth(bill.month) }).lean();
    const points = fromPhoto ? billPoints(prev, bill) : 0;
    const saved = await UtilityBill.create({
      user: req.user._id,
      ...bill,
      photoUrl: scan?.photoUrl || "",
      source: fromPhoto ? "ai" : "manual",
      points,
    });
    if (points > 0) {
      await creditPoints({ userId: req.user._id, amount: points, type: "bill_saving", reason: `${bill.provider} bill ${bill.month}` });
    }
    res.status(201).json({ success: true, bill: saved, points });
  } catch (error) {
    if (error?.code === 11000) return res.status(409).json({ success: false, message: "You already added this month's bill" });
    return sendServerError(res, "Unable to save the bill");
  }
};

// GET /api/bills — newest first, with change against the month before.
export const myBills = async (req, res) => {
  try {
    const bills = await UtilityBill.find({ user: req.user._id }).sort({ month: -1 }).limit(24).lean();
    const byKey = new Map(bills.map((b) => [`${b.provider}:${b.month}`, b]));
    const rows = bills.map((b) => {
      const prev = byKey.get(`${b.provider}:${previousMonth(b.month)}`);
      return {
        ...b,
        co2Kg: co2ForKwh(b.electricityKwh),
        electricityChange: prev ? percentChange(prev.electricityKwh, b.electricityKwh) : null,
        waterChange: prev ? percentChange(prev.waterLitres, b.waterLitres) : null,
      };
    });
    res.json({ success: true, bills: rows });
  } catch (error) {
    return sendServerError(res, "Unable to load your bills");
  }
};

// DELETE /api/bills/:id — manual bills only (photo bills earned points).
export const deleteBill = async (req, res) => {
  try {
    const r = await UtilityBill.deleteOne({ _id: req.params.id, user: req.user._id, source: "manual" });
    if (!r.deletedCount) return res.status(404).json({ success: false, message: "Bill not found, or it was read from a photo" });
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Unable to delete the bill");
  }
};
