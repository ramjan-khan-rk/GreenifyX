import User from "../models/User.js";
import { resolveEcoPoints } from "../utils/ecoPoints.js";
import { escapeRegex } from "../utils/escapeRegex.js";

// COMPLETE / UPDATE PROFILE
export const updateProfile = async (req, res) => {
  try {
    const { name, bio, profileImage } = req.body;

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
    res.status(500).json({
      success: false,
      message: error.message,
    });
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
    res.status(500).json({
      success: false,
      message: e.message,
    });
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
        ecoPoints: resolveEcoPoints(user),
        level: user.level,
        streak: user.streak,
      },
    });
  } catch (e) {
    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};

// LEADERBOARD
export const getLeaderboard = async (req, res) => {
  try {
    const users = await User.find()
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
    res.status(500).json({
      success: false,
      message: error.message,
    });
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

    const users = await User.find({
      _id: {
        $ne: req.user._id,
      },
      name: {
        $regex: escapeRegex(keyword),
        $options: "i",
      },
    }).select(
      "name profileImage ecoPoints level friends friendRequests sentRequests"
    );

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
    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};
