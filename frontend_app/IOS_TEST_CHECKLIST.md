# iOS – What’s set up and what to test

## Already configured

- **Info.plist**
  - `UIBackgroundModes`: `voip`, `remote-notification` (CallKit + FCM background)
  - `NSMicrophoneUsageDescription` (calls + live)
  - `NSPhotoLibraryUsageDescription` (onboarding)
  - `NSAllowsLocalNetworking` (local backend)
- **Podfile** – `platform :ios, '12.0'` for Agora/CallKit/Firebase
- **GoogleService-Info.plist** – present for Firebase
- **AppDelegate** – default Flutter registration (plugins register themselves)

So in code and project config you’re in good shape for iOS.

---

## Before you run on a real device

1. **Xcode capabilities (recommended)**  
   Open `ios/Runner.xcworkspace` in Xcode, select the **Runner** target → **Signing & Capabilities** and add:
   - **Push Notifications** (for FCM when app is in background/killed)
   - **Background Modes** (Xcode may show this; ensure “Voice over IP” and “Remote notifications” are checked if listed)

   Without Push Notifications capability, FCM may not deliver when the app is not in the foreground.

2. **CallKit**  
   Works only on a **real device**, not in the simulator. Test incoming calls (and background/killed behavior) on a physical iPhone.

3. **CallKit icon (optional)**  
   The app uses `iconName: 'CallKitLogo'`. If the incoming call screen shows a missing icon, add an image named `CallKitLogo` to the iOS app (e.g. in `Runner/Assets.xcassets` or as an image set). Otherwise you can leave it; the system may show a default.

4. **Backend URL**  
   If you use a real backend, point the app to it (e.g. via env or `app_config.dart`). For simulator/device, ensure the device can reach that URL (e.g. same Wi‑Fi, or a deployed backend).

---

## Quick test plan on a real iPhone

| What to test | Where | Note |
|--------------|--------|------|
| App launches, sign-in / auth | Full app | Phone auth, onboarding if needed |
| Reels | Dashboard → Audio Reels | Scroll, play, pause (hold) |
| Outgoing call | Dashboard → Find people → user → call | Caller flow, ringing, then in-call |
| Incoming call (foreground) | Second device/account calls you | In-app incoming screen, Accept/Decline |
| Incoming call (background) | App in background, receive call | System/CallKit incoming UI, Accept/Decline, then in-app |
| Incoming call (killed) | Force quit app, receive call | Same as background; FCM + CallKit |
| Live (go live) | Dashboard → Audio Streaming → Go live | Mic permission, then “You’re live” |
| Live (listen) | Second device joins your live | Listener flow, leave |

---

## If something fails on iOS

- **No push when app is killed/background**  
  Add **Push Notifications** (and correct Background Modes) in Xcode and ensure FCM token is uploaded to your backend after sign-in.

- **CallKit never shows**  
  Use a real device, check `voip` + `remote-notification` in **Background Modes**, and that the backend sends the FCM payload when a call is offered.

- **Agora / “Failed to join”**  
  Check Agora app id/certificate and token from your backend; ensure mic permission is granted (first time you’ll get the system prompt).

- **Build error (e.g. signing, Pods)**  
  In `ios/`: run `pod install` (or `flutter pub get` then build again). Fix signing in Xcode (team, bundle id, capabilities).

---

**Summary:** iOS config in the project is in place. Add Push Notifications (and double-check Background Modes) in Xcode, then test on a **real device** for calls and push; you should be good to go.
