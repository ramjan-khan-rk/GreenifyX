# Resend email OTP

GreenifyX sends registration and verification OTPs through [Resend](https://resend.com). No sender domain is hardcoded.

## Environment

Copy `backend/.env.example` and set:

- `RESEND_API_KEY` — API key from the Resend dashboard (never commit it)
- `EMAIL_FROM` — a from-address on a domain you verified in Resend, e.g. `GreenifyX <noreply@your-domain>`
- `APP_NAME` — used in the email subject and body
- `NODE_ENV` — `production` disables `ALLOW_DEV_OTP` even if that flag is true
- `ALLOW_DEV_OTP` — `true` only on local/non-prod so `send-otp` may include `devOtp`

## Domain

1. In Resend, add and verify **your** domain (DNS records Resend shows for that domain).
2. Set `EMAIL_FROM` to an address on that verified domain.
3. Do not use a placeholder domain in production. Resend will reject unverified senders.

## Behaviour

- OTP is emailed, never logged, and never returned in production API responses.
- `emailVerified` stays false until OTP verification succeeds (or set-password after a verified OTP).
- If Resend is unconfigured or the send fails, `POST /api/auth/send-otp` returns **503** unless the non-prod `ALLOW_DEV_OTP` shortcut is on.
