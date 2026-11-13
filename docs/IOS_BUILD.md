# Building GreenifyX for iPhone

The project is ready for iOS: the bundle ID is `com.ramjankhan.greenifyx`. Permissions are set for camera, photos, microphone, location and music, the app icons are in place, and the background modes needed for push and calls are on.

Apple only allows iOS builds on a **Mac with Xcode**. You also need an **Apple Developer account** (USD 99 per year) to install the app on real iPhones or publish it.

## One-time setup (on the Mac)
1. Install Xcode from the App Store, open it once and accept the licence.
2. Install Flutter, then run `flutter doctor` and fix anything it lists for iOS.
3. Install CocoaPods: `sudo gem install cocoapods`.
4. Copy the GreenifyX folder to the Mac (or clone it from GitHub).

## Firebase push for iPhone
1. In the Firebase console, open the GreenifyX project, then Add app → iOS. Use the bundle ID `com.ramjankhan.greenifyx`.
2. Download `GoogleService-Info.plist` and put it in `mobile/ios/Runner/`. It is git-ignored.
3. In Apple Developer → Keys, create an **APNs key**. Upload it in Firebase → Project settings → Cloud Messaging → Apple app configuration.

## Build
```
cd mobile
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```
In Xcode, select **Runner**, open **Signing & Capabilities**, and choose your Team. Then add these capabilities:
- **Push Notifications**
- **Background Modes**: Remote notifications, Audio, Voice over IP. These are already declared in Info.plist; Xcode only needs them ticked.
- **HealthKit** (for Health sync: steps and cycling workouts). The usage text is already in Info.plist. Also enable HealthKit for the App ID in your Apple Developer account.

Connect an iPhone and press Run. To share the app with testers or a client:
```
flutter build ipa --release
```
Then upload the `.ipa` in Xcode → Organizer, or with the Transporter app, to **TestFlight**. Testers install it from the TestFlight app.
