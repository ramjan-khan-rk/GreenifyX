import cloudinary from "../config/cloudinary.js";
import streamifier from "streamifier";

export const uploadImage = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image selected",
      });
    }

    const stream = cloudinary.uploader.upload_stream(
      {
        folder: "GreenifyX",
      },
      (error, result) => {
        if (error) {
          return res.status(500).json({
            success: false,
            message: error.message,
          });
        }

        return res.status(200).json({
          success: true,
          imageUrl: result.secure_url,
        });
      }
    );

    streamifier.createReadStream(req.file.buffer).pipe(stream);

  } catch (e) {
    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};