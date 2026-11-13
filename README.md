# 🌱 GreenifyX

> **A full-stack eco-social platform that turns real-world environmental actions into a social and rewarding experience.**

**GreenifyX** is an independently developed Flutter & Node.js platform, piloting in the UAE. People share eco-friendly actions, get them verified, earn **Eco Points**, join challenges and campaigns, talk in real time and redeem rewards. Organisations get their own dashboards and ESG reports. An admin web app runs the whole thing.

Current mobile version: **1.0.2 (build 3)**.

---

## 🚀 Features

### 👤 Accounts & onboarding

* Sign-up with email OTP (Brevo), then password login (JWT)
* Guided onboarding, invite links and referrals
* Profiles with photo, emirate, Eco Points, streaks and verified ticks
* English and **Arabic** (switchable in the app), light and **dark mode**
* Stays signed in on slow networks; wakes the server at launch with a friendly message

### 🌍 Feed & social

* Post eco actions with photos or video from a live, searchable eco-activity catalogue
* Tag friends, save posts, hashtags, mentions and trending topics
* **For you** feed, follows, **stories** and **reels** with trending sounds
* Threaded comments with reactions and pins
* Communities and community group chat
* Creator analytics

### ✅ Verification & Eco Points

* Friend verification before Eco Points are awarded (not on upload)
* **AI instant verification** with an AI-verified badge
* AI moderation and duplicate-photo detection
* GPS evidence and geofences for campaigns, QR check-ins at checkpoints
* Field verifiers and points ledger
* Authenticated leaderboard of verified Eco Points

### 🏆 Challenges, campaigns & events

* Friend challenges with difficulty, target and deadline
* Weekly battles, streak freezes and reminders
* Sponsored challenges from partner organisations
* Campaigns, events and recycling pickups
* Environmental issue reporting on a map, eco places

### 🌿 Impact

* Personal **carbon tracker** and CO₂ impact estimates
* Shareable impact certificates with a public verify link
* Snap & Sort recycling guide

### 🛍 Rewards & marketplace

* Rewards catalogue and redemptions
* Paid partner rewards with **Stripe Checkout**
* **Swap & Share** marketplace

### 💬 Real-time

* One-to-one chat with text, images and **voice notes**
* Voice and video calls (WebRTC, optional TURN relay)
* **Live streaming** (LiveKit)
* Notification centre: bundled, grouped, bulk actions, plus push notifications (Firebase)
* Offline mode and background uploads

### 🤖 Assistants

* AI eco companion and assistant
* **Hey Greeny** voice assistant (speech-to-text and voice replies)

### 🏢 Organisations

* Organisation accounts with their own codes and dashboards
* Shareable **ESG reports**
* Public website for organisations, with enquiries sent to the admin

### 🛡️ Admin dashboard (Flutter Web)

* Overview KPIs, including rewards, pickups and events
* Analytics: DAU / WAU / MAU, cohorts, funnel, emirates, heat map
* AI-written insights and impact pages
* Users (search, filter, suspend / restore), moderation queue, verification queue
* Campaigns, checkpoints, places, eco activities, sponsored challenges, badges
* Rewards, pickups, events, points, issues, organisations and enquiries
* Public pages: organisations site, ESG report, certificate verify, invite join, payment result
* Responsive: sidebar on desktop, drawer on tablets and phones; deployable as a website

### 🇦🇪 UAE pilot

* Emirate on every profile (all seven emirates) for regional reporting
* Asia/Dubai time for streaks and charts, +971 phone defaults

---

## 🛠 Tech stack

| Layer              | Technologies                                                    |
| ------------------ | --------------------------------------------------------------- |
| **Mobile**         | Flutter, Dart, Riverpod, GoRouter, Dio                          |
| **Admin web**      | Flutter Web, GoRouter, Dio                                      |
| **Backend**        | Node.js, Express.js                                             |
| **Database**       | MongoDB, Mongoose                                               |
| **Auth**           | JWT, email OTP (Brevo)                                          |
| **Real-time**      | Socket.IO, WebRTC, LiveKit                                      |
| **Media**          | Cloudinary                                                      |
| **Payments**       | Stripe Checkout                                                 |
| **Push**           | Firebase Cloud Messaging                                        |
| **AI (optional)**  | Claude API for the assistant, Snap & Sort and admin reports     |
| **Maps**           | flutter_map, geolocator                                         |

---

## 🏗 System architecture

```text
Flutter Mobile App      Flutter Web Admin + public site
        │                      │
        └──── REST APIs ───────┘
                   ▼
           Node.js + Express
   ┌──────────┬──────┴─────┬───────────┬──────────┐
   ▼          ▼            ▼           ▼          ▼
MongoDB   Cloudinary   Socket.IO    Stripe    LiveKit / FCM / Claude
```

The apps talk to the backend over REST. Socket.IO handles chat, calls signalling and live notifications.

---

## 📂 Project structure

```text
GreenifyX
├── admin/      Flutter Web admin dashboard and public pages (lib/api, core, pages, widgets)
├── mobile/     Flutter app, feature-first (lib/core, lib/features/*)
├── backend/
│   ├── config/  controllers/  middleware/  models/  routes/  socket/  utils/
│   ├── scripts/ (create-admin, make-admin, demo seeder)
│   ├── tests/   (node:test)
│   └── docs/    (Brevo and Resend email setup)
└── docs/       IOS_BUILD.md
```

---

## 📡 REST API modules

All under `/api`:

```text
/auth  /users  /friends  /posts  /comments  /challenges  /messages  /upload
/notifications  /campaigns  /verifier  /env-reports  /map  /assistant  /calls
/orgs  /rewards  /pickups  /events  /activities  /public  /admin (admin only)
```

Growth, lifestyle and social endpoints (onboarding, invites, streaks, trending, badges, sponsored, live, ESG, voice, stories, reels, follows, battles, communities, marketplace, carbon, certificates, check-ins) are mounted directly on `/api`. Protected endpoints use JWT middleware.

---

## ⚙️ Getting started

### Clone

```bash
git clone https://github.com/ramjan-khan-rk/GreenifyX.git
cd GreenifyX
```

### Backend

```bash
cd backend
npm install
npm run dev     # or: npm start
npm test        # backend unit tests
```

Copy `backend/.env.example` to `backend/.env` and fill values locally:

```env
PORT=5000
NODE_ENV=development
MONGO_URI=
JWT_SECRET=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CORS_ORIGIN=
BREVO_API_KEY=
EMAIL_FROM=
APP_NAME=GreenifyX
ALLOW_DEV_OTP=false

# Optional
RESEND_API_KEY=
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-haiku-5-5
TURN_URLS=
TURN_USERNAME=
TURN_CREDENTIAL=
FIREBASE_SERVICE_ACCOUNT=
STRIPE_SECRET_KEY=
PUBLIC_SITE_URL=
LIVEKIT_URL=
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
```

* Production `JWT_SECRET` must be at least 32 characters.
* `ALLOW_DEV_OTP=true` is for non-production only; it is ignored when `NODE_ENV=production`.
* Email OTP uses **Brevo** when `BREVO_API_KEY` is set (see `backend/docs/brevo-setup.md`), with Resend as a fallback.
* Without `ANTHROPIC_API_KEY`, the assistant, Snap & Sort and admin reports run from live GreenifyX data and templates.
* `FIREBASE_SERVICE_ACCOUNT` is the service-account JSON on one line, set only on the host.
* Use `sk_test_...` Stripe keys while testing.

> **Never commit your `.env` file.** It is excluded through `.gitignore`.

**JWT rotation (ops, not automated):** set a new `JWT_SECRET` on the host, restart the API, and expect existing sessions to end until users log in again.

### Mobile app

```bash
cd mobile
flutter pub get
flutter run
```

iOS build steps are in `docs/IOS_BUILD.md`.

### Admin dashboard

```bash
cd admin
flutter pub get
flutter run -d chrome
# against a local API:
flutter run -d chrome --dart-define=API_BASE=http://localhost:5000/api
```

Build it as a website with `flutter build web --dart-define=API_BASE=https://your-api/api`, host the `admin/build/web` folder on any static host, and add that address to `CORS_ORIGIN`.

Create your admin account (you'll be asked for a password; it's stored only as a hash):

```bash
cd backend
npm run create-admin -- --email you@company.com --name "Your Name"
```

Run it again with the same email to reset that admin's password.

### Demo data

```bash
cd backend
npm run seed:demo             # members across all 7 emirates, posts, challenges, comments
npm run seed:demo -- --clear  # removes only what the seeder created
```

The seeder prints the demo resident and field-verifier logins. It never creates an admin account. Every seeded record is flagged `isDemo`, so clearing never touches real accounts.

---

## 🚧 Status

### ✅ Done

Everything listed under **Features** above is implemented on `main`, and the backend unit tests pass.

### 🔜 Planned

* UAE PASS sign-in
* Monthly ESG / impact reports as PDF
* Nearby-user verification
* Production optimisation

### Pilot notes

* Eco Points are community- and AI-verified, not government MRV.
* CO₂ figures are indicative per-action estimates, not certified measurement.
* Challenge progress is self-reported.
* This README is not a live ops report. Brevo, JWT length, Atlas indexes, Stripe, Firebase and LiveKit must still be set on the host.

---

## 🌍 Vision

GreenifyX aims to make sustainability **visible, social, verifiable and rewarding** by encouraging measurable environmental actions instead of passive awareness.

---

## 👨‍💻 Developer

**Ramjan Khan**

Full-Stack & Mobile Application Developer

Building practical software that combines technology with real-world impact.
