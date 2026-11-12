import mongoose from "mongoose";
import { ORG_TYPES } from "./Organization.js";

/** Lead from the public "GreenifyX for organisations" website. */
const orgEnquirySchema = new mongoose.Schema(
  {
    organisation: { type: String, required: true, trim: true, maxlength: 120 },
    type: { type: String, enum: ORG_TYPES, default: "Company" },
    emirate: { type: String, default: "", trim: true },
    size: { type: String, default: "", trim: true, maxlength: 40 },
    contactName: { type: String, required: true, trim: true, maxlength: 80 },
    email: { type: String, required: true, trim: true, lowercase: true, maxlength: 120 },
    phone: { type: String, default: "", trim: true, maxlength: 30 },
    website: { type: String, default: "", trim: true, maxlength: 200 },
    interests: [{ type: String, trim: true, maxlength: 40 }],
    message: { type: String, default: "", trim: true, maxlength: 1500 },
    status: { type: String, enum: ["new", "contacted", "converted", "closed"], default: "new", index: true },
    adminNote: { type: String, default: "", trim: true, maxlength: 500 },
  },
  { timestamps: true }
);

export default mongoose.model("OrgEnquiry", orgEnquirySchema);
