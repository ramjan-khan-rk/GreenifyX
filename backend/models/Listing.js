import mongoose from "mongoose";

export const LISTING_CATEGORIES = ["Furniture", "Electronics", "Books & School", "Kids & Baby", "Clothes", "Home & Kitchen", "Sports & Bikes", "Plants & Garden", "Other"];
export const LISTING_TYPES = ["give", "swap", "sell"];
// Rough kg kept out of landfill per item, by category (for impact numbers).
export const KG_SAVED = { Furniture: 25, Electronics: 4, "Books & School": 1.5, "Kids & Baby": 3, Clothes: 1, "Home & Kitchen": 3, "Sports & Bikes": 8, "Plants & Garden": 2, Other: 2 };

const listingSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    title: { type: String, required: true, trim: true, maxlength: 80 },
    description: { type: String, default: "", trim: true, maxlength: 1000 },
    category: { type: String, enum: LISTING_CATEGORIES, default: "Other" },
    condition: { type: String, enum: ["new", "like-new", "good", "fair"], default: "good" },
    type: { type: String, enum: LISTING_TYPES, default: "give" },
    priceAed: { type: Number, default: 0, min: 0, max: 100000 },
    swapFor: { type: String, default: "", trim: true, maxlength: 120 },
    images: [{ type: String }],
    emirate: { type: String, default: "", trim: true },
    area: { type: String, default: "", trim: true, maxlength: 80 },
    status: { type: String, enum: ["active", "reserved", "done", "removed"], default: "active", index: true },
    interested: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    receiver: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    completedAt: { type: Date },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

listingSchema.index({ status: 1, emirate: 1, category: 1, createdAt: -1 });

export default mongoose.model("Listing", listingSchema);
