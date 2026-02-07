# Environment Variables Setup

Create a `.env` file in the `backend_app` directory with the following variables:

```env
# Server Configuration
PORT=3000

# Database Configuration (PostgreSQL)
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=assignment_db
DB_SYNC=true

# Firebase Admin SDK Configuration
# Get these from Firebase Console > Project Settings > Service Accounts
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour private key here\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
# Storage bucket for reels uploads (e.g. audioreel.firebasestorage.app or your-project.appspot.com)
FIREBASE_STORAGE_BUCKET=audioreel.firebasestorage.app
# Set to true to use public URLs for uploads (no signed URL). Objects will be publicly readable. Avoids "Signature was not base64 encoded" errors.
# FIREBASE_STORAGE_USE_PUBLIC_URL=true

# JWT Configuration (if needed later)
JWT_SECRET=your-jwt-secret-key

# Admin upload (reels) – set a secret key and pass it as X-Admin-Key when uploading
ADMIN_API_KEY=your-admin-secret-key

# Agora (calls & live audio streaming)
# Get these from https://console.agora.io/ → Your project → App ID & Certificate
AGORA_APP_ID=your-agora-app-id
AGORA_APP_CERTIFICATE=your-agora-app-certificate
```

**Note:** For reels admin upload, `ffmpeg` and `ffprobe` must be installed on the server (used to convert uploaded audio to M4A).

## Agora Setup (required for voice/video calls)

If you see **"Failed to get call token"** or **"Agora is not configured"**, the backend is missing Agora credentials. Add them to `.env`:

1. Go to [Agora Console](https://console.agora.io/).
2. Sign in or create an account.
3. Create a project (or use an existing one).
4. Open the project → **Project Management** → **App ID**.
5. Copy **App ID** → set as `AGORA_APP_ID` in `.env`.
6. Under the same project, enable **Primary Certificate** (or create one) and copy it → set as `AGORA_APP_CERTIFICATE` in `.env`.

Example (use your real values):

```env
AGORA_APP_ID=0123456789abcdef0123456789abcdef
AGORA_APP_CERTIFICATE=abcdef0123456789abcdef0123456789
```

Restart the backend after changing `.env`. Calls will then be able to get RTC tokens.

## Firebase Setup Instructions

1. Go to Firebase Console (https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Go to Project Settings > Service Accounts
4. Click "Generate new private key"
5. Download the JSON file
6. Extract the following values:
   - `project_id` → `FIREBASE_PROJECT_ID`
   - `private_key` → `FIREBASE_PRIVATE_KEY` (keep the quotes and \n characters)
   - `client_email` → `FIREBASE_CLIENT_EMAIL`
6. For reels admin upload, set **FIREBASE_STORAGE_BUCKET** to your Storage bucket name (Firebase Console > Storage: use the bucket host, e.g. `audioreel.firebasestorage.app` or `your-project-id.appspot.com`).

## Database Setup

Make sure PostgreSQL is running and create the database:

```sql
CREATE DATABASE assignment_db;
```

The application will automatically create tables if `DB_SYNC=true` (development only).
