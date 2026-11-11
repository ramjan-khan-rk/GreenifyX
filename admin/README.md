# GreenifyX Admin

Flutter Web dashboard for running the GreenifyX community.

| Page | What it shows |
| --- | --- |
| Overview | Members, weekly actives, verified actions, est. CO₂ saved, 30-day trend, top actions, top contributors, latest activity |
| Impact | CO₂ by action type, members by emirate, tree-year and car-km equivalents, methodology |
| Users | Search and filter members, view stats, suspend or restore accounts |
| Moderation | Reported posts with reasons; hide, restore or keep |
| Challenges | All friend challenges with live progress |

## Run

```bash
flutter pub get
flutter run -d chrome                                                   # uses the hosted API
flutter run -d chrome --dart-define=API_BASE=http://localhost:5000/api  # local API
```

Sign in with an account that has the admin role (`npm run make-admin -- you@example.com` in `backend/`, or use the seeded `admin@greenifyx.demo`).

## Deploy as a website

```bash
flutter build web --release --dart-define=API_BASE=https://your-api.example.com/api
```

Upload `build/web` to any static host (Firebase Hosting, Netlify, Vercel, S3) and add the site's address to the backend `CORS_ORIGIN`.
