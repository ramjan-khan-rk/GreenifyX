import cloudinary from "../config/cloudinary.js";
import streamifier from "streamifier";

export const uploadBufferToCloudinary = (buffer, folder = "GreenifyX") =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder },
      (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(result.secure_url);
      }
    );

    streamifier.createReadStream(buffer).pipe(stream);
  });
