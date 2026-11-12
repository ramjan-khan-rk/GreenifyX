/** Notification inbox: categories, bundling and day groups. Pure; tested. */
export const CATEGORY = {
  tag: "mentions",
  like: "social",
  comment: "social",
  friend_request: "social",
  friend_accept: "social",
  message: "social",
  call: "social",
  live: "social",
  listing: "social",
  points: "rewards",
  reward: "rewards",
  verification: "rewards",
  pickup: "rewards",
  sponsored: "rewards",
  badge: "rewards",
};
export const categoryOf = (type) => CATEGORY[type] || (String(type).startsWith("challenge") ? "activity" : "activity");

const BUNDLE_TYPES = new Set(["like", "comment"]);
const dayKey = (d) => new Date(d).toISOString().slice(0, 10);

/**
 * Bundle likes/comments on the same post on the same day:
 * "Sara and 4 others liked your post".
 */
export const bundle = (notifications) => {
  const out = [];
  const index = new Map();
  for (const n of notifications) {
    const sender = n.sender && typeof n.sender === "object" ? n.sender : null;
    const key = BUNDLE_TYPES.has(n.type) && n.referenceId ? `${n.type}:${n.referenceId}:${dayKey(n.createdAt)}` : null;
    if (key && index.has(key)) {
      const b = index.get(key);
      b.ids.push(String(n._id));
      b.count += 1;
      if (sender && !b.senders.some((s) => String(s._id) === String(sender._id))) b.senders.push(sender);
      b.isRead = b.isRead && n.isRead;
      continue;
    }
    const item = {
      key: key || String(n._id),
      ids: [String(n._id)],
      type: n.type,
      category: categoryOf(n.type),
      title: n.title,
      message: n.message,
      referenceId: n.referenceId,
      senders: sender ? [sender] : [],
      count: 1,
      isRead: n.isRead,
      createdAt: n.createdAt,
    };
    out.push(item);
    if (key) index.set(key, item);
  }
  for (const b of out) {
    if (b.count > 1 && b.senders.length) {
      const first = String(b.senders[0].name || "Someone").split(" ")[0];
      const others = b.senders.length - 1;
      const verb = b.type === "like" ? "liked your post" : "commented on your post";
      b.message = others > 0 ? `${first} and ${others} other${others > 1 ? "s" : ""} ${verb}.` : `${first} ${verb} ${b.count} times.`;
      b.title = b.type === "like" ? "New likes" : "New comments";
    }
  }
  return out;
};

export const groupLabel = (date, now = new Date()) => {
  const d = new Date(date);
  const days = Math.floor((new Date(now.toDateString()) - new Date(d.toDateString())) / 864e5);
  if (days <= 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7) return "This week";
  return "Earlier";
};
