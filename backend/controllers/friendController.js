import User from "../models/User.js";
import Notification from "../models/Notification.js";
//
export const sendRequest = async (req, res) => {
  try {
    const { userId } = req.body;

    if (userId === req.user._id.toString()) {
      return res.status(400).json({
        success: false,
        message: "You cannot send request to yourself",
      });
    }

    const sender = await User.findById(req.user._id);
    const receiver = await User.findById(userId);

    if (!receiver) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (
      sender.friends.some(
        (id) => id.toString() === userId
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Already friends",
      });
    }

    if (
      sender.sentRequests.some(
        (id) => id.toString() === userId
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Request already sent",
      });
    }

    sender.sentRequests.push(receiver._id);

    receiver.friendRequests.push(sender._id);

    await sender.save();
    await receiver.save();
    await Notification.create({
    receiver: receiver._id,
    sender: req.user._id,

    type: "friend_request",

    title: "New Friend Request",

    message: `${req.user.name} sent you a friend request.`,

    referenceId: req.user._id,
});
    res.json({
      success: true,
      message: "Friend request sent",
    });

  } catch (e) {

    res.status(500).json({
      success: false,
      message: e.message,
    });

  }
};
export const acceptRequest = async (req, res) => {
  try {

    const { userId } = req.body;

    const currentUser =
      await User.findById(req.user._id);

    const sender =
      await User.findById(userId);

    if (!sender) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const pending = currentUser.friendRequests.some(
      (id) => id.toString() === userId
    );

    if (!pending) {
      return res.status(400).json({
        success: false,
        message: "No pending friend request from this user",
      });
    }

    const alreadyFriends = currentUser.friends.some(
      (id) => id.toString() === userId
    );

    if (alreadyFriends) {
      return res.status(400).json({
        success: false,
        message: "Already friends",
      });
    }

    currentUser.friendRequests =
      currentUser.friendRequests.filter(
        (id) => id.toString() !== userId
      );

    sender.sentRequests =
      sender.sentRequests.filter(
        (id) =>
          id.toString() !==
          req.user._id.toString()
      );

    currentUser.friends.push(sender._id);

    sender.friends.push(currentUser._id);

    await currentUser.save();

    await sender.save();
    await Notification.create({
  receiver: sender._id,
  sender: req.user._id,

  type: "friend_accept",

  title: "Friend Request Accepted",

  message: `${req.user.name} accepted your friend request.`,

  referenceId: currentUser._id,
});
    res.json({
      success: true,
    });

  } catch (e) {

    res.status(500).json({
      success: false,
      message: e.message,
    });

  }
};


// GET FRIENDS
export const getFriends = async (req, res) => {

  try {

    const user = await User.findById(req.user._id)
      .populate(
        "friends",
        "name bio profileImage ecoPoints level streak"
      );

    res.status(200).json({
      success: true,
      friends: user.friends.map((f) => {
        const obj = f.toObject ? f.toObject() : f;
        return {
          ...obj,
          ecoPoints: obj.ecoPoints ?? obj.ecoScore ?? obj.karamCount ?? 0,
        };
      }),
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      message: error.message,
    });

  }

};

// GET FRIEND REQUESTS
export const getRequests = async (req, res) => {

  try {

    const user = await User.findById(req.user._id)
      .populate(
        "friendRequests",
        "name bio profileImage ecoPoints level streak"
      );

    res.status(200).json({
      success: true,
      requests: user.friendRequests.map((f) => {
        const obj = f.toObject ? f.toObject() : f;
        return {
          ...obj,
          ecoPoints: obj.ecoPoints ?? obj.ecoScore ?? obj.karamCount ?? 0,
        };
      }),
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      message: error.message,
    });

  }

};