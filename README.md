# 🌱 GreenifyX

> **A full-stack eco-social platform that transforms real-world environmental actions into a social and rewarding experience.**

**GreenifyX** is an independently developed Flutter & Node.js application where users can share eco-friendly activities, challenge friends, earn **Eco Score**, communicate in real time, and build a community around sustainable living.

---

## 🚀 Key Features

### 👤 Authentication & Profiles

* Secure user registration & login (JWT)
* Personalized profiles with profile images
* Eco Score and activity statistics
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
MONGODB_URI=your_connection_string
JWT_SECRET=your_secret

CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

> **Note:** Never commit your `.env` file. It is excluded through `.gitignore`.

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
