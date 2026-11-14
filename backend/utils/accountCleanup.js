import cloudinary from "../config/cloudinary.js";
import UtilityBill from "../models/UtilityBill.js";
import HealthDay from "../models/HealthDay.js";
import Household from "../models/Household.js";
import LessonProgress from "../models/LessonProgress.js";
import BrandDeal from "../models/BrandDeal.js";
import ForestTree from "../models/ForestTree.js";
import BillScan from "../models/BillScan.js";
import User from "../models/User.js";
import { Dropoff } from "../models/RecyclingStation.js";

/**
 * Cloudinary public id from a delivery URL, e.g.
 * https://res.cloudinary.com/x/image/upload/v1712/GreenifyX/bills/abc.jpg -> GreenifyX/bills/abc
 */
export const cloudinaryPublicId = (url) => {
  const m = /\/upload\/(?:[^/]+\/)*?(?:v\d+\/)?(GreenifyX\/[^?#]+?)(?:\.[a-z0-9]+)?(?:[?#].*)?$/i.exec(String(url || ""));
  return m ? m[1] : null;
};

/** Take a member out of their household; the next member becomes owner, the last one out closes it. */
export const removeFromHousehold = async (userId) => {
  const h = await Household.findOne({ members: userId });
  if (!h) return;
  h.members = h.members.filter((m) => String(m) !== String(userId));
  if (!h.members.length) {
    await h.deleteOne();
    return;
  }
  if (String(h.owner) === String(userId)) h.owner = h.members[0];
  await h.save();
};

/**
 * Personal data from the newer features, removed when a member deletes their account.
 * Keeps only what others rely on, without personal details:
 * funded trees (real trees, now anonymous) and brand deal records already accepted or paid
 * (the brand's payment record), with the pitch text cleared.
 */
export const removeFeatureData = async (userId) => {
  const bills = await UtilityBill.find({ user: userId }).select("photoUrl").lean();
  for (const b of bills) {
    const id = cloudinaryPublicId(b.photoUrl);
    if (id) await cloudinary.uploader.destroy(id).catch(() => {});
  }
  await Promise.all([
    UtilityBill.deleteMany({ user: userId }),
    HealthDay.deleteMany({ user: userId }),
    LessonProgress.deleteMany({ user: userId }),
    removeFromHousehold(userId),
    // Open or declined applications go; accepted, delivered or paid ones stay as the brand's record.
    BrandDeal.updateMany({ "applications.user": userId }, { $pull: { applications: { user: userId, status: { $in: ["applied", "rejected"] } } } }),
    ForestTree.updateMany({ user: userId }, { $set: { nickname: "" } }),
  ]);
  await BrandDeal.updateMany(
    { "applications.user": userId },
    { $set: { "applications.$[a].pitch": "" } },
    { arrayFilters: [{ "a.user": userId }] }
  );
  // Added with UAE PASS, missions, recycling stations and the passport.
  await Promise.all([
    BillScan.deleteMany({ user: userId }),
    Dropoff.deleteMany({ user: userId }),
    User.updateOne(
      { _id: userId },
      { $unset: { homeZone: 1, homeLocation: 1, passportCode: 1, uaePass: 1, partnerOrg: 1 }, $set: { passportPublic: false, isVerifiedResident: false } }
    ),
  ]);
  return { bills: bills.length };
};
