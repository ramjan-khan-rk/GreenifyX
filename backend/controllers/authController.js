import crypto from "crypto";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User from "../models/User.js";
import OtpChallenge from "../models/OtpChallenge.js";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { allowDevOtpShortcut, deliverOtp } from "../utils/otpDelivery.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { normalizePhone, phoneCandidates } from "../utils/phone.js";

const OTP_TTL_MS = 10 * 60 * 1000;
const VERIFIED_TTL_MS = 15 * 60 * 1000;
const MIN_PASSWORD_LENGTH = 6;
const MAX_OTP_ATTEMPTS = 5;

const generateToken = (id) => {
  return jwt.sign({ id }, getJwtSecret(), {
    expiresIn: "7d",
  });
};

const normalizePurpose = (purpose) => {
  return purpose === "reset" ? "reset" : "register";
};

const sanitizeUser = (user) => {
  const obj = user.toObject ? user.toObject() : { ...user };
  delete obj.password;
  return obj;
};

const hashOtp = (phone, purpose, code) =>
  crypto
    .createHmac("sha256", getJwtSecret())
    .update(`${phone}:${purpose}:${code}`)
    .digest("hex");

const hashesMatch = (a, b) => {
  if (!a || !b) return false;
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
};

const findUserByPhone = async (phone, extra = "") => {
  const candidates = phoneCandidates(phone);
  if (!candidates.length) return null;
  return User.findOne({ phone: { $in: candidates } }).select(extra);
};

const getActiveOtp = async (phone, purpose) => {
  return OtpChallenge.findOne({
    phone,
    purpose,
  }).sort({ createdAt: -1 });
};

const isVerifiedForPurpose = async (phone, purpose) => {
  const entry = await getActiveOtp(phone, purpose);
  if (!entry || !entry.verifiedAt || entry.codeHash) {
    return false;
  }
  if (Date.now() - entry.verifiedAt.getTime() > VERIFIED_TTL_MS) {
    await OtpChallenge.deleteMany({ phone, purpose });
    return false;
  }
  return true;
};

const generateOtpCode = () =>
  crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");

export const sendOTP = async (req, res) => {
  try {
    const purpose = normalizePurpose(req.body.purpose);
    const phone = normalizePhone(req.body.phone);

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    if (
      hitRateLimit({
        key: `otp-phone:${phone}:${purpose}`,
        max: 5,
        windowMs: 15 * 60 * 1000,
      })
    ) {
      return res.status(429).json({
        success: false,
        message: "Too many OTP requests for this number. Try again later.",
      });
    }

    const existingUser = await findUserByPhone(phone, "+password");

    if (purpose === "register" && existingUser?.password) {
      return res.status(400).json({
        success: false,
        message: "Account already exists. Please log in with your password.",
      });
    }

    if (purpose === "reset" && !existingUser) {
      return res.status(404).json({
        success: false,
        message: "No account found for this phone number.",
      });
    }

    const otp = generateOtpCode();

    await OtpChallenge.deleteMany({ phone, purpose });
    await OtpChallenge.create({
      phone,
      purpose,
      codeHash: hashOtp(phone, purpose, otp),
      attempts: 0,
      verifiedAt: null,
    });

    const delivery = await deliverOtp({ phone, otp });
    const devShortcut = allowDevOtpShortcut();

    const payload = {
      success: true,
      purpose,
      delivery: delivery.delivered ? "sent" : "not_sent",
      message: delivery.delivered
        ? "OTP sent successfully"
        : devShortcut
          ? "OTP generated. SMS is not configured; use the development shortcut."
          : "OTP could not be delivered. Configure SMS_PROVIDER before production use.",
    };

    if (devShortcut) {
      payload.devOtp = otp;
    }

    return res.status(200).json(payload);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Unable to send OTP",
    });
  }
};

export const verifyOTP = async (req, res) => {
  try {
    const purpose = normalizePurpose(req.body.purpose);
    const phone = normalizePhone(req.body.phone);
    const otp = String(req.body.otp ?? "").trim();

    if (!phone || !otp) {
      return res.status(400).json({
        success: false,
        message: "Phone and OTP are required",
      });
    }

    const entry = await getActiveOtp(phone, purpose);

    if (!entry || !entry.codeHash) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    if (Date.now() - entry.createdAt.getTime() > OTP_TTL_MS) {
      await OtpChallenge.deleteMany({ phone, purpose });
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    if (entry.attempts >= MAX_OTP_ATTEMPTS) {
      await OtpChallenge.deleteMany({ phone, purpose });
      return res.status(429).json({
        success: false,
        message: "Too many incorrect attempts. Request a new OTP.",
      });
    }

    const expected = hashOtp(phone, purpose, otp);
    if (!hashesMatch(entry.codeHash, expected)) {
      entry.attempts += 1;
      await entry.save();
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    entry.verifiedAt = new Date();
    entry.codeHash = null;
    entry.attempts = 0;
    await entry.save();

    res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      verified: true,
      purpose,
      phone,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Unable to verify OTP",
    });
  }
};

export const setPassword = async (req, res) => {
  try {
    const purpose = normalizePurpose(req.body.purpose);
    const phone = normalizePhone(req.body.phone);
    const password = req.body.password;

    if (!phone || !password) {
      return res.status(400).json({
        success: false,
        message: "Phone and password are required",
      });
    }

    if (String(password).length < MIN_PASSWORD_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Password must be at least ${MIN_PASSWORD_LENGTH} characters`,
      });
    }

    if (!(await isVerifiedForPurpose(phone, purpose))) {
      return res.status(400).json({
        success: false,
        message: "Please verify OTP before setting a password",
      });
    }

    const hashed = await bcrypt.hash(password, 10);
    let user = await findUserByPhone(phone, "+password");
    let isNewUser = false;

    if (purpose === "register") {
      if (user?.password) {
        await OtpChallenge.deleteMany({ phone, purpose });
        return res.status(400).json({
          success: false,
          message: "Account already exists. Please log in.",
        });
      }

      if (!user) {
        isNewUser = true;
        user = await User.create({ phone, password: hashed });
      } else {
        user.password = hashed;
        await user.save();
        isNewUser = !user.isProfileCompleted;
      }
    } else {
      if (!user) {
        await OtpChallenge.deleteMany({ phone, purpose });
        return res.status(404).json({
          success: false,
          message: "No account found for this phone number.",
        });
      }

      user.password = hashed;
      await user.save();
      isNewUser = !user.isProfileCompleted;
    }

    await OtpChallenge.deleteMany({ phone, purpose });

    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      message:
        purpose === "reset"
          ? "Password reset successful"
          : "Registration successful",
      token,
      isNewUser,
      user: sanitizeUser(user),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Unable to set password",
    });
  }
};

export const login = async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const password = req.body.password;

    if (!phone || !password) {
      return res.status(400).json({
        success: false,
        message: "Phone and password are required",
      });
    }

    const user = await findUserByPhone(phone, "+password");

    if (!user || !user.password) {
      return res.status(401).json({
        success: false,
        message:
          "Invalid credentials. If you signed up earlier, use Forgot password to set one.",
      });
    }

    const match = await bcrypt.compare(password, user.password);

    if (!match) {
      return res.status(401).json({
        success: false,
        message: "Invalid phone or password",
      });
    }

    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      message: "Login successful",
      token,
      isNewUser: !user.isProfileCompleted,
      user: sanitizeUser(user),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Unable to log in",
    });
  }
};
