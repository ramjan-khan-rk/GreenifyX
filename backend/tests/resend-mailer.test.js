import assert from "node:assert/strict";
import { test, beforeEach, afterEach } from "node:test";
import {
  resetResendSender,
  sendOtpEmail,
  setResendSender,
} from "../utils/resendMailer.js";
import { allowDevOtpShortcut } from "../utils/otpDelivery.js";

const originalEnv = { ...process.env };

beforeEach(() => {
  process.env.RESEND_API_KEY = "re_test_placeholder";
  process.env.EMAIL_FROM = "GreenifyX <noreply@example.test>";
  process.env.APP_NAME = "GreenifyX";
  process.env.NODE_ENV = "test";
  process.env.ALLOW_DEV_OTP = "false";
  resetResendSender();
});

afterEach(() => {
  resetResendSender();
  for (const key of Object.keys(process.env)) {
    if (!(key in originalEnv)) delete process.env[key];
  }
  Object.assign(process.env, originalEnv);
});

test("sendOtpEmail uses mocked Resend sender and does not require a live API", async () => {
  let captured = null;
  setResendSender(async (payload) => {
    captured = payload;
    return { ok: true };
  });

  const result = await sendOtpEmail({
    to: "pilot@example.test",
    otp: "654321",
  });

  assert.equal(result.delivered, true);
  assert.equal(captured.to, "pilot@example.test");
  assert.equal(captured.from, "GreenifyX <noreply@example.test>");
  assert.match(captured.html, /654321/);
  assert.equal(captured.text.includes("654321"), false);
});

test("sendOtpEmail fails safely when EMAIL_FROM is missing", async () => {
  delete process.env.EMAIL_FROM;
  const result = await sendOtpEmail({
    to: "pilot@example.test",
    otp: "654321",
  });
  assert.equal(result.delivered, false);
  assert.equal(result.reason, "not_configured");
});

test("sendOtpEmail fails safely when the provider rejects", async () => {
  setResendSender(async () => ({ ok: false, reason: "provider", status: 429 }));
  const result = await sendOtpEmail({
    to: "pilot@example.test",
    otp: "654321",
  });
  assert.equal(result.delivered, false);
  assert.equal(result.reason, "provider");
});

test("ALLOW_DEV_OTP is ignored in production", () => {
  process.env.NODE_ENV = "production";
  process.env.ALLOW_DEV_OTP = "true";
  assert.equal(allowDevOtpShortcut(), false);
});

test("ALLOW_DEV_OTP works only outside production", () => {
  process.env.NODE_ENV = "development";
  process.env.ALLOW_DEV_OTP = "true";
  assert.equal(allowDevOtpShortcut(), true);
});
