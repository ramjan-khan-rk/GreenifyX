import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    phone: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
      required: false,
    },
    // Existing deployments may still have a non-sparse unique phone index.
    // Recreate it as sparse before adding a second email-only user.

    email: {
      type: String,
      unique: true,
      sparse: true,
      lowercase: true,
      trim: true,
    },

    emailVerified: {
      type: Boolean,
      default: false,
    },

    password: {
      type: String,
      select: false,
      minlength: 6,
    },

    name: {
      type: String,
      default: "",
      trim: true,
    },

    profileImage: {
      type: String,
      default: "",
    },

    bio: {
      type: String,
      default: "",
      maxlength: 150,
    },

    // Single points currency used app-wide (Eco Points)
    ecoPoints: {
      type: Number,
      default: 0,
      min: 0,
    },

    // Points spent on rewards. Spending never lowers ecoPoints (lifetime, drives level);
    // the spendable balance is ecoPoints - pointsSpent.
    pointsSpent: {
      type: Number,
      default: 0,
      min: 0,
    },

    // Legacy fields — read for migration only; prefer ecoPoints
    ecoScore: {
      type: Number,
    },

    karamCount: {
      type: Number,
    },

    level: {
      type: Number,
      default: 1,
    },

    streak: {
      type: Number,
      default: 0,
    },

    lastVerifiedAt: {
      type: Date,
    },

    badges: [
      {
        type: String,
      },
    ],

    friends: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    friendRequests: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    sentRequests: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    blockedUsers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    isProfileCompleted: {
      type: Boolean,
      default: false,
    },

    emirate: {
      type: String,
      enum: [
        "Abu Dhabi",
        "Dubai",
        "Sharjah",
        "Ajman",
        "Umm Al Quwain",
        "Ras Al Khaimah",
        "Fujairah",
      ],
    },

    role: {
      type: String,
      // verifier = authorised field verifier for campaigns
      enum: ["user", "verifier", "admin", "partner", "auditor"],
      default: "user",
    },

    isSuspended: {
      type: Boolean,
      default: false,
    },

    suspendedReason: {
      type: String,
      default: "",
      maxlength: 200,
    },

    notificationPrefs: {
      messages: { type: Boolean, default: true },
      calls: { type: Boolean, default: true },
      social: { type: Boolean, default: true },
      campaigns: { type: Boolean, default: true },
      points: { type: Boolean, default: true },
    },

    // Push notification device tokens (Firebase Cloud Messaging).
    // Weekly goal accepted from the AI companion.
    weeklyGoal: {
      points: { type: Number, default: 0 },
      actions: { type: Number, default: 0 },
      setAt: { type: Date },
    },

    // Carbon footprint questionnaire and result (kg CO2e / year).
    carbon: {
      answers: { type: mongoose.Schema.Types.Mixed, default: undefined },
      baselineKg: { type: Number },
      targetKg: { type: Number },
      updatedAt: { type: Date },
    },

    onboardedAt: { type: Date },

    // Referrals
    referralCode: { type: String, unique: true, sparse: true, uppercase: true, trim: true },

    // UAE PASS link. The Emirates ID number is never stored, only the account type.
    uaePass: {
      uuid: { type: String, index: { unique: true, sparse: true } },
      userType: { type: String, default: "" }, // SOP1 visitor, SOP2/SOP3 verified resident
      linkedAt: Date,
    },
    isVerifiedResident: { type: Boolean, default: false, index: true },

    // Neighbourhood for leagues and missions; home point rounded to ~1 km.
    homeZone: { type: mongoose.Schema.Types.ObjectId, ref: "Zone", index: true },
    homeLocation: { lat: Number, lng: Number },

    // Brand deal payouts through Stripe Connect (bank details stay with Stripe).
    stripeAccountId: { type: String, default: "" },

    // Impact passport: code for the QR and whether the owner shares it.
    passportCode: { type: String, unique: true, sparse: true },
    passportPublic: { type: Boolean, default: false },

    // Partner portal login: the one organisation this account can see.
    partnerOrg: { type: mongoose.Schema.Types.ObjectId, ref: "Organization" },
    referredBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    referralRewardedAt: { type: Date },

    // Streak protection
    streakFreezes: { type: Number, default: 1, min: 0, max: 3 },
    streakReminderAt: { type: Date },

    // Verified badge (blue tick)
    verifiedBadge: { type: String, enum: ["", "creator", "organisation", "verifier", "official"], default: "" },
    badgeRequest: {
      type: { type: String, enum: ["creator", "organisation", "verifier", "official"] },
      note: { type: String, maxlength: 500 },
      links: { type: String, maxlength: 300 },
      status: { type: String, enum: ["pending", "approved", "rejected"] },
      requestedAt: Date,
      decidedAt: Date,
    },

    // Topics picked by the member (boost the For you feed).
    interests: [{ type: String, trim: true, maxlength: 40 }],

    pushTokens: [
      {
        token: { type: String },
        platform: { type: String, default: "android" },
        updatedAt: { type: Date, default: Date.now },
        _id: false,
      },
    ],

    language: {
      type: String,
      enum: ["en", "ar"],
      default: "en",
    },

    lastSeenAt: {
      type: Date,
    },

    deletedAt: {
      type: Date,
    },

    // Marks records created by scripts/seedDemo.js so they can be cleared.
    isDemo: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("User", userSchema);