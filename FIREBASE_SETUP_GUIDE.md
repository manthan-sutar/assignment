# Firebase Setup Guide

This guide will help you set up Firebase for both frontend (Flutter) and backend (NestJS).

## Step 1: Select or Create Firebase Project

You have two options:

### Option A: Use Existing Project
Run the FlutterFire configure command and select an existing project:
```bash
cd frontend_app
$HOME/.pub-cache/bin/flutterfire configure
```
Then select one of your existing projects from the list.

### Option B: Create New Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or "Create a project"
3. Enter project name: `assignment-app` (or any name you prefer)
4. Follow the setup wizard
5. Once created, run the FlutterFire configure command:
```bash
cd frontend_app
$HOME/.pub-cache/bin/flutterfire configure
```
6. Select the newly created project

---

## Step 2: Enable Google Authentication

1. In Firebase Console, go to your project
2. Navigate to **Authentication** > **Sign-in method**
3. Click on **Google** provider
4. Enable it and set:
   - **Support email**: Your email
   - **Project support email**: Your email
5. Click **Save**

---

## Step 3: Get Service Account Credentials (For Backend)

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Click on **Service Accounts** tab
3. Click **Generate new private key**
4. Download the JSON file
5. Open the JSON file and extract:
   - `project_id` → Use for `FIREBASE_PROJECT_ID`
   - `private_key` → Use for `FIREBASE_PRIVATE_KEY` (keep quotes and \n)
   - `client_email` → Use for `FIREBASE_CLIENT_EMAIL`

6. Add these to `backend_app/.env`:
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour private key here\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

---

## Step 4: Configure Flutter App (Automatic - Recommended)

After running `flutterfire configure` and selecting your project, it will:
- Add Firebase packages to `pubspec.yaml`
- Download and configure `google-services.json` (Android)
- Download and configure `GoogleService-Info.plist` (iOS)
- Create `firebase_options.dart` file

**Run this command:**
```bash
cd frontend_app
$HOME/.pub-cache/bin/flutterfire configure
```

Then select your Firebase project from the list.

---

## Step 5: Manual Flutter Configuration (If needed)

If you prefer manual setup:

### Add Firebase Packages
Add these to `frontend_app/pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  google_sign_in: ^6.0.0
```

### Android Setup
1. Download `google-services.json` from Firebase Console
   - Go to Project Settings > Your apps > Android app
   - Download `google-services.json`
2. Place it in `frontend_app/android/app/`
3. Add to `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```
4. Add to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

### iOS Setup
1. Download `GoogleService-Info.plist` from Firebase Console
   - Go to Project Settings > Your apps > iOS app
   - Download `GoogleService-Info.plist`
2. Place it in `frontend_app/ios/Runner/`
3. Open `ios/Runner.xcworkspace` in Xcode
4. Drag `GoogleService-Info.plist` into the Runner folder in Xcode

---

## Step 6: Verify Setup

### Backend
1. Make sure `.env` file has all Firebase credentials
2. Start the backend:
```bash
cd backend_app
npm run start:dev
```

### Frontend
1. Run `flutter pub get` in `frontend_app`
2. Test Firebase connection (we'll add this in auth implementation)

---

## Quick Commands Summary

```bash
# Configure Flutter Firebase (interactive)
cd frontend_app
$HOME/.pub-cache/bin/flutterfire configure

# Install Flutter dependencies
cd frontend_app
flutter pub get

# Start backend
cd backend_app
npm run start:dev
```

---

## Troubleshooting

### FlutterFire CLI not found
Add to your `~/.zshrc` or `~/.bashrc`:
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```
Then run `source ~/.zshrc` (or `source ~/.bashrc`)

### Firebase project creation failed
- Project ID might be taken, try a different name
- Or create project manually in Firebase Console

### Service account key issues
- Make sure private key includes `\n` characters
- Keep the quotes around the private key in `.env`
