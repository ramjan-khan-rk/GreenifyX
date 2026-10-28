import Challenge from "../models/Challenge.js";
import User from "../models/User.js";
import { emitToUser } from "../socket/socket.js";
import Notification from "../models/Notification.js";
// ======================================================
// CREATE CHALLENGE
// ======================================================

export const createChallenge = async (req, res) => {
  try {
    const {
      friendId,
      title,
      description,
      activity,
      target,
      category,
      difficulty,
      deadline,
    } = req.body;

    if (!friendId) {
      return res.status(400).json({
        success: false,
        message: "Friend is required.",
      });
    }

    if (friendId === req.user._id.toString()) {
      return res.status(400).json({
        success: false,
        message: "You cannot challenge yourself.",
      });
    }

    const creator = await User.findById(req.user._id);

    const friend = await User.findById(friendId);

    if (!friend) {
      return res.status(404).json({
        success: false,
        message: "Friend not found.",
      });
    }

    const isFriend = creator.friends.some(
      (id) => id.toString() === friendId
    );

    if (!isFriend) {
      return res.status(400).json({
        success: false,
        message: "You can only challenge your friends.",
      });
    }

    const existing = await Challenge.findOne({
      creator: req.user._id,
      friend: friendId,
      status: {
        $in: ["pending", "ongoing"],
      },
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        message: "Challenge already exists.",
      });
    }

    let ecoReward = 20;

    switch (difficulty) {
      case "Medium":
        ecoReward = 50;
        break;

      case "Hard":
        ecoReward = 100;
        break;

      default:
        ecoReward = 20;
    }

    const challenge = await Challenge.create({
      creator: req.user._id,
      friend: friendId,
      title,
      description,
      activity,
      target,
      category,
      difficulty,
      ecoReward,
      deadline,
      status: "pending",
    });

    const populatedChallenge = await Challenge.findById(challenge._id)
      .populate("creator", "name profileImage ecoPoints")
      .populate("friend", "name profileImage ecoPoints");
      
      

      await Notification.create({
  receiver: friend._id,
  sender: creator._id,

  type: "challenge",

  title: "New Challenge",

  message: `${creator.name} challenged you: "${title}".`,

  referenceId: challenge._id,
});



    emitToUser(friendId, "challengeReceived", populatedChallenge);

    return res.status(201).json({
      success: true,
      message: "Challenge sent successfully.",
      challenge: populatedChallenge,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ======================================================
// ACCEPT CHALLENGE
// ======================================================

export const acceptChallenge = async (req, res) => {
  try {
    const { challengeId } = req.params;

    const challenge = await Challenge.findById(challengeId);

    if (!challenge) {
      return res.status(404).json({
        success: false,
        message: "Challenge not found.",
      });
    }

    if (
      challenge.friend.toString() !==
      req.user._id.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "Unauthorized.",
      });
    }

    if (challenge.status !== "pending") {
      return res.status(400).json({
        success: false,
        message: "Challenge already processed.",
      });
    }

    challenge.status = "ongoing";

    await challenge.save();

    const populated = await Challenge.findById(challenge._id)
      .populate("creator", "name profileImage ecoPoints")
      .populate("friend", "name profileImage ecoPoints");
      
      

      const accepter = await User.findById(req.user._id);

await Notification.create({
  receiver: challenge.creator,
  sender: req.user._id,

  type: "challenge_accept",

  title: "Challenge Accepted",

  message: `${accepter.name} accepted your challenge.`,

  referenceId: challenge._id,
});






    emitToUser(challenge.creator, "challengeAccepted", populated);

    return res.status(200).json({
      success: true,
      message: "Challenge accepted.",
      challenge: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ======================================================
// REJECT CHALLENGE
// ======================================================

export const rejectChallenge = async (req, res) => {
  try {
    const { challengeId } = req.params;

    const challenge = await Challenge.findById(challengeId);

    if (!challenge) {
      return res.status(404).json({
        success: false,
        message: "Challenge not found.",
      });
    }

    if (
      challenge.friend.toString() !==
      req.user._id.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "Unauthorized.",
      });
    }

    challenge.status = "rejected";

    await challenge.save();
   const rejector = await User.findById(req.user._id);

await Notification.create({
  receiver: challenge.creator,
  sender: req.user._id,

  type: "challenge_reject",

  title: "Challenge Rejected",

  message: `${rejector.name} rejected your challenge.`,

  referenceId: challenge._id,
});


    emitToUser(challenge.creator, "challengeRejected", challenge);

    return res.status(200).json({
      success: true,
      message: "Challenge rejected.",
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
// ======================================================
// GET MY CHALLENGES
// ======================================================

export const getChallenges = async (req, res) => {
  try {
    const challenges = await Challenge.find({
      $or: [
        { creator: req.user._id },
        { friend: req.user._id },
      ],
    })
      .populate("creator", "name profileImage ecoPoints")
      .populate("friend", "name profileImage ecoPoints")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      challenges,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ======================================================
// UPDATE PROGRESS
// ======================================================

export const updateProgress = async (req, res) => {try {
  const { challengeId } = req.params;

  const challenge = await Challenge.findById(challengeId);

  if (!challenge) {
    return res.status(404).json({
      success: false,
      message: "Challenge not found.",
    });
  }

  // Only creator or invited friend
  const isCreator =
    challenge.creator.toString() === req.user._id.toString();

  const isFriend =
    challenge.friend.toString() === req.user._id.toString();

  if (!isCreator && !isFriend) {
    return res.status(403).json({
      success: false,
      message: "Unauthorized.",
    });
  }

  if (challenge.status !== "ongoing") {
    return res.status(400).json({
      success: false,
      message: "Challenge is not active.",
    });
  }

  // Expired
  if (
    challenge.deadline &&
    new Date() > new Date(challenge.deadline)
  ) {
    challenge.status = "expired";

    await challenge.save();

    return res.status(400).json({
      success: false,
      message: "Challenge expired.",
    });
  }

  // Increase progress
  if (isCreator) {
    challenge.creatorProgress++;
  } else {
    challenge.friendProgress++;
  }

  // Winner
  if (
    challenge.creatorProgress >= challenge.target ||
    challenge.friendProgress >= challenge.target
  ) {
    challenge.status = "completed";

    if (
      challenge.creatorProgress >
      challenge.friendProgress
    ) {
      challenge.winner = challenge.creator;
    } else if (
      challenge.friendProgress >
      challenge.creatorProgress
    ) {
      challenge.winner = challenge.friend;
    } else {
      challenge.winner = null;
    }

    // Rewards
    if (challenge.winner) {
      await User.findByIdAndUpdate(
        challenge.winner,
        {
          $inc: {
            ecoPoints: challenge.ecoReward,
          },
        }
      );
    }

    // Create notifications
    await Notification.create({
      receiver: challenge.creator,
      sender: req.user._id,
      type: "challenge_complete",
      title: "Challenge Completed",
      message: `${req.user.name} completed "${challenge.title}".`,
      referenceId: challenge._id,
    });

    await Notification.create({
      receiver: challenge.friend,
      sender: req.user._id,
      type: "challenge_complete",
      title: "Challenge Completed",
      message: `${req.user.name} completed "${challenge.title}".`,
      referenceId: challenge._id,
    });

    emitToUser(challenge.creator, "challengeCompleted", challenge);
    emitToUser(challenge.friend, "challengeCompleted", challenge);
  }

  await challenge.save();

  const populatedChallenge = await Challenge.findById(
    challenge._id
  )
    .populate("creator", "name profileImage ecoPoints")
    .populate("friend", "name profileImage ecoPoints");

  return res.status(200).json({
    success: true,
    challenge: populatedChallenge,
    progressEvidence: "self_reported",
  });
} catch (error) {
  return res.status(500).json({
    success: false,
    message: error.message,
  });
}};