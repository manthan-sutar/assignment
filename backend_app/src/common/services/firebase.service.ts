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
  private storageBucket: string;

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

    this.storageBucket =
      this.configService.get<string>('FIREBASE_STORAGE_BUCKET') ||
      `${projectId}.appspot.com`;

    this.firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey,
        clientEmail,
      }),
      storageBucket: this.storageBucket,
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

  /**
   * Send FCM message to a device token (data + optional notification for when app is in background/killed).
   */
  async sendToToken(
    token: string,
    data: Record<string, string>,
    notification?: { title: string; body: string },
  ): Promise<void> {
    if (!token?.trim()) return;
    const messaging = admin.messaging(this.firebaseApp);
    const message: admin.messaging.Message = {
      token,
      data,
      notification: notification
        ? { title: notification.title, body: notification.body }
        : undefined,
      android: { priority: 'high' as const },
      apns: { payload: { aps: { contentAvailable: true } }, fcmOptions: {} },
    };
    try {
      await messaging.send(message);
    } catch (err) {
      console.error('FCM send failed:', err);
    }
  }

  /**
   * Upload a file buffer to Firebase Storage and return a download URL.
   * If FIREBASE_STORAGE_USE_PUBLIC_URL is true, makes the object public and returns
   * the public URL (no signature). Otherwise returns a v4 signed URL (avoids
   * v2 "Signature was not base64 encoded" issues).
   */
  async uploadBufferAndGetUrl(
    path: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<string> {
    const bucket = admin
      .storage(this.firebaseApp)
      .bucket(this.storageBucket);
    const file = bucket.file(path);
    await file.save(buffer, {
      contentType,
      metadata: { cacheControl: 'public, max-age=31536000' },
    });

    const usePublicUrl =
      this.configService.get<string>('FIREBASE_STORAGE_USE_PUBLIC_URL') ===
      'true';

    if (usePublicUrl) {
      await file.makePublic();
      return `https://storage.googleapis.com/${this.storageBucket}/${path}`;
    }

    // v4 signed URLs allow max 7 days (604800 seconds)
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    const expires = new Date(Date.now() + sevenDaysMs);
    const [url] = (await file.getSignedUrl({
      action: 'read',
      expires,
      version: 'v4',
      virtualHostedStyle: true,
    })) as [string];
    return url;
  }
}
