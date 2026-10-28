import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";

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
