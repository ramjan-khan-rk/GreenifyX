import { bundle, groupLabel } from "../utils/inbox.js";
import Notification from "../models/Notification.js";
import { parsePagination } from "../utils/pagination.js";
import { sendServerError } from "../utils/httpError.js";


// Get all notifications for logged-in user
export const getNotifications = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, {
      defaultLimit: 30,
      maxLimit: 50,
    });

    const filter = { receiver: req.user._id };
    const [notifications, total] = await Promise.all([
      Notification.find(filter)
        .populate("sender", "name profileImage")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Notification.countDocuments(filter),
    ]);

    res.status(200).json({
      success: true,
      notifications,
      page,
      limit,
      total,
      hasMore: skip + notifications.length < total,
    });
  } catch (error) {
    return sendServerError(res, "Request failed");
  }
};


// Mark one notification as read
export const markAsRead = async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found",
      });
    }

    if (
      notification.receiver.toString() !==
      req.user._id.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "Unauthorized",
      });
    }

    notification.isRead = true;

    await notification.save();

    res.status(200).json({
      success: true,
      message: "Notification marked as read",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Request failed",
    });
  }
};


// Mark all notifications as read
export const markAllAsRead = async (req, res) => {
  try {
    await Notification.updateMany(
      {
        receiver: req.user._id,
        isRead: false,
      },
      {
        isRead: true,
      }
    );

    res.status(200).json({
      success: true,
      message: "All notifications marked as read",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Request failed",
    });
  }
};


// Delete notification
export const deleteNotification = async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found",
      });
    }

    if (
      notification.receiver.toString() !==
      req.user._id.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "Unauthorized",
      });
    }

    await notification.deleteOne();

    res.status(200).json({
      success: true,
      message: "Notification deleted",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Request failed",
    });
  }
};

// GET /api/notifications/inbox?category=all|mentions|social|rewards|activity
export const getInbox = async (req, res) => {
  try {
    const items = await Notification.find({ receiver: req.user._id, createdAt: { $gte: new Date(Date.now() - 60 * 864e5) } })
      .populate("sender", "name profileImage verifiedBadge")
      .sort({ createdAt: -1 })
      .limit(300)
      .lean();
    let list = bundle(items);
    const cat = String(req.query.category || "all");
    if (cat !== "all") list = list.filter((i) => i.category === cat);
    const groups = [];
    for (const i of list) {
      const label = groupLabel(i.createdAt);
      let g = groups.find((x) => x.label === label);
      if (!g) groups.push((g = { label, items: [] }));
      g.items.push(i);
    }
    const counts = {};
    for (const i of bundle(items)) if (!i.isRead) counts[i.category] = (counts[i.category] || 0) + 1;
    res.json({ success: true, groups, unreadByCategory: counts, unread: items.filter((n) => !n.isRead).length });
  } catch (error) {
    return sendServerError(res, "Unable to load notifications");
  }
};

// POST /api/notifications/bulk { ids: [...], action: "read" | "delete" }
export const bulkNotifications = async (req, res) => {
  try {
    const ids = (Array.isArray(req.body?.ids) ? req.body.ids : []).filter((id) => /^[a-f\d]{24}$/i.test(String(id))).slice(0, 500);
    const q = { _id: { $in: ids }, receiver: req.user._id };
    if (req.body?.action === "delete") await Notification.deleteMany(q);
    else await Notification.updateMany(q, { isRead: true });
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Request failed");
  }
};
