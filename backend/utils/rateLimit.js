const buckets = new Map();

export const recordHit = ({ key, windowMs }) => {
  const now = Date.now();
  let bucket = buckets.get(key);

  if (!bucket || now - bucket.start > windowMs) {
    bucket = { start: now, count: 0 };
    buckets.set(key, bucket);
  }

  bucket.count += 1;
  return bucket.count;
};

export const isRateLimited = ({ key, max, windowMs }) => {
  const now = Date.now();
  const bucket = buckets.get(key);
  if (!bucket || now - bucket.start > windowMs) return false;
  return bucket.count >= max;
};

export const clearRateLimit = (key) => {
  buckets.delete(key);
};

export const hitRateLimit = ({ key, max, windowMs }) => {
  recordHit({ key, windowMs });
  return buckets.get(key).count > max;
};

export const limitAuthRequests = (req, res, next) => {
  const ip = req.ip || req.socket?.remoteAddress || "unknown";

  if (
    hitRateLimit({
      key: `auth-ip:${ip}`,
      max: 40,
      windowMs: 15 * 60 * 1000,
    })
  ) {
    return res.status(429).json({
      success: false,
      message: "Too many requests. Try again later.",
    });
  }

  next();
};
