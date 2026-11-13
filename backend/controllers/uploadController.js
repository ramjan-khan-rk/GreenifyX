import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";

// POST /api/upload/audio  (multipart field "audio")
export const uploadAudio = async (req, res) => {
  try {
    if (!req.file || !req.file.size) {
      console.log("[voice] empty upload");
      return res.status(400).json({ success: false, message: "The recording was empty. Hold the mic a little longer." });
    }
    // Cloudinary stores audio under the "video" resource type.
    const audioUrl = await uploadBufferToCloudinary(req.file.buffer, "GreenifyX/audio", "video");
    return res.status(200).json({ success: true, audioUrl });
  } catch (e) {
    console.error("Audio upload failed:", e?.message || e);
    res.status(500).json({ success: false, message: "Voice note couldn't be saved. Please try again." });
  }
};

export const uploadImage = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image selected",
      });
    }

    const imageUrl = await uploadBufferToCloudinary(req.file.buffer);

    return res.status(200).json({
      success: true,
      imageUrl,
    });
  } catch (e) {
    res.status(500).json({
      success: false,
      message: "Image upload failed",
    });
  }
};
