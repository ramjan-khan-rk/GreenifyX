import User from "../models/User.js";
import jwt from "jsonwebtoken";

// Temporary OTP storage (Development only)
const otpStore = {};

// Generate JWT
const generateToken = (id) => {
  return jwt.sign(
    { id },
    process.env.JWT_SECRET,
    {
      expiresIn: "7d",
    }
  );
};

// SEND OTP
export const sendOTP = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    // Generate 4-digit OTP
    const otp = Math.floor(1000 + Math.random() * 9000).toString();

    otpStore[phone] = otp;

    console.log(`📱 OTP for ${phone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
      otp, // Remove this in production
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};


// VERIFY OTP
export const verifyOTP = async (req, res) => {
  try { 
    console.log("VERIFY OTP HIT");
    const { phone, otp } = req.body;
console.log(phone,otp);
    if (!phone || !otp) {
      return res.status(400).json({
        success: false,
        message: "Phone and OTP are required",
      });
    }

    if (otpStore[phone] !== otp) {
      return res.status(400).json({
        success: false,
        message: "Invalid OTP",
      });
    }

    let user = await User.findOne({ phone });

    let isNewUser = false;

    if (!user) {
      isNewUser = true;

      user = await User.create({
        phone,
      });
    }

    // OTP can only be used once
    delete otpStore[phone];

    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      message: "Login successful",
      token,
      isNewUser,
      user,
    });

  } catch (error) {

  console.log("VERIFY OTP ERROR:", error);

  res.status(500).json({
    success: false,
    message: error.message,
  });

}
};