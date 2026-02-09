# Audio & Call App

A cross-platform Flutter app with a NestJS backend providing **audio reels** (vertical scroll feed), **voice/video calling** (Agora), **live audio streaming**, and **Firebase auth** (phone OTP). Built with BLoC state management, WebSocket signaling, and FCM/CallKit for incoming calls when the app is in background or killed.

---

## Features

| Feature   | Description                                                                                                                                                |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Reels** | Vertical full-screen audio feed; auto-play on scroll, dual-player preload for instant transitions, app lifecycle handling (pause/resume).                  |
| **Calls** | Create offer → callee notified via WebSocket (foreground) or FCM (background/killed); Accept/Decline with CallKit-style UI; join Agora channel with token. |
| **Live**  | Host goes live (Agora publisher); real-time "Live now" list via WebSocket; listeners join as subscribers.                                                  |
| **Auth**  | Phone OTP (Firebase), sign-up, profile (display name + photo), FCM token upload, list users for calling.                                                   |

---

## Tech Stack

| Layer        | Technologies                                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| **Frontend** | Flutter 3.x, Dart, `flutter_bloc`, Firebase (Auth, FCM), Agora RTC, Socket.IO client, `just_audio`, `flutter_callkit_incoming` |
| **Backend**  | NestJS, TypeORM, PostgreSQL, Socket.IO, Firebase Admin, Agora token server                                                     |
| **Infra**    | Firebase (Auth, optional Storage), Agora (calls & live)                                                                        |

---

## Project Structure

```
assignment/
├── README.md                 # This file
├── .gitignore
├── backend_app/              # NestJS API + WebSocket + static files
│   ├── src/
│   │   ├── auth/             # Sign-in, sign-up, profile, FCM token, users list
│   │   ├── calls/            # Agora tokens, call offer/accept/decline/cancel
│   │   ├── live/             # Start/end live, list sessions
│   │   ├── reels/            # Reels list (audio/image URLs)
│   │   ├── signaling/        # Socket.IO gateway (incoming_call, call_accepted, live_started, etc.)
│   │   ├── users/
│   │   └── common/            # Firebase module
│   ├── ENV_SETUP.md
│   └── README.md
└── frontend_app/             # Flutter app (Android & iOS)
    ├── lib/
    │   ├── main.dart         # Bootstrap, FCM background handler, providers, IncomingCallListener
    │   ├── core/             # Config, network (Dio), errors, widgets
    │   └── features/
    │       ├── auth/         # BLoC, phone OTP, onboarding, sign-in
    │       ├── call/         # BLoCs (incoming, ringing, active), FCM, CallKit, signaling, Agora
    │       ├── live/         # BLoCs (hub, host, listener), Agora live
    │       └── reels/        # BLoC, ReelsAudioController, feed UI
    ├── IOS_TEST_CHECKLIST.md
    └── README.md
```

---

## Prerequisites

- **Node.js** 18+ and **npm** (backend)
- **Flutter** SDK 3.x (frontend)
- **PostgreSQL** (backend DB)
- **Firebase** project (Auth, Cloud Messaging; optional Storage for reels media)
- **Agora** project (App ID + token auth; used for calls and live)

---

## Setup

### 1. Backend

```bash
cd backend_app
npm install
cp .env.example .env   # or create .env from ENV_SETUP.md
```

Edit `.env` with:

- `DATABASE_URL` or `DB_*` (PostgreSQL)
- `FIREBASE_*` (service account path or JSON)
- `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`
- Optional: `PORT`, `DB_SYNC`

```bash
npm run start:dev
```

API: `http://localhost:3000` (or your `PORT`). WebSocket: `ws://localhost:3000`.

### 2. Firebase (frontend)

- Create a Firebase project; enable **Authentication** (Phone) and **Cloud Messaging**.
- Add Android and iOS apps; download `google-services.json` / `GoogleService-Info.plist`.
- From project root:

```bash
cd frontend_app
flutter pub get
flutterfire configure
```

### 3. Frontend config

- In `frontend_app/lib/core/config/app_config.dart`, set `baseUrlOverride` to your backend URL when using a physical device (e.g. `http://192.168.1.100:3000`). Leave `null` for emulator/simulator (defaults: Android `10.0.2.2:3000`, iOS `localhost:3000`).

### 4. Run the app

```bash
cd frontend_app
flutter run
```

---

## Running the Full Stack

1. Start PostgreSQL.
2. Start backend: `cd backend_app && npm run start:dev`.
3. Run Flutter app: `cd frontend_app && flutter run` (choose device/simulator).

---

## Main Components (summary)

- **Bootstrap (`main.dart`)**: Firebase + FCM background handler, create repositories (auth, reels, call, live), FCM + Signaling services, `GlobalKey` for navigator, `runApp` with `RepositoryProvider`s and BLoC providers. Incoming call listener wraps dashboard to show `IncomingCallPage` on WebSocket/FCM `incoming_call`.
- **Auth**: `AuthRepository` (domain) → `AuthRepositoryImpl` (remote + local + Firebase). `AuthBloc` handles OTP, sign-up, profile, sign-out; after login, FCM token is uploaded and WebSocket connects.
- **Calls**: `CallRepository` for tokens and offer/accept/decline/cancel. **Foreground**: `SignalingService` (Socket.IO) emits `incoming_call` → `_IncomingCallListener` pushes `IncomingCallPage`. **Background/killed**: FCM data message → `_firebaseMessagingBackgroundHandler` → `CallKitIncomingService.showIncomingCall`; on Accept, `listenToCallEvents` uses navigator key to push `IncomingCallPage`. Accept → token → `CallScreenPage` + Agora join. Deduplication avoids duplicate UI for the same call.
- **Reels**: `ReelsBloc` loads list; `ReelsFeedPage` uses `PageView` + `ReelsAudioController` (two `AudioPlayer`s for preload, lifecycle pause/resume).
- **Live**: `LiveHubBloc` + `SignalingService.liveStarted` / `liveEnded`; host/listener use `LiveRepository` + Agora with publisher/subscriber roles.

---

## Documentation

| Doc                                                                      | Purpose                  |
| ------------------------------------------------------------------------ | ------------------------ |
| [backend_app/README.md](backend_app/README.md)                           | NestJS setup and scripts |
| [backend_app/ENV_SETUP.md](backend_app/ENV_SETUP.md)                     | Environment variables    |
| [frontend_app/IOS_TEST_CHECKLIST.md](frontend_app/IOS_TEST_CHECKLIST.md) | iOS testing notes        |

---

## License

Private / unlicensed unless otherwise stated.
