import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User from "../models/User.js";

// Temporary OTP storage (Development only)
// phone -> { code, purpose, verifiedAt }
const otpStore = {};

const OTP_TTL_MS = 10 * 60 * 1000;
const VERIFIED_TTL_MS = 15 * 60 * 1000;
const MIN_PASSWORD_LENGTH = 6;

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
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

const getOtpEntry = (phone) => otpStore[phone];

const clearOtp = (phone) => {
  delete otpStore[phone];
};

const isVerifiedForPurpose = (phone, purpose) => {
  const entry = getOtpEntry(phone);
  if (!entry || entry.purpose !== purpose || !entry.verifiedAt) {
    return false;
  }
  if (Date.now() - entry.verifiedAt > VERIFIED_TTL_MS) {
    clearOtp(phone);
    return false;
  }
  return true;
};

// SEND OTP (registration or password reset)
export const sendOTP = async (req, res) => {
  try {
    const { phone } = req.body;
    const purpose = normalizePurpose(req.body.purpose);

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    const existingUser = await User.findOne({ phone }).select("+password");

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

    const otp = Math.floor(1000 + Math.random() * 9000).toString();

    otpStore[phone] = {
      code: otp,
      purpose,
      createdAt: Date.now(),
      verifiedAt: null,
    };

    console.log(`📱 OTP (${purpose}) for ${phone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
      purpose,
      otp, // Remove this in production
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// VERIFY OTP — does not log the user in; unlocks set-password
export const verifyOTP = async (req, res) => {
  try {
    const { phone, otp } = req.body;
    const purpose = normalizePurpose(req.body.purpose);

    if (!phone || !otp) {
      return res.status(400).json({
        success: false,
        message: "Phone and OTP are required",
      });
    }

    const entry = getOtpEntry(phone);

    if (
      !entry ||
      entry.purpose !== purpose ||
      entry.code !== otp ||
      Date.now() - entry.createdAt > OTP_TTL_MS
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    entry.verifiedAt = Date.now();
    entry.code = null;

    res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      verified: true,
      purpose,
      phone,
    });
  } catch (error) {
    console.log("VERIFY OTP ERROR:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// SET / RESET PASSWORD after OTP verification
export const setPassword = async (req, res) => {
  try {
    const { phone, password } = req.body;
    const purpose = normalizePurpose(req.body.purpose);

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

    if (!isVerifiedForPurpose(phone, purpose)) {
      return res.status(400).json({
        success: false,
        message: "Please verify OTP before setting a password",
      });
    }

    const hashed = await bcrypt.hash(password, 10);
    let user = await User.findOne({ phone }).select("+password");
    let isNewUser = false;

    if (purpose === "register") {
      if (user?.password) {
        clearOtp(phone);
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
        clearOtp(phone);
        return res.status(404).json({
          success: false,
          message: "No account found for this phone number.",
        });
      }

      user.password = hashed;
      await user.save();
      isNewUser = !user.isProfileCompleted;
    }

    clearOtp(phone);

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
    console.log("SET PASSWORD ERROR:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// PASSWORD LOGIN
export const login = async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({
        success: false,
        message: "Phone and password are required",
      });
    }

    const user = await User.findOne({ phone }).select("+password");

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
    console.log("LOGIN ERROR:", error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
