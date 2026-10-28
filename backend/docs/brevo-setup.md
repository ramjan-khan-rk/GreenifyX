# Brevo email OTP

GreenifyX sends registration, reset, and verify OTPs through the existing OTP service. Delivery uses [Brevo transactional email](https://developers.brevo.com/reference/sendtransacemail) when `BREVO_API_KEY` is set. This is not a second OTP system: hashing, 10-minute expiry, 5 attempts, one-time use, and rate limits stay in `authController` / `OtpChallenge`.

This doc does **not** send live mail and does not include API keys. Put secrets only in local or host env.

## Environment

Copy `backend/.env.example` to `backend/.env` and set:

- `BREVO_API_KEY` — transactional API key from Brevo (never commit it)
- `EMAIL_FROM` — a from-address you verified in Brevo, e.g. `GreenifyX <noreply@your-domain>`
- `APP_NAME` — used in the email subject and body (default `GreenifyX`)
- `NODE_ENV` — `production` disables `ALLOW_DEV_OTP` even if that flag is true

If `BREVO_API_KEY` is empty, delivery can still use Resend (`RESEND_API_KEY`) as a leftover fallback. Prefer Brevo for new setups.

## Clicks in Brevo (create a key and verify sender)

1. Open [https://app.brevo.com](https://app.brevo.com) and sign in.
2. Click your **profile** (bottom-left or top-right) → **SMTP & API**.
3. Open the **API keys** tab.
4. Click **Generate a new API key**. Name it something like `GreenifyX OTP`. Copy the key once into `BREVO_API_KEY` on your machine or host. Do not paste it into git.
5. In the left menu open **Transactional** (or **Campaigns**) → **Settings** → **Senders**. Direct list: [https://app.brevo.com/senders/list](https://app.brevo.com/senders/list).
6. Click **Add a sender**.
7. Enter the from name (`APP_NAME`, e.g. GreenifyX) and the from email you will put in `EMAIL_FROM`.
8. Open the confirmation email Brevo sends to that address and click the verify link.
9. Optional but recommended for production: **Senders** → **Domains** → **Add a domain**. Add the DNS records Brevo shows. Wait until the domain status is verified. Then set `EMAIL_FROM` to an address on that domain (example shape only: `GreenifyX <noreply@your-domain>`).
10. Restart the API after saving env. `POST /api/auth/send-otp` emails the code. OTP is never logged and never returned when `NODE_ENV=production`.

## Behaviour

- Same endpoints: `send-otp` → `verify-otp` → `set-password`.
- If Brevo is unconfigured or the send fails, `send-otp` returns **503** unless the non-prod `ALLOW_DEV_OTP` shortcut is on.
- Tests mock the Brevo sender and do not call `api.brevo.com`.
