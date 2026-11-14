import BrandDeal from "../models/BrandDeal.js";
import Follow from "../models/Follow.js";
import Post from "../models/Post.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { canMove, creatorPayout, eligibility } from "../utils/deals.js";
import { sendServerError } from "../utils/httpError.js";
import User from "../models/User.js";
import { createAccountLink, createConnectAccount, getAccount, paymentsEnabled } from "../utils/stripe.js";

const site = () => (process.env.PUBLIC_SITE_URL || "https://greenifyx-admin.netlify.app").replace(/\/+$/, "");

// GET /api/deals/payouts — is automatic payout available, and has this creator set it up?
export const payoutStatus = async (req, res) => {
  try {
    if (!paymentsEnabled()) return res.json({ success: true, available: false, ready: false });
    const me = await User.findById(req.user._id).select("stripeAccountId").lean();
    if (!me?.stripeAccountId) return res.json({ success: true, available: true, ready: false });
    const acct = await getAccount(me.stripeAccountId).catch(() => null);
    res.json({ success: true, available: true, ready: Boolean(acct?.payouts_enabled), started: true });
  } catch (error) {
    return sendServerError(res, "Unable to check payouts");
  }
};

// POST /api/deals/payouts/setup — opens Stripe's own page to add bank details (GreenifyX never sees them).
export const payoutSetup = async (req, res) => {
  try {
    if (!paymentsEnabled()) return res.status(503).json({ success: false, message: "Automatic payouts aren't switched on yet" });
    const me = await User.findById(req.user._id).select("stripeAccountId email");
    if (!me.stripeAccountId) {
      const acct = await createConnectAccount({ email: me.email || undefined });
      me.stripeAccountId = acct.id;
      await me.save();
    }
    const link = await createAccountLink({ account: me.stripeAccountId, refreshUrl: `${site()}/#/payouts/retry`, returnUrl: `${site()}/#/payouts/done` });
    res.json({ success: true, url: link.url });
  } catch (error) {
    return res.status(400).json({ success: false, message: `Stripe: ${error.message}` });
  }
};

const notify = async (userId, title, message, dealId) => {
  try {
    const n = await Notification.create({ receiver: userId, type: "sponsored", title, message, referenceId: dealId });
    emitToUser(userId, "newNotification", n);
  } catch {
    /* best-effort */
  }
};

const forCreator = (d, meId, followers) => {
  const mine = (d.applications || []).find((a) => String(a.user) === String(meId)) || null;
  const e = eligibility({ deal: d, followers, application: mine });
  return {
    _id: d._id,
    brand: d.brand,
    brandLogo: d.brandLogo,
    title: d.title,
    brief: d.brief,
    activity: d.activity,
    hashtag: d.hashtag,
    payoutAed: d.payoutAed,
    youReceiveAed: creatorPayout(d.payoutAed, d.platformFeePct),
    platformFeePct: d.platformFeePct,
    minFollowers: d.minFollowers,
    slots: d.slots,
    deadline: d.deadline,
    canApply: e.ok,
    reason: e.reason,
    application: mine ? { status: mine.status, post: mine.post || null, appliedAt: mine.appliedAt } : null,
  };
};

// GET /api/deals — open deals plus any I've applied to.
export const listDeals = async (req, res) => {
  try {
    const [deals, followers] = await Promise.all([
      BrandDeal.find({ $or: [{ status: "open" }, { "applications.user": req.user._id }] }).sort({ createdAt: -1 }).limit(50).lean(),
      Follow.countDocuments({ followee: req.user._id }),
    ]);
    res.json({ success: true, followers, deals: deals.map((d) => forCreator(d, req.user._id, followers)) });
  } catch (error) {
    return sendServerError(res, "Unable to load brand deals");
  }
};

// POST /api/deals/:id/apply { pitch }
export const applyToDeal = async (req, res) => {
  try {
    const deal = await BrandDeal.findById(req.params.id);
    if (!deal) return res.status(404).json({ success: false, message: "Deal not found" });
    const followers = await Follow.countDocuments({ followee: req.user._id });
    const mine = deal.applications.find((a) => String(a.user) === String(req.user._id));
    const e = eligibility({ deal, followers, application: mine });
    if (!e.ok) return res.status(400).json({ success: false, message: e.reason });
    const pitch = String(req.body?.pitch || "").trim().slice(0, 500);
    const updated = await BrandDeal.findOneAndUpdate(
      { _id: deal._id, "applications.user": { $ne: req.user._id } },
      { $push: { applications: { user: req.user._id, pitch } } },
      { new: true }
    ).lean();
    if (!updated) return res.status(400).json({ success: false, message: "You've already applied" });
    res.json({ success: true, deal: forCreator(updated, req.user._id, followers) });
  } catch (error) {
    return sendServerError(res, "Unable to apply");
  }
};

// POST /api/deals/:id/deliver { postId } — link the post you made for the brand.
export const deliverDeal = async (req, res) => {
  try {
    const deal = await BrandDeal.findById(req.params.id);
    if (!deal) return res.status(404).json({ success: false, message: "Deal not found" });
    const app = deal.applications.find((a) => String(a.user) === String(req.user._id));
    if (!app || app.status !== "accepted") return res.status(400).json({ success: false, message: "You can deliver once the brand accepts you" });
    const post = await Post.findOne({ _id: req.body?.postId, user: req.user._id, isHidden: { $ne: true } }).select("visibility createdAt");
    if (!post) return res.status(400).json({ success: false, message: "Choose one of your posts" });
    if (post.visibility !== "public") return res.status(400).json({ success: false, message: "The post must be public" });
    if (post.createdAt < app.updatedAt) return res.status(400).json({ success: false, message: "Use a post made after you were accepted" });
    app.status = "delivered";
    app.post = post._id;
    app.updatedAt = new Date();
    await deal.save();
    const followers = await Follow.countDocuments({ followee: req.user._id });
    res.json({ success: true, deal: forCreator(deal.toObject(), req.user._id, followers) });
  } catch (error) {
    return sendServerError(res, "Unable to deliver");
  }
};

// ---------- admin ----------

const DEAL_FIELDS = ["brand", "brandLogo", "title", "brief", "activity", "hashtag", "payoutAed", "platformFeePct", "minFollowers", "slots", "deadline", "status"];
const pick = (body = {}) => Object.fromEntries(DEAL_FIELDS.filter((k) => body[k] !== undefined).map((k) => [k, body[k]]));

// GET /api/admin/deals
export const adminDeals = async (req, res) => {
  try {
    const deals = await BrandDeal.find().sort({ createdAt: -1 }).limit(100).populate("applications.user", "name email profileImage").lean();
    const counts = await Follow.aggregate([
      { $match: { followee: { $in: deals.flatMap((d) => d.applications.map((a) => a.user?._id).filter(Boolean)) } } },
      { $group: { _id: "$followee", n: { $sum: 1 } } },
    ]);
    const byUser = Object.fromEntries(counts.map((c) => [String(c._id), c.n]));
    res.json({
      success: true,
      deals: deals.map((d) => ({
        ...d,
        youReceiveAed: creatorPayout(d.payoutAed, d.platformFeePct),
        applications: d.applications.map((a) => ({ ...a, followers: byUser[String(a.user?._id)] || 0 })),
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load deals");
  }
};

// POST /api/admin/deals
export const adminCreateDeal = async (req, res) => {
  try {
    const deal = await BrandDeal.create(pick(req.body));
    res.status(201).json({ success: true, deal });
  } catch (error) {
    if (error?.name === "ValidationError") return res.status(400).json({ success: false, message: "Brand, title and payout are required" });
    return sendServerError(res, "Unable to create the deal");
  }
};

// PATCH /api/admin/deals/:id
export const adminUpdateDeal = async (req, res) => {
  try {
    const deal = await BrandDeal.findByIdAndUpdate(req.params.id, pick(req.body), { new: true, runValidators: true });
    if (!deal) return res.status(404).json({ success: false, message: "Deal not found" });
    res.json({ success: true, deal });
  } catch (error) {
    if (error?.name === "ValidationError") return res.status(400).json({ success: false, message: "Check the deal fields" });
    return sendServerError(res, "Unable to update the deal");
  }
};

// PATCH /api/admin/deals/:id/applications/:userId { status }
export const adminMoveApplication = async (req, res) => {
  try {
    const deal = await BrandDeal.findById(req.params.id);
    if (!deal) return res.status(404).json({ success: false, message: "Deal not found" });
    const app = deal.applications.find((a) => String(a.user) === String(req.params.userId));
    if (!app) return res.status(404).json({ success: false, message: "Application not found" });
    const to = String(req.body?.status || "");
    if (!canMove(app.status, to)) return res.status(400).json({ success: false, message: `Can't move from ${app.status} to ${to}` });
    if (to === "accepted" && deal.slots) {
      const taken = deal.applications.filter((a) => a !== app && ["accepted", "delivered", "paid"].includes(a.status)).length;
      if (taken >= deal.slots) return res.status(400).json({ success: false, message: "All spots are taken" });
    }
    // Paying: send the creator's share automatically through Stripe Connect when they've set it up;
    // otherwise it's recorded as a manual bank transfer, as before.
    let paidVia = "";
    if (to === "paid") {
      const creator = await User.findById(app.user).select("stripeAccountId").lean();
      if (paymentsEnabled() && creator?.stripeAccountId && req.body?.manual !== true) {
        try {
          const acct = await getAccount(creator.stripeAccountId);
          if (!acct.payouts_enabled) return res.status(400).json({ success: false, message: "The creator hasn't finished payout setup with Stripe yet. Pay manually or ask them to finish." });
          const t = await createTransfer({
            amountAed: creatorPayout(deal.payoutAed, deal.platformFeePct),
            destination: creator.stripeAccountId,
            metadata: { deal: String(deal._id), user: String(app.user) },
            idempotencyKey: `deal-${deal._id}-${app.user}`,
          });
          app.transferId = t.id;
          paidVia = "stripe";
        } catch (e) {
          return res.status(400).json({ success: false, message: `Stripe couldn't send the payment: ${e.message}` });
        }
      } else {
        paidVia = "manual";
      }
      app.paidVia = paidVia;
    }
    app.status = to;
    app.updatedAt = new Date();
    await deal.save();
    const msg = {
      accepted: ["You're in! 🤝", `${deal.brand} accepted you for "${deal.title}". Post your action, then link it in Brand deals.`],
      rejected: ["Brand deal update", `${deal.brand} went with other creators for "${deal.title}" this time.`],
      paid: ["You've been paid 💸", `${deal.brand} paid AED ${creatorPayout(deal.payoutAed, deal.platformFeePct)} for "${deal.title}"${paidVia === "stripe" ? ". It's on its way to your bank through Stripe." : "."}`],
    }[to];
    if (msg) await notify(app.user, msg[0], msg[1], deal._id);
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Unable to update the application");
  }
};
