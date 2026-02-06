# Authentication Implementation Plan

## Overview
Implement Google Authentication using Firebase (Firebase Auth on frontend, Firebase Admin SDK on backend) with clean architecture, reusable code, and modular design.

---

## Architecture Layers

### Backend (NestJS)

#### 1. **Firebase Admin Setup**
- Install `firebase-admin` package
- Create `FirebaseModule` with configuration
- Initialize Firebase Admin SDK with service account credentials
- Export Firebase Admin service for use across modules

#### 2. **Database Layer**
- **User Entity** (`src/users/entities/user.entity.ts`)
  - Fields: `id`, `email`, `displayName`, `photoURL`, `firebaseUid`, `createdAt`, `updatedAt`
  - Use TypeORM or Prisma (we'll use TypeORM for simplicity)
- **User Repository** (`src/users/repositories/user.repository.ts`)
  - Methods: `findByFirebaseUid()`, `findByEmail()`, `create()`, `update()`

#### 3. **Auth Module Structure**
```
src/auth/
├── auth.module.ts
├── auth.controller.ts          # HTTP endpoints
├── auth.service.ts              # Business logic
├── dto/
│   ├── sign-in.dto.ts          # Request DTOs
│   ├── sign-up.dto.ts
│   └── auth-response.dto.ts    # Response DTOs
├── guards/
│   └── firebase-auth.guard.ts  # Token verification guard
└── strategies/
    └── firebase.strategy.ts    # Passport strategy (optional, for JWT)
```

#### 4. **Auth Endpoints**
- `POST /auth/sign-in`
  - Receives Firebase ID token from frontend
  - Verifies token with Firebase Admin
  - Checks if user exists in DB
  - If exists: return user data + JWT (or session token)
  - If not exists: return `{ exists: false }` with user info from Firebase
- `POST /auth/sign-up`
  - Receives Firebase ID token + consent flag
  - Verifies token
  - Creates user in DB
  - Returns user data + JWT
- `GET /auth/me` (protected)
  - Returns current user info
- `POST /auth/verify-token`
  - Verifies Firebase token and returns user info

#### 5. **Reusable Components**
- **FirebaseService** (`src/common/services/firebase.service.ts`)
  - Centralized Firebase Admin operations
  - Token verification
  - User info extraction
- **Response Interceptor**
  - Standardized API responses
- **Exception Filters**
  - Handle auth errors gracefully

---

### Frontend (Flutter)

#### 1. **Firebase Setup**
- Add `firebase_core` and `firebase_auth` packages
- Add `google_sign_in` package
- Configure Firebase for Android & iOS
- Initialize Firebase in `main.dart`

#### 2. **Clean Architecture Structure**
```
lib/
├── core/
│   ├── config/
│   │   └── firebase_config.dart      # Firebase initialization
│   └── errors/
│       └── auth_exceptions.dart      # Custom auth exceptions
├── features/
│   └── auth/
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── auth_remote_datasource.dart  # API calls
│       │   │   └── auth_local_datasource.dart   # Local storage (tokens)
│       │   ├── models/
│       │   │   └── user_model.dart              # Data model
│       │   └── repositories/
│       │       └── auth_repository_impl.dart    # Repository implementation
│       ├── domain/
│       │   ├── entities/
│       │   │   └── user_entity.dart            # Domain entity
│       │   ├── repositories/
│       │   │   └── auth_repository.dart        # Repository interface
│       │   └── usecases/
│       │       ├── sign_in_with_google.dart
│       │       ├── sign_up_with_google.dart
│       │       ├── get_current_user.dart
│       │       └── sign_out.dart
│       └── presentation/
│           ├── bloc/
│           │   ├── auth_bloc.dart
│           │   ├── auth_event.dart
│           │   └── auth_state.dart
│           ├── pages/
│           │   ├── sign_in_page.dart
│           │   └── sign_up_consent_page.dart
│           └── widgets/
│               ├── google_sign_in_button.dart
│               └── auth_error_message.dart
```

#### 3. **BLoC Implementation**
- **AuthEvent**
  - `SignInWithGoogleRequested()`
  - `SignUpWithGoogleRequested(consent: bool)`
  - `SignOutRequested()`
  - `CheckAuthStatus()`
- **AuthState**
  - `AuthInitial()`
  - `AuthLoading()`
  - `AuthAuthenticated(UserEntity user)`
  - `AuthUnauthenticated()`
  - `AuthUserNotFound(UserEntity userInfo)` - When user doesn't exist, show sign-up option
  - `AuthError(String message)`
- **AuthBloc**
  - Handles all auth logic
  - Emits appropriate states based on backend responses

#### 4. **UI Flow**
1. **Sign In Page**
   - Google Sign-In button
   - Loading state
   - Error messages
2. **User Not Found Flow**
   - Show dialog: "User not found. Would you like to create an account?"
   - Consent checkbox/button
   - Sign-up action
3. **Success Flow**
   - Navigate to Dashboard (with reels placeholder)
   - Store auth token locally

#### 5. **Reusable Components**
- **BaseButton** (`core/widgets/base_button.dart`)
- **BaseTextField** (`core/widgets/base_text_field.dart`)
- **LoadingIndicator** (`core/widgets/loading_indicator.dart`)
- **ErrorSnackbar** (`core/widgets/error_snackbar.dart`)
- **AuthGuard** - Route guard for protected pages

---

## Implementation Steps

### Phase 1: Backend Setup
1. Install Firebase Admin SDK
2. Create FirebaseModule
3. Setup database (PostgreSQL + TypeORM)
4. Create User entity
5. Create Auth module structure

### Phase 2: Backend Auth Logic
1. Implement token verification
2. Create sign-in endpoint (check if user exists)
3. Create sign-up endpoint
4. Add auth guards
5. Test endpoints with Postman/Thunder Client

### Phase 3: Frontend Setup
1. Add Firebase packages
2. Configure Firebase for Android/iOS
3. Initialize Firebase in app
4. Create clean architecture folders

### Phase 4: Frontend Auth Implementation
1. Create domain layer (entities, use cases, repository interface)
2. Create data layer (models, datasources, repository implementation)
3. Create Auth BLoC
4. Build sign-in UI
5. Implement user-not-found flow with consent
6. Add navigation to dashboard

### Phase 5: Integration & Testing
1. Connect frontend to backend
2. Test full flow (sign-in → user not found → sign-up → dashboard)
3. Handle edge cases and errors
4. Add proper error messages

---

## Key Design Principles

1. **Separation of Concerns**: Clear boundaries between data, domain, and presentation
2. **Dependency Inversion**: Domain layer doesn't depend on data layer
3. **Single Responsibility**: Each class/function has one job
4. **Reusability**: Common widgets, services, and utilities in `core/`
5. **Error Handling**: Consistent error handling across layers
6. **Type Safety**: Strong typing in both TypeScript and Dart

---

## Environment Variables Needed

### Backend (.env)
```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
JWT_SECRET=your-jwt-secret
```

### Frontend
- `google-services.json` (Android)
- `GoogleService-Info.plist` (iOS)
- Firebase config in code (or environment-specific config)

---

## Next Steps After Auth
Once authentication is complete:
- Dashboard page (placeholder for now)
- Protected routes
- Token refresh mechanism
- User profile management
