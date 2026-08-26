# 🌱 GreenifyX

> **An eco-social mobile platform that turns environmental actions into a social and rewarding experience.**

GreenifyX is an independently developed **Flutter + Node.js** application built to encourage people to participate in real-world environmental activities, share their progress, connect with friends, and participate in challenges.

The project covers the complete development stack — **mobile application, REST APIs, authentication, database systems, media storage, and real-time communication.**

---

## 🚀 Features

### 👤 Authentication & Profiles

* JWT-based user authentication
* User registration and login
* Personalized user profiles
* Profile image management
* Eco Score and activity statistics

### 🌍 Social Feed

* Share environmental activities with images
* Like and comment on posts
* Activity categories such as:

  * 🌳 Tree Plantation
  * ♻️ Recycling
  * 🚲 Cycling
  * 🚶 Walking
  * 💧 Water Conservation

### 🤝 Friends & Challenges

* Search for users
* Send and accept friend requests
* Create environmental challenges
* Set challenge difficulty, targets, and deadlines
* Track challenge progress

### 💬 Real-Time Chat

* One-to-one messaging
* Text messages
* Image messages
* Real-time communication using **Socket.IO**

### 🔔 Notifications

The backend supports notifications for events such as:

* Friend requests
* Likes and comments
* Challenge updates
* New messages
* Verification events

---

## 🛠️ Tech Stack

| Layer               | Technologies                 |
| ------------------- | ---------------------------- |
| **Mobile**          | Flutter, Dart, Riverpod, Dio |
| **Backend**         | Node.js, Express.js          |
| **Database**        | MongoDB, Mongoose            |
| **Authentication**  | JWT                          |
| **Real-Time**       | Socket.IO                    |
| **Media Storage**   | Cloudinary                   |
| **Version Control** | Git, GitHub                  |

---

## 🏗️ Architecture

```text
                    ┌──────────────────┐
                    │  Flutter Mobile  │
                    │       App        │
                    └────────┬─────────┘
                             │
                        REST APIs
                             │
                             ▼
                    ┌──────────────────┐
                    │ Node.js +        │
                    │ Express.js       │
                    └───────┬──────────┘
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
         MongoDB        Cloudinary      Socket.IO
         Database       Media Storage    Real-Time
```

The Flutter application communicates with the backend through REST APIs. **Socket.IO** provides real-time communication for features such as messaging.

---

## 📂 Project Structure

```text
GreenifyX/
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

The Flutter application follows a **feature-oriented structure**, while the backend separates controllers, models, routes, middleware, configuration, and real-time communication.

---

## 🌱 Eco Score

GreenifyX uses an **Eco Score** system to represent a user's participation in environmental activities.

Examples include:

* 🌳 Tree Plantation
* ♻️ Recycling
* 🚲 Cycling
* 🚶 Walking
* 💧 Water Conservation

The goal is to make environmental participation measurable and engaging within the platform.

---

## 📡 Backend API

The backend is organized into modules including:

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

Protected endpoints use **JWT authentication middleware**.

---

## ⚙️ Getting Started

### Clone

```bash
git clone https://github.com/ramjan-khan-rk/GreenifyX.git
cd GreenifyX
```

### Mobile

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

Create a `.env` file inside the `backend` directory:

```env
PORT=5000
MONGODB_URI=your_connection_string
JWT_SECRET=your_secret

CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

> **Never commit your `.env` file or other credentials to GitHub.**

---

## 🧪 Current Development Status

GreenifyX is an **actively developed project currently undergoing testing**.

### Implemented

* ✅ JWT Authentication
* ✅ User Profiles
* ✅ Friends System
* ✅ Social Feed
* ✅ Posts & Comments
* ✅ Likes
* ✅ Challenge System
* ✅ Real-Time Chat
* ✅ Socket.IO Integration
* ✅ Cloudinary Media Uploads
* ✅ REST API Communication
* ✅ Notification Backend

### In Progress

* 🔄 Production testing and optimization
* 🔄 Mobile release testing
* 🔄 Notification experience improvements

### Planned

* 📍 GPS-based activity verification
* 📍 Nearby user verification
* 🏆 Advanced leaderboard system
* 📊 Improved Eco Score algorithm
* ⚡ Further production optimization

---

## 🌍 Vision

GreenifyX aims to make sustainability:

**Visible. Social. Verifiable. Rewarding.**

The idea is simple — instead of only encouraging people to care about the environment, create a platform where environmental actions can be **shared, tracked, discussed, and turned into meaningful community participation.**

---

## 👨‍💻 Developer

**Ramjan Khan**

**Full-Stack Developer & Product Builder**

I build practical software across web, mobile, backend systems, databases, APIs, and real-time technologies.

[Portfolio](https://ramjan-khan-portfolio-g7jr-three.vercel.app/) · [LinkedIn](https://www.linkedin.com/in/ramjan-khan) · [GitHub](https://github.com/ramjan-khan-rk)
