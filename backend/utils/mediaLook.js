const LOOK_TRANSFORMS = {
  hd: "e_sharpen:70,e_contrast:12,q_auto:best,f_auto",
  vivid: "e_vibrance:50,e_contrast:10,q_auto:best,f_auto",
  warm: "e_sepia:18,e_vibrance:20,q_auto:best,f_auto",
  cool: "e_hue:-12,e_vibrance:15,q_auto:best,f_auto",
  mono: "e_grayscale,e_contrast:12,q_auto:best,f_auto",
  soft: "e_brightness:8,e_contrast:-8,q_auto:best,f_auto",
};

export const LOOKS = new Set(["natural", ...Object.keys(LOOK_TRANSFORMS)]);

export const CAUSES = new Set(["Planet", "Humanity", "Wildlife", "Stories"]);

export const presentMediaUrl = (url, look, mediaType) => {
  if (!url || mediaType === "video") return url;
  const transform = LOOK_TRANSFORMS[look];
  if (!transform) return url;

  const marker = "/upload/";
  const index = url.indexOf(marker);
  if (index === -1) return url;

  return `${url.slice(0, index + marker.length)}${transform}/${url.slice(
    index + marker.length
  )}`;
};
