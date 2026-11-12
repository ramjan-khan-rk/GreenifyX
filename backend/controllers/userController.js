import bcrypt from "bcryptjs";
import User from "../models/User.js";
import { resolveEcoPoints } from "../utils/ecoPoints.js";
import { escapeRegex } from "../utils/escapeRegex.js";
import { parsePagination } from "../utils/pagination.js";
import { sendServerError } from "../utils/httpError.js";
import { normalizeEmirate } from "../utils/emirates.js";

// COMPLETE / UPDATE PROFILE
export const updateProfile = async (req, res) => {
  try {
    const { name, bio, profileImage, emirate } = req.body;

    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (name !== undefined) user.name = name;
    if (bio !== undefined) user.bio = bio;
    if (profileImage !== undefined) user.profileImage = profileImage;
    if (emirate !== undefined) {
      const value = normalizeEmirate(emirate);
      if (emirate && !value) {
        return res.status(400).json({ success: false, message: "Choose a valid emirate" });
      }
      user.emirate = value || undefined;
    }

    user.isProfileCompleted = true;

    await user.save();

    const obj = user.toObject();
    obj.ecoPoints = resolveEcoPoints(user);
    delete obj.password;
    delete obj.karamCount;
    delete obj.ecoScore;

    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      user: obj,
    });
  } catch (error) {
    return sendServerError(res, "Unable to update profile");
  }
};

// GET MY PROFILE
export const getMyProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Not authorized",
      });
    }

    const obj = user.toObject();
    obj.ecoPoints = resolveEcoPoints(user);
    obj.friendsCount = user.friends.length;
    delete obj.password;
    delete obj.karamCount;
    delete obj.ecoScore;

    res.json({
      success: true,
      user: obj,
    });
  } catch (e) {
    return sendServerError(res, "Unable to load profile");
  }
};

export const getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      success: true,
      user: {
        _id: user._id,
        name: user.name,
        bio: user.bio,
        profileImage: user.profileImage,
        emirate: user.emirate || "",
        ecoPoints: resolveEcoPoints(user),
        level: user.level,
        streak: user.streak,
        badges: user.badges || [],
      },
    });
  } catch (e) {
    return sendServerError(res, "Unable to load user");
  }
};

// LEADERBOARD
export const getLeaderboard = async (req, res) => {
  try {
    const users = await User.find({ isSuspended: { $ne: true } })
      .select("name profileImage ecoPoints level streak")
      .sort({ ecoPoints: -1 })
      .limit(10);

    res.status(200).json({
      success: true,
      users: users.map((u) => ({
        _id: u._id,
        name: u.name,
        profileImage: u.profileImage,
        ecoPoints: resolveEcoPoints(u),
        level: u.level,
        streak: u.streak,
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load leaderboard");
  }
};

// SEARCH USERS
export const searchUsers = async (req, res) => {
  try {
    const keyword = String(req.query.q || "").trim();

    if (!keyword) {
      return res.status(200).json({
        success: true,
        users: [],
      });
    }

    const currentUser = await User.findById(req.user._id);
    const { limit } = parsePagination(req.query, {
      defaultLimit: 20,
      maxLimit: 50,
    });

    const users = await User.find({
      _id: {
        $ne: req.user._id,
      },
      name: {
        $regex: escapeRegex(keyword),
        $options: "i",
      },
    })
      .select(
        "name profileImage ecoPoints level friends friendRequests sentRequests"
      )
      .limit(limit);

    const result = users.map((user) => ({
      _id: user._id,
      name: user.name,
      profileImage: user.profileImage,
      ecoPoints: resolveEcoPoints(user),
      level: user.level,

      isFriend: currentUser.friends.some(
        (id) => id.toString() === user._id.toString()
      ),

      requestSent: currentUser.sentRequests.some(
        (id) => id.toString() === user._id.toString()
      ),

      requestReceived: currentUser.friendRequests.some(
        (id) => id.toString() === user._id.toString()
      ),
    }));

    res.status(200).json({
      success: true,
      users: result,
    });
  } catch (e) {
    return sendServerError(res, "Unable to search users");
  }
};

// ---------------- Settings ----------------

const PREF_KEYS = ["messages", "calls", "social", "campaigns", "points"];

// GET /api/users/me/settings
export const getSettings = async (req, res) => {
  try {
    const u = await User.findById(req.user._id);
    const prefs = {};
    for (const k of PREF_KEYS) prefs[k] = u?.notificationPrefs?.[k] !== false;
    res.json({ success: true, settings: { notificationPrefs: prefs, language: u?.language || "en", email: u?.email || "", phone: u?.phone || "" } });
  } catch (e) {
    return sendServerError(res, "Unable to load settings");
  }
};

// PATCH /api/users/me/settings  { notificationPrefs?: {...}, language?: "en"|"ar" }
export const updateSettings = async (req, res) => {
  try {
    const u = await User.findById(req.user._id);
    if (!u) return res.status(404).json({ success: false, message: "User not found" });
    const incoming = req.body.notificationPrefs;
    if (incoming && typeof incoming === "object") {
      for (const k of PREF_KEYS) {
        if (typeof incoming[k] === "boolean") u.set(`notificationPrefs.${k}`, incoming[k]);
      }
    }
    if (["en", "ar"].includes(req.body.language)) u.language = req.body.language;
    await u.save();
    const prefs = {};
    for (const k of PREF_KEYS) prefs[k] = u.notificationPrefs?.[k] !== false;
    res.json({ success: true, settings: { notificationPrefs: prefs, language: u.language } });
  } catch (e) {
    return sendServerError(res, "Unable to save settings");
  }
};

// POST /api/users/me/password  { currentPassword, newPassword }
export const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const next = String(newPassword || "");
    if (next.length < 8 || !/[A-Za-z]/.test(next) || !/\d/.test(next)) {
      return res.status(400).json({ success: false, message: "Use at least 8 characters with letters and a number" });
    }
    const u = await User.findById(req.user._id).select("+password");
    if (!u) return res.status(404).json({ success: false, message: "User not found" });
    if (u.password) {
      const ok = await bcrypt.compare(String(currentPassword || ""), u.password);
      if (!ok) return res.status(400).json({ success: false, message: "Your current password is incorrect" });
    }
    u.password = await bcrypt.hash(next, 10);
    await u.save();
    res.json({ success: true, message: "Password updated" });
  } catch (e) {
    return sendServerError(res, "Unable to change password");
  }
};

// DELETE /api/users/me  { password }
// Removes personal data and detaches the account. Verified impact records stay anonymised.
export const deleteAccount = async (req, res) => {
  try {
    const u = await User.findById(req.user._id).select("+password");
    if (!u) return res.status(404).json({ success: false, message: "User not found" });
    if (u.role === "admin") return res.status(400).json({ success: false, message: "Admin accounts can't be deleted from the app" });
    if (u.password) {
      const ok = await bcrypt.compare(String(req.body.password || ""), u.password);
      if (!ok) return res.status(400).json({ success: false, message: "Password is incorrect" });
    }
    await User.updateMany(
      { _id: { $ne: u._id } },
      { $pull: { friends: u._id, friendRequests: u._id, sentRequests: u._id, blockedUsers: u._id } }
    );
    u.name = "Deleted user";
    u.bio = "";
    u.profileImage = "";
    u.email = undefined;
    u.phone = undefined;
    u.password = undefined;
    u.friends = [];
    u.friendRequests = [];
    u.sentRequests = [];
    u.pushTokens = [];
    u.isSuspended = true;
    u.suspendedReason = "Account deleted by user";
    u.deletedAt = new Date();
    await u.save();
    res.json({ success: true, message: "Your account was deleted" });
  } catch (e) {
    return sendServerError(res, "Unable to delete account");
  }
};

// POST /api/users/me/push-token  { token, platform }
export const registerPushToken = async (req, res) => {
  try {
    const token = String(req.body.token || "").trim();
    if (token.length < 20 || token.length > 4096) return res.status(400).json({ success: false, message: "Invalid token" });
    const platform = ["android", "ios", "web"].includes(req.body.platform) ? req.body.platform : "android";
    // A device belongs to one account at a time.
    await User.updateMany({ "pushTokens.token": token, _id: { $ne: req.user._id } }, { $pull: { pushTokens: { token } } });
    const u = await User.findById(req.user._id);
    u.pushTokens = [...(u.pushTokens || []).filter((t) => t.token !== token), { token, platform, updatedAt: new Date() }].slice(-5);
    await u.save();
    res.json({ success: true });
  } catch (e) {
    return sendServerError(res, "Unable to register device");
  }
};

// DELETE /api/users/me/push-token  { token }
export const removePushToken = async (req, res) => {
  try {
    await User.updateOne({ _id: req.user._id }, { $pull: { pushTokens: { token: String(req.body.token || "") } } });
    res.json({ success: true });
  } catch (e) {
    return sendServerError(res, "Unable to remove device");
  }
};
