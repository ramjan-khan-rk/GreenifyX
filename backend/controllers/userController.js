import User from "../models/User.js";

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

    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      user,
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

    res.json({

      success: true,

      user: {

        ...user.toObject(),

        friendsCount: user.friends.length,

      },

    });

  } catch (e) {

    res.status(500).json({
      success:false,
      message:e.message,
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
        ecoScore: user.ecoScore,
        karamCount: user.karamCount,
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
      .select("name profileImage ecoScore level streak")
      .sort({ ecoScore: -1 })
      .limit(10);

    res.status(200).json({
      success: true,
      users,
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
    console.log("=================================");
    console.log("SEARCH ROUTE HIT");
    console.log("Keyword:", req.query.q);
    console.log("Logged In User:", req.user);
    console.log("=================================");

    const keyword = req.query.q || "";

    const currentUser = await User.findById(req.user._id);

    console.log("CURRENT USER:");
    console.log(currentUser);

    // SHOW EVERY USER IN DATABASE
    const allUsers = await User.find().select("name phone");

    console.log("========== ALL USERS ==========");
    console.log(allUsers);
    console.log("===============================");

    // SEARCH USERS
    const users = await User.find({
      _id: {
        $ne: req.user._id,
      },
      name: {
        $regex: keyword,
        $options: "i",
      },
    }).select(
      "name profileImage ecoScore level friends friendRequests sentRequests"
    );

    console.log("========== MATCHED USERS ==========");
    console.log(users);
    console.log("===================================");

    const result = users.map((user) => ({
      _id: user._id,
      name: user.name,
      profileImage: user.profileImage,
      ecoScore: user.ecoScore,
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

    console.log("========== FINAL RESPONSE ==========");
    console.log(result);
    console.log("====================================");

    res.status(200).json({
      success: true,
      users: result,
    });

  } catch (e) {

    console.log("========== SEARCH ERROR ==========");
    console.log(e);
    console.log("==================================");

    res.status(500).json({
      success: false,
      message: e.message,
    });

  }
};