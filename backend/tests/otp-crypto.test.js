import assert from "node:assert/strict";
import { test } from "node:test";
import { generateOtpCode, hashOtp, hashesMatch } from "../utils/otpCrypto.js";

test("generateOtpCode is six digits", () => {
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret-for-otp-hashing";
  const code = generateOtpCode();
  assert.match(code, /^\d{6}$/);
});

test("hashOtp is stable and compared in constant time", () => {
  process.env.JWT_SECRET = "test-secret-for-otp-hashing";
  const a = hashOtp("user@test.com", "register", "123456");
  const b = hashOtp("user@test.com", "register", "123456");
  const c = hashOtp("user@test.com", "register", "000000");
  assert.equal(hashesMatch(a, b), true);
  assert.equal(hashesMatch(a, c), false);
});
