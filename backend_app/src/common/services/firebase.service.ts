import { Injectable, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { ConfigService } from '@nestjs/config';

/**
 * Firebase Service
 * Centralized service for Firebase Admin SDK operations
 * Handles token verification and user info extraction
 */
@Injectable()
export class FirebaseService implements OnModuleInit {
  private firebaseApp: admin.app.App;

  constructor(private configService: ConfigService) {}

  /**
   * Initialize Firebase Admin SDK on module initialization
   * Reads credentials from environment variables
   */
  onModuleInit() {
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');
    const privateKey = this.configService
      .get<string>('FIREBASE_PRIVATE_KEY')
      ?.replace(/\\n/g, '\n');
    const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL');

    if (!projectId || !privateKey || !clientEmail) {
      throw new Error('Firebase credentials are missing in environment variables');
    }

    this.firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey,
        clientEmail,
      }),
    });
  }

  /**
   * Verify Firebase ID token
   * @param idToken - Firebase ID token from client
   * @returns Decoded token with user information
   */
  async verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
    try {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      return decodedToken;
    } catch (error) {
      throw new Error(`Invalid Firebase token: ${error.message}`);
    }
  }

  /**
   * Get user information from Firebase Auth
   * @param uid - Firebase user UID
   * @returns User record from Firebase
   */
  async getUserByUid(uid: string): Promise<admin.auth.UserRecord> {
    try {
      return await admin.auth().getUser(uid);
    } catch (error) {
      throw new Error(`Failed to get user from Firebase: ${error.message}`);
    }
  }

  /**
   * Get Firebase Admin instance
   * @returns Firebase Admin app instance
   */
  getAdmin(): admin.app.App {
    return this.firebaseApp;
  }
}
