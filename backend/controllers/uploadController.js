import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";

// POST /api/upload/audio  (multipart field "audio")
export const uploadAudio = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: "No audio selected" });
    }
    // Cloudinary stores audio under the "video" resource type.
    const audioUrl = await uploadBufferToCloudinary(req.file.buffer, "GreenifyX/audio", "video");
    return res.status(200).json({ success: true, audioUrl });
  } catch (e) {
    res.status(500).json({ success: false, message: "Audio upload failed" });
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
