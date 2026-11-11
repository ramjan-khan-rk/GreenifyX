import test from "node:test";
import assert from "node:assert/strict";
import { presentMediaUrl } from "../utils/mediaLook.js";

test("photo looks are inserted into Cloudinary delivery urls", () => {
  const url = "https://res.cloudinary.com/demo/image/upload/v1/GreenifyX/posts/a.jpg";
  const next = presentMediaUrl(url, "hd", "image");
  assert.match(next, /\/upload\/e_sharpen:70/);
  assert.match(next, /GreenifyX\/posts\/a\.jpg$/);
});

test("natural and video urls stay untouched", () => {
  const url = "https://res.cloudinary.com/demo/video/upload/v1/clip.mp4";
  assert.equal(presentMediaUrl(url, "vivid", "video"), url);
  assert.equal(presentMediaUrl(url, "natural", "image"), url);
});
