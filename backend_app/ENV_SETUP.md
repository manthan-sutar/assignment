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

# JWT Configuration (if needed later)
JWT_SECRET=your-jwt-secret-key
```

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

## Database Setup

Make sure PostgreSQL is running and create the database:

```sql
CREATE DATABASE assignment_db;
```

The application will automatically create tables if `DB_SYNC=true` (development only).
