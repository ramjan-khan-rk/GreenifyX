# 🌱 GreenifyX

> **A full-stack eco-social platform that transforms real-world environmental actions into a social and rewarding experience.**

**GreenifyX** is an independently developed Flutter & Node.js application where users can share eco-friendly activities, challenge friends, earn **Eco Points**, communicate in real time, and build a community around sustainable living.

---

## 🚀 Key Features

### 👤 Authentication & Profiles

* Secure user registration & login (JWT, email OTP via Resend)
* Personalized profiles with profile images
* Eco Points and activity statistics
* Friend-based social network

### 🌍 Social Feed

* Share environmental activities with images
* Like and comment on posts
* Activity categories (Tree Plantation, Recycling, Cycling, Water Conservation, etc.)
* Community-driven engagement

### 🤝 Friends & Challenges

* Search and add friends
* Send & accept friend requests
* Create eco challenges
* Set difficulty, target & deadline
* Track challenge progress and completion

### 💬 Real-Time Chat

* One-to-one messaging
* Text & image messages
* Instant delivery using **Socket.IO**

### 🔔 Notification System

* Friend requests
* Likes & comments
* Challenge updates
* New messages
* Verification events

---

## 🛠 Tech Stack

| Layer               | Technologies                 |
| ------------------- | ---------------------------- |
| **Mobile**          | Flutter, Dart, Riverpod, Dio |
| **Backend**         | Node.js, Express.js          |
| **Database**        | MongoDB, Mongoose            |
| **Authentication**  | JWT                          |
| **Real-time**       | Socket.IO                    |
| **Media Storage**   | Cloudinary                   |
| **Version Control** | Git & GitHub                 |

---

## 🏗 System Architecture

```text
Flutter Mobile App
        │
        │ REST APIs
        ▼
Node.js + Express
   │      │
   │      ├────────► MongoDB
   │      ├────────► Cloudinary
   │      └────────► Socket.IO
   │
   ▼
Real-Time Updates
```

The mobile application communicates with the backend through REST APIs, while Socket.IO powers instant messaging and live notifications.

---

## 📂 Project Structure

```text
GreenifyX
│
├── mobile/
│   └── lib/
│       ├── core/
│       └── features/
│           ├── auth/
│           ├── home/
│           ├── profile/
│           ├── friends/
│           ├── post/
│           ├── challenge/
│           ├── chat/
│           ├── comment/
│           ├── feed/
│           ├── navigation/
│           └── splash/
│
├── backend/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   ├── socket/
│   └── utils/
│
└── README.md
```

The Flutter application follows a **feature-first architecture** with clear separation of **application**, **data**, **domain**, and **presentation** layers.

---

## 🌱 Eco Score System

GreenifyX rewards genuine environmental actions through **Eco Score**.

Examples include:

* 🌳 Tree Plantation
* ♻️ Recycling
* 🚲 Cycling
* 🚶 Walking
* 💧 Water Conservation

Each activity contributes to a user's overall environmental impact within the platform.

---

## 📡 REST API Modules

The backend currently provides APIs for:

```text
/auth
/users
/friends
/posts
/comments
/challenges
/messages
/uploads
/notifications
```

Protected endpoints use JWT authentication middleware.

---

## ⚙️ Getting Started

### Clone the repository

```bash
git clone https://github.com/ramjan-khan-rk/GreenifyX.git
cd GreenifyX
```

### Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

### Backend

```bash
cd backend
npm install
npm run dev
```

Create a `.env` file inside the backend directory with:

```env
PORT=5000
NODE_ENV=development
MONGO_URI=
JWT_SECRET=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CORS_ORIGIN=
RESEND_API_KEY=
EMAIL_FROM=
APP_NAME=GreenifyX
ALLOW_DEV_OTP=false
```

Copy `backend/.env.example` to `backend/.env` and fill values locally. Production `JWT_SECRET` must be at least 32 characters; do not rotate an existing production secret from this repo. `ALLOW_DEV_OTP=true` is non-production only and may include `devOtp` in the send-otp JSON body; it is ignored when `NODE_ENV=production`. Registration OTP is sent with Resend — see `backend/docs/resend-setup.md`. Use a from-address on a domain you verified in Resend (`EMAIL_FROM`). Do not commit secrets.

> **Note:** Never commit your `.env` file. It is excluded through `.gitignore`.

**JWT rotation (ops, not automated):** set a new `JWT_SECRET` on the host, restart the API, and expect existing sessions to fail until users log in again. This process does not change any current production secret.

---

## 🧪 Tested Functionality

* User authentication
* Friend requests
* Social feed
* Likes & comments
* Eco challenges
* Real-time messaging
* Notifications
* Cloud media uploads
* REST API communication

---

## 🚧 Development Status

### ✅ Implemented

* JWT Authentication
* User Profiles
* Friends System
* Posts & Comments
* Likes
* Challenge System
* Real-Time Chat
* Notification Backend
* Socket.IO Integration
* Cloudinary Uploads

### 🔜 Planned

* GPS-based eco verification
* Nearby user verification
* Leaderboards
* Advanced Eco Score algorithm
* Enhanced notification UI
* Production optimization

---

## 🌍 Vision

GreenifyX aims to make sustainability **visible, social, verifiable, and rewarding** by encouraging measurable environmental actions instead of passive awareness.

---

## 👨‍💻 Developer

**Ramjan Khan**

Full-Stack & Mobile Application Developer

Building practical software that combines technology with real-world impact.
