import assert from "node:assert/strict";
import { test } from "node:test";
import { cloudinaryPublicId } from "../utils/accountCleanup.js";

test("finds the Cloudinary public id of a bill photo", () => {
  assert.equal(cloudinaryPublicId("https://res.cloudinary.com/demo/image/upload/v1712345/GreenifyX/bills/abc123.jpg"), "GreenifyX/bills/abc123");
  assert.equal(cloudinaryPublicId("https://res.cloudinary.com/demo/image/upload/GreenifyX/bills/x_y.png"), "GreenifyX/bills/x_y");
  assert.equal(cloudinaryPublicId("https://res.cloudinary.com/demo/image/upload/q_auto/v99/GreenifyX/bills/z.webp"), "GreenifyX/bills/z");
});

test("ignores empty or foreign links", () => {
  assert.equal(cloudinaryPublicId(""), null);
  assert.equal(cloudinaryPublicId("https://example.com/photo.jpg"), null);
});
