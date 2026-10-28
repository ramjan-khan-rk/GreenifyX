import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User from "../models/User.js";
import OtpChallenge from "../models/OtpChallenge.js";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { allowDevOtpShortcut, deliverOtp } from "../utils/otpDelivery.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { normalizePhone, phoneCandidates } from "../utils/phone.js";
import { looksLikeEmail, normalizeEmail } from "../utils/email.js";
import { generateOtpCode, hashOtp, hashesMatch } from "../utils/otpCrypto.js";

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
  if (purpose === "reset") return "reset";
  if (purpose === "verify") return "verify";
  return "register";
};

const sanitizeUser = (user) => {
  const obj = user.toObject ? user.toObject() : { ...user };
  delete obj.password;
  return obj;
};

const findUserByPhone = async (phone, extra = "") => {
  const candidates = phoneCandidates(phone);
  if (!candidates.length) return null;
  return User.findOne({ phone: { $in: candidates } }).select(extra);
};

const findUserByEmail = async (email, extra = "") => {
  if (!email) return null;
  return User.findOne({ email }).select(extra);
};

const findUserForLogin = async (reqBody) => {
  const email = normalizeEmail(reqBody.email);
  if (email) {
    return findUserByEmail(email, "+password");
  }

  const raw = String(reqBody.email || reqBody.phone || "").trim();
  if (looksLikeEmail(raw)) {
    return findUserByEmail(normalizeEmail(raw), "+password");
  }

  if (raw || reqBody.phone) {
    return findUserByPhone(reqBody.phone || raw, "+password");
  }

  return null;
};

const getActiveOtp = async (email, purpose) => {
  return OtpChallenge.findOne({
    email,
    purpose,
  }).sort({ createdAt: -1 });
};

const isVerifiedForPurpose = async (email, purpose) => {
  const entry = await getActiveOtp(email, purpose);
  if (!entry || !entry.verifiedAt || entry.codeHash) {
    return false;
  }
  if (Date.now() - entry.verifiedAt.getTime() > VERIFIED_TTL_MS) {
    await OtpChallenge.deleteMany({ email, purpose });
    return false;
  }
  return true;
};

const requireEmail = (req) => normalizeEmail(req.body.email);

export const sendOTP = async (req, res) => {
  try {
    const purpose = normalizePurpose(req.body.purpose);
    const email = requireEmail(req);

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    if (
      hitRateLimit({
        key: `otp-email:${email}:${purpose}`,
        max: 5,
        windowMs: 15 * 60 * 1000,
      })
    ) {
      return res.status(429).json({
        success: false,
        message: "Too many OTP requests for this email. Try again later.",
      });
    }

    const existingUser = await findUserByEmail(email, "+password");

    if (purpose === "register" && existingUser?.password) {
      return res.status(400).json({
        success: false,
        message: "Account already exists. Please log in with your password.",
      });
    }

    if (purpose === "reset" && !existingUser) {
      return res.status(404).json({
        success: false,
        message: "No account found for this email.",
      });
    }

    if (purpose === "verify" && !existingUser) {
      return res.status(404).json({
        success: false,
        message: "No account found for this email.",
      });
    }

    const otp = generateOtpCode();

    await OtpChallenge.deleteMany({ email, purpose });
    await OtpChallenge.create({
      email,
      purpose,
      codeHash: hashOtp(email, purpose, otp),
      attempts: 0,
      verifiedAt: null,
    });

    const delivery = await deliverOtp({ email, otp });
    const devShortcut = allowDevOtpShortcut();

    if (!delivery.delivered && !devShortcut) {
      return res.status(503).json({
        success: false,
        message: "Unable to send verification email. Try again later.",
      });
    }

    const payload = {
      success: true,
      purpose,
      delivery: delivery.delivered ? "sent" : "not_sent",
      message: delivery.delivered
        ? "OTP sent successfully"
        : "OTP generated. Email delivery is not configured; use the development shortcut.",
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
    const email = requireEmail(req);
    const otp = String(req.body.otp ?? "").trim();

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Email and OTP are required",
      });
    }

    const entry = await getActiveOtp(email, purpose);

    if (!entry || !entry.codeHash) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    if (Date.now() - entry.createdAt.getTime() > OTP_TTL_MS) {
      await OtpChallenge.deleteMany({ email, purpose });
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    if (entry.attempts >= MAX_OTP_ATTEMPTS) {
      await OtpChallenge.deleteMany({ email, purpose });
      return res.status(429).json({
        success: false,
        message: "Too many incorrect attempts. Request a new OTP.",
      });
    }

    const expected = hashOtp(email, purpose, otp);
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

    if (purpose === "verify") {
      const user = await findUserByEmail(email);
      if (user && !user.emailVerified) {
        user.emailVerified = true;
        await user.save();
      }
    }

    res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      verified: true,
      purpose,
      email,
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
    const email = requireEmail(req);
    const password = req.body.password;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    if (String(password).length < MIN_PASSWORD_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Password must be at least ${MIN_PASSWORD_LENGTH} characters`,
      });
    }

    if (!(await isVerifiedForPurpose(email, purpose))) {
      return res.status(400).json({
        success: false,
        message: "Please verify OTP before setting a password",
      });
    }

    const hashed = await bcrypt.hash(password, 10);
    let user = await findUserByEmail(email, "+password");
    let isNewUser = false;

    if (purpose === "register") {
      if (user?.password) {
        await OtpChallenge.deleteMany({ email, purpose });
        return res.status(400).json({
          success: false,
          message: "Account already exists. Please log in.",
        });
      }

      if (!user) {
        isNewUser = true;
        user = await User.create({
          email,
          password: hashed,
          emailVerified: true,
        });
      } else {
        user.password = hashed;
        user.emailVerified = true;
        await user.save();
        isNewUser = !user.isProfileCompleted;
      }
    } else if (purpose === "reset") {
      if (!user) {
        await OtpChallenge.deleteMany({ email, purpose });
        return res.status(404).json({
          success: false,
          message: "No account found for this email.",
        });
      }

      user.password = hashed;
      user.emailVerified = true;
      await user.save();
      isNewUser = !user.isProfileCompleted;
    } else {
      return res.status(400).json({
        success: false,
        message: "Invalid purpose",
      });
    }

    await OtpChallenge.deleteMany({ email, purpose });

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
    const password = req.body.password;

    if (!password || (!req.body.email && !req.body.phone)) {
      return res.status(400).json({
        success: false,
        message: "Email or phone and password are required",
      });
    }

    const user = await findUserForLogin(req.body);

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
        message: "Invalid email, phone, or password",
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
