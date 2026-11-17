# Google Play Console: App content answers

Package: `com.ramjankhan.greenifyx`. Answers below match what the app really does (checked against `AndroidManifest.xml` and the backend). If a feature changes, update this file and the policy at `admin/web/privacy.html`.

**First:** push the repo so Netlify rebuilds the admin site, then open these two links in a browser to check they load:

- Privacy policy: https://greenifyx-admin.netlify.app/privacy.html
- Account deletion: https://greenifyx-admin.netlify.app/delete-account.html

---

## 1. Privacy policy
Paste `https://greenifyx-admin.netlify.app/privacy.html` → Save.

## 2. App access
Choose **All or some functionality is restricted** and add a reviewer login: a normal test account you create yourself (email and password), with a note:
> Sign in with email and password. Calls need a second account; Health sync needs Health Connect installed. UAE PASS sign-in is optional; use email login.

Never use your own personal account or the admin account here.

## 3. Ads
**No**, the app does not contain ads.

## 4. Content rating
Category: **Social / communication**. Answer **Yes** to: users can interact/communicate, user-generated content is shared, the app shares the user's location with other users (posts can show a place; check-ins). Answer **No** to violence, gambling, drugs and similar. Mention that the app has reporting and blocking for content and users.

## 5. Target audience
Pick **13–15, 16–17 and 18+**. Do **not** pick any age under 13, because that brings in the Families policy. Answer **No** to "Could the app unintentionally appeal to children?"

## 6. News app
**No.**

## 7. Government app
**No.** GreenifyX is not built by or for a government body, even though it supports UAE PASS sign-in.

## 8. Financial features
**My app doesn't provide any financial features.** Paid rewards go through Stripe Checkout; that is a purchase, not a financial service.

## 9. Health apps
Tick **Activity and fitness** only. Nothing medical.

## 10. Data safety

General questions:
- Does your app collect or share any of the required user data types? **Yes**
- Is all user data encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes**, and add the deletion URL `https://greenifyx-admin.netlify.app/delete-account.html`

**Shared?** Answer **No** for every type below. Google does not count sending data to your own service providers (MongoDB, Render, Cloudinary, Firebase, Stripe, Anthropic and so on) as sharing, nor transfers the user starts themselves (for example joining an organisation that sees their impact).

**Processed ephemerally?** **No** for all, except where noted.

| Section | Data type | Required or optional | Purposes |
|---|---|---|---|
| Location | Approximate location | Optional | App functionality |
| Location | Precise location | Optional | App functionality, Fraud prevention / security |
| Personal info | Name | Required | App functionality, Account management |
| Personal info | Email address | Required | App functionality, Account management, Developer communications |
| Personal info | User IDs | Required | App functionality, Account management |
| Personal info | Phone number | Optional | Account management |
| Personal info | Other info (bio, emirate, UAE PASS account type) | Optional | App functionality |
| Financial info | Purchase history | Optional | App functionality |
| Financial info | Other financial info (utility bill amounts) | Optional | App functionality |
| Health and fitness | Fitness info (steps, cycling) | Optional | App functionality |
| Messages | Other in-app messages | Optional | App functionality |
| Photos and videos | Photos | Optional | App functionality, Fraud prevention / security |
| Photos and videos | Videos | Optional | App functionality |
| Audio | Voice or sound recordings (voice notes) | Optional | App functionality |
| App activity | App interactions | Required | App functionality, Analytics |
| App activity | Other user-generated content (posts, comments) | Optional | App functionality |
| App info and performance | Diagnostics (call step logs) | Required | App functionality |
| Device or other IDs | Device or other IDs (push tokens) | Required | App functionality |

Do **not** tick: contacts, calendar, files and docs, web browsing, search history, installed apps, credit card details (Stripe collects those, not the app), race, religion, sexual orientation, political views.

## 11. Health Connect declaration
Under **App content → Health Connect**, request only these, with these reasons:

| Permission | Reason to paste |
|---|---|
| READ_STEPS | Users earn Eco Points for walking instead of driving. We read daily step totals for the last 7 days and send only the daily total to our server. |
| READ_EXERCISE | We read cycling workouts so users can earn Eco Points for cycling instead of driving. |
| READ_DISTANCE | We read the distance of cycling workouts to calculate the points and the estimated CO₂ saved. |

Confirm you follow the Limited Use rules (the privacy policy has a Health Connect section for this). Expect Google to ask for a short screen recording of the Health sync screen.

## 12. Foreground service permissions
The app uses `FOREGROUND_SERVICE_MICROPHONE` and `FOREGROUND_SERVICE_CAMERA` (type `microphone|camera`) to keep a call alive while the user switches to another app.

- Task type: **Phone call / Video call (user-initiated)**
- Description: *"When the user is in a voice or video call with a friend, a foreground service keeps the microphone and camera running if they switch to another app. A notification is shown for the whole call and the service stops when the call ends."*
- Video: record about 30 seconds on a phone: start a call, go to the home screen, show the call notification, come back, hang up. Upload it to YouTube as **Unlisted** and paste the link.

## 13. Full-screen intent
`USE_FULL_SCREEN_INTENT` is used to show incoming calls on the lock screen. Declare the use case **Calling (receiving voice or video calls)**.

## 14. Other permissions (no form needed)
Location is foreground only (no `ACCESS_BACKGROUND_LOCATION`), so no location declaration. `ACTIVITY_RECOGNITION`, camera, microphone and notifications are normal runtime permissions covered by the Data safety form.

## 15. Before sending for review
- Main store listing: short description, full description, icon 512×512, feature graphic 1024×500, at least 2 phone screenshots.
- Upload an **App bundle (.aab)**: `flutter build appbundle --release`, signed with your upload key.
- Start with **Internal testing**, then Closed testing. New personal developer accounts need 12 testers for 14 days before Production.
