import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * User Entity
 * Represents a user in the system
 * Stores user information from Firebase Auth
 */
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: true })
  email: string;

  /**
   * Phone number - primary identifier for phone authentication
   * Format: +[country code][number] (e.g., +1234567890)
   */
  @Column({ unique: true })
  phoneNumber: string;

  @Column({ nullable: true })
  displayName: string;

  @Column({ nullable: true })
  photoURL: string;

  /**
   * Firebase UID - unique identifier from Firebase Auth
   * Used to link our user record with Firebase user
   */
  @Column({ unique: true, name: 'firebase_uid' })
  firebaseUid: string;

  /** FCM device token for push (incoming call, etc.). */
  @Column({ type: 'varchar', nullable: true, name: 'fcm_token' })
  fcmToken: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
