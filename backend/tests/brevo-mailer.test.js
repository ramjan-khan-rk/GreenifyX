import assert from "node:assert/strict";
import { test, beforeEach, afterEach } from "node:test";
import {
  resetBrevoSender,
  sendOtpEmail,
  setBrevoSender,
} from "../utils/brevoMailer.js";
import { deliverOtp } from "../utils/otpDelivery.js";
import { parseFromAddress } from "../utils/fromAddress.js";
import {
  resetResendSender,
  setResendSender,
} from "../utils/resendMailer.js";

const originalEnv = { ...process.env };

beforeEach(() => {
  process.env.BREVO_API_KEY = "xkeysib-test-placeholder";
  process.env.EMAIL_FROM = "GreenifyX <noreply@example.test>";
  process.env.APP_NAME = "GreenifyX";
  process.env.NODE_ENV = "test";
  process.env.ALLOW_DEV_OTP = "false";
  delete process.env.RESEND_API_KEY;
  resetBrevoSender();
  resetResendSender();
});

afterEach(() => {
  resetBrevoSender();
  resetResendSender();
  for (const key of Object.keys(process.env)) {
    if (!(key in originalEnv)) delete process.env[key];
  }
  Object.assign(process.env, originalEnv);
});

test("sendOtpEmail uses mocked Brevo sender and does not call a live API", async () => {
  let captured = null;
  setBrevoSender(async (payload) => {
    captured = payload;
    return { ok: true };
  });

  const result = await sendOtpEmail({
    to: "pilot@example.test",
    otp: "654321",
  });

  assert.equal(result.delivered, true);
  assert.equal(result.channel, "brevo");
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
  setBrevoSender(async () => ({ ok: false, reason: "provider", status: 401 }));
  const result = await sendOtpEmail({
    to: "pilot@example.test",
    otp: "654321",
  });
  assert.equal(result.delivered, false);
  assert.equal(result.reason, "provider");
});

test("parseFromAddress reads display name and email", () => {
  assert.deepEqual(parseFromAddress("GreenifyX <noreply@example.test>"), {
    name: "GreenifyX",
    email: "noreply@example.test",
  });
  assert.deepEqual(parseFromAddress("noreply@example.test", "GreenifyX"), {
    name: "GreenifyX",
    email: "noreply@example.test",
  });
});

test("deliverOtp uses Brevo when BREVO_API_KEY is set", async () => {
  let used = "";
  setBrevoSender(async () => {
    used = "brevo";
    return { ok: true };
  });
  setResendSender(async () => {
    used = "resend";
    return { ok: true };
  });

  const result = await deliverOtp({ email: "pilot@example.test", otp: "111111" });
  assert.equal(result.delivered, true);
  assert.equal(result.channel, "brevo");
  assert.equal(used, "brevo");
});

test("deliverOtp falls back to Resend when BREVO_API_KEY is unset", async () => {
  delete process.env.BREVO_API_KEY;
  process.env.RESEND_API_KEY = "re_test_placeholder";
  let used = "";
  setBrevoSender(async () => {
    used = "brevo";
    return { ok: true };
  });
  setResendSender(async () => {
    used = "resend";
    return { ok: true };
  });

  const result = await deliverOtp({ email: "pilot@example.test", otp: "111111" });
  assert.equal(result.delivered, true);
  assert.equal(result.channel, "resend");
  assert.equal(used, "resend");
});
